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
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;

-- Strategies:
--	RR				RoundRobin
--	LOT				Lottery

ENTITY bus_Arbiter IS
	GENERIC (
		STRATEGY									: STRING										:= "RR";			-- RR, LOT
		PORTS											: POSITIVE									:= 1;
		WEIGHTS										: T_INTVEC									:= (0 => 1);
		OUTPUT_REG								: BOOLEAN										:= TRUE
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		Arbitrate									: IN	STD_LOGIC;
		Request_Vector						: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		Arbitrated								: OUT	STD_LOGIC;
		Grant_Vector							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Grant_Index								: OUT	STD_LOGIC_VECTOR(log2ceilnz(PORTS) - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF bus_Arbiter IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

BEGIN

	-- Assert STRATEGY for known strings
	-- ==========================================================================================================================================================
	ASSERT ((STRATEGY = "RR") OR (STRATEGY = "LOT"))
		REPORT "Unknown arbiter strategy." SEVERITY FAILURE;

	-- Round Robin Arbiter
	-- ==========================================================================================================================================================
	genRR : IF (STRATEGY = "RR") GENERATE
		SIGNAL RequestLeft								: UNSIGNED(PORTS - 1 DOWNTO 0);
		SIGNAL SelectLeft									: UNSIGNED(PORTS - 1 DOWNTO 0);
		SIGNAL SelectRight								: UNSIGNED(PORTS - 1 DOWNTO 0);
		
		SIGNAL ChannelPointer_en					: STD_LOGIC;
		SIGNAL ChannelPointer							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		SIGNAL ChannelPointer_d						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)								:= to_slv(1, PORTS);
		SIGNAL ChannelPointer_nxt					: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	BEGIN

		ChannelPointer_en		<= Arbitrate;

		RequestLeft					<= (NOT ((unsigned(ChannelPointer_d) - 1) OR unsigned(ChannelPointer_d))) AND unsigned(Request_Vector);
		SelectLeft					<= (unsigned(NOT RequestLeft) + 1)		AND RequestLeft;
		SelectRight					<= (unsigned(NOT Request_Vector) + 1)	AND unsigned(Request_Vector);
		ChannelPointer_nxt	<= std_logic_vector(ite((RequestLeft = (RequestLeft'range => '0')), SelectRight, SelectLeft));
	
		-- generate ChannelPointer register and unregistered outputs
		genREG0 : IF (OUTPUT_REG = FALSE) GENERATE
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF (Reset = '1') THEN
						ChannelPointer_d		<= to_slv(1, PORTS);
					ELSIF (ChannelPointer_en = '1') THEN
						ChannelPointer_d		<= ChannelPointer_nxt;
					END IF;
				END IF;
			END PROCESS;

			Arbitrated				<= Arbitrate;
			Grant_Vector			<= ChannelPointer_nxt;
			Grant_Index				<= std_logic_vector(onehot2bin(ChannelPointer_nxt));
		END GENERATE;
		
		-- generate ChannelPointer register and registered outputs
		genREG1 : IF (OUTPUT_REG = TRUE) GENERATE
			SIGNAL ChannelPointer_bin_d				: STD_LOGIC_VECTOR(log2ceilnz(PORTS) - 1 DOWNTO 0)		:= to_slv(0, log2ceilnz(PORTS) - 1);
		BEGIN
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF (Reset = '1') THEN
						ChannelPointer_d			<= to_slv(1, PORTS);
						ChannelPointer_bin_d	<= to_slv(0, log2ceilnz(PORTS) - 1);
					ELSIF (ChannelPointer_en = '1') THEN
						ChannelPointer_d			<= ChannelPointer_nxt;
						ChannelPointer_bin_d	<= std_logic_vector(onehot2bin(ChannelPointer_nxt));
					END IF;
				END IF;
			END PROCESS;
			
			Arbitrated				<= Arbitrate WHEN rising_edge(Clock);
			Grant_Vector			<= ChannelPointer_d;
			Grant_Index				<= ChannelPointer_bin_d;
		END GENERATE;
	END GENERATE;
	
	-- Lottery Arbiter
	-- ==========================================================================================================================================================
	genLOT : IF (STRATEGY = "RR") GENERATE
	
	
	BEGIN
	
	
	END GENERATE;
	
	

	
END ARCHITECTURE;
