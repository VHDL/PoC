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


ENTITY sata_PhysicalLayer IS
	GENERIC (
		DEBUG														: BOOLEAN													:= FALSE;
		ENABLE_DEBUGPORT								: BOOLEAN													:= FALSE;
		CLOCK_FREQ											: FREQ														:= 150.0 MHz;
		CONTROLLER_TYPE									: T_SATA_DEVICE_TYPE							:= SATA_DEVICE_TYPE_HOST;
		ALLOW_SPEED_NEGOTIATION					: BOOLEAN													:= TRUE;
		INITIAL_SATA_GENERATION					: T_SATA_GENERATION								:= C_SATA_GENERATION_MAX;
		ALLOW_AUTO_RECONNECT						: BOOLEAN													:= TRUE;
		ALLOW_STANDARD_VIOLATION				: BOOLEAN													:= FALSE;
		OOB_TIMEOUT											: TIME														:= TIME'low;
		GENERATION_CHANGE_COUNT					: INTEGER													:= 8;
		ATTEMPTS_PER_GENERATION					: INTEGER													:= 4
	);
	PORT (
		Clock														: IN	STD_LOGIC;
		ClockEnable											: IN	STD_LOGIC;
		Reset														: IN	STD_LOGIC;										-- general logic reset without some counter resets while Clock is unstable
																																				--   => preserve SATAGeneration between connection-cycles
		SATAGenerationMin								: IN	T_SATA_GENERATION;						-- 
		SATAGenerationMax								: IN	T_SATA_GENERATION;						-- 

		-- PhysicalLayer interface
		Command													: IN	T_SATA_PHY_COMMAND;
		Status													: OUT	T_SATA_PHY_STATUS;
		Error														: OUT	T_SATA_PHY_ERROR;

		DebugPortOut										: OUT	T_SATADBG_PHYSICAL_OUT;

		Link_RX_Data										: OUT	T_SLV_32;
		Link_RX_CharIsK									: OUT	T_SLV_4;
		
		Link_TX_Data										: IN	T_SLV_32;
		Link_TX_CharIsK									: IN	T_SLV_4;

		-- TransceiverLayer interface
		Trans_ResetDone									: IN	STD_LOGIC;
		
		Trans_Command										: OUT	T_SATA_TRANSCEIVER_COMMAND;
		Trans_Status										: IN	T_SATA_TRANSCEIVER_STATUS;
		Trans_TX_Error									: IN	T_SATA_TRANSCEIVER_TX_ERROR;
		Trans_RX_Error									: IN	T_SATA_TRANSCEIVER_RX_ERROR;

		Trans_RP_Reconfig								: OUT	STD_LOGIC;
		Trans_RP_SATAGeneration					: OUT	T_SATA_GENERATION;
		Trans_RP_ReconfigComplete				: IN	STD_LOGIC;
		Trans_RP_ConfigReloaded					: IN	STD_LOGIC;
		Trans_RP_Lock										: OUT	STD_LOGIC;
		Trans_RP_Locked									: IN	STD_LOGIC;

		Trans_OOB_TX_Command						: OUT	T_SATA_OOB;
		Trans_OOB_TX_Complete						: IN	STD_LOGIC;
		Trans_OOB_RX_Received						: IN	T_SATA_OOB;
		Trans_OOB_HandshakeComplete			: OUT	STD_LOGIC;		

		Trans_TX_Data										: OUT	T_SLV_32;
		Trans_TX_CharIsK								: OUT T_SLV_4;

		Trans_RX_Data										: IN	T_SLV_32;
		Trans_RX_CharIsK								: IN	T_SLV_4;
		Trans_RX_IsAligned							: IN	STD_LOGIC
	);
END;


ARCHITECTURE rtl OF sata_PhysicalLayer IS
	ATTRIBUTE KEEP						: BOOLEAN;
	ATTRIBUTE FSM_ENCODING		: STRING;
	
	TYPE T_STATE IS (
		ST_RESET,
		ST_LINK_UP,
		ST_CHANGE_SPEED,
		ST_LINK_OK,
		ST_LINK_BROKEN,
		ST_ERROR
	);
	
	SIGNAL State											: T_STATE													:= ST_RESET;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS getFSMEncoding_gray(DEBUG);

	SIGNAL Status_i										: T_SATA_PHY_STATUS;

	SIGNAL FSM_SC_Reset								: STD_LOGIC;
	SIGNAL FSM_SC_Command							: T_SATA_PHY_SPEED_COMMAND;
	
	SIGNAL SC_Status									: T_SATA_PHY_SPEED_STATUS;	
	SIGNAL SC_Retry										: STD_LOGIC;
	SIGNAL SC_SATAGeneration					: T_SATA_GENERATION;
		
	SIGNAL OOBC_Reset									: STD_LOGIC;
	SIGNAL OOBC_LinkOK								: STD_LOGIC;
	SIGNAL OOBC_LinkDead							: STD_LOGIC;
	SIGNAL OOBC_Timeout								: STD_LOGIC;
	SIGNAL OOBC_Timeout_d							: STD_LOGIC;
	SIGNAL OOBC_Timeout_re						: STD_LOGIC;
	SIGNAL OOBC_ReceivedReset					: STD_LOGIC;

	SIGNAL ResetGeneration						: STD_LOGIC;
	SIGNAL ResetTrysPerGeneration_i		: STD_LOGIC;
	SIGNAL Trans_RP_Reconfig_i				: STD_LOGIC;

	SIGNAL OOBC_TX_Primitive					: T_SATA_PRIMITIVE;
	SIGNAL RX_Primitive								: T_SATA_PRIMITIVE;
	SIGNAL Trans_TX_Data_i						: T_SLV_32;
	SIGNAL Trans_TX_CharIsK_i					: T_SLV_4;
	
	SIGNAL OOBC_DebugPortOut					: T_SATADBG_PHYSICAL_OOBCONTROL_OUT;
	SIGNAL SC_DebugPortOut						: T_SATADBG_PHYSICAL_SPEEDCONTROL_OUT;
	
	SIGNAL Error_rst									: STD_LOGIC;
	SIGNAL Error_en										: STD_LOGIC;
	SIGNAL Error_nxt									: T_SATA_PHY_ERROR;
	
BEGIN

	ASSERT FALSE REPORT "Physical Layer"																															SEVERITY NOTE;
	ASSERT FALSE REPORT "  ControllerType:         " & T_SATA_DEVICE_TYPE'image(CONTROLLER_TYPE)			SEVERITY NOTE;
	ASSERT FALSE REPORT "  AllowSpeedNegotiation:  " & to_string(ALLOW_SPEED_NEGOTIATION)							SEVERITY NOTE;
	ASSERT FALSE REPORT "  AllowAutoReconnect:     " & to_string(ALLOW_AUTO_RECONNECT)								SEVERITY NOTE;
	ASSERT FALSE REPORT "  AllowStandardViolation: " & to_string(ALLOW_STANDARD_VIOLATION)						SEVERITY NOTE;
	ASSERT FALSE REPORT "  Init. SATA Generation:  Gen" & INTEGER'image(INITIAL_SATA_GENERATION + 1)	SEVERITY NOTE;

	-- ================================================================
	-- physical layer control
	-- ================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_RESET;
			ELSIF (ClockEnable = '1') THEN
				State			<= NextState;
			END IF;
			
			IF (Error_rst = '1') THEN
				Error			<= SATA_PHY_ERROR_NONE;
			ELSIF (Error_en = '1') THEN
				Error			<= Error_nxt;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(State, Command, SC_Status,
					Trans_ResetDone, Trans_RP_Reconfig_i, Trans_RP_ConfigReloaded,
					OOBC_LinkOK, OOBC_LinkDead, OOBC_ReceivedReset)
	BEGIN
		NextState								<= State;
		
		Status_i								<= SATA_PHY_STATUS_ERROR;
		Error_rst								<= '0';
		Error_en								<= '0';
		Error_nxt								<= SATA_PHY_ERROR_NONE;
		
		Trans_Command						<= SATA_TRANSCEIVER_CMD_NONE;
		
		FSM_SC_Reset						<= '0';
		FSM_SC_Command					<= SATA_PHY_SPEED_CMD_NONE;
		OOBC_Reset							<= '0';
		
		CASE State IS
			WHEN ST_RESET =>
				Status_i						<= SATA_PHY_STATUS_RESET;
				NextState						<= ST_LINK_UP;
	
			WHEN ST_LINK_UP =>
				Status_i						<= SATA_PHY_STATUS_LINK_UP;
			
				IF (Command = SATA_PHY_CMD_RESET) THEN
					OOBC_Reset				<= '1';
--					FSM_SC_Reset			<= '1';
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_RESET;
					NextState					<= ST_LINK_UP;
				ELSIF (Command = SATA_PHY_CMD_NEWLINK_UP) THEN
					OOBC_Reset				<= '1';
--					FSM_SC_Reset			<= '1';
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_NEWLINK_UP;
					NextState					<= ST_LINK_UP;
				ELSIF (Trans_RP_Reconfig_i = '1') THEN
					NextState					<= ST_CHANGE_SPEED;
				ELSIF (OOBC_LinkOK = '1') THEN
					NextState					<= ST_LINK_OK;
				ELSIF (SC_Status = SATA_PHY_SPEED_STATUS_NEGOTIATION_ERROR) THEN
					Error_nxt					<= SATA_PHY_ERROR_NEGOTIATION_ERROR;
					Error_en					<= '1';
					NextState					<= ST_ERROR;
				END IF;
				
			WHEN ST_LINK_OK =>
				Status_i						<= SATA_PHY_STATUS_LINK_OK;
			
				IF (Command = SATA_PHY_CMD_RESET) THEN
					OOBC_Reset				<= '1';
--					FSM_SC_Reset			<= '1';
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_RESET;
					NextState					<= ST_LINK_UP;
				ELSIF (Command = SATA_PHY_CMD_NEWLINK_UP) THEN
					OOBC_Reset				<= '1';
--					FSM_SC_Reset			<= '1';
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_NEWLINK_UP;
					NextState					<= ST_LINK_UP;
				ELSIF (OOBC_LinkOK = '0') THEN
					NextState					<= ST_LINK_BROKEN;
				ELSIF (OOBC_LinkDead = '1') THEN
					Error_nxt					<= SATA_PHY_ERROR_LINK_DEAD;
					Error_en					<= '1';
					NextState					<= ST_ERROR;
				ELSIF (OOBC_ReceivedReset = '1') THEN
					NextState					<= ST_LINK_UP;
				END IF;
			
			WHEN ST_LINK_BROKEN =>
				Status_i						<= SATA_PHY_STATUS_LINK_BROKEN;
			
				IF (Command = SATA_PHY_CMD_RESET) THEN
					OOBC_Reset				<= '1';
--					FSM_SC_Reset			<= '1';
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_RESET;
					NextState					<= ST_LINK_UP;
				ELSIF (Command = SATA_PHY_CMD_NEWLINK_UP) THEN
					OOBC_Reset				<= '1';
--					FSM_SC_Reset			<= '1';
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_NEWLINK_UP;
					NextState					<= ST_LINK_UP;
				ELSIF (OOBC_LinkOK = '1') THEN
					NextState					<= ST_LINK_OK;
				ELSIF (OOBC_LinkDead = '1') THEN
					Error_nxt					<= SATA_PHY_ERROR_LINK_DEAD;
					Error_en					<= '1';
					NextState					<= ST_ERROR;
				ELSIF (OOBC_ReceivedReset = '1') THEN
					NextState					<= ST_LINK_UP;
				END IF;
				
			WHEN ST_CHANGE_SPEED =>
				Status_i						<= SATA_PHY_STATUS_CHANGE_SPEED;

				IF (Trans_RP_ConfigReloaded = '1') THEN
					NextState					<= ST_LINK_UP;
				END IF;
			
			WHEN ST_ERROR =>
				Status_i						<= SATA_PHY_STATUS_ERROR;
				
				IF (Command = SATA_PHY_CMD_RESET) THEN
					OOBC_Reset				<= '1';
--					FSM_SC_Reset			<= '1';
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_RESET;
					NextState					<= ST_LINK_UP;
				ELSIF (Command = SATA_PHY_CMD_NEWLINK_UP) THEN
					OOBC_Reset				<= '1';
--					FSM_SC_Reset			<= '1';
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_NEWLINK_UP;
					NextState					<= ST_LINK_UP;
				ELSIF (OOBC_ReceivedReset = '1') THEN
					Error_rst					<= '1';
					NextState					<= ST_LINK_UP;
				END IF;
				
		END CASE;
	END PROCESS;
	
	Status	<= Status_i;
	
	-- OOB (out of band) signaling
	-- ===========================================================================
	genHost : IF (CONTROLLER_TYPE = SATA_DEVICE_TYPE_HOST) GENERATE
		OOBC : ENTITY PoC.sata_Physical_OOBControl_Host
			GENERIC MAP (
				DEBUG											=> DEBUG,
				ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
				CLOCK_FREQ								=> CLOCK_FREQ,
				ALLOW_STANDARD_VIOLATION	=> ALLOW_STANDARD_VIOLATION,
				OOB_TIMEOUT								=> OOB_TIMEOUT
			)
			PORT MAP (
				Clock											=> Clock,
				ClockEnable								=> ClockEnable,
				Reset											=> OOBC_Reset,
				
				DebugPortOut							=> OOBC_DebugPortOut,

				Retry											=> SC_Retry,
				SATAGeneration						=> SC_SATAGeneration,
				Timeout										=> OOBC_Timeout,
				LinkOK										=> OOBC_LinkOK,
				LinkDead									=> OOBC_LinkDead,
				ReceivedReset							=> OOBC_ReceivedReset,
				
				OOB_TX_Command						=> Trans_OOB_TX_Command,
				OOB_TX_Complete						=> Trans_OOB_TX_Complete,
				OOB_RX_Received						=> Trans_OOB_RX_Received,
				OOB_HandshakeComplete			=> Trans_OOB_HandshakeComplete,
				
				TX_Primitive							=> OOBC_TX_Primitive,
				RX_Primitive							=> RX_Primitive,
				RX_IsAligned							=> Trans_RX_IsAligned
			);
	END GENERATE;
	genDev : IF (CONTROLLER_TYPE = SATA_DEVICE_TYPE_DEVICE) GENERATE
		OOBC : ENTITY PoC.sata_Physical_OOBControl_Device
			GENERIC MAP (
				DEBUG											=> DEBUG,
				ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
				CLOCK_FREQ								=> CLOCK_FREQ,
				ALLOW_STANDARD_VIOLATION	=> ALLOW_STANDARD_VIOLATION,
				OOB_TIMEOUT								=> OOB_TIMEOUT
			)
			PORT MAP (
				Clock											=> Clock,
				ClockEnable								=> ClockEnable,
				Reset											=> OOBC_Reset,
				
				DebugPortOut							=> OOBC_DebugPortOut,

				Retry											=> SC_Retry,
				SATAGeneration						=> SC_SATAGeneration,
				Timeout										=> OOBC_Timeout,
				LinkOK										=> OOBC_LinkOK,
				LinkDead									=> OOBC_LinkDead,
				ReceivedReset							=> OOBC_ReceivedReset,
				
				OOB_TX_Command						=> Trans_OOB_TX_Command,
				OOB_TX_Complete						=> Trans_OOB_TX_Complete,
				OOB_RX_Received						=> Trans_OOB_RX_Received,
				OOB_HandshakeComplete			=> Trans_OOB_HandshakeComplete,
				
				TX_Primitive							=> OOBC_TX_Primitive,
				RX_Primitive							=> RX_Primitive,
				RX_IsAligned							=> Trans_RX_IsAligned
			);
	END GENERATE;
	

	-- SpeedControl
	-- ===========================================================================
	genSC : IF (ALLOW_SPEED_NEGOTIATION = TRUE) GENERATE
		SC : ENTITY PoC.sata_Physical_SpeedControl
			GENERIC MAP (
				DEBUG											=> DEBUG,
				ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
				INITIAL_SATA_GENERATION		=> INITIAL_SATA_GENERATION,
				GENERATION_CHANGE_COUNT		=> GENERATION_CHANGE_COUNT,
				ATTEMPTS_PER_GENERATION		=> ATTEMPTS_PER_GENERATION
			)
			PORT MAP (
				Clock											=> Clock,
				ClockEnable								=> ClockEnable,
				Reset											=> FSM_SC_Reset,

				Command										=> FSM_SC_Command,
				Status										=> SC_Status,

				DebugPortOut							=> SC_DebugPortOut,

				SATAGenerationMin					=> SATAGenerationMin,								-- 
				SATAGenerationMax					=> SATAGenerationMax,								-- 

				-- OOBControl interface
				OOBC_Timeout							=> OOBC_Timeout,
				OOBC_Retry								=> SC_Retry,

				-- reconfiguration interface
				Trans_RP_Reconfig					=> Trans_RP_Reconfig_i,
				Trans_RP_SATAGeneration		=> SC_SATAGeneration,								-- 
				Trans_RP_ReconfigComplete	=> Trans_RP_ReconfigComplete,
				Trans_RP_ConfigReloaded		=> Trans_RP_ConfigReloaded,
				Trans_RP_Lock							=> Trans_RP_Lock,
				Trans_RP_Locked						=> Trans_RP_Locked
			);
	END GENERATE;
	--
	-- no SpeedControl
	-- ===========================================================================
	genNoSC : IF (ALLOW_SPEED_NEGOTIATION = FALSE) GENERATE
		SIGNAL TryCounter_rst			: STD_LOGIC;
		SIGNAL TryCounter_en			: STD_LOGIC;
		SIGNAL TryCounter_s				: SIGNED(log2ceilnz(ATTEMPTS_PER_GENERATION) DOWNTO 0)			:= (OTHERS => '0');
		SIGNAL TryCounter_uf			: STD_LOGIC;
		
		SIGNAL OOB_Timeout_d			: STD_LOGIC					:= '0';
		SIGNAl OOB_Timeout_re			: STD_LOGIC;
		
	BEGIN
		SC_SATAGeneration			<= INITIAL_SATA_GENERATION;
		
		Trans_RP_Reconfig_i		<= '0';
		Trans_RP_Lock					<= NOT TryCounter_uf;
	
		OOBC_Timeout_d				<= OOBC_Timeout WHEN rising_edge(Clock);
		OOBC_Timeout_re				<= NOT OOBC_Timeout_d AND OOBC_Timeout;
		SC_Retry							<= OOBC_Timeout_re AND NOT TryCounter_uf;
		SC_Status							<= SATA_PHY_SPEED_STATUS_NEGOTIATION_ERROR WHEN (TryCounter_uf = '1') ELSE SATA_PHY_SPEED_STATUS_NEGOTIATING;

		TryCounter_rst				<= '0';	-- FIXME: replace resets by commands ... SC_SATAGeneration_Reset OR SC_AttemptCounter_Reset;
		TryCounter_en					<= OOBC_Timeout_re;
	
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (TryCounter_rst = '1') THEN
					TryCounter_s		<= to_signed(ATTEMPTS_PER_GENERATION, TryCounter_s'length);
				ELSE
					IF (TryCounter_en = '1') THEN
						TryCounter_s	<= TryCounter_s - 1;
					END IF;
				END IF;
			END IF;
		END PROCESS;
	
		TryCounter_uf <= TryCounter_s(TryCounter_s'high);
	
	END GENERATE;

	Trans_RP_Reconfig					<= Trans_RP_Reconfig_i;
	Trans_RP_SATAGeneration		<= SC_SATAGeneration;

	-- physical layer PrimitiveMux
	PROCESS(OOBC_TX_Primitive, Link_TX_Data, Link_TX_CharIsK)
	BEGIN
		CASE OOBC_TX_Primitive IS
			WHEN SATA_PRIMITIVE_ALIGN =>																			-- ALIGN				D27.3 D10.2 D10.2 K28.5
				Trans_TX_Data_i			<= to_sata_word(SATA_PRIMITIVE_ALIGN);			-- x"7B4A4ABC";
				Trans_TX_CharIsK_i	<= "0001";
				
			WHEN SATA_PRIMITIVE_DIAL_TONE =>																	-- Dial Tone		D10.2 D10.2 D10.2 D10.2
				Trans_TX_Data_i			<= to_sata_word(SATA_PRIMITIVE_DIAL_TONE);	-- x"4A4A4A4A";
				Trans_TX_CharIsK_i	<= "0000";

			WHEN SATA_PRIMITIVE_NONE =>																				-- passthrought data and k-symbols from linklayer
				Trans_TX_Data_i			<= Link_TX_Data;
				Trans_TX_CharIsK_i	<= Link_TX_CharIsK;

			WHEN OTHERS =>
				Trans_TX_Data_i			<= to_sata_word(SATA_PRIMITIVE_DIAL_TONE);
				Trans_TX_CharIsK_i	<= "0000";
				
				ASSERT FALSE REPORT "Illegal PRIMTIVE" SEVERITY FAILURE;
				
		END CASE;
	END PROCESS;
	
	Trans_TX_Data			<= Trans_TX_Data_i;
	Trans_TX_CharIsK	<= Trans_TX_CharIsK_i;
	
	-- physical layer PrimtiveDetector
	RX_Primitive			<= to_sata_primitive(Trans_RX_Data, Trans_RX_CharIsK);
	
	-- passthrought RX data
	Link_RX_Data			<= Trans_RX_Data;
	Link_RX_CharIsK		<= Trans_RX_CharIsK;
	
		
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

		CONSTANT test : boolean := dbg_ExportEncoding("Physical Layer", dbg_GenerateEncodingList,  MY_PROJECT_DIR & "ChipScope/TokenFiles/FSM_PhysicalLayer.tok");
	BEGIN
		DebugPortOut.FSM						<= dbg_EncodeState(State);
		DebugPortOut.PHY_Status			<= Status_i;
	
		DebugPortOut.TX_Data				<= Trans_TX_Data_i;
		DebugPortOut.TX_CharIsK			<= Trans_TX_CharIsK_i;
		DebugPortOut.RX_Data				<= Trans_RX_Data;
		DebugPortOut.RX_CharIsK			<= Trans_RX_CharIsK;
		DebugPortOut.RX_IsAligned		<= Trans_RX_IsAligned;
	
		DebugPortOut.OOBControl			<= OOBC_DebugPortOut;
		DebugPortOut.SpeedControl		<= SC_DebugPortOut;
	END GENERATE;
END;
