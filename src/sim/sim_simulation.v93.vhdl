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
use			PoC.sim_unprotected.all;


package simulation is
	-- Testbench Status Management
	-- ===========================================================================
	procedure				simInitialize(MaxAssertFailures : NATURAL := NATURAL'high; MaxSimulationRuntime : TIME := TIME'high);
	procedure				simFinalize;
	
	impure function simCreateTest(Name : STRING) return T_SIM_TEST_ID;
	procedure				simFinalizeTest(constant TestID : T_SIM_TEST_ID);
	impure function simRegisterProcess(constant TestID : T_SIM_TEST_ID; Name : STRING; constant IsLowPriority : BOOLEAN := FALSE) return T_SIM_PROCESS_ID;
	impure function simRegisterProcess(Name : STRING; constant IsLowPriority : BOOLEAN := FALSE) return T_SIM_PROCESS_ID;
	procedure				simDeactivateProcess(ProcID : T_SIM_PROCESS_ID);
	
	impure function	simIsStopped(constant TestID : T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) return BOOLEAN;
	impure function	simIsAllFinalized return BOOLEAN;
	
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
	procedure getUniformDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Minimum : REAL; Maximum : REAL);
	procedure getNormalDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; StandardDeviation : REAL := 1.0; Mean : REAL := 0.0);
	procedure getPoissonDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Mean : in REAL);
	procedure getPoissonDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Mean : in REAL; Minimum : in REAL; Maximum : in REAL);
	
	-- checksum functions
	-- ===========================================================================
	-- TODO: move checksum functions here
end package;


package body simulation is
	-- legacy procedures
	-- ===========================================================================
	-- TODO: undocumented group
	procedure simInitialize(MaxAssertFailures : NATURAL := NATURAL'high; MaxSimulationRuntime : TIME := TIME'high) is
	begin
		initialize(MaxAssertFailures, MaxSimulationRuntime);
	end procedure;
	
	procedure simFinalize is
	begin
		finalize;
	end procedure;
	
	impure function simCreateTest(Name : STRING) return T_SIM_TEST_ID is
	begin
		return createTest(Name);
	end function;
	
	procedure simFinalizeTest(constant TestID : T_SIM_TEST_ID) is
	begin
		finalizeTest(TestID);
	end procedure;
	
	impure function simRegisterProcess(Name : STRING; constant IsLowPriority : BOOLEAN := FALSE) return T_SIM_PROCESS_ID is
	begin
		return registerProcess(Name, IsLowPriority);
	end function;
	
	impure function simRegisterProcess(constant TestID : T_SIM_TEST_ID; Name : STRING; constant IsLowPriority : BOOLEAN := FALSE) return T_SIM_PROCESS_ID is
	begin
		return registerProcess(TestID, Name, IsLowPriority);
	end function;
		
	procedure simDeactivateProcess(ProcID : T_SIM_PROCESS_ID) is
	begin
		deactivateProcess(ProcID);
	end procedure;
	
	impure function simIsStopped(constant TestID : T_SIM_TEST_ID := C_SIM_DEFAULT_TEST_ID) return BOOLEAN is
	begin
		return isStopped(TestID);
	end function;
	
	impure function simIsAllFinalized return BOOLEAN is
	begin
		return isAllFinalized;
	end function;

	-- TODO: undocumented group
	procedure simWriteMessage(Message : in STRING := "") is
	begin
		writeMessage(Message);
	end procedure;
	
  procedure simFail(Message : in STRING := "") is
  begin
		fail(Message);
  end procedure;

	procedure simAssertion(cond : in BOOLEAN; Message : in STRING := "") is
	begin
		assertion(cond, Message);
	end procedure;


	-- ===========================================================================
	-- Random Numbers
	-- ===========================================================================
	procedure initializeSeed(Seed : inout T_SIM_SEED) is
	begin
		Seed.Seed1	:= 5;
		Seed.Seed2	:= 3423;
	end procedure;

	procedure getUniformDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; Minimum : REAL; Maximum : REAL) is
		variable rand : REAL;
	begin
		if (Maximum < Minimum) then			report "getUniformDistibutedRandomValue: Maximum must be greater than Minimum."	severity FAILURE;		end if;
		ieee.math_real.Uniform(Seed.Seed1, Seed.Seed2, rand);
		Value := scale(rand, Minimum, Maximum);
	end procedure ;

	procedure getNormalDistibutedRandomValue(Seed : inout T_SIM_SEED; Value : inout REAL; StandardDeviation : REAL := 1.0; Mean : REAL := 0.0) is
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
	
	-- checksum functions
	-- ===========================================================================
	-- TODO: move checksum functions here
end package body;
