-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Testbench:				Simulation constants, functions and utilities.
-- 
-- Authors:					Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		Automated testbench for PoC.arith_prng
--		The Pseudo-Random Number Generator is instanziated for 8 bits. The
--		output sequence is compared to 256 precalculated values.
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

USE			STD.TextIO.ALL;

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;


PACKAGE simulation IS
	CONSTANT U8								: T_SLV_8							:= (OTHERS => 'U');
	CONSTANT U16							: T_SLV_16						:= (OTHERS => 'U');
	CONSTANT U24							: T_SLV_24						:= (OTHERS => 'U');
	CONSTANT U32							: T_SLV_32						:= (OTHERS => 'U');

	CONSTANT D8								: T_SLV_8							:= (OTHERS => '-');
	CONSTANT D16							: T_SLV_16						:= (OTHERS => '-');
	CONSTANT D24							: T_SLV_24						:= (OTHERS => '-');
	CONSTANT D32							: T_SLV_32						:= (OTHERS => '-');

	PROCEDURE printSimulationResult(SimPassed : BOOLEAN);
	
	-- checksum functions
	-- ================================================================
--	FUNCTION crc(
END;


PACKAGE BODY simulation IS

	PROCEDURE printSimulationResult(SimPassed : BOOLEAN) IS
		VARIABLE l				: LINE;
	BEGIN
		IF SimPassed THEN
			write(l, string'("SIMULATION RESULT = PASSED"));
		ELSE
			write(l, string'("SIMULATION RESULT = FAILED"));
		END IF;
		writeline(output, l);
	END PROCEDURE;

	-- checksum functions
	-- ================================================================

END PACKAGE BODY;
