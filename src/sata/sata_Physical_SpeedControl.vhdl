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
--		TODO
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
USE			PoC.vectors.ALL;
USE			PoC.components.ALL;
USE			PoC.sata.ALL;
USE			PoC.satadbg.ALL;


ENTITY sata_Physical_SpeedControl IS
	GENERIC (
		DEBUG											: BOOLEAN							:= FALSE;												-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: BOOLEAN							:= FALSE;												-- enables the assignment of signals to the debugport
		INITIAL_SATA_GENERATION		: T_SATA_GENERATION		:= C_SATA_GENERATION_MAX;
		GENERATION_CHANGE_COUNT		: INTEGER							:= 32;
		ATTEMPTS_PER_GENERATION		: INTEGER							:= 8
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		ClockEnable								: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;

		Command										: IN	T_SATA_PHY_SPEED_COMMAND;
		Status										: OUT	T_SATA_PHY_SPEED_STATUS;
		SATAGenerationMin					: IN	T_SATA_GENERATION;									-- 
		SATAGenerationMax					: IN	T_SATA_GENERATION;									-- 

		DebugPortOut							: OUT	T_SATADBG_PHYSICAL_SPEEDCONTROL_OUT;

		OOBC_Timeout							: IN	STD_LOGIC;
		OOBC_Retry								: OUT	STD_LOGIC;
		
		-- reconfiguration interface
		Trans_RP_Reconfig					: OUT	STD_LOGIC;
		Trans_RP_SATAGeneration		: OUT	T_SATA_GENERATION;									-- 
		Trans_RP_ReconfigComplete	: IN	STD_LOGIC;
		Trans_RP_ConfigReloaded		: IN	STD_LOGIC;
		Trans_RP_Lock							: OUT	STD_LOGIC;
		Trans_RP_Locked						: IN	STD_LOGIC
	);
END;


ARCHITECTURE rtl OF sata_Physical_SpeedControl IS
	ATTRIBUTE KEEP					: BOOLEAN;
	ATTRIBUTE FSM_ENCODING	: STRING;

	TYPE T_SGEN_SGEN	IS ARRAY (T_SATA_GENERATION) OF T_SATA_GENERATION;
	TYPE T_SGEN2_SGEN	IS ARRAY (T_SATA_GENERATION) OF T_SGEN_SGEN;
	TYPE T_SGEN3_SGEN	IS ARRAY (T_SATA_GENERATION) OF T_SGEN2_SGEN;

	FUNCTION StartGen RETURN T_SGEN2_SGEN IS
		CONSTANT ERROR_VALUE	: T_SATA_GENERATION	:= ite(SIMULATION, SATA_GENERATION_ERROR, SATA_GENERATION_1);
		VARIABLE SG						: T_SGEN2_SGEN			:= (OTHERS => (OTHERS => ERROR_VALUE));
	BEGIN
		-- minimal			/	maximal gen.		==>	cmp value
		-- ========================================================================
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_3;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_1)				:= SATA_GENERATION_1;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_2)				:= SATA_GENERATION_2;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_3)				:= SATA_GENERATION_3;
	
		SG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		SG(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		SG(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		
		SG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		SG(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		SG(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		SG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		SG(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		SG(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
				
		RETURN SG;
	END;
	
	FUNCTION NextGen RETURN T_SGEN3_SGEN IS
		CONSTANT ERROR_VALUE	: T_SATA_GENERATION	:= ite(SIMULATION, SATA_GENERATION_ERROR, SATA_GENERATION_1);
		VARIABLE NG						: T_SGEN3_SGEN			:= (OTHERS => (OTHERS => (OTHERS => ERROR_VALUE)));
	BEGIN
		-- current 		/ minimal			/	maximal gen.		==>	next gen.
		-- ========================================================================
		-- current generation is SATA_GENERATION_1
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_1)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_2)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_3)			:= SATA_GENERATION_3;
		
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		-- current generation is SATA_GENERATION_2
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_1)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_2)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_3)			:= SATA_GENERATION_1;
		
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_1;

		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		-- current generation is SATA_GENERATION_3
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_1)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_2)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_3)			:= SATA_GENERATION_2;
		
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_2;

		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_2;

		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		RETURN NG;
	END;
	
	CONSTANT ROM_StartGeneration							: T_SGEN2_SGEN	:= StartGen;
	CONSTANT ROM_NextGeneration 							: T_SGEN3_SGEN	:= NextGen;

	CONSTANT GENERATION_CHANGE_COUNTER_BITS		: POSITIVE			:= log2ceilnz(GENERATION_CHANGE_COUNT);
	CONSTANT TRY_PER_GENERATION_COUNTER_BITS	: POSITIVE			:= log2ceilnz(ATTEMPTS_PER_GENERATION);

	TYPE T_STATE IS (
		ST_RESET,
		ST_RECONFIG,		ST_RECONFIG_WAIT,
		ST_NEGOTIATION,	ST_RETRY,
		ST_TIMEOUT,
		ST_NEGOTIATION_ERROR
	);
	
	-- Speed Negotiation - Statemachine
	SIGNAL State												: T_STATE												:= ST_RESET;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State		: SIGNAL IS getFSMEncoding_gray(DEBUG);

	SIGNAL Status_i											: T_SATA_PHY_SPEED_STATUS;

	SIGNAL SATAGeneration_rst						: STD_LOGIC;
	SIGNAL SATAGeneration_Change				: STD_LOGIC;
	SIGNAL SATAGeneration_Changed				: STD_LOGIC;
	SIGNAL SATAGeneration_cur						: T_SATA_GENERATION							:= INITIAL_SATA_GENERATION;
	SIGNAL SATAGeneration_nxt						: T_SATA_GENERATION;

	SIGNAL OOBC_Retry_i									: STD_LOGIC;
	SIGNAL Trans_RP_Reconfig_i					: STD_LOGIC;
	SIGNAL Trans_RP_Lock_i							: STD_LOGIC;
	
	SIGNAL GenerationChange_Counter_rst	: STD_LOGIC;
	SIGNAL GenerationChange_Counter_en	: STD_LOGIC;
	SIGNAL GenerationChange_Counter_us	: UNSIGNED(GENERATION_CHANGE_COUNTER_BITS DOWNTO 0) := (OTHERS => '0');
	SIGNAL GenerationChange_Counter_ov	: STD_LOGIC;
	
	SIGNAL TryPerGeneration_Counter_rst	: STD_LOGIC;
	SIGNAL TryPerGeneration_Counter_en	: STD_LOGIC;
	SIGNAL TryPerGeneration_Counter_us	: UNSIGNED(TRY_PER_GENERATION_COUNTER_BITS DOWNTO 0) := (OTHERS => '0');
	SIGNAL TryPerGeneration_Counter_ov	: STD_LOGIC;
	
BEGIN

	-- ===========================================================================
	-- Speed Negotiation - Statemachine
	-- ===========================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (ClockEnable = '1') THEN
				SATAGeneration_cur	<= SATAGeneration_nxt;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(SATAGeneration_rst, SATAGeneration_cur, SATAGeneration_Change, SATAGenerationMin, SATAGenerationMax)
		VARIABLE SATAGeneration_nxt_v : T_SATA_GENERATION;
	BEGIN
		SATAGeneration_nxt				<= SATAGeneration_cur;
		SATAGeneration_Changed		<= '0';
		
		IF (SATAGeneration_Change = '1') THEN
			IF (SATAGeneration_rst = '1') THEN
				SATAGeneration_nxt_v	:= ROM_StartGeneration(SATAGenerationMin)(SATAGenerationMax);
			ELSE
				SATAGeneration_nxt_v	:= ROM_NextGeneration(SATAGeneration_cur)(SATAGenerationMin)(SATAGenerationMax);
			END IF;
			
			-- test if generation is going to be changed
			SATAGeneration_Changed	<= to_sl(SATAGeneration_cur /= SATAGeneration_nxt_v);
			
			-- assign new generation to *_nxt signal
			SATAGeneration_nxt			<= SATAGeneration_nxt_v;
		END IF;
	END PROCESS;

	-- export current SATA generation to other layers
	Trans_RP_SATAGeneration <= SATAGeneration_cur;


	-- ===========================================================================
	-- SpeedControl - Statemachine
	-- ===========================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State	<= ST_RESET;
			ELSIF (ClockEnable = '1') THEN
				State	<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State,
					Command,
					OOBC_Timeout,
					Trans_RP_ConfigReloaded,
					SATAGeneration_Changed,
					TryPerGeneration_Counter_ov, GenerationChange_Counter_ov)
	BEGIN
		NextState														<= State;
		
		Status_i														<= SATA_PHY_SPEED_STATUS_RESET;
		
		SATAGeneration_rst									<= '0';
		SATAGeneration_Change								<= '0';
		OOBC_Retry_i												<= '0';
		Trans_RP_Reconfig_i									<= '0';
		Trans_RP_Lock_i											<= '1';
		
		TryPerGeneration_Counter_rst				<= '0';
		TryPerGeneration_Counter_en					<= '0';
		GenerationChange_Counter_rst				<= '0';
		GenerationChange_Counter_en					<= '0';
	
		CASE State IS
			WHEN ST_RESET =>
				Status_i												<= SATA_PHY_SPEED_STATUS_RESET;
				
				IF (Command = SATA_PHY_SPEED_CMD_RESET) THEN
					SATAGeneration_rst						<= '1';
					TryPerGeneration_Counter_rst	<= '1';
					GenerationChange_Counter_rst	<= '1';
					NextState											<= ST_RETRY;
					
				ELSIF (Command = SATA_PHY_SPEED_CMD_NEWLINK_UP) THEN
--					SATAGeneration_rst						<= '1';
					TryPerGeneration_Counter_rst	<= '1';
--					GenerationChange_Counter_rst	<= '1';
					NextState											<= ST_RETRY;
				END IF;
			
			WHEN ST_RETRY =>
				Status_i												<= SATA_PHY_SPEED_STATUS_NEGOTIATING;
				OOBC_Retry_i										<= '1';
				NextState												<= ST_NEGOTIATION;
			
			WHEN ST_NEGOTIATION =>
				Status_i												<= SATA_PHY_SPEED_STATUS_NEGOTIATING;
				
				IF (Command = SATA_PHY_SPEED_CMD_NEWLINK_UP) THEN
					-- TODO:
				END IF;
				
				IF (OOBC_Timeout = '1') THEN
					NextState											<= ST_TIMEOUT;
				END IF;
			
			WHEN ST_TIMEOUT =>
				Status_i												<= SATA_PHY_SPEED_STATUS_NEGOTIATING;
				
				IF (TryPerGeneration_Counter_ov = '1') THEN
					IF (GenerationChange_Counter_ov = '1') THEN
						NextState										<= ST_NEGOTIATION_ERROR;
					ELSE																					-- generation change counter allows => generation change
						SATAGeneration_Change				<= '1';
						TryPerGeneration_Counter_rst<= '1';
						GenerationChange_Counter_en	<= '1';
						
						IF (SATAGeneration_Changed = '1') THEN
							NextState									<= ST_RECONFIG;
						ELSE
							NextState									<= ST_RETRY;
						END IF;
					END IF;
				ELSE																						-- tries per generation counter allows an other try at current generation
					TryPerGeneration_Counter_en		<= '1';
					NextState											<= ST_RETRY;
				END IF;

			WHEN ST_RECONFIG =>
				Status_i												<= SATA_PHY_SPEED_STATUS_RECONFIGURATING;
				Trans_RP_Lock_i									<= '0';
				Trans_RP_Reconfig_i							<= '1';
				NextState												<= ST_RECONFIG_WAIT;

			WHEN ST_RECONFIG_WAIT =>
				Status_i												<= SATA_PHY_SPEED_STATUS_RECONFIGURATING;
				Trans_RP_Lock_i									<= '0';
				
				IF (Trans_RP_ConfigReloaded = '1') THEN
					NextState											<= ST_RETRY;
				END IF;

			WHEN ST_NEGOTIATION_ERROR =>
				Trans_RP_Lock_i									<= '0';
				Status_i												<= SATA_PHY_SPEED_STATUS_NEGOTIATION_ERROR;
				
				IF (Command = SATA_PHY_SPEED_CMD_RESET) THEN
					SATAGeneration_rst						<= '1';
					TryPerGeneration_Counter_rst	<= '1';
					GenerationChange_Counter_rst	<= '1';
					NextState											<= ST_RETRY;
					
				ELSIF (Command = SATA_PHY_SPEED_CMD_NEWLINK_UP) THEN
--					SATAGeneration_rst						<= '1';
					TryPerGeneration_Counter_rst	<= '1';
--					GenerationChange_Counter_rst	<= '1';
					NextState											<= ST_RETRY;
				END IF;

		END CASE;
	END PROCESS;

	Status						<= Status_i;
	OOBC_Retry				<= OOBC_Retry_i;
	Trans_RP_Reconfig	<= Trans_RP_Reconfig_i;
	Trans_RP_Lock			<= Trans_RP_Lock_i;

	-- ================================================================
	-- try counters
	-- ================================================================
	TryPerGeneration_Counter_us	<= counter_inc(TryPerGeneration_Counter_us, TryPerGeneration_Counter_rst,	TryPerGeneration_Counter_en) WHEN rising_edge(Clock);		-- count attempts per generation
	GenerationChange_Counter_us	<= counter_inc(GenerationChange_Counter_us, GenerationChange_Counter_rst,	GenerationChange_Counter_en) WHEN rising_edge(Clock);		-- count generation changes
	
	TryPerGeneration_Counter_ov	<= counter_eq(TryPerGeneration_Counter_us, ATTEMPTS_PER_GENERATION);
	GenerationChange_Counter_ov	<= counter_eq(GenerationChange_Counter_us, GENERATION_CHANGE_COUNT);
	
		
	-- debug port
	-- ===========================================================================
	genDebug : IF (ENABLE_DEBUGPORT = TRUE) GENERATE
	
		FUNCTION dbg_EncodeState(State : T_STATE) RETURN STD_LOGIC_VECTOR IS
			CONSTANT ResultSize		: POSITIVE																	:= log2ceilnz(T_STATE'pos(T_STATE'high));
			CONSTANT Result				: STD_LOGIC_VECTOR(ResultSize - 1 DOWNTO 0)	:= to_slv(T_STATE'pos(State), ResultSize);
		BEGIN
			RETURN ite(DEBUG, bin2gray(Result), Result);
		END FUNCTION;
		
	BEGIN
		DebugPortOut.FSM										<= dbg_EncodeState(State);
		DebugPortOut.Status									<= Status_i;
		DebugPortOut.SATAGeneration					<= SATAGeneration_cur;
		DebugPortOut.SATAGeneration_Reset		<= SATAGeneration_rst;
		DebugPortOut.SATAGeneration_Change	<= SATAGeneration_Change;
		DebugPortOut.SATAGeneration_Changed	<= SATAGeneration_Changed;
		DebugPortOut.OOBC_Retry							<= OOBC_Retry_i;
		DebugPortOut.OOBC_Timeout						<= OOBC_Timeout;
		DebugPortOut.Trans_Reconfig					<= Trans_RP_Reconfig_i;
		DebugPortOut.Trans_ReconfigComplete	<= Trans_RP_ReconfigComplete;
		DebugPortOut.Trans_ConfigReloaded		<= Trans_RP_ConfigReloaded;
		DebugPortOut.GenerationChanges			<= resize(std_logic_vector(GenerationChange_Counter_us), DebugPortOut.GenerationChanges'length);
		DebugPortOut.TrysPerGeneration			<= resize(std_logic_vector(TryPerGeneration_Counter_us), DebugPortOut.TrysPerGeneration'length);
	END GENERATE;
END;
