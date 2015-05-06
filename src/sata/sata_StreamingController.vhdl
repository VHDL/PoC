-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--									Steffen Koehler
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
USE			PoC.sata.ALL;
USE			PoC.satadbg.ALL;


ENTITY sata_StreamingController IS
	GENERIC (
    SIM_WAIT_FOR_INITIAL_REGDH_FIS		: BOOLEAN                     := TRUE;      -- required by ATA/SATA standard
		SIM_EXECUTE_IDENTIFY_DEVICE				: BOOLEAN											:= TRUE;			-- required by CommandLayer: load device parameters
		DEBUG															: BOOLEAN											:= FALSE;			-- generate ChipScope DBG_* signals
		ENABLE_DEBUGPORT									: BOOLEAN											:= FALSE;			-- 
		LOGICAL_BLOCK_SIZE_ldB						: POSITIVE										:= 13					-- accessable logical block size: 8 kB (independant from device)
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;

		-- ATAStreamingController interface
		-- ========================================================================
		Command										: IN	T_SATA_STREAMC_COMMAND;
		Status										: OUT	T_SATA_STREAMC_STATUS;
		Error											: OUT	T_SATA_STREAMC_ERROR;

		-- debug ports
		DebugPortOut							: OUT	T_SATADBG_SATASC_OUT;

		-- for measurement purposes only
		Config_BurstSize					: IN	T_SLV_16;
		
		-- ATA Streaming interface
		Address_AppLB							: IN	T_SLV_48;
		BlockCount_AppLB					: IN	T_SLV_48;
		
		-- TX path
		TX_Valid									: IN	STD_LOGIC;
		TX_Data										: IN	T_SLV_32;
		TX_SOR										: IN	STD_LOGIC;
		TX_EOR										: IN	STD_LOGIC;
		TX_Ack										: OUT	STD_LOGIC;
		
		-- RX path
		RX_Valid									: OUT	STD_LOGIC;
		RX_Data										: OUT	T_SLV_32;
		RX_SOR										: OUT	STD_LOGIC;
		RX_EOR										: OUT	STD_LOGIC;
		RX_Ack										: IN	STD_LOGIC;
		
		-- SATAController interface
		-- ========================================================================
		SATA_ResetDone 						: in  STD_LOGIC;
		SATA_Status								: IN	T_SATA_SATACONTROLLER_STATUS;
	
		-- TX port
		SATA_TX_SOF								: OUT	STD_LOGIC;
		SATA_TX_EOF								: OUT	STD_LOGIC;
		SATA_TX_Valid							: OUT	STD_LOGIC;
		SATA_TX_Data							: OUT	T_SLV_32;
		SATA_TX_Ack								: IN	STD_LOGIC;
		SATA_TX_InsertEOF					: IN	STD_LOGIC;															-- helper signal: insert EOF - max frame size reached
		
		SATA_TX_FS_Ack						: OUT	STD_LOGIC;
		SATA_TX_FS_Valid					: IN	STD_LOGIC;
		SATA_TX_FS_SendOK					: IN	STD_LOGIC;
		SATA_TX_FS_Abort					: IN	STD_LOGIC;
		
		-- RX port
		SATA_RX_SOF								: IN	STD_LOGIC;
		SATA_RX_EOF								: IN	STD_LOGIC;
		SATA_RX_Valid							: IN	STD_LOGIC;
		SATA_RX_Data							: IN	T_SLV_32;
		SATA_RX_Ack								: OUT	STD_LOGIC;
		
		SATA_RX_FS_Ack						: OUT	STD_LOGIC;
		SATA_RX_FS_Valid					: IN	STD_LOGIC;
		SATA_RX_FS_CRCOK					: IN	STD_LOGIC;
		SATA_RX_FS_Abort					: IN	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF sata_StreamingController IS
	ATTRIBUTE KEEP													: BOOLEAN;

	-- ==========================================================================
	-- ATAStreamingController configuration
	-- ==========================================================================
	CONSTANT AHEAD_CYCLES_FOR_INSERT_EOT		: NATURAL			:= 1;
	
	-- TX path																						current value				test value			default value
	CONSTANT TX_FIFO_DEPTH									: NATURAL			:= 16;					--		 0							 0

	-- RX path
	CONSTANT RX_FIFO_DEPTH									: POSITIVE		:= 4096;				--	1024						2048
	
	-- ApplicationLayer
	-- ==========================================================================
	SIGNAL RX_Data_i												: T_SLV_32;
	SIGNAL RX_SOR_i													: STD_LOGIC;
	SIGNAL RX_EOR_i													: STD_LOGIC;
	SIGNAL RX_Valid_i												: STD_LOGIC;
	
	-- CommandLayer
	-- ==========================================================================
	SIGNAL Cmd_Command											: T_SATA_CMD_COMMAND;
	SIGNAL Cmd_Status												: T_SATA_CMD_STATUS;
	SIGNAL Cmd_Error												: T_SATA_CMD_ERROR;
	
	SIGNAL Cmd_ATA_Command									: T_SATA_ATA_COMMAND;
	SIGNAL Cmd_ATA_Address_LB								: T_SLV_48;
	SIGNAL Cmd_ATA_BlockCount_LB						: T_SLV_16;

	SIGNAL Cmd_DriveInformation							: T_SATA_DRIVE_INFORMATION;

	SIGNAL Cmd_UpdateATAHostRegisters				: STD_LOGIC;
	SIGNAL Cmd_ATAHostRegisters							: T_SATA_ATA_HOST_REGISTERS;

	-- TransportLayer
	signal Trans_ResetDone									: STD_LOGIC;
	SIGNAL Trans_Command										: T_SATA_TRANS_COMMAND;
	SIGNAL Trans_Status											: T_SATA_TRANS_STATUS;
	SIGNAL Trans_Error											:	T_SATA_TRANS_ERROR;

	SIGNAL Trans_ATADeviceRegisters					: T_SATA_ATA_DEVICE_REGISTERS;

	SIGNAL Cmd_TX_Valid				: STD_LOGIC;
	SIGNAL Cmd_TX_Data				: T_SLV_32;
	SIGNAL Cmd_TX_SOT					: STD_LOGIC;
	SIGNAL Cmd_TX_EOT					: STD_LOGIC;
	SIGNAL Cmd_RX_Ack					: STD_LOGIC;
	
	SIGNAL TX_Glue_Ack				: STD_LOGIC;
	SIGNAL TX_Glue_Valid			: STD_LOGIC;
	SIGNAL TX_Glue_Data				: T_SLV_32;
	SIGNAL TX_Glue_SOT				: STD_LOGIC;
	SIGNAL TX_Glue_EOT				: STD_LOGIC;
	
	SIGNAL RX_Glue_Valid			: STD_LOGIC;
	SIGNAL RX_Glue_Data				: T_SLV_32;
	SIGNAL RX_Glue_SOT				: STD_LOGIC;
	SIGNAL RX_Glue_EOT				: STD_LOGIC;
	SIGNAL RX_Glue_Commit			: STD_LOGIC;
	SIGNAL RX_Glue_Rollback		: STD_LOGIC;
	SIGNAL RX_Glue_Ack					: STD_LOGIC;

	SIGNAL Trans_RX_Valid			: STD_LOGIC;
	SIGNAL Trans_RX_Data			: T_SLV_32;
	SIGNAL Trans_RX_SOT				: STD_LOGIC;
	SIGNAL Trans_RX_EOT				: STD_LOGIC;
	SIGNAL Trans_RX_Commit		: STD_LOGIC;
	SIGNAL Trans_RX_Rollback	: STD_LOGIC;
	SIGNAL Trans_TX_Ack				: STD_LOGIC;			
	
	-- SATAController (LinkLayer)
	SIGNAL SATA_TX_Data_i			: T_SLV_32;
	SIGNAL SATA_TX_SOF_i			: STD_LOGIC;
	SIGNAL SATA_TX_EOF_i			: STD_LOGIC;
	SIGNAL SATA_TX_Valid_i		: STD_LOGIC;

BEGIN

	-- rewrite StreamingController commands to ATA command layer commands
	-- ==========================================================================================================================================================
	PROCESS(Command)
	BEGIN
		CASE Command IS
			WHEN SATA_STREAMC_CMD_NONE =>					Cmd_Command	<= SATA_CMD_CMD_NONE;
			WHEN SATA_STREAMC_CMD_RESET =>				Cmd_Command	<= SATA_CMD_CMD_RESET;
			WHEN SATA_STREAMC_CMD_READ =>					Cmd_Command	<= SATA_CMD_CMD_READ;
			WHEN SATA_STREAMC_CMD_WRITE =>				Cmd_Command	<= SATA_CMD_CMD_WRITE;
			WHEN SATA_STREAMC_CMD_FLUSH_CACHE =>	Cmd_Command	<= SATA_CMD_CMD_FLUSH_CACHE;
			WHEN OTHERS =>												Cmd_Command	<= SATA_CMD_CMD_NONE;
		END CASE;
	END PROCESS;

	-- assign status record
	Status.CommandLayer				<= Cmd_Status;
	Status.TransportLayer			<= Trans_Status;
	
	-- assign error record
	Error.Commandlayer				<= Cmd_Error;
	Error.TransportLayer			<= Trans_Error;
	
	-- CommandLayer
	-- ==========================================================================================================================================================
	Cmd : ENTITY PoC.sata_CommandLayer
		GENERIC MAP (
			SIM_EXECUTE_IDENTIFY_DEVICE	=> SIM_EXECUTE_IDENTIFY_DEVICE,				-- required by CommandLayer: load device parameters
			DEBUG												=> DEBUG,										-- generate ChipScope DBG_* signals
			ENABLE_DEBUGPORT						=> ENABLE_DEBUGPORT,
			TX_FIFO_DEPTH								=> TX_FIFO_DEPTH,
			RX_FIFO_DEPTH								=> RX_FIFO_DEPTH,
			LOGICAL_BLOCK_SIZE_ldB			=> LOGICAL_BLOCK_SIZE_ldB
		)
		PORT MAP (
			Clock												=> Clock,
			Reset												=> Reset,

			-- for measurement purposes only
			Config_BurstSize						=> Config_BurstSize,

			-- CommandLayer interface
			Command											=> Cmd_Command,
			Status											=> Cmd_Status,
			Error												=> Cmd_Error,
		
			DebugPortOut								=> DebugPortOut.Commandlayer,
		
			Address_AppLB								=> Address_AppLB,
			BlockCount_AppLB						=> BlockCount_AppLB,
			DriveInformation						=> Cmd_DriveInformation,
		
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
			Trans_ResetDone 						=> Trans_ResetDone,
			Trans_Command								=> Trans_Command,
			Trans_Status								=> Trans_Status,
			Trans_Error									=> Trans_Error,

			-- ATARegister interface
			Trans_UpdateATAHostRegisters	=> Cmd_UpdateATAHostRegisters,
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
			Trans_RX_Commit							=> RX_Glue_Commit,
			Trans_RX_Rollback						=> RX_Glue_Rollback,
			Trans_RX_Ack								=> Cmd_RX_Ack	
		);
	
	RX_Data		<= RX_Data_i;
	RX_SOR		<= RX_SOR_i;
	RX_EOR		<= RX_EOR_i;
	RX_Valid	<= RX_Valid_i;

	RX_Glue : BLOCK IS
		SIGNAL FIFO_Reset		: STD_LOGIC;
		SIGNAL FIFO_Full		: STD_LOGIC;
		SIGNAL FIFO_DataOut	: STD_LOGIC_VECTOR(34 DOWNTO 0);
		SIGNAL FIFO_DataIn	: STD_LOGIC_VECTOR(34 DOWNTO 0);
		
	BEGIN
		RX_FIFO : ENTITY PoC.fifo_glue
			GENERIC MAP ( 
				D_BITS => 35
			)
			PORT MAP (
				clk => Clock,
				rst => FIFO_Reset,
				
				di 	=> FIFO_DataIn,
				ful => FIFO_Full,
				put => Trans_RX_Valid,
				
				do 	=> FIFO_DataOut,
				vld => RX_Glue_Valid,
				got => Cmd_RX_Ack	
			);

		FIFO_DataIn 			<= (Trans_RX_Commit & Trans_RX_SOT & Trans_RX_EOT & Trans_RX_Data);
		FIFO_Reset 				<= Trans_RX_Rollback or Reset;
		RX_Glue_Ack	 		<= not FIFO_Full;
		RX_Glue_Rollback 	<= Trans_RX_Rollback when rising_edge(Clock);
		RX_Glue_Data 			<= FIFO_DataOut(31 downto 0);
		-- ensure convertion from data signal to control signal
		RX_Glue_Commit 		<= FIFO_DataOut(34) AND RX_Glue_Valid; 			
		RX_Glue_SOT 			<= FIFO_DataOut(33);
		RX_Glue_EOT 			<= FIFO_DataOut(32);
	END BLOCK;

	TX_Glue : BLOCK
		SIGNAL FIFO_Full		: STD_LOGIC;
		SIGNAL FIFO_DataOut	: STD_LOGIC_VECTOR(33 DOWNTO 0);
		SIGNAL FIFO_DataIn	: STD_LOGIC_VECTOR(33 DOWNTO 0);
		
	BEGIN
		TX_FIFO : ENTITY PoC.fifo_glue
			GENERIC MAP ( 
				D_BITS => 34
			)
			PORT MAP (
				clk => Clock,
				rst => Reset,
				
				di 	=> FIFO_DataIn,
				ful => FIFO_Full,
				put => Cmd_TX_Valid,
				
				do 	=> FIFO_DataOut,
				vld => TX_Glue_Valid, 
				got => Trans_TX_Ack	
			);

		FIFO_DataIn 	<= (Cmd_TX_SOT & Cmd_TX_EOT & Cmd_TX_Data);
		TX_Glue_Ack	 <= not FIFO_Full;
		TX_Glue_Data	<= FIFO_DataOut(31 downto 0);
		TX_Glue_SOT		<= FIFO_DataOut(33);
		TX_Glue_EOT		<= FIFO_DataOut(32);
	END BLOCK;

-- TransportLayer
	-- ==========================================================================================================================================================
	Trans : ENTITY PoC.sata_TransportLayer
    GENERIC MAP (
			DEBUG														=> DEBUG,
			ENABLE_DEBUGPORT								=> ENABLE_DEBUGPORT,
      SIM_WAIT_FOR_INITIAL_REGDH_FIS  => SIM_WAIT_FOR_INITIAL_REGDH_FIS
    )
		PORT MAP (
			Clock												=> Clock,
			Reset												=> Reset,

			-- TransportLayer interface
			Command											=> Trans_Command,
			Status											=> Trans_Status,
			Error												=> Trans_Error,
		
			DebugPortOut								=> DebugPortOut.TransportLayer,
		
			-- ATA registers
			UpdateATAHostRegisters			=> Cmd_UpdateATAHostRegisters,
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
			RX_Commit										=> Trans_RX_Commit,
			RX_Rollback									=> Trans_RX_Rollback,
			RX_Ack											=> RX_Glue_Ack,
			
			-- LinkLayer interface
			Link_ResetDone 							=> SATA_ResetDone, -- input from lower layer
--			Link_Command								=> SATA_Command,
			Link_Status									=> SATA_Status,
--			Link_Error									=> SATA_Error,
			
			-- TX path
			Link_TX_Ack									=> SATA_TX_Ack,
			Link_TX_Data								=> SATA_TX_Data_i,
			Link_TX_SOF									=> SATA_TX_SOF_i,
			Link_TX_EOF									=> SATA_TX_EOF_i,
			Link_TX_Valid								=> SATA_TX_Valid_i,
			Link_TX_InsertEOF						=> SATA_TX_InsertEOF,															-- helper signal: insert EOF - max frame size reached
				
			Link_TX_FS_Ack							=> SATA_TX_FS_Ack,
			Link_TX_FS_SendOK						=> SATA_TX_FS_SendOK,
			Link_TX_FS_Abort						=> SATA_TX_FS_Abort,
			Link_TX_FS_Valid						=> SATA_TX_FS_Valid,
		
			-- RX path
			Link_RX_Ack									=> SATA_RX_Ack,
			Link_RX_Data								=> SATA_RX_Data,
			Link_RX_SOF									=> SATA_RX_SOF,
			Link_RX_EOF									=> SATA_RX_EOF,
			Link_RX_Valid								=> SATA_RX_Valid,
				
			Link_RX_FS_Ack							=> SATA_RX_FS_Ack,
			Link_RX_FS_CRCOK						=> SATA_RX_FS_CRCOK,
			Link_RX_FS_Abort						=> SATA_RX_FS_Abort,
			Link_RX_FS_Valid						=> SATA_RX_FS_Valid
		);
	
	SATA_TX_Data				<= SATA_TX_Data_i;
	SATA_TX_SOF					<= SATA_TX_SOF_i;
	SATA_TX_EOF					<= SATA_TX_EOF_i;
	SATA_TX_Valid				<= SATA_TX_Valid_i;

	-- The interface of the Transportlayer is ready, when the interface of the
	-- LinkLayer is ready.
	Trans_ResetDone 		<= SATA_ResetDone;
	
	-- DebugPort
	-- ==========================================================================================================================================================
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
	begin
		DebugPortOut.Command_Command <= Cmd_Command;
		DebugPortOut.Command_Status  <= Cmd_Status;
		DebugPortOut.Command_Error   <= Cmd_Error;

		DebugPortOut.Transport_Command <= Trans_Command;
		DebugPortOut.Transport_Status  <=	Trans_Status;
		DebugPortOut.Transport_Error   <=	Trans_Error;
	end generate;
END;
