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
-- Entity: vga_testcard3
-- Author(s): Martin Zabel
-- 
-- Testcard design for 3-Bit color output.
-- To complete chip design, just connect the appropiate PHY.
-- See also ../README.
--
-- Read comments on vga_timing.vhdl for "CVT", "MODE" and "clk".
--
-- pixel_data(2) = red
-- pixel_data(1) = green
-- pixel_data(0) = blue
--
-- Revision:    $Revision: 1.5 $
-- Last change: $Date: 2013-06-20 11:37:30 $
--

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

library poc;
use poc.vga.all;

entity vga_testcard3 is
  generic (
    CLK_FREQ : positive := 25000000;
    MODE     : natural  := 0;
    CVT      : boolean  := false);
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    phy_ctrl    : out VGA_PHY_CTRL_TYPE;
    pixel_data  : out std_logic_vector (2 downto 0));
end vga_testcard3;

architecture rtl of vga_testcard3 is

  signal xpos            : unsigned(11 downto 0);
  signal ypos            : unsigned(10 downto 0);
  signal timing_phy_ctrl : VGA_PHY_CTRL_TYPE;
  
begin  -- rtl

  timing: vga_timing
    generic map (
      MODE => MODE,
      CVT => CVT)
    port map (
      clk        => clk,
      rst        => rst,
      phy_ctrl   => timing_phy_ctrl,
      xvalid     => open,
      yvalid     => open,
      line_end   => open,
      screen_end => open,
      xpos       => xpos,
      ypos       => ypos);
  
  data: vga_testcard3_data
    generic map (
      CLK_FREQ  => CLK_FREQ,
      XPOS_BITS => 12,
      YPOS_BITS => 11)
    port map (
      clk          => clk,
      rst          => rst,
      xpos         => xpos,
      ypos         => ypos,
      phy_ctrl_in  => timing_phy_ctrl,
      phy_ctrl_out => phy_ctrl,
      pixel_data   => pixel_data);

end rtl;
