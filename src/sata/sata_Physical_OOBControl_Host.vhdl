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
USE			PoC.my_project.ALL;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
USE			PoC.physical.ALL;
USE			PoC.debug.ALL;
USE			PoC.sata.ALL;
USE			PoC.satadbg.ALL;


ENTITY sata_Physical_OOBControl_Host IS
	GENERIC (
		DEBUG											: BOOLEAN														:= FALSE;												-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: BOOLEAN														:= FALSE;												-- enables the assignment of signals to the debugport
		CLOCK_FREQ								: FREQ															:= 150.0 MHz;										-- 
		ALLOW_STANDARD_VIOLATION	: BOOLEAN														:= FALSE;
		OOB_TIMEOUT								: TIME															:= TIME'low
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


ARCHITECTURE rtl OF sata_Physical_OOBControl_Host IS
	ATTRIBUTE KEEP												: BOOLEAN;
	ATTRIBUTE FSM_ENCODING								: STRING;

	CONSTANT CLOCK_GEN1_FREQ							: FREQ				:= CLOCK_FREQ / 4.0;			-- SATAClock frequency in MHz for SATA generation 1
	CONSTANT CLOCK_GEN2_FREQ							: FREQ				:= CLOCK_FREQ / 2.0;			-- SATAClock frequency in MHz for SATA generation 2
	CONSTANT CLOCK_GEN3_FREQ							: FREQ				:= CLOCK_FREQ / 1.0;			-- SATAClock frequency in MHz for SATA generation 3

	CONSTANT DEFAULT_OOB_TIMEOUT					: TIME				:= 880.0 us;
	
	CONSTANT OOB_TIMEOUT_I								: TIME				:= ite((OOB_TIMEOUT = TIME'low), DEFAULT_OOB_TIMEOUT, OOB_TIMEOUT);
	CONSTANT COMRESET_TIMEOUT							: TIME				:= 450.0 ns;
	CONSTANT COMWAKE_TIMEOUT							: TIME				:= 250.0 ns;

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
		TTID1_OOB_TIMEOUT_GEN1 => TimingToCycles(OOB_TIMEOUT_I,	CLOCK_GEN1_FREQ),							-- slot 0
		TTID1_OOB_TIMEOUT_GEN2 => TimingToCycles(OOB_TIMEOUT_I,	CLOCK_GEN2_FREQ),							-- slot 1
		TTID1_OOB_TIMEOUT_GEN3 => TimingToCycles(OOB_TIMEOUT_I,	CLOCK_GEN3_FREQ)							-- slot 2
	);
	
	CONSTANT TC2_TIMING_TABLE					: T_NATVEC				:= (
		TTID2_COMRESET_TIMEOUT_GEN1	=> TimingToCycles(COMRESET_TIMEOUT,	CLOCK_GEN1_FREQ),		-- slot 0
		TTID2_COMRESET_TIMEOUT_GEN2	=> TimingToCycles(COMRESET_TIMEOUT,	CLOCK_GEN2_FREQ),		-- slot 1
		TTID2_COMRESET_TIMEOUT_GEN3	=> TimingToCycles(COMRESET_TIMEOUT,	CLOCK_GEN3_FREQ),		-- slot 2
		TTID2_COMWAKE_TIMEOUT_GEN1	=> TimingToCycles(COMWAKE_TIMEOUT,	CLOCK_GEN1_FREQ),		-- slot 3
		TTID2_COMWAKE_TIMEOUT_GEN2	=> TimingToCycles(COMWAKE_TIMEOUT,	CLOCK_GEN2_FREQ),		-- slot 4
		TTID2_COMWAKE_TIMEOUT_GEN3	=> TimingToCycles(COMWAKE_TIMEOUT,	CLOCK_GEN3_FREQ)		-- slot 5
	);

	TYPE T_STATE IS (
		ST_HOST_RESET,
		ST_HOST_SEND_COMRESET,
		ST_HOST_SEND_COMRESET_WAIT,
		ST_HOST_WAIT_DEV_COMINIT,
		ST_HOST_WAIT_AFTER_DEV_COMINIT,
		ST_HOST_SEND_COMWAKE,
		ST_HOST_SEND_COMWAKE_WAIT,
		ST_HOST_WAIT_DEV_COMWAKE,
		ST_HOST_WAIT_AFTER_COMWAKE,
		ST_HOST_WAIT_DEV_NORMAL_MODE,
		ST_HOST_OOB_HANDSHAKE_COMPLETE,
		ST_HOST_SEND_D10_2,
		ST_HOST_SEND_ALIGN,
		ST_HOST_TIMEOUT,
		ST_HOST_LINK_OK,
		ST_HOST_LINK_BROKEN,
		ST_HOST_LINK_DEAD
	);

	-- OOB-Statemachine
	SIGNAL State											: T_STATE													:= ST_HOST_RESET;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS getFSMEncoding_gray(DEBUG);

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
				State			<= ST_HOST_RESET;
			ELSIF (ClockEnable = '1') THEN
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;


	PROCESS(State, SATAGeneration, Retry, OOB_TX_Complete, OOB_RX_Received, RX_IsAligned, RX_Primitive, TC1_Timeout, TC2_Timeout)
	BEGIN
		NextState									<= State;
		
		TX_Primitive							<= SATA_PRIMITIVE_ALIGN;
	
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
		OOB_HandshakeComplete_i	<= '0';

		-- handle timeout with highest priority
		IF (TC1_Timeout = '1') THEN
			TC1_en											<= '0';
			TC1_Load										<= '1';
			TC1_Slot										<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																							 TTID1_OOB_TIMEOUT_GEN3)));
			NextState										<= ST_HOST_TIMEOUT;
		ELSE
			CASE State IS
				WHEN ST_HOST_RESET =>
					IF (Retry = '1') THEN
						NextState							<= ST_HOST_SEND_COMRESET;
					END IF;
			
				WHEN ST_HOST_SEND_COMRESET =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					OOB_TX_Command_i				<= SATA_OOB_COMRESET;
					TC1_en									<= '1';
						
					TC1_Load								<= '1';
					TC1_Slot								<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																							 TTID1_OOB_TIMEOUT_GEN3)));
					NextState								<= ST_HOST_SEND_COMRESET_WAIT;
			
				WHEN ST_HOST_SEND_COMRESET_WAIT =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					IF (OOB_TX_Complete = '1') THEN
						NextState							<= ST_HOST_WAIT_DEV_COMINIT;
					ELSIF ((ALLOW_STANDARD_VIOLATION = TRUE) AND (OOB_RX_Received = SATA_OOB_COMRESET)) THEN					-- allow premature OOB response
						NextState							<= ST_HOST_WAIT_AFTER_DEV_COMINIT;
					END IF;
					
				WHEN ST_HOST_WAIT_DEV_COMINIT =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					IF (OOB_RX_Received = SATA_OOB_COMRESET) THEN																										-- device cominit detected
						TC2_Load							<= '1';
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMRESET_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMRESET_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMRESET_TIMEOUT_GEN3,
																																							 TTID2_COMRESET_TIMEOUT_GEN3)));
						
						NextState							<= ST_HOST_WAIT_AFTER_DEV_COMINIT;
					END IF;
		
				WHEN ST_HOST_WAIT_AFTER_DEV_COMINIT =>
					TC2_en									<= '1';
					TC1_en									<= '1';

					IF (OOB_RX_Received = SATA_OOB_COMRESET) THEN
						TC2_Load							<= '1';
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMRESET_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMRESET_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMRESET_TIMEOUT_GEN3,
																																							 TTID2_COMRESET_TIMEOUT_GEN3)));
					ELSIF (TC2_Timeout = '1') THEN
						NextState							<= ST_HOST_SEND_COMWAKE;
					END IF;

				WHEN ST_HOST_SEND_COMWAKE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					OOB_TX_Command_i				<= SATA_OOB_COMWAKE;
					TC1_en									<= '1';
					NextState								<= ST_HOST_SEND_COMWAKE_WAIT;
			
				WHEN ST_HOST_SEND_COMWAKE_WAIT =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					IF (OOB_TX_Complete = '1') THEN
						NextState							<= ST_HOST_WAIT_DEV_COMWAKE;
					ELSIF ((ALLOW_STANDARD_VIOLATION = TRUE) AND (OOB_RX_Received = SATA_OOB_COMWAKE)) THEN						-- allow premature OOB response
						NextState							<= ST_HOST_WAIT_AFTER_COMWAKE;
					END IF;
				
				WHEN ST_HOST_WAIT_DEV_COMWAKE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					IF (OOB_RX_Received = SATA_OOB_COMWAKE) THEN																											-- device comwake detected
						TC2_Load							<= '1';
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMWAKE_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMWAKE_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMWAKE_TIMEOUT_GEN3,
																																							 TTID2_COMWAKE_TIMEOUT_GEN3)));
					
						NextState							<= ST_HOST_WAIT_AFTER_COMWAKE;
					ELSIF ((ALLOW_STANDARD_VIOLATION = TRUE) AND (OOB_RX_Received = SATA_OOB_COMRESET)) THEN					-- device COMINIT detected, but COMWAKE expected
						NextState							<= ST_HOST_SEND_COMWAKE;
					END IF;
				
				WHEN ST_HOST_WAIT_AFTER_COMWAKE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;
					TC1_en									<= '1';
					TC2_en									<= '1';

					IF (OOB_RX_Received = SATA_OOB_COMWAKE) THEN
						TC2_Load							<= '1';
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMWAKE_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMWAKE_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMWAKE_TIMEOUT_GEN3,
																																							 TTID2_COMWAKE_TIMEOUT_GEN3)));
					ELSIF (TC2_Timeout = '1') THEN
						NextState							<= ST_HOST_WAIT_DEV_NORMAL_MODE;
					END IF;
				
				WHEN ST_HOST_WAIT_DEV_NORMAL_MODE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;
					TC1_en									<= '1';
				
					IF (OOB_RX_Received = SATA_OOB_NONE) THEN
						NextState							<= ST_HOST_OOB_HANDSHAKE_COMPLETE;
					END IF;
				
				WHEN ST_HOST_OOB_HANDSHAKE_COMPLETE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;
					OOB_HandshakeComplete_i	<= '1';
					TC1_en									<= '1';
						
					NextState								<= ST_HOST_SEND_D10_2;
				
				WHEN ST_HOST_SEND_D10_2 =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;
					TC1_en									<= '1';
					
					-- TODO
					-- 		wait for 53,3 ns (64 UIs ~= 2 Gen1-DWords) before accepting ALIGN (<= crosstalking)
					--		source: ATA8-AST page 75, transition HP8:HP9, => note text
					
					IF ((ALLOW_STANDARD_VIOLATION = FALSE) AND (OOB_RX_Received /= SATA_OOB_NONE)) THEN						-- disallow OOB signals after "OOB_HandshakeComplete"
						NextState							<= ST_HOST_LINK_DEAD;
					ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) AND (RX_IsAligned = '1')) THEN										-- ALIGN detected
						NextState							<= ST_HOST_SEND_ALIGN;
					END IF;
				
				WHEN ST_HOST_SEND_ALIGN =>
					TX_Primitive						<= SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					IF (OOB_RX_Received /= SATA_OOB_NONE) THEN
						NextState							<= ST_HOST_LINK_DEAD;
					ELSIF (RX_IsAligned = '0') THEN
						NextState							<= ST_HOST_LINK_BROKEN;
					ELSIF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN																				-- SYNC detected
						NextState							<= ST_HOST_LINK_OK;
					END IF;
					
				WHEN ST_HOST_LINK_OK =>
					LinkOK_i								<= '1';
					TX_Primitive						<= SATA_PRIMITIVE_NONE;
					
					IF (OOB_RX_Received /= SATA_OOB_NONE) THEN
						NextState							<= ST_HOST_LINK_DEAD;
					ELSIF (RX_IsAligned = '0') THEN
						NextState							<= ST_HOST_LINK_BROKEN;
					END IF;
				
				WHEN ST_HOST_LINK_BROKEN =>
					TX_Primitive						<= SATA_PRIMITIVE_ALIGN;
					
					IF (RX_IsAligned = '1') THEN
						NextState							<= ST_HOST_LINK_OK;
					END IF;
					
					IF (Retry = '1') THEN
						NextState							<= ST_HOST_SEND_COMRESET;
					END IF;
				
				WHEN ST_HOST_LINK_DEAD =>
					LinkDead_i							<= '1';
					
					IF (Retry = '1') THEN
						NextState							<= ST_HOST_SEND_COMRESET;
					END IF;
				
				WHEN ST_HOST_TIMEOUT =>
					Timeout_i								<= '1';
				
					IF (Retry = '1') THEN
						NextState							<= ST_HOST_SEND_COMRESET;
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
		function dbg_EncodeState(st : T_STATE) return STD_LOGIC_VECTOR is
		begin
			return to_slv(T_STATE'pos(st), log2ceilnz(T_STATE'pos(T_STATE'high) + 1));
		end function;
		
		function dbg_GenerateEncodingList return T_DBG_ENCODING_VECTOR is
			variable i					: NATURAL		:= 0;
			variable result			: T_DBG_ENCODING_VECTOR(0 to T_STATE'pos(T_STATE'high));
		begin
			for st in T_STATE loop
				result(i).Name		:= resize(T_STATE'image(st), T_DBG_ENCODING.Name'length);
				result(i).Binary	:= to_slv(T_STATE'pos(st),	 T_DBG_ENCODING.Binary'length);
				i	:= i + 1;
			end loop;
			return result;
		end function;

		CONSTANT DBG_ENCODING_REPLACEMENTS		: T_DBG_ENCODING_REPLACEMENTS		:= C_DBG_DEFAULT_ENCODING_REPLACEMENTS & T_DBG_ENCODING_REPLACEMENTS'(
			0 => (Pattern => resize("host_", C_DBG_STRING_LENGTH),			Replacement => resize("", C_DBG_STRING_LENGTH)),
			1 => (Pattern => resize("handshake", C_DBG_STRING_LENGTH),	Replacement => resize("hs", C_DBG_STRING_LENGTH))
		);
		
		CONSTANT test : boolean := dbg_ExportEncoding("OOBControl (Host)", dbg_GenerateEncodingList, MY_PROJECT_DIR & "ChipScope/TokenFiles/FSM_OOBControl_Host.tok", DBG_ENCODING_REPLACEMENTS);
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
