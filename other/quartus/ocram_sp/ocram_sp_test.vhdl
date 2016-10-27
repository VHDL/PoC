library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;

entity ocram_sp_test is

  generic (
    A_BITS : positive := 8;
    D_BITS : positive := 16);

  port (
    clk : in  std_logic;
    ce	: in  std_logic;
    we	: in  std_logic;
    a	: in  unsigned(A_BITS-1 downto 0);
    d	: in  std_logic_vector(D_BITS-1 downto 0);
    q	: out std_logic_vector(D_BITS-1 downto 0));

end entity ocram_sp_test;

architecture rtl of ocram_sp_test is

begin  -- architecture rtl

  ocram0: entity poc.ocram_sp
    generic map (
      A_BITS => A_BITS,
      D_BITS => D_BITS)
    port map (
      clk => clk,
      ce  => ce,
      we  => we,
      a   => a,
      d   => d,
      q   => q);

end architecture rtl;
