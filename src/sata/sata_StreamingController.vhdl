-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Steffen Koehler
--									Martin Zabel
--
-- Module: 					ATA Streaming Controller (Command and Transport Layer)
--
-- Description:
-- ------------------------------------
-- Combines ATA Command and SATA Transport Layer. Provides a simple interface
-- to stream data from the device to the host (read data) and vice versa (write
-- data).
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
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_StreamingController is
	generic (
		SIM_EXECUTE_IDENTIFY_DEVICE				: BOOLEAN						:= TRUE;			-- required by CommandLayer: load device parameters
		DEBUG															: BOOLEAN						:= FALSE;			-- generate ChipScope DBG_* signals
		ENABLE_DEBUGPORT									: BOOLEAN						:= FALSE;			-- 
		LOGICAL_BLOCK_SIZE								: MEMORY						:= 8 KiB			-- accessable logical block size: 8 KiB (independant from device)
																																				-- 8 KiB, maximum supported is 64 KiB, with 512 B device logical blocks
	);
	port (
		Clock											: in	STD_LOGIC;
		ClockEnable								: in	STD_LOGIC;
		Reset											: in	STD_LOGIC;

		-- StreamingController interface
		-- ========================================================================
		Command										: in	T_SATA_STREAMC_COMMAND;
		Status										: out	T_SATA_STREAMC_STATUS;
		Error											: out	T_SATA_STREAMC_ERROR;

		-- debug ports
		DebugPortOut							: out	T_SATADBG_SATASC_OUT;

		-- for measurement purposes only
		Config_BurstSize					: in	T_SLV_16;
		DriveInformation					: out	T_SATA_DRIVE_INFORMATION;
		
		-- ATA Streaming interface
		Address_AppLB							: in	T_SLV_48;
		BlockCount_AppLB					: in	T_SLV_48;
		
		-- TX path
		TX_Valid									: in	STD_LOGIC;
		TX_Data										: in	T_SLV_32;
		TX_SOR										: in	STD_LOGIC;
		TX_EOR										: in	STD_LOGIC;
		TX_Ack										: out	STD_LOGIC;
		
		-- RX path
		RX_Valid									: out	STD_LOGIC;
		RX_Data										: out	T_SLV_32;
		RX_SOR										: out	STD_LOGIC;
		RX_EOR										: out	STD_LOGIC;
		RX_Ack										: in	STD_LOGIC;
		
		-- SATAController interface
		-- ========================================================================
		SATA_ResetDone 						: in 	STD_LOGIC;
		SATA_Command							: out	T_SATA_SATACONTROLLER_COMMAND;
		SATA_Status								: in	T_SATA_SATACONTROLLER_STATUS;
		SATA_Error								: in	T_SATA_SATACONTROLLER_ERROR;
		
		-- ATA registers
		SATA_ATAHostRegisters			: out	T_SATA_ATA_HOST_REGISTERS;
		SATA_ATADeviceRegisters		: in	T_SATA_ATA_DEVICE_REGISTERS;
		
		-- TX port
		SATA_TX_SOT								: out	STD_LOGIC;
		SATA_TX_EOT								: out	STD_LOGIC;
		SATA_TX_Valid							: out	STD_LOGIC;
		SATA_TX_Data							: out	T_SLV_32;
		SATA_TX_Ack								: in	STD_LOGIC;
		
		-- RX port
		SATA_RX_SOT								: in	STD_LOGIC;
		SATA_RX_EOT								: in	STD_LOGIC;
		SATA_RX_Valid							: in	STD_LOGIC;
		SATA_RX_Data							: in	T_SLV_32;
		SATA_RX_Ack								: out	STD_LOGIC
	);
end;


architecture rtl of sata_StreamingController is
	attribute KEEP													: BOOLEAN;

	-- Common
	-- ==========================================================================
	signal MyReset 													: STD_LOGIC;
	
	-- CommandLayer
	-- ==========================================================================
	signal Cmd_Command											: T_SATA_CMD_COMMAND;
	signal Cmd_Status												: T_SATA_CMD_STATUS;
	signal Cmd_Error												: T_SATA_CMD_ERROR;
	
begin
	-- Reset sub-components until initial reset of SATAController has been
	-- completed. Allow synchronous 'Reset' only when ClockEnable = '1'.
	-- ===========================================================================
	MyReset <= (not SATA_ResetDone) or (Reset and ClockEnable);

	
	-- rewrite StreamingController commands to ATA command layer commands
	-- ===========================================================================
	process(Command)
	begin
		case Command is
			when SATA_STREAMC_CMD_NONE =>					Cmd_Command	<= SATA_CMD_CMD_NONE;
			when SATA_STREAMC_CMD_READ =>					Cmd_Command	<= SATA_CMD_CMD_READ;
			when SATA_STREAMC_CMD_WRITE =>				Cmd_Command	<= SATA_CMD_CMD_WRITE;
			when SATA_STREAMC_CMD_FLUSH_CACHE =>	Cmd_Command	<= SATA_CMD_CMD_FLUSH_CACHE;
			when SATA_STREAMC_CMD_DEVICE_RESET =>	Cmd_Command	<= SATA_CMD_CMD_DEVICE_RESET;
			when others =>												Cmd_Command	<= SATA_CMD_CMD_NONE;
		end case;
	end process;

	-- assign status record
	Status.CommandLayer				<= Cmd_Status;
	Status.TransportLayer			<= SATA_Status.TransportLayer;
	Status.LinkLayer					<= SATA_Status.LinkLayer;
	Status.PhysicalLayer			<= SATA_Status.PhysicalLayer;
	Status.TransceiverLayer		<= SATA_Status.TransceiverLayer;
	
	-- assign error record
	Error.Commandlayer				<= Cmd_Error;
	Error.TransportLayer			<= SATA_Error.TransportLayer;
	Error.LinkLayer						<= SATA_Error.LinkLayer;
	Error.PhysicalLayer				<= SATA_Error.PhysicalLayer;
	Error.TransceiverLayer		<= SATA_Error.TransceiverLayer;
	
	-- CommandLayer
	-- ===========================================================================
	Cmd : entity PoC.sata_CommandLayer
		generic map (
			SIM_EXECUTE_IDENTIFY_DEVICE	=> SIM_EXECUTE_IDENTIFY_DEVICE,		-- required by CommandLayer: load device parameters
			DEBUG												=> DEBUG,													-- generate ChipScope DBG_* signals
			ENABLE_DEBUGPORT						=> ENABLE_DEBUGPORT,
			LOGICAL_BLOCK_SIZE					=> LOGICAL_BLOCK_SIZE
		)
		port map (
			Clock												=> Clock,
			Reset												=> MyReset,

			-- for measurement purposes only
			Config_BurstSize						=> Config_BurstSize,

			-- CommandLayer interface
			Command											=> Cmd_Command,
			Status											=> Cmd_Status,
			Error												=> Cmd_Error,
		
			DebugPortOut								=> DebugPortOut.Commandlayer,
		
			Address_AppLB								=> Address_AppLB,
			BlockCount_AppLB						=> BlockCount_AppLB,
			DriveInformation						=> DriveInformation,
		
			-- TX path
			TX_Valid										=> TX_Valid,
			TX_Data											=> TX_Data,
			TX_SOR											=> TX_SOR,
			TX_EOR											=> TX_EOR,
			TX_Ack											=> TX_Ack,
		
			-- RX path
			RX_Valid										=> RX_Valid,
			RX_Data											=> RX_Data,
			RX_SOR											=> RX_SOR,
			RX_EOR											=> RX_EOR,
			RX_Ack											=> RX_Ack,
			
			-- TransportLayer interface
			SATAC_Command								=> SATA_Command,
			SATAC_Status								=> SATA_Status,
			SATAC_Error									=> SATA_Error,

			-- ATARegister interface
			Trans_ATAHostRegisters			=> SATA_ATAHostRegisters,
			Trans_ATAdeviceRegisters		=> SATA_ATAdeviceRegisters,
			
			-- TX path
			Trans_TX_Valid							=> SATA_TX_Valid,
			Trans_TX_Data								=> SATA_TX_Data,
			Trans_TX_SOT								=> SATA_TX_SOT,
			Trans_TX_EOT								=> SATA_TX_EOT,
			Trans_TX_Ack								=> SATA_TX_Ack,
			
			-- RX path
			Trans_RX_Valid							=> SATA_RX_Valid,
			Trans_RX_Data								=> SATA_RX_Data,
			Trans_RX_SOT								=> SATA_RX_SOT,
			Trans_RX_EOT								=> SATA_RX_EOT,
			Trans_RX_Ack								=> SATA_RX_Ack	
		);
	
	-- DebugPort
	-- ===========================================================================
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
	begin
		DebugPortOut.Command_Command		<= Cmd_Command;
		DebugPortOut.Command_Status			<= Cmd_Status;
		DebugPortOut.Command_Error			<= Cmd_Error;
	end generate;
end;
