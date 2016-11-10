-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Peter Reichel
--									Martin Zabel
--									Patrick Lehmann
--
-- Entity:					Generates Timing for several VGA/VESA video modes.
--
-- Description:
-- -------------------------------------
-- Configuration:
-- --------------
-- MODE = 0: VGA mode with  640x480  pixels, 60 Hz, frequency(clk) ~  25	MHz
-- MODE = 1: HD  720p with 1280x720  pixels, 60 Hz, frequency(clk) =  74,5 MHz
-- MODE = 2: HD 1080p with 1920x1080 pixels, 60 Hz, frequency(clk) = 138,5 MHz
--
-- MODE = 2 uses reduced blanking => only suitable for LCDs.
--
-- For MODE = 0, CVT can be configured:
-- - CVT = false: Use Safe Mode Timing (SMT).
-- 	 The legacy fall-back mode supported by CRTs as well as LCDs.
-- 	 HSync: low-active. VSync: low-active.
-- 	 frequency(clk) = 25.175 MHz. (25 MHz works => 31 kHz / 59 Hz)
-- - CVT = true: The "new" Coordinated Video Timing (since 2003).
-- 	 The CVT supports some new features, such as reduced blanking (for LCDs) or
-- 	 aspect ratio encoding. See the web for more details.
-- 	 Standard CRT-based timing (CVT-GTF) has been implemented for best
-- 	 compatibility:
-- 	 HSync: low-active. VSync: high-active.
-- 	 frequency(clk) = 23.75 MHz. (25 MHz works => 31 kHz / 62 Hz)
--
-- Usage:
-- ------
-- The frequency of ``clk`` must be equal to the pixel clock frequency of the
-- selected video mode, see also above.
--
-- When using analog output, the VGA color signals must be blanked, during
-- horizontal and vertical beam return. This could be achieved by
-- combinatorial "anding" the color value with "beam_on" (part of "phy_ctrl")
-- inside the PHY.
--
-- When using digital output (DVI), then "beam_on" is equal to "DE"
-- (Data Enable) of the DVI transmitter.
--
-- xvalid and yvalid show if xpos respectivly ypos are in a valid range.
-- beam_on is '1' iff both xvalid and yvalid = '1'.
--
-- xpos and ypos also show the pixel location during blanking.
-- This might be useful in some applications. But be careful, that the ranges
-- differ between SMT and CVT.
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

library	PoC;
use			PoC.vga.all;


entity vga_timing is
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
end entity;


architecture rtl of vga_timing is
	constant PARAMETERS : T_VGA_PARAMETERS := io_vga_GetParameters(MODE, CVT);

	signal xcount : unsigned(11 downto 0);
	signal ycount : unsigned(10 downto 0);

	signal ctrl_rst_x : std_logic;
	signal ctrl_inc_x : std_logic;
	signal ctrl_rst_y : std_logic;
	signal ctrl_inc_y : std_logic;
	signal xvalid_nxt : std_logic;
	signal yvalid_nxt : std_logic;

begin
	-- counter register
	process(clk)
	begin
		if rising_edge(clk) then
			if (rst or ctrl_rst_x) = '1' then
				xcount <= to_unsigned(0, xcount'length);
			elsif ctrl_inc_x = '1' then
				xcount <= xcount + 1;
			end if;

			if (rst or ctrl_rst_y) = '1' then
				ycount <= to_unsigned(0, ycount'length);
			elsif ctrl_inc_y = '1' then
				ycount <= ycount + 1;
			end if;
		end if;
	end process;

	-- calculate internal control signals
	process(xcount, ycount)
	begin
		ctrl_rst_x		 <= '0';
		ctrl_inc_x		 <= '0';
		ctrl_rst_y		 <= '0';
		ctrl_inc_y		 <= '0';
		yvalid_nxt		 <= '0';
		xvalid_nxt		 <= '0';

		-- end of current line
		if xcount = PARAMETERS.htotal_e then
			ctrl_inc_y <= '1';
			ctrl_rst_x <= '1';
		else
			ctrl_inc_x <= '1';
		end if;

		-- end of current screen
		if xcount = PARAMETERS.htotal_e and ycount = PARAMETERS.vtotal_e then
			ctrl_rst_y <= '1';
		end if;

		-- yvalid
		if (ycount >= 0 and ycount < PARAMETERS.vaddr) then
			yvalid_nxt <= '1';
		end if;

		-- xvalid
		if (xcount >= 0 and xcount < PARAMETERS.haddr) then
			xvalid_nxt <= '1';
		end if;
	end process;

	-- calculate control signals for registered outputs
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				-- keep low during reset
				yvalid				 <= '0';
				xvalid				 <= '0';
				phy_ctrl.beam_on <= '0';
			else
				yvalid				 <= yvalid_nxt;
				xvalid				 <= xvalid_nxt;
				phy_ctrl.beam_on <= xvalid_nxt and yvalid_nxt;
			end if;

			line_end			<= ctrl_rst_x;
			screen_end		 <= ctrl_rst_y;
			xpos				 <= xcount;
			ypos				 <= ycount;

			-- hsync
			if xcount >= PARAMETERS.hsync_b and xcount <= PARAMETERS.hsync_e then
				phy_ctrl.hsync <= PARAMETERS.hs_pol;
			else
				phy_ctrl.hsync <= not PARAMETERS.hs_pol;
			end if;

			-- vsync
			if ycount >= PARAMETERS.vsync_b and ycount <= PARAMETERS.vsync_e then
				phy_ctrl.vsync <= PARAMETERS.vs_pol;
			else
				phy_ctrl.vsync <= not PARAMETERS.vs_pol;
			end if;
		end if;
	end process;
end architecture;
