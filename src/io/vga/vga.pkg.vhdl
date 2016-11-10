-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Martin Zabel
--									Patrick Lehmann
--
-- Package:					VHDL package for component declarations, types and
--									functions associated to the PoC.io.vga namespace
--
-- Description:
-- -------------------------------------
--		For detailed documentation see below.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany,
--											Chair of VLSI-Design, Diagnostics and Architecture
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
-- =============================================================================

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;


package vga is
	type T_IO_VGA_MODE is (
		-- 5:4
		VGA_MODE_1280X1024,	VGA_MODE_SXGA,
		VGA_MODE_2560X2048,	VGA_MODE_QSXGA,
		-- 4:3
		VGA_MODE_320X240,		VGA_MODE_QVGA,
		VGA_MODE_640X480,		VGA_MODE_VGA,
		VGA_MODE_768X576,		VGA_MODE_PAL,
		VGA_MODE_800X600,		VGA_MODE_SVGA,
		VGA_MODE_1024X768,	VGA_MODE_XGA,
		VGA_MODE_1280X960,
		VGA_MODE_1400X1050,	VGA_MODE_SXGAP,
		VGA_MODE_1600X1200,	VGA_MODE_UXGA,
		VGA_MODE_2048X1536,	VGA_MODE_QXGA,
		-- 3:2
		VGA_MODE_1151X768,
		VGA_MODE_1440X960,
		-- 16:10 (8:5)
		VGA_MODE_320X200,		VGA_MODE_CGA,
		VGA_MODE_1280X800,	VGA_MODE_WXGA,
		VGA_MODE_1440X900,
		VGA_MODE_1680X1050,	VGA_MODE_WSXGAP,
		VGA_MODE_1920X1200,	VGA_MODE_WUXGA,
		VGA_MODE_2560X1600,	VGA_MODE_WQXGA,
		-- 5:3
		VGA_MODE_800X480,		VGA_MODE_WVGA,
		VGA_MODE_1280X768,	VGA_MODE_WXVGA,
		-- 16:9
		VGA_MODE_854X480,		VGA_MODE_FWVGA,
		VGA_MODE_1280X720,	VGA_MODE_HD720,
		VGA_MODE_1366X768,
		VGA_MODE_1920X1080,	VGA_MODE_HD1080,
		-- 17:9
		VGA_MODE_2048X1080,	VGA_MODE_2K
	);

	-- Timing and polarity parameters.
  type T_VGA_PARAMETERS is record
		haddr			: positive;						-- displayed horizontal pixels
		htotal_e	: positive;						-- end	of htotal (inclusive)
		hsync_b 	: positive;						-- begin of hsync
		hsync_e 	: positive;						-- end	of hsync  (inclusive)
		vaddr			: positive;						-- displayed vertical pixels
		vtotal_e	: positive;						-- end	of vtotal (inclusive)
		vsync_b 	: positive;						-- begin of vsync
		vsync_e 	: positive;						-- end	of vsync  (inclusive)
		hs_pol		: std_logic;					-- hsync polarity
		vs_pol		: std_logic;					-- vsync_polarity
  end record;

	function io_vga_GetParameters(Mode : T_IO_VGA_MODE; CVT : boolean) return T_VGA_PARAMETERS;

  -- Control signals which must be passed from the timing module through
  -- the data processing pipeline to the physical layer controller.
  type T_IO_VGA_PHY_CTRL is record
    hsync		: std_logic;
    vsync		: std_logic;
    beam_on	: std_logic;
  end record;

	component vga_timing
		generic (
			MODE				: T_IO_VGA_MODE		:= VGA_MODE_VGA;
			CVT					: boolean					:= false			-- Coordinated Video Timing
		);
		port (
			clk					: in	std_logic;
			rst					: in	std_logic;
			phy_ctrl		: out	T_IO_VGA_PHY_CTRL;
			xvalid			: out	std_logic;
			yvalid			: out	std_logic;
			line_end		: out	std_logic;
			screen_end	: out	std_logic;
			xpos				: out	unsigned(11 downto 0);
			ypos				: out	unsigned(10 downto 0)
		);
	end component;

	component vga_phy
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
	end component;

	component vga_phy_ch7301c is
		port (
			clk0				: in	std_logic;
			clk90				: in	std_logic;
			phy_ctrl		: in	T_IO_VGA_PHY_CTRL;
			pixel_data	: in	std_logic_vector(23 downto 0);
			dvi_xclk_p	: out	std_logic;
			dvi_xclk_n	: out	std_logic;
			dvi_h				: out	std_logic;
			dvi_v				: out	std_logic;
			dvi_de			: out	std_logic;
			dvi_d				: out	std_logic_vector(11 downto 0)
		);
	end component;
end package;


package body vga is

  -- Calculate timing parameters
  function io_vga_GetParameters(Mode : T_IO_VGA_MODE; CVT : boolean) return T_VGA_PARAMETERS is
		variable res : T_VGA_PARAMETERS;
  begin
		case Mode is
			when VGA_MODE_640X480 | VGA_MODE_VGA =>			-- VGA 640x480
				res.haddr			:= 640;
				res.vaddr			:= 480;
				res.htotal_e	:= 800-1;
				res.hsync_b 	:= res.haddr+16;						-- + h_front_porch
				res.hs_pol		:= '0';

				if CVT then
						res.vtotal_e	:= 500-1;
						res.hsync_e 	:= res.hsync_b+64-1;
						res.vsync_b 	:= res.vaddr+3;						-- + v_front_porch
						res.vsync_e 	:= res.vsync_b+4-1;
						res.vs_pol		:= '1';
				else
						res.vtotal_e	:= 525-1;
						res.hsync_e 	:= res.hsync_b+96-1;
						res.vsync_b 	:= res.vaddr+10;					-- + v_front_porch
						res.vsync_e 	:= res.vsync_b+2-1;
						res.vs_pol		:= '0';
				end if;

			when VGA_MODE_1280X720 | VGA_MODE_HD720 =>		-- HD 720p 1280x720
				res.haddr			:= 1280;
				res.htotal_e	:= 1664-1;							-- hor_total -1
				res.hsync_b 	:= res.haddr+64;				-- + h_front_porch
				res.hsync_e 	:= res.hsync_b+128-1; 	-- + hor_sync -1
				res.vaddr			:= 720;
				res.vtotal_e	:= 748-1;								-- ver_total -1
				res.vsync_b 	:= res.vaddr+3;					-- + v_front_porch
				res.vsync_e 	:= res.vsync_b+5-1;			-- + ver_sync -1
				res.hs_pol		:= '0';									-- negative
				res.vs_pol		:= '1';									-- positive

			when VGA_MODE_1920X1080 | VGA_MODE_HD1080 =>	-- HD 720p 1280x720
				res.haddr			:= 1920;
				res.htotal_e	:= 2080-1;							-- hor_total -1
				res.hsync_b 	:= res.haddr+48;				-- + h_front_porch
				res.hsync_e 	:= res.hsync_b+32-1;		-- + hor_sync -1
				res.vaddr			:= 1080;
				res.vtotal_e	:= 1111-1;							-- ver_total -1
				res.vsync_b 	:= res.vaddr+3;					-- + v_front_porch
				res.vsync_e 	:= res.vsync_b+5-1;			-- + ver_sync -1
				res.hs_pol		:= '1';									-- positive
				res.vs_pol		:= '0';									-- negative

			when others =>
				report "MODE " & T_IO_VGA_MODE'image(Mode) & " is not supported!"
					severity failure;

		end case;

		return res;
  end function;

end package body;
