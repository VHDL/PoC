-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 
-- Testbench:				Pseudo-Random Number Generator (PRNG).
-- 
-- Description:
-- ------------------------------------
--		Automated testbench for PoC.arith_prng
--		The Pseudo-Random Number Generator is instantiated for 8 bits. The
--		output sequence is compared to 256 pre calculated values.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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

library OSVVM;
use			OSVVM.CoveragePkg.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.components.all;
-- simulation only packages
use			PoC.sim_global.all;
use			PoC.sim_types.all;
use			PoC.simulation.all;


entity sim_ClockGenerator_tb is
end entity;


architecture test of sim_ClockGenerator_tb is
	constant CLOCK_FREQ							: FREQ					:= 100 MHz;
	constant NO_CLOCK_PHASE					: T_PHASE				:= 0 deg;

	constant simTestID	: T_SIM_TEST_ID		:= simCreateTest("Test clock generation");
	
	signal Clock					: STD_LOGIC;
	
	signal Clock_01				: STD_LOGIC;
	signal Clock_02				: STD_LOGIC;
	signal Clock_03				: STD_LOGIC;
	signal Clock_04				: STD_LOGIC;
	signal Clock_05				: STD_LOGIC;
	signal Clock_06				: STD_LOGIC;
	
	signal Clock_10				: STD_LOGIC;
	signal Clock_11				: STD_LOGIC;
	signal Clock_12				: STD_LOGIC;
	signal Clock_13				: STD_LOGIC;
	signal Clock_14				: STD_LOGIC;
	signal Clock_15				: STD_LOGIC;
	signal Clock_16				: STD_LOGIC;
	signal Clock_17				: STD_LOGIC;
	signal Clock_18				: STD_LOGIC;
	signal Clock_19				: STD_LOGIC;
	
	signal Clock_21				: STD_LOGIC;
	signal Clock_22				: STD_LOGIC;
	signal Clock_23				: STD_LOGIC;
	signal Clock_24				: STD_LOGIC;
	signal Clock_25				: STD_LOGIC;
	
	signal Clock_31				: STD_LOGIC;
	signal Clock_32				: STD_LOGIC;
	signal Clock_33				: STD_LOGIC;
	signal Clock_34				: STD_LOGIC;
	signal Clock_35				: STD_LOGIC;

	signal Clock_40							: STD_LOGIC;
	signal Clock_41							: STD_LOGIC;
	signal Clock_42							: STD_LOGIC;
	signal Counter_Clock_40_us	: UNSIGNED(15 downto 0)		:= (others => '0');
	signal Counter_Clock_41_us	: UNSIGNED(15 downto 0)		:= (others => '0');
	signal Counter_Clock_42_us	: UNSIGNED(15 downto 0)		:= (others => '0');
	signal Counter_41_cmp				: UNSIGNED(1 downto 0);
	signal Counter_42_cmp				: UNSIGNED(1 downto 0);
	signal Drift_Clock_41				: SIGNED(15 downto 0);
	signal Drift_Clock_42				: SIGNED(15 downto 0);
	
	signal Clock_50							: STD_LOGIC;
	signal Mean_Clock_50				: SIGNED(15 downto 0);
	signal Debug1								: INTEGER;
	signal Debug2								: SIGNED(15 downto 0);

	signal Reset_1							: STD_LOGIC;
	signal Reset_2							: STD_LOGIC;
	
begin
	-- initialize global simulation status
	simInitialize;
	
	simGenerateClock(Clock, CLOCK_FREQ / 2);
	
	-- generate global testbench clock
	simGenerateClock(Clock_01, CLOCK_FREQ,	 0 deg);
	simGenerateClock(Clock_02, CLOCK_FREQ,  90 deg);
	simGenerateClock(Clock_03, CLOCK_FREQ, 180 deg);
	simGenerateClock(Clock_04, CLOCK_FREQ, 270 deg);
	simGenerateClock(Clock_05, CLOCK_FREQ, 360 deg);
	simGenerateClock(Clock_06, CLOCK_FREQ, -90 deg);
	
	simGenerateClock(Clock_10, CLOCK_FREQ, NO_CLOCK_PHASE, 0.0);
	simGenerateClock(Clock_11, CLOCK_FREQ, NO_CLOCK_PHASE, 0.1);
	simGenerateClock(Clock_12, CLOCK_FREQ, NO_CLOCK_PHASE, 0.2);
	simGenerateClock(Clock_13, CLOCK_FREQ, NO_CLOCK_PHASE, 0.3);
	simGenerateClock(Clock_14, CLOCK_FREQ, NO_CLOCK_PHASE, 0.4);
	simGenerateClock(Clock_15, CLOCK_FREQ, NO_CLOCK_PHASE, 0.5);
	simGenerateClock(Clock_16, CLOCK_FREQ, NO_CLOCK_PHASE, 0.6);
	simGenerateClock(Clock_17, CLOCK_FREQ, NO_CLOCK_PHASE, 0.7);
	simGenerateClock(Clock_18, CLOCK_FREQ, NO_CLOCK_PHASE, 0.8);
	simGenerateClock(Clock_19, CLOCK_FREQ, NO_CLOCK_PHASE, 0.9);
	
	simGenerateClock(Clock_21, CLOCK_FREQ,	 0 deg, 0.25);
	simGenerateClock(Clock_22, CLOCK_FREQ,  90 deg, 0.25);
	simGenerateClock(Clock_23, CLOCK_FREQ, 180 deg, 0.25);
	simGenerateClock(Clock_24, CLOCK_FREQ, 270 deg, 0.25);
	simGenerateClock(Clock_25, CLOCK_FREQ, 360 deg, 0.25);
	
	simGenerateClock(Clock_31, CLOCK_FREQ,	 0 deg, 0.75);
	simGenerateClock(Clock_32, CLOCK_FREQ,  90 deg, 0.75);
	simGenerateClock(Clock_33, CLOCK_FREQ, 180 deg, 0.75);
	simGenerateClock(Clock_34, CLOCK_FREQ, 270 deg, 0.75);
	simGenerateClock(Clock_35, CLOCK_FREQ, 360 deg, 0.75);

	simGenerateClock(Clock_40, CLOCK_FREQ, Wander =>	0 percent);
	simGenerateClock(Clock_41, CLOCK_FREQ, Wander =>	5 permil);		-- clock drift of 0.5% (5 permil)	 => shift by 1 UI every 200 cycles
	simGenerateClock(Clock_42, CLOCK_FREQ, Wander => 10 permil);		-- clock drift of 1.0% (10 permil) => shift by 1 UI every 100 cycles

	Counter_Clock_40_us		<= upcounter_next(cnt => Counter_Clock_40_us) when rising_edge(Clock_40);
	Counter_Clock_41_us		<= upcounter_next(cnt => Counter_Clock_41_us) when rising_edge(Clock_41);
	Counter_Clock_42_us		<= upcounter_next(cnt => Counter_Clock_42_us) when rising_edge(Clock_42);
	Counter_41_cmp				<= comp(Counter_Clock_40_us, Counter_Clock_41_us);
	Counter_42_cmp				<= comp(Counter_Clock_40_us, Counter_Clock_42_us);

	process
	begin
		Drift_Clock_41		<= (others => '0');
		wait until rising_edge(Clock_40);
		wait until rising_edge(Clock_41);
		while (TRUE) loop
			wait until rising_edge(Clock_41);
			Drift_Clock_41		<= to_signed((Clock_40'last_event - Clock_41'last_event) / 10 ps, Drift_Clock_41'length);
		end loop;
	end process;
	
	process
	begin
		Drift_Clock_42		<= (others => '0');
		wait until rising_edge(Clock_40);
		wait until rising_edge(Clock_42);
		while (TRUE) loop
			wait until rising_edge(Clock_42);
			Drift_Clock_42		<= to_signed((Clock_40'last_event - Clock_42'last_event) / 10 ps, Drift_Clock_42'length);
		end loop;
	end process;

	simGenerateClock2(Clock_50, Debug1, to_time(CLOCK_FREQ));

	Debug2	<= to_signed(Debug1, Debug2'length);

	process
		variable Sum					: INTEGER;
		variable Count				: NATURAL;
		variable Rand					: INTEGER;
		variable RandPointer	: NATURAL;
		variable RandBuffer		: T_INTVEC(0 to 31);

		variable CovBin1			: CovPType;
	begin
		CovBin1.AddBins(GenBin(0, 512));

		Sum							:= 0;
		Count						:= 0;
		Mean_Clock_50		<= (others => '0');
		RandPointer			:= 0;
		RandBuffer			:= (others => 256);

		wait until rising_edge(Clock_50);
		while (not simIsStopped) loop
			wait until rising_edge(Clock_50);
			Sum												:= Sum - RandBuffer(RandPointer);

			Rand											:= Debug1;-- + 256;
			CovBin1.ICover(Rand);

			RandBuffer(RandPointer)		:= Rand;
			RandPointer								:= (RandPointer + 1) mod RandBuffer'length;

			Sum							:= Sum + Rand;
			Count						:= Count + 1;
			Mean_Clock_50		<= to_signed((Sum / imax(RandBuffer'length, Count + 1)), Mean_Clock_50'length);
		end loop;

		CovBin1.WriteBin("sim_ClockGenerator_tb.osvvm.log");
	end process;
	


	simGenerateWaveform(Reset_1, simGenerateWaveform_Reset(Pause => 10 ns, ResetPulse => 10 ns));

	-- procChecker_1 : process
		-- constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Checker_1");
	-- begin
	
		-- simWaitUntilRisingEdge(Clock_01, 99);
		-- simWaitUntilFallingEdge(Clock_01, 99);
	
		-- -- This process is finished
		-- simDeactivateProcess(simProcessID);
		-- simFinalize;
		-- wait;  -- forever
	-- end process;
	
	procChecker_2 : process
		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Checker_2");
	begin
	
		simWaitUntilRisingEdge(Clock, 5000);
		simWaitUntilFallingEdge(Clock, 5000);
	
		-- This process is finished
		simDeactivateProcess(simProcessID);
		simFinalize;
		wait;  -- forever
	end process;
end architecture;
