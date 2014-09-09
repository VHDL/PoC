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
USE			PoC.io.ALL;
USE			PoC.sata.ALL;
USE			PoC.satadbg.ALL;


ENTITY sata_Physical_OOBControl_Device IS
	GENERIC (
		DEBUG											: BOOLEAN														:= FALSE;												-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: BOOLEAN														:= FALSE;												-- enables the assignment of signals to the debugport
		CLOCK_FREQ_MHZ						: REAL															:= 150.0;												-- 
		ALLOW_STANDARD_VIOLATION	: BOOLEAN														:= FALSE;
		OOB_TIMEOUT_US						: INTEGER														:= 0
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		ClockEnable								: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		-- debug ports
		DebugPortOut							: OUT	T_SATADBG_PHYSICAL_OOBCONTROL_OUT;

		Retry											: IN	STD_LOGIC;
		Timeout										: OUT	STD_LOGIC;
		SATAGeneration						: IN	T_SATA_GENERATION;
		LinkOK										: OUT	STD_LOGIC;
		LinkDead									: OUT	STD_LOGIC;
		ReceivedReset							: OUT	STD_LOGIC;
		
		OOB_TX_Command						: OUT	T_SATA_OOB;
		OOB_TX_Complete						: IN	STD_LOGIC;
		OOB_RX_Received						: IN	T_SATA_OOB;
		OOB_HandshakeComplete			:	OUT	STD_LOGIC;
		
		TX_Primitive							: OUT	T_SATA_PRIMITIVE;
		RX_Primitive							: IN	T_SATA_PRIMITIVE;
		RX_IsAligned							: IN	STD_LOGIC
	);
END;


ARCHITECTURE rtl OF sata_Physical_OOBControl_Device IS
	ATTRIBUTE KEEP												: BOOLEAN;
	ATTRIBUTE FSM_ENCODING								: STRING;

	CONSTANT CLOCK_GEN1_FREQ_MHZ					: REAL				:= CLOCK_FREQ_MHZ / 4.0;			-- SATAClock frequency in MHz for SATA generation 1
	CONSTANT CLOCK_GEN2_FREQ_MHZ					: REAL				:= CLOCK_FREQ_MHZ / 2.0;			-- SATAClock frequency in MHz for SATA generation 2
	CONSTANT CLOCK_GEN3_FREQ_MHZ					: REAL				:= CLOCK_FREQ_MHZ / 1.0;			-- SATAClock frequency in MHz for SATA generation 3

	CONSTANT DEFAULT_OOB_TIMEOUT_US				: POSITIVE		:= 880;
	
	CONSTANT OOB_TIMEOUT_NS								: INTEGER			:= ite((OOB_TIMEOUT_US = 0), DEFAULT_OOB_TIMEOUT_US, OOB_TIMEOUT_US) * 1000;
	CONSTANT COMRESET_TIMEOUT_NS					: INTEGER			:= 450;
	CONSTANT COMWAKE_TIMEOUT_NS						: INTEGER			:= 250;

	CONSTANT TTID1_OOB_TIMEOUT_GEN1				: NATURAL			:= 0;
	CONSTANT TTID1_OOB_TIMEOUT_GEN2				: NATURAL			:= 1;
	CONSTANT TTID1_OOB_TIMEOUT_GEN3				: NATURAL			:= 2;
	CONSTANT TTID2_COMRESET_TIMEOUT_GEN1	: NATURAL			:= 0;
	CONSTANT TTID2_COMRESET_TIMEOUT_GEN2	: NATURAL			:= 1;
	CONSTANT TTID2_COMRESET_TIMEOUT_GEN3	: NATURAL			:= 2;
	CONSTANT TTID2_COMWAKE_TIMEOUT_GEN1		: NATURAL			:= 3;
	CONSTANT TTID2_COMWAKE_TIMEOUT_GEN2		: NATURAL			:= 4;
	CONSTANT TTID2_COMWAKE_TIMEOUT_GEN3		: NATURAL			:= 5;

	CONSTANT TC1_TIMING_TABLE					: T_NATVEC				:= (--		 880 us
		TTID1_OOB_TIMEOUT_GEN1 => TimingToCycles_ns(OOB_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN1_FREQ_MHZ)),							-- slot 0
		TTID1_OOB_TIMEOUT_GEN2 => TimingToCycles_ns(OOB_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN2_FREQ_MHZ)),							-- slot 1
		TTID1_OOB_TIMEOUT_GEN3 => TimingToCycles_ns(OOB_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN3_FREQ_MHZ))							-- slot 2
	);
	
	CONSTANT TC2_TIMING_TABLE					: T_NATVEC				:= (
		TTID2_COMRESET_TIMEOUT_GEN1	=> TimingToCycles_ns(COMRESET_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN1_FREQ_MHZ)),		-- slot 0
		TTID2_COMRESET_TIMEOUT_GEN2	=> TimingToCycles_ns(COMRESET_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN2_FREQ_MHZ)),		-- slot 1
		TTID2_COMRESET_TIMEOUT_GEN3	=> TimingToCycles_ns(COMRESET_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN3_FREQ_MHZ)),		-- slot 2
		TTID2_COMWAKE_TIMEOUT_GEN1	=> TimingToCycles_ns(COMWAKE_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN1_FREQ_MHZ)),		-- slot 3
		TTID2_COMWAKE_TIMEOUT_GEN2	=> TimingToCycles_ns(COMWAKE_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN2_FREQ_MHZ)),		-- slot 4
		TTID2_COMWAKE_TIMEOUT_GEN3	=> TimingToCycles_ns(COMWAKE_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN3_FREQ_MHZ))		-- slot 5
	);

	TYPE T_STATE IS (
		ST_DEV_RESET,
		ST_DEV_WAIT_HOST_COMRESET,
		ST_DEV_WAIT_AFTER_HOST_COMRESET,
		ST_DEV_SEND_COMINIT,
		ST_DEV_WAIT_HOST_COMWAKE,
		ST_DEV_WAIT_AFTER_COMWAKE,
		ST_DEV_SEND_COMWAKE,
		ST_DEV_OOB_HANDSHAKE_COMPLETE,
		ST_DEV_SEND_ALIGN,
		ST_DEV_TIMEOUT,
		ST_DEV_LINK_OK,
		ST_DEV_LINK_BROKEN,
		ST_DEV_LINK_DEAD
	);

	-- OOB-Statemachine
	SIGNAL State										: T_STATE														:= ST_DEV_RESET;
	SIGNAL NextState								: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State	: SIGNAL IS getFSMEncoding_gray(DEBUG);
	SIGNAL LinkOK_i										: STD_LOGIC;
	SIGNAL LinkDead_i									: STD_LOGIC;
	SIGNAL Timeout_i									: STD_LOGIC;
	SIGNAL ReceivedReset_i						: STD_LOGIC;

	SIGNAL OOB_TX_Command_i						: T_SATA_OOB;
	SIGNAL OOB_HandshakeComplete_i		: STD_LOGIC;

	-- Timing-Counter
	-- ===========================================================================
	-- general timeouts
	SIGNAL TC1_en										: STD_LOGIC;
	SIGNAL TC1_Load									: STD_LOGIC;
	SIGNAL TC1_Slot									: NATURAL;
	SIGNAL TC1_Timeout							: STD_LOGIC;
	
	-- OOB state specific timeouts
	SIGNAL TC2_en										: STD_LOGIC;
	SIGNAL TC2_Load									: STD_LOGIC;
	SIGNAL TC2_Slot									: NATURAL;
	SIGNAL TC2_Timeout							: STD_LOGIC;	
	
BEGIN
	ASSERT ((SATAGeneration = SATA_GENERATION_1) OR
					(SATAGeneration = SATA_GENERATION_2) OR
					(SATAGeneration = SATA_GENERATION_3))
		REPORT "Member of T_SATA_GENERATION not supported"
		SEVERITY FAILURE;

	-- OOBControl Statemachine
	-- ======================================================================================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_DEV_RESET;
			ELSIF (ClockEnable = '1') THEN
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;


	PROCESS(State, SATAGeneration, Retry, OOB_TX_Complete, OOB_RX_Received, RX_IsAligned, RX_Primitive, TC1_Timeout, TC2_Timeout)
	BEGIN
		NextState									<= State;
		
		TX_Primitive							<= SATA_PRIMITIVE_DIAL_TONE;
	
		-- general timeout
		TC1_en										<= '0';
		TC1_Load									<= '0';
		TC1_Slot									<= 0;
		
		-- OOB state specific timeouts
		TC2_en										<= '0';
		TC2_Load									<= '0';
		TC2_Slot									<= 0;
	
		LinkOK_i									<= '0';
		LinkDead_i								<= '0';
		Timeout_i									<= '0';
		ReceivedReset_i						<= '0';
		
		OOB_TX_Command_i					<= SATA_OOB_NONE;
		OOB_HandshakeComplete_i		<= '0';

		-- handle timeout with highest priority
		IF (TC1_Timeout = '1') THEN
			TC1_en											<= '0';
			TC1_Load										<= '1';
			TC1_Slot										<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																							 TTID1_OOB_TIMEOUT_GEN3)));
			NextState										<= ST_DEV_TIMEOUT;
			
		-- treat COMRESET as communication reset
		ELSIF ((OOB_RX_Received = SATA_OOB_COMRESET) AND
					 ((State /= ST_DEV_WAIT_HOST_COMRESET) OR
					  (State /= ST_DEV_WAIT_AFTER_HOST_COMRESET)))
		THEN
			ReceivedReset_i							<= '1';

			TC1_Load										<= '1';
			TC2_Load										<= '1';
			TC1_Slot										<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																								TTID1_OOB_TIMEOUT_GEN3)));
			TC2_Slot										<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMRESET_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMRESET_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMRESET_TIMEOUT_GEN3,
																																								TTID2_COMRESET_TIMEOUT_GEN3)));
			NextState										<= ST_DEV_WAIT_AFTER_HOST_COMRESET;
		ELSE
			CASE State IS
				WHEN ST_DEV_RESET =>
					IF (Retry = '1') THEN
						TC1_Load							<= '1';
						TC1_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																								TTID1_OOB_TIMEOUT_GEN3)));
						NextState							<= ST_DEV_WAIT_HOST_COMRESET;
					END IF;

				WHEN ST_DEV_WAIT_HOST_COMRESET =>
					IF (OOB_RX_Received = SATA_OOB_COMRESET) THEN																										-- host comreset detected
						TC1_Load							<= '1';
						TC2_Load							<= '1';
						TC1_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																								TTID1_OOB_TIMEOUT_GEN3)));
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMRESET_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMRESET_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMRESET_TIMEOUT_GEN3,
																																								TTID2_COMRESET_TIMEOUT_GEN3)));
						NextState							<= ST_DEV_WAIT_AFTER_HOST_COMRESET;
					END IF;
		
				WHEN ST_DEV_WAIT_AFTER_HOST_COMRESET =>
					TC1_en									<= '1';
					TC2_en									<= '1';

					IF (OOB_RX_Received = SATA_OOB_COMRESET) THEN																										-- host additional comreset detected
						TC2_Load							<= '1';
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMRESET_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMRESET_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMRESET_TIMEOUT_GEN3,
																																								TTID2_COMRESET_TIMEOUT_GEN3)));
					ELSIF (TC2_Timeout = '1') THEN
						OOB_TX_Command_i			<= SATA_OOB_COMRESET;
						
						NextState							<= ST_DEV_SEND_COMINIT;
					END IF;

				WHEN ST_DEV_SEND_COMINIT =>
					TC1_en									<= '1';
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					
					IF (OOB_TX_Complete = '1') THEN
						NextState					<= ST_DEV_WAIT_HOST_COMWAKE;
					ELSIF ((ALLOW_STANDARD_VIOLATION = TRUE) AND (OOB_RX_Received = SATA_OOB_COMWAKE)) THEN					-- allow premature OOB response
						NextState					<= ST_DEV_WAIT_AFTER_COMWAKE;
					END IF;

				WHEN ST_DEV_WAIT_HOST_COMWAKE =>
					TX_Primitive				<= SATA_PRIMITIVE_ALIGN;
					TC1_en							<= '1';
					
					IF (OOB_RX_Received = SATA_OOB_COMWAKE) THEN																											-- host comwake detected
						TC2_Load					<= '1';
						TC2_Slot					<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMWAKE_TIMEOUT_GEN1,
																 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMWAKE_TIMEOUT_GEN2,
																 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMWAKE_TIMEOUT_GEN3,
																																						TTID2_COMWAKE_TIMEOUT_GEN3)));
						NextState					<= ST_DEV_WAIT_AFTER_COMWAKE;
					END IF;
				
				WHEN ST_DEV_WAIT_AFTER_COMWAKE =>
					TC1_en							<= '1';
					TC2_en							<= '1';

					IF (OOB_RX_Received = SATA_OOB_COMWAKE) THEN																											-- additional host cominit detected
						TC2_Load					<= '1';
						TC2_Slot					<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMWAKE_TIMEOUT_GEN1,
																 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMWAKE_TIMEOUT_GEN2,
																 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMWAKE_TIMEOUT_GEN3,
																																						TTID2_COMWAKE_TIMEOUT_GEN3)));
					ELSIF (TC2_Timeout = '1') THEN
						OOB_TX_Command_i			<= SATA_OOB_COMWAKE;
						
						NextState							<= ST_DEV_SEND_COMWAKE;
					END IF;

				WHEN ST_DEV_SEND_COMWAKE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					IF (OOB_TX_Complete = '1') THEN
						NextState							<= ST_DEV_OOB_HANDSHAKE_COMPLETE;
					END IF;

				WHEN ST_DEV_OOB_HANDSHAKE_COMPLETE =>
					OOB_HandshakeComplete_i	<= '1';
					TX_Primitive						<= SATA_PRIMITIVE_ALIGN;
					NextState								<= ST_DEV_SEND_ALIGN;
					
				WHEN ST_DEV_SEND_ALIGN =>
					TX_Primitive						<= SATA_PRIMITIVE_ALIGN;
				
					IF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) AND (RX_IsAligned = '1')) THEN												-- ALIGN detected
						NextState							<= ST_DEV_LINK_OK;
					END IF;
				
				WHEN ST_DEV_LINK_OK =>
					LinkOK_i								<= '1';
					TX_Primitive						<= SATA_PRIMITIVE_NONE;
					
					IF (OOB_RX_Received /= SATA_OOB_NONE) THEN
						NextState							<= ST_DEV_LINK_DEAD;
					ELSIF (RX_IsAligned = '0') THEN
						NextState							<= ST_DEV_LINK_BROKEN;
					END IF;
				
				WHEN ST_DEV_LINK_BROKEN =>
					TX_Primitive						<= SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '0';
					
					IF (RX_IsAligned = '1') THEN
						NextState							<= ST_DEV_LINK_OK;
					END IF;
				
					IF (Retry = '1') THEN
						TC1_Load							<= '1';
						TC1_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																							 TTID1_OOB_TIMEOUT_GEN3)));
						NextState							<= ST_DEV_WAIT_HOST_COMRESET;
					END IF;
				
				WHEN ST_DEV_LINK_DEAD =>
					LinkDead_i							<= '1';
					
					IF (Retry = '1') THEN
						TC1_Load							<= '1';
						TC1_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																							 TTID1_OOB_TIMEOUT_GEN3)));
						NextState							<= ST_DEV_WAIT_HOST_COMRESET;
					END IF;
				
				WHEN ST_DEV_TIMEOUT =>
					Timeout_i								<= '1';
				
					IF (Retry = '1') THEN
						TC1_Load							<= '1';
						TC1_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																							 TTID1_OOB_TIMEOUT_GEN3)));
						NextState							<= ST_DEV_WAIT_HOST_COMRESET;
					END IF;
				
			END CASE;
		END IF;
	END PROCESS;
	
	LinkOK									<= LinkOK_i;
	LinkDead								<= LinkDead_i;
	Timeout									<= Timeout_i;
	ReceivedReset						<= ReceivedReset_i;

	OOB_TX_Command					<= OOB_TX_Command_i;
	OOB_HandshakeComplete		<= OOB_HandshakeComplete_i;
	
	-- overall timeout counter
	TC1 : ENTITY PoC.io_TimingCounter
		GENERIC MAP (							-- timing table
			TIMING_TABLE				=> TC1_TIMING_TABLE
		)
		PORT MAP (
			Clock								=> Clock,
			Enable							=> TC1_en,
			Load								=> TC1_load,
			Slot								=> TC1_Slot,
			Timeout							=> TC1_Timeout
		);
	
	-- timeout counter for *_WAIT_AFTER_* states
	TC2 : ENTITY PoC.io_TimingCounter
		GENERIC MAP (							-- timing table
			TIMING_TABLE				=> TC2_TIMING_TABLE
		)
		PORT MAP (
			Clock								=> Clock,
			Enable							=> TC2_en,
			Load								=> TC2_load,
			Slot								=> TC2_Slot,
			Timeout							=> TC2_Timeout
		);
	
	-- debug port
	-- ===========================================================================
	genDebugPort : IF (ENABLE_DEBUGPORT = TRUE) GENERATE
	
		FUNCTION dbg_EncodeState(State : T_STATE) RETURN STD_LOGIC_VECTOR IS
			CONSTANT ResultSize		: POSITIVE																	:= log2ceilnz(T_STATE'pos(T_STATE'high));
			CONSTANT Result				: STD_LOGIC_VECTOR(ResultSize - 1 DOWNTO 0)	:= to_slv(T_STATE'pos(State), ResultSize);
		BEGIN
			RETURN ite(DEBUG, bin2gray(Result), Result);
		END FUNCTION;
		
	BEGIN
		DebugPortOut.FSM												<= dbg_EncodeState(State);
		DebugPortOut.Retry											<= Retry;
		DebugPortOut.Timeout										<= Timeout_i;
		DebugPortOut.LinkOK											<= LinkOK_i;
		DebugPortOut.LinkDead										<= LinkDead_i;
		DebugPortOut.ReceivedReset							<= ReceivedReset_i;
		
		DebugPortOut.OOB_TX_Command							<= OOB_TX_Command_i;
		DebugPortOut.OOB_TX_Complete						<= OOB_TX_Complete;
		DebugPortOut.OOB_RX_Received						<= OOB_RX_Received;
		DebugPortOut.OOB_HandshakeComplete			<= OOB_HandshakeComplete_i;		
	END GENERATE;
END;
