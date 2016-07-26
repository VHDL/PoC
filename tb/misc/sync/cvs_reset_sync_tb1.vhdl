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
-- Entity: reset_sync_tb1
-- Author(s): Martin Zabel
--
-- Testbench for reset_sync.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-09-09 14:01:28 $
--

library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------

entity reset_sync_tb1 is

end reset_sync_tb1;

-------------------------------------------------------------------------------

architecture behavioral of reset_sync_tb1 is

  component reset_sync
    generic (
      N : positive);
    port (
      rst_a : in  std_logic;
      clk   : in  std_logic_vector(N-1 downto 0);
      rst_s : out std_logic_vector(N-1 downto 0));
  end component;

  -- component generics
  constant N : positive := 1;

  -- component ports
  signal rst_a : std_logic;

  signal clk_sys : std_logic := '0';
  signal rst_sys : std_logic;

begin  -- behavioral

  -- component instantiation
  UUT: reset_sync
    generic map (
      N => 1)
    port map (
      rst_a    => rst_a,
      clk(0)   => clk_sys,
      rst_s(0) => rst_sys);

  -- clock generation
  clk_sys <= not clk_sys after 10    ns;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    rst_a <= '1';
    wait until clk_sys = '1'; wait for 1 ns;
    rst_a <= '0';

    wait;                               -- forever
  end process WaveGen_Proc;

end behavioral;
