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
-- Entity: trace_memTracer
-- Author(s): Stefan Alex
-- 
------------------------------------------------------
-- Memory Tracer                                    --
--                                                  --
-- data_fill is number of valid bits minus 1        --
------------------------------------------------------
--
-- Revision:    $Revision: 1.6 $
-- Last change: $Date: 2010-04-30 14:37:52 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_types.all;
use poc.trace_functions.all;
use poc.trace_internals.all;
use poc.trace_config.all;

entity trace_memTracer is
  generic (
    ADR_PORTS   : tPorts;
    DATA_PORT   : tPort;
    SOURCE_BITS : natural;
    COLLECT_VAL : boolean;
    FIFO_DEPTH  : positive;
    FIFO_SDS    : positive;
    CODING      : boolean;
    CODING_VAL  : std_logic_vector;
    TIME_BITS   : natural
  );
  port (
    clk_trc : in std_logic;
    clk_sys : in std_logic;
    rst_trc : in std_logic;
    rst_sys : in std_logic;

    -- port-interface (clk-trc-domain)
    adr      : in std_logic_vector(sumWidths(ADR_PORTS)-1 downto 0);
    adr_stbs : in std_logic_vector(countPorts(ADR_PORTS)-1 downto 0);
    data     : in std_logic_vector(DATA_PORT.WIDTH-1 downto 0);
    data_stb : in std_logic;
    src      : in std_logic_vector(notZero(SOURCE_BITS)-1 downto 0);
    rw       : in std_logic;

    stb_out : out std_logic;

    -- controller-output (clk-sys-domain)
    data_out   : out std_logic_vector(getMemDataOutBits(ADR_PORTS, DATA_PORT, SOURCE_BITS,
                                                        ifThenElse(CODING, CODING_VAL'length, 0),
                                                        TIME_BITS)-1 downto 0);
    data_got   : in  std_logic;
    data_fill  : out unsigned(log2ceilnz(getMemDataOutBits(ADR_PORTS, DATA_PORT, SOURCE_BITS,
                                                           ifThenElse(CODING, CODING_VAL'length, 0),
                                                           TIME_BITS))-1 downto 0);
    data_last  : out std_logic;
    data_se    : out std_logic;
    data_valid : out std_logic;
    sel        : in  std_logic;

    -- enable-interface (clk-trc-domain)
    trc_enable  : in std_logic;
    stb_enable  : in std_logic;
    send_enable : in std_logic;

    -- overflow-interface (clk-trc-domain)
    ov        : out std_logic;
    ov_start  : out std_logic;
    ov_stop   : out std_logic;
    ov_danger : out std_logic;

    adr_en   : in std_logic;
    data_en  : in std_logic
    );
end trace_memTracer;

architecture Behavioral of trace_memTracer is

  constant COMPRESSION     : boolean  := haveCompression(ADR_PORTS) or haveCompression(DATA_PORT);
  constant ADR_PORT_CNT    : natural  := countPorts(ADR_PORTS);
  constant PORT_CNT        : natural  := ADR_PORT_CNT + 1;
  constant LAST_ADR_BITS   : positive := ADR_PORTS(ADR_PORT_CNT-1).WIDTH;
  constant LAST_ADR_INDEX  : natural  := sumWidths(ADR_PORTS, ADR_PORT_CNT-1);
  constant LAST_ADR_PORT   : tPort    := ADR_PORTS(ADR_PORT_CNT-1);
  constant CODING_BITS     : natural  := ifThenElse(CODING, CODING_VAL'length, 0);
  constant ID_BITS         : positive := log2ceilnz(PORT_CNT+1);
  constant FIFO_VALUE_BITS : positive := max(getMaxPortWidth(ADR_PORTS),
                                             DATA_PORT.WIDTH+LAST_ADR_BITS+1);
  constant DATA_OUT_BITS   : positive := getMemDataOutBits(ADR_PORTS, DATA_PORT, SOURCE_BITS,
                                                           ifThenElse(CODING, CODING_VAL'length, 0),
                                                           TIME_BITS);
  constant DATA_FILL_BITS  : positive := log2ceilnz(DATA_OUT_BITS);
  constant OUT_CHOISES     : natural  := ADR_PORT_CNT + 2;

  function getMaxOutSteps return positive is
    variable result : positive := 1;
    variable tmp    : natural;
    variable ch     : natural;
    variable vv     : natural;
    variable dob    : natural;
  begin
    if ADR_PORT_CNT > 1 then
      for i in 0 to ADR_PORT_CNT-2 loop
        tmp := getTracerHeaderBits(ADR_PORTS(i))+ID_BITS+SOURCE_BITS+CODING_BITS;
        dob := getTracerDataOutBits(tmp, haveCompression(ADR_PORTS(i)), TIME_BITS);
        if tmp mod dob = 0 then
          ch := (tmp / dob);
        else
          ch := (tmp / dob) + 1;
        end if;
        vv := getTracerVarValBytes(ADR_PORTS(i));
        result := max(result, ch+vv);
      end loop;
    end if;

    tmp := getTracerHeaderBits(ADR_PORTS(ADR_PORT_CNT-1))+getTracerHeaderBits(DATA_PORT)+ID_BITS+
                                                          SOURCE_BITS+1+CODING_BITS;
    dob := getTracerDataOutBits(tmp, haveCompression(ADR_PORTS(ADR_PORT_CNT-1)) or haveCompression(DATA_PORT), TIME_BITS);
    if tmp mod dob = 0 then
      ch := tmp / dob;
    else
      ch := (tmp / dob) + 1;
    end if;
    vv := getTracerVarValBytes(ADR_PORTS(ADR_PORT_CNT-1)) + getTracerVarValBytes(DATA_PORT);
    result := max(result, ch+vv);

    return result;

  end function getMaxOutSteps;

  constant OUT_STEPS : positive := getMaxOutSteps;

  -- clk-trc-domain-signals

  signal last_adr     : std_logic_vector(LAST_ADR_BITS-1 downto 0);
  signal last_adr_stb : std_logic;
  signal last_adr_rw  : std_logic;

  signal adr_stbs_enabled : std_logic_vector(ADR_PORT_CNT-1 downto 0);
  signal data_stb_enabled : std_logic;
  signal adr_stbs_tracing : std_logic_vector(ADR_PORT_CNT-1 downto 0);
  signal data_stb_tracing : std_logic;
  signal stb_tracing      : std_logic;
  signal stb_fifordy      : std_logic;
  signal stb_i            : std_logic;
  signal stb_en_nov       : std_logic;

  signal fifo_full       : std_logic;
  signal fifo_sd         : std_logic;
  signal fifo_sd_clk_trc : std_logic;

  signal trc_id_in     : unsigned(ID_BITS-1 downto 0);
  signal trc_value_in  : std_logic_vector(FIFO_VALUE_BITS-1 downto 0);

  -- clk-sys-domain-signals

  signal trc_id_out : unsigned(ID_BITS-1 downto 0);

  signal fifo_sd_clk_sys : std_logic;

  signal load_message    : std_logic;
  signal done_message    : std_logic;
  signal done_message_sd : std_logic;
  signal valid_message   : std_logic;
  signal send_enabled    : std_logic;

  type tAllDataOut is array(natural range <>) of std_logic_vector(DATA_OUT_BITS-1 downto 0);
  type tAllDataFill is array(natural range <>) of unsigned(DATA_FILL_BITS-1 downto 0);
  signal all_data_out   : tAllDataOut(OUT_CHOISES-1 downto 0);
  signal all_data_fill  : tAllDataFill(OUT_CHOISES-1 downto 0);
  signal all_data_last  : std_logic_vector(OUT_CHOISES-1 downto 0);

  signal out_counter_r   : unsigned(log2ceil(OUT_STEPS)-1 downto 0) := (others => '0');
  signal out_counter_nxt : unsigned(log2ceil(OUT_STEPS)-1 downto 0);

  signal data_out_i   : std_logic_vector(DATA_OUT_BITS-1 downto 0);
  signal data_fill_i  : unsigned(DATA_FILL_BITS-1 downto 0);
  signal data_last_i  : std_logic;
  signal data_got_i   : std_logic;
  signal data_valid_i : std_logic;
  signal data_se_i    : std_logic;

begin

  assert countPorts(ADR_PORTS) > 0
    report "ERROR: No valid address-port in memory-tracer."
    severity error;

  assert not isNullPort(DATA_PORT)
    report "ERROR: No valid data-port in memory-tracer."
    severity error;

  -- collect-value logic
  collect_val_gen : if COLLECT_VAL generate
    signal last_adr_stb_i : std_logic;
    signal last_adr_i     : std_logic_vector(LAST_ADR_BITS-1 downto 0);
    signal last_adr_r     : std_logic_vector(LAST_ADR_BITS-1 downto 0) := (others => '0');
    signal last_adr_rw_i  : std_logic;
    signal last_adr_rw_r  : std_logic := '0';
    signal last_adr_set   : std_logic;
    signal done_r         : std_logic := '1';
  begin

    last_adr_stb_i <= adr_stbs(ADR_PORT_CNT-1);

    last_adr_set   <= last_adr_stb_i and not data_stb;

    last_adr_i    <= adr(LAST_ADR_INDEX+LAST_ADR_BITS-1 downto LAST_ADR_INDEX);
    last_adr_rw_i <= rw;

    last_adr    <= last_adr_r when last_adr_stb_i = '0' else last_adr_i;
    last_adr_rw <= last_adr_rw_r when last_adr_stb_i = '0' else last_adr_rw_i;

    last_adr_stb <= data_stb and (not done_r or last_adr_stb_i);

    clk_proc : process(clk_trc)
    begin
      if rising_edge(clk_trc) then
        if rst_trc = '1' then
          last_adr_r    <= (others => '0');
          last_adr_rw_r <= '0';
          done_r        <= '1';
        else
          if last_adr_set <= '1' then
            last_adr_r    <= last_adr_i;
            last_adr_rw_r <= last_adr_rw_i;
            done_r        <= '0';
          end if;
          if data_stb = '1' then
            done_r <= '1';
          end if;
        end if;
      end if;
    end process clk_proc;

  end generate collect_val_gen;

  no_collect_val_gen : if not COLLECT_VAL generate
  begin
    last_adr     <= adr(LAST_ADR_INDEX+LAST_ADR_BITS-1 downto LAST_ADR_INDEX);
    last_adr_stb <= adr_stbs(ADR_PORT_CNT-1);
    last_adr_rw  <= rw;
  end generate no_collect_val_gen;

  -- intern stb-signal-generation

  other_adr_gen : if ADR_PORT_CNT > 1 generate
    adr_stbs_enabled  <= last_adr_stb & adr_stbs(ADR_PORT_CNT-2 downto 0) and (ADR_PORT_CNT-1 downto 0 => adr_en);
  end generate other_adr_gen;

  no_other_adr_gen : if ADR_PORT_CNT = 1 generate
    adr_stbs_enabled <= (adr_stbs_enabled'left downto 0 => last_adr_stb and adr_en);
  end generate no_other_adr_gen;

  data_stb_enabled <= data_stb and data_en;
  adr_stbs_tracing <= adr_stbs_enabled and (ADR_PORT_CNT-1 downto 0 => trc_enable);
  data_stb_tracing <= data_stb_enabled and trc_enable;
  stb_tracing      <= '1' when unsigned(adr_stbs_tracing & data_stb_tracing) /= 0 else '0';
  stb_fifordy      <= stb_tracing and stb_en_nov;
  stb_i            <= stb_enable and stb_fifordy;
  stb_out          <= stb_fifordy and send_enable;

  -- intern id-generation

  id_gen_blk : block
    signal stbs : std_logic_vector(ADR_PORT_CNT+2-1 downto 0);
  begin
    stbs(ADR_PORT_CNT-1 downto 0) <= adr_stbs_enabled(ADR_PORT_CNT-1 downto 0);
    stbs(ADR_PORT_CNT)            <= data_stb_enabled;
    stbs(ADR_PORT_CNT+1)          <= data_stb_enabled and adr_stbs_enabled(ADR_PORT_CNT-1);

    trc_id_in <= to_unsigned(getLastBitSet(stbs), trc_id_in'length);

  end block id_gen_blk;

  -- from id, select value to put in fifo

  value_sel_blk : block

    function value_widths return tNat_array is
      variable result : tNat_array(0 to ADR_PORT_CNT-1);
    begin
      if ADR_PORT_CNT > 1 then
        for i in 0 to ADR_PORT_CNT-2 loop
          result(i) := ADR_PORTS(i).WIDTH;
        end loop;
      end if;
      result(ADR_PORT_CNT-1) := LAST_ADR_BITS+1 + DATA_PORT.WIDTH;

      return result;

    end function value_widths;

    constant WIDTHS   : tNat_array(0 to ADR_PORT_CNT-1) := value_widths;
    constant IN_BITS  : positive := sum(WIDTHS);
    constant OUT_BITS : positive := max(WIDTHS);
    signal in_value   : std_logic_vector(IN_BITS-1 downto 0);
    signal out_value  : std_logic_vector(OUT_BITS-1 downto 0);
    signal sel        : unsigned(log2ceilnz(ADR_PORT_CNT)-1 downto 0);
  begin

    sel <= trc_id_in(sel'left downto 0) when trc_id_in < ADR_PORT_CNT-1 else
                                             to_unsigned(ADR_PORT_CNT-1, sel'length); -- TODO optimize

    in_value(in_value'left downto sum(WIDTHS, ADR_PORT_CNT-1)) <= data & last_adr_rw & last_adr;
    other_adr_gen : if ADR_PORT_CNT > 1 generate
      in_value(sum(WIDTHS, ADR_PORT_CNT-1)-1 downto 0) <= adr(LAST_ADR_INDEX-1 downto 0);
    end generate other_adr_gen;

    value_sel_multiplex : trace_multiplex
      generic map (
        DATA_BITS => WIDTHS,
        IMPL      => false
      )
      port map (
        inputs => in_value,
        sel    => sel,
        output => out_value
      );

    trc_value_in <= out_value;

  end block value_sel_blk;

  -- overflow
  ov_blk : block
    signal ov_r        : std_logic := '0';
    signal ov_rst      : std_logic;
    signal ov_set      : std_logic;
    signal ov_danger_i : std_logic;
    signal ov_danger_r : std_logic := '0'; --register signal to prevent timing-error
  begin

    ov_rst <= not ov_danger_r;
    ov_set <= '1' when (unsigned(adr_stbs_tracing) /= 0 or data_stb_tracing = '1') and fifo_full = '1'
                  else '0';

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

  fifo_sd_clk_trc <= fifo_sd;

  sd_sync : trace_clk_sync
    port map (
      clk_dst   => clk_sys,
      value_in  => fifo_sd_clk_trc,     -- must be a registered value
      value_out => fifo_sd_clk_sys
  );

  -------------------------------------------------------------
  -- implementation with minimal logic and more memory-usage --
  -------------------------------------------------------------

  main_blk : block

    constant FIFO_BITS : positive := ID_BITS + FIFO_VALUE_BITS + SOURCE_BITS + 1;

    -- clk-trc-domain-signals

    signal fifo_din : std_logic_vector(FIFO_BITS-1 downto 0);
    signal fifo_put : std_logic;

    -- clk-sys-domain-signals

    signal fifo_got   : std_logic;
    signal fifo_dout  : std_logic_vector(FIFO_BITS-1 downto 0);
    signal fifo_valid : std_logic;

    signal trc_id_out_i  : unsigned(log2ceil(PORT_CNT+1)-1 downto 0);
    signal trc_src_out_i : std_logic_vector(SOURCE_BITS-1 downto 0);
    signal trc_src_out   : std_logic_vector(SOURCE_BITS-1 downto 0);
    signal trc_rw_out_i  : std_logic;
    signal trc_rw_out    : std_logic;

    -- signals for ad-blk (no extra registered values)
    signal last_adr_val : std_logic_vector(getTracerHeaderBits(LAST_ADR_PORT)+
                                           getTracerVarValBytes(LAST_ADR_PORT)*8-1 downto 0);
    signal data_val     : std_logic_vector(getTracerHeaderBits(DATA_PORT)+
                                           getTracerVarValBytes(DATA_PORT)*8-1 downto 0);
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

    fifo_din(ID_BITS-1 downto 0) <= std_logic_vector(trc_id_in);

    src_gen : if SOURCE_BITS > 0 generate
      fifo_din(ID_BITS+SOURCE_BITS-1 downto ID_BITS) <= src;
    end generate;

    fifo_din(ID_BITS+SOURCE_BITS+FIFO_VALUE_BITS-1 downto ID_BITS+SOURCE_BITS) <= trc_value_in;

    fifo_din(FIFO_BITS-1) <= send_enable;

    fifo_put <= stb_i;

    --------------------
    -- clk-sys-domain --
    --------------------

    fifo_got     <= load_message;
    send_enabled <= fifo_dout(FIFO_BITS-1);

    trc_id_out_i  <= unsigned(fifo_dout(ID_BITS-1 downto 0));
    trc_src_out_i <= fifo_dout(ID_BITS+SOURCE_BITS-1 downto ID_BITS);
    trc_rw_out_i  <= fifo_dout(ID_BITS+SOURCE_BITS+LAST_ADR_BITS);

    -- register id, src and rw-values when there's compression

    reg_gen : if COMPRESSION generate
      signal trc_id_out_r    : unsigned(log2ceil(PORT_CNT+1)-1 downto 0) := (others => '0');
      signal trc_src_out_r   : std_logic_vector(SOURCE_BITS-1 downto 0) := (others => '0');
      signal trc_rw_out_r    : std_logic := '0';
      signal valid_message_r : std_logic := '0';
      signal send_enabled_r  : std_logic := '0';
    begin

      clk_proc : process(clk_sys)
      begin
        if rising_edge(clk_sys) then
          if rst_sys = '1' then
            valid_message_r <= '0';
            send_enabled_r  <= '0';
          elsif done_message = '1' or valid_message_r = '0' then
            trc_id_out_r    <= trc_id_out_i;
            trc_src_out_r   <= trc_src_out_i;
            trc_rw_out_r    <= trc_rw_out_i;
            valid_message_r <= fifo_valid;
            send_enabled_r  <= send_enabled;
          end if;
        end if;
      end process clk_proc;

      load_message <= (done_message or not valid_message_r) and fifo_valid;

      trc_id_out    <= trc_id_out_r;
      trc_src_out   <= trc_src_out_r;
      trc_rw_out    <= trc_rw_out_r;
      valid_message <= valid_message_r;
      data_se_i     <= send_enabled_r;

    end generate reg_gen;

    no_reg_gen : if not COMPRESSION generate
      trc_id_out    <= trc_id_out_i;
      trc_src_out   <= trc_src_out_i;
      trc_rw_out    <= trc_rw_out_i;
      valid_message <= fifo_valid;
      load_message  <= done_message;
      data_se_i     <= send_enabled;
    end generate no_reg_gen;

    port_gen : for i in 0 to PORT_CNT generate

      constant PORT_I : tPort := ifThenElse(i < ADR_PORT_CNT, ADR_PORTS(ifThenElse(i < ADR_PORT_CNT, i, 0)),
                                            DATA_PORT);
      constant LAST_ADR        : boolean  := i = ADR_PORT_CNT-1;
      constant AD              : boolean  := i = PORT_CNT;
      constant COMPRESSION_I   : boolean  := ifThenElse(AD,
                                                        haveCompression(LAST_ADR_PORT) or
                                                        haveCompression(DATA_PORT),
                                                        haveCompression(PORT_I));
      constant HEADER_VAL_BITS : natural  := ifThenElse(AD,
                                                        getTracerHeaderValBits(LAST_ADR_PORT) +
                                                        getTracerHeaderValBits(DATA_PORT),
                                                        getTracerHeaderValBits(PORT_I));
      constant HEADER_LEN_BITS : natural  := ifThenElse(AD,
                                                        getTracerHeaderLenBits(LAST_ADR_PORT) +
                                                        getTracerHeaderLenBits(DATA_PORT),
                                                        getTracerHeaderLenBits(PORT_I));
      constant HEADER_RW_BITS  : natural  := ifThenElse(LAST_ADR or AD, 1, 0);
      constant HEADER_BITS     : positive := ID_BITS + HEADER_VAL_BITS + HEADER_LEN_BITS + HEADER_RW_BITS + SOURCE_BITS;
      constant VAR_VAL_BYTES   : natural  := ifThenElse(AD,
                                                        getTracerVarValBytes(LAST_ADR_PORT) +
                                                        getTracerVarValBytes(DATA_PORT),
                                                        getTracerVarValBytes(PORT_I));
      constant CH_BITS         : positive := CODING_BITS + HEADER_BITS;
      constant DATA_OUT_BITS_I : positive := getTracerDataOutBits(CH_BITS, COMPRESSION, TIME_BITS);
      constant SEND_FIRST_BITS : positive := ifThenElse(CH_BITS mod DATA_OUT_BITS_I = 0,
                                                        DATA_OUT_BITS_I,
                                                        CH_BITS mod DATA_OUT_BITS_I);
      constant OUT_CH_STEPS    : positive := ifThenElse(CH_BITS mod DATA_OUT_BITS_I > 0,
                                                       (CH_BITS / DATA_OUT_BITS_I)+1,
                                                        CH_BITS / DATA_OUT_BITS_I);
      constant OUT_STEPS       : positive := OUT_CH_STEPS + VAR_VAL_BYTES;
      constant OUT_WIDTHS      : tNat_array
                               := SEND_FIRST_BITS &
                                  ifThenElse(OUT_CH_STEPS > 1,
                                            (max(OUT_CH_STEPS,2)-2 downto 0 => DATA_OUT_BITS_I), (0,0)) &
                                  ifThenElse(VAR_VAL_BYTES > 0 , (notZero(VAR_VAL_BYTES)-1 downto 0 => 8), (0,0));
      constant SRC_INDEX       : natural := ifThenElse(i < ADR_PORT_CNT, ID_BITS+SOURCE_BITS,
                                                                         ID_BITS+SOURCE_BITS+1+LAST_ADR_BITS);

      signal out_vec        : std_logic_vector(CH_BITS+VAR_VAL_BYTES*8-1 downto 0);
      signal last_packet    : std_logic;
      signal sel            : unsigned(log2ceilnz(OUT_STEPS)-1 downto 0);
      signal all_data_out_i : std_logic_vector(max(OUT_WIDTHS)-1 downto 0);
   begin

      -- create coding-and-header-vector

      coding_gen : if CODING generate
        out_vec(CODING_BITS-1 downto 0) <= CODING_VAL;
      end generate coding_gen;

      out_vec(CODING_BITS+ID_BITS-1 downto CODING_BITS) <= std_logic_vector(trc_id_out);

      header_rw_gen : if LAST_ADR or AD generate
        out_vec(CODING_BITS+ID_BITS+SOURCE_BITS) <= trc_rw_out;
      end generate;

      source_gen : if SOURCE_BITS > 0 generate
        constant INDEX : natural := CODING_BITS+ID_BITS;
      begin
        out_vec(INDEX+SOURCE_BITS-1 downto INDEX) <= trc_src_out;
      end generate source_gen;

      -- address or data
      not_ad : if not AD generate

        header_val_gen : if HEADER_VAL_BITS > 0 generate
          constant INDEX : natural := CODING_BITS+ID_BITS+HEADER_RW_BITS+SOURCE_BITS+HEADER_LEN_BITS;
          signal header_val : std_logic_vector(HEADER_VAL_BITS-1 downto 0);
        begin

          -- when one vector is compressed, so register the signals
          reg_gen : if COMPRESSION generate
            signal header_val_r : std_logic_vector(HEADER_VAL_BITS-1 downto 0) := (others => '0');
          begin
            clk_proc : process(clk_sys)
            begin
              if rising_edge(clk_sys) then
                if done_message = '1' or valid_message = '0' then
                  header_val_r <= fifo_dout(SRC_INDEX+HEADER_VAL_BITS-1 downto SRC_INDEX);
                end if;
              end if;
            end process clk_proc;
            header_val <= header_val_r;
          end generate reg_gen;

          no_reg_gen : if not COMPRESSION generate
            header_val <= fifo_dout(SRC_INDEX+HEADER_VAL_BITS-1 downto SRC_INDEX);
          end generate no_reg_gen;

          out_vec(INDEX+HEADER_VAL_BITS-1 downto INDEX) <= header_val;

        end generate header_val_gen;

        -- compression

        comp_gen : if COMPRESSION_I generate

          constant BITS : positive := PORT_I.WIDTH;

          signal comp_in   : std_logic_vector(VAR_VAL_BYTES*8-1 downto 0);
          signal compress  : std_logic;
          signal comp_stb  : std_logic;

          signal comp_out_i : std_logic_vector(VAR_VAL_BYTES*8-1 downto 0);
          signal comp_out_r : std_logic_vector(VAR_VAL_BYTES*8-1 downto 0) := (others => '0');
          signal length_i   : unsigned(HEADER_LEN_BITS-1 downto 0);
          signal length_r   : unsigned(HEADER_LEN_BITS-1 downto 0) := (others => '0');

        begin

          -- TODO: Compression must be resetted when:
          -- - Every time a message is not transmitted. IMPORTANT!
          --   That is, compress only transmitted messages, except first one.
          -- - Tracing is (re-)started. Should be fixed together with above.
          -- - More cases?
          assert false
            report "Compression for trace messages does not work properly."
            severity error;

          comp_stb <= '1' when fifo_got = '1' and (trc_id_out_i = i or ((i = ADR_PORT_CNT-1 or i = PORT_CNT-1) and
                                                                       trc_id_out_i = PORT_CNT)) else '0';

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
          
          -- compression

          comp_in <= fifo_dout(SRC_INDEX+BITS-1 downto SRC_INDEX+HEADER_VAL_BITS);

          comp_inst : trace_compression
            generic map (
              NUM_BYTES   => VAR_VAL_BYTES,
              COMPRESSION => PORT_I.COMP
            )
            port map (
              clk      => clk_sys,
              rst      => rst_sys,
              data_in  => comp_in,
              ie       => comp_stb,
              compress => compress,
              len      => length_i,
              data_out => comp_out_i
            );

          -- register compression-output-values

          clk_proc : process(clk_sys)
          begin
            if rising_edge(clk_sys) then
              if done_message = '1' or valid_message = '0' then
                length_r   <= length_i;
                comp_out_r <= comp_out_i;
              end if;
            end if;
          end process clk_proc;

          -- put length-information to header

          out_vec(CODING_BITS+ID_BITS+HEADER_RW_BITS+SOURCE_BITS+HEADER_LEN_BITS-1 downto
                  CODING_BITS+ID_BITS+HEADER_RW_BITS+SOURCE_BITS) <= std_logic_vector(length_r);

          -- put the compressed output to central array
          out_vec(CH_BITS+VAR_VAL_BYTES*8-1 downto CH_BITS) <= comp_out_r;

          -- last- signal

          last_packet <= '1' when out_counter_r = (OUT_CH_STEPS + fill(length_r, out_counter_r'length) - 1) else
                                  '0';
        end generate comp_gen;

        no_comp_gen : if not COMPRESSION_I generate
        begin
          last_packet <= '1' when out_counter_r = OUT_CH_STEPS - 1 else
                                  '0';
        end generate no_comp_gen;

        last_adr_gen : if LAST_ADR generate
          constant INDEX : natural := CODING_BITS+HEADER_RW_BITS+ID_BITS+SOURCE_BITS;
        begin
          last_adr_val <= out_vec(out_vec'left downto INDEX);
        end generate last_adr_gen;

        dat_gen : if i = PORT_CNT-1 generate
          constant INDEX : natural := CODING_BITS+HEADER_RW_BITS+ID_BITS+SOURCE_BITS;
        begin
          data_val <= out_vec(out_vec'left downto INDEX);
        end generate dat_gen;

      end generate not_ad;

      -- address and data

      ad_gen : if AD generate
        constant HEADER_ADR_VAL_BITS : natural := getTracerHeaderValBits(LAST_ADR_PORT);
        constant HEADER_DAT_VAL_BITS : natural := getTracerHeaderValBits(DATA_PORT);
        constant HEADER_ADR_LEN_BITS : natural := getTracerHeaderLenBits(LAST_ADR_PORT);
        constant HEADER_DAT_LEN_BITS : natural := getTracerHeaderLenBits(DATA_PORT);
        constant ADR_VAR_VAL_BYTES   : natural := getTracerVarValBytes(LAST_ADR_PORT);
        constant DAT_VAR_VAL_BYTES   : natural := getTracerVarValBytes(DATA_PORT);
      begin

        header_adr_len_gen : if HEADER_ADR_LEN_BITS > 0 generate
          constant INDEX : natural := CODING_BITS+ID_BITS+HEADER_RW_BITS+SOURCE_BITS;
        begin
          out_vec(INDEX+HEADER_ADR_LEN_BITS-1 downto INDEX) <= last_adr_val(HEADER_ADR_LEN_BITS-1 downto 0);
        end generate header_adr_len_gen;

        header_dat_len_gen : if HEADER_DAT_LEN_BITS > 0 generate
          constant INDEX : natural := CODING_BITS+ID_BITS+HEADER_RW_BITS+SOURCE_BITS+HEADER_ADR_LEN_BITS;
        begin
          out_vec(INDEX+HEADER_DAT_LEN_BITS-1 downto INDEX) <= data_val(HEADER_DAT_LEN_BITS-1 downto 0);
        end generate header_dat_len_gen;

        header_adr_val_gen : if HEADER_ADR_VAL_BITS > 0 generate
          constant INDEX : natural := CODING_BITS+ID_BITS+HEADER_RW_BITS+SOURCE_BITS+
                                      HEADER_LEN_BITS;
        begin
          out_vec(INDEX+HEADER_ADR_VAL_BITS-1 downto INDEX)
                                <= last_adr_val(HEADER_ADR_LEN_BITS+HEADER_ADR_VAL_BITS-1 downto HEADER_ADR_LEN_BITS);
        end generate header_adr_val_gen;

        header_dat_val_gen : if HEADER_DAT_VAL_BITS > 0 generate
          constant INDEX : natural := CODING_BITS+ID_BITS+HEADER_RW_BITS+SOURCE_BITS+
                                      HEADER_ADR_VAL_BITS+HEADER_LEN_BITS;
        begin
          out_vec(INDEX+HEADER_DAT_VAL_BITS-1 downto INDEX)
                                <= data_val(HEADER_DAT_LEN_BITS+HEADER_DAT_VAL_BITS-1 downto HEADER_DAT_LEN_BITS);
        end generate header_dat_val_gen;

        adr_var_val_gen : if ADR_VAR_VAL_BYTES > 0 generate
          constant DST_INDEX : natural := CODING_BITS+ID_BITS+HEADER_RW_BITS+SOURCE_BITS+
                                          HEADER_LEN_BITS+HEADER_VAL_BITS;
          constant SRC_INDEX : natural := HEADER_ADR_LEN_BITS+HEADER_ADR_VAL_BITS;
        begin
          out_vec(DST_INDEX+ADR_VAR_VAL_BYTES*8-1 downto DST_INDEX)
                                <= last_adr_val(SRC_INDEX+ADR_VAR_VAL_BYTES*8-1 downto SRC_INDEX);
        end generate adr_var_val_gen;

        dat_var_val_gen : if DAT_VAR_VAL_BYTES > 0 generate
          constant DST_INDEX : natural := CODING_BITS+ID_BITS+HEADER_RW_BITS+SOURCE_BITS+
                                          HEADER_LEN_BITS+HEADER_VAL_BITS+ADR_VAR_VAL_BYTES*8;
          constant SRC_INDEX : natural := HEADER_DAT_LEN_BITS+HEADER_DAT_VAL_BITS;
        begin
          out_vec(DST_INDEX+DAT_VAR_VAL_BYTES*8-1 downto DST_INDEX)
                                <= data_val(SRC_INDEX+DAT_VAR_VAL_BYTES*8-1 downto SRC_INDEX);
        end generate dat_var_val_gen;

        -- output control

        oc_adr_gen : if ADR_VAR_VAL_BYTES > 0 and DAT_VAR_VAL_BYTES = 0 generate
          signal last_adr_length : unsigned(HEADER_ADR_LEN_BITS-1 downto 0);
        begin

          last_adr_length <= unsigned(last_adr_val(HEADER_ADR_LEN_BITS-1 downto 0));

          last_packet <= '1' when out_counter_r = OUT_CH_STEPS + fill(last_adr_length, out_counter_r'length)-1 else
                                  '0';

          with last_packet select
            out_counter_nxt <= out_counter_r + 1 when '0',
                               (others => '0')   when others;
        end generate oc_adr_gen;

        oc_dat_gen : if ADR_VAR_VAL_BYTES = 0 and DAT_VAR_VAL_BYTES > 0 generate
          signal data_length : unsigned(HEADER_DAT_LEN_BITS-1 downto 0);
        begin

          data_length <= unsigned(data_val(HEADER_DAT_LEN_BITS-1 downto 0));

          last_packet <= '1' when out_counter_r = OUT_CH_STEPS + fill(data_length, out_counter_r'length)-1 else
                                  '0';

          with last_packet select
            out_counter_nxt <= out_counter_r + 1 when '0',
                               (others => '0')   when others;
        end generate oc_dat_gen;

        oc_gen : if ADR_VAR_VAL_BYTES = 0 and DAT_VAR_VAL_BYTES = 0 generate
          last_packet <= '1' when out_counter_r = OUT_CH_STEPS -1 else
                                  '0';

          with last_packet select
            out_counter_nxt <= out_counter_r + 1 when '0',
                               (others => '0')   when others;
        end generate oc_gen;

        oc_ad_gen : if ADR_VAR_VAL_BYTES > 0 and DAT_VAR_VAL_BYTES > 0 generate
          signal last_adr_byte   : std_logic;
          signal valid_last_adr  : std_logic;

          signal valid_dat       : std_logic;
          signal last_adr_length : unsigned(HEADER_ADR_LEN_BITS-1 downto 0);
          signal data_length     : unsigned(HEADER_DAT_LEN_BITS-1 downto 0);
        begin

          last_adr_length <= unsigned(last_adr_val(HEADER_ADR_LEN_BITS-1 downto 0));
          data_length     <= unsigned(data_val(HEADER_DAT_LEN_BITS-1 downto 0));

          valid_last_adr <= '1' when last_adr_length /= 0 else '0';
          valid_dat      <= '1' when data_length /= 0 else '0';

          last_adr_byte  <= '1' when out_counter_r = OUT_CH_STEPS +
                                     fill(last_adr_length, out_counter_r'length)-1 else
                                      '0';
          last_packet    <= '1' when (out_counter_r = OUT_CH_STEPS-1 and valid_last_adr = '0' and valid_dat = '0') or
                                     (out_counter_r = OUT_CH_STEPS + fill(last_adr_length, out_counter_r'length)-1 and valid_last_adr = '1' and valid_dat = '0') or
                                     (out_counter_r = OUT_CH_STEPS + ADR_VAR_VAL_BYTES + fill(data_length, out_counter_r'length)-1 and valid_dat = '1') else '0';


          out_counter_nxt <= out_counter_r + 1           when last_packet = '0' and last_adr_byte = '0' else
                             to_unsigned(OUT_CH_STEPS+ADR_VAR_VAL_BYTES, out_counter_nxt'length)
                                                          when last_packet = '0' and last_adr_byte = '1' else
                             (others => '0');

        end generate oc_ad_gen;

      end generate ad_gen;

      -- put values in central array

      all_data_fill(i) <= to_unsigned(SEND_FIRST_BITS-1, DATA_FILL_BITS)
                             when out_counter_r = 0 else
                          to_unsigned(DATA_OUT_BITS_I-1, DATA_FILL_BITS)
                             when OUT_CH_STEPS > 1 and out_counter_r < OUT_CH_STEPS else
                          to_unsigned(7, DATA_FILL_BITS)
                             when VAR_VAL_BYTES > 0 else
                          to_unsigned(0, DATA_FILL_BITS);

      sel <= out_counter_r(sel'left downto 0) when out_counter_r < OUT_STEPS else to_unsigned(0, sel'length); -- TODO optimize

      data_out_multiplex : trace_multiplex
        generic map (
          DATA_BITS => OUT_WIDTHS,
          IMPL      => false
        )
        port map (
          inputs => out_vec,
          sel    => sel,
          output => all_data_out_i
        );


      all_data_out(i)  <= fill(all_data_out_i, DATA_OUT_BITS);
      all_data_last(i) <= last_packet;

    end generate port_gen;

  end block main_blk;

  -------------
  -- Outputs --
  -------------

  out_blk : block
    signal trc_id_int : natural;
    signal out_counter_rst : std_logic;
    signal out_counter_inc : std_logic;
    signal cv : std_logic;
  begin

    cv <= '1' when trc_id_out = PORT_CNT else '0';

    clk_proc : process(clk_sys)
    begin
      if rising_edge(clk_sys) then
        if rst_sys = '1' or out_counter_rst = '1' then
          out_counter_r <= (others => '0');
        elsif out_counter_inc = '1' then
          if cv = '1' then
            out_counter_r <= out_counter_nxt;
          else
            out_counter_r <= out_counter_r + 1;
          end if;
        end if;
      end if;
    end process clk_proc;

    out_counter_rst <= done_message;
    out_counter_inc <= data_got_i;

    trc_id_int <= to_integer(trc_id_out);

    -- Select and mutliplex output-values

    data_fill_i  <= all_data_fill(trc_id_int);
    data_out_i   <= all_data_out(trc_id_int);
    data_last_i  <= all_data_last(trc_id_int);
    data_valid_i <= valid_message;

    done_message_sd <= not data_se_i and not sel and fifo_sd_clk_sys;

    done_message <= (data_got_i and data_last_i) or done_message_sd;

    data_got_i <= data_got;

    data_se    <= data_se_i;
    data_fill  <= data_fill_i;
    data_out   <= data_out_i;
    data_last  <= data_last_i;
    data_valid <= data_valid_i;

  end block out_blk;

end Behavioral;
