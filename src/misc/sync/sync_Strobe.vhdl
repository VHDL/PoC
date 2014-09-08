-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--									Steffen Köhler
--
-- Description:
-- ------------------------------------
--		This module synchronizes multiple high-active bits from clock domain
--		'Clock1' to clock domain 'Clock2'. The clock domain boundary crossing is
--		done by a T-FF, two synchronizer D-FFs and a reconstructive XOR. A busy
--		flag is additionally calculated and can be used to block new inputs. All
--		bits are independent from each other.
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


ENTITY misc_Synchronizer_Strobe IS
  GENERIC (
	  BITS								: POSITIVE		:= 1;														-- number of bit to be synchronized
		GATED_INPUT_BY_BUSY	: BOOLEAN			:= TRUE													-- use gated input (by busy signal)
	);
  PORT (
		Clock1							: IN	STD_LOGIC;															-- <Clock>	input clock domain
		Clock2							: IN	STD_LOGIC;															-- <Clock>	output clock domain
		Input								: IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- @Clock1:	input bits
		Output							: OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- @Clock2:	output bits
		Busy								: OUT	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)			-- @Clock1:	busy bits
	);
END;


ARCHITECTURE rtl OF misc_Synchronizer_Strobe IS
	ATTRIBUTE SHREG_EXTRACT										: STRING;

	SIGNAL syncClk1_In		: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
	SIGNAL syncClk1_Out		: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
	SIGNAL syncClk2_In		: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
	SIGNAL syncClk2_Out		: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
	
BEGIN

	gen : FOR I IN 0 TO BITS - 1 GENERATE
		SIGNAL D0							: STD_LOGIC			:= '0';
		SIGNAL T1							: STD_LOGIC			:= '0';
		SIGNAL D2							: STD_LOGIC			:= '0';

		SIGNAL Changed_Clk1		: STD_LOGIC;
		SIGNAL Changed_Clk2		: STD_LOGIC;
		SIGNAL Busy_i					: STD_LOGIC;
		
		-- Prevent XST from translating two FFs into SRL plus FF
		ATTRIBUTE SHREG_EXTRACT OF D0	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF T1	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF D2	: SIGNAL IS "NO";
		
	BEGIN
		
		PROCESS(Clock1)
		BEGIN
			IF rising_edge(Clock1) THEN
				-- input delay for rising edge detection
				D0		<= Input(I);
			
				-- T-FF to converts a strobe to a flag signal
				IF (GATED_INPUT_BY_BUSY = TRUE) THEN
					T1	<= (Changed_Clk1 AND NOT Busy_i) XOR T1;
				ELSE
					T1	<= Changed_Clk1 XOR T1;
				END IF;
			END IF;
		END PROCESS;
		
		-- D-FF for level change detection (both edges)
		D2	<= syncClk2_Out(I) WHEN rising_edge(Clock2);

		-- assign syncClk*_In signals
		syncClk2_In(I)	<= T1;
		syncClk1_In(I)	<= syncClk2_Out(I);	-- D2

		Changed_Clk1		<= NOT D0 AND Input(I);				-- rising edge detection
		Changed_Clk2		<= syncClk2_Out(I) XOR D2;		-- level change detection; restore strobe signal from flag
		Busy_i					<= T1 XOR syncClk1_Out(I);		-- calculate busy signal

		-- output signals
		Output(I)				<= Changed_Clk2;
		Busy(I)					<= Busy_i;
	END GENERATE;
	
	syncClk2 : ENTITY PoC.misc_Synchronizer_Flag
		GENERIC MAP (
			BITS				=> BITS						-- number of bit to be synchronized
		)
		PORT MAP (
			Clock				=> Clock2,				-- <Clock>	output clock domain
			Input				=> syncClk2_In,		-- @async:	input bits
			Output			=> syncClk2_Out		-- @Clock:	output bits
		);
	
	syncClk1 : ENTITY PoC.misc_Synchronizer_Flag
		GENERIC MAP (
			BITS				=> BITS						-- number of bit to be synchronized
		)
		PORT MAP (
			Clock				=> Clock1,				-- <Clock>	output clock domain
			Input				=> syncClk1_In,		-- @async:	input bits
			Output			=> syncClk1_Out		-- @Clock:	output bits
		);
END;