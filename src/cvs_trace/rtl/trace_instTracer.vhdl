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
-- Entity: trace_instTracer
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- Instruction Tracer                               --
--                                                  --
-- data_fill is number of valid bits minus 1        --
--
-- Branch-Coding:
-- --------------
-- 000 No Change in program flow
-- 010 Direct Branch Not Taken
-- 011 Direct Branch Taken
-- 100 Indirect Branch Not Taken
-- 101 Indirect Branch Taken or Exception
--
-- Trace Interpretation:
-- ---------------------
-- For each trigger interval the following messages are sent:
-- a) If center- oder post-trigger: all messages stored in the FIFO before the
--    trigger event.
-- b) After sending is enabled, the first new instruction (strobe) always
--    generates a "first" message. This also resyncs compression.
-- c) Messages when branches or overflows occur.
--    (depends on selected compression)
-- d) The "last message" denoting the state at the time sending is disabled.
--
-- The instruction count specifies the count of sequential instructions since
-- the previous message. This count includes the instruction (e.g. branch)
-- which triggered the previous message.
--
-- Normally, messages are generated only if a new instruction is strobed. The
-- instruction count MSB of these messages is always zero.
--
-- When sending is disabled, a "last message" is sent to signal the end of the
-- instruction sequence. This message is always send regardless if a new
-- instrcution is strobed or not. To identify this special message, the
-- instrcution count MSB is one. The lower counter bits specifying the
-- sequential instructions so far as usual.
--
-- If two "last messages" are occur consecutive inside the trace, then no
-- instruction was strobed while sending was enabled (e.g. processor pipeline
-- stall).
--
-- An instruction count of zero may only occur in the overall first message.
--
-- The highest '1' in the history field is a start marker. All following lower
-- bits (if any), from higher to lower, denote if branch has taken ('1') or not
-- ('0').
------------------------------------------------------
--
-- Revision:    $Revision: 1.15 $
-- Last change: $Date: 2010-04-30 14:38:06 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_types.all;
use poc.trace_functions.all;
use poc.trace_internals.all;

entity trace_instTracer is
  generic (
    ADR_PORT      : tPort;
    BRANCH_INFO   : boolean;
    COUNTER_BITS  : positive;
    HISTORY_BYTES : natural;
    LS_ENCODING   : boolean;
    FIFO_DEPTH    : positive;
    FIFO_SDS      : positive;
    CODING        : boolean;
    CODING_VAL    : std_logic_vector;
    TIME_BITS     : natural
  );
  port (
    clk_trc : in std_logic;
    rst_trc : in std_logic;
    clk_sys : in std_logic;
    rst_sys : in std_logic;

    -- port-interface (clk-trc-domain)
    adr     : in  std_logic_vector(ADR_PORT.WIDTH-1 downto 0);
    adr_stb : in  std_logic;
    branch  : in  std_logic_vector(ifThenElse(BRANCH_INFO, 2, 0) downto 0);
    stb_out : out std_logic;

    -- controller-output (clk-sys-domain)
    data_out   : out std_logic_vector(getInstDataOutBits(ADR_PORT, BRANCH_INFO, COUNTER_BITS, HISTORY_BYTES,
                                                         ifThenElse(CODING, CODING_VAL'length, 0),
                                                         TIME_BITS)-1 downto 0);
    data_got   : in  std_logic;
    data_fill  : out unsigned(log2ceilnz(getInstDataOutBits(ADR_PORT, BRANCH_INFO, COUNTER_BITS, HISTORY_BYTES,
                                                             ifThenElse(CODING, CODING_VAL'length, 0),
                                                             TIME_BITS))-1 downto 0);
    data_last  : out std_logic;
    data_se    : out std_logic;
    data_valid : out std_logic;
    sel       : in  std_logic;

    -- enable-interface (clk-trc-domain)
    trc_enable  : in std_logic;
    stb_enable  : in std_logic;
    send_enable : in std_logic;

    -- overflow-interface (clk-trc-domain)
    ov        : out std_logic;
    ov_start  : out std_logic;
    ov_stop   : out std_logic;
    ov_danger : out std_logic
    );
end trace_instTracer;

architecture Behavioral of trace_instTracer is

  constant MSG_BITS                : natural  := ifThenElse(BRANCH_INFO, HISTORY_BYTES*8, 0) +
                                                 COUNTER_BITS + ADR_PORT.WIDTH;
  constant CODING_BITS             : natural  := ifThenElse(CODING, CODING_VAL'length, 0);
  constant HEADER_VAL_BITS         : natural  := getTracerHeaderValBits(ADR_PORT) +
                                                 ifThenElse(BRANCH_INFO, HISTORY_BYTES*8, 0) +
                                                 COUNTER_BITS;
  constant HEADER_LEN_BITS         : natural  := getTracerHeaderLenBits(ADR_PORT);
  constant HEADER_BITS             : positive := HEADER_VAL_BITS + HEADER_LEN_BITS;
  constant CODING_AND_HEADER_BITS  : positive := CODING_BITS + HEADER_BITS;
  constant CODING_AND_HEADER_BYTES : positive := getBytesUp(CODING_AND_HEADER_BITS);
  constant VAR_VAL_BYTES           : natural  := getTracerVarValBytes(ADR_PORT);
  constant VAR_VAL                 : boolean  := VAR_VAL_BYTES > 0;
  constant DATA_OUT_BITS           : positive := getInstDataOutBits(ADR_PORT, BRANCH_INFO, COUNTER_BITS, HISTORY_BYTES,
                                                                    ifThenElse(CODING, CODING_VAL'length, 0),
                                                                    TIME_BITS);
  constant DATA_FILL_BITS          : positive := log2ceilnz(DATA_OUT_BITS);
  constant OUT_CH_STEPS            : positive := ifThenElse(CODING_AND_HEADER_BITS mod DATA_OUT_BITS > 0,
                                                           (CODING_AND_HEADER_BITS / DATA_OUT_BITS)+1,
                                                            CODING_AND_HEADER_BITS / DATA_OUT_BITS);
  constant OUT_STEPS               : positive := OUT_CH_STEPS + VAR_VAL_BYTES;
  constant SEND_FIRST_BITS         : positive := ifThenElse(CODING_AND_HEADER_BITS mod DATA_OUT_BITS = 0,
                                                            DATA_OUT_BITS,
                                                            CODING_AND_HEADER_BITS mod DATA_OUT_BITS);
  constant OUT_WIDTHS              : tNat_array
                                   := SEND_FIRST_BITS &
                                      ifThenElse(OUT_CH_STEPS > 1,
                                                (max(OUT_CH_STEPS,2)-2 downto 0 => DATA_OUT_BITS), (0,0)) &
                                      ifThenElse(VAR_VAL_BYTES > 0 , (notZero(VAR_VAL_BYTES)-1 downto 0 => 8), (0,0));

  -- clk-trc-domain-signals

  signal msg       : std_logic_vector(MSG_BITS-1 downto 0);
  signal msg_stb   : std_logic;
  signal last_stb  : std_logic;
  signal first_stb : std_logic;

  signal send_enable_r : std_logic := '0';
  signal do_first_r    : std_logic := '0';

  signal stb_tracing : std_logic;
  signal stb_fifordy : std_logic;
  signal stb_i       : std_logic;
  signal stb_en_nov  : std_logic;

  signal fifo_full       : std_logic;
  signal fifo_sd         : std_logic;
  signal fifo_sd_clk_trc : std_logic;

  -- MSB denotes "last message" and is not part of counter
  signal inst_cnt_ov  : std_logic;
  signal inst_cnt_r   : unsigned(COUNTER_BITS-2 downto 0) := (others => '0');

  -- clk-sys-domain-signals

  signal fifo_sd_clk_sys : std_logic;

  signal load_message    : std_logic;
  signal done_message    : std_logic;
  signal done_message_sd : std_logic;
  signal send_enabled    : std_logic;

  signal data_out_all : std_logic_vector(CODING_AND_HEADER_BITS+VAR_VAL_BYTES*8-1 downto 0);

  signal data_out_i   : std_logic_vector(DATA_OUT_BITS-1 downto 0);
  signal data_fill_i  : unsigned(DATA_FILL_BITS-1 downto 0);
  signal data_last_i  : std_logic;
  signal data_got_i   : std_logic;
  signal data_valid_i : std_logic;
  signal data_se_i    : std_logic;

  signal out_counter_r : unsigned(log2ceilnz(OUT_STEPS)-1 downto 0) := (others => '0');

begin

  assert FIFO_DEPTH > FIFO_SDS
    report "ERROR: Reduce safe-distance in instruction-tracer."
    severity error;

  assert not isNullPort(ADR_PORT)
    report "ERROR: No valid port in instruction-tracer."
    severity error;

  -- clk-trc-domain

  fifo_sd_clk_trc <= fifo_sd;

  stb_tracing <= (msg_stb and trc_enable) or last_stb;
  stb_fifordy <= stb_tracing and stb_en_nov;
  stb_i       <= stb_enable and stb_fifordy;
  stb_out     <= stb_fifordy and (send_enable or send_enable_r);

  -- overflow
  ov_blk : block
    signal ov_r        : std_logic := '0';
    signal ov_rst      : std_logic;
    signal ov_set      : std_logic;
    signal ov_danger_i : std_logic;
    signal ov_danger_r : std_logic := '0'; --register signal to prevent timing-error
  begin

    ov_rst <= not ov_danger_r;
    ov_set <= (stb_tracing and fifo_full);

    clk_proc : process(clk_trc)
    begin
      if rising_edge(clk_trc) then
        ov_danger_r <= ov_danger_i;
        if (rst_trc or ov_rst) = '1' then
          ov_r <= '0';
        elsif ov_set = '1' then
          ov_r <= '1';
        end if;
      end if;
    end process clk_proc;

    stb_en_nov <= not ov_r and not fifo_full;

    -- outputs
    ov          <= ov_r;
    ov_start    <= ov_set and not ov_r;
    ov_stop     <= ov_rst and ov_r;
    ov_danger_i <= fifo_sd_clk_trc;
    ov_danger   <= ov_danger_i;

  end block ov_blk;

  -- bring fifo_sd to clk_sys-domain

  sd_sync : trace_clk_sync
    port map (
      clk_dst   => clk_sys,
      value_in  => fifo_sd_clk_trc,     -- must be a registered value
      value_out => fifo_sd_clk_sys
  );

  -- send enable
  clk_se_proc : process(clk_trc)
  begin
    if rising_edge(clk_trc) then
      send_enable_r <= send_enable;

      if (rst_trc or adr_stb or not send_enable) = '1' then
        -- reset when new instruction arrives or sending is disabled
        do_first_r <= '0';
      elsif (send_enable and not send_enable_r) = '1' then
        -- wait for first instruction after sending is enabled
        -- except when new instruction arrives at the same time
        do_first_r <= '1';
      end if;
    end if;
  end process clk_se_proc;

  -- Always send a last message.
  last_stb  <= not send_enable and send_enable_r;
  first_stb <= adr_stb and ((do_first_r and send_enable)
                            or (send_enable and not send_enable_r));

  ------------------------
  -- MESSAGE-GENERATION --
  ------------------------

  clk_proc : process(clk_trc)
  begin
    if rising_edge(clk_trc) then
      if (rst_trc or msg_stb) = '1' then
        -- reset counter when message has send
        -- if a instruction is strobed at this time, count this one
        inst_cnt_r    <= (others => '0');
        inst_cnt_r(0) <= adr_stb;
      elsif adr_stb = '1' then
        -- also count instructions between messages
        inst_cnt_r <= inst_cnt_r + 1;
      end if;
    end if;
  end process clk_proc;

  inst_cnt_ov <= '1' when inst_cnt_r = (COUNTER_BITS-2 downto 0 => '1') else '0';

  -----------------------------------
  -- NO BRANCH CHARACTERIZED-Trace --
  -----------------------------------
  no_branch_char_gen : if not BRANCH_INFO generate
    signal adr_branch : std_logic;
    signal last_adr_r : std_logic_vector(ADR_PORT.WIDTH-1 downto 0) := (others => '0');
  begin

    clk_proc : process(clk_trc)
    begin
      if rising_edge(clk_trc) then
        if rst_trc = '1' then
          last_adr_r <= (others => '0');
        elsif adr_stb = '1' then
          last_adr_r <= adr;
        end if;
      end if;
    end process clk_proc;

    adr_branch <= '1' when unsigned(adr) /= unsigned(last_adr_r) + 1 else '0';

    msg_stb <= (adr_stb and (adr_branch or inst_cnt_ov)) or first_stb or last_stb;
    msg     <= adr & last_stb & std_logic_vector(inst_cnt_r);

  end generate no_branch_char_gen;

  --------------------------------
  -- BRANCH CHARACTERIZED-Trace --
  --------------------------------

  branch_char_gen : if BRANCH_INFO generate
    signal direct_branch   : std_logic;
    signal branch_taken    : std_logic;
    signal indirect_branch : std_logic;
  begin

    direct_branch   <= branch(1);
    indirect_branch <= branch(2);
    branch_taken    <= branch(0);

    -- History
    history_gen : if HISTORY_BYTES > 0 generate
      signal history_msg : std_logic_vector(HISTORY_BYTES*8-1 downto 0);
      signal history_rst : std_logic;
      signal history_stb : std_logic;
      signal history_ov  : std_logic;

      signal indirect_change : std_logic;
    begin

      msg     <= adr & last_stb & std_logic_vector(inst_cnt_r) & history_msg;
      msg_stb <= (adr_stb and (inst_cnt_ov or history_ov or indirect_change))
                 or first_stb or last_stb;

      -- All taken branches except direct.
      indirect_change <= branch_taken and not direct_branch;

      -- Might be valid at the same time if a direct branch follows an
      -- instruction causing a message.
      history_rst <= msg_stb or rst_trc;
      history_stb <= adr_stb and direct_branch;

      -- Ls-Encoder
      ls_encoder_gen : if LS_ENCODING generate
      begin

        assert false
          report "LS_ENCODING for Instruction-Trace has not been verified yet."
          severity error;

        -- The LS-Encoder must support 'rst' and 'ie' at the same time.
        -- This has not been verified yet.
        ls_encoder_inst : trace_lsEncoder
          generic map (
            MESSAGE_BYTES => HISTORY_BYTES
          )
          port map (
            clk     => clk_trc,
            rst     => history_rst,
            ie      => history_stb,
            ev      => branch_taken,
            message => history_msg,
            oe      => history_ov
          );

      end generate ls_encoder_gen;

      -- No Ls-Encoder
      no_ls_encoder_gen : if not LS_ENCODING generate
        -- Init state must correspond to reset.
        signal history_r     : std_logic_vector(HISTORY_BYTES*8-1 downto 0)
          := (HISTORY_BYTES*8-1 downto 1 => '0') & '1';
      begin

        -- if history_r(MSB) = '1', then history is full.
        history_ov    <= history_stb and history_r(history_r'left);
        history_msg   <= history_r;

        clk_proc : process(clk_trc)
        begin
          if rising_edge(clk_trc) then
            if history_rst = '1' then
              -- also called when history is resetted due to overflow
              history_r <= (others => '0');
              if history_stb = '1' then
                -- also shift
                history_r(1 downto 0) <= '1' & branch_taken;
              else
                -- just init
                history_r(0) <= '1';
              end if;

            elsif history_stb = '1' then
              history_r <= history_r(history_r'left-1 downto 0) & branch_taken;
            end if;
          end if;
        end process clk_proc;

      end generate no_ls_encoder_gen;

    end generate history_gen;

    -- no History
    no_history_gen : if HISTORY_BYTES = 0 generate

      msg     <= adr & last_stb & std_logic_vector(inst_cnt_r);
      msg_stb <= (adr_stb and (branch_taken or inst_cnt_ov))
                 or first_stb or last_stb;

    end generate no_history_gen;

  end generate branch_char_gen;

  -------------------------------------------------------------
  -- implementation with minimal logic and more memory-usage --
  -------------------------------------------------------------

  main_blk : block

    constant FIFO_BITS : natural := MSG_BITS+1;

    -- clk-trc-domain-signals

    signal fifo_din : std_logic_vector(FIFO_BITS-1 downto 0);
    signal fifo_put : std_logic;

    -- clk-sys-domain-signals

    signal header_val   : std_logic_vector(HEADER_VAL_BITS-1 downto 0);
    signal header_out   : std_logic_vector(HEADER_BITS-1 downto 0);
    signal codingHeader : std_logic_vector(CODING_AND_HEADER_BITS-1 downto 0);

    signal fifo_got   : std_logic;
    signal fifo_dout  : std_logic_vector(FIFO_BITS-1 downto 0);
    signal fifo_valid : std_logic;

  begin

    fifo_inst : trace_fifo_ic
      generic map (
        D_BITS     => FIFO_BITS,
        MIN_DEPTH  => FIFO_DEPTH,
        THRESHOLD  => FIFO_SDS,
        OUTPUT_REG => false
      )
      port map (
        clk_wr => clk_trc,
        rst_wr => rst_trc,
        put    => fifo_put,
        din    => fifo_din,
        full   => fifo_full,
        thres  => fifo_sd,
        clk_rd => clk_sys,
        rst_rd => rst_sys,
        got    => fifo_got,
        valid  => fifo_valid,
        dout   => fifo_dout
     );

    --------------------
    -- clk-trc-domain --
    --------------------

    fifo_din <= (send_enable or send_enable_r) & msg;
    fifo_put <= stb_i;

    --------------------
    -- clk-sys-domain --
    --------------------

    fifo_got     <= load_message;
    send_enabled <= fifo_dout(FIFO_BITS-1);

    -- header-val

    header_val_gen : if HEADER_VAL_BITS > 0 generate
      header_val(HEADER_VAL_BITS-1 downto 0) <= fifo_dout(HEADER_VAL_BITS-1 downto 0);
    end generate header_val_gen;

    -- compression
    comp_gen : if haveCompression(ADR_PORT) generate

      constant COMP   : tComp    := ADR_PORT.COMP;
      constant LENGTH : natural  := log2ceil(VAR_VAL_BYTES+1);

      signal comp_in    : std_logic_vector(VAR_VAL_BYTES*8-1 downto 0);
      signal comp_stb   : std_logic;
      signal compress   : std_logic;
      signal length_i   : unsigned(HEADER_LEN_BITS-1 downto 0);
      signal length_r   : unsigned(HEADER_LEN_BITS-1 downto 0) := (others => '0');
      signal comp_out_i : std_logic_vector(VAR_VAL_BYTES*8-1 downto 0);
      signal comp_out_r : std_logic_vector(VAR_VAL_BYTES*8-1 downto 0) := (others => '0');
      signal header_val_r    : std_logic_vector(HEADER_VAL_BITS-1 downto 0) := (others => '0');
      signal valid_message_r : std_logic := '0';
      signal send_enabled_r  : std_logic := '0';

    begin

      -- TODO: Compression must be resetted when:
      -- - Every time a message is not transmitted. IMPORTANT!
      --   That is, compress only transmitted messages, except first one.
      -- - Tracing is (re-)started. Should be fixed together with above.
      -- - More cases?
      assert false
        report "Compression for trace messages does not work properly."
        severity error;

      comp_stb <= load_message;

      -- synchronisation

      sync_proc: process (clk_sys)
      begin  -- process sync_proc
        if rising_edge(clk_sys) then
          if rst_sys = '1' then
            compress <= '0';
          else
            -- compression is activated after first message with 'send_enabled'
            compress <= send_enabled;
          end if;
        end if;
      end process sync_proc;

      comp_in <= fifo_dout(HEADER_VAL_BITS+VAR_VAL_BYTES*8-1 downto HEADER_VAL_BITS);

      comp_inst : trace_compression
        generic map (
          NUM_BYTES   => VAR_VAL_BYTES,
          COMPRESSION => COMP
        )
        port map (
          clk      => clk_sys,
          rst      => rst_sys,
          data_in  => comp_in,
          ie       => comp_stb,
          compress => compress,
          len_mark => open,
          len      => length_i,
          data_out => comp_out_i
        );

      clk_proc : process(clk_sys)
      begin
        if rising_edge(clk_sys) then
          if rst_sys = '1' then
            valid_message_r <= '0';
            send_enabled_r  <= '0';
          elsif done_message = '1' or valid_message_r = '0' then
            comp_out_r      <= comp_out_i;
            header_val_r    <= header_val;
            length_r        <= length_i;
            valid_message_r <= fifo_valid;
            send_enabled_r  <= send_enabled;
          end if;
        end if;
      end process clk_proc;

      load_message <= (done_message or not valid_message_r) and fifo_valid;
      header_out   <= header_val_r & std_logic_vector(length_r);

      -- generate outputs for compressed values

      data_last_i  <= '1' when out_counter_r = OUT_CH_STEPS+fill(length_r, out_counter_r'length)-1 else '0';
      data_valid_i <= valid_message_r;
      data_se_i    <= send_enabled_r;

      data_out_all(CODING_AND_HEADER_BITS+VAR_VAL_BYTES*8-1 downto CODING_AND_HEADER_BITS) <= comp_out_r;
    end generate comp_gen;

    -- no compression

    no_comp_gen : if not haveCompression(ADR_PORT) generate
      header_out   <= header_val;
      load_message <= done_message;
      data_se_i    <= send_enabled;
      data_last_i  <= '1' when out_counter_r = OUT_CH_STEPS-1 else '0';
      data_valid_i <= fifo_valid;
    end generate no_comp_gen;

    -- coding

    coding_gen : if CODING generate
      codingHeader <= header_out & CODING_VAL;
    end generate coding_gen;

    no_coding_gen : if not CODING generate
      codingHeader <= header_out;
    end generate no_coding_gen;

    data_out_all(CODING_AND_HEADER_BITS-1 downto 0) <= codingHeader;

  end block main_blk;

  -------------
  -- Outputs --
  -------------

  out_blk : block

    signal out_counter_set : std_logic;
    signal out_counter_rst : std_logic;

  begin

    clk_proc : process(clk_sys)
    begin
      if rising_edge(clk_sys) then
        if rst_sys = '1' or out_counter_rst = '1' then
          out_counter_r <= (others => '0');
        elsif out_counter_set = '1' then
          out_counter_r <= out_counter_r + 1;
        end if;
      end if;
    end process clk_proc;

    data_out_multiplex : trace_multiplex
      generic map (
        DATA_BITS => OUT_WIDTHS,
        IMPL      => false
      )
      port map (
        inputs => data_out_all,
        sel    => out_counter_r,
        output => data_out_i(max(OUT_WIDTHS)-1 downto 0)
      );

    data_fill_i <= to_unsigned(DATA_OUT_BITS-1, DATA_FILL_BITS) when out_counter_r > 0 and out_counter_r < OUT_CH_STEPS else
                   to_unsigned(7, DATA_FILL_BITS)               when out_counter_r >= OUT_CH_STEPS else
                   to_unsigned(SEND_FIRST_BITS-1, DATA_FILL_BITS);

    done_message_sd <= not data_se_i and not sel and fifo_sd_clk_sys;

    done_message <= (data_got_i and data_last_i) or done_message_sd;

    out_counter_rst <= done_message;
    out_counter_set <= data_got_i;

    data_got_i <= data_got;

    data_fill  <= data_fill_i;
    data_last  <= data_last_i;
    data_out   <= data_out_i;
    data_valid <= data_valid_i;
    data_se    <= data_se_i;

  end block out_blk;
end Behavioral;
