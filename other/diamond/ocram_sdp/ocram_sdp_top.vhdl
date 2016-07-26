library	ieee;
use			ieee.std_logic_1164.all;
use			ieee.numeric_std.all;

library poc;

entity ocram_sdp_top is
  generic (
    A_BITS : positive := 8;
    D_BITS : positive := 16
	);
  port (
    clk1 : in  std_logic;
    clk2 : in  std_logic;
    ce1	 : in  std_logic;
    ce2	 : in  std_logic;
    we1	 : in  std_logic;
    a1	 : in  unsigned(A_BITS-1 downto 0);
    a2	 : in  unsigned(A_BITS-1 downto 0);
    d1	 : in  std_logic_vector(D_BITS-1 downto 0);
    q1	 : out std_logic_vector(D_BITS-1 downto 0)
	);
end entity;

architecture rtl of ocram_sdp_top is
	signal reg0		: std_logic_vector(D_BITS-1 downto 0);
	signal reg1		: std_logic_vector(D_BITS-1 downto 0);
begin

	reg0	<= d1		when rising_edge(clk1);
	q1		<= reg1	when rising_edge(clk1);

  ram0 : entity PoC.ocram_sdp
    generic map (
      A_BITS => A_BITS,
      D_BITS => D_BITS
		)
    port map (
      rclk => clk1,
      wclk => clk2,
      rce  => ce1,
			wce  => ce2,
      we   => we1,
      ra   => a1,
      wa   => a2,
      d    => reg0,
      q    => reg1
		);
end architecture;

