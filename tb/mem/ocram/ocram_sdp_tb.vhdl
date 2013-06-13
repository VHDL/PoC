--
-- Copyright (c) 2008
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
-- Entity: ocram_sdp_tb
-- Author(s): Martin Zabel
-- 
-- Testbench for ocram_sdp
--
-- When simulating a netlist:
-- a) Setup constants for component generics to the values used for synthesis.
-- b) Comment out the generics in the component declaration.
--
-- Revision:    $Revision: 1.3 $
-- Last change: $Date: 2008-12-11 18:52:22 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ocram_sdp_tb is
end ocram_sdp_tb;

library poc;
use poc.ocram.all;

architecture tb of ocram_sdp_tb is

  -- component generics
  -- Set to values used for synthesis when simulating a netlist.
  constant A_BITS : positive := 10;
  constant D_BITS : positive := 32;

  component ocram_sdp
-- Comment out when simulating a netlist. Default values are applied here, so
-- that this is the only location which must be commented out.
  generic (
      A_BITS : positive := A_BITS;
      D_BITS : positive := D_BITS);
    port (
      rclk : in  std_logic;
      rce  : in  std_logic;
      wclk : in  std_logic;
      wce  : in  std_logic;
      we   : in  std_logic;
      ra   : in  unsigned(A_BITS-1 downto 0);
      wa   : in  unsigned(A_BITS-1 downto 0);
      d    : in  std_logic_vector(D_BITS-1 downto 0);
      q    : out std_logic_vector(D_BITS-1 downto 0));
  end component;

  -- component ports
  signal rce  : std_logic;
  signal wce  : std_logic;
  signal we   : std_logic;
  signal ra   : unsigned(A_BITS-1 downto 0);
  signal wa   : unsigned(A_BITS-1 downto 0);
  signal d    : std_logic_vector(D_BITS-1 downto 0);
  signal q    : std_logic_vector(D_BITS-1 downto 0);

  -- clock
  signal clk : std_logic := '1';

begin  -- tb

  -- component instantiation
  UUT: ocram_sdp
    port map (
      rclk => clk,
      rce  => rce,
      wclk => clk,
      wce  => wce,
      we   => we,
      ra   => ra,
      wa   => wa,
      d    => d,
      q    => q);

  -- clock generation
  clk <= not clk after 5 ns;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    ra  <= (others => '0');
    wa  <= (others => '0');
    rce <= '0';
    wce <= '0';
    we  <= '0';
    wait for 100 ns;
    
    wait until falling_edge(clk);
    
    d   <= x"11111111";
    we  <= '1';
    wce <= '1';
    rce <= '0';
    wait until falling_edge(clk);
    
    we  <= '0';
    wce <= '1';
    rce <= '1';                         -- normal read after write
    wait until falling_edge(clk);
    assert q = x"11111111" report "wrong read data1" severity error;
    
    d   <= x"22222222";
    we  <= '1';
    wce <= '1';
    rce <= '1';                         -- read-during-write on opposite port
    wait until falling_edge(clk);
    
    we  <= '0';
    wce <= '1';
    rce <= '1';                         -- read again
    wait until falling_edge(clk);
    assert q = x"22222222" report "wrong read data2" severity error;
    
    d   <= x"33333333";
    we  <= '1';                         -- write new value
    wce <= '1';
    rce <= '0';                         -- no read
    wait until falling_edge(clk);
    assert q = x"22222222" report "wrong read data3" severity error;

    we  <= '0';                         -- no write
    wce <= '1';
    rce <= '0';                         -- no read
    wait until falling_edge(clk);
    assert q = x"22222222" report "wrong read data4" severity error;

    d   <= x"44444444";
    we  <= '1';
    wce <= '1';
    rce <= '1';                         -- read-during-write on opposite port
    wait until falling_edge(clk);

    d   <= x"55555555";
    we  <= '1';
    wce <= '0';                         -- write clock disabled
    rce <= '1';                         -- should be normal read
    wait until falling_edge(clk);
    assert q = x"44444444" report "wrong read data5" severity error;

    we  <= '0';
    wce <= '0';
    rce <= '0';
    wait;                               -- forever
  end process WaveGen_Proc;

end tb;
