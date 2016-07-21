library	ieee;
use			ieee.std_logic_1164.all;
use			ieee.numeric_std.all;

library poc;

entity ocram_sp_top is
  generic (
    A_BITS : positive := 8;
    D_BITS : positive := 16
	);
  port (
    clk1 : in  std_logic;
    ce1	 : in  std_logic;
    we1	 : in  std_logic;
    a1	 : in  unsigned(A_BITS-1 downto 0);
    d1	 : in  std_logic_vector(D_BITS-1 downto 0);
    q1	 : out std_logic_vector(D_BITS-1 downto 0)
	);
end entity;

architecture rtl of ocram_sp_top is
	signal reg0		: std_logic_vector(D_BITS-1 downto 0);
	signal reg1		: std_logic_vector(D_BITS-1 downto 0);
begin

	reg0	<= d1		when rising_edge(clk1);
	q1		<= reg1	when rising_edge(clk1);

  ram0 : entity PoC.ocram_sp
    generic map (
      A_BITS => A_BITS,
      D_BITS => D_BITS
		)
    port map (
      clk  => clk1,
      ce   => ce1,
      we   => we1,
      a    => a1,
      d    => reg0,
      q    => reg1
		);
end architecture;

