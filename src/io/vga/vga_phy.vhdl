-- EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Martin Zabel
--
-- Module:					PhysicalLayer controller for analog VGA output from FPGA.
--
-- Description:
-- ------------------------------------
--	The clock frequency must be the same as used for the timing module.
--
--	The number of color-bits per pixel can be configured with the generic
--	"COLOR_BITS". The format of the pixel data is defined the picture generator
--	in use.
--
-- License:
-- ============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany,
--											Chair for VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;
use			PoC.vga.all;


entity vga_phy is
	generic (
		COLOR_BITS : positive
	);
	port (
		clk							: in	std_logic;
		phy_ctrl				: in	T_IO_VGA_PHY_CTRL;
		pixel_data_in		: in	std_logic_vector(COLOR_BITS - 1 downto 0);
		hsync						: out	std_logic;
		vsync						: out	std_logic;
		pixel_data_out	: out	std_logic_vector(COLOR_BITS - 1 downto 0)
	);
end entity;


architecture rtl of vga_phy is

begin
	process(clk)
	begin
		if rising_edge(clk) then
			hsync <= phy_ctrl.hsync;
			vsync <= phy_ctrl.vsync;

			-- blank on beam return
			pixel_data_out <= pixel_data_in and (pixel_data_in'range => phy_ctrl.beam_on);
		end if;
	end process;

end architecture;
