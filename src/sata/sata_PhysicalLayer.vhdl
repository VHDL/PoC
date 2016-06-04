-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Entity:					SATA Physical Layer
--
-- Description:
-- ------------------------------------
-- Represents the PhysicalLayer of the SATA stack. Detects if a device is
-- present and establishes a communication, both using OOB.
--
-- Clock might be unstable as defined in module sata_PhysicalLayerFSM.
--
-- After Power-Up or a ClockNetwork_Reset (indicated by Trans_ResetDone = '0')
-- this layer automatically tries to establish a communication with speed
-- negotiation. A device is detected by indefinitly polling using OOB COMRESET.
-- The result is indicated by output Status:
--
-- Status can be one of the following:
-- - SATA_PHY_STATUS_RESET: 					PhysicalLayer is resetting.
-- - SATA_PHY_STATUS_NODEVICE: 				No device detected yet.
-- - SATA_PHY_STATUS_NOCOMMUNICATION: Device detected, but communication not
-- 																		yet established.
-- - SATA_PHY_STATUS_COMMUNICATING:		Device detected and communication
-- 																		established.
-- - SATA_PHY_STATUS_ERROR:						See output Error.
--
-- It is guaranteed, that after SATA_PHY_STATUS_COMMUNICATING is signaled,
-- the clock is stable (i.e. no reconfiguration) until a Command or a global
-- Reset/PowerDown/ClockNetwork_Reset is applied.
--
-- Error can be one of the following:
-- - SATA_PHY_ERROR_NONE: 				No error.
-- - SATA_PHY_ERROR_LINK_DEAD: 		Received OOB sequences after link was
-- 																established. Resetting this stack on behalf
-- 																of receiving COMRESET is not yet supported.
-- - SATA_PHY_ERROR_NEGOTIATION:	Speed negotiation failed.
--
-- Commands are only accepted when Status is SATA_PHY_STATUS_COMMUNICATING or
-- SATA_PHY_STATUS_ERROR. Possible Commands are:
-- - SATA_PHY_CMD_NONE: 							Do nothing.
-- - SATA_PHY_CMD_INIT_CONNECTION: 		Init connection with speed negotiation.
-- - SATA_PHY_CMD_REINIT_CONNECTION: 	Reinit connection at same speed.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_PhysicalLayer is
	generic (
		DEBUG														: BOOLEAN													:= FALSE;
		ENABLE_DEBUGPORT								: BOOLEAN													:= FALSE;
		CONTROLLER_TYPE									: T_SATA_DEVICE_TYPE							:= SATA_DEVICE_TYPE_HOST;
		ALLOW_SPEED_NEGOTIATION					: BOOLEAN													:= TRUE;
		INITIAL_SATA_GENERATION					: T_SATA_GENERATION								:= C_SATA_GENERATION_MAX;
		ALLOW_STANDARD_VIOLATION				: BOOLEAN													:= FALSE;
		OOB_TIMEOUT											: TIME														:= TIME'low;
		GENERATION_CHANGE_COUNT					: INTEGER													:= 8;
		ATTEMPTS_PER_GENERATION					: INTEGER													:= 4
	);
	port (
		Clock														: in	STD_LOGIC;
		ClockEnable											: in	STD_LOGIC;
		Reset														: in	STD_LOGIC;										-- general logic reset without some counter resets while Clock is unstable
																																				--   => preserve SATAGeneration between connection-cycles
		SATAGenerationMin								: in	T_SATA_GENERATION;						--
		SATAGenerationMax								: in	T_SATA_GENERATION;						--

		-- PhysicalLayer interface
		Command													: in	T_SATA_PHY_COMMAND;
		Status													: out	T_SATA_PHY_STATUS;
		Error														: out	T_SATA_PHY_ERROR;

		DebugPortOut										: out	T_SATADBG_PHYSICAL_OUT;

		Link_RX_Data										: out	T_SLV_32;
		Link_RX_CharIsK									: out	T_SLV_4;

		Link_TX_Data										: in	T_SLV_32;
		Link_TX_CharIsK									: in	T_SLV_4;

		-- TransceiverLayer interface
		Trans_ResetDone									: in	STD_LOGIC;

		Trans_Command										: out	T_SATA_TRANSCEIVER_COMMAND;
		Trans_Status										: in	T_SATA_TRANSCEIVER_STATUS;
		Trans_Error											: in	T_SATA_TRANSCEIVER_ERROR;

		Trans_RP_Reconfig								: out	STD_LOGIC;
		Trans_RP_SATAGeneration					: out	T_SATA_GENERATION;
		Trans_RP_ConfigReloaded					: in	STD_LOGIC;

		Trans_OOB_TX_Command						: out	T_SATA_OOB;
		Trans_OOB_TX_Complete						: in	STD_LOGIC;
		Trans_OOB_RX_Received						: in	T_SATA_OOB;
		Trans_OOB_HandshakeComplete			: out	STD_LOGIC;
		Trans_OOB_AlignDetected    			: out	STD_LOGIC;

		Trans_TX_Data										: out	T_SLV_32;
		Trans_TX_CharIsK								: out T_SLV_4;

		Trans_RX_Data										: in	T_SLV_32;
		Trans_RX_CharIsK								: in	T_SLV_4;
		Trans_RX_Valid									: in	STD_LOGIC
	);
end entity;


architecture rtl of sata_PhysicalLayer is
	signal OOBC_Reset									: STD_LOGIC;
	signal OOBC_DeviceOrHostDetected	: STD_LOGIC;
	signal OOBC_LinkOK								: STD_LOGIC;
	signal OOBC_LinkDead							: STD_LOGIC;
	signal OOBC_Timeout								: STD_LOGIC;

	signal Trans_RP_SATAGeneration_i	: T_SATA_GENERATION;

	signal OOBC_TX_Primitive					: T_SATA_PRIMITIVE;
	signal RX_Primitive								: T_SATA_PRIMITIVE;
	signal Trans_TX_Data_i						: T_SLV_32;
	signal Trans_TX_CharIsK_i					: T_SLV_4;

	signal OOBC_DebugPortOut					: T_SATADBG_PHYSICAL_OOBCONTROL_OUT;
	signal PFSM_DebugPortOut					: T_SATADBG_PHYSICAL_PFSM_OUT;

begin

	assert FALSE report "Physical Layer"																															severity NOTE;
	assert FALSE report "  ControllerType:         " & T_SATA_DEVICE_TYPE'image(CONTROLLER_TYPE)			severity NOTE;
	assert FALSE report "  AllowSpeedNegotiation:  " & to_string(ALLOW_SPEED_NEGOTIATION)							severity NOTE;
	assert FALSE report "  AllowStandardViolation: " & to_string(ALLOW_STANDARD_VIOLATION)						severity NOTE;
	assert FALSE report "  Init. SATA Generation:  Gen" & INTEGER'image(INITIAL_SATA_GENERATION + 1)	severity NOTE;

	-- The FSM
	-- ===========================================================================
	PFSM: entity work.sata_PhysicalLayerFSM
		generic map (
			DEBUG										=> DEBUG,
			ALLOW_SPEED_NEGOTIATION => ALLOW_SPEED_NEGOTIATION,
			ENABLE_DEBUGPORT				=> ENABLE_DEBUGPORT,
			INITIAL_SATA_GENERATION => INITIAL_SATA_GENERATION,
			GENERATION_CHANGE_COUNT => GENERATION_CHANGE_COUNT,
			ATTEMPTS_PER_GENERATION => ATTEMPTS_PER_GENERATION)
		port map (
			Clock											=> Clock,
			ClockEnable 							=> ClockEnable,
			Reset 										=> Reset,
			Command										=> Command,
			Status										=> Status,
			Error											=> Error,
			SATAGenerationMin					=> SATAGenerationMin,
			SATAGenerationMax					=> SATAGenerationMax,
			DebugPortOut							=> PFSM_DebugPortOut,
			OOBC_Timeout							=> OOBC_Timeout,
			OOBC_DeviceOrHostDetected => OOBC_DeviceOrHostDetected,
			OOBC_LinkOK								=> OOBC_LinkOK,
			OOBC_LinkDead							=> OOBC_LinkDead,
			OOBC_Reset								=> OOBC_Reset,
			Trans_ResetDone  					=> Trans_ResetDone,
			Trans_Status     					=> Trans_Status,
			Trans_RP_Reconfig					=> Trans_RP_Reconfig,
			Trans_RP_SATAGeneration		=> Trans_RP_SATAGeneration_i,
			Trans_RP_ConfigReloaded		=> Trans_RP_ConfigReloaded);

	-- TODO Feature Request: Replace Trans_RP_* signals by CSE interface
	Trans_Command 					<= SATA_TRANSCEIVER_CMD_NONE;
	Trans_RP_SATAGeneration <= Trans_RP_SATAGeneration_i;

	-- OOB (out of band) signaling
	-- ===========================================================================
	genHost : if (CONTROLLER_TYPE = SATA_DEVICE_TYPE_HOST) generate
		OOBC : entity PoC.sata_Physical_OOBControl_Host
			generic map (
				DEBUG											=> DEBUG,
				ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
				ALLOW_STANDARD_VIOLATION	=> ALLOW_STANDARD_VIOLATION,
				OOB_TIMEOUT								=> OOB_TIMEOUT
			)
			port map (
				Clock											=> Clock,
				Reset											=> OOBC_Reset,

				DebugPortOut							=> OOBC_DebugPortOut,

				SATAGeneration						=> Trans_RP_SATAGeneration_i,
				Timeout										=> OOBC_Timeout,
				DeviceDetected 						=> OOBC_DeviceOrHostDetected,
				LinkOK										=> OOBC_LinkOK,
				LinkDead									=> OOBC_LinkDead,

				OOB_TX_Command						=> Trans_OOB_TX_Command,
				OOB_TX_Complete						=> Trans_OOB_TX_Complete,
				OOB_RX_Received						=> Trans_OOB_RX_Received,
				OOB_HandshakeComplete			=> Trans_OOB_HandshakeComplete,
				OOB_AlignDetected					=> Trans_OOB_AlignDetected,

				TX_Primitive							=> OOBC_TX_Primitive,
				RX_Primitive							=> RX_Primitive,
				RX_Valid									=> Trans_RX_Valid
			);
	end generate;
	genDev : if (CONTROLLER_TYPE = SATA_DEVICE_TYPE_DEVICE) generate
		OOBC : entity PoC.sata_Physical_OOBControl_Device
			generic map (
				DEBUG											=> DEBUG,
				ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
				ALLOW_STANDARD_VIOLATION	=> ALLOW_STANDARD_VIOLATION,
				OOB_TIMEOUT								=> OOB_TIMEOUT
			)
			port map (
				Clock											=> Clock,
				Reset											=> OOBC_Reset,

				DebugPortOut							=> OOBC_DebugPortOut,

				SATAGeneration						=> Trans_RP_SATAGeneration_i,
				HostDetected 							=> OOBC_DeviceOrHostDetected,
				Timeout										=> OOBC_Timeout,
				LinkOK										=> OOBC_LinkOK,
				LinkDead									=> OOBC_LinkDead,

				OOB_TX_Command						=> Trans_OOB_TX_Command,
				OOB_TX_Complete						=> Trans_OOB_TX_Complete,
				OOB_RX_Received						=> Trans_OOB_RX_Received,
				OOB_HandshakeComplete			=> Trans_OOB_HandshakeComplete,
--			OOB_AlignDetected					=> Trans_OOB_AlignDetected,

				TX_Primitive							=> OOBC_TX_Primitive,
				RX_Primitive							=> RX_Primitive,
				RX_Valid									=> Trans_RX_Valid
				);

		Trans_OOB_AlignDetected <= '0';
	end generate;



	-- physical layer PrimitiveMux
	-- ===========================================================================
	process(OOBC_TX_Primitive, Link_TX_Data, Link_TX_CharIsK)
	begin
		case OOBC_TX_Primitive is
			when SATA_PRIMITIVE_ALIGN =>																			-- ALIGN				D27.3 D10.2 D10.2 K28.5
				Trans_TX_Data_i			<= to_sata_word(SATA_PRIMITIVE_ALIGN);			-- x"7B4A4ABC";
				Trans_TX_CharIsK_i	<= "0001";

			when SATA_PRIMITIVE_DIAL_TONE =>																	-- Dial Tone		D10.2 D10.2 D10.2 D10.2
				Trans_TX_Data_i			<= to_sata_word(SATA_PRIMITIVE_DIAL_TONE);	-- x"4A4A4A4A";
				Trans_TX_CharIsK_i	<= "0000";

			when SATA_PRIMITIVE_NONE =>																				-- passthrought data and k-symbols from linklayer
				Trans_TX_Data_i			<= Link_TX_Data;
				Trans_TX_CharIsK_i	<= Link_TX_CharIsK;

			when others =>
				Trans_TX_Data_i			<= to_sata_word(SATA_PRIMITIVE_DIAL_TONE);
				Trans_TX_CharIsK_i	<= "0000";

				assert FALSE report "Illegal PRIMTIVE" severity FAILURE;

		end case;
	end process;

	Trans_TX_Data			<= Trans_TX_Data_i;
	Trans_TX_CharIsK	<= Trans_TX_CharIsK_i;

	-- physical layer PrimtiveDetector
	RX_Primitive			<= to_sata_primitive(Trans_RX_Data, Trans_RX_CharIsK);

	-- passthrought RX data
	Link_RX_Data			<= Trans_RX_Data;
	Link_RX_CharIsK		<= Trans_RX_CharIsK;


	-- debug port
	-- ===========================================================================
	genDebugPort : if (ENABLE_DEBUGPORT = TRUE) generate
	begin
		DebugPortOut.TX_Data				<= Trans_TX_Data_i;
		DebugPortOut.TX_CharIsK			<= Trans_TX_CharIsK_i;
		DebugPortOut.RX_Data				<= Trans_RX_Data;
		DebugPortOut.RX_CharIsK			<= Trans_RX_CharIsK;
		DebugPortOut.RX_Valid				<= Trans_RX_Valid;

		DebugPortOut.OOBControl			<= OOBC_DebugPortOut;
		DebugPortOut.PFSM 					<= PFSM_DebugPortOut;
	end generate;
end;
