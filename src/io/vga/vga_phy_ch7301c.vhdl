-- EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Martin Zabel
--
-- Entity:					PhysicalLayer controller for external CH7301C DVI Transmitter.
--
-- Description:
-- -------------------------------------
--	The clock frequency must be the same as used for the timing module,
--	e.g., 25 MHZ for VGA 640x480. A phase-shifted clock must be provided:
--	- clk0	:		0 degrees
--	- clk90	:	90 degrees
--
--	pixel_data(23 downto 16) : red
--	pixel_data(15 downto	8) : green
--	pixel_data( 7 downto	0) : blue
--
--	The "reset_b"-pin must be driven by other logic (such as the reset button).
--
--	The IIC_interface is not part of this modules, as an IIC-master controls
--	several slaves. The following registers must be set, see
--	tests/ml505/vga_test_ml505.vhdl for an example.
--
--	Register			Value				Description
--	-----------------------------------
--	0x49 PM				0xC0				Enable DVI, RGB bypass off
--						 or 0xD0				Enable DVI, RGB bypass on
--	0x33 TPCP			0x08 if clk_freq <= 65 MHz else 0x06
--	0x34 TPD			0x16 if clk_freq <= 65 MHz else 0x26
--	0x36 TPF			0x60 if clk_freq <= 65 MHz else 0xA0
--	0x1F IDF			0x80				when using SMT (VS0, HS0)
--						 or 0x90				when using CVT (VS1, HS0)
--	0x21 DC				0x09				Enable DAC if RGB bypass is on
--
-- License:
-- =============================================================================
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
-- =============================================================================

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;
use			PoC.vga.all;


entity vga_phy_ch7301c is
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
end entity;


architecture rtl of vga_phy_ch7301c is
	signal data					: std_logic_vector(23 downto 0);

	signal dvi_h_r			: std_logic;
	signal dvi_v_r			: std_logic;
	signal dvi_de_r			: std_logic;

	attribute iob				: string;
	attribute iob of dvi_h_r	: signal is "TRUE";
	attribute iob of dvi_v_r	: signal is "TRUE";
	attribute iob of dvi_de_r	: signal is "TRUE";

begin
	-- CH7301C Input Data Format "RGB" (IDF 0)
	-- Blank on beam return.
	data <= pixel_data and (pixel_data'range => phy_ctrl.beam_on);

	-- Timing: Data changes with 0 / 180 degrees.
	-- Clock changes with 90 degrees.

	-- Mirror clk90
	xclk_out : entity PoC.ddrio_out
		generic map (
			NO_OUTPUT_ENABLE	=> true,
			BITS							=> 2
		)
		port map (
			Clock					=> clk90,
			ClockEnable		=> '1',
			OutputEnable	=> '1',
			DataOut_high	=> "01",
			DataOut_low		=> "10",
			Pad(0)				=> dvi_xclk_p,
			Pad(1)				=> dvi_xclk_n
		);

	-- Output control signals (single data rate)
	-- Registers must be placed into IOBs.
	process (clk0)
	begin
		if rising_edge(clk0) then
			dvi_h_r		<= phy_ctrl.hsync;
			dvi_v_r		<= phy_ctrl.vsync;
			dvi_de_r	<= phy_ctrl.beam_on;
		end if;
	end process;

	dvi_v		<= dvi_v_r;
	dvi_h		<= dvi_h_r;
	dvi_de	<= dvi_de_r;

	-- Output data signals (dual data rate)
	data_out : entity PoC.ddrio_out
		generic map (
			NO_OUTPUT_ENABLE	=> true,
			BITS							=> 12
		)
		port map (
			Clock					=> clk0,
			ClockEnable		=> '1',
			OutputEnable	=> '1',
			DataOut_high	=> data(11 downto	0),
			DataOut_low		=> data(23 downto 12),
			Pad						=> dvi_d
		);
end architecture;
