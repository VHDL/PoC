-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Testbench:				Simulation constants, functions and utilities.
-- 
-- Authors:					Patrick Lehmann
--									Thomas B. Preusser
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
use			IEEE.STD_LOGIC_1164.all;

library PoC;
-- use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.vectors.all;
use			PoC.physical.all;

use			PoC.sim_global.all;
use			PoC.sim_types.all;
use			PoC.sim_unprotected.all;


package simulation is
	-- Testbench Status Management
	-- ===========================================================================
	procedure				simInitialize;
	procedure				simFinalize;
	
	impure function simCreateTest(Name : STRING) return T_SIM_TEST_ID;
	impure function	simRegisterProcess(Name : STRING) return T_SIM_PROCESS_ID;
	procedure				simDeactivateProcess(ProcID : T_SIM_PROCESS_ID);
	
	impure function	simIsStopped return BOOLEAN;
	
	procedure				simWriteMessage(Message : in STRING := "");
	
	-- The testbench is marked as failed. If a message is provided, it is
	-- reported as an error.
	procedure simFail(Message : in string := "");

	-- If the passed condition has evaluated false, the testbench is marked
	-- as failed. In this case, the optional message will be reported as an
	-- error if one was provided.
	procedure simAssertion(cond : in boolean; Message : in string := "");

	-- clock generation
	-- ===========================================================================
	procedure simGenerateClock(signal Clock : out STD_LOGIC; constant Frequency : in FREQ; constant DutyCycle : T_DutyCycle := 0.5);
	procedure simGenerateClock(signal Clock : out STD_LOGIC; constant Period : in TIME; constant DutyCycle : T_DutyCycle := 0.5);
	
	-- waveform generation
	-- ===========================================================================
	procedure simGenerateWaveform(signal Wave : out BOOLEAN;		Waveform: T_TIMEVEC;							InitialValue : BOOLEAN);
	procedure simGenerateWaveform(signal Wave : out STD_LOGIC;	Waveform: T_TIMEVEC;							InitialValue : STD_LOGIC := '0');
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
	-- TODO: undocumented
	-- ===========================================================================
	procedure simInitialize is
	begin
		initialize;
	end procedure;
	
	procedure simFinalize is
	begin
		finalize;
	end procedure;
	
	impure function simCreateTest(Name : STRING) return T_SIM_TEST_ID is
	begin
		return createTest(Name);
	end function;
	
	impure function simRegisterProcess(Name : STRING) return T_SIM_PROCESS_ID is
	begin
		return registerProcess(Name);
	end function;
		
	procedure simDeactivateProcess(ProcID : T_SIM_PROCESS_ID) is
	begin
		deactivateProcess(ProcID);
	end procedure;
	
	procedure simWriteMessage(Message : in STRING := "") is
	begin
		writeMessage(Message);
	end procedure;
	
	procedure simFail(Message : in string := "") is
	begin
		fail(Message);
	end procedure;

	procedure simAssertion(cond : in boolean; Message : in string := "") is
	begin
		assertion(cond, Message);
	end procedure;

	-- clock generation
	procedure simStop is
	begin
		stopAllClocks;
	end procedure;
	
	impure function simIsStopped return BOOLEAN is
	begin
		return isStopped;
	end function;
	
	procedure simGenerateClock(signal Clock : out STD_LOGIC; constant Frequency : in FREQ; constant DutyCycle : T_DutyCycle := 0.5) is
		constant Period : TIME := to_time(Frequency);
	begin
		simGenerateClock(Clock, Period, DutyCycle);
	end procedure;
	
	procedure simGenerateClock(signal Clock : out STD_LOGIC; constant Period : in TIME; constant DutyCycle : T_DutyCycle := 0.5) is
		constant TIME_HIGH	: TIME := Period * DutyCycle;
		constant TIME_LOW		: TIME := Period - TIME_HIGH;
	begin
		Clock		<= '0';
		while (not isStopped) loop
			wait for TIME_LOW;
			Clock		<= '1';
			wait for TIME_HIGH;
			Clock		<= '0';
		end loop;
	end procedure;
	
	-- waveform generation
	procedure simGenerateWaveform(signal Wave : out BOOLEAN; Waveform : T_TIMEVEC; InitialValue : BOOLEAN) is
		variable State : BOOLEAN := InitialValue;
	begin
		Wave <= State;
		for i in Waveform'range loop
			wait for Waveform(i);
			State := not State;
			Wave		<= State;
			exit when isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out STD_LOGIC; Waveform: T_TIMEVEC; InitialValue : STD_LOGIC := '0') is
		variable State : STD_LOGIC := InitialValue;
	begin
		Wave <= State;
		for i in Waveform'range loop
			wait for Waveform(i);
			State := not State;
			Wave		<= State;
			exit when isStopped;
		end loop;
	end procedure;

	procedure simGenerateWaveform(signal Wave : out STD_LOGIC; Waveform: T_SIM_WAVEFORM_SL; InitialValue : STD_LOGIC := '0') is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_8; Waveform: T_SIM_WAVEFORM_SLV_8; InitialValue : T_SLV_8) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_16; Waveform: T_SIM_WAVEFORM_SLV_16; InitialValue : T_SLV_16) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_24; Waveform: T_SIM_WAVEFORM_SLV_24; InitialValue : T_SLV_24) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_32; Waveform: T_SIM_WAVEFORM_SLV_32; InitialValue : T_SLV_32) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_48; Waveform: T_SIM_WAVEFORM_SLV_48; InitialValue : T_SLV_48) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when isStopped;
		end loop;
	end procedure;
	
	procedure simGenerateWaveform(signal Wave : out T_SLV_64; Waveform: T_SIM_WAVEFORM_SLV_64; InitialValue : T_SLV_64) is
	begin
		Wave <= InitialValue;
		for i in Waveform'range loop
			wait for Waveform(i).Delay;
			Wave		<= Waveform(i).Value;
			exit when isStopped;
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
