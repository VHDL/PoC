-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Thomas B. Preusser
-- 
-- Package:					Simulation constants, functions and utilities.
-- 
-- Description:
-- ------------------------------------
--		TODO
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
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;
use			IEEE.math_real.all;

library PoC;
use			PoC.utils.all;
-- use			PoC.strings.all;
use			PoC.vectors.all;
use			PoC.physical.all;

use			PoC.sim_global.all;
use			PoC.sim_types.all;
use			PoC.sim_protected.all;


package simulation is
	-- Legacy interface for pre VHDL-2002
	-- ===========================================================================
	procedure				simInitialize;
	procedure				simFinalize;
	
	impure function	simCreateTest(Name : STRING) return T_SIM_TEST_ID;
	procedure				simFinalizeTest(constant TestID : T_SIM_TEST_ID);
	impure function	simRegisterProcess(Name : STRING) return T_SIM_PROCESS_ID;
	impure function	simRegisterProcess(constant TestID : T_SIM_TEST_ID; Name : STRING) return T_SIM_PROCESS_ID;
	procedure				simDeactivateProcess(ProcID : T_SIM_PROCESS_ID);
	
	impure function	simIsStopped(constant TestID : T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) return BOOLEAN;
	
	procedure				simWriteMessage(Message : in STRING := "");
	
  -- The testbench is marked as failed. If a message is provided, it is
  -- reported as an error.
  procedure simFail(Message : in STRING := "");

  -- If the passed condition has evaluated false, the testbench is marked
  -- as failed. In this case, the optional message will be reported as an
  -- error if one was provided.
	procedure simAssertion(cond : in BOOLEAN; Message : in STRING := "");

	-- Random Numbers
	-- ===========================================================================
	type T_SIM_SEED is record
		Seed1	: INTEGER;
		Seed2	: INTEGER;
	end record;

	procedure initializeSeed(Seed : inout T_SIM_SEED);
	procedure getUniformDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Minimum : in REAL; Maximum : in REAL);
	procedure getNormalDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; StandardDeviation : in REAL := 1.0; Mean : in REAL := 0.0);
	procedure getNormalDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; StandardDeviation : in REAL; Mean : in REAL; Minimum : in REAL; Maximum : in REAL);
	procedure getPoissonDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Mean : in REAL);
	procedure getPoissonDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Mean : in REAL; Minimum : in REAL; Maximum : in REAL);

	-- clock generation
	-- ===========================================================================
	procedure simGenerateClock(
		signal	 Clock			: out	STD_LOGIC;
		constant Frequency	: in	FREQ;
		constant Phase			: in	T_PHASE			:=	0 deg;
		constant DutyCycle	: in	T_DUTYCYCLE	:= 50 percent;
		constant Wander			: in	T_WANDER		:=	0 permil
	);
	procedure simGenerateClock(
		constant TestID			: in	T_SIM_TEST_ID;
		signal	 Clock			: out	STD_LOGIC;
		constant Frequency	: in	FREQ;
		constant Phase			: in	T_PHASE			:=	0 deg;
		constant DutyCycle	: in	T_DUTYCYCLE	:= 50 percent;
		constant Wander			: in	T_WANDER		:=	0 permil
	);
	procedure simGenerateClock(
		signal	 Clock			: out	STD_LOGIC;
		constant Period			: in	TIME;
		constant Phase			: in	T_PHASE			:=	0 deg;
		constant DutyCycle	: in	T_DUTYCYCLE	:= 50 percent;
		constant Wander			: in	T_WANDER		:=	0 permil
	);
	procedure simGenerateClock(
		constant TestID			: in	T_SIM_TEST_ID;
		signal	 Clock			: out	STD_LOGIC;
		constant Period			: in	TIME;
		constant Phase			: in	T_PHASE			:=	0 deg;
		constant DutyCycle	: in	T_DUTYCYCLE	:= 50 percent;
		constant Wander			: in	T_WANDER		:=	0 permil
	);
	procedure simWaitUntilRisingEdge(signal Clock : in STD_LOGIC; constant Times : in POSITIVE);
	procedure simWaitUntilFallingEdge(signal Clock : in STD_LOGIC; constant Times : in POSITIVE);
	
	procedure simGenerateClock2(signal Clock : out STD_LOGIC; signal Debug : out REAL; constant Period : in TIME);

	-- waveform generation
	-- ===========================================================================
	procedure simGenerateWaveform(
		signal	 Wave					: out	BOOLEAN;
		constant Waveform			: in	T_TIMEVEC;
		constant InitialValue	: in	BOOLEAN					:= FALSE
	);
	procedure simGenerateWaveform(
		constant TestID				: in	T_SIM_TEST_ID;
		signal	 Wave					: out	BOOLEAN;
		constant Waveform			: in	T_TIMEVEC;
		constant InitialValue	: in	BOOLEAN					:= FALSE
	);
	procedure simGenerateWaveform(
		signal	 Wave					: out	STD_LOGIC;
		constant Waveform			: in	T_TIMEVEC;
		constant InitialValue	: in	STD_LOGIC				:= '0'
	);
	procedure simGenerateWaveform(
		constant TestID				: in	T_SIM_TEST_ID;
		signal	 Wave					: out	STD_LOGIC;
		constant Waveform			: in	T_TIMEVEC;
		constant InitialValue	: in	STD_LOGIC				:= '0'
	);
	procedure simGenerateWaveform(signal Wave : out STD_LOGIC;	Waveform: T_SIM_WAVEFORM_SL;			InitialValue : STD_LOGIC := '0');
	procedure simGenerateWaveform(signal Wave : out T_SLV_8;		Waveform: T_SIM_WAVEFORM_SLV_8;		InitialValue : T_SLV_8);
	procedure simGenerateWaveform(signal Wave : out T_SLV_16;		Waveform: T_SIM_WAVEFORM_SLV_16;	InitialValue : T_SLV_16);
	procedure simGenerateWaveform(signal Wave : out T_SLV_24;		Waveform: T_SIM_WAVEFORM_SLV_24;	InitialValue : T_SLV_24);
	procedure simGenerateWaveform(signal Wave : out T_SLV_32;		Waveform: T_SIM_WAVEFORM_SLV_32;	InitialValue : T_SLV_32);
	procedure simGenerateWaveform(signal Wave : out T_SLV_48;		Waveform: T_SIM_WAVEFORM_SLV_48;	InitialValue : T_SLV_48);
	procedure simGenerateWaveform(signal Wave : out T_SLV_64;		Waveform: T_SIM_WAVEFORM_SLV_64;	InitialValue : T_SLV_64);
	
	function simGenerateWaveform_Reset(constant Pause : TIME := 0 ns; ResetPulse : TIME := 10 ns) return T_TIMEVEC;
	

	-- TODO: integrate VCD simulation functions and procedures from sim_value_change_dump.vhdl here
	
	-- checksum functions
	-- ===========================================================================
	-- TODO: move checksum functions here
end package;


package body simulation is
	-- legacy procedures
	-- ===========================================================================
	-- TODO: undocumented group
	procedure simInitialize is
	begin
		globalSimulationStatus.initialize;
	end procedure;
	
	procedure simFinalize is
	begin
		globalSimulationStatus.finalize;
	end procedure;
	
	impure function simCreateTest(Name : STRING) return T_SIM_TEST_ID is
	begin
		return globalSimulationStatus.createTest(Name);
	end function;
	
	procedure simFinalizeTest(constant TestID : T_SIM_TEST_ID) is
	begin
		globalSimulationStatus.finalizeTest(TestID);
	end procedure;
	
	impure function simRegisterProcess(Name : STRING) return T_SIM_PROCESS_ID is
	begin
		return globalSimulationStatus.registerProcess(Name);
	end function;
	
	impure function simRegisterProcess(constant TestID : T_SIM_TEST_ID; Name : STRING) return T_SIM_PROCESS_ID is
	begin
		return globalSimulationStatus.registerProcess(TestID, Name);
	end function;
		
	procedure simDeactivateProcess(ProcID : T_SIM_PROCESS_ID) is
	begin
		globalSimulationStatus.deactivateProcess(ProcID);
	end procedure;
	
	impure function simIsStopped(constant TestID : T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) return BOOLEAN is
	begin
		return globalSimulationStatus.isStopped(TestID);
	end function;

	-- TODO: undocumented group
	procedure simWriteMessage(Message : in STRING := "") is
	begin
		globalSimulationStatus.writeMessage(Message);
	end procedure;
	
  procedure simFail(Message : in STRING := "") is
  begin
		globalSimulationStatus.fail(Message);
  end procedure;

  procedure simAssertion(cond : in BOOLEAN; Message : in STRING := "") is
	begin
		globalSimulationStatus.assertion(cond, Message);
	end procedure;


	-- ===========================================================================
	-- Random Numbers
	-- ===========================================================================
	procedure initializeSeed(Seed : inout T_SIM_SEED) is
	begin
		Seed.Seed1	:= 5;
		Seed.Seed2	:= 3423;
	end procedure;

	procedure getUniformDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Minimum : in REAL; Maximum : in REAL) is
		variable rand : REAL;
	begin
		if (Maximum < Minimum) then			report "getUniformDistibutedRandomValue: Maximum must be greater than Minimum."	severity FAILURE;		end if;
		ieee.math_real.Uniform(Seed.Seed1, Seed.Seed2, rand);
		Value := scale(rand, Minimum, Maximum);
	end procedure ;

	procedure getNormalDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; StandardDeviation : in REAL := 1.0; Mean : in REAL := 0.0) is
		variable rand1 : REAL;
		variable rand2 : REAL;
	begin
		if StandardDeviation < 0.0 then	report "getNormalDistibutedRandomValue: Standard deviation must be >= 0.0"			severity FAILURE;		end if;
		-- Box Muller transformation
		ieee.math_real.Uniform(Seed.Seed1, Seed.Seed2, rand1);
		ieee.math_real.Uniform(Seed.Seed1, Seed.Seed2, rand2);
		--													standard normal distribution: mean 0, variance 1
		Value := StandardDeviation * (sqrt(-2.0 * log(rand1)) * cos(MATH_2_PI * rand2)) + Mean;
	end procedure;

	procedure getNormalDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; StandardDeviation : in REAL; Mean : in REAL; Minimum : in REAL; Maximum : in REAL) is
		variable rand		: REAL;
	begin
		if (Maximum < Minimum) then			report "getNormalDistibutedRandomValue: Maximum must be greater than Minimum."	severity FAILURE;		end if;
		if StandardDeviation < 0.0 then	report "getNormalDistibutedRandomValue: Standard deviation must be >= 0.0"			severity FAILURE;		end if;
		while (TRUE) loop
			getNormalDistibutedRandomValue(Seed, rand, StandardDeviation, Mean);
			exit when ((Minimum <= rand) and (rand <= Maximum));
		end loop;
		Value := rand;
	end procedure;
	
	procedure getPoissonDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Mean : in REAL) is
		variable Product	: Real;
		variable Bound		: Real;
		variable rand			: Real;
		variable Result		: Real;
	begin
		Product	:= 1.0;
		Result	:= 0.0;
		Bound		:= exp(-1.0 * Mean);
		if ((Mean <= 0.0) or (Bound <= 0.0)) then
			report "getPoissonDistibutedRandomValue: Mean must be greater than 0.0." severity FAILURE;
			return;
		end if;
		
		while (Product >= Bound) loop
			ieee.math_real.Uniform(Seed.Seed1, Seed.Seed2, rand);
			Product		:= Product * rand;
			Result		:= Result + 1.0;
		end loop;
		Value	:= Result;
	end procedure;
	
	procedure getPoissonDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Mean : in REAL; Minimum : in REAL; Maximum : in REAL) is
		variable rand		: REAL;
	begin
		if (Maximum < Minimum) then			report "getPoissonDistibutedRandomValue: Maximum must be greater than Minimum."	severity FAILURE;		end if;
		while (TRUE) loop
			getPoissonDistibutedRandomValue(Seed, rand, Mean);
			exit when ((Minimum <= rand) and (rand <= Maximum));
		end loop;
		Value := rand;
	end procedure;
	
	-- clock generation
	-- ===========================================================================
	procedure simGenerateClock(
		signal	 Clock			: out	STD_LOGIC;
		constant Frequency	: in	FREQ;
		constant Phase			: in	T_PHASE			:=	0 deg;
		constant DutyCycle	: in	T_DUTYCYCLE	:= 50 percent;
		constant Wander			: in	T_WANDER		:=	0 permil
	) is
		constant Period : TIME := to_time(Frequency);
	begin
		simGenerateClock(C_SIM_DEFAULT_TEST_ID, Clock, Period, Phase, DutyCycle, Wander);
	end procedure;
	
	procedure simGenerateClock(
		constant TestID			: in	T_SIM_TEST_ID;
		signal	 Clock			: out	STD_LOGIC;
		constant Frequency	: in	FREQ;
		constant Phase			: in	T_PHASE			:=	0 deg;
		constant DutyCycle	: in	T_DUTYCYCLE	:= 50 percent;
		constant Wander			: in	T_WANDER		:=	0 permil
	) is
		constant Period : TIME := to_time(Frequency);
	begin
		simGenerateClock(TestID, Clock, Period, Phase, DutyCycle, Wander);
	end procedure;
	
	procedure simGenerateClock(
		signal	 Clock			: out	STD_LOGIC;
		constant Period			: in	TIME;
		constant Phase			: in	T_PHASE			:=	0 deg;
		constant DutyCycle	: in	T_DUTYCYCLE	:= 50 percent;
		constant Wander			: in	T_WANDER		:=	0 permil
	) is
	begin
		simGenerateClock(C_SIM_DEFAULT_TEST_ID, Clock, Period, Phase, DutyCycle, Wander);
	end procedure;
	
	procedure simGenerateClock(
		constant TestID			: in	T_SIM_TEST_ID;
		signal	 Clock			: out	STD_LOGIC;
		constant Period			: in	TIME;
		constant Phase			: in	T_PHASE			:=	0 deg;
		constant DutyCycle	: in	T_DUTYCYCLE	:= 50 percent;
		constant Wander			: in	T_WANDER		:=	0 permil
	) is
		constant NormalizedPhase		: T_PHASE		:= ite((Phase >= 0 deg), Phase, Phase + 360 deg);						-- move Phase into the range of 0° to 360°
		constant PhaseAsFactor			: REAL			:= real(NormalizedPhase / 1 second) / 1296000.0;						-- 1,296,000 = 3,600 seconds * 360 degree per cycle
		constant WanderAsFactor			: REAL			:= real(Wander / 1 ppb) / 1.0e9;
		constant DutyCycleAsFactor	: REAL			:= real(DutyCycle / 1 permil) / 1000.0;
		constant Delay							: TIME			:= Period * PhaseAsFactor;
		constant TimeHigh						: TIME			:= Period * DutyCycleAsFactor + (Period * (WanderAsFactor / 2.0));	-- add 50% wander to the high level
		constant TimeLow						: TIME			:= Period - TimeHigh + (Period * WanderAsFactor);						-- and 50% to the low level
		constant ClockAfterRun_cy		: POSITIVE	:= 5;
		
		constant PROCESS_ID					: T_SIM_PROCESS_ID	:= globalSimulationStatus.registerProcess(TestID, "simGenerateClock", IsLowPriority => TRUE);
	begin
		-- report "simGenerateClock: (Instance: '" & Clock'instance_name & "')" & CR &
			-- "Period: "						& TIME'image(Period) & CR &
			-- "Phase: "							& T_PHASE'image(Phase) & CR &
			-- "DutyCycle: "					& T_DUTYCYCLE'image(DutyCycle) & CR &
			-- "PhaseAsFactor: "			& REAL'image(PhaseAsFactor) & CR &
			-- "WanderAsFactor: "		& REAL'image(WanderAsFactor) & CR &
			-- "DutyCycleAsFactor: "	& REAL'image(DutyCycleAsFactor) & CR &
			-- "Delay: "							& TIME'image(Delay) & CR &
			-- "TimeHigh: "					& TIME'image(TimeHigh) & CR &
			-- "TimeLow: "						& TIME'image(TimeLow)
			-- severity NOTE;
	
		if (Delay = 0 ns) then
			null;
		elsif (Delay <= TimeLow) then
			Clock		<= '0';
			wait for Delay;
		else
			Clock		<= '1';
			wait for Delay - TimeLow;
			Clock		<= '0';
			wait for TimeLow;
		end if;
		Clock		<= '1';
		while (not globalSimulationStatus.isStopped) loop
			wait for TimeHigh;
			Clock		<= '0';
			wait for TimeLow;
			Clock		<= '1';
		end loop;
		globalSimulationStatus.deactivateProcess(PROCESS_ID);
		-- create N more cycles to allow other processes to recognize the stop condition (clock after run)
		for i in 1 to ClockAfterRun_cy loop
			wait for TimeHigh;
			Clock		<= '0';
			wait for TimeLow;
			Clock		<= '1';
		end loop;
		Clock		<= '0';
	end procedure;
	
	type T_SIM_NORMAL_DIST_PARAMETER is record
		StandardDeviation		: REAL;
		Mean								: REAL;
	end record;
	type T_JITTER_DISTRIBUTION is array (NATURAL range <>) of T_SIM_NORMAL_DIST_PARAMETER;
	
	procedure simGenerateClock2(signal Clock : out STD_LOGIC; signal Debug : out REAL; constant Period : in TIME) is
		constant TimeHigh							: TIME			:= Period * 0.5;
		constant TimeLow							: TIME			:= Period - TimeHigh;
		constant JitterPeakPeak				: REAL			:= 0.1;		-- UI
		constant JitterAsFactor				: REAL			:= JitterPeakPeak / 4.0;	-- Maximum jitter per edge
		constant JitterDistribution		: T_JITTER_DISTRIBUTION	:= (
			-- 0 => (StandardDeviation => 0.2, Mean => -0.4),
			-- 1 => (StandardDeviation => 0.2, Mean =>  0.4)
			
			-- 0 => (StandardDeviation => 0.2, Mean => -0.4),
			-- 1 => (StandardDeviation => 0.3, Mean => -0.1),
			-- 2 => (StandardDeviation => 0.5, Mean =>  0.0),
			-- 3 => (StandardDeviation => 0.3, Mean =>  0.1),
			-- 4 => (StandardDeviation => 0.2, Mean =>  0.4)
			
			0 => (StandardDeviation => 0.15,	Mean => -0.6),
			1 => (StandardDeviation => 0.2,		Mean => -0.3),
			2 => (StandardDeviation => 0.25,	Mean => -0.2),
			3 => (StandardDeviation => 0.3,		Mean =>  0.0),
			4 => (StandardDeviation => 0.25,	Mean =>  0.2),
			5 => (StandardDeviation => 0.2,		Mean =>  0.3),
			6 => (StandardDeviation => 0.15,	Mean =>  0.6)
		);
		variable Seed									: T_SIM_SEED;
		variable rand									: REAL;
		variable Jitter								: REAL;
		variable Index								: NATURAL;
		
		constant ClockAfterRun_cy			: POSITIVE	:= 5;
	begin
		Clock		<= '1';
		initializeSeed(Seed);

		while (not globalSimulationStatus.isStopped) loop
			ieee.math_real.Uniform(Seed.Seed1, Seed.Seed2, rand);
			Index		:= scale(rand, 0, JitterDistribution'length * 10) mod JitterDistribution'length;
			getNormalDistibutedRandomValue(Seed, rand, JitterDistribution(Index).StandardDeviation, JitterDistribution(Index).Mean, -1.0, 1.0);
			
			Jitter := JitterAsFactor * rand;
			Debug		<= rand;
			
			-- Debug		<= integer(rand * 256.0 + 256.0);
			wait for TimeHigh + (Period * Jitter);
			Clock		<= '0';
			wait for TimeLow + (Period * Jitter);
			Clock		<= '1';
		end loop;
		-- create N more cycles to allow other processes to recognize the stop condition (clock after run)
		for i in 1 to ClockAfterRun_cy loop
			wait for TimeHigh;
			Clock		<= '0';
			wait for TimeLow;
			Clock		<= '1';
		end loop;
		Clock		<= '0';
	end procedure;

	procedure simWaitUntilRisingEdge(signal Clock : in STD_LOGIC; constant Times : in POSITIVE) is
	begin
		for i in 1 to Times loop
			wait until rising_edge(Clock);
			exit when globalSimulationStatus.isStopped;
		end loop;
	end procedure;
	
	procedure simWaitUntilFallingEdge(signal Clock : in STD_LOGIC; constant Times : in POSITIVE) is
	begin
		for i in 1 to Times loop
			wait until falling_edge(Clock);
			exit when globalSimulationStatus.isStopped;
		end loop;
	end procedure;
	
	-- waveform generation
	-- ===========================================================================
	procedure simGenerateWaveform(
		signal	 Wave					: out	BOOLEAN;
		constant Waveform			: in	T_TIMEVEC;
		constant InitialValue	: in	BOOLEAN					:= FALSE
	) is
	begin
		simGenerateWaveform(C_SIM_DEFAULT_TEST_ID, Wave, Waveform, InitialValue);
	end procedure;
	
	procedure simGenerateWaveform(
		constant TestID				: in	T_SIM_TEST_ID;
		signal	 Wave					: out	BOOLEAN;
		constant Waveform			: in	T_TIMEVEC;
		constant InitialValue	: in	BOOLEAN					:= FALSE
	) is
		constant PROCESS_ID	: T_SIM_PROCESS_ID			:= globalSimulationStatus.registerProcess(TestID, "simGenerateWaveform");
		variable State			: BOOLEAN								:= InitialValue;
	begin
		Wave <= State;
		for i in Waveform'range loop
			wait for Waveform(i);
			State		:= not State;
			Wave		<= State;
			exit when globalSimulationStatus.isStopped;
		end loop;
		globalSimulationStatus.deactivateProcess(PROCESS_ID);
	end procedure;
	
	procedure simGenerateWaveform(
		signal	 Wave					: out	STD_LOGIC;
		constant Waveform			: in	T_TIMEVEC;
		constant InitialValue	: in	STD_LOGIC				:= '0'
	) is
	begin
		simGenerateWaveform(C_SIM_DEFAULT_TEST_ID, Wave, Waveform, InitialValue);
	end procedure;
	
	procedure simGenerateWaveform(
		constant TestID				: in	T_SIM_TEST_ID;
		signal	 Wave					: out	STD_LOGIC;
		constant Waveform			: in	T_TIMEVEC;
		constant InitialValue	: in	STD_LOGIC				:= '0'
	) is
		constant PROCESS_ID	: T_SIM_PROCESS_ID			:= globalSimulationStatus.registerProcess(TestID, "simGenerateWaveform");
		variable State : STD_LOGIC := InitialValue;
	begin
		Wave <= State;
		for i in Waveform'range loop
			wait for Waveform(i);
			State		:= not State;
			Wave		<= State;
			exit when globalSimulationStatus.isStopped;
		end loop;
		globalSimulationStatus.deactivateProcess(PROCESS_ID);
	end procedure;

	procedure simGenerateWaveform(signal Wave : out STD_LOGIC; Waveform: T_SIM_WAVEFORM_SL; InitialValue : STD_LOGIC := '0') is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when globalSimulationStatus.isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_8; Waveform: T_SIM_WAVEFORM_SLV_8; InitialValue : T_SLV_8) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when globalSimulationStatus.isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_16; Waveform: T_SIM_WAVEFORM_SLV_16; InitialValue : T_SLV_16) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when globalSimulationStatus.isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_24; Waveform: T_SIM_WAVEFORM_SLV_24; InitialValue : T_SLV_24) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when globalSimulationStatus.isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_32; Waveform: T_SIM_WAVEFORM_SLV_32; InitialValue : T_SLV_32) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when globalSimulationStatus.isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_48; Waveform: T_SIM_WAVEFORM_SLV_48; InitialValue : T_SLV_48) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when globalSimulationStatus.isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_64; Waveform: T_SIM_WAVEFORM_SLV_64; InitialValue : T_SLV_64) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when globalSimulationStatus.isStopped;
		end loop;
	end procedure;
	
	function simGenerateWaveform_Reset(constant Pause : TIME := 0 ns; ResetPulse : TIME := 10 ns) return T_TIMEVEC is
		variable p  : TIME;
		variable rp : TIME;
	begin
		-- WORKAROUND: for QuestaSim/ModelSim
		--	Version:	10.4c
		--	Issue:
		--		return (0 => Pause, 1 => ResetPulse); always evaluates to (0 ns, 10 ns),
		--		regardless of the passed function parameters
		p  := Pause;
		rp := ResetPulse;
		return (0 => p, 1 => rp);
	end function;

	-- checksum functions
	-- ===========================================================================
	-- TODO: move checksum functions here
end package body;
