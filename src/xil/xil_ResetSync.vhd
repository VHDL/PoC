-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
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
-- ============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

-- ============================================================================
-- asynchronous active-high reset, synchronous release
-- placement is constrained by RLOCs
-- ============================================================================

ENTITY xil_ResetSync IS
	PORT (
		Clock					: IN	STD_LOGIC;					-- clock to be sync'ed to
		ResetIn				: IN	STD_LOGIC;					-- Active high asynchronous reset
		ResetOut			: OUT	STD_LOGIC						-- "Synchronised" reset signal ()
	);
END;


ARCHITECTURE rtl OF xil_ResetSync IS
	SIGNAL ResetSync_async											: STD_LOGIC;

	-- Mark register "ResetSync_async" and "ResetOut" as asynchronous
	ATTRIBUTE ASYNC_REG													: STRING;
	ATTRIBUTE ASYNC_REG OF ResetSync_async			: SIGNAL IS "TRUE";
	ATTRIBUTE ASYNC_REG OF ResetOut							: SIGNAL IS "TRUE";

	-- Prevent XST from translating two FFs into SRL plus FF
	ATTRIBUTE SHREG_EXTRACT											: STRING;
	ATTRIBUTE SHREG_EXTRACT OF ResetSync_async	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF ResetOut					: SIGNAL IS "NO";

BEGIN

	FF1 : FDP
		GENERIC MAP (
			INIT		=> '1'
		)
		PORT MAP (
			C				=> Clock,
			PRE			=> ResetIn,
			D				=> '0',
			Q				=> ResetSync_async
	);

	FF2 : FDP
		GENERIC MAP (
			INIT		=> '1'
		)
		PORT MAP (
			C				=> Clock,
			PRE			=> ResetIn,
			D				=> ResetSync_async,
			Q				=> ResetOut
	);

	END;
