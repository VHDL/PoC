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
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.strings.ALL;
USE			PoC.io.ALL;
USE			PoC.sata.ALL;

ENTITY sata_OOBControl_Host IS
	GENERIC (
		DEBUG											: BOOLEAN														:= FALSE;
		CLOCK_IN_FREQ_MHZ					: REAL															:= 150.0;												-- 
		CLOCK_GEN1_FREQ_MHZ				: REAL															:= 37.5;												-- SATAClock frequency in MHz for SATA generation 1
		CLOCK_GEN2_FREQ_MHZ				: REAL															:= 75.0;												-- SATAClock frequency in MHz for SATA generation 2
		ALLOW_STANDARD_VIOLATION	: BOOLEAN														:= FALSE;
		OOB_TIMEOUT_US						: INTEGER														:= 0
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;

		SATA_Generation						: IN	T_SATA_GENERATION;
		Trans_ResetDone						: IN	STD_LOGIC;
		
		OOB_TX_Command						: OUT	T_SATA_OOB;
		OOB_TX_Complete						: IN	STD_LOGIC;
		OOB_RX_Status							: IN	T_SATA_OOB;
		OOB_HandshakingComplete		:	OUT	STD_LOGIC;
		
		OOB_Retry									: IN	STD_LOGIC;
		OOB_LinkOK							: OUT	STD_LOGIC;
		OOB_LinkDead							: OUT	STD_LOGIC;
		OOB_Timeout								: OUT	STD_LOGIC;
		OOB_ReceivedReset					: OUT	STD_LOGIC;
		
		RX_IsAligned							: IN	STD_LOGIC;
		RX_Primitive							: IN	T_SATA_PRIMITIVE;
		TX_Primitive							: OUT	T_SATA_PRIMITIVE
	);
END;

ARCHITECTURE rtl OF sata_OOBControl_Host IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	CONSTANT DEFAULT_OOB_TIMEOUT_US		: POSITIVE				:= 880;
	
	CONSTANT OOB_TIMEOUT_NS						: INTEGER					:= ite((OOB_TIMEOUT_US = 0), DEFAULT_OOB_TIMEOUT_US, OOB_TIMEOUT_US) * 1000;
	CONSTANT COMRESET_TIMEOUT_NS			: INTEGER					:= 450;
	CONSTANT COMWAKE_TIMEOUT_NS				: INTEGER					:= 250;

	TYPE T_OOBCONTROL_STATE IS (
		ST_HOST_RESET,
		ST_HOST_SEND_COMRESET,
		ST_HOST_WAIT_DEV_COMINIT,
		ST_HOST_WAIT_AFTER_DEV_COMINIT,
		ST_HOST_SEND_COMWAKE,
		ST_HOST_WAIT_DEV_COMWAKE,
		ST_HOST_WAIT_AFTER_COMWAKE,
		ST_HOST_WAIT_DEV_NORMAL_MODE,
		ST_HOST_SEND_D10_2,
		ST_HOST_SEND_ALIGN,
		ST_HOST_TIMEOUT,
		ST_HOST_LINK_OK,
		ST_HOST_LINK_BROKEN,
		ST_HOST_LINK_DEAD
	);

	-- OOB-Statemachine
	SIGNAL OOBControl_State					: T_OOBCONTROL_STATE											:= ST_HOST_RESET;
	SIGNAL OOBControl_NextState			: T_OOBCONTROL_STATE;
	ATTRIBUTE FSM_ENCODING OF OOBControl_State		: SIGNAL IS ite(DEBUG					, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	-- Timing-Counter
	-- ================================================================
	-- general timeouts
	SIGNAL TC1_en										: STD_LOGIC;
	SIGNAL TC1_Load									: STD_LOGIC;
	SIGNAL TC1_Slot									: INTEGER;
	SIGNAL TC1_Timeout							: STD_LOGIC;
	
	-- OOB state specific timeouts
	SIGNAL TC2_en										: STD_LOGIC;
	SIGNAL TC2_Load									: STD_LOGIC;
	SIGNAL TC2_Slot									: INTEGER;
	SIGNAL TC2_Timeout							: STD_LOGIC;	
	
	FUNCTION IsSupportedGeneration(SATAGen : T_SATA_GENERATION) RETURN BOOLEAN IS
	BEGIN
		CASE SATAGen IS
			WHEN SATA_GENERATION_1 =>			RETURN TRUE;
			WHEN SATA_GENERATION_2 =>			RETURN TRUE;
			WHEN OTHERS =>								RETURN FALSE;
		END CASE;
	END;
	
BEGIN
	ASSERT IsSupportedGeneration(SATA_Generation)	REPORT "Member of T_SATA_GENERATION not supported" SEVERITY FAILURE;

	-- OOBControl Statemachine
	-- ======================================================================================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				OOBControl_State			<= ST_HOST_RESET;
			ELSE
				OOBControl_State			<= OOBControl_NextState;
			END IF;
		END IF;
	END PROCESS;


	PROCESS(OOBControl_State, Trans_ResetDone, SATA_Generation, OOB_Retry, OOB_TX_Complete, OOB_RX_Status, RX_IsAligned, RX_Primitive, TC1_Timeout, TC2_Timeout)
	BEGIN
		OOBControl_NextState									<= OOBControl_State;
		
		TX_Primitive													<= SATA_PRIMITIVE_DIAL_TONE;
	
		-- general timeout
		TC1_en																<= '1';
		TC1_Load															<= '0';
		TC1_Slot															<= 0;
		
		-- OOB state specific timeouts
		TC2_en																<= '0';
		TC2_Load															<= '0';
		TC2_Slot															<= 0;
	
		OOB_LinkOK														<= '0';
		OOB_LinkDead													<= '0';
		OOB_Timeout														<= '0';
		OOB_ReceivedReset											<= '0';
		
		OOB_TX_Command												<= SATA_OOB_NONE;
		OOB_HandshakingComplete								<= '0';

		-- handle timeout with highest priority
		IF (TC1_Timeout = '1') THEN
			OOB_Timeout													<= '1';
			
			TC1_en															<= '0';
			TC1_Load														<= '1';
			TC1_Slot														<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
			
			OOBControl_NextState								<= ST_HOST_TIMEOUT;
		ELSE
			CASE OOBControl_State IS
				WHEN ST_HOST_RESET =>
					TC1_en													<= '0';
				
					IF (Trans_ResetDone = '1') THEN
						OOB_TX_Command								<= SATA_OOB_COMRESET;
						
						TC1_Load											<= '1';
						TC1_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
						
						OOBControl_NextState					<= ST_HOST_SEND_COMRESET;
					END IF;
			
				WHEN ST_HOST_SEND_COMRESET =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
				
					IF (OOB_TX_Complete = '1') THEN
						OOBControl_NextState					<= ST_HOST_WAIT_DEV_COMINIT;
					ELSIF ((ALLOW_STANDARD_VIOLATION = TRUE) AND (OOB_RX_Status = SATA_OOB_COMRESET)) THEN					-- allow premature OOB response
						OOBControl_NextState					<= ST_HOST_WAIT_AFTER_DEV_COMINIT;
					END IF;
					
				WHEN ST_HOST_WAIT_DEV_COMINIT =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
				
					IF (OOB_RX_Status = SATA_OOB_COMRESET) THEN																										-- device cominit detected
						TC2_Load											<= '1';
						TC2_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
						
						OOBControl_NextState					<= ST_HOST_WAIT_AFTER_DEV_COMINIT;
					END IF;
		
				WHEN ST_HOST_WAIT_AFTER_DEV_COMINIT =>
					TC2_en													<= '1';

					IF (OOB_RX_Status = SATA_OOB_COMRESET) THEN
						TC2_Load											<= '1';
						TC2_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
					ELSIF (TC2_Timeout = '1') THEN
						OOB_TX_Command								<= SATA_OOB_COMWAKE;
						
						OOBControl_NextState					<= ST_HOST_SEND_COMWAKE;
					END IF;
			
				WHEN ST_HOST_SEND_COMWAKE =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
				
					IF (OOB_TX_Complete = '1') THEN
						OOBControl_NextState					<= ST_HOST_WAIT_DEV_COMWAKE;
					ELSIF ((ALLOW_STANDARD_VIOLATION = TRUE) AND (OOB_RX_Status = SATA_OOB_COMWAKE)) THEN						-- allow premature OOB response
						OOBControl_NextState					<= ST_HOST_WAIT_AFTER_COMWAKE;
					END IF;
				
				WHEN ST_HOST_WAIT_DEV_COMWAKE =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
				
					IF (OOB_RX_Status = SATA_OOB_COMWAKE) THEN																											-- device comwake detected
						TC2_Load											<= '1';
						TC2_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 2,
																						 ite((SATA_Generation = SATA_GENERATION_2), 3, 2));
					
						OOBControl_NextState					<= ST_HOST_WAIT_AFTER_COMWAKE;
					ELSIF ((ALLOW_STANDARD_VIOLATION = TRUE) AND (OOB_RX_Status = SATA_OOB_COMRESET)) THEN					-- device COMINIT detected, but COMWAKE expected
						OOB_TX_Command								<= SATA_OOB_COMWAKE;
						
						OOBControl_NextState					<= ST_HOST_SEND_COMWAKE;
					END IF;
				
				WHEN ST_HOST_WAIT_AFTER_COMWAKE =>
					TX_Primitive										<= SATA_PRIMITIVE_DIAL_TONE;
					TC2_en													<= '1';

					IF (OOB_RX_Status = SATA_OOB_COMWAKE) THEN
						TC2_Load											<= '1';
						TC2_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 2,
																						 ite((SATA_Generation = SATA_GENERATION_2), 3, 2));
					ELSIF (TC2_Timeout = '1') THEN
						OOBControl_NextState					<= ST_HOST_WAIT_DEV_NORMAL_MODE;
					END IF;
				
				WHEN ST_HOST_WAIT_DEV_NORMAL_MODE =>
					TX_Primitive										<= SATA_PRIMITIVE_DIAL_TONE;
				
					IF (OOB_RX_Status = SATA_OOB_NONE) THEN
						OOB_HandshakingComplete				<= '1';
						
						OOBControl_NextState					<= ST_HOST_SEND_D10_2;
					END IF;
				
				WHEN ST_HOST_SEND_D10_2 =>
					TX_Primitive										<= SATA_PRIMITIVE_DIAL_TONE;
					
					-- TODO
					-- 		wait for 53,3 ns (64 UIs ~= 2 Gen1-DWords) before accepting ALIGN (<= crosstalking)
					--		source: ATA8-AST page 75, transition HP8:HP9, => note text
					
					IF ((ALLOW_STANDARD_VIOLATION = FALSE) AND (OOB_RX_Status /= SATA_OOB_NONE)) THEN							-- disallow OOB signals after "OOB_HandshakingComplete"
						OOBControl_NextState					<= ST_HOST_LINK_DEAD;
					ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) AND (RX_IsAligned = '1')) THEN										-- ALIGN detected
						OOBControl_NextState					<= ST_HOST_SEND_ALIGN;
					END IF;
				
				WHEN ST_HOST_SEND_ALIGN =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
				
					IF (OOB_RX_Status /= SATA_OOB_NONE) THEN
						OOBControl_NextState					<= ST_HOST_LINK_DEAD;
					ELSIF (RX_IsAligned = '0') THEN
						OOBControl_NextState					<= ST_HOST_LINK_BROKEN;
					ELSIF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN																				-- SYNC detected
						OOBControl_NextState					<= ST_HOST_LINK_OK;
					END IF;
					
				WHEN ST_HOST_LINK_OK =>
					TX_Primitive										<= SATA_PRIMITIVE_NONE;
					TC1_en													<= '0';
					
					OOB_LinkOK											<= '1';
					
					IF (OOB_RX_Status /= SATA_OOB_NONE) THEN
						OOB_LinkDead									<= '1';
						
						OOBControl_NextState					<= ST_HOST_LINK_DEAD;
					ELSIF (RX_IsAligned = '0') THEN
						OOB_LinkOK										<= '0';
					
						OOBControl_NextState					<= ST_HOST_LINK_BROKEN;
					END IF;
				
				WHEN ST_HOST_LINK_BROKEN =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
					TC1_en													<= '0';
					
					IF (RX_IsAligned = '1') THEN
						OOB_LinkOK										<= '1';
					
						OOBControl_NextState					<= ST_HOST_LINK_OK;
					END IF;
					
					IF (OOB_Retry = '1') THEN
						OOBControl_NextState					<= ST_HOST_RESET;
					END IF;
				
				WHEN ST_HOST_LINK_DEAD =>
					OOB_LinkDead										<= '1';
					TC1_en													<= '0';
					
					IF (OOB_Retry = '1') THEN
						OOBControl_NextState					<= ST_HOST_RESET;
					END IF;
				
				WHEN ST_HOST_TIMEOUT =>
					TC1_en													<= '0';
				
					IF (OOB_Retry = '1') THEN
						OOBControl_NextState					<= ST_HOST_RESET;
					END IF;

			END CASE;
		END IF;
	END PROCESS;
	
	-- overall timeout counter
	TC1 : ENTITY sata_L_IO.TimingCounter
		GENERIC MAP (							-- timing table
			TIMING_TABLE				=> T_NATVEC'(				--		 880 us
															0 => TimingToCycles_ns(OOB_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN1_FREQ_MHZ)),					-- slot 0
															1 => TimingToCycles_ns(OOB_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN2_FREQ_MHZ)))					-- slot 1
		)
		PORT MAP (
			Clock								=> Clock,
			Enable							=> TC1_en,
			Load								=> TC1_load,
			Slot								=> TC1_Slot,
			Timeout							=> TC1_Timeout
		);
	
	-- timeout counter for *_WAIT_AFTER_* states
	TC2 : ENTITY sata_L_IO.TimingCounter
		GENERIC MAP (							-- timing table
			TIMING_TABLE				=> T_NATVEC'(				--			ns
															0 => TimingToCycles_ns(COMRESET_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN1_FREQ_MHZ)),			-- slot 0
															1 => TimingToCycles_ns(COMRESET_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN2_FREQ_MHZ)),			-- slot 1
															2 => TimingToCycles_ns(COMWAKE_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN1_FREQ_MHZ)),			-- slot 2
															3 => TimingToCycles_ns(COMWAKE_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN2_FREQ_MHZ)))			-- slot 3
		)
		PORT MAP (
			Clock								=> Clock,
			Enable							=> TC2_en,
			Load								=> TC2_load,
			Slot								=> TC2_Slot,
			Timeout							=> TC2_Timeout
		);
	
	-- ================================================================
	-- ChipScope
	-- ================================================================
	genCSP : IF (DEBUG = TRUE) GENERATE
		SIGNAL CSP_State_D10_2													: STD_LOGIC;
		SIGNAL CSP_State_D10_2_d												: STD_LOGIC;											-- D-FF is required to KEEP the signal
		
		ATTRIBUTE KEEP OF CSP_State_D10_2								: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_State_D10_2_d							: SIGNAL IS TRUE;									-- D-FF is required to KEEP the signal
	BEGIN
		CSP_State_D10_2								<= to_sl(OOBControl_State = ST_HOST_SEND_D10_2);
		CSP_State_D10_2_d							<= CSP_State_D10_2 WHEN rising_edge(Clock);					-- D-FF is required to KEEP the signal
	END GENERATE;
END;
