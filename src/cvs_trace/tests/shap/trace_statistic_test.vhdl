library ieee;
use ieee.std_logic_1164.all;

entity trace_statistic_test is

  generic (
    COUNTER_BITS : positive := 4);

  port (
    clk_trc       : in  std_logic;
    rst_trc       : in  std_logic;
    inc           : in  std_logic;
    rst           : in  std_logic;
    counter_value : out std_logic_vector(COUNTER_BITS-1 downto 0);
    counter_stb   : out std_logic);

end trace_statistic_test;

architecture rtl of trace_statistic_test is
  component trace_statistic
    generic (
      COUNTER_BITS : positive);
    port (
      clk_trc       : in  std_logic;
      rst_trc       : in  std_logic;
      inc           : in  std_logic;
      rst           : in  std_logic;
      counter_value : out std_logic_vector(COUNTER_BITS-1 downto 0);
      counter_stb   : out std_logic);
  end component;
begin  -- rtl

  inst: trace_statistic
    generic map (
      COUNTER_BITS => COUNTER_BITS)
    port map (
      clk_trc       => clk_trc,
      rst_trc       => rst_trc,
      inc           => inc,
      rst           => rst,
      counter_value => counter_value,
      counter_stb   => counter_stb);

end rtl;
