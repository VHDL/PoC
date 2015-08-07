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
-- Entity: reset_sync_tb3
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

entity reset_sync_tb3 is

end reset_sync_tb3;

-------------------------------------------------------------------------------

architecture behavioral of reset_sync_tb3 is

  component reset_sync
    generic (
      N : positive);
    port (
      rst_a : in  std_logic;
      clk   : in  std_logic_vector(N-1 downto 0);
      rst_s : out std_logic_vector(N-1 downto 0));
  end component;

  -- component generics
  constant N : positive := 3;

  -- component ports
  signal rst_a : std_logic;
  
  signal clk_lcd : std_logic := '0';
  signal rst_lcd : std_logic;
  
  signal clk_eth : std_logic := '0';
  signal rst_eth : std_logic;
  
  signal clk_dsp : std_logic := '0';
  signal rst_dsp : std_logic;
  
begin  -- behavioral

  -- component instantiation
  UUT: reset_sync
    generic map (
      N => 3)
    port map (
      rst_a    => rst_a,
      clk(0)   => clk_lcd,
      clk(1)   => clk_eth,
      clk(2)   => clk_dsp,
      rst_s(0) => rst_lcd,
      rst_s(1) => rst_eth,
      rst_s(2) => rst_dsp);

  -- clock generation
  clk_lcd <= not clk_lcd after 10    ns;
  clk_eth <= not clk_eth after  4    ns;
  clk_dsp <= not clk_dsp after  1.25 ns;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    rst_a <= '1';
    wait until clk_lcd = '1'; wait for 1 ns;
    rst_a <= '0';

    wait;                               -- forever
  end process WaveGen_Proc;

end behavioral;
