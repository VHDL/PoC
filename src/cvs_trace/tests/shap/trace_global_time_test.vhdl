library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

entity trace_global_time_test is

  generic (
    TIME_BITS                 : positive := 2;
    TIME_CMP_LEVELS           : positive := 4;
    GLOBAL_TIME_SAFE_DISTANCE : positive := 7;
    GLOBAL_TIME_FIFO_DEPTH    : positive := 127);

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

end trace_global_time_test;

architecture rtl of trace_global_time_test is
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
begin  -- rtl

  inst: trace_global_time
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

end rtl;
