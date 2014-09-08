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


ENTITY misc_Synchronizer_Flag IS
  GENERIC (
	  BITS								: POSITIVE						:= 1;										-- number of bit to be synchronized
		INIT								: STD_LOGIC_VECTOR		:= x"00"
	);
  PORT (
		Clock								: IN	STD_LOGIC;															-- <Clock>	output clock domain
		Input								: IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- @async:	input bits
		Output							: OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)			-- @Clock:	output bits
	);
END;


ARCHITECTURE rtl OF misc_Synchronizer_Flag IS
	CONSTANT INIT_I		: STD_LOGIC_VECTOR		:= descend(INIT);

BEGIN
	genXilinx0 : IF (VENDOR /= VENDOR_XILINX) GENERATE
		ATTRIBUTE TIG										: STRING;
		ATTRIBUTE ASYNC_REG							: STRING;
		ATTRIBUTE SHREG_EXTRACT					: STRING;
	BEGIN
		gen : FOR I IN 0 TO BITS - 1 GENERATE
			SIGNAL Q0											: STD_LOGIC		:= INIT_I(I);
			SIGNAL Q1											: STD_LOGIC		:= INIT_I(I);
			
			-- Mark register DataSync_async's input as asynchronous and ignore timings (TIG)
			ATTRIBUTE TIG						OF Q0	: SIGNAL IS "TRUE";
			ATTRIBUTE ASYNC_REG			OF Q0	: SIGNAL IS "TRUE";

			-- Prevent XST from translating two FFs into SRL plus FF
			ATTRIBUTE SHREG_EXTRACT OF Q0	: SIGNAL IS "NO";
			ATTRIBUTE SHREG_EXTRACT OF Q1	: SIGNAL IS "NO";
		BEGIN
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					Q0		<= Input(I);
					Q1		<= Q0;
				END IF;
			END PROCESS;		
			
			Output(I)	<= Q1;
		END GENERATE;
	END GENERATE;

	genXilinx1 : IF (VENDOR = VENDOR_XILINX) GENERATE
		-- locally component declaration removes the dependancy to 'PoC.xil.ALL'
		COMPONENT xil_SyncBlock IS
			GENERIC (
				BITS					: POSITIVE						:= 1;									-- number of bit to be synchronized
				INIT					: STD_LOGIC_VECTOR		:= x"00"
			);
			PORT (
				Clock					: IN	STD_LOGIC;														-- Clock to be synchronized to
				Input					: IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);	-- Data to be synchronized
				Output				: OUT	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)		-- synchronised data
			);
		END COMPONENT;
	BEGIN
		-- use dedicated and optimized 2 D-FF synchronizer for Xilinx FPGAs
		sync : xil_SyncBlock
			GENERIC MAP (
				BITS			=> BITS,
				INIT			=> INIT_I
			)
			PORT MAP (
				Clock			=> Clock,
				Input			=> Input,
				Output		=> Output
			);
	END GENERATE;

END;