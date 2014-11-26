-- EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
--            ____        ____    _     _ _
--           |  _ \ ___  / ___|  | |   (_) |__  _ __ __ _ _ __ _   _
--           | |_) / _ \| |      | |   | | '_ \| '__/ _` | '__| | | |
--           |  __/ (_) | |___   | |___| | |_) | | | (_| | |  | |_| |
--           |_|   \___/ \____|  |_____|_|_.__/|_|  \__,_|_|   \__, |
--                                                             |___/
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		This is a vendor, device and protocol specific instanziation of a 7-Series
--		GTXE2 transceiver. This GTX is configured for Serial-ATA from Gen1 to Gen3
--		with linerates from 1.5 GHz to 6.0 GHz. It has a 'RP_SATAGeneration' dependant
--		user interface frequency of 37.5 MHz up to 150 MHz at Gen3. The data interface
--		has a constant width of 32 bit per data word and 4 CharIsK marker bits.
-- 
-- License:
-- -----------------------------------------------------------------------------
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
use			PoC.components.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;


entity misc_Watch is
	generic (
		CLOCK_FREQ		: FREQ		:= 100 MHz
	);
	port (
		Clock					: IN	STD_LOGIC;
		Reset					: IN	STD_LOGIC;
		
		Ticks					: OUT	STD_LOGIC_VECTOR(23 downto 0)
		
		
	);
end;

architecture rtl of misc_Watch is
	function cond_inc(condition : STD_LOGIC; value : UNSIGNED) return UNSIGNED is
	begin
		return mux(condition, value, (value + 1));
	end function;

	signal Tick1_us								: UNSIGNED(6 downto 0)		:= (others => '0');
	signal Tick2_us								: UNSIGNED(3 downto 0)		:= (others => '0');
	signal TickCounter_us					: UNSIGNED(23 downto 0)		:= (others => '0');
	signal USecondCounter_us			: UNSIGNED(9 downto 0)		:= (others => '0');
	signal MSecondCounter_us			: UNSIGNED(9 downto 0)		:= (others => '0');
	signal SecondCounter_us				: UNSIGNED(5 downto 0)		:= (others => '0');
	signal MinuteCounter_us				: UNSIGNED(5 downto 0)		:= (others => '0');
	signal HourCounter_us					: UNSIGNED(4 downto 0)		:= (others => '0');
	signal DayOfWeekCounter_us		: UNSIGNED(2 downto 0)		:= (others => '0');
	signal DayOfMonthCounter_us		: UNSIGNED(4 downto 0)		:= (others => '0');
	signal DayOfYearCounter_us		: UNSIGNED(8 downto 0)		:= (others => '0');
	signal WeekCounter_us					: UNSIGNED(5 downto 0)		:= (others => '0');
	signal MonthCounter_us				: UNSIGNED(3 downto 0)		:= (others => '0');
	signal YearCounter_us					: UNSIGNED(12 downto 0)		:= (others => '0');
	
	signal Tick1_rst							: STD_LOGIC;
	signal Tick1_cmp							: STD_LOGIC								:= '0';
	signal Tick2_rst							: STD_LOGIC;
	signal Tick2_cmp							: STD_LOGIC								:= '0';
	signal TickCounter_rst				: STD_LOGIC;
	signal TickCounter_cmp				: STD_LOGIC								:= '0';
	signal USecondCounter_rst			: STD_LOGIC;
	signal USecondCounter_cmp			: STD_LOGIC								:= '0';
	signal MSecondCounter_rst			: STD_LOGIC;
	signal MSecondCounter_cmp			: STD_LOGIC								:= '0';
	signal SecondCounter_rst			: STD_LOGIC;
	signal SecondCounter_cmp			: STD_LOGIC								:= '0';
	signal MinuteCounter_rst			: STD_LOGIC;
	signal MinuteCounter_cmp			: STD_LOGIC								:= '0';
	signal HourCounter_rst				: STD_LOGIC;
	signal HourCounter_cmp				: STD_LOGIC								:= '0';
	signal DayOfWeekCounter_rst		: STD_LOGIC;
	signal DayOfWeekCounter_cmp		: STD_LOGIC								:= '0';
	signal DayOfMonthCounter_rst	: STD_LOGIC;
	signal DayOfMonthCounter_cmp	: STD_LOGIC								:= '0';
	signal DayOfYearCounter_rst		: STD_LOGIC;
	signal DayOfYearCounter_cmp		: STD_LOGIC								:= '0';
	signal WeekCounter_rst				: STD_LOGIC;
	signal WeekCounter_cmp				: STD_LOGIC								:= '0';
	signal MonthCounter_rst				: STD_LOGIC;
	signal MonthCounter_cmp				: STD_LOGIC								:= '0';
	signal YearCounter_rst				: STD_LOGIC;
	signal YearCounter_cmp				: STD_LOGIC								:= '0';
begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Tick1_us							<= (others => '0');
				Tick2_us							<= (others => '0');
				TickCounter_us				<= (others => '0');
				USecondCounter_us			<= (others => '0');
				MSecondCounter_us			<= (others => '0');
				SecondCounter_us			<= (others => '0');
				MinuteCounter_us			<= (others => '0');
				HourCounter_us				<= (others => '0');
				DayOfWeekCounter_us		<= (others => '0');
				DayOfMonthCounter_us	<= (others => '0');
				DayOfYearCounter_us		<= (others => '0');
				WeekCounter_us				<= (others => '0');
				MonthCounter_us				<= (others => '0');
				YearCounter_us				<= (others => '0');
			else
				if (Tick1_rst = '1') then
					Tick1_us						<= (others => '0');
				else
					Tick1_us						<= Tick1_us + 1;
				end if;
				Tick1_cmp							<= to_sl(Tick1_us = 8);

				if (TickCounter_rst = '1') then
					TickCounter_us			<= (others => '0');
				else
					TickCounter_us			<= cond_inc(Tick1_rst, TickCounter_us);
				end if;
				TickCounter_cmp				<= to_sl(TickCounter_us = ite(SIMULATION, 999, 9999999));

				if (Tick2_rst = '1') then
					Tick2_us						<= (others => '0');
				else
					Tick2_us						<= cond_inc(Tick1_rst, Tick2_us);
				end if;
				Tick2_cmp							<= to_sl(Tick2_us = 9);

				if (USecondCounter_rst = '1') then
					USecondCounter_us		<= (others => '0');
				else
					USecondCounter_us		<= cond_inc(Tick2_rst, USecondCounter_us);
				end if;
				USecondCounter_cmp		<= to_sl(USecondCounter_us = ite(SIMULATION, 9, 999));

				if (MSecondCounter_rst = '1') then
					MSecondCounter_us		<= (others => '0');
				else
					MSecondCounter_us		<= cond_inc(USecondCounter_rst, MSecondCounter_us);
				end if;
				MSecondCounter_cmp		<= to_sl(MSecondCounter_us = ite(SIMULATION, 9, 999));

				if (SecondCounter_rst = '1') then
					SecondCounter_us		<= (others => '0');
				else
					SecondCounter_us		<= cond_inc(TickCounter_rst, SecondCounter_us);
				end if;
				SecondCounter_cmp			<= to_sl(SecondCounter_us = ite(SIMULATION, 5, 59));

				if (MinuteCounter_rst = '1') then
					MinuteCounter_us		<= (others => '0');
				else
					MinuteCounter_us		<= cond_inc(SecondCounter_rst, MinuteCounter_us);
				end if;
				MinuteCounter_cmp			<= to_sl(MinuteCounter_us = ite(SIMULATION, 5, 59));
				
				if (HourCounter_rst = '1') then
					HourCounter_us			<= (others => '0');
				else
					HourCounter_us			<= cond_inc(MinuteCounter_rst, HourCounter_us);
				end if;
				HourCounter_cmp				<= to_sl(HourCounter_us = ite(SIMULATION, 3, 23));
				
				if (DayOfYearCounter_rst = '1') then
					DayOfYearCounter_us	<= (others => '0');
				else
					DayOfYearCounter_us	<= cond_inc(HourCounter_rst, DayOfYearCounter_us);
				end if;
				DayOfYearCounter_cmp	<= to_sl(DayOfYearCounter_us = 364);

			end if;
		end if;
	end process;

	Tick1_rst							<= Tick1_cmp;
	TickCounter_rst				<= Tick1_cmp and TickCounter_cmp;				
	Tick2_rst							<= Tick1_cmp and Tick2_cmp;				
	USecondCounter_rst		<= Tick1_cmp and Tick2_cmp and USecondCounter_cmp;				
	MSecondCounter_rst		<= Tick1_cmp and Tick2_cmp and USecondCounter_cmp and MSecondCounter_cmp;				
	SecondCounter_rst			<= Tick1_cmp and TickCounter_cmp and SecondCounter_cmp;
	MinuteCounter_rst			<= Tick1_cmp and TickCounter_cmp and SecondCounter_cmp and MinuteCounter_cmp;
	HourCounter_rst				<= Tick1_cmp and TickCounter_cmp and SecondCounter_cmp and MinuteCounter_cmp and HourCounter_cmp;
	DayOfYearCounter_rst	<= Tick1_cmp and TickCounter_cmp and SecondCounter_cmp and MinuteCounter_cmp and HourCounter_cmp and DayOfYearCounter_cmp;

	Ticks				<= std_logic_vector(TickCounter_us);
end;
