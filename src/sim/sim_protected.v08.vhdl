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

use			STD.TextIO.all;

library IEEE;
use			IEEE.STD_LOGIC_1164.all;

library PoC;
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.vectors.all;
use			PoC.physical.all;

use			PoC.sim_types.all;


package sim_protected is
  -- Simulation Task and Status Management
	-- ===========================================================================
	type T_SIM_STATUS is protected
		-- Initializer and Finalizer
		procedure				initialize(MaxAssertFailures : NATURAL := NATURAL'high; MaxSimulationRuntime : TIME := TIME'high);
		procedure				finalize;
		
		-- Assertions
    procedure				fail(Message : STRING := "");
	  procedure				assertion(Condition : BOOLEAN; Message : STRING := "");
	  procedure				writeMessage(Message : STRING);
		procedure				writeReport;
		
		-- Process Management
		impure function	registerProcess(Name : STRING; IsLowPriority : BOOLEAN := FALSE) return T_SIM_PROCESS_ID;
		impure function registerProcess(TestID : T_SIM_TEST_ID; Name : STRING; IsLowPriority : BOOLEAN := FALSE) return T_SIM_PROCESS_ID;
		procedure				deactivateProcess(procID : T_SIM_PROCESS_ID);
		
		-- Test Management
		procedure				createDefaultTest;
		impure function	createTest(Name : STRING) return T_SIM_TEST_ID;
		procedure				activateDefaultTest;
		procedure				finalizeTest(TestID : T_SIM_TEST_ID);
		
		-- Run Management
		procedure				stopAllProcesses(TestID	: T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID);
		procedure				stopAllClocks(TestID		: T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID);
		
		impure function	isStopped(TestID		: T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) return BOOLEAN;
		impure function	isFinalized(TestID	: T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) return BOOLEAN;
		impure function isAllFinalized return BOOLEAN;
	end protected;
end package;


package body sim_protected is
	-- Simulation process and Status Management
	-- ===========================================================================
	type T_SIM_STATUS_STATE is record
		IsInitialized			: BOOLEAN;
		IsFinalized				: BOOLEAN;
	end record;
	
	type T_SIM_STATUS is protected body
		-- status
		variable State									: T_SIM_STATUS_STATE											:= (FALSE, FALSE);
		
		variable Max_AssertFailures			: NATURAL																	:= NATURAL'high;
		variable Max_SimulationRuntime	: TIME																		:= TIME'high;
		
    -- Internal state variable to log a failure condition for final reporting.
    -- Once de-asserted, this variable will never return to a value of true.
		variable Passed									: BOOLEAN 																:= TRUE;
		variable AssertCount						: NATURAL																	:= 0;
		variable FailedAssertCount			: NATURAL																	:= 0;
		
		-- Clock Management
		variable MainProcessEnables			: T_SIM_BOOLVEC(T_SIM_TEST_ID)						:= (others => TRUE);
		variable MainClockEnables				: T_SIM_BOOLVEC(T_SIM_TEST_ID)						:= (others => TRUE);
		
		-- Process Management
		variable ProcessCount						: NATURAL																	:= 0;
		variable ActiveProcessCount			: NATURAL																	:= 0;
		variable Processes							: T_SIM_PROCESS_VECTOR(T_SIM_PROCESS_ID);
		
		-- Test Management
		variable TestCount							: NATURAL																	:= 0;
		variable ActiveTestCount				: NATURAL																	:= 0;
		variable Tests									: T_SIM_TEST_VECTOR(T_SIM_TEST_ID);
		
		-- Initializer
		procedure initialize(MaxAssertFailures : NATURAL := NATURAL'high; MaxSimulationRuntime : TIME := TIME'high) is
		begin
			if (State.IsInitialized = FALSE) then
				if C_SIM_VERBOSE then		report "initialize:" severity NOTE;			end if;
				State.IsInitialized		:= TRUE;
				createDefaultTest;
				Max_AssertFailures		:= MaxAssertFailures;
				Max_SimulationRuntime	:= MaxSimulationRuntime;
			end if;
		end procedure;
		
		procedure finalize is
		begin
			if (State.IsFinalized = FALSE) then
				if C_SIM_VERBOSE then		report "finalize: " severity NOTE;		end if;
				State.IsFinalized		:= TRUE;
				for i in 0 to TestCount - 1 loop
					finalizeTest(i);
				end loop;
				writeReport;
			end if;
		end procedure;
		
		procedure writeReport_Header is
		  variable LineBuffer : LINE;
		begin
		  write(LineBuffer,		(			STRING'("========================================")));
		  write(LineBuffer,		(CR & STRING'("POC TESTBENCH REPORT")));
		  write(LineBuffer,		(CR & STRING'("========================================")));
		  writeline(output, LineBuffer);
		end procedure;
		
		procedure writeReport_TestReport(Prefix : STRING := "") is
		  variable LineBuffer : LINE;
	  begin
			write(LineBuffer,					 Prefix & "Tests          " & INTEGER'image(imax(1, TestCount)));
			for i in 0 to TestCount - 1 loop
				write(LineBuffer,		CR & Prefix & "  " & str_ralign(INTEGER'image(i), log10ceilnz(TestCount)) & ": " & str_trim(Tests(i).Name));
			end loop;
		  writeline(output, LineBuffer);
		end procedure;
		
		procedure writeReport_AssertReport(Prefix : STRING := "") is
		  variable LineBuffer : LINE;
	  begin
			write(LineBuffer,					 Prefix & "Assertions   " & INTEGER'image(AssertCount));
			write(LineBuffer,			CR & Prefix & "  failed     " & INTEGER'image(FailedAssertCount) & ite((FailedAssertCount >= Max_AssertFailures), " Too many failed asserts!", ""));
		  writeline(output, LineBuffer);
		end procedure;
		
		procedure writeReport_ProcessReport(Prefix : STRING := "") is
		  variable LineBuffer : LINE;
	  begin
			write(LineBuffer,					 Prefix & "Processes    " & INTEGER'image(ProcessCount));
			write(LineBuffer,			CR & Prefix & "  active     " & INTEGER'image(ActiveProcessCount));
			-- report killed processes
			for i in 0 to ProcessCount - 1 loop
				if ((Processes(i).Status = SIM_PROCESS_STATUS_ACTIVE) and (Processes(i).IsLowPriority = FALSE)) then
					write(LineBuffer,	CR & Prefix & "    " & str_trim(Processes(i).Name));
				end if;
			end loop;
		  writeline(output, LineBuffer);
		end procedure;
		
		procedure writeReport_SimulationResult is
		  variable LineBuffer : LINE;
	  begin
		  write(LineBuffer,															(			STRING'("========================================")));
			if (AssertCount = 0) then	  write(LineBuffer, (CR & STRING'("SIMULATION RESULT = NO ASSERTS")));
		  elsif (Passed = TRUE) then  write(LineBuffer, (CR & STRING'("SIMULATION RESULT = PASSED")));
		  else										  	write(LineBuffer, (CR & STRING'("SIMULATION RESULT = FAILED")));
		  end if;
		  write(LineBuffer,															(CR & STRING'("========================================")));
		  writeline(output, LineBuffer);
		end procedure;
		
	  procedure writeReport is
		  variable LineBuffer : LINE;
	  begin
			writeReport_Header;
			writeReport_TestReport("");
			write(LineBuffer, CR & "Overall");
		  writeline(output, LineBuffer);
			writeReport_AssertReport("  ");
			writeReport_ProcessReport("  ");
			writeReport_SimulationResult;
		end procedure;

	  procedure assertion(condition : BOOLEAN; Message : STRING := "") is
  	begin
			AssertCount := AssertCount + 1;
		  if (condition = FALSE) then
		    fail(Message);
				FailedAssertCount := FailedAssertCount + 1;
				if (FailedAssertCount >= Max_AssertFailures) then
					stopAllProcesses;
				end if;
		  end if;
	  end procedure;
		
	  procedure fail(Message : STRING := "") is
		begin
	  	if (Message'length > 0) then
		  	report Message severity ERROR;
		  end if;
		  Passed := FALSE;
		end procedure;

		procedure writeMessage(Message : STRING) is
		  variable LineBuffer : LINE;
	  begin
		  write(LineBuffer, Message);
		  writeline(output, LineBuffer);
		end procedure;
	
		procedure createDefaultTest is
			variable Test							: T_SIM_TEST;
		begin
			if (State.IsInitialized = FALSE) then
				initialize;
			end if;
			if C_SIM_VERBOSE then		report "createDefaultTest(" & C_SIM_DEFAULT_TEST_NAME & "):" severity NOTE;		end if;
			Test.ID										:= C_SIM_DEFAULT_TEST_ID;
			Test.Name									:= resize(C_SIM_DEFAULT_TEST_NAME, T_SIM_TEST_NAME'length);
			Test.Status								:= SIM_TEST_STATUS_CREATED;
			Test.ProcessIDs						:= (others => 0);
			Test.ProcessCount					:= 0;
			Test.ActiveProcessCount		:= 0;
			-- add to the internal structure
			Tests(Test.ID)						:= Test;
		end procedure;
		
		impure function createTest(Name : STRING) return T_SIM_TEST_ID is
			variable Test						: T_SIM_TEST;
		begin
			if (State.IsInitialized = FALSE) then
				initialize;
			end if;
			if C_SIM_VERBOSE then		report "createTest(" & Name & "): => " & T_SIM_TEST_ID'image(TestCount) severity NOTE;		end if;
			Test.ID									:= TestCount;
			Test.Name								:= resize(Name, T_SIM_TEST_NAME'length);
			Test.Status							:= SIM_TEST_STATUS_ACTIVE;
			Test.ProcessIDs					:= (others => 0);
			Test.ProcessCount				:= 0;
			Test.ActiveProcessCount	:= 0;
			-- add to the internal structure
			Tests(Test.ID)					:= Test;
			TestCount								:= TestCount + 1;
			ActiveTestCount					:= ActiveTestCount + 1;
			-- return TestID for finalizeTest
			return Test.ID;
		end function;
		
		procedure activateDefaultTest is
		begin
			if (Tests(C_SIM_DEFAULT_TEST_ID).Status = SIM_TEST_STATUS_CREATED) then
				Tests(C_SIM_DEFAULT_TEST_ID).Status := SIM_TEST_STATUS_ACTIVE;
				ActiveTestCount											:= ActiveTestCount + 1;
			end if;
		end procedure;
		
		impure function finalizeDefaultTest return BOOLEAN is
			variable Result		: BOOLEAN;
		begin
			Result	:= FALSE;
			if (ActiveTestCount = 1) then
				if C_SIM_VERBOSE then		report "finalizeDefaultTest: " severity NOTE;		end if;
				if (Tests(C_SIM_DEFAULT_TEST_ID).Status = SIM_TEST_STATUS_CREATED) then
					Result						:= TRUE;
				elsif (Tests(C_SIM_DEFAULT_TEST_ID).Status = SIM_TEST_STATUS_ACTIVE) then
					if (Tests(C_SIM_DEFAULT_TEST_ID).ActiveProcessCount = 0) then
						ActiveTestCount	:= ActiveTestCount - 1;
						Result					:= TRUE;
					end if;
				end if;
			end if;
			if (Result = TRUE) then
				Tests(C_SIM_DEFAULT_TEST_ID).Status	:= SIM_TEST_STATUS_ENDED;
				stopAllProcesses(C_SIM_DEFAULT_TEST_ID);
				if (ActiveTestCount = 0) then
					finalize;
				end if;
			end if;
			return Result;
		end function;
		
		procedure finalizeTest(TestID : T_SIM_TEST_ID) is
			variable Dummy	: BOOLEAN;
		begin
			if (TestID = C_SIM_DEFAULT_TEST_ID) then
				Dummy := finalizeDefaultTest;
			elsif (TestID < TestCount) then
				if (Tests(TestID).Status = SIM_TEST_STATUS_ACTIVE) then
					if C_SIM_VERBOSE then		report "finalizeTest(TestID=" & T_SIM_TEST_ID'image(TestID) & "): " & str_trim(Tests(TestID).Name) severity NOTE;		end if;
					Tests(TestID).Status		:= SIM_TEST_STATUS_ENDED;
					ActiveTestCount					:= ActiveTestCount - 1;
					stopAllProcesses(TestID);
					
					if (ActiveTestCount = 0) then
						finalize;
					elsif (ActiveTestCount = 1) then
						if (finalizeDefaultTest = TRUE) then
							finalize;
						end if;
					end if;
				end if;
			else
				report "TestID (" & T_SIM_TEST_ID'image(TestID) & ") is unknown." severity FAILURE;
			end if;
		end procedure;
		
		impure function registerProcess(Name : STRING; IsLowPriority : BOOLEAN := FALSE) return T_SIM_PROCESS_ID is
		begin
			return registerProcess(C_SIM_DEFAULT_TEST_ID, Name, IsLowPriority);
		end function;
		
		impure function registerProcess(TestID : T_SIM_TEST_ID; Name : STRING; IsLowPriority : BOOLEAN := FALSE) return T_SIM_PROCESS_ID is
			variable Proc						: T_SIM_PROCESS;
			variable TestProcID			: T_SIM_TEST_ID;
		begin
			if (State.IsInitialized = FALSE) then
				initialize;
			end if;
			if (TestID = C_SIM_DEFAULT_TEST_ID) then
				activateDefaultTest;
			end if;
			if (TestID < TestCount) then
				if C_SIM_VERBOSE then		report "registerProcess(TestID=" & T_SIM_TEST_ID'image(TestID) & ", " & Name & "): => " & T_SIM_PROCESS_ID'image(ProcessCount) severity NOTE;		end if;
				Proc.ID									:= ProcessCount;
				Proc.TestID							:= TestID;
				Proc.Name								:= resize(Name, T_SIM_PROCESS_NAME'length);
				Proc.Status							:= SIM_PROCESS_STATUS_ACTIVE;
				Proc.IsLowPriority			:= IsLowPriority;
				
				-- add process to list
				Processes(Proc.ID)										:= Proc;
				ProcessCount													:= ProcessCount + 1;
				ActiveProcessCount										:= inc(not IsLowPriority, ActiveProcessCount);
				-- add process to test
				TestProcID														:= Tests(TestID).ProcessCount;
				Tests(TestID).ProcessIDs(TestProcID)	:= Proc.ID;
				Tests(TestID).ProcessCount						:= TestProcID + 1;
				Tests(TestID).ActiveProcessCount			:= inc(not IsLowPriority, Tests(TestID).ActiveProcessCount);
				-- return the process ID
				return Proc.ID;
			else
				report "TestID (" & T_SIM_TEST_ID'image(TestID) & ") is unknown." severity FAILURE;
			end if;
		end function;
		
		procedure deactivateProcess(ProcID : T_SIM_PROCESS_ID) is
			variable TestID		: T_SIM_TEST_ID;
		begin
			if (ProcID < ProcessCount) then
				TestID	:= Processes(ProcID).TestID;
				-- deactivate process
				if (Processes(ProcID).Status = SIM_PROCESS_STATUS_ACTIVE) then
					if C_SIM_VERBOSE then		report "deactivateProcess(ProcID=" & T_SIM_PROCESS_ID'image(ProcID) & "): TestID=" & T_SIM_TEST_ID'image(TestID) & "  Name=" & str_trim(Processes(ProcID).Name) severity NOTE;		end if;
					Processes(ProcID).Status					:= SIM_PROCESS_STATUS_ENDED;
					ActiveProcessCount								:= dec(not Processes(ProcID).IsLowPriority, ActiveProcessCount);
					Tests(TestID).ActiveProcessCount	:= dec(not Processes(ProcID).IsLowPriority, Tests(TestID).ActiveProcessCount);
					if (Tests(TestID).ActiveProcessCount = 0) then
						-- stopAllProcesses(TestID);
						finalizeTest(TestID);
					end if;
				end if;
			else
				report "ProcID (" & T_SIM_PROCESS_ID'image(ProcID) & ") is unknown." severity FAILURE;
			end if;
		end procedure;
		
		procedure stopAllProcesses(TestID : T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) is
		begin
			if C_SIM_VERBOSE then		report "stopAllProcesses(TestID=" & T_SIM_TEST_ID'image(TestID) & "):" severity NOTE;		end if;
			if (TestID = C_SIM_DEFAULT_TEST_ID) then
				for i in C_SIM_DEFAULT_TEST_ID to TestCount - 1 loop
					MainProcessEnables(i)			:= FALSE;
				end loop;
				stopAllClocks(TestID);
			elsif (TestID < TestCount) then
				MainProcessEnables(TestID)	:= FALSE;
				stopAllClocks(TestID);
			else
				report "TestID (" & T_SIM_TEST_ID'image(TestID) & ") is unknown." severity FAILURE;
			end if;
		end procedure;
		
		procedure stopAllClocks(TestID : T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) is
		begin
			if C_SIM_VERBOSE then		report "stopAllClocks(TestID=" & T_SIM_TEST_ID'image(TestID) & "):" severity NOTE;		end if;
			if (TestID = C_SIM_DEFAULT_TEST_ID) then
				for i in C_SIM_DEFAULT_TEST_ID to TestCount - 1 loop
					MainClockEnables(i)				:= FALSE;
				end loop;
			elsif (TestID < TestCount) then
				MainClockEnables(TestID)		:= FALSE;
			else
				report "TestID (" & T_SIM_TEST_ID'image(TestID) & ") is unknown." severity FAILURE;
			end if;
		end procedure;
		
		impure function isStopped(TestID : T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) return BOOLEAN is
		begin
			return not MainClockEnables(TestID);
		end function;
	
		impure function isFinalized(TestID : T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) return BOOLEAN is
		begin
			return (Tests(TestID).Status = SIM_TEST_STATUS_ENDED);
		end function;
		
		impure function isAllFinalized return BOOLEAN is
		begin
			if (State.IsFinalized = TRUE) then
				if (ActiveTestCount = 0) then
					return TRUE;
				end if;
				report "isAllFinalized: " severity ERROR;
			else
				return FALSE;
			end if;
		end function;
	end protected body;
end package body;
