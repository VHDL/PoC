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
		ATTRIBUTE TIG									: STRING;
		ATTRIBUTE ASYNC_REG						: STRING;
		ATTRIBUTE SHREG_EXTRACT				: STRING;
		
		SIGNAL Q0											: STD_LOGIC		:= '0';
		SIGNAL Q1											: STD_LOGIC		:= '0';
		
		-- Mark input of register one with ignore timings (TIG)
		ATTRIBUTE TIG						OF Q0	: SIGNAL IS "TRUE";
		
		-- Mark registers as asynchronous
		ATTRIBUTE ASYNC_REG			OF Q0	: SIGNAL IS "TRUE";
		ATTRIBUTE ASYNC_REG			OF Q1	: SIGNAL IS "TRUE";

		-- Prevent XST from translating two FFs into SRL plus FF
		ATTRIBUTE SHREG_EXTRACT OF Q0	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF Q1	: SIGNAL IS "NO";
		
	BEGIN
		PROCESS(Clock, Input)
		BEGIN
			IF (Input = '1') THEN
				Q0		<= '1';
				Q1		<= '1';
			ELSIF rising_edge(Clock) THEN
				Q0		<= '0';
				Q1		<= Q0;
			END IF;
		END PROCESS;		
				
		Output		<= Q1;
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