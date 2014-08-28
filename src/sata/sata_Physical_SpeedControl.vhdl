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


ENTITY sata_SpeedControl IS
	GENERIC (
		DEBUG											: BOOLEAN							:= FALSE;												-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: BOOLEAN							:= FALSE;												-- enables the assignment of signals to the debugport
		INITIAL_SATA_GENERATION		: T_SATA_GENERATION		:= C_SATA_GENERATION_MAX;
		GENERATION_CHANGE_COUNT		: INTEGER							:= 32;
		ATTEMPTS_PER_GENERATION		: INTEGER							:= 8
	);
	PORT (
		Clock										: IN	STD_LOGIC;
		Reset										: IN	STD_LOGIC;

		SATAGeneration_Reset		: IN	STD_LOGIC;													--	=> reset SATA_Generation, reset all attempt counters => if necessary reconfigure MGT
		AttemptCounter_Reset		: IN	STD_LOGIC;													-- 

		DebugPortOut						: OUT	T_SATADBG_PHYSICAL_SPEEDCONTROL_OUT;

		OOB_Timeout							: IN	STD_LOGIC;
		OOB_Retry								: OUT	STD_LOGIC;

		SATA_GenerationMin			: IN	T_SATA_GENERATION;									-- 
		SATA_GenerationMax			: IN	T_SATA_GENERATION;									-- 
		SATA_Generation					: OUT	T_SATA_GENERATION;									-- 
		NegotiationError				: OUT	STD_LOGIC;													-- speed negotiation unsuccessful
		
		-- reconfiguration interface
		Trans_Reconfig					: OUT	STD_LOGIC;
		Trans_ConfigReloaded		: IN	STD_LOGIC;
		Trans_Lock							: OUT	STD_LOGIC;
		Trans_Locked						: IN	STD_LOGIC
	);
END;


ARCHITECTURE rtl OF sata_SpeedControl IS
	ATTRIBUTE KEEP : BOOLEAN;
	ATTRIBUTE FSM_ENCODING	: STRING;

	FUNCTION StartGen RETURN T_SGEN2_SGEN IS
		VARIABLE SG : T_SGEN2_SGEN := (OTHERS => (OTHERS => SATA_GENERATION_ERROR));
	BEGIN
		-- minimal			/	maximal gen.		==>	cmp value
		-- ========================================================================
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_3;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_1)				:= SATA_GENERATION_1;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_2)				:= SATA_GENERATION_2;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_3)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_ERROR)		:= SATA_GENERATION_ERROR;
	
		SG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		SG(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		SG(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		SG(SATA_GENERATION_1)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;
		
		SG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		SG(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		SG(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		SG(SATA_GENERATION_2)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		SG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		SG(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		SG(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		SG(SATA_GENERATION_3)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;
				
		RETURN SG;
	END;
	
	FUNCTION CmpGen RETURN T_SGEN2_INT IS
		VARIABLE CG : T_SGEN2_INT := (OTHERS => (OTHERS => -10));
	BEGIN
		-- minimal			/	maximal gen.		==>	cmp value
		-- ========================================================================
		CG(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= 0;
		CG(SATA_GENERATION_AUTO)(SATA_GENERATION_1)				:= 10;
		CG(SATA_GENERATION_AUTO)(SATA_GENERATION_2)				:= 10;
		CG(SATA_GENERATION_AUTO)(SATA_GENERATION_3)				:= 10;
		CG(SATA_GENERATION_AUTO)(SATA_GENERATION_ERROR)		:= -10;
		
		CG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)				:= 10;
		CG(SATA_GENERATION_1)(SATA_GENERATION_1)					:= 0;
		CG(SATA_GENERATION_1)(SATA_GENERATION_2)					:= -1;
		CG(SATA_GENERATION_1)(SATA_GENERATION_3)					:= -1;
		CG(SATA_GENERATION_1)(SATA_GENERATION_ERROR)			:= -10;

		CG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)				:= 10;
		CG(SATA_GENERATION_2)(SATA_GENERATION_1)					:= 1;
		CG(SATA_GENERATION_2)(SATA_GENERATION_2)					:= 0;
		CG(SATA_GENERATION_2)(SATA_GENERATION_3)					:= -1;
		CG(SATA_GENERATION_2)(SATA_GENERATION_ERROR)			:= -10;	

		CG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)				:= 10;
		CG(SATA_GENERATION_3)(SATA_GENERATION_1)					:= 1;
		CG(SATA_GENERATION_3)(SATA_GENERATION_2)					:= 1;
		CG(SATA_GENERATION_3)(SATA_GENERATION_3)					:= 0;
		CG(SATA_GENERATION_3)(SATA_GENERATION_ERROR)			:= -10;	

		RETURN CG;
	END;
	
	FUNCTION NextGen RETURN T_SGEN3_SGEN IS
		VARIABLE NG : T_SGEN3_SGEN := (OTHERS => (OTHERS => (OTHERS => SATA_GENERATION_ERROR)));
	BEGIN
		-- current 		/ minimal			/	maximal gen.		==>	next gen.
		-- ========================================================================
		-- current generation is SATA_GENERATION_1
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_1)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_2)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_3)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_ERROR)	:= SATA_GENERATION_ERROR;
		
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		-- current generation is SATA_GENERATION_2
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_1)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_2)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_3)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_ERROR)	:= SATA_GENERATION_ERROR;
		
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		-- current generation is SATA_GENERATION_3
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_1)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_2)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_3)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_ERROR)	:= SATA_GENERATION_ERROR;
		
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_ERROR)			:= SATA_GENERATION_ERROR;

		RETURN NG;
	END;
	
	CONSTANT CmpGeneration		: T_SGEN2_INT		:= CmpGen;
	CONSTANT StartGeneration	: T_SGEN2_SGEN	:= StartGen;
	CONSTANT NextGeneration 	: T_SGEN3_SGEN	:= NextGen;

	CONSTANT GENERATION_CHANGE_COUNTER_BITS		: POSITIVE := log2ceilnz(GENERATION_CHANGE_COUNT);
	CONSTANT TRY_PER_GENERATION_COUNTER_BITS	: POSITIVE := log2ceilnz(ATTEMPTS_PER_GENERATION);

	TYPE T_STATE IS (
		ST_RECONFIG, ST_RECONFIG_WAIT,
		ST_RETRY, ST_WAIT, ST_TIMEOUT,
		ST_NEGOTIATION_ERROR
	);
	
	FUNCTION to_slv(State : T_STATE) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN to_slv(T_STATE'pos(State), log2ceilnz(T_STATE'pos(T_STATE'high)));
	END FUNCTION;
	
	-- Speed Negotiation - Statemachine
	SIGNAL State				: T_STATE := ST_WAIT;
	SIGNAL NextState		: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State	: SIGNAL IS getFSMEncoding_gray(DEBUG);

	SIGNAL SATAGeneration_Current		: T_SATA_GENERATION := INITIAL_SATA_GENERATION;
	SIGNAL SATAGeneration_Next			: T_SATA_GENERATION;

	SIGNAL ChangeGeneration					: STD_LOGIC;
	SIGNAL GenerationChanged				: STD_LOGIC;

	SIGNAL ResetGeneration					: STD_LOGIC := '0';
	
	SIGNAL GenerationChange_Counter_en	: STD_LOGIC;
	SIGNAL GenerationChange_Counter_us	: UNSIGNED(GENERATION_CHANGE_COUNTER_BITS DOWNTO 0) := (OTHERS => '0');
	SIGNAL GenerationChange_Counter_ov	: STD_LOGIC;
	
	SIGNAL TryPerGeneration_Counter_en	: STD_LOGIC;
	SIGNAL TryPerGeneration_Counter_us	: UNSIGNED(TRY_PER_GENERATION_COUNTER_BITS DOWNTO 0) := (OTHERS => '0');
	SIGNAL TryPerGeneration_Counter_ov	: STD_LOGIC;
	
BEGIN
	ASSERT (CmpGeneration(SATA_GenerationMax)(SATA_GenerationMin) >= 0) REPORT "min is less then max" SEVERITY ERROR;

-- ==================================================================
-- Speed Negotiation - Statemachine
-- ==================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			SATAGeneration_Current	<= SATAGeneration_Next;
		END IF;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF SATAGeneration_Reset = '1' THEN
				ResetGeneration <= '1';
			ELSIF ChangeGeneration = '1' THEN
				ResetGeneration <= '0';
			END IF;
		END IF;
	END PROCESS;

	PROCESS(ResetGeneration, ChangeGeneration, SATAGeneration_Current, SATA_GenerationMin, SATA_GenerationMax)
		VARIABLE SATAGeneration_Next_v : T_SATA_GENERATION;
	BEGIN
		SATAGeneration_Next	<= SATAGeneration_Current;
		
		GenerationChanged	<= '0';
		
		IF (ChangeGeneration = '1') THEN
			IF (ResetGeneration = '1') THEN
				SATAGeneration_Next_v	:= StartGeneration(SATA_GenerationMin)(SATA_GenerationMax);
			ELSE
				SATAGeneration_Next_v	:= NextGeneration(SATAGeneration_Current)(SATA_GenerationMin)(SATA_GenerationMax);
			END IF;
			
			SATAGeneration_Next	<= SATAGeneration_Next_v;
			
			IF (SATAGeneration_Current /= SATAGeneration_Next_v) THEN
				GenerationChanged	<= '1';
			END IF;
		END IF;
	END PROCESS;

	SATA_Generation <= SATAGeneration_Current;


-- ==================================================================
-- SpeedControl - Statemachine
-- ==================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State	<= ST_WAIT;
			ELSE
				State	<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Trans_ConfigReloaded, OOB_Timeout, Reset, ResetGeneration, GenerationChanged, TryPerGeneration_Counter_ov, GenerationChange_Counter_ov)
	BEGIN
		NextState			<= State;
		
		ChangeGeneration			<= '0';
		Trans_Reconfig				<= '0';
		Trans_Lock				<= '1';
		OOB_Retry				<= '0';
		NegotiationError			<= '0';
		
		TryPerGeneration_Counter_en		<= '0';
		GenerationChange_Counter_en		<= '0';
	
		CASE State IS

			WHEN ST_WAIT =>
				IF (ResetGeneration = '1') THEN
					ChangeGeneration <= not Reset;
					IF (GenerationChanged = '1') THEN
						NextState <= ST_RECONFIG;
					END IF;
				ELSIF (OOB_Timeout = '1') THEN
					NextState <= ST_TIMEOUT;
				END IF;
				
			WHEN ST_TIMEOUT =>
				IF (TryPerGeneration_Counter_ov = '1') THEN
					IF (GenerationChange_Counter_ov = '1') THEN
						NextState		<= ST_NEGOTIATION_ERROR;
					ELSE																													-- generation change counter allows => generation change
						ChangeGeneration		<= '1';
						GenerationChange_Counter_en	<= '1';
						
						IF (GenerationChanged = '1') THEN
							NextState		<= ST_RECONFIG;
						ELSE
							NextState		<= ST_RETRY;
						END IF;
					END IF;
				ELSE																														-- tries per generation counter allows an other try at current generation
					NextState		<= ST_RETRY;
				END IF;

			WHEN ST_RECONFIG =>
				Trans_Lock			<= '0';
				Trans_Reconfig			<= '1';
				
				NextState		<= ST_RECONFIG_WAIT;

			WHEN ST_RECONFIG_WAIT =>
				Trans_Lock			<= '0';
				
				IF (Trans_ConfigReloaded = '1') THEN
					NextState		<= ST_RETRY;
				END IF;

			WHEN ST_RETRY =>
				OOB_Retry			<= '1';
				TryPerGeneration_Counter_en	<= '1';

				NextState		<= ST_WAIT;
			
			WHEN ST_NEGOTIATION_ERROR =>
				Trans_Lock			<= '0';
				NegotiationError		<= '1';

		END CASE;
	END PROCESS;


	-- ================================================================
	-- try counters
	-- ================================================================
	TryPerGeneration_Counter_us	<= counter_inc(TryPerGeneration_Counter_us, (Reset or ChangeGeneration),	TryPerGeneration_Counter_en) WHEN rising_edge(Clock);		-- count attempts per generation
	GenerationChange_Counter_us	<= counter_inc(GenerationChange_Counter_us, AttemptCounter_Reset,						GenerationChange_Counter_en) WHEN rising_edge(Clock);		-- count generation changes
	
	TryPerGeneration_Counter_ov	<= counter_eq(TryPerGeneration_Counter_us, ATTEMPTS_PER_GENERATION);
	GenerationChange_Counter_ov	<= counter_eq(GenerationChange_Counter_us, GENERATION_CHANGE_COUNT);
	
		
	-- Debug signals
	-- ===========================================================================
	genDBG : IF (DEBUG = TRUE) GENERATE
		SIGNAL DBG_ChangeGeneration	: STD_LOGIC;
		SIGNAL DBG_GenerationChanged	: STD_LOGIC;
	
		ATTRIBUTE KEEP OF DBG_ChangeGeneration		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_GenerationChanged		: SIGNAL IS TRUE;
	BEGIN
		DBG_ChangeGeneration	<= ChangeGeneration;
		DBG_GenerationChanged	<= GenerationChanged;
	END GENERATE;

	-- debug port
	-- ===========================================================================
	genDebug : IF (ENABLE_DEBUGPORT = TRUE) GENERATE
		DebugPortOut.FSM								<= to_slv(State);
		DebugPortOut.GenerationChanges	<= resize(std_logic_vector(GenerationChange_Counter_us), DebugPortOut.GenerationChanges'length);
		DebugPortOut.TrysPerGeneration	<= resize(std_logic_vector(TryPerGeneration_Counter_us), DebugPortOut.TrysPerGeneration'length);
		DebugPortOut.SATAGeneration			<= SATAGeneration_Current;
	END GENERATE;
END;
