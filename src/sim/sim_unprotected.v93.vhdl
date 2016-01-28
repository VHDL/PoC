-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
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

use			STD.TextIO.all;

library IEEE;
use			IEEE.STD_LOGIC_1164.all;

library PoC;
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.vectors.all;
use			PoC.physical.all;

use			PoC.sim_types.all;
use			PoC.sim_global.all;


package sim_unprotected is
  -- Simulation Task and Status Management
	-- ===========================================================================
	-- Initializer and Finalizer
	procedure initialize;
	procedure finalize;
	
	-- Assertions
	procedure fail(Message : STRING := "");
	procedure assertion(Condition : BOOLEAN; Message : STRING := "");
	
	procedure writeMessage(Message : STRING);
	procedure writeReport;
	
	-- Process Management
	-- impure function	registerProcess(Name : STRING; InstanceName : STRING) return T_SIM_PROCESS_ID;
	impure function	registerProcess(Name : STRING) return T_SIM_PROCESS_ID;
	procedure				deactivateProcess(procID : T_SIM_PROCESS_ID);
	
	-- Test Management
	impure function createTest(Name : STRING) return T_SIM_TEST_ID;
	
	-- Run Management
	procedure				stopAllClocks;
	impure function	isStopped return BOOLEAN;
end package;


package body sim_unprotected is
	-- Simulation process and Status Management
	-- ===========================================================================
	procedure initialize is
	begin
		globalSim_IsInitialized			:= TRUE;
	end procedure;
	
	procedure finalize is
	begin
		if (globalSim_IsFinalized = FALSE) then
			if (globalSim_ActiveProcessCount = 0) then
				writeReport;
				globalSim_IsFinalized		:= TRUE;
			end if;
		end if;
	end procedure;

	procedure fail(Message : STRING := "") is
	begin
		if (Message'length > 0) then
			report Message severity ERROR;
		end if;
		globalSim_Passed := FALSE;
	end procedure;

	procedure assertion(condition : BOOLEAN; Message : STRING := "") is
	begin
		globalSim_AssertCount := globalSim_AssertCount + 1;
		if (condition = FALSE) then
			fail(Message);
			globalSim_FailedAssertCount := globalSim_FailedAssertCount + 1;
		end if;
	end procedure;

	procedure writeMessage(Message : STRING) is
		variable LineBuffer : LINE;
	begin
		write(LineBuffer, Message);
		writeline(output, LineBuffer);
	end procedure;
	
	procedure writeReport is
		variable LineBuffer : LINE;
	begin
		write(LineBuffer,		(CR & STRING'("========================================")));
		write(LineBuffer,		(CR & STRING'("POC TESTBENCH REPORT")));
		write(LineBuffer,		(CR & STRING'("========================================")));
		write(LineBuffer,		(CR & STRING'("Assertions   ") & INTEGER'image(globalSim_AssertCount)));
		write(LineBuffer,		(CR & STRING'("  failed     ") & INTEGER'image(globalSim_FailedAssertCount)));
		write(LineBuffer,		(CR & STRING'("Processes    ") & INTEGER'image(globalSim_ProcessCount)));
		write(LineBuffer,		(CR & STRING'("  active     ") & INTEGER'image(globalSim_ActiveProcessCount)));
		for i in 0 to globalSim_ProcessCount - 1 loop
			if (globalSim_Processes(i).Status = SIM_PROCESS_STATUS_ACTIVE) then
				write(LineBuffer,	(CR & STRING'("    ") & str_trim(globalSim_Processes(i).Name)));
			end if;
		end loop;
		write(LineBuffer,		(CR & STRING'("Tests        ") & INTEGER'image(globalSim_TestCount)));
		for i in 0 to globalSim_TestCount - 1 loop
			write(LineBuffer,	(CR & STRING'("  ") & str_ralign(INTEGER'image(i), log10ceil(T_SIM_TEST_ID'high)) & ": " & str_trim(globalSim_Tests(i).Name)));
		end loop;
		write(LineBuffer,		(CR & STRING'("========================================")));
		if (globalSim_AssertCount = 0) then
			write(LineBuffer, (CR & STRING'("SIMULATION RESULT = NO ASSERTS")));
		elsif (globalSim_Passed = TRUE) then
			write(LineBuffer, (CR & STRING'("SIMULATION RESULT = PASSED")));
		else
			write(LineBuffer, (CR & STRING'("SIMULATION RESULT = FAILED")));
		end if;
		write(LineBuffer,		(CR & STRING'("========================================")));
		writeline(output, LineBuffer);
	end procedure;
	
	-- impure function registerProcess(Name : STRING; InstanceName : STRING) return T_SIM_PROCESS_ID is
	impure function registerProcess(Name : STRING) return T_SIM_PROCESS_ID is
		variable Proc									: T_SIM_PROCESS;
	begin
		Proc.ID												:= globalSim_ProcessCount;
		Proc.Name											:= resize(Name, T_SIM_PROCESS_NAME'length);
		-- Proc.InstanceName						:= resize(InstanceName, T_SIM_PROCESS_INSTNAME'length);
		Proc.Status										:= SIM_PROCESS_STATUS_ACTIVE;
		
		globalSim_Processes(Proc.ID)	:= Proc;
		globalSim_ProcessCount				:= globalSim_ProcessCount + 1;
		globalSim_ActiveProcessCount	:= globalSim_ActiveProcessCount + 1;
		return Proc.ID;
	end function;
	
	procedure deactivateProcess(ProcID : T_SIM_PROCESS_ID) is
		variable hasActiveProcesses		: BOOLEAN		:= FALSE;
	begin
		if (ProcID < globalSim_ProcessCount) then
			if (globalSim_Processes(ProcID).Status = SIM_PROCESS_STATUS_ACTIVE) then
				globalSim_Processes(ProcID).Status	:= SIM_PROCESS_STATUS_ENDED;
				globalSim_ActiveProcessCount				:= globalSim_ActiveProcessCount - 1;
			end if;
		end if;
		
		if (globalSim_ActiveProcessCount = 0) then
			stopAllClocks;
		end if;
	end procedure;
	
	impure function createTest(Name : STRING) return T_SIM_TEST_ID is
		variable Test							: T_SIM_TEST;
	begin
		Test.ID										:= globalSim_TestCount;
		Test.Name									:= resize(Name, T_SIM_TEST_NAME'length);
		Test.Status								:= SIM_TEST_STATUS_ACTIVE;
	
		globalSim_Tests(Test.ID)	:= Test;
		globalSim_TestCount				:= globalSim_TestCount + 1;
		return Test.ID;
	end function;
	
	procedure stopAllClocks is
	begin
		globalSim_MainClockEnable		:= FALSE;
	end procedure;
	
	impure function isStopped return BOOLEAN is
	begin
		return not globalSim_MainClockEnable;
	end function;
end package body;
