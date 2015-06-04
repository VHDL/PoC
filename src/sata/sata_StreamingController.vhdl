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
    SIM_WAIT_FOR_INITIAL_REGDH_FIS		: BOOLEAN						:= TRUE;      -- required by ATA/SATA standard
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
		SATA_ResetDone 						: in  STD_LOGIC;
		SATA_Command							: out	T_SATA_SATACONTROLLER_COMMAND;
		SATA_Status								: in	T_SATA_SATACONTROLLER_STATUS;
		SATA_Error								: in	T_SATA_SATACONTROLLER_ERROR;
		SATA_SATAGeneration 			: in  T_SATA_GENERATION;
		
		-- TX port
		SATA_TX_SOF								: out	STD_LOGIC;
		SATA_TX_EOF								: out	STD_LOGIC;
		SATA_TX_Valid							: out	STD_LOGIC;
		SATA_TX_Data							: out	T_SLV_32;
		SATA_TX_Ack								: in	STD_LOGIC;
		SATA_TX_InsertEOF					: in	STD_LOGIC;															-- helper signal: insert EOF - max frame size reached
		
		SATA_TX_FS_Ack						: out	STD_LOGIC;
		SATA_TX_FS_Valid					: in	STD_LOGIC;
		SATA_TX_FS_SendOK					: in	STD_LOGIC;
		SATA_TX_FS_SyncEsc				: in	STD_LOGIC;
		
		-- RX port
		SATA_RX_SOF								: in	STD_LOGIC;
		SATA_RX_EOF								: in	STD_LOGIC;
		SATA_RX_Valid							: in	STD_LOGIC;
		SATA_RX_Data							: in	T_SLV_32;
		SATA_RX_Ack								: out	STD_LOGIC;
		
		SATA_RX_FS_Ack						: out	STD_LOGIC;
		SATA_RX_FS_Valid					: in	STD_LOGIC;
		SATA_RX_FS_CRCOK					: in	STD_LOGIC;
		SATA_RX_FS_SyncEsc				: in	STD_LOGIC
	);
end;


architecture rtl of sata_StreamingController is
	attribute KEEP													: BOOLEAN;

	-- Common
	-- ==========================================================================
	signal MyReset 													: STD_LOGIC;
	
	-- ApplicationLayer
	-- ==========================================================================
	signal RX_Data_i												: T_SLV_32;
	signal RX_SOR_i													: STD_LOGIC;
	signal RX_EOR_i													: STD_LOGIC;
	signal RX_Valid_i												: STD_LOGIC;
	
	-- CommandLayer
	-- ==========================================================================
	signal Cmd_Command											: T_SATA_CMD_COMMAND;
	signal Cmd_Status												: T_SATA_CMD_STATUS;
	signal Cmd_Error												: T_SATA_CMD_ERROR;
	
--	signal Cmd_DriveInformation							: T_SATA_DRIVE_INFORMATION;
	signal Cmd_ATAHostRegisters							: T_SATA_ATA_HOST_REGISTERS;

	-- TransportLayer
	signal Trans_ResetDone									: STD_LOGIC;
	signal Trans_Command										: T_SATA_TRANS_COMMAND;
	signal Trans_Status											: T_SATA_TRANS_STATUS;
	signal Trans_Error											:	T_SATA_TRANS_ERROR;

	signal Trans_ATADeviceRegisters					: T_SATA_ATA_DEVICE_REGISTERS;

	signal Cmd_TX_Valid				: STD_LOGIC;
	signal Cmd_TX_Data				: T_SLV_32;
	signal Cmd_TX_SOT					: STD_LOGIC;
	signal Cmd_TX_EOT					: STD_LOGIC;
	signal Cmd_RX_Ack					: STD_LOGIC;
	
	signal TX_Glue_Ack				: STD_LOGIC;
	signal TX_Glue_Valid			: STD_LOGIC;
	signal TX_Glue_Data				: T_SLV_32;
	signal TX_Glue_SOT				: STD_LOGIC;
	signal TX_Glue_EOT				: STD_LOGIC;
	
	signal RX_Glue_Valid			: STD_LOGIC;
	signal RX_Glue_Data				: T_SLV_32;
	signal RX_Glue_SOT				: STD_LOGIC;
	signal RX_Glue_EOT				: STD_LOGIC;
	signal RX_Glue_Ack					: STD_LOGIC;

	signal Trans_RX_Valid			: STD_LOGIC;
	signal Trans_RX_Data			: T_SLV_32;
	signal Trans_RX_SOT				: STD_LOGIC;
	signal Trans_RX_EOT				: STD_LOGIC;
	signal Trans_TX_Ack				: STD_LOGIC;			
	
	-- SATAController (LinkLayer)
	signal SATA_TX_Data_i			: T_SLV_32;
	signal SATA_TX_SOF_i			: STD_LOGIC;
	signal SATA_TX_EOF_i			: STD_LOGIC;
	signal SATA_TX_Valid_i		: STD_LOGIC;

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
	Status.TransportLayer			<= Trans_Status;
	Status.LinkLayer					<= SATA_Status.LinkLayer;
	Status.PhysicalLayer			<= SATA_Status.PhysicalLayer;
	Status.TransceiverLayer		<= SATA_Status.TransceiverLayer;
	
	-- assign error record
	Error.Commandlayer				<= Cmd_Error;
	Error.TransportLayer			<= Trans_Error;
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
			RX_Valid										=> RX_Valid_i,
			RX_Data											=> RX_Data_i,
			RX_SOR											=> RX_SOR_i,
			RX_EOR											=> RX_EOR_i,
			RX_Ack											=> RX_Ack,
			
			-- TransportLayer interface
			Trans_Command								=> Trans_Command,
			Trans_Status								=> Trans_Status,
			Trans_Error									=> Trans_Error,

			-- ATARegister interface
			Trans_ATAHostRegisters				=> Cmd_ATAHostRegisters,
			Trans_ATAdeviceRegisters			=> Trans_ATAdeviceRegisters,
			
			-- TX path
			Trans_TX_Valid							=> Cmd_TX_Valid,
			Trans_TX_Data								=> Cmd_TX_Data,
			Trans_TX_SOT								=> Cmd_TX_SOT,
			Trans_TX_EOT								=> Cmd_TX_EOT,
			Trans_TX_Ack								=> TX_Glue_Ack,
			
			-- RX path
			Trans_RX_Valid							=> RX_Glue_Valid,
			Trans_RX_Data								=> RX_Glue_Data,
			Trans_RX_SOT								=> RX_Glue_SOT,
			Trans_RX_EOT								=> RX_Glue_EOT,
			Trans_RX_Ack								=> Cmd_RX_Ack	
		);
	
	RX_Data		<= RX_Data_i;
	RX_SOR		<= RX_SOR_i;
	RX_EOR		<= RX_EOR_i;
	RX_Valid	<= RX_Valid_i;

	RX_Glue : block is
		signal FIFO_Full		: STD_LOGIC;
		signal FIFO_DataIn	: STD_LOGIC_VECTOR(33 downto 0);
		signal FIFO_DataOut	: STD_LOGIC_VECTOR(33 downto 0);
		
	begin
		RX_FIFO : entity PoC.fifo_glue
			generic map ( 
				D_BITS => FIFO_DataIn'length
			)
			port map (
				clk => Clock,
				rst => MyReset,
				
				di 	=> FIFO_DataIn,
				ful => FIFO_Full,
				put => Trans_RX_Valid,
				
				do 	=> FIFO_DataOut,
				vld => RX_Glue_Valid,
				got => Cmd_RX_Ack	
			);

		FIFO_DataIn 			<= (Trans_RX_SOT & Trans_RX_EOT & Trans_RX_Data);
		RX_Glue_Ack		 		<= not FIFO_Full;
		RX_Glue_Data 			<= FIFO_DataOut(31 downto 0);
		RX_Glue_SOT 			<= FIFO_DataOut(33);
		RX_Glue_EOT 			<= FIFO_DataOut(32);
	end block;

	TX_Glue : block
		signal FIFO_Full		: STD_LOGIC;
		signal FIFO_DataIn	: STD_LOGIC_VECTOR(33 downto 0);
		signal FIFO_DataOut	: STD_LOGIC_VECTOR(33 downto 0);
		
	begin
		TX_FIFO : entity PoC.fifo_glue
			generic map ( 
				D_BITS => FIFO_DataIn'length
			)
			port map (
				clk => Clock,
				rst => MyReset,
				
				di 	=> FIFO_DataIn,
				ful => FIFO_Full,
				put => Cmd_TX_Valid,
				
				do 	=> FIFO_DataOut,
				vld => TX_Glue_Valid, 
				got => Trans_TX_Ack	
			);

		FIFO_DataIn 	<= (Cmd_TX_SOT & Cmd_TX_EOT & Cmd_TX_Data);
		TX_Glue_Ack		<= not FIFO_Full;
		TX_Glue_Data	<= FIFO_DataOut(31 downto 0);
		TX_Glue_SOT		<= FIFO_DataOut(33);
		TX_Glue_EOT		<= FIFO_DataOut(32);
	end block;

-- TransportLayer
	-- ==========================================================================================================================================================
	Trans : entity PoC.sata_TransportLayer
    generic map (
			DEBUG														=> DEBUG,
			ENABLE_DEBUGPORT								=> ENABLE_DEBUGPORT,
      SIM_WAIT_FOR_INITIAL_REGDH_FIS  => SIM_WAIT_FOR_INITIAL_REGDH_FIS
    )
		port map (
			Clock												=> Clock,
			Reset												=> MyReset,

			-- TransportLayer interface
			Command											=> Trans_Command,
			Status											=> Trans_Status,
			Error												=> Trans_Error,
		
			DebugPortOut								=> DebugPortOut.TransportLayer,
		
			-- ATA registers
			ATAHostRegisters						=> Cmd_ATAHostRegisters,
			ATADeviceRegisters					=> Trans_ATADeviceRegisters,
		
			-- TX path
			TX_Valid										=> TX_Glue_Valid,
			TX_Data											=> TX_Glue_Data,
			TX_SOT											=> TX_Glue_SOT,
			TX_EOT											=> TX_Glue_EOT,
			TX_Ack											=> Trans_TX_Ack,
		
			-- RX path
			RX_Valid										=> Trans_RX_Valid,
			RX_Data											=> Trans_RX_Data,
			RX_SOT											=> Trans_RX_SOT,
			RX_EOT											=> Trans_RX_EOT,
			RX_Ack											=> RX_Glue_Ack,
			
			-- SATAController interface
			SATAGeneration 							=> SATA_SATAGeneration,
			SATA_Command								=> SATA_Command,
			SATA_Status									=> SATA_Status,
			
			-- TX path
			Link_TX_Ack									=> SATA_TX_Ack,
			Link_TX_Data								=> SATA_TX_Data_i,
			Link_TX_SOF									=> SATA_TX_SOF_i,
			Link_TX_EOF									=> SATA_TX_EOF_i,
			Link_TX_Valid								=> SATA_TX_Valid_i,
			Link_TX_InsertEOF						=> SATA_TX_InsertEOF,				-- helper signal: insert EOF - max frame size reached
				
			Link_TX_FS_Ack							=> SATA_TX_FS_Ack,
			Link_TX_FS_SendOK						=> SATA_TX_FS_SendOK,
			Link_TX_FS_SyncEsc					=> SATA_TX_FS_SyncEsc,
			Link_TX_FS_Valid						=> SATA_TX_FS_Valid,
		
			-- RX path
			Link_RX_Ack									=> SATA_RX_Ack,
			Link_RX_Data								=> SATA_RX_Data,
			Link_RX_SOF									=> SATA_RX_SOF,
			Link_RX_EOF									=> SATA_RX_EOF,
			Link_RX_Valid								=> SATA_RX_Valid,
				
			Link_RX_FS_Ack							=> SATA_RX_FS_Ack,
			Link_RX_FS_CRCOK						=> SATA_RX_FS_CRCOK,
			Link_RX_FS_SyncEsc					=> SATA_RX_FS_SyncEsc,
			Link_RX_FS_Valid						=> SATA_RX_FS_Valid
		);
	
	SATA_TX_Data				<= SATA_TX_Data_i;
	SATA_TX_SOF					<= SATA_TX_SOF_i;
	SATA_TX_EOF					<= SATA_TX_EOF_i;
	SATA_TX_Valid				<= SATA_TX_Valid_i;

	-- DebugPort
	-- ===========================================================================
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
	begin
		DebugPortOut.Command_Command		<= Cmd_Command;
		DebugPortOut.Command_Status			<= Cmd_Status;
		DebugPortOut.Command_Error			<= Cmd_Error;

		DebugPortOut.Transport_Command	<= Trans_Command;
		DebugPortOut.Transport_Status		<=	Trans_Status;
		DebugPortOut.Transport_Error		<=	Trans_Error;
	end generate;
end;
