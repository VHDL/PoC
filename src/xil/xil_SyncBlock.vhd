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
-- clock-domain crossing with two FFs
-- use only for:
--	o long time signals
--	o between clock domains with the same frequency
-- 
-- placement is constrained by RLOCs
-- ============================================================================

ENTITY xil_SyncBlock IS
	PORT (
		Clock					: IN	STD_LOGIC;					-- Clock to be synchronized to
		DataIn				: IN	STD_LOGIC;					-- Data to be synchronized
		DataOut				: OUT	STD_LOGIC						-- synchronised data
	);
END;


ARCHITECTURE rtl OF xil_SyncBlock IS
	SIGNAL DataSync_async				: STD_LOGIC;

	-- Mark register "DataSync_async" as asynchronous
	ATTRIBUTE ASYNC_REG												: STRING;
	ATTRIBUTE ASYNC_REG			OF DataSync_async	: SIGNAL IS "TRUE";

	-- Prevent XST from translating two FFs into SRL plus FF
	ATTRIBUTE SHREG_EXTRACT										: STRING;
	ATTRIBUTE SHREG_EXTRACT OF DataSync_async	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF DataOut				: SIGNAL IS "NO";

BEGIN

	FF1 : FD
		GENERIC MAP (
			INIT		=> '0'
		)
		PORT MAP (
			C				=> Clock,
			D				=> DataIn,
			Q				=> DataSync_async
	);

	FF2 : FD
		GENERIC MAP (
			INIT		=> '0'
		)
		PORT MAP (
			C				=> Clock,
			D				=> DataSync_async,
			Q				=> DataOut
	);

	END;
