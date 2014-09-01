-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Steffen Köhler
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


ENTITY misc_VectorSynchronizer IS
  GENERIC (
	  BITS								: POSITIVE					:= 8;											-- number of bit to be synchronized
		INIT								: STD_LOGIC_VECTOR	:= x"00"									-- 
	);
  PORT (
		Clock1							: IN	STD_LOGIC;															-- <Clock>	input clock
		Clock2							: IN	STD_LOGIC;															-- <Clock>	output clock
		I										: IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- @Clock1:	input vector
		O										: OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- @Clock2:	output vector
		Busy								: OUT	STD_LOGIC;															-- @Clock1:	busy bit 
		Changed							: OUT	STD_LOGIC																-- @Clock2:	changed bit
	);
END;


ARCHITECTURE rtl OF misc_VectorSynchronizer IS
	ATTRIBUTE TIG									: STRING;
	ATTRIBUTE ASYNC_REG						: STRING;
	ATTRIBUTE SHREG_EXTRACT				: STRING;
	
	SIGNAL Q0											: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)			:= INIT(BITS - 1 DOWNTO 0);
	SIGNAL Q1											: STD_LOGIC																:= '0';
	SIGNAL Q2											: STD_LOGIC																:= '0';
	SIGNAL Q3											: STD_LOGIC																:= '0';
	SIGNAL Q4											: STD_LOGIC																:= '0';
	SIGNAL Q5											: STD_LOGIC																:= '0';
	SIGNAL Q6											: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)			:= INIT(BITS - 1 DOWNTO 0);
	SIGNAL Q7											: STD_LOGIC																:= '0';
	SIGNAL Q8											: STD_LOGIC																:= '0';

	SIGNAL Busy_i									: STD_LOGIC;
	SIGNAL Changed_i							: STD_LOGIC;
	
	-- Mark registers Q1 and Q4  as asynchronous
	ATTRIBUTE TIG				OF Q2			: SIGNAL IS "TRUE";
	ATTRIBUTE TIG				OF Q6			: SIGNAL IS "TRUE";
	ATTRIBUTE TIG				OF Q7			: SIGNAL IS "TRUE";
	
	ATTRIBUTE ASYNC_REG OF Q2			: SIGNAL IS "TRUE";
	ATTRIBUTE ASYNC_REG OF Q6			: SIGNAL IS "TRUE";
	ATTRIBUTE ASYNC_REG OF Q7			: SIGNAL IS "TRUE";

	-- Prevent XST from translating two FFs into SRL plus FF
	ATTRIBUTE SHREG_EXTRACT OF Q0	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF Q1	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF Q2	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF Q3	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF Q4	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF Q5	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF Q6	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF Q7	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF Q8	: SIGNAL IS "NO";

BEGIN

	-- input D-FF @Clock1 -> changed detection
	PROCESS(Clock1)
	BEGIN
		IF rising_edge(Clock1) THEN
			Q0	<= I;
			Q1	<= Q1 XOR to_sl(Q0 /= I);
		END IF;
	END PROCESS;
			
	-- D-FFs @Clock2
	PROCESS(Clock2)
	BEGIN
		IF rising_edge(Clock2) THEN
			Q2	<= Q1;
			Q3	<= Q2;
			Q4	<= Q3;
			Q5	<= Changed_i;						-- delay changed signal before output
			
			-- Capture-FFs
			IF (Changed_i = '1') THEN
				Q6		<= Q0;
			END IF;
		END IF;
	END PROCESS;

	-- D-FFs @Clock1
	PROCESS(Clock1)
	BEGIN
		IF rising_edge(Clock1) THEN
			Q7	<= Q4;
			Q8	<= Q7;
		END IF;
	END PROCESS;

	Busy_i		<= Q1 XOR Q8;			-- calculate busy signal
	Changed_i	<= Q3 XOR Q4;			-- restore changed information from T-FF
	
	-- assign internal signals to outputs
	O					<= Q6;
	Busy			<= Busy_i;	
	Changed		<= Q5;
	
END;