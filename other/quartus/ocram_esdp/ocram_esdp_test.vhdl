library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;

entity ocram_esdp_test is

  generic (
    A_BITS : positive := 8;
    D_BITS : positive := 16);

  port (
    clk1 : in  std_logic;
    clk2 : in  std_logic;
    ce1	 : in  std_logic;
    ce2	 : in  std_logic;
    we1	 : in  std_logic;
    a1	 : in  unsigned(A_BITS-1 downto 0);
    a2	 : in  unsigned(A_BITS-1 downto 0);
    d1	 : in  std_logic_vector(D_BITS-1 downto 0);
    q1	 : out std_logic_vector(D_BITS-1 downto 0);
    q2	 : out std_logic_vector(D_BITS-1 downto 0));

end entity ocram_esdp_test;

architecture rtl of ocram_esdp_test is

begin  -- architecture rtl

  ocram0: entity poc.ocram_esdp
    generic map (
      A_BITS => A_BITS,
      D_BITS => D_BITS)
    port map (
      clk1 => clk1,
      clk2 => clk2,
      ce1  => ce1,
      ce2  => ce2,
      we1  => we1,
      a1   => a1,
      a2   => a2,
      d1   => d1,
      q1   => q1,
      q2   => q2);

end architecture rtl;

