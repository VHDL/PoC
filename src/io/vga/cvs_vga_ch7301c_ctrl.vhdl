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
-- Entity: vga_ch7301c_ctrl
-- Author(s): Martin Zabel
-- 
-- Physical layer controller for external CH7301C DVI transmitter.
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
-- The "reset_b"-pin must be driven by other logic (such as the reset button).
--
-- THE IIC_interface is not part of this modules, as one IIC-master controls
-- several slaves. The following registers must be set, see
-- tests/ml505/vga_test_ml505.vhdl for an example.
--
-- Register      Value       Description
-- -----------------------------------
-- 0x49 PM       0xC0        Enable DVI, RGB bypass off
--            or 0xD0        Enable DVI, RGB bypass on
-- 0x33 TPCP     0x08 if clk_freq <= 65 MHz else 0x06
-- 0x34 TPD      0x16 if clk_freq <= 65 MHz else 0x26
-- 0x36 TPF      0x60 if clk_freq <= 65 MHz else 0xA0
-- 0x1F IDF      0x80        when using SMT (VS0, HS0)
--            or 0x90        when using CVT (VS1, HS0)
-- 0x21 DC       0x09        Enable DAC if RGB bypass is on
--
-- Revision:    $Revision: 1.6 $
-- Last change: $Date: 2013-07-04 11:01:59 $
--

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

library poc;
use poc.vga.all;
use poc.ddrio.all;

entity vga_ch7301c_ctrl is
  
  port (
    clk0       : in  std_logic;
    clk90      : in  std_logic;
    phy_ctrl   : in  VGA_PHY_CTRL_TYPE;
    pixel_data : in  std_logic_vector(23 downto 0);
    dvi_xclk_p : out std_logic;
    dvi_xclk_n : out std_logic;
    dvi_h      : out std_logic;
    dvi_v      : out std_logic;
    dvi_de     : out std_logic;
    dvi_d      : out std_logic_vector(11 downto 0));

end vga_ch7301c_ctrl;

architecture rtl of vga_ch7301c_ctrl is
  signal beam_on_vec : std_logic_vector(23 downto 0);
  signal data        : std_logic_vector(23 downto 0);

  signal dvi_h_r : std_logic;
  signal dvi_v_r : std_logic;
  signal dvi_de_r : std_logic;

  attribute iob : string;
  attribute iob of dvi_h_r, dvi_v_r, dvi_de_r : signal is "TRUE";
begin  -- rtl

  -- Some tools do not allow this assignment as part of another equation.
  beam_on_vec <= (others => phy_ctrl.beam_on);

  -- CH7301C Input Data Format "RGB" (IDF 0)
  -- Blank on beam return.
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
      dvi_h_r  <= phy_ctrl.hsync;
      dvi_v_r  <= phy_ctrl.vsync;
      dvi_de_r <= phy_ctrl.beam_on;
    end if;
  end process;

  dvi_v  <= dvi_v_r;
  dvi_h  <= dvi_h_r;
  dvi_de <= dvi_de_r;
  
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
end rtl;
