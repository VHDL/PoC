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
-- Entity: vga_phy
-- Author(s): Martin Zabel
-- 
-- Physical layer controller for analog VGA output from FPGA.
-- See also ../README.
--
-- The clock frequency must be the same as used for the timing module.
--
-- The number of color-bits per pixel can be configured with the generic
-- "COLOR_BITS". The format of the pixel data is defined the picture generator
-- in use.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2009-02-16 10:03:28 $
--

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

library poc;
use poc.vga.all;

entity vga_phy is
  
  generic (
    COLOR_BITS : positive);-- := 3);

  port (
    clk            : in  std_logic;
    phy_ctrl       : in  VGA_PHY_CTRL_TYPE;
    pixel_data_in  : in  std_logic_vector(COLOR_BITS-1 downto 0);
    hsync          : out std_logic;
    vsync          : out std_logic;
    pixel_data_out : out std_logic_vector(COLOR_BITS-1 downto 0));

end vga_phy;

architecture rtl of vga_phy is
  signal beam_on_vec : std_logic_vector(COLOR_BITS-1 downto 0);
  
begin  -- rtl

  -- Some tools do not allow this assignment as part of another equation.
  beam_on_vec <= (others => phy_ctrl.beam_on);
    
  process (clk)
  begin  -- process
    if rising_edge(clk) then
      hsync <= phy_ctrl.hsync;
      vsync <= phy_ctrl.vsync;
      
      -- blank on beam return
      pixel_data_out <= pixel_data_in and beam_on_vec;
    end if;
  end process;

end rtl;
