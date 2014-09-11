-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		This module synchronizes multiple flag bits from clock domain
--		'Clock1' to clock domain 'Clock'. The clock domain boundary crossing is
--		done by two synchronizer D-FFs. All bits are independent from each other.
-- 
--		ATTENTION:
--			Only use this synchronizer for reset signals.
--
--		CONSTRAINTS:
--			General:
--				Please add constraints for meta stability to all '_meta' signals and
--				timing ignore constraints to all '_async' signals.
--			
--			Xilinx:
--				In case of a xilinx device, this module will instantiate the optimized
--				module xil_SyncReset. Please attend to the notes of xil_SyncReset.
--		
--			Altera sdc file:
--				TODO
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;


ENTITY sync_Reset IS
  PORT (
		Clock			: IN	STD_LOGIC;															-- <Clock>	output clock domain
		Input			: IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- @async:	reset input
		Output		: OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)			-- @Clock:	reset output
	);
END;


ARCHITECTURE rtl OF sync_Reset IS

BEGIN
	genXilinx0 : IF (VENDOR /= VENDOR_XILINX) GENERATE
		ATTRIBUTE ASYNC_REG						: STRING;
		ATTRIBUTE SHREG_EXTRACT				: STRING;
		
		SIGNAL Data_async											: STD_LOGIC;
		SIGNAL Data_meta											: STD_LOGIC		:= '0';
		SIGNAL Data_sync											: STD_LOGIC		:= '0';
		
		-- Mark registers as asynchronous
		ATTRIBUTE ASYNC_REG			OF Data_meta	: SIGNAL IS "TRUE";
		ATTRIBUTE ASYNC_REG			OF Data_sync	: SIGNAL IS "TRUE";

		-- Prevent XST from translating two FFs into SRL plus FF
		ATTRIBUTE SHREG_EXTRACT OF Data_meta	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF Data_sync	: SIGNAL IS "NO";
		
	BEGIN
		Data_async	<= Input;
	
		PROCESS(Clock, Input)
		BEGIN
			IF (Data_async = '1') THEN
				Data_meta		<= '1';
				Data_sync		<= '1';
			ELSIF rising_edge(Clock) THEN
				Data_meta		<= '0';
				Data_sync		<= Data_meta;
			END IF;
		END PROCESS;		
				
		Output		<= Data_sync;
	END GENERATE;

	genXilinx1 : IF (VENDOR = VENDOR_XILINX) GENERATE
		-- locally component declaration removes the dependancy to 'PoC.xil.ALL'
		COMPONENT xil_SyncReset IS
			PORT (
				Clock					: IN	STD_LOGIC;														-- Clock to be synchronized to
				Input					: IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);	-- Data to be synchronized
				Output				: OUT	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)		-- synchronised data
			);
		END COMPONENT;
	BEGIN
		-- use dedicated and optimized 2 D-FF synchronizer for Xilinx FPGAs
		sync : xil_SyncReset
			PORT MAP (
				Clock			=> Clock,
				Input			=> Input,
				Output		=> Output
			);
	END GENERATE;

END;