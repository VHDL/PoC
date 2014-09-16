-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Testbench:				Pseudo-Random Number Generator (PRNG).
-- 
-- Authors:					Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		Automated testbench for 'PoC.io_Debounce'.
--		TODO
--
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.simulation.all;


entity io_Debounce_tb is
end;


architecture test of io_Debounce_tb is 
	constant CLOCK_FREQ			: FREQ					:= 100.0 MHz;

	-- simulation signals
	signal SimStop					: STD_LOGIC 		:= '0';
	signal Clock						: STD_LOGIC			:= '1';

	signal EventCounter			: NATURAL				:= 0;
	
	signal dummy						: STD_LOGIC			:= '0';
	signal EventCounter2		: NATURAL				:= 0;
	
	-- unit Under Test (UUT) configuration
	constant DEBOUNCE_TIME	:	TIME					:= 50.0 ns;
	
	signal RawInput					: STD_LOGIC			:= '0';
	signal deb_out					: STD_LOGIC;

begin

	-- common clock generation
	Clock <= Clock xnor SimStop after (to_time(CLOCK_FREQ) / 2.0);
	
	process
	begin
		wait for 5 ns;
	
		dummy			<= '1';
	
		RawInput	<= '0';
		wait for 200 ns;
		
		RawInput	<= '1';
		wait for 200 ns;
		
		RawInput	<= '0';
		wait for 20 ns;

		RawInput	<= '1';
		wait for 20 ns;

		RawInput	<= '0';
		wait for 200 ns;
		
		RawInput	<= '1';
		wait for 20 ns;
		
		RawInput	<= '0';
		wait for 200 ns;

		RawInput	<= '1';
		wait for 100 ns;

		RawInput	<= '0';
		wait for 235 ns;

		-- shut down simulation
		RawInput	<= '0';
		
		-- final assertion
		tbAssert((EventCounter = 4), "Events counted=" & INTEGER'image(EventCounter) &	" Expected=4");
		
		-- Report overall simulation result
		tbPrintResult;
		SimStop	<= '1';
		wait;
	end process;

	process(deb_out)
	begin
		if deb_out'event then
			report "deb_out=" & to_char(deb_out) & " deb_out'last_value=" & to_char(deb_out'last_value) severity note;
			EventCounter <= EventCounter + 1;
		end if;
	end process;
	
	process(dummy)
	begin
		if dummy'event then
			report "dummy=" & to_char(dummy) & " dummy'last_value=" & to_char(dummy'last_value) severity note;
			EventCounter2 <= EventCounter2 + 1;
		end if;
	end process;
	
	uut : entity PoC.io_Debounce
		generic map (
			CLOCK_FREQ				=> CLOCK_FREQ,			-- 
			DEBOUNCE_TIME			=> DEBOUNCE_TIME,		-- 
			BITS							=> 1								-- 1 bit
		)
		port map (
			Clock							=> Clock,
			Input(0)					=> RawInput,
			Output(0)					=> deb_out
		);
END;
