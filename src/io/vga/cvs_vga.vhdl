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
-- Package: vga
-- Author(s): Jan Schirok, Martin Zabel
-- 
-- Component and type declarations for VGA modules.
--
-- Revision:    $Revision: 1.13 $
-- Last change: $Date: 2013-07-02 15:12:14 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package vga is

  --
  -- Control signals which must be passed from the timing module through
  -- the data processing pipeline to the physical layer controller.
  -- See also ../README.
  --
  type VGA_PHY_CTRL_TYPE is record
    hsync   : std_logic;
    vsync   : std_logic;
    beam_on : std_logic;
  end record;
  
  component vga_timing
   generic (
      MODE : natural := 0;
      CVT : boolean := false);
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      phy_ctrl   : out VGA_PHY_CTRL_TYPE;
      xvalid     : out std_logic;
      yvalid     : out std_logic;
      line_end   : out std_logic;
      screen_end : out std_logic;
      xpos       : out unsigned(11 downto 0);
      ypos       : out unsigned(10 downto 0));
  end component;
  
  component vga_testcard3_data
    generic (
      CLK_FREQ  : positive;
      XPOS_BITS : positive;
      YPOS_BITS : positive);
    port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      xpos         : in  unsigned (XPOS_BITS-1 downto 0);
      ypos         : in  unsigned (YPOS_BITS-1 downto 0);
      phy_ctrl_in  : in  VGA_PHY_CTRL_TYPE;
      phy_ctrl_out : out VGA_PHY_CTRL_TYPE;
      pixel_data   : out std_logic_vector (2 downto 0));
  end component;

  component vga_testcard3
    generic (
      CLK_FREQ : positive := 25000000;
      MODE     : natural  := 0;
      CVT      : boolean := false);
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      phy_ctrl   : out VGA_PHY_CTRL_TYPE;
      pixel_data : out std_logic_vector (2 downto 0));
  end component;

  component vga_phy
    generic (
      COLOR_BITS : positive);
    port (
      clk            : in  std_logic;
      phy_ctrl       : in  VGA_PHY_CTRL_TYPE;
      pixel_data_in  : in  std_logic_vector(COLOR_BITS-1 downto 0);
      hsync          : out std_logic;
      vsync          : out std_logic;
      pixel_data_out : out std_logic_vector(COLOR_BITS-1 downto 0));
  end component;

  component vga_ch7301c_ctrl
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
  end component;

  component vga_ch7301c_init
    generic (
      CLK_FREQ   : positive;
      CVT        : boolean;
      DEV_ADDR   : std_logic_vector(6 downto 0);
      RGB_BYPASS : boolean);
    port (
      clk     : in  std_logic;
      rst     : in  std_logic;
      status  : out std_logic_vector(1 downto 0);
      error   : out std_logic_vector(3 downto 0);
      start   : out std_logic;
      stop    : out std_logic;
      read    : out std_logic;
      write   : out std_logic;
      ack_in  : out std_logic;
      din     : out std_logic_vector(7 downto 0);
      cmd_ack : in  std_logic;
      ack_out : in  std_logic;
      dout    : in  std_logic_vector(7 downto 0));
  end component;
  
  component vga_sil1172_ctrl is
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
  end component;

  
end vga;

package body vga is
end vga;
