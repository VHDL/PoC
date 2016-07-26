library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

-------------------------------------------------------------------------------

entity trace_global_time_tb is

end trace_global_time_tb;

-------------------------------------------------------------------------------

architecture behavioral of trace_global_time_tb is

  component trace_global_time
    generic (
      TIME_BITS                 : positive;
      TIME_CMP_LEVELS           : positive;
      GLOBAL_TIME_SAFE_DISTANCE : positive;
      GLOBAL_TIME_FIFO_DEPTH    : positive);
    port (
      clk_trc       : in  std_logic;
      rst_trc       : in  std_logic;
      clk_sys       : in  std_logic;
      rst_sys       : in  std_logic;
      enable        : in  std_logic;
      ov_stop       : out std_logic;
      ov_danger     : out std_logic;
      tracer_stb    : in  std_logic;
      stb_en        : out std_logic;
      current_level : out unsigned(log2ceilnz(TIME_CMP_LEVELS)-1 downto 0);
      current_time  : out std_logic_vector(TIME_BITS-1 downto 0);
      no_data       : out std_logic;
      done_level    : in  std_logic;
      valid_out     : out std_logic);
  end component;

  -- component generics
  constant TIME_BITS                 : positive := 4;
  constant TIME_CMP_LEVELS           : positive := 2;
  constant GLOBAL_TIME_SAFE_DISTANCE : positive := 7;
  constant GLOBAL_TIME_FIFO_DEPTH    : positive := 127;

  -- component ports
  signal clk_trc       : std_logic := '0';
  signal rst_trc       : std_logic;
  signal clk_sys       : std_logic := '0';
  signal rst_sys       : std_logic;
  signal enable        : std_logic;
  signal ov_stop       : std_logic;
  signal ov_danger     : std_logic;
  signal tracer_stb    : std_logic;
  signal stb_en        : std_logic;
  signal current_level : unsigned(log2ceilnz(TIME_CMP_LEVELS)-1 downto 0);
  signal current_time  : std_logic_vector(TIME_BITS-1 downto 0);
  signal no_data       : std_logic;
  signal done_level    : std_logic;
  signal valid_out     : std_logic;

  constant clk_sys_period : time := 10 ns;
  constant clk_trc_period : time := 10 ns;

begin  -- behavioral

  -- component instantiation
  DUT: trace_global_time
    generic map (
      TIME_BITS                 => TIME_BITS,
      TIME_CMP_LEVELS           => TIME_CMP_LEVELS,
      GLOBAL_TIME_SAFE_DISTANCE => GLOBAL_TIME_SAFE_DISTANCE,
      GLOBAL_TIME_FIFO_DEPTH    => GLOBAL_TIME_FIFO_DEPTH)
    port map (
      clk_trc       => clk_trc,
      rst_trc       => rst_trc,
      clk_sys       => clk_sys,
      rst_sys       => rst_sys,
      enable        => enable,
      ov_stop       => ov_stop,
      ov_danger     => ov_danger,
      tracer_stb    => tracer_stb,
      stb_en        => stb_en,
      current_level => current_level,
      current_time  => current_time,
      no_data       => no_data,
      done_level    => done_level,
      valid_out     => valid_out);

  -- clock generation
  clk_sys <= not clk_sys after clk_sys_period/2;
  clk_trc <= not clk_trc after clk_trc_period/2;

  -- waveform generation
  trc_proc : process
  begin
    -- insert signal assignments here
    rst_trc    <= '1';
    enable     <= '0';
    tracer_stb <= '0';
    wait until rising_edge(clk_trc);
    rst_trc    <= '0';
    enable     <= '1';

    wait for clk_trc_period*10;
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '0';

    wait for clk_trc_period*20;
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '0';

    wait for clk_trc_period*100;
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '1';
    wait until rising_edge(clk_trc);
    tracer_stb <= '0';

    enable <= '0';
    wait;
  end process trc_proc;

  -- waveform generation
  sys_proc : process
  begin
    -- insert signal assignments here
    rst_sys    <= '1';
    done_level <= '0';
    wait until rising_edge(clk_sys);
    rst_sys    <= '0';

    while true loop
      wait until rising_edge(clk_sys);
      wait for 1 ns;                    -- output update
      if valid_out = '1' then
        wait until rising_edge(clk_sys);
        done_level <= '1';
        wait until rising_edge(clk_sys);
        done_level <= '0';
      end if;
    end loop;
    wait;
  end process sys_proc;

end behavioral;
