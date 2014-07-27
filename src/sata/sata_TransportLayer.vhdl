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
USE			PoC.sata.ALL;


ENTITY sata_TransportLayer IS
  GENERIC (
		DEBUG														: BOOLEAN											:= FALSE;					-- generate ChipScope DBG_* signals
		SIM_WAIT_FOR_INITIAL_REGDH_FIS	: BOOLEAN											:= TRUE						-- required by ATA/SATA standard
  );
	PORT (
		Clock														: IN	STD_LOGIC;
		Reset														: IN	STD_LOGIC;

		-- TransportLayer interface
		Command													: IN	T_SATA_TRANS_COMMAND;
		Status													: OUT	T_SATA_TRANS_STATUS;
		Error														: OUT	T_SATA_TRANS_ERROR;	
	
--		DebugPort												: OUT T_DBG_TRANSPORT_OUT;
	
		-- ATA registers
		UpdateATAHostRegisters					: IN	STD_LOGIC;
		ATAHostRegisters								: IN	T_SATA_ATA_HOST_REGISTERS;
		ATADeviceRegisters							: OUT	T_SATA_ATA_DEVICE_REGISTERS;
	
		-- TX path
		TX_Ready											: OUT	STD_LOGIC;
		TX_SOT												: IN	STD_LOGIC;
		TX_EOT												: IN	STD_LOGIC;
		TX_Data												: IN	T_SLV_32;
		TX_Valid											: IN	STD_LOGIC;
	
		-- RX path
		RX_Ready											: IN	STD_LOGIC;
		RX_SOT												: OUT STD_LOGIC;
		RX_EOT												: OUT STD_LOGIC;
		RX_Data												: OUT	T_SLV_32;
		RX_Valid											: OUT	STD_LOGIC;
		RX_Commit											: OUT	STD_LOGIC;
		RX_Rollback										: OUT	STD_LOGIC;
	
		-- LinkLayer interface
		Link_Command									: OUT	T_SATA_COMMAND;
		Link_Status										: IN	T_SATA_STATUS;
		Link_Error										: IN	T_SATA_ERROR;
		
		-- TX path
		Link_TX_Ready									: IN	STD_LOGIC;
		Link_TX_Data									: OUT	T_SLV_32;
		Link_TX_SOF										: OUT	STD_LOGIC;
		Link_TX_EOF										: OUT	STD_LOGIC;
		Link_TX_Valid									: OUT	STD_LOGIC;
		Link_TX_InsertEOF							: IN	STD_LOGIC;															-- helper signal: insert EOF - max frame size reached
			
		Link_TX_FS_Ready							: OUT	STD_LOGIC;
		Link_TX_FS_SendOK							: IN	STD_LOGIC;
		Link_TX_FS_Abort							: IN	STD_LOGIC;
		Link_TX_FS_Valid							: IN	STD_LOGIC;
	
		-- RX path
		Link_RX_Ready									: OUT	STD_LOGIC;
		Link_RX_Data									: IN	T_SLV_32;
		Link_RX_SOF										: IN	STD_LOGIC;
		Link_RX_EOF										: IN	STD_LOGIC;
		Link_RX_Valid									: IN	STD_LOGIC;
			
		Link_RX_FS_Ready							: OUT	STD_LOGIC;
		Link_RX_FS_CRCOK							: IN	STD_LOGIC;
		Link_RX_FS_Abort							: IN	STD_LOGIC;
		Link_RX_FS_Valid							: IN	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF sata_TransportLayer IS
	ATTRIBUTE KEEP														: BOOLEAN;

	SIGNAL ATAHostRegisters_i									: T_SATA_ATA_HOST_REGISTERS;
	SIGNAL ATAHostRegisters_d									: T_SATA_ATA_HOST_REGISTERS;

	SIGNAL UpdateATADeviceRegisters						: STD_LOGIC;
	SIGNAL CopyATADeviceRegisterStatus				: STD_LOGIC;
	SIGNAL ATADeviceRegisters_i								: T_SATA_ATA_DEVICE_REGISTERS;
	SIGNAL ATADeviceRegisters_d								: T_SATA_ATA_DEVICE_REGISTERS;

	-- TransportFSM
	SIGNAL Status_i														: T_SATA_TRANS_STATUS;
	SIGNAL Error_i														: T_SATA_TRANS_ERROR;

	SIGNAL TFSM_FISType												: T_SATA_FISTYPE;
	SIGNAL TFSM_TX_en													: STD_LOGIC;
	SIGNAL TFSM_TX_SOP												: STD_LOGIC;
	SIGNAL TFSM_TX_EOP												: STD_LOGIC;
	SIGNAL TFSM_RX_LastWord										: STD_LOGIC;
	SIGNAL TFSM_RX_SOT												: STD_LOGIC;
	SIGNAL TFSM_RX_EOT												: STD_LOGIC;

	-- TX path (transport cut)
	SIGNAL TC_TX_SOP													: STD_LOGIC;
	SIGNAL TC_TX_EOP													: STD_LOGIC;
	SIGNAL TC_TX_Data													: T_SLV_32;
	SIGNAL TC_TX_Valid												: STD_LOGIC;
	SIGNAL TC_TX_Ready												: STD_LOGIC;
	SIGNAl TC_TX_LastWord											: STD_LOGIC;

	-- RX_Registers
	SIGNAL RXReg_Ready												: STD_LOGIC;

	-- FISEncoder
	SIGNAL FISE_Reset													: STD_LOGIC;
	SIGNAL FISE_Status												: T_SATA_FISENCODER_STATUS;
	SIGNAL FISE_TX_Ready											: STD_LOGIC;
	SIGNAL FISE_TX_InsertEOP									: STD_LOGIC;
	
	-- FISDecoder
	SIGNAL FISD_Reset													: STD_LOGIC;
	SIGNAL FISD_Status												: T_SATA_FISDECODER_STATUS;
	SIGNAL FISD_FISType												: T_SATA_FISTYPE;
	SIGNAL FISD_RX_Data												: T_SLV_32;
	SIGNAL FISD_RX_SOP												: STD_LOGIC;
	SIGNAL FISD_RX_EOP												: STD_LOGIC;
	SIGNAL FISD_RX_Valid											: STD_LOGIC;
	SIGNAL FISD_RX_Commit											: STD_LOGIC;
	SIGNAL FISD_RX_Rollback										: STD_LOGIC;
	SIGNAL FISD_ATADeviceRegisters						: T_SATA_ATA_DEVICE_REGISTERS;

BEGIN
	FISE_Reset		<= Reset OR to_sl(Command = SATA_TRANS_CMD_RESET);
	FISD_Reset		<= Reset OR to_sl(Command = SATA_TRANS_CMD_RESET);

	-- ================================================================
	-- TransportLayer FSM
	-- ================================================================
	TFSM : ENTITY PoC.sata_TransportFSM
    GENERIC MAP (
			DEBUG															=> DEBUG					,
      SIM_WAIT_FOR_INITIAL_REGDH_FIS    => SIM_WAIT_FOR_INITIAL_REGDH_FIS
    )
		PORT MAP (
			Clock															=> Clock,
			Reset															=> Reset,

			-- TransportLayer interface
			Command														=> Command,
			Status														=> Status_i,
			Error															=> Error_i,
			
			-- linkLayer interface
			Link_Command											=> Link_Command,
			Link_Status												=> Link_Status,
			Link_Error												=> Link_Error,

      CopyATADeviceRegisterStatus       => CopyATADeviceRegisterStatus,
			ATAHostRegisters									=> ATAHostRegisters_i,
			ATADeviceRegisters								=> ATADeviceRegisters_i,
			
			TX_en															=> TFSM_TX_en,
			--TODO: TX_LastWord												=> TC_TX_LastWord,
			TX_SOT														=> TX_SOT,
			TX_EOT														=> TX_EOT,
			
			RX_LastWord												=> TFSM_RX_LastWord,
			RX_SOT														=> TFSM_RX_SOT,
			RX_EOT														=> TFSM_RX_EOT,
			
			-- FISDecoder interface
			FISD_FISType											=> FISD_FISType,
			FISD_Status												=> FISD_Status,
			FISD_SOP													=> FISD_RX_SOP,
			FISD_EOP													=> FISD_RX_EOP,
			
			-- FISEncoder interface
			FISE_FISType											=> TFSM_FISType,
			FISE_Status												=> FISE_Status,
			FISE_SOP													=> TFSM_TX_SOP,
			FISE_EOP													=> TFSM_TX_EOP
		);

	Status	<= Status_i;
	Error		<= Error_i;

	-- ==========================================================================================================================================================
	-- ATA registers
	-- ==========================================================================================================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset = '1') OR (Command = SATA_TRANS_CMD_RESET)) THEN
				ATAHostRegisters_d.Flag_C								<= '0';												-- set C flag => access Command register on device
				ATAHostRegisters_d.Command							<= (OTHERS => '0');						-- Command register
				ATAHostRegisters_d.Control							<= (OTHERS => '0');						-- Control register
				ATAHostRegisters_d.Feature							<= (OTHERS => '0');						-- Feature register
				ATAHostRegisters_d.LBlockAddress				<= (OTHERS => '0');						-- logical block address (LBA)
				ATAHostRegisters_d.SectorCount					<= (OTHERS => '0');						-- 
				
--				ATAHostRegisters_d											<= (Flag_C => '0', OTHERS => (OTHERS => '0'));
				
				ATADeviceRegisters_d.Flags							<= (OTHERS => '0');						-- 
				ATADeviceRegisters_d.Status							<= (OTHERS => '0');						-- 
				ATADeviceRegisters_d.EndStatus					<= (OTHERS => '0');						-- 
				ATADeviceRegisters_d.Error							<= (OTHERS => '0');						-- 
				ATADeviceRegisters_d.LBlockAddress			<= (OTHERS => '0');						-- 
				ATADeviceRegisters_d.SectorCount				<= (OTHERS => '0');						-- 
				ATADeviceRegisters_d.TransferCount			<= (OTHERS => '0');						-- 
			ELSE
				IF (UpdateATAHostRegisters = '1') THEN
					ATAHostRegisters_d										<= ATAHostRegisters;
				END IF;
				
				IF (UpdateATADeviceRegisters = '1') THEN
					ATADeviceRegisters_d									<= FISD_ATADeviceRegisters;
				END IF;
				
				IF (CopyATADeviceRegisterStatus = '1') THEN
					ATADeviceRegisters_d.Status						<= ATADeviceRegisters_d.EndStatus;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	-- assign internal signals
	ATAHostRegisters_i		<= ATAHostRegisters_d;
	ATADeviceRegisters_i	<= ATADeviceRegisters_d;

	-- assign output signals
	ATADeviceRegisters	<= ATADeviceRegisters_i;
  
	
	-- TX FrameCutter logic
	-- ==========================================================================================================================================================
	FrameCutter : BLOCK
		SIGNAL TC_TX_DataFlow								: STD_LOGIC;
		
		SIGNAL InsertEOP_d									: STD_LOGIC						:= '0';
		SIGNAL InsertEOP_re									: STD_LOGIC;
		SIGNAL InsertEOP_re_d								: STD_LOGIC						:= '0';
		SIGNAL InsertEOP_re_d2							: STD_LOGIC						:= '0';
		
	BEGIN
		-- enable TX data path
		TC_TX_Valid					<= TX_Valid				AND TFSM_TX_en;
		TC_TX_Ready					<= FISE_TX_Ready	AND TFSM_TX_en;

		TC_TX_DataFlow			<= TC_TX_Valid		AND TC_TX_Ready;

		InsertEOP_d					<= FISE_TX_InsertEOP	WHEN rising_edge(Clock) AND (TC_TX_DataFlow = '1');
		InsertEOP_re				<= FISE_TX_InsertEOP	AND NOT InsertEOP_d;
		InsertEOP_re_d			<= InsertEOP_re				WHEN rising_edge(Clock) AND (TC_TX_DataFlow = '1');
		InsertEOP_re_d2			<= InsertEOP_re_d			WHEN rising_edge(Clock) AND (TC_TX_DataFlow = '1');

		TC_TX_SOP						<= TX_SOT OR InsertEOP_re_d2;
		TC_TX_EOP						<= TX_EOT	OR InsertEOP_re_d;
		TC_TX_Data					<= TX_Data;

		TX_Ready						<= TC_TX_Ready;
	END BLOCK;	-- TransferCutter


	-- RX registers
	-- ==========================================================================================================================================================
	RXReg : BLOCK
		SIGNAL RXReg_mux_set										: STD_LOGIC;
		SIGNAL RXReg_mux_rst										: STD_LOGIC;
		SIGNAL RXReg_mux_r											: STD_LOGIC												:= '0';
		SIGNAL RXReg_mux												: STD_LOGIC;
		SIGNAL RXReg_Data_en										: STD_LOGIC;
		SIGNAL RXReg_Data_d											: T_SLV_32												:= (OTHERS => '0');	
		SIGNAL RXReg_EOT_r											: STD_LOGIC												:= '0';
		SIGNAL RXReg_Commit_r										: STD_LOGIC												:= '0';
		SIGNAL RXReg_Rollback_r									: STD_LOGIC												:= '0';
	
		SIGNAL RXReg_LastWord										: STD_LOGIC;
		SIGNAL RXReg_LastWord_r									: STD_LOGIC												:= '0';
		SIGNAL RXReg_LastWordCommit							: STD_LOGIC;
		
		SIGNAL RXReg_SOT												: STD_LOGIC;
		SIGNAL RXReg_EOT												: STD_LOGIC;
		SIGNAL RXReg_Commit											: STD_LOGIC;
		SIGNAL RXReg_Rollback										: STD_LOGIC;
	BEGIN

		RXReg_Data_en					<= FISD_RX_Valid AND FISD_RX_EOP;
		RXReg_mux_set					<= FISD_RX_Valid AND FISD_RX_EOP;
		RXReg_mux_rst					<= RXReg_LastWordCommit; --RXReg_mux AND RXReg_LastWordCommit;
		
		RX_Data								<= FISD_RX_Data WHEN (RXReg_mux = '0') ELSE RXReg_Data_d;
		RX_Valid							<= (FISD_RX_Valid AND NOT RXReg_Data_en) OR RXReg_LastWord;

		RXReg_Ready						<= (RX_Ready OR RXReg_Data_en) AND NOT RXReg_mux;
		RXReg_LastWordCommit	<= RXReg_LastWord AND RX_Ready;

		RXReg_SOT							<= TFSM_RX_SOT;
		RXReg_EOT							<= RXReg_EOT_r				OR TFSM_RX_EOT;
		RXReg_LastWord				<= RXReg_LastWord_r 	OR TFSM_RX_LastWord;
		RXReg_mux							<= RXReg_mux_r;
		RXReg_Commit					<= RXReg_Commit_r			OR FISD_RX_Commit;
		RXReg_Rollback				<= RXReg_Rollback_r		OR FISD_RX_Rollback;

		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF ((Reset = '1') OR (Command = SATA_TRANS_CMD_RESET)) THEN
					RXReg_Data_d				<= (OTHERS => '0');
					RXReg_mux_r					<= '0';
					RXReg_EOT_r					<= '0';
					RXReg_Commit_r			<= '0';
					RXReg_Rollback_r		<= '0';
				ELSE
					IF (RXReg_Data_en = '1') THEN
						RXReg_Data_d			<= FISD_RX_Data;
					END IF;
				
					IF (RXReg_mux_rst = '1') THEN
						RXReg_mux_r				<= '0';
					ELSIF (RXReg_mux_set = '1') THEN
						RXReg_mux_r				<= '1';
					END IF;

					IF (RXReg_mux_rst = '1') THEN
						RXReg_LastWord_r	<= '0';
					ELSIF (TFSM_RX_LastWord = '1') THEN
						RXReg_LastWord_r	<= '1';
					END IF;				
					
					IF (RXReg_mux_rst = '1') THEN
						RXReg_EOT_r		<= '0';
					ELSIF (TFSM_RX_EOT = '1') THEN
						RXReg_EOT_r		<= '1';
					END IF;
					
					IF (RXReg_mux_rst = '1') THEN
						RXReg_Commit_r		<= '0';
					ELSIF (FISD_RX_Commit = '1') THEN
						RXReg_Commit_r		<= '1';
					END IF;
					
					IF (RXReg_mux_rst = '1') THEN
						RXReg_Rollback_r		<= '0';
					ELSIF (FISD_RX_Rollback = '1') THEN
						RXReg_Rollback_r		<= '1';
					END IF;
				END IF;
			END IF;
		END PROCESS;

		RX_SOT								<= RXReg_SOT;
		RX_EOT								<= RXReg_EOT;
		RX_Commit							<= RXReg_Commit;
		RX_Rollback						<= RXReg_Rollback;
		
--		DebugPort.SOT					<= RXReg_SOT;
--		DebugPort.EOT					<= RXReg_EOT;
	END BLOCK;


	FISE : ENTITY PoC.sata_FISEncoder
		GENERIC MAP (
			DEBUG												=> DEBUG					
		)
		PORT MAP (
			Clock												=> Clock,
			Reset												=> FISE_Reset,

			-- FISEncoder interface
			Status											=> FISE_Status,
			FISType											=> TFSM_FISType,
			
			ATARegisters								=> ATAHostRegisters_i,
			
			-- TransportLayer TX_FIFO interface
			TX_Ready										=> FISE_TX_Ready,
			TX_SOP											=> TC_TX_SOP,
			TX_EOP											=> TC_TX_EOP,
			TX_Data											=> TC_TX_Data,
			TX_Valid										=> TC_TX_Valid,
			TX_InsertEOP								=> FISE_TX_InsertEOP,
			
			-- LinkLayer FIFO interface
			Link_TX_Ready								=> Link_TX_Ready,
			Link_TX_SOF									=> Link_TX_SOF,
			Link_TX_EOF									=> Link_TX_EOF,
			Link_TX_Data								=> Link_TX_Data,
			Link_TX_Valid								=> Link_TX_Valid,
			Link_TX_InsertEOF						=> Link_TX_InsertEOF,
			
			-- LinkLayer FS-FIFO interface
			Link_TX_FS_Valid						=> Link_TX_FS_Valid,
			Link_TX_FS_Ready						=> Link_TX_FS_Ready,
			Link_TX_FS_SendOK						=> Link_TX_FS_SendOK,
			Link_TX_FS_Abort						=> Link_TX_FS_Abort
		);

	-- ================================================================
	-- RX path
	-- ================================================================
	FISD : ENTITY PoC.sata_FISDecoder
		GENERIC MAP (
			DEBUG												=> DEBUG					
		)
		PORT MAP (
			Clock												=> Clock,
			Reset												=> FISD_Reset,
			
			Status											=> FISD_Status,
			FISType											=> FISD_FISType,
			
			UpdateATARegisters					=> UpdateATADeviceRegisters,
			ATADeviceRegisters					=> FISD_ATADeviceRegisters,
			
			-- TransportLayer FIFO interface
			RX_Commit										=> FISD_RX_Commit,
			RX_Rollback									=> FISD_RX_Rollback,
			
			RX_Valid										=> FISD_RX_Valid,
			RX_Data											=> FISD_RX_Data,
			RX_SOP											=> FISD_RX_SOP,
			RX_EOP											=> FISD_RX_EOP,
			RX_Ready										=> RXReg_Ready,
			
			-- LinkLayer FIFO interface
			Link_RX_Ready								=> Link_RX_Ready,
			Link_RX_Data								=> Link_RX_Data,
			Link_RX_SOF									=> Link_RX_SOF,
			Link_RX_EOF									=> Link_RX_EOF,
			Link_RX_Valid								=> Link_RX_Valid,
			
			-- LinkLayer FS-FIFO interface
			Link_RX_FS_Ready						=> Link_RX_FS_Ready,
			Link_RX_FS_CRCOK						=> Link_RX_FS_CRCOK,
			Link_RX_FS_Abort						=> Link_RX_FS_Abort,
			Link_RX_FS_Valid						=> Link_RX_FS_Valid
		);
	
	-- debug ports
	-- ==========================================================================================================================================================
--	DebugPort.Command											<= Command;
--	DebugPort.Status											<= Status_i;
--	DebugPort.Error												<= Error_i;
--		
--	DebugPort.UpdateATAHostRegisters			<= UpdateATAHostRegisters;
--	DebugPort.ATAHostRegisters						<= ATAHostRegisters_i;
--	DebugPort.UpdateATADeviceRegisters		<= UpdateATADeviceRegisters;
--	DebugPort.ATADeviceRegisters					<= ATADeviceRegisters_i;
--		
--	DebugPort.FISE_FISType								<= TFSM_FISType;
--	DebugPort.FISE_Status									<= FISE_Status;
--	DebugPort.FISD_FISType								<= FISD_FISType;
--	DebugPort.FISD_Status									<= FISD_Status;
--		
--	DebugPort.SOF													<= Link_RX_SOF;
--	DebugPort.EOF													<= Link_RX_EOF;
	
	-- ChipScope
	-- ==========================================================================================================================================================
	genCSP : IF (DEBUG = TRUE) GENERATE
		SIGNAL DBG_UpdateATAHostRegisters							: STD_LOGIC;
		SIGNAL DBG_ATAHostRegisters										: T_SATA_ATA_HOST_REGISTERS;
		SIGNAL DBG_ATADeviceRegisters									: T_SATA_ATA_DEVICE_REGISTERS;
		SIGNAL DBG_FISD_Error													: STD_LOGIC;
		
		ATTRIBUTE KEEP OF DBG_UpdateATAHostRegisters	: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_ATAHostRegisters				: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_ATADeviceRegisters			: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_FISD_Error							: SIGNAL IS TRUE;
	BEGIN
		DBG_UpdateATAHostRegisters	<= UpdateATAHostRegisters;
		DBG_ATAHostRegisters				<= ATAHostRegisters_d;
		DBG_ATADeviceRegisters			<= ATADeviceRegisters_d;

		DBG_FISD_Error							<= to_sl(FISD_Status = SATA_FISD_STATUS_CRC_ERROR);
	END GENERATE;
END;
