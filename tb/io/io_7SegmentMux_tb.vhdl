-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- =============================================================================
-- Testbench:				7-SegmentDisplay Time-Multiplexer
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		Automated testbench for PoC.io.7SegmentMux_BCD
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
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.simulation.all;


entity io_7SegmentMux_tb is
end;


architecture test of io_7SegmentMux_tb is
	constant CLOCK_FREQ	: FREQ				:= 100 MHz;

	signal SimStop				: std_logic 	:= '0';

	signal Clock					: STD_LOGIC		:= '1';

	constant DIGITS				: POSITIVE		:= 5;

	signal BCDDigits			: T_BCD_VECTOR(DIGITS - 1 downto 0);
	signal BCDDots				: STD_LOGIC_VECTOR(DIGITS - 1 downto 0);
	signal HEXDigits			: T_SLVV_4(DIGITS - 1 downto 0);
	signal HEXDots				: STD_LOGIC_VECTOR(DIGITS - 1 downto 0);

	signal BCD_SegmentControl	: STD_LOGIC_VECTOR(7 downto 0);
	signal BCD_DigitControl		: STD_LOGIC_VECTOR(DIGITS - 1 downto 0);
	signal HEX_SegmentControl	: STD_LOGIC_VECTOR(7 downto 0);
	signal HEX_DigitControl		: STD_LOGIC_VECTOR(DIGITS - 1 downto 0);

begin
	blkClock : block
		constant CLOCK_PERIOD		: TIME	:= to_time(CLOCK_FREQ);
	begin
		Clock <= Clock xnor SimStop after CLOCK_PERIOD / 2.0;
	end block;

	process
	begin
		wait until rising_edge(Clock);

		BCDDigits		<= (0 => C_BCD_MINUS, 1 => "0001", 2 => C_BCD_OFF, 3 => "0110", 4 => "1001");
		BCDDots			<= "01000";
		HEXDigits		<= (0 => "1100", 1 => "1010", 2 => "0000", 3 => "1111", 4 => "1110");
		HEXDots			<= "01000";

		for i in 0 to 99 loop
			wait until rising_edge(Clock);
		end loop;

		BCDDigits		<= (0 => "0001", 1 => "0010", 2 => "0011", 3 => "0100", 4 => "0101");
		BCDDots			<= "00100";
		HEXDigits		<= (0 => "1101", 1 => "1110", 2 => "1010", 3 => "1111", 4 => "1101");
		HEXDots			<= "01001";

		for i in 0 to 99 loop
			wait until rising_edge(Clock);
		end loop;

		wait until rising_edge(Clock);
		wait until rising_edge(Clock);

		-- Report overall simulation result
		tbPrintResult;
		SimStop	<= '1';
		wait;
	end process;

	Display_BCD : entity PoC.io_7SegmentMux_BCD
		generic map (
			CLOCK_FREQ			=> CLOCK_FREQ,
			REFRESH_RATE		=> 10 MHz,
			DIGITS					=> DIGITS
		)
		port map (
			Clock						=> Clock,

			BCDDigits				=> BCDDigits,
			BCDDots					=> BCDDots,

			SegmentControl	=> BCD_SegmentControl,
			DigitControl		=> BCD_DigitControl
		);


	Display_HEX : entity PoC.io_7SegmentMux_HEX
		generic map (
			CLOCK_FREQ			=> CLOCK_FREQ,
			REFRESH_RATE		=> 10 MHz,
			DIGITS					=> DIGITS
		)
		port map (
			Clock						=> Clock,

			HEXDigits				=> HEXDigits,
			HEXDots					=> HEXDots,

			SegmentControl	=> HEX_SegmentControl,
			DigitControl		=> HEX_DigitControl
		);
end;
