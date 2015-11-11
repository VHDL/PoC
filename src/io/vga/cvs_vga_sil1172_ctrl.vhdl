--
-- Copyright (c) 2009
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
-- Entity: vga_sil1172_ctrl
-- Author(s): Jan Schirok, Martin Zabel
-- 
-- Physical layer controller for external SIL1172 DVI transmitter.
-- See also ../README.
--
-- The clock frequency must be the same as used for the timing module,
-- e.g., 25 MHZ for VGA 640x480. A phase-shifted clock must be provided:
-- clk0  :  0 degrees
-- clk90 : 90 degrees
--
-- pixel_data(23 downto 16) : red
-- pixel_data(15 downto  8) : green
-- pixel_data( 7 downto  0) : blue
--
-- The implementation is taken from CH7301C DVI interface.
-- In comparison to the Chrontel Device, the SIL1172 doesn't need an 
-- initialization via I2C, thus all configuration is done via external
-- signal lines. These are statically driven to low/high in this module.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2009-02-25 14:15:42 $
--

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

library poc;
use poc.vga.all;
use poc.ddrio.all;

entity vga_sil1172_ctrl is
  
  port (
    clk0       : in  std_logic;
    clk90      : in  std_logic;
    rst0       : in  std_logic;
    rst90      : in  std_logic;
    phy_ctrl   : in  VGA_PHY_CTRL_TYPE;
    pixel_data : in  std_logic_vector(23 downto 0);
    dvi_xclk_p : out std_logic;
    dvi_xclk_n : out std_logic;
    dvi_h      : out std_logic;
    dvi_v      : out std_logic;
    dvi_de     : out std_logic;
    dvi_d      : out std_logic_vector(11 downto 0);
    dvi_edge   : out std_logic;
    dvi_ctl3   : out std_logic;
    dvi_rstn   : out std_logic;
    dvi_pdn    : out std_logic;
    dvi_dk0    : out std_logic;
    dvi_dk1    : out std_logic);

end vga_sil1172_ctrl;

architecture rtl of vga_sil1172_ctrl is
  signal beam_on_vec : std_logic_vector(23 downto 0);
  signal data        : std_logic_vector(23 downto 0);
  
begin  -- rtl

  -- Some tools do not allow this assignment as part of another equation.
  beam_on_vec <= (others => phy_ctrl.beam_on);

  -- CH7301C Input Data Format "RGB" (IDF 0)
  -- Blank on beam return.
  -- Doesn't hurt for other DVI PHYs.
  data <= pixel_data and beam_on_vec;
  
  -- Timing: Data changes with 0 / 180 degrees.
  -- Clock changes with 90 degrees.

  -- Mirror clk90
  xclk_out : ddrio_out
    generic map (
      NO_OE => true,
      WIDTH => 2)
    port map (
      clk  => clk90,
      ce   => '1',
      dh   => "01",
      dl   => "10",
      oe   => '1',
      q(0) => dvi_xclk_p,
      q(1) => dvi_xclk_n);
  
  -- Output control signals (single data rate)
  -- Registers must be placed into IOBs.
  process (clk0)
  begin  -- process
    if rising_edge(clk0) then
      dvi_h  <= phy_ctrl.hsync;
      dvi_v  <= phy_ctrl.vsync;
      dvi_de <= phy_ctrl.beam_on;
    end if;
  end process;

  -- Output data signals (dual data rate)
  data_out: ddrio_out
    generic map (
      NO_OE => true,
      WIDTH => 12)
    port map (
      clk => clk0,
      ce  => '1',
      dh  => data(11 downto  0),
      dl  => data(23 downto 12),
      oe  => '1',
      q   => dvi_d);
      
  -- DVI Controller configuration
  -- pin definitions for dvi_rstn='0'
  dvi_rstn <= '0'; -- permanently reset I2C (ISEL=0)
  dvi_edge <= '1'; -- rising idct_p
  dvi_pdn  <= '1'; -- active low power down
  dvi_dk0  <= '0'; -- de-skew inputs
  dvi_dk1  <= '0';
  dvi_ctl3 <= '0';
  
end rtl;
