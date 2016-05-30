-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- =============================================================================
-- Testbench:				Tests global constants, functions and settings
--
-- Authors:					Thomas B. Preusser
--									Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
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

library IEEE;
use			IEEE.std_logic_1164.all;


entity physical_tb is
	port (
		input			: in std_logic;
		output		: out std_logic
	);
end;


library	PoC;
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.simulation.all;


architecture tb of physical_tb is
	signal SimQuiet		: BOOLEAN		:= true;

	constant CLOCK_FREQ		: FREQ			:= 100 MHz;
	constant delay				: T_DELAY		:= 256.8 ns;

	constant cycles				: POSITIVE	:= TimingToCycles(delay, CLOCK_FREQ);

	constant Time1				: TIME			:= 10 ns;
	constant Time2				: TIME			:= 0.5 us;

begin
	assert false report "CLOCK_FREQ: " & FREQ'image(CLOCK_FREQ) severity note;
	assert false report "CLOCK_FREQ: " & to_string(CLOCK_FREQ)  severity note;

	output		<= input;

	process

		variable res1		: INTEGER;
		variable res2		: REAL;
	begin
		res1		:= Time1 / Time2;
		res2		:= real((Time1 * 1000) / Time2) / 1000.0;

		report "res1=" & INTEGER'image(res1);
		report "res2=" & REAL'image(res2);
		report "CLOCK_FREQ: " & FREQ'image(CLOCK_FREQ) severity note;
		report "CLOCK_FREQ: " & to_string(CLOCK_FREQ)  severity note;
		-- simulation completed

		-- Report overall simulation result
		tbPrintResult;
		wait;
	end process;
end;
