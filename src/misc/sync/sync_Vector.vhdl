-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Steffen Koehler
--									Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		This module synchronizes a vector of bits from clock domain 'Clock1' to
--		clock domain 'Clock2'. The clock domain boundary crossing is done by a
--		change comparator, a T-FF, two synchronizer D-FFs and a reconstructive
--		XOR indicating a value change on the input. This changed signal is used
--		to capture the input for the new output. A busy flag is additionally
--		calculated for the input clock domain.
-- 
--		CONSTRAINTS:
--			General:
--				This module uses sub modules which need to be constrainted. Please
--				attend to the notes of the instantiated sub modules.
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
USE			PoC.utils.ALL;


ENTITY sync_Vector IS
  GENERIC (
	  BITS								: POSITIVE					:= 8;											-- number of bit to be synchronized
		INIT								: STD_LOGIC_VECTOR	:= x"00000000"						-- 
	);
  PORT (
		Clock1							: IN	STD_LOGIC;															-- <Clock>	input clock
		Clock2							: IN	STD_LOGIC;															-- <Clock>	output clock
		Input								: IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- @Clock1:	input vector
		Output							: OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- @Clock2:	output vector
		Busy								: OUT	STD_LOGIC;															-- @Clock1:	busy bit 
		Changed							: OUT	STD_LOGIC																-- @Clock2:	changed bit
	);
END;


ARCHITECTURE rtl OF sync_Vector IS
	ATTRIBUTE SHREG_EXTRACT				: STRING;
	
	CONSTANT INIT_I								: STD_LOGIC_VECTOR												:= descend(INIT)(BITS - 1 DOWNTO 0);
	
	SIGNAL D0											: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)			:= INIT_I;
	SIGNAL T1											: STD_LOGIC																:= '0';
	SIGNAL D2											: STD_LOGIC																:= '0';
	SIGNAL D3											: STD_LOGIC																:= '0';
	SIGNAL D4											: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)			:= INIT_I;

	SIGNAL Changed_Clk1						: STD_LOGIC;
	SIGNAL Changed_Clk2						: STD_LOGIC;
	SIGNAL Busy_i									: STD_LOGIC;
	
	-- Prevent XST from translating two FFs into SRL plus FF
	ATTRIBUTE SHREG_EXTRACT OF D0	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF T1	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF D2	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF D3	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF D4	: SIGNAL IS "NO";

	SIGNAL syncClk1_In		: STD_LOGIC;
	SIGNAL syncClk1_Out		: STD_LOGIC;
	SIGNAL syncClk2_In		: STD_LOGIC;
	SIGNAL syncClk2_Out		: STD_LOGIC;

BEGIN

	-- input D-FF @Clock1 -> changed detection
	PROCESS(Clock1)
	BEGIN
		IF rising_edge(Clock1) THEN
			IF (Busy_i = '0') THEN
				D0	<= Input;									-- delay input vector for change detection; gated by busy flag
				T1	<= T1 XOR Changed_Clk1;		-- toggle T1 if input vector has changed
			END IF;
		END IF;
	END PROCESS;
	
	-- D-FF for level change detection (both edges)
	PROCESS(Clock2)
	BEGIN
		IF rising_edge(Clock2) THEN
			D2		<= syncClk2_Out;
			D3		<= Changed_Clk2;
			
			IF (Changed_Clk2 = '1') THEN
				D4	<= D0;
			END IF;
		END IF;
	END PROCESS;

	-- assign syncClk*_In signals
	syncClk2_In		<= T1;
	syncClk1_In		<= D2;
	
	Changed_Clk1	<='0' WHEN (D0 = Input) ELSE '1';		-- input change detection
	Changed_Clk2	<= syncClk2_Out XOR D2;							-- level change detection; restore strobe signal from flag
	Busy_i				<= T1 XOR syncClk1_Out;							-- calculate busy signal
	
	-- output signals
	Output				<= D4;
	Busy					<= Busy_i;
	Changed				<= D3;
		
	syncClk2 : ENTITY PoC.sync_Flag
		GENERIC MAP (
			BITS				=> 1							-- number of bit to be synchronized
		)
		PORT MAP (
			Clock				=> Clock2,				-- <Clock>	output clock domain
			Input(0)		=> syncClk2_In,		-- @async:	input bits
			Output(0)		=> syncClk2_Out		-- @Clock:	output bits
		);
	
	syncClk1 : ENTITY PoC.sync_Flag
		GENERIC MAP (
			BITS				=> 1							-- number of bit to be synchronized
		)
		PORT MAP (
			Clock				=> Clock1,				-- <Clock>	output clock domain
			Input(0)		=> syncClk1_In,		-- @async:	input bits
			Output(0)		=> syncClk1_Out		-- @Clock:	output bits
		);
END;