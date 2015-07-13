--
-- Copyright (c) 2010
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: trace_ctrl
-- Author(s): Stefan Alex
-- 
------------------------------------------------------
-- Controller                                       --
------------------------------------------------------
--
-- Revision:    $Revision: 1.15 $
-- Last change: $Date: 2013-05-27 16:04:01 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.fifo.all;
use poc.functions.all;

use poc.trace_types.all;
use poc.trace_functions.all;
use poc.trace_internals.all;

entity trace_ctrl is
  generic (
    CONFIG                    : tSlv8_array;
    ICE_REGISTERS             : tNat_array;
    TRIGGER_INFORM            : boolean;
    TRIGGER_CNT               : natural;
    TRIGGER_OUT_BITS          : natural;
    TRIG_ACTIV_BITS           : positive;
    TRIG_REG_INDEX_BITS       : positive;
    TRIG_REG_BITS             : tNat_array;
    HAVE_ICE_TRIGGER          : boolean;
    TRIG_CMP1_BITS            : positive;
    TRIG_CMP2_BITS            : positive;
    TRIG_MODE_BITS            : positive;
    TRIG_TYPE_BITS            : positive;
    CYCLE_ACCURATE            : boolean;
    OV_DANGER_REACTION        : tOvDangerReaction;
    FILTER_INTERVAL           : natural;
    MIN_DATA_PACKET_SIZE      : positive;
    TIME_BITS                 : t1To8Int;
    TIME_CMP_LEVELS           : t1To8Int;
    GLOBAL_TIME_SAFE_DISTANCE : positive;
    GLOBAL_TIME_FIFO_DEPTH    : positive;
    TRACER_TIME_SAFE_DISTANCE : positive;
    TRACER_TIME_FIFO_DEPTH    : positive;
    TRACER_CNT                : positive;
    TRACER_DATA_BITS          : tNat_array;
    DO_RESYNC                 : boolean
  );
  port (
    clk_trc       : in  std_logic;
    rst_trc       : in  std_logic;
    clk_sys       : in  std_logic;
    rst_sys       : in  std_logic;
    trace_running : out std_logic;
    resync        : out std_logic;

    -- ICE-Interface (clk-trc-domain)
    ice_trig     : in  std_logic;
    cpu_stall    : out std_logic;
    ice_regs_in  : in  std_logic_vector(notZero(sum(ICE_REGISTERS))-1 downto 0);
    ice_regs_out : out std_logic_vector(notZero(sum(ICE_REGISTERS))-1 downto 0);
    ice_store    : out std_logic_vector(notZero(countValuesGreaterThan(ICE_REGISTERS, 0))-1 downto 0);

    -- incoming messegas (clk-sys-domain)
    eth_full : out std_logic;
    eth_din  : in  std_logic_vector(7 downto 0);
    eth_put  : in  std_logic;

    -- outgoing messages (clk-sys-domain)
    eth_valid   : out std_logic;
    eth_last    : out std_logic;
    eth_dout    : out std_logic_vector(7 downto 0);
    eth_got     : in  std_logic;
    eth_finish  : in  std_logic;
    header      : out std_logic;

    -- others
    trig_rsp : in std_logic; -- clk-trc-domain
    trig_err : in std_logic; -- clk-trc-domain

    -- filter for data_tracer (clk-trc-domain)
    filter_data : out std_logic;
    filter_adr  : out std_logic;

    -- status-tracer-interface (clk-trc-domain)
    st_stb : out std_logic;
    st_msg : out std_logic_vector(TRACER_CNT*2+2+
                                  ifThenElse(CYCLE_ACCURATE, 1, 0)+
                                  ifThenElse(TRIGGER_INFORM, TRIGGER_OUT_BITS, 0)-1 downto 0);

    -- tracer-interface (clk-trc-domain)
    tracer_stbs       : in  std_logic_vector(TRACER_CNT-1 downto 0);
    tracer_stb_en     : out std_logic;
    tracer_ovs        : in  std_logic_vector(TRACER_CNT-1 downto 0);
    tracer_ov_starts  : in  std_logic_vector(TRACER_CNT-1 downto 0);
    tracer_ov_stops   : in  std_logic_vector(TRACER_CNT-1 downto 0);
    tracer_ov_dangers : in  std_logic_vector(TRACER_CNT-1 downto 0);

    -- tracer-interface (clk-sys-domain)
    tracer_data       : in  std_logic_vector(sum(TRACER_DATA_BITS)-1 downto 0);
    tracer_data_fill  : in  std_logic_vector(sum(log2ceilnz(TRACER_DATA_BITS))-1 downto 0);
    tracer_data_last  : in  std_logic_vector(TRACER_CNT-1 downto 0);
    tracer_data_got   : out std_logic_vector(TRACER_CNT-1 downto 0);
    tracer_data_se    : in  std_logic_vector(TRACER_CNT-1 downto 0);
    tracer_data_valid : in  std_logic_vector(TRACER_CNT-1 downto 0);
    tracer_sel        : out std_logic_vector(TRACER_CNT-1 downto 0);

    -- trigger (clk-trc-domain)
    trig_reg_set   : out std_logic;
    trig_reg_index : out unsigned(TRIG_REG_INDEX_BITS-1 downto 0);
    trig_reg_val   : out std_logic_vector(notZero(max(TRIG_REG_BITS))-1 downto 0);
    trig_cmp_set   : out std_logic;
    trig_cmp1_val  : out tTriggerCmp1;
    trig_cmp2_val  : out tTriggerCmp2;
    trig_index     : out unsigned(notZero(log2ceilnz(notZero(TRIGGER_CNT)))-1 downto 0);
    trig_mode_set  : out std_logic;
    trig_mode_val  : out tTriggerMode;
    trig_type_set  : out std_logic;
    trig_type_val  : out tTriggerType;
    trig_activ_set : out std_logic;
    trig_activ_sel : out unsigned(TRIG_ACTIV_BITS-1 downto 0);
    trig_fired     : in  std_logic_vector(notZero(TRIGGER_OUT_BITS)-1 downto 0);
    trig_fired_stb : in  std_logic
  );
end trace_ctrl;

architecture Behavioral of trace_ctrl is

  constant TRIGGER : boolean := TRIGGER_CNT > 0;

  -- clk-trc-domain

  signal cpu_start_ov  : std_logic;
  signal cpu_stop_ov   : std_logic;

  signal st_stb_trig   : std_logic;
  signal st_stb_ov     : std_logic;
  signal st_stb_finish : std_logic;

  signal global_time_ov_stop   : std_logic;
  signal global_time_ov_danger : std_logic;
  signal tracer_time_ov_stop   : std_logic;
  signal tracer_time_ov_danger : std_logic;

  -- clk-sys-domain

  signal send_finish_cmd : std_logic;

  signal cpu_start_cmd : std_logic;
  signal cpu_stop_cmd  : std_logic;

  signal cpu_stall_sys : std_logic;

  signal trace_running_sys  : std_logic;
  signal trace_running_trc  : std_logic;
  signal trace_working      : std_logic;
  signal trace_init         : std_logic;

  signal tracer_valid2 : std_logic;
  
  signal sys2trc_rdy : std_logic;

  signal trig_rsp_sys : std_logic;
  signal trig_err_sys : std_logic;

  signal eth_dout_cmd  : std_logic_vector(7 downto 0);
  signal eth_valid_cmd : std_logic;
  signal eth_last_cmd  : std_logic;
  signal eth_got_cmd   : std_logic;

  signal send_data_fifo_clear : std_logic;
  signal send_data_fifo_put   : std_logic;
  signal send_data_fifo_full  : std_logic;
  signal send_data_fifo_din   : std_logic_vector(7 downto 0);
  signal send_data_fifo_empty : std_logic;

begin

  ---------------------
  -- CPU-Stall-Logic --
  ---------------------

  cpu_stall_blk : block
    signal cpu_stall_r : std_logic := '0';

    signal ice_trig_fired : std_logic;

    signal cpu_stop_cmd_trc  : std_logic;
    signal cpu_start_cmd_trc : std_logic;

  begin
  
    no_ice_trig_gen : if not HAVE_ICE_TRIGGER generate
      ice_trig_fired <= '0';
    end generate no_ice_trig_gen;

    ice_trig_gen : if HAVE_ICE_TRIGGER generate
      signal ice_trig_r     : std_logic;
    begin
      ice_trig_fired <= not ice_trig_r and ice_trig;

      clk_proc : process(clk_trc)
      begin
        if rising_edge(clk_trc) then
          ice_trig_r <= ice_trig;
        end if;
      end process clk_proc;

    end generate ice_trig_gen;

    clk_proc : process(clk_trc)
    begin
      if rising_edge(clk_trc) then
        if rst_trc = '1' then
          cpu_stall_r     <= '0';
        else

          if cpu_stop_ov = '1' or cpu_stop_cmd_trc = '1' or ice_trig_fired = '1' then
            cpu_stall_r <= '1';
          elsif cpu_start_ov = '1' or cpu_start_cmd_trc = '1' then
            cpu_stall_r <= '0';
          end if;

        end if;
      end if;
    end process clk_proc;

    cpu_stall <= cpu_stall_r;

    cpu_stall_sync_inst : trace_clk_sync
      port map (
        clk_dst   => clk_sys,
        value_in  => cpu_stall_r,       -- must be a registered value
        value_out => cpu_stall_sys
     );

    cpu_start_sync_inst : trace_clk_sync_2
      port map (
        clk_from       => clk_sys,
        clk_to         => clk_trc,
        signal_event   => cpu_start_cmd,
        event_signaled => cpu_start_cmd_trc
     );

    cpu_stop_sync_inst : trace_clk_sync_2
      port map (
        clk_from       => clk_sys,
        clk_to         => clk_trc,
        signal_event   => cpu_stop_cmd,
        event_signaled => cpu_stop_cmd_trc
     );

  end block cpu_stall_blk;

  ---------------------------------------------------------
  -- Process incoming messages and send outgoing answers --
  ---------------------------------------------------------

  cmd_block : block
    type tState is (WAITING_AND_DECODE, SEND_CONFIG, GET_ICE_REG_VALUE, SET_ICE_REG_VALUE, SET_TRIG_REG_VALUE,
                    SET_TRIG_REG_CMP, SET_TRIG_ACTIV, SET_TRIG_TYPE, SET_TRIG_MODE, SEND_ACK, SEND_ERR, SEND_TRIG_RSP,
                    STOP_MESSAGE, STOP_WAITING, WAIT_FOR_FINISH);
    signal state_cs : tState := WAITING_AND_DECODE;
    signal state_ns : tState;

    constant ICE_REG_CNT        : natural := countValuesGreaterThan(ICE_REGISTERS, 0);
    constant ICE_REGS           : boolean := ICE_REG_CNT > 0;
    constant ICE_BITS           : natural := sum(ICE_REGISTERS);
    constant ICE_MAX_REG_BITS   : natural := max(ICE_REGISTERS);
    constant ICE_SET_REG_BYTES  : natural := getBytesUp(max(ICE_REGISTERS));
    constant ICE_GET_REG_BYTES  : natural := getBytesUp(sum(ICE_REGISTERS));

    constant TRIGGER            : boolean := TRIGGER_CNT > 0;
    constant TRIG_MAX_REG_BITS  : natural := max(TRIG_REG_BITS);
    constant TRIG_MAX_REG_BYTES : natural := getBytesUp(TRIG_MAX_REG_BITS);
    constant TRIG_MAX_VAL_BITS  : natural := max(TRIG_CMP1_BITS, max(TRIG_CMP2_BITS,
                                             max(TRIG_MODE_BITS, max(TRIG_TYPE_BITS,
                                             TRIG_ACTIV_BITS))));
    constant TRIG_INDEX_BITS    : natural := notZero(log2ceilnz(notZero(TRIGGER_CNT)));

    constant FINISH_INT : positive := 15;

    constant CNT : positive := max(CONFIG'length, ifThenElse(TRIGGER, TRIG_MAX_REG_BYTES, 0),
                                                  ifThenElse(ICE_REGS, max(ICE_SET_REG_BYTES, ICE_GET_REG_BYTES), 0),
                                                  FINISH_INT);
    -- signals

    signal cnt_r            : unsigned(log2ceil(CNT)-1 downto 0) := (others => '0');
    signal cnt_rst          : std_logic;
    signal cnt_inc          : std_logic;
    signal cnt_config       : std_logic;
    signal cnt_set_ice_reg  : std_logic;
    signal cnt_get_ice_reg  : std_logic;
    signal cnt_set_trig_reg : std_logic;
    signal cnt_zero         : std_logic;
    signal cnt_one          : std_logic;
    signal cnt_finish       : std_logic;

    signal upd_id : std_logic;

    signal ice_store_cmd      : std_logic;
    signal ice_store_sys      : std_logic_vector(notZero(ICE_REG_CNT)-1 downto 0);
    signal ice_regs_in_sys    : std_logic_vector(notZero(ICE_BITS)-1 downto 0);
    signal ice_regs_valid_sys : std_logic;
    signal ice_regs_out_sys   : std_logic_vector(notZero(ICE_MAX_REG_BITS)-1 downto 0);
    signal ice_reg_id_sys     : std_logic_vector(log2ceilnz(notZero(ICE_REG_CNT))-1 downto 0);
    signal ice_reg_send       : std_logic_vector(7 downto 0);
    signal ice_reg_id_invalid : std_logic;

    signal trig_reg_set_sys   : std_logic;
    signal trig_reg_index_sys : std_logic_vector(TRIG_REG_INDEX_BITS-1 downto 0);
    signal trig_cmp_set_sys   : std_logic;
    signal trig_val_sys       : std_logic_vector(notZero(TRIG_MAX_VAL_BITS)-1 downto 0);
    signal trig_reg_sys       : std_logic_vector(notZero(TRIG_MAX_REG_BITS)-1 downto 0);
    signal trig_index_sys     : std_logic_vector(notZero(TRIG_INDEX_BITS)-1 downto 0);
    signal trig_mode_set_sys  : std_logic;
    signal trig_type_set_sys  : std_logic;
    signal trig_activ_set_sys : std_logic;

    signal config_send : std_logic_vector(7 downto 0);

    signal trace_start        : std_logic;
    signal trace_stop         : std_logic;
    signal trace_reinit       : std_logic;
    signal trace_reinit_r     : std_logic;
  begin

    eth_full <= '1' when state_cs = SEND_ACK
                      or state_cs = SEND_ERR
                      or state_cs = SEND_TRIG_RSP
                      or state_cs = SEND_CONFIG
                      or state_cs = GET_ICE_REG_VALUE
                      or sys2trc_rdy = '0'
                    else '0';

    -----------------------------------------------
    -- receive trigger- and ice-register-content --
    -----------------------------------------------

    recv_gen : if TRIGGER or ICE_REGS generate
      constant REG_BITS      : natural := max(ICE_MAX_REG_BITS, TRIG_MAX_REG_BITS);
      constant STORE_BYTES   : natural := getBytesDown(REG_BITS);
      constant NO_STORE_BITS : natural := REG_BITS-STORE_BYTES*8;

      signal recv_reg_r : std_logic_vector(REG_BITS-1 downto 0) := (others => '0');
      signal recv_state : std_logic;

    begin

      recv_state <= '1' when state_cs = SET_ICE_REG_VALUE or state_cs = SET_TRIG_REG_VALUE or
                             state_cs = SET_TRIG_REG_CMP or state_cs = SET_TRIG_ACTIV or
                             state_cs = SET_TRIG_TYPE or state_cs = SET_TRIG_MODE else '0';

      -- generate receive-id-register
      recv_id_gen : if TRIGGER or (ICE_REG_CNT > 1) generate
        constant ID_BITS : positive := max(ifThenElse(TRIGGER, TRIG_REG_INDEX_BITS,1), ifThenElse(TRIGGER, TRIG_INDEX_BITS, 1),
                                           ifThenElse(ICE_REGS, log2ceil(notZero(ICE_REG_CNT)),1));
        signal recv_id_r   : std_logic_vector(ID_BITS-1 downto 0) := (others => '0');
        signal recv_id_nxt : std_logic_vector(ID_BITS-1 downto 0);
      begin

        assert ID_BITS <= 8
          severity error;

        with upd_id select
          recv_id_nxt <= eth_din(ID_BITS-1 downto 0) when '1',
                         recv_id_r                   when others;

        clk_proc : process(clk_sys)
        begin
          if rising_edge(clk_sys) then
            recv_id_r <= recv_id_nxt;
          end if;
        end process clk_proc;

        trigger_id_gen : if TRIGGER generate
          trig_index_sys     <= recv_id_r(trig_index_sys'left downto 0);
          trig_reg_index_sys <= recv_id_r(trig_reg_index_sys'left downto 0);
        end generate trigger_id_gen;

        ice_id_gen : if ICE_REG_CNT > 1 generate
          ice_reg_id_sys     <= recv_id_r(ice_reg_id_sys'left downto 0);
          ice_reg_id_invalid <= '1' when to_integer(unsigned(ice_reg_id_sys)) > ICE_REG_CNT-1
                                    else '0';
        end generate ice_id_gen;

      end generate recv_id_gen;

      no_recv_id_gen : if not TRIGGER and not (ICE_REG_CNT > 1)generate
        ice_reg_id_invalid <= '0';
      end generate no_recv_id_gen;

      -- generate recv_reg

      recv_reg_r(recv_reg_r'left downto STORE_BYTES*8) <= eth_din(NO_STORE_BITS-1 downto 0);

      more_byte_gen : if STORE_BYTES > 0 generate
        signal recv_reg_nxt : std_logic_vector(STORE_BYTES*8-1 downto 0);
      begin

        reg_multi_gen : for i in 1 to STORE_BYTES generate
          recv_reg_nxt(i*8-1 downto (i-1)*8) <= eth_din when recv_state = '1' and cnt_r = to_unsigned(i, cnt_r'length) else
                                                recv_reg_r(i*8-1 downto (i-1)*8);
        end generate reg_multi_gen;

        clk_proc : process(clk_sys)
        begin
          if rising_edge(clk_sys) then
            if rst_sys = '1' then
              recv_reg_r(STORE_BYTES*8-1 downto 0) <= (others => '0');
            else
              recv_reg_r(STORE_BYTES*8-1 downto 0) <= recv_reg_nxt;
            end if;
          end if;
        end process clk_proc;

      end generate more_byte_gen;

      -- generate ice-register-output

      ice_out_gen : if ICE_REGS generate

        ice_regs_out_sys <= recv_reg_r(ICE_MAX_REG_BITS-1 downto 0);

        ice_reg_out_gen : for i in 0 to ICE_REGISTERS'length-1 generate
          cond_gen : if ICE_REGISTERS(i) > 0 generate
            constant ID : natural := countValuesGreaterThan(ICE_REGISTERS, i, 0);
          begin
            ice_store_sys(i) <= '1' when ice_reg_id_sys = std_logic_vector(to_unsigned(ID, ice_reg_id_sys'length)) and ice_store_cmd = '1' else '0';
          end generate cond_gen;
        end generate ice_reg_out_gen;

      end generate ice_out_gen;

      -- generate trigger-register-output
      trigger_out_gen : if TRIGGER generate
        trig_reg_sys <= recv_reg_r(trig_reg_sys'left downto 0);
        trig_val_sys <= eth_din(trig_val_sys'left downto 0);
      end generate trigger_out_gen;

    end generate recv_gen;

    ------------------------------------------
    -- send config and ice-register-content --
    ------------------------------------------

    -- multiplex config-and fifo-signals
    config_send <= CONFIG(to_integer(cnt_r)) when cnt_r < CONFIG'length else (others => 'X');

    send_gen : if ICE_REGS generate
      signal ice_sel : unsigned(log2ceilnz(ICE_GET_REG_BYTES)-1 downto 0);
      signal ice_reg : std_logic_vector(ICE_GET_REG_BYTES*8-1 downto 0);
    begin

      -- fill with zeros
      ice_reg <= fill(ice_regs_in_sys, ICE_GET_REG_BYTES*8);

      ice_sel  <= cnt_r(ice_sel'left downto 0);

      ice_reg_send_multiplex : trace_multiplex
        generic map (
          DATA_BITS => (ICE_GET_REG_BYTES-1 downto 0 => 8),
          IMPL      => true
        )
        port map (
          inputs => ice_reg,
          sel    => ice_sel,
          output => ice_reg_send
        );

    end generate send_gen;

    no_send_gen : if not ICE_REGS generate
      ice_reg_send <= (others => '0');
    end generate no_send_gen;

    -------------------
    -- counter-flags --
    -------------------

    cnt_config       <= '1' when cnt_r = notZero(CONFIG'length)-1     else '0';
    cnt_set_ice_reg  <= '1' when cnt_r = notZero(ICE_SET_REG_BYTES)   else '0';
    cnt_get_ice_reg  <= '1' when cnt_r = notZero(ICE_GET_REG_BYTES)-1 else '0';
    cnt_set_trig_reg <= '1' when cnt_r = notZero(TRIG_MAX_REG_BYTES)  else '0';
    cnt_zero         <= '1' when cnt_r = 0                            else '0';
    cnt_one          <= '1' when cnt_r = 1                            else '0';
    cnt_finish       <= '1' when cnt_r = FINISH_INT                   else '0';

    ----------------------------
    -- combinatorical process --
    ----------------------------

    com_proc : process(state_cs, ice_reg_id_invalid, ice_regs_valid_sys, eth_put, eth_din, eth_got_cmd, trig_rsp_sys,
                       cpu_stall_sys, cnt_config, ice_reg_send, cnt_get_ice_reg, cnt_set_ice_reg,
                       cnt_zero, trig_err, config_send, cnt_finish, trace_working,
                       trace_running_sys, send_data_fifo_empty, trig_err_sys, cnt_r, cnt_set_trig_reg, cnt_one)
    begin

      state_ns           <= state_cs;
      trace_start        <= '0';
      trace_stop         <= '0';
      trace_reinit       <= '0';
      cnt_inc            <= '0';
      cnt_rst            <= '0';
      cpu_stop_cmd       <= '0';
      cpu_start_cmd      <= '0';
      ice_store_cmd      <= '0';
      upd_id             <= '0';
      trig_reg_set_sys   <= '0';
      trig_cmp_set_sys   <= '0';
      trig_mode_set_sys  <= '0';
      trig_type_set_sys  <= '0';
      trig_activ_set_sys <= '0';
      eth_dout_cmd       <= (others => '0');
      eth_valid_cmd      <= '0';
      eth_last_cmd       <= '0';
      send_finish_cmd    <= '0';
      send_data_fifo_clear <= '0';
      
      case state_cs is

        when WAITING_AND_DECODE =>

          if eth_put = '1' then -- new command avl

            cnt_rst <= '1';

            case eth_din(3 downto 0) is -- decode the message

              when "0000" => -- get config

                state_ns <= SEND_CONFIG;

              when "0010" => -- stop cpu

                cpu_stop_cmd <= '1';
                state_ns     <= SEND_ACK;

              when "0011" => -- cpu stopped?

                if cpu_stall_sys = '1' then
                  state_ns <= SEND_ACK;
                else
                  state_ns <= SEND_ERR;
                end if;

              when "0100" => -- start cpu

                cpu_start_cmd <= '1';
                state_ns      <= SEND_ACK;

              when "0101" => -- get ice-register value

                if not ICE_REGS then
                  state_ns <= SEND_ERR;
                else
                  state_ns <= GET_ICE_REG_VALUE;
                end if;

              when "0110" => -- set ice-register value

                if not ICE_REGS then
                  state_ns <= SEND_ERR;
                else
                  state_ns <= SET_ICE_REG_VALUE;
                end if;

              when "0111" => -- set trigger-register-value

                if not TRIGGER then
                  state_ns <= SEND_ERR;
                else
                  state_ns <= SET_TRIG_REG_VALUE;
                end if;

              when "1000" => -- set register-compare-type

                if not TRIGGER  then
                  state_ns <= SEND_ERR;
                else
                  state_ns <= SET_TRIG_REG_CMP;
                end if;

              when "1001" => -- set trigger-activ

                if not TRIGGER then
                  state_ns <= SEND_ERR;
                else
                  state_ns <= SET_TRIG_ACTIV;
                end if;

              when "1010" => -- set trigger-mode

                if not TRIGGER then
                  state_ns <= SEND_ERR;
                else
                  state_ns <= SET_TRIG_MODE;
                end if;

              when "1011" => -- set trigger-type

                if not TRIGGER then
                  state_ns <= SEND_ERR;
                else
                  state_ns <= SET_TRIG_TYPE;
                end if;

              when "1100" => -- start tracing

                trace_start <= '1';
                state_ns    <= SEND_ACK;

              when "1101" => -- stop tracing

                if trace_running_sys = '0' then
                  state_ns <= SEND_ERR;
                else
                  -- stop all tracer except ctrl-message-tracer
                  trace_stop <= '1';
                  state_ns <= STOP_MESSAGE;
                end if;

              when others => -- wrong opcode
                state_ns <= SEND_ERR;

            end case;

          end if;

        when SEND_CONFIG =>

          eth_dout_cmd  <= config_send;
          eth_valid_cmd <= '1';
          eth_last_cmd  <= cnt_config;

          if eth_got_cmd = '1' then
            if cnt_config = '1' then
              state_ns     <= WAITING_AND_DECODE;
            else
              cnt_inc <= '1';
            end if;
          end if;

        when GET_ICE_REG_VALUE =>

          if ice_regs_valid_sys = '1' then
            eth_dout_cmd  <= ice_reg_send;
            eth_valid_cmd <= '1';
            eth_last_cmd  <= cnt_get_ice_reg;

            if eth_got_cmd = '1' then
              if cnt_get_ice_reg = '1' then
                state_ns     <= WAITING_AND_DECODE;
              else
                cnt_inc <= '1';
              end if;
            end if;
          end if;

        when SET_ICE_REG_VALUE =>

          if eth_put = '1' then

            if cnt_zero = '1' then
              if ice_reg_id_invalid = '1' then -- id is not valid, so send error-message
                state_ns <= SEND_ERR;
              else -- id is valid
                upd_id <= '1';
                cnt_inc <= '1';
              end if;

            else -- get register values

              if cnt_set_ice_reg = '1' then
                ice_store_cmd <= '1';
                state_ns    <= SEND_ACK;
              else
                cnt_inc <= '1';
              end if;
            end if;
          end if;

        when SET_TRIG_REG_VALUE =>

          if eth_put = '1' then
            cnt_inc <= '1';

            if cnt_zero = '1' then
              upd_id <= '1';
            elsif cnt_set_trig_reg = '1' then -- get register values
              trig_reg_set_sys <= '1';
              state_ns         <= SEND_TRIG_RSP;
            end if;

          end if;

        when SET_TRIG_REG_CMP =>

          if eth_put = '1' then
            cnt_inc <= '1';

            if cnt_zero = '1' then
              upd_id <= '1';
            elsif cnt_one = '1' then
              trig_cmp_set_sys <= '1';
              state_ns         <= SEND_TRIG_RSP;
            end if;

          end if;

        when SET_TRIG_ACTIV =>

          if eth_put = '1' then
            cnt_inc <= '1';

            if cnt_zero = '1' then
              upd_id  <= '1';
            elsif cnt_one = '1' then
              trig_activ_set_sys <= '1';
              state_ns           <= SEND_TRIG_RSP;
            end if;
          end if;

        when SET_TRIG_MODE =>

          if eth_put = '1' then
            cnt_inc <= '1';

            if cnt_zero = '1' then
              upd_id  <= '1';
            elsif cnt_one = '1' then
              trig_mode_set_sys <= '1';
              state_ns          <= SEND_TRIG_RSP;
            end if;
          end if;

        when SET_TRIG_TYPE =>

          if eth_put = '1' then
            cnt_inc <= '1';

            if cnt_zero = '1' then
              upd_id  <= '1';
            elsif cnt_one = '1' then
              trig_type_set_sys <= '1';
              state_ns          <= SEND_TRIG_RSP;
            end if;

          end if;

        when SEND_TRIG_RSP =>

          if trig_rsp_sys = '1' then

            if trig_err_sys = '1' then
              state_ns <= SEND_ERR;
            else
              state_ns <= SEND_ACK;
            end if;

          end if;

        when STOP_MESSAGE =>
          -- all tracer except ctrl-message-tracer have already been stopped
          -- insert some stop messages, actually more than one to also clear
          -- pipeline registers inside the funnel
          send_finish_cmd <= '1';
          
          cnt_inc <= '1';
          if cnt_finish = '1' then
            cnt_rst  <= '1';
            state_ns <= STOP_WAITING;
          end if;

        when STOP_WAITING =>
          -- Wait for passing stop-messages through the pipeline
          cnt_inc <= '1';
          if cnt_finish = '1' then
            cnt_rst  <= '1';
            state_ns <= WAIT_FOR_FINISH;
          end if;

          
        when WAIT_FOR_FINISH =>
          -- clear fifos
          send_data_fifo_clear <= '1';
          if trace_running_sys = '0' and trace_working = '0' and send_data_fifo_empty = '1' then
            trace_reinit <= '1';
            state_ns <= SEND_ACK;
          end if;

        when SEND_ACK =>

          eth_dout_cmd  <= "00000001";
          eth_valid_cmd <= '1';
          eth_last_cmd  <= '1';

          if eth_got_cmd = '1' then
            state_ns <= WAITING_AND_DECODE;
          end if;

        when SEND_ERR =>

          eth_dout_cmd  <= "00000000";
          eth_valid_cmd <= '1';
          eth_last_cmd  <= '1';

          if eth_got_cmd = '1' then
            state_ns <= WAITING_AND_DECODE;
          end if;

      end case;

    end process com_proc;

    clk_proc : process(clk_sys)
    begin
      if rising_edge(clk_sys) then
        if rst_sys = '1' then
          state_cs <= WAITING_AND_DECODE;
          cnt_r    <= (others => '0');

          trace_running_sys <= '0';
          trace_reinit_r    <= '0';
        else

          state_cs <= state_ns;

          if cnt_rst = '1' then
            cnt_r <= (others => '0');
          elsif cnt_inc = '1' then
            cnt_r <= cnt_r + 1;
          end if;

          if trace_start = '1' then
            trace_running_sys <= '1';
          elsif trace_stop = '1' then
            trace_running_sys <= '0';
          end if;

          -- shorten critical path
          trace_reinit_r <= trace_reinit;
        end if;
      end if;
    end process clk_proc;

    trace_running_sync_I: trace_clk_sync
      port map (
        clk_dst   => clk_trc,
        value_in  => trace_running_sys,  -- must be a registered value
        value_out => trace_running_trc);

    trace_running <= trace_running_trc;
    
    -- Initialize trace-components for a new trace, e.g.
    -- value_sel and value_2fifo.
    -- Do not use it to reset trace_fifo_ic or fifo_ic_*. These
    -- components have two clocks for which reset must be applied at the same
    -- time!
    trace_init <= rst_sys or trace_reinit_r;
    
    ---------------
    -- trc-2-sys --
    ---------------

    trc2sys_blk : block

      constant TRIG_CTRL_BITS : natural := ifThenElse(TRIGGER,2, 0);
      constant ICE_VALUE_BITS : natural := ifThenElse(ICE_REGS, sum(ICE_REGISTERS), 0);
      constant TRC2SYS_BITS   : natural := ICE_VALUE_BITS + TRIG_CTRL_BITS;
    begin

      fifo_gen : if TRC2SYS_BITS > 0 generate
        signal t2s_fifo_din   : std_logic_vector(TRC2SYS_BITS-1 downto 0);
        signal t2s_fifo_put   : std_logic;
        signal t2s_fifo_full  : std_logic;
        signal t2s_fifo_dout  : std_logic_vector(TRC2SYS_BITS-1 downto 0);
        signal t2s_fifo_valid : std_logic;
        signal t2s_fifo_got   : std_logic;
      begin

        trc2sys_fifo_inst : fifo_ic_got
          generic map (
            DATA_REG   => true,
            D_BITS     => TRC2SYS_BITS,
            MIN_DEPTH  => 2
          )
          port map (
            clk_wr => clk_trc,
            rst_wr => rst_trc,
            put    => t2s_fifo_put,
            din    => t2s_fifo_din,
            full   => t2s_fifo_full,
            clk_rd => clk_sys,
            rst_rd => rst_sys,
            got    => t2s_fifo_got,
            valid  => t2s_fifo_valid,
            dout   => t2s_fifo_dout
          );

        t2s_fifo_put <= not t2s_fifo_full;
        t2s_fifo_got <= '1' when state_cs /= GET_ICE_REG_VALUE else '0';

        -- trigger

        trig_gen : if TRIG_CTRL_BITS > 0 generate

          t2s_fifo_din(1 downto 0) <= trig_err & trig_rsp;

          trig_err_sys <= t2s_fifo_dout(1);
          trig_rsp_sys <= t2s_fifo_dout(0) and t2s_fifo_valid;

        end generate trig_gen;

        -- ice-register

        ice_gen : if ICE_VALUE_BITS > 0 generate

          t2s_fifo_din(TRIG_CTRL_BITS+ICE_VALUE_BITS-1 downto TRIG_CTRL_BITS) <= ice_regs_in;

          ice_regs_in_sys    <= t2s_fifo_dout(TRIG_CTRL_BITS+ICE_VALUE_BITS-1 downto TRIG_CTRL_BITS);
          ice_regs_valid_sys <= t2s_fifo_valid;

        end generate ice_gen;

      end generate fifo_gen;

      -- no ice or trigger

      no_trig_gen : if TRIG_CTRL_BITS = 0 generate
        trig_rsp_sys <= '1';
        trig_err_sys <= '1';
      end generate no_trig_gen;

      ice_gen : if ICE_VALUE_BITS = 0 generate
        ice_regs_in_sys    <= (others => '0');
        ice_regs_valid_sys <= '0';
      end generate ice_gen;

    end block trc2sys_blk;

    ---------------
    -- sys-2-trc --
    ---------------
    sys2trc_blk : block

      constant ICE_CTRL_BITS  : natural := countValuesGreaterThan(ICE_REGISTERS, 0);
      constant ICE_DATA_BITS  : natural := ifThenElse(ICE_REGS, max(ICE_REGISTERS), 0);
      constant TRIG_CTRL_BITS : natural := ifThenElse(TRIGGER, 5, 0);
      constant TRIG_DATA_BITS : natural := ifThenElse(TRIGGER, max(TRIG_MAX_REG_BITS+TRIG_REG_INDEX_BITS,
                                                               max(TRIG_CMP1_BITS+TRIG_REG_INDEX_BITS,
                                                               max(TRIG_CMP2_BITS+TRIG_REG_INDEX_BITS,
                                                               max(TRIG_ACTIV_BITS+TRIG_INDEX_BITS,
                                                               max(TRIG_MODE_BITS+TRIG_INDEX_BITS,
                                                                   TRIG_TYPE_BITS+TRIG_INDEX_BITS))))), 0);
      constant DATA_INDEX     : natural := ICE_CTRL_BITS + TRIG_CTRL_BITS;
      constant DATA_BITS      : natural := max(ICE_DATA_BITS, TRIG_DATA_BITS);
      constant SYS2TRC_BITS   : natural := ICE_CTRL_BITS + TRIG_CTRL_BITS + DATA_BITS;

      signal trig_or_ice : std_logic;

    begin

      fifo_gen : if SYS2TRC_BITS > 0 generate
        signal s2t_fifo_din   : std_logic_vector(SYS2TRC_BITS-1 downto 0);
        signal s2t_fifo_put   : std_logic;
        signal s2t_fifo_full  : std_logic;
        signal s2t_fifo_dout  : std_logic_vector(SYS2TRC_BITS-1 downto 0);
        signal s2t_fifo_valid : std_logic;
        signal s2t_fifo_got   : std_logic;

      begin

        sys2trc_fifo_inst : fifo_ic_got
          generic map (
            DATA_REG   => true,
            D_BITS     => SYS2TRC_BITS,
            MIN_DEPTH  => 2
          )
          port map (
            clk_wr => clk_sys,
            rst_wr => rst_sys,
            put    => s2t_fifo_put,
            din    => s2t_fifo_din,
            full   => s2t_fifo_full,
            clk_rd => clk_trc,
            rst_rd => rst_trc,
            got    => s2t_fifo_got,
            valid  => s2t_fifo_valid,
            dout   => s2t_fifo_dout
          );

        -----------------
        -- fifo-inputs --
        -----------------

        -- ice-ctrl-signals
        ice_in_gen : if ICE_REGS generate
        begin
          s2t_fifo_din(ICE_CTRL_BITS-1 downto 0) <= ice_store_sys;
        end generate ice_in_gen;

        -- trigger-ctrl-signals
        trig_in_gen : if TRIGGER generate
          signal trig_ctrl_sys : std_logic_vector(TRIG_CTRL_BITS-1 downto 0);
        begin
          trig_ctrl_sys(0) <= trig_reg_set_sys;
          trig_ctrl_sys(1) <= trig_cmp_set_sys;
          trig_ctrl_sys(2) <= trig_mode_set_sys;
          trig_ctrl_sys(3) <= trig_type_set_sys;
          trig_ctrl_sys(4) <= trig_activ_set_sys;

          s2t_fifo_din(TRIG_CTRL_BITS+ICE_CTRL_BITS-1 downto ICE_CTRL_BITS) <= trig_ctrl_sys;
        end generate trig_in_gen;

        -- data-bits
        data_in_gen : if TRIGGER or ICE_REGS generate
          signal data_sys     : std_logic_vector(DATA_BITS-1 downto 0);
          signal ice_data     : std_logic_vector(DATA_BITS-1 downto 0);
          signal trigger_data : std_logic_vector(DATA_BITS-1 downto 0);
        begin

          ice_gen : if ICE_REGS generate
            ice_data    <= fill(ice_regs_out_sys, DATA_BITS);
            trig_or_ice <= '0' when unsigned(ice_store_sys) /= 0 else '1';
          end generate ice_gen;

          no_ice_gen : if not ICE_REGS generate
            ice_data   <= (others => '0');
            trig_or_ice <= '1';
          end generate no_ice_gen;

          trig_gen : if TRIGGER generate
          begin

            trigger_data <= fill(trig_reg_sys, DATA_BITS-TRIG_REG_INDEX_BITS) & trig_reg_index_sys when trig_reg_set_sys = '1' else
                            fill(trig_val_sys, DATA_BITS-TRIG_REG_INDEX_BITS) & trig_reg_index_sys when trig_cmp_set_sys = '1' else
                            fill(trig_val_sys, DATA_BITS-TRIG_INDEX_BITS)     & trig_index_sys;

          end generate trig_gen;

          no_trig_gen : if not TRIGGER generate
            trigger_data <= (others => '0');
          end generate no_trig_gen;

          with trig_or_ice select
            data_sys <= trigger_data when '1',
                        ice_data     when others;

          s2t_fifo_din(DATA_INDEX+DATA_BITS-1 downto DATA_INDEX) <= data_sys;

        end generate data_in_gen;

        -- put value, when controll-bits are activ
        s2t_fifo_put <= '1' when unsigned(s2t_fifo_din(TRIG_CTRL_BITS+ICE_CTRL_BITS-1 downto 0)) /= 0
                            else '0';

        sys2trc_rdy <= not s2t_fifo_full;

        ------------------
        -- fifo-outputs --
        ------------------

        s2t_fifo_got <= '1';

        -- ice-register

        ice_out_gen : if ICE_REGS generate
          signal data : std_logic_vector(DATA_BITS-1 downto 0);
        begin

          data <= s2t_fifo_dout(SYS2TRC_BITS-1 downto ICE_CTRL_BITS+TRIG_CTRL_BITS);

          ice_store <= s2t_fifo_dout(ICE_CTRL_BITS-1 downto 0) and (ICE_CTRL_BITS-1 downto 0 => s2t_fifo_valid);

          reg_out_gen : for i in 0 to ICE_REGISTERS'length-1 generate
            cond_gen : if ICE_REGISTERS(i) > 0 generate
              constant INDEX    : natural := sum(ICE_REGISTERS, i);
              constant REG_BITS : natural := ICE_REGISTERS(i);
            begin
              ice_regs_out(INDEX+REG_BITS-1 downto INDEX) <= data(REG_BITS-1 downto 0);
            end generate cond_gen;
          end generate reg_out_gen;

        end generate ice_out_gen;

        trigger_out_gen : if TRIGGER generate
          signal trig_reg_index_slv : std_logic_vector(TRIG_REG_INDEX_BITS-1 downto 0);
          signal trig_index_slv     : std_logic_vector(TRIG_INDEX_BITS-1 downto 0);
          signal trig_activ_sel_slv : std_logic_vector(TRIG_ACTIV_BITS-1 downto 0);
          signal trig_cmp1_val_slv  : std_logic_vector(TRIG_CMP1_BITS-1 downto 0);
          signal trig_cmp2_val_slv  : std_logic_vector(TRIG_CMP2_BITS-1 downto 0);
          signal trig_mode_val_slv  : std_logic_vector(TRIG_MODE_BITS-1 downto 0);
          signal trig_type_val_slv  : std_logic_vector(TRIG_TYPE_BITS-1 downto 0);
        begin
          trig_reg_set       <= s2t_fifo_dout(ICE_CTRL_BITS+0) and s2t_fifo_valid;
          trig_cmp_set       <= s2t_fifo_dout(ICE_CTRL_BITS+1) and s2t_fifo_valid;
          trig_mode_set      <= s2t_fifo_dout(ICE_CTRL_BITS+2) and s2t_fifo_valid;
          trig_type_set      <= s2t_fifo_dout(ICE_CTRL_BITS+3) and s2t_fifo_valid;
          trig_activ_set     <= s2t_fifo_dout(ICE_CTRL_BITS+4) and s2t_fifo_valid;
          trig_reg_index_slv <= s2t_fifo_dout(DATA_INDEX+TRIG_REG_INDEX_BITS-1 downto DATA_INDEX);
          trig_reg_val       <= s2t_fifo_dout(DATA_INDEX+TRIG_REG_INDEX_BITS+TRIG_MAX_REG_BITS-1 downto DATA_INDEX+TRIG_REG_INDEX_BITS);
          trig_cmp1_val_slv  <= s2t_fifo_dout(DATA_INDEX+TRIG_REG_INDEX_BITS+TRIG_CMP1_BITS-1 downto DATA_INDEX+TRIG_REG_INDEX_BITS);
          trig_cmp2_val_slv  <= s2t_fifo_dout(DATA_INDEX+TRIG_REG_INDEX_BITS+TRIG_CMP2_BITS-1 downto DATA_INDEX+TRIG_REG_INDEX_BITS);
          trig_index_slv     <= s2t_fifo_dout(DATA_INDEX+TRIG_INDEX_BITS-1 downto DATA_INDEX);
          trig_mode_val_slv  <= s2t_fifo_dout(DATA_INDEX+TRIG_INDEX_BITS+TRIG_MODE_BITS-1 downto DATA_INDEX+TRIG_INDEX_BITS);
          trig_type_val_slv  <= s2t_fifo_dout(DATA_INDEX+TRIG_INDEX_BITS+TRIG_TYPE_BITS-1 downto DATA_INDEX+TRIG_INDEX_BITS);
          trig_activ_sel_slv <= s2t_fifo_dout(DATA_INDEX+TRIG_INDEX_BITS+TRIG_ACTIV_BITS-1 downto DATA_INDEX+TRIG_INDEX_BITS);

          trig_cmp1_val  <= getTriggerCmp1Value(to_integer(unsigned(trig_cmp1_val_slv)));
          trig_cmp2_val  <= getTriggerCmp2Value(to_integer(unsigned(trig_cmp2_val_slv)));
          trig_mode_val  <= getTriggerModeValue(to_integer(unsigned(trig_mode_val_slv)));
          trig_type_val  <= getTriggerTypeValue(to_integer(unsigned(trig_type_val_slv)));
          trig_reg_index <= unsigned(trig_reg_index_slv);
          trig_index     <= unsigned(trig_index_slv);
          trig_activ_sel <= unsigned(trig_activ_sel_slv);

        end generate trigger_out_gen;

      end generate fifo_gen;

      no_fifo_gen : if SYS2TRC_BITS = 0 generate
        sys2trc_rdy <= '1';
      end generate no_fifo_gen;

      no_trigger_out_gen : if not TRIGGER generate
        trig_reg_set   <= '0';
        trig_cmp_set   <= '0';
        trig_mode_set  <= '0';
        trig_type_set  <= '0';
        trig_activ_set <= '0';
        trig_reg_index <= (others => '-');
        trig_reg_val   <= (others => '-');
        trig_cmp1_val  <= getTriggerCmp1Value(0);
        trig_cmp2_val  <= getTriggerCmp2Value(0);
        trig_mode_val  <= getTriggerModeValue(0);
        trig_type_val  <= getTriggerTypeValue(0);
        trig_index     <= (others => '-');
        trig_activ_sel <= (others => '-');
      end generate no_trigger_out_gen;

      no_ice_out_gen : if not ICE_REGS generate
        ice_store    <= (others => '0');
        ice_regs_out <= (others => '-');
      end generate no_ice_out_gen;

    end block sys2trc_blk;

  end block cmd_block;

  st_stb <= st_stb_trig or st_stb_ov or st_stb_finish;

  --------------------
  -- Trigger-Inform --
  --------------------
  trigger_inform_gen : if TRIGGER_INFORM and TRIGGER_CNT > 0 generate
    constant INDEX : natural := TRACER_CNT*2+2+ifThenElse(CYCLE_ACCURATE,1, 0);
  begin
    st_msg(TRIGGER_OUT_BITS+INDEX-1 downto INDEX) <= trig_fired;
    st_stb_trig                                   <= trig_fired_stb;
  end generate trigger_inform_gen;

  no_trigger_inform_gen : if not TRIGGER_INFORM or TRIGGER_CNT = 0 generate
    st_stb_trig <= '0';
  end generate no_trigger_inform_gen;

  -----------------------
  -- Overflow-Reaction --
  -----------------------

  ov_blk : block
    signal ov_bit        : std_logic;
    signal ov_start_bit  : std_logic;
    signal ov_stop_bit   : std_logic;
    signal ov_danger_bit : std_logic;
  begin

    ov_bit <= '1' when unsigned(tracer_ovs) /= 0 else '0';

    ov_danger_bit <= '1' when unsigned(tracer_ov_dangers) /= 0
                           or global_time_ov_danger = '1'
                           or tracer_time_ov_danger = '1'
                         else '0';

    ov_start_bit <= '1' when unsigned(tracer_ov_starts) /= 0 else '0';
    ov_stop_bit  <= '1' when unsigned(tracer_ov_stops) /= 0 else '0';

    -- send message to host-pc

    st_stb_ov <= ov_start_bit or ov_stop_bit or tracer_time_ov_stop or global_time_ov_stop;

    st_msg(TRACER_CNT*2 downto 1) <= tracer_ov_starts & tracer_ov_stops;

    st_msg(TRACER_CNT*2+1) <= tracer_time_ov_stop;

    cyc_acc_gen : if CYCLE_ACCURATE generate
      st_msg(TRACER_CNT*2+2) <= global_time_ov_stop;
    end generate cyc_acc_gen;

    -- overflow-danger
    filter_data_gen : if OV_DANGER_REACTION = FilterDataTrace generate
    begin

      filter_adr <= ov_danger_bit;

      filter_interval_gen : if FILTER_INTERVAL > 0 generate
        signal reaction_cnt  : unsigned(log2ceil(FILTER_INTERVAL+1)-1 downto 0) := (others => '0');
        signal reaction_inc  : std_logic;
        signal reaction_rst  : std_logic;
        signal filter_data_i : std_logic;
      begin

        clk_proc : process(clk_trc)
        begin
          if rising_edge(clk_trc) then
            if rst_trc = '1' or reaction_rst = '1' then
              reaction_cnt <= (others => '0');
            elsif reaction_inc = '1' then
              reaction_cnt <= reaction_cnt + 1;
            end if;
          end if;
        end process clk_proc;

        reaction_inc <= not filter_data_i and ov_danger_bit;
        reaction_rst <= not ov_danger_bit;

        filter_data_i <= '1' when reaction_cnt = to_unsigned(FILTER_INTERVAL, reaction_cnt'length) else '0';

        filter_data <= filter_data_i;

      end generate filter_interval_gen;

      no_filter_interval_gen : if FILTER_INTERVAL = 0 generate
        filter_data <= ov_danger_bit;
      end generate;

      cpu_stop_ov  <= '0';
      cpu_start_ov <= '0';

    end generate filter_data_gen;

    system_stall_gen : if OV_DANGER_REACTION = SystemStall generate
      filter_data <= '0';
      filter_adr  <= '0';

      cpu_stop_ov  <= ov_danger_bit;
      cpu_start_ov <= not ov_danger_bit;
    end generate system_stall_gen;

    none_gen : if OV_DANGER_REACTION = None generate
      filter_data  <= '0';
      filter_adr   <= '0';
      cpu_stop_ov  <= '0';
      cpu_start_ov <= '0';
    end generate;

    -- resync

    resync_gen : if DO_RESYNC generate
      signal resync_delay : std_logic;
      signal resync_r     : std_logic;
    begin

      resync_delay <= (ov_stop_bit or global_time_ov_stop or tracer_time_ov_stop) and not ov_bit;
      resync       <= resync_r;

      clk_proc : process(clk_trc)
      begin
         if rising_edge(clk_trc) then
          resync_r <= resync_delay;
        end if;
      end process clk_proc;

    end generate resync_gen;

    no_resync_gen : if not DO_RESYNC generate
      resync <= '-';
    end generate;

  end block ov_blk;

  ----------------------------------------
  -- Send finish-message through tracer --
  ----------------------------------------

  finish_blk : block
    signal trace_running_p1  : std_logic;

    -- sending 7 stop-messages should be enough
    signal finish_cnt_r : unsigned(2 downto 0);
    signal send_finish  : std_logic;
  begin

    process (clk_trc)
    begin  -- process
      if rising_edge(clk_trc) then
        if rst_trc = '1' then
          trace_running_p1 <= '0';
          finish_cnt_r     <= (others => '0');
        else
          trace_running_p1 <= trace_running_trc;

          if (trace_running_p1 and not trace_running_trc) = '1' then
            -- start counting when tracing is stopped
            finish_cnt_r <= (others => '1');
          elsif send_finish = '1' then
            -- decrement until zero is reached
            finish_cnt_r <= finish_cnt_r - 1;
          end if;
        end if;
      end if;
    end process;

    send_finish <= '1' when finish_cnt_r /= 0 else '0';
    
    st_msg(0)     <= send_finish;
    st_stb_finish <= send_finish;

  end block finish_blk;

  ------------------------------------
  -- Multiplex data and ctrl-packets
  -- clk_sys-domain
  ------------------------------------

  sendmux: trace_sendmux
    generic map (
      MIN_DATA_PACKET_SIZE => MIN_DATA_PACKET_SIZE)
    port map (
      clk             => clk_sys,
      rst             => rst_sys,
      data_fifo_clear => send_data_fifo_clear,
      data_fifo_put   => send_data_fifo_put,
      data_fifo_din   => send_data_fifo_din,
      data_fifo_full  => send_data_fifo_full,
      data_fifo_empty => send_data_fifo_empty,
      ctrl_valid      => eth_valid_cmd,
      ctrl_data       => eth_dout_cmd,
      ctrl_last       => eth_last_cmd,
      ctrl_got        => eth_got_cmd,
      eth_valid       => eth_valid,
      eth_last        => eth_last,
      eth_dout        => eth_dout,
      eth_got         => eth_got,
      eth_finish      => eth_finish,
      header          => header);

  ------------
  -- Funnel --
  ------------

  funnel_blk : block

    constant VALUE_BITS : positive := max(TRACER_DATA_BITS)+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0);

    signal current_level : unsigned(log2ceilnz(TIME_CMP_LEVELS)-1 downto 0);
    signal current_time  : std_logic_vector(TIME_BITS-1 downto 0);

    signal no_data    : std_logic;
    signal done_level : std_logic;

    signal tracer_valid          : std_logic;
    signal current_tracer        : unsigned(log2ceilnz(TRACER_CNT)-1 downto 0);
    signal first_tracer_in_level : std_logic;
    signal last_tracer_in_level  : std_logic;
    signal done_tracer           : std_logic;
    signal tracer_time_valid     : std_logic;
    signal tracer_time_stb_en    : std_logic;
    signal global_time_stb_en    : std_logic;
    signal tracer_sel_i          : std_logic_vector(TRACER_CNT-1 downto 0);

    signal next_value       : std_logic_vector(VALUE_BITS-1 downto 0);
    signal next_value_fill  : unsigned(log2ceil(VALUE_BITS)-1 downto 0);
    signal next_value_got   : std_logic;
    signal next_value_valid : std_logic;
  begin

    -- Check if selected tracer already delivers data
    tracer_valid <= '1' when tracer_time_valid = '1'
                         and unsigned(not tracer_data_valid and tracer_sel_i) = 0
                        else '0';

    -----------------
    -- global_time --
    -----------------

    cyc_acc_gen : if CYCLE_ACCURATE generate
      signal global_time_valid  : std_logic;
      signal global_time_stb    : std_logic;

      signal enable    : std_logic;
      signal enabled_r : unsigned(2 downto 0);
      signal disable   : std_logic;
    begin

      global_time_inst : trace_global_time
        generic map (
          TIME_BITS                 => TIME_BITS,
          TIME_CMP_LEVELS           => TIME_CMP_LEVELS,
          GLOBAL_TIME_SAFE_DISTANCE => GLOBAL_TIME_SAFE_DISTANCE,
          GLOBAL_TIME_FIFO_DEPTH    => GLOBAL_TIME_FIFO_DEPTH
          )
        port map (
          clk_trc       => clk_trc,
          rst_trc       => rst_trc,
          clk_sys       => clk_sys,
          rst_sys       => rst_sys,
          enable        => enable,
          ov_stop       => global_time_ov_stop,
          ov_danger     => global_time_ov_danger,
          tracer_stb    => global_time_stb,
          stb_en        => global_time_stb_en,
          current_level => current_level,
          current_time  => current_time,
          no_data       => no_data,
          done_level    => done_level,
          valid_out     => global_time_valid
        );

      -- It takes some time, before stop-message are strobed.
      -- So keep global_time enabled after trace_running goes low.
      process (clk_trc)
      begin  -- process
        if rising_edge(clk_trc) then
          if rst_trc = '1' then
            enabled_r <= (others => '0');
          elsif trace_running_trc = '1' then
            -- manual enable
            enabled_r <= (others => '1');
          elsif disable = '0' then
            -- auto disable after some time
            -- strobes from ctrl-message-tracer is checked below.
            enabled_r <= enabled_r - 1;
          end if;
        end if;
      end process;

      disable <= '1' when enabled_r = 0 else '0';
      
      -- Enable immediatly with trace_running.
      -- Hold enable also while ctrl-message-tracer is strobing stop-messages.
      -- Do not use trace_working, it is in the wrong clock domain.
      enable <= (not disable) or
                trace_running_trc or tracer_stbs(TRACER_CNT-1);
      
      tracer_stb_en    <= global_time_stb_en and tracer_time_stb_en;
      tracer_valid2    <= global_time_valid and (no_data or tracer_valid);
      trace_working    <= global_time_valid or tracer_time_valid;
      
      global_time_stb  <= '1' when tracer_time_stb_en = '1' and unsigned(tracer_stbs) /= 0
                              else '0';

    end generate cyc_acc_gen;

    no_cyc_acc_gen : if not CYCLE_ACCURATE generate
      tracer_stb_en         <= tracer_time_stb_en;
      tracer_valid2         <= tracer_valid;
      trace_working         <= tracer_time_valid;
      global_time_ov_stop   <= '0';
      global_time_ov_danger <= '0';
      global_time_stb_en    <= '1';
      no_data               <= not tracer_time_valid;
      current_time          <= (others => '0');
      current_level         <= (others => '0');
    end generate no_cyc_acc_gen;
    
    -----------------
    -- tracer_time --
    -----------------

    tracer_time_inst : trace_tracer_time
      generic map (
        TRACER                    => TRACER_CNT,
        TRACER_TIME_SAFE_DISTANCE => TRACER_TIME_SAFE_DISTANCE,
        TRACER_TIME_FIFO_DEPTH    => TRACER_TIME_FIFO_DEPTH
      )
      port map (
        clk_trc               => clk_trc,
        rst_trc               => rst_trc,
        clk_sys               => clk_sys,
        rst_sys               => rst_sys,
        tracer_stbs           => tracer_stbs,
        tracer_data_se        => tracer_data_se,
        tracer_sel            => tracer_sel_i,
        stb_en_in             => global_time_stb_en,
        stb_en_out            => tracer_time_stb_en,
        ov_stop               => tracer_time_ov_stop,
        ov_danger             => tracer_time_ov_danger,
        done_tracer           => done_tracer,
        current_tracer        => current_tracer,
        first_tracer_in_level => first_tracer_in_level,
        last_tracer_in_level  => last_tracer_in_level,
        valid_out             => tracer_time_valid
      );

    tracer_sel <= tracer_sel_i;

    ------------------
    -- Value select --
    ------------------

    value_sel_inst : trace_value_sel
      generic map (
        CYCLE_ACCURATE   => CYCLE_ACCURATE,
        TRACER_CNT       => TRACER_CNT,
        TRACER_DATA_BITS => TRACER_DATA_BITS,
        TIME_CMP_LEVELS  => TIME_CMP_LEVELS,
        TIME_BITS        => TIME_BITS
        )
      port map (
        clk_sys               => clk_sys,
        rst_sys               => trace_init,
        valid_in              => tracer_valid2,
        tracer_data           => tracer_data,
        tracer_data_fill      => tracer_data_fill,
        tracer_data_last      => tracer_data_last,
        tracer_data_got       => tracer_data_got,
        current_tracer        => current_tracer,
        first_tracer_in_level => first_tracer_in_level,
        last_tracer_in_level  => last_tracer_in_level,
        done_tracer           => done_tracer,
        current_level         => current_level,
        current_time          => current_time,
        no_data               => no_data,
        done_level            => done_level,
        next_value            => next_value,
        next_value_fill       => next_value_fill,
        next_value_got        => next_value_got,
        next_value_valid      => next_value_valid
        );

    --------------------
    -- Values to fifo --
    --------------------

    value_2fifo_inst : trace_value_2fifo
      generic map (
        BLOCK_BITS => 1,
        IN_BLOCKS  => VALUE_BITS,
        OUT_BLOCKS => 8
        )
      port map (
        clk            => clk_sys,
        rst            => trace_init,
        in_value_got   => next_value_got,
        in_value       => next_value,
        in_value_fill  => next_value_fill,
        in_value_valid => next_value_valid,
        fifo_dat       => send_data_fifo_din,
        fifo_put       => send_data_fifo_put,
        fifo_full      => send_data_fifo_full
        );

  end block funnel_blk;

end Behavioral;
