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
-- Entity: trace_instTracer_tb
-- Author(s): Stefan Alex
-- 
-- Test instrTracer.
--
-- Revision:    $Revision: 1.10 $
-- Last change: $Date: 2010-04-24 18:16:40 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;
use poc.trace_types.all;
use poc.trace_functions.all;
use poc.trace_internals.all;

-------------------------------------------------------------------------------

entity trace_instTracer_tb is

end trace_instTracer_tb;

-------------------------------------------------------------------------------

architecture behavioral of trace_instTracer_tb is

  -- component generics
  constant ADR_PORT      : tPort := (ID     => 1,
                                     WIDTH  => 32,
                                     INPUTS => 1,
                                     COMP   => diffC);
  constant BRANCH_INFO   : boolean  := true;
  constant COUNTER_BITS  : positive := 8;
  constant HISTORY_BYTES : natural  := 1;
  constant LS_ENCODING   : boolean  := false;
  constant FIFO_DEPTH    : positive := 1023;
  constant FIFO_SDS      : positive := 15;
  constant CODING        : boolean  := true;
  constant CODING_VAL    : std_logic_vector := "0";
  constant TIME_BITS     : natural  := 0;  -- not cycle-accurate

  -- component ports
  signal clk_trc     : std_logic := '0';
  signal rst_trc     : std_logic;
  signal clk_sys     : std_logic := '0';
  signal rst_sys     : std_logic;
  signal adr         : std_logic_vector(ADR_PORT.WIDTH-1 downto 0);
  signal adr_stb     : std_logic;
  signal branch      : std_logic_vector(ifThenElse(BRANCH_INFO, 2, 0) downto 0);
  signal stb_out     : std_logic;
  signal data_out    : std_logic_vector(getInstDataOutBits(ADR_PORT, BRANCH_INFO, COUNTER_BITS, HISTORY_BYTES,
                                                         ifThenElse(CODING, CODING_VAL'length, 0),
                                                         TIME_BITS)-1 downto 0);
  signal data_got    : std_logic;
  signal data_fill   : unsigned(log2ceilnz(getInstDataOutBits(ADR_PORT, BRANCH_INFO, COUNTER_BITS, HISTORY_BYTES,
                                                             ifThenElse(CODING, CODING_VAL'length, 0),
                                                             TIME_BITS))-1 downto 0);
  signal data_last   : std_logic;
  signal data_se     : std_logic;
  signal data_valid  : std_logic;
  signal sel         : std_logic;
  signal trc_enable  : std_logic;
  signal stb_enable  : std_logic;
  signal send_enable : std_logic;
  signal ov          : std_logic;
  signal ov_start    : std_logic;
  signal ov_stop     : std_logic;
  signal ov_danger   : std_logic;

  -- constants for testbench
  constant NO_BRANCH      : std_logic_vector(2 downto 0) := "000";
  constant DIRECT_NOT     : std_logic_vector(2 downto 0) := "010";
  constant DIRECT_TAKEN   : std_logic_vector(2 downto 0) := "011";
  constant INDIRECT_NOT   : std_logic_vector(2 downto 0) := "100";
  constant INDIRECT_TAKEN : std_logic_vector(2 downto 0) := "101";
  constant EXCEPTION      : std_logic_vector(2 downto 0) := "101";
  
begin  -- behavioral

  -- component instantiation
  DUT: trace_instTracer
    generic map (
      ADR_PORT      => ADR_PORT,
      BRANCH_INFO   => BRANCH_INFO,
      COUNTER_BITS  => COUNTER_BITS,
      HISTORY_BYTES => HISTORY_BYTES,
      LS_ENCODING   => LS_ENCODING,
      FIFO_DEPTH    => FIFO_DEPTH,
      FIFO_SDS      => FIFO_SDS,
      CODING        => CODING,
      CODING_VAL    => CODING_VAL,
      TIME_BITS     => TIME_BITS)
    port map (
      clk_trc     => clk_trc,
      rst_trc     => rst_trc,
      clk_sys     => clk_sys,
      rst_sys     => rst_sys,
      adr         => adr,
      adr_stb     => adr_stb,
      branch      => branch,
      stb_out     => stb_out,
      data_out    => data_out,
      data_got    => data_got,
      data_fill   => data_fill,
      data_last   => data_last,
      data_se     => data_se,
      data_valid  => data_valid,
      sel         => sel,
      trc_enable  => trc_enable,
      stb_enable  => stb_enable,
      send_enable => send_enable,
      ov          => ov,
      ov_start    => ov_start,
      ov_stop     => ov_stop,
      ov_danger   => ov_danger);

  -- clock generation
  clk_sys <= not clk_sys after 5 ns;    -- 100 MHz
  clk_trc <= not clk_trc after 5 ns;    -- 100 MHz

  -- waveform generation
  WaveGen_Proc : process
  begin
    -- Init
    rst_trc     <= '1';
    rst_sys     <= '1';
    adr         <= (others => '0');
    adr_stb     <= '0';
    branch      <= NO_BRANCH;
    data_got    <= '0';
    sel         <= '0';
    trc_enable  <= '0';
    stb_enable  <= '0';
    send_enable <= '0';
    wait until rising_edge(clk_trc);
    wait until rising_edge(clk_trc);
    rst_trc     <= '0';
    rst_sys     <= '0';
    stb_enable  <= '1';

    ---------------------------------------------------------------------------
    -- First Test:
    --   Trace starts and stops during sequential execution.
    --   Trace includes wait states and branches
    ---------------------------------------------------------------------------
    
    -- Some strobes before trigger
    adr_stb <= '1';
    adr     <= x"0000000D";
    wait until rising_edge(clk_trc);
    adr     <= x"0000000E";
    wait until rising_edge(clk_trc);
    adr     <= x"0000000F";
    wait until rising_edge(clk_trc);

    -- PointTrigger
    send_enable <= '1';
    trc_enable  <= '1';
    
    adr_stb <= '1';
    adr     <= x"00000010";             -- following address
    wait until rising_edge(clk_trc);
    adr     <= x"00000011";
    wait until rising_edge(clk_trc);
    adr     <= x"00000012";
    wait until rising_edge(clk_trc);
    adr_stb <= '0';                     -- wait state
    wait until rising_edge(clk_trc);
    adr_stb <= '1';
    adr     <= x"00000013";
    wait until rising_edge(clk_trc);
    adr     <= x"00000014";
    wait until rising_edge(clk_trc);
    adr     <= x"00000015";
    wait until rising_edge(clk_trc);
    adr     <= x"00000018";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000019";
    branch  <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    adr     <= x"0000001A";
    wait until rising_edge(clk_trc);
    adr_stb <= '0';                     -- wait state followed by ...
    wait until rising_edge(clk_trc);
    adr_stb <= '1';
    adr     <= x"0000001D";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"0000001E";
    branch  <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    adr     <= x"0000001F";
    wait until rising_edge(clk_trc);

    -- Some strobes after trigger
    send_enable <= '0';                 -- release trigger
    trc_enable  <= '0';                 -- release trigger
    
    adr_stb <= '1';
    adr     <= x"00000020";             -- following address
    wait until rising_edge(clk_trc);
    adr     <= x"00000021";
    wait until rising_edge(clk_trc);
    adr     <= x"00000022";
    wait until rising_edge(clk_trc);

    ---------------------------------------------------------------------------
    -- Second Test:
    --   Trace starts and stops before/after branch.
    --   Trace includes double branch.
    ---------------------------------------------------------------------------

    -- Branch before Trigger
    send_enable <= '0';
    trc_enable  <= '0';
    adr_stb <= '1';
    adr     <= x"00000030";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);

    -- PointTrigger
    send_enable <= '1';
    trc_enable  <= '1';
    adr     <= x"00000032";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000033";
    branch  <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    adr     <= x"00000035";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000037";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000038";
    branch  <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    adr     <= x"0000003A";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);

    -- Branch after Trigger
    send_enable <= '0';                 -- release trigger
    trc_enable  <= '0';                 -- release trigger
    
    adr_stb <= '1';
    adr     <= x"00000040";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000041";
    branch  <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    adr     <= x"00000042";
    wait until rising_edge(clk_trc);

    ---------------------------------------------------------------------------
    -- Third Test:
    --   Trace starts and stops with wait state.
    ---------------------------------------------------------------------------
    
    -- PointTrigger
    send_enable <= '1';
    trc_enable  <= '1';
    
    adr_stb <= '0';                     -- wait state
    wait until rising_edge(clk_trc);
    wait until rising_edge(clk_trc);
    adr_stb <= '1';
    adr     <= x"00000043";             -- following address
    wait until rising_edge(clk_trc);
    adr     <= x"00000044";
    wait until rising_edge(clk_trc);
    adr     <= x"00000045";
    wait until rising_edge(clk_trc);
    adr_stb <= '0';                     -- wait state
    wait until rising_edge(clk_trc);

    -- Some strobes after trigger
    send_enable <= '0';                 -- release trigger
    trc_enable  <= '0';                 -- release trigger

    adr_stb <= '1';
    adr     <= x"00000046";             -- following address
    wait until rising_edge(clk_trc);
    adr     <= x"00000047";
    wait until rising_edge(clk_trc);
    adr     <= x"00000048";
    wait until rising_edge(clk_trc);

    ---------------------------------------------------------------------------
    -- Fourth Test:
    --   Trace starts and stops with wait state and branch.
    ---------------------------------------------------------------------------
    
    -- PointTrigger
    send_enable <= '1';
    trc_enable  <= '1';
    
    adr_stb <= '0';                     -- wait state followed by
    wait until rising_edge(clk_trc);
    wait until rising_edge(clk_trc);
    adr_stb <= '1';
    adr     <= x"00000050";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000051";
    branch  <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    adr     <= x"00000052";
    wait until rising_edge(clk_trc);
    adr_stb <= '0';                     -- wait state followed by
    wait until rising_edge(clk_trc);

    -- Some strobes after trigger
    send_enable <= '0';                 -- release trigger
    trc_enable  <= '0';                 -- release trigger

    adr_stb <= '1';
    adr     <= x"00000058";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000059";
    branch  <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    adr     <= x"0000005A";
    wait until rising_edge(clk_trc);

    ---------------------------------------------------------------------------
    -- Fifth Test:
    --   No stb during sending.
    ---------------------------------------------------------------------------

    -- PointTrigger
    send_enable <= '1';
    trc_enable  <= '1';
    
    adr_stb <= '0';                     -- just wait state
    wait until rising_edge(clk_trc);
    wait until rising_edge(clk_trc);
    
    -- No Trigger
    send_enable <= '0';                 -- release trigger
    trc_enable  <= '0';                 -- release trigger
    wait until rising_edge(clk_trc);
    wait until rising_edge(clk_trc);
    
    ---------------------------------------------------------------------------
    -- Sixth Test:
    --   Post Trigger
    ---------------------------------------------------------------------------

    -- Before Trigger, tracing only
    send_enable <= '0';
    trc_enable  <= '1';
    
    adr_stb <= '1';
    adr     <= x"00000100";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000101";
    branch  <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    adr     <= x"00000102";
    wait until rising_edge(clk_trc);

    -- PostTrigger
    send_enable <= '1';
    adr     <= x"00000103";
    wait until rising_edge(clk_trc);
    adr     <= x"00000104";
    wait until rising_edge(clk_trc);
    
    -- No Trigger
    send_enable <= '0';                 -- release trigger
    trc_enable  <= '0';                 -- release trigger
    adr     <= x"00000105";
    wait until rising_edge(clk_trc);
    
    ---------------------------------------------------------------------------
    -- Seventh Test:
    --   History fill and overflow
    --   Indirect branches
    ---------------------------------------------------------------------------

    -- PointTrigger
    send_enable <= '1';
    trc_enable  <= '1';
    
    adr_stb <= '1';
    adr     <= x"00000110";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000111";             -- branch not taken
    branch  <= DIRECT_NOT;
    wait until rising_edge(clk_trc);
    adr     <= x"00000110";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000111";             -- branch not taken
    branch  <= DIRECT_NOT;
    wait until rising_edge(clk_trc);
    adr     <= x"00000110";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000111";             -- branch not taken
    branch  <= DIRECT_NOT;
    wait until rising_edge(clk_trc);
    adr     <= x"00000110";             -- branch
    branch  <= DIRECT_TAKEN;
    wait until rising_edge(clk_trc);    -- history is full (no LS-Encoding)
    adr     <= x"00000111";             -- no branch, no message
    branch  <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    adr     <= x"00000112";             -- branch not taken
    branch  <= DIRECT_NOT;
    wait until rising_edge(clk_trc);
    adr     <= x"00000115";             -- indirect
    branch  <= INDIRECT_TAKEN;
    wait until rising_edge(clk_trc);
    adr     <= x"00000116";             -- indirect not taken
    branch  <= INDIRECT_NOT;
    wait until rising_edge(clk_trc);
    adr     <= x"00000118";             -- exception
    branch  <= EXCEPTION;
    wait until rising_edge(clk_trc);

    -- No Trigger
    send_enable <= '0';                 -- release trigger
    trc_enable  <= '0';                 -- release trigger
    adr_stb     <= '0';
    branch      <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    
    ---------------------------------------------------------------------------
    -- Eight Test:
    --   Threshold check.
    --   PostTriggger
    ---------------------------------------------------------------------------

    -- EMPTY FIFO:
    wait until rising_edge(clk_sys);
    wait for 1 ns;                      -- output settle
    while data_valid = '1' loop
      data_got <= '1';
      wait until rising_edge(clk_sys);  -- output settle
      wait for 1 ns;
    end loop;
    
    -- Before trigger, tracing only.
    send_enable <= '0';
    trc_enable  <= '1';

    for i in 0 to FIFO_DEPTH+15 loop
      adr_stb <= '1';
      adr     <= x"00001000";             -- branch
      branch  <= INDIRECT_TAKEN;
      wait until rising_edge(clk_trc);
    end loop;  -- i

    -- PostTrigger
    send_enable <= '1';
    trc_enable  <= '1';

    adr_stb <= '1';
    adr     <= x"00001001";             -- branch
    branch  <= INDIRECT_TAKEN;
    wait until rising_edge(clk_trc);

    -- No Trigger
    send_enable <= '0';                 -- release trigger
    trc_enable  <= '0';                 -- release trigger
    adr_stb     <= '0';
    branch      <= NO_BRANCH;
    wait until rising_edge(clk_trc);
    
    -- EMPTY FIFO:
    wait until rising_edge(clk_sys);
    wait for 1 ns;                      -- output settle
    while data_valid = '1' loop
      data_got <= '1';
      wait until rising_edge(clk_sys);  -- output settle
      wait for 1 ns;
    end loop;
    
    ---------------------------------------------------------------------------
    -- End
    ---------------------------------------------------------------------------
    adr         <= (others => '0');
    adr_stb     <= '0';
    branch      <= (others => '0');
    data_got    <= '0';
    sel         <= '0';
    trc_enable  <= '0';
    stb_enable  <= '0';
    send_enable <= '0';
    wait;
    
  end process WaveGen_Proc;

  

end behavioral;
