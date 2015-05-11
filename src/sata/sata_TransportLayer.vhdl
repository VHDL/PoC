-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
--
-- Package:					TODO
--
-- Description:
-- ------------------------------------
-- Provides transport of frames via SATA links for the Host endpoint.
--
-- Automatically awaits a Register Frame after the link has been established.
-- To initiate a new connection (later on), synchronously reset this layer and
-- the underlying SATAController at the same time.
--
-- Clock might be instable in two conditions:
-- a) Reset is asserted, e.g., wenn ResetDone of SATAController is not asserted
-- 	  yet.
-- b) After power-up or reset: Phy_Status is constant and not equal to
-- 	  SATA_PHY_STATUS_LINK_OK. After SATA_PHY_STATUS_LINK_OK was signaled,
-- 	  reset must be asserted before the clock might be instable again.
--
-- If these conditions are met, then Status will be constant and equal to
-- SATA_TRANS_STATUS_RESET during an unstable clock, especially in case b).
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
use			PoC.strings.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_TransportLayer is
  generic (
		DEBUG														: BOOLEAN						:= FALSE;					-- generate ChipScope DBG_* signals
		ENABLE_DEBUGPORT								: BOOLEAN						:= FALSE;
		SIM_WAIT_FOR_INITIAL_REGDH_FIS	: BOOLEAN						:= TRUE						-- required by ATA/SATA standard
  );
	port (
		Clock														: IN	STD_LOGIC;
		Reset														: IN	STD_LOGIC;

		-- TransportLayer interface
		Command													: IN	T_SATA_TRANS_COMMAND;
		Status													: OUT	T_SATA_TRANS_STATUS;
		Error														: OUT	T_SATA_TRANS_ERROR;	
	
		DebugPortOut										: OUT T_SATADBG_TRANS_OUT;
	
		-- ATA registers
		UpdateATAHostRegisters					: IN	STD_LOGIC;
		ATAHostRegisters								: IN	T_SATA_ATA_HOST_REGISTERS;
		ATADeviceRegisters							: OUT	T_SATA_ATA_DEVICE_REGISTERS;
	
		-- TX path
		TX_Ack												: OUT	STD_LOGIC;
		TX_SOT												: IN	STD_LOGIC;
		TX_EOT												: IN	STD_LOGIC;
		TX_Data												: IN	T_SLV_32;
		TX_Valid											: IN	STD_LOGIC;
	
		-- RX path
		RX_Ack												: IN	STD_LOGIC;
		RX_SOT												: OUT STD_LOGIC;
		RX_EOT												: OUT STD_LOGIC;
		RX_Data												: OUT	T_SLV_32;
		RX_Valid											: OUT	STD_LOGIC;
		RX_Commit											: OUT	STD_LOGIC;
		RX_Rollback										: OUT	STD_LOGIC;
	
		-- SATAController Status
		Phy_Status										: IN	T_SATA_PHY_STATUS;
		
		-- TX path
		Link_TX_Ack										: IN	STD_LOGIC;
		Link_TX_Data									: OUT	T_SLV_32;
		Link_TX_SOF										: OUT	STD_LOGIC;
		Link_TX_EOF										: OUT	STD_LOGIC;
		Link_TX_Valid									: OUT	STD_LOGIC;
		Link_TX_InsertEOF							: IN	STD_LOGIC;															-- helper signal: insert EOF - max frame size reached
			
		Link_TX_FS_Ack								: OUT	STD_LOGIC;
		Link_TX_FS_SendOK							: IN	STD_LOGIC;
		Link_TX_FS_Abort							: IN	STD_LOGIC;
		Link_TX_FS_Valid							: IN	STD_LOGIC;
	
		-- RX path
		Link_RX_Ack										: OUT	STD_LOGIC;
		Link_RX_Data									: IN	T_SLV_32;
		Link_RX_SOF										: IN	STD_LOGIC;
		Link_RX_EOF										: IN	STD_LOGIC;
		Link_RX_Valid									: IN	STD_LOGIC;
			
		Link_RX_FS_Ack								: OUT	STD_LOGIC;
		Link_RX_FS_CRCOK							: IN	STD_LOGIC;
		Link_RX_FS_Abort							: IN	STD_LOGIC;
		Link_RX_FS_Valid							: IN	STD_LOGIC
	);
end;

ARCHITECTURE rtl OF sata_TransportLayer IS
	ATTRIBUTE KEEP											: BOOLEAN;

	signal MyReset 											: STD_LOGIC;
	
	signal ATAHostRegisters_i						: T_SATA_ATA_HOST_REGISTERS;
	signal ATAHostRegisters_d						: T_SATA_ATA_HOST_REGISTERS;

	signal UpdateATADeviceRegisters			: STD_LOGIC;
	signal CopyATADeviceRegisterStatus	: STD_LOGIC;
	signal ATADeviceRegisters_i					: T_SATA_ATA_DEVICE_REGISTERS;
	signal ATADeviceRegisters_d					: T_SATA_ATA_DEVICE_REGISTERS;

	-- TransportFSM
	signal Status_i											: T_SATA_TRANS_STATUS;
	signal Error_i											: T_SATA_TRANS_ERROR;

	signal TFSM_FISType									: T_SATA_FISTYPE;
	signal TFSM_TX_en										: STD_LOGIC;
	signal TFSM_TX_SOP									: STD_LOGIC;
	signal TFSM_TX_EOP									: STD_LOGIC;
	signal TFSM_RX_LastWord							: STD_LOGIC;
	signal TFSM_RX_SOT									: STD_LOGIC;
	signal TFSM_RX_EOT									: STD_LOGIC;

	-- TX path (transport cut)
	signal TC_TX_SOP										: STD_LOGIC;
	signal TC_TX_EOP										: STD_LOGIC;
	signal TC_TX_Data										: T_SLV_32;
	signal TC_TX_Valid									: STD_LOGIC;
	signal TC_TX_Ack										: STD_LOGIC;
	signal TC_TX_LastWord								: STD_LOGIC;

	-- RX_Registers
	signal RXReg_Ack										: STD_LOGIC;
	signal RXReg_RX_Valid								: STD_LOGIC;
	signal RXReg_RX_Data								: T_SLV_32;
	signal RXReg_RX_SOT									: STD_LOGIC;
	signal RXReg_RX_EOT									: STD_LOGIC;
	signal RXReg_RX_Commit							: STD_LOGIC;
	signal RXReg_RX_Rollback						: STD_LOGIC;

	-- FISEncoder
	signal FISE_Status									: T_SATA_FISENCODER_STATUS;
	signal FISE_TX_Ack									: STD_LOGIC;
	signal FISE_TX_InsertEOP						: STD_LOGIC;
	signal FISE_Link_TX_Valid						: STD_LOGIC;
	signal FISE_Link_TX_Data						: T_SLV_32;
	signal FISE_Link_TX_SOF							: STD_LOGIC;
	signal FISE_Link_TX_EOF							: STD_LOGIC;
	signal FISE_Link_TX_FS_Ack					: STD_LOGIC;
	
	-- FISDecoder
	signal FISD_Status									: T_SATA_FISDECODER_STATUS;
	signal FISD_FISType									: T_SATA_FISTYPE;
	signal FISD_RX_Data									: T_SLV_32;
	signal FISD_RX_SOP									: STD_LOGIC;
	signal FISD_RX_EOP									: STD_LOGIC;
	signal FISD_RX_Valid								: STD_LOGIC;
	signal FISD_RX_Commit								: STD_LOGIC;
	signal FISD_RX_Rollback							: STD_LOGIC;
	signal FISD_ATADeviceRegisters			: T_SATA_ATA_DEVICE_REGISTERS;
	signal FISD_Link_RX_Ack							: STD_LOGIC;
	signal FISD_Link_RX_FS_Ack					: STD_LOGIC;

	signal TFSM_DebugPortOut						: T_SATADBG_TRANS_TFSM_OUT;
	signal FISE_DebugPortOut						: T_SATADBG_TRANS_FISE_OUT;
	signal FISD_DebugPortOut						: T_SATADBG_TRANS_FISD_OUT;
	
begin
	-- ================================================================
	-- TransportLayer FSM
	-- ================================================================
	TFSM : ENTITY PoC.sata_TransportFSM
    GENERIC MAP (
			DEBUG															=> DEBUG,
			ENABLE_DEBUGPORT									=> ENABLE_DEBUGPORT,
      SIM_WAIT_FOR_INITIAL_REGDH_FIS    => SIM_WAIT_FOR_INITIAL_REGDH_FIS
    )
		PORT MAP (
			Clock															=> Clock,
			Reset															=> Reset,

			-- TransportLayer interface
			Command														=> Command,
			Status														=> Status_i,
			Error															=> Error_i,

			-- DebugPort
			DebugPortOut											=> TFSM_DebugPortOut,
			
			-- ATA
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
			
			-- SATAController Status
			Phy_Status 												=> Phy_Status,

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
			IF (Reset = '1') THEN
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
		signal TC_TX_DataFlow								: STD_LOGIC;
		
		signal InsertEOP_d									: STD_LOGIC						:= '0';
		signal InsertEOP_re									: STD_LOGIC;
		signal InsertEOP_re_d								: STD_LOGIC						:= '0';
		signal InsertEOP_re_d2							: STD_LOGIC						:= '0';
		
	BEGIN
		-- enable TX data path
		TC_TX_Valid					<= TX_Valid				AND TFSM_TX_en;
		TC_TX_Ack						<= FISE_TX_Ack		AND TFSM_TX_en;

		TC_TX_DataFlow			<= TC_TX_Valid		AND TC_TX_Ack;

		InsertEOP_d					<= FISE_TX_InsertEOP	WHEN rising_edge(Clock) AND (TC_TX_DataFlow = '1');
		InsertEOP_re				<= FISE_TX_InsertEOP	AND NOT InsertEOP_d;
		InsertEOP_re_d			<= InsertEOP_re				WHEN rising_edge(Clock) AND (TC_TX_DataFlow = '1');
		InsertEOP_re_d2			<= InsertEOP_re_d			WHEN rising_edge(Clock) AND (TC_TX_DataFlow = '1');

		TC_TX_SOP						<= TX_SOT OR InsertEOP_re_d2;
		TC_TX_EOP						<= TX_EOT	OR InsertEOP_re_d;
		TC_TX_Data					<= TX_Data;

		TX_Ack							<= TC_TX_Ack;
	END BLOCK;	-- TransferCutter


	-- RX registers
	-- ==========================================================================================================================================================
	RXReg : BLOCK
		signal RXReg_mux_set										: STD_LOGIC;
		signal RXReg_mux_rst										: STD_LOGIC;
		signal RXReg_mux_r											: STD_LOGIC												:= '0';
		signal RXReg_mux												: STD_LOGIC;
		signal RXReg_Data_en										: STD_LOGIC;
		signal RXReg_Data_d											: T_SLV_32												:= (OTHERS => '0');	
		signal RXReg_EOT_r											: STD_LOGIC												:= '0';
		signal RXReg_Commit_r										: STD_LOGIC												:= '0';
		signal RXReg_Rollback_r									: STD_LOGIC												:= '0';
	
		signal RXReg_LastWord										: STD_LOGIC;
		signal RXReg_LastWord_r									: STD_LOGIC												:= '0';
		signal RXReg_LastWordCommit							: STD_LOGIC;
		
		signal RXReg_SOT												: STD_LOGIC;
		signal RXReg_EOT												: STD_LOGIC;
		signal RXReg_Commit											: STD_LOGIC;
		signal RXReg_Rollback										: STD_LOGIC;
	BEGIN

		RXReg_Data_en					<= FISD_RX_Valid AND FISD_RX_EOP;
		RXReg_mux_set					<= FISD_RX_Valid AND FISD_RX_EOP;
		RXReg_mux_rst					<= RXReg_LastWordCommit; --RXReg_mux AND RXReg_LastWordCommit;
		
		RXReg_RX_Data					<= FISD_RX_Data WHEN (RXReg_mux = '0') ELSE RXReg_Data_d;
		RXReg_RX_Valid				<= (FISD_RX_Valid AND NOT RXReg_Data_en) OR RXReg_LastWord;

		RXReg_Ack							<= (RX_Ack	 OR RXReg_Data_en) AND NOT RXReg_mux;
		RXReg_LastWordCommit	<= RXReg_LastWord AND RX_Ack;

		RXReg_SOT							<= TFSM_RX_SOT;
		RXReg_EOT							<= RXReg_EOT_r				OR TFSM_RX_EOT;
		RXReg_LastWord				<= RXReg_LastWord_r 	OR TFSM_RX_LastWord;
		RXReg_mux							<= RXReg_mux_r;
		RXReg_Commit					<= RXReg_Commit_r			OR FISD_RX_Commit;
		RXReg_Rollback				<= RXReg_Rollback_r		OR FISD_RX_Rollback;

		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Reset = '1') THEN
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

		RXReg_RX_SOT				<= RXReg_SOT;
		RXReg_RX_EOT				<= RXReg_EOT;
		RXReg_RX_Commit			<= RXReg_Commit;
		RXReg_RX_Rollback		<= RXReg_Rollback;
	END BLOCK;

	RX_Valid			<= RXReg_RX_Valid;
	RX_Data				<= RXReg_RX_Data;
	RX_SOT				<= RXReg_RX_SOT;
	RX_EOT				<= RXReg_RX_EOT;
	RX_Commit			<= RXReg_RX_Commit;
	RX_Rollback		<= RXReg_RX_Rollback;


	FISE : ENTITY PoC.sata_FISEncoder
		GENERIC MAP (
			DEBUG												=> DEBUG		,
			ENABLE_DEBUGPORT						=> ENABLE_DEBUGPORT			
		)
		PORT MAP (
			Clock												=> Clock,
			Reset												=> Reset,

			-- FISEncoder interface
			Status											=> FISE_Status,
			FISType											=> TFSM_FISType,
			
			-- DebugPort
			DebugPortOut								=> FISE_DebugPortOut,
			
			ATARegisters								=> ATAHostRegisters_i,
			
			-- TransportLayer TX_FIFO interface
			TX_Ack											=> FISE_TX_Ack,
			TX_SOP											=> TC_TX_SOP,
			TX_EOP											=> TC_TX_EOP,
			TX_Data											=> TC_TX_Data,
			TX_Valid										=> TC_TX_Valid,
			TX_InsertEOP								=> FISE_TX_InsertEOP,

			-- SATAController Status
			Phy_Status 									=> Phy_Status,
			
			-- LinkLayer FIFO interface
			Link_TX_Valid								=> FISE_Link_TX_Valid,
			Link_TX_Data								=> FISE_Link_TX_Data,
			Link_TX_SOF									=> FISE_Link_TX_SOF,
			Link_TX_EOF									=> FISE_Link_TX_EOF,
			Link_TX_Ack									=> Link_TX_Ack,
			Link_TX_InsertEOF						=> Link_TX_InsertEOF,
			
			-- LinkLayer FS-FIFO interface
			Link_TX_FS_Valid						=> Link_TX_FS_Valid,
			Link_TX_FS_SendOK						=> Link_TX_FS_SendOK,
			Link_TX_FS_Abort						=> Link_TX_FS_Abort,
			Link_TX_FS_Ack							=> FISE_Link_TX_FS_Ack
		);

	-- ================================================================
	-- RX path
	-- ================================================================
	FISD : ENTITY PoC.sata_FISDecoder
		GENERIC MAP (
			DEBUG												=> DEBUG,
			ENABLE_DEBUGPORT						=> ENABLE_DEBUGPORT
		)
		PORT MAP (
			Clock												=> Clock,
			Reset												=> Reset,
			
			Status											=> FISD_Status,
			FISType											=> FISD_FISType,
			
			-- DebugPort
			DebugPortOut								=> FISD_DebugPortOut,
			
			UpdateATARegisters					=> UpdateATADeviceRegisters,
			ATADeviceRegisters					=> FISD_ATADeviceRegisters,
			
			-- TransportLayer FIFO interface
			RX_Commit										=> FISD_RX_Commit,
			RX_Rollback									=> FISD_RX_Rollback,
			
			RX_Valid										=> FISD_RX_Valid,
			RX_Data											=> FISD_RX_Data,
			RX_SOP											=> FISD_RX_SOP,
			RX_EOP											=> FISD_RX_EOP,
			RX_Ack											=> RXReg_Ack,
			
			-- SATAController Status
			Phy_Status 									=> Phy_Status,
			
			-- LinkLayer FIFO interface
			Link_RX_Valid								=> Link_RX_Valid,
			Link_RX_Data								=> Link_RX_Data,
			Link_RX_SOF									=> Link_RX_SOF,
			Link_RX_EOF									=> Link_RX_EOF,
			Link_RX_Ack									=> FISD_Link_RX_Ack,
			-- LinkLayer FS-FIFO interface
			Link_RX_FS_Valid						=> Link_RX_FS_Valid,
			Link_RX_FS_CRCOK						=> Link_RX_FS_CRCOK,
			Link_RX_FS_Abort						=> Link_RX_FS_Abort,
			Link_RX_FS_Ack							=> FISD_Link_RX_FS_Ack
		);
	
	Link_TX_Valid				<= FISE_Link_TX_Valid;
	Link_TX_Data				<= FISE_Link_TX_Data;
	Link_TX_SOF					<= FISE_Link_TX_SOF;
	Link_TX_EOF					<= FISE_Link_TX_EOF;
	Link_TX_FS_Ack			<= FISE_Link_TX_FS_Ack;
	
	Link_RX_Ack					<= FISD_Link_RX_Ack;
	Link_RX_FS_Ack			<= FISD_Link_RX_FS_Ack;
	
	-- debug ports
	-- ==========================================================================================================================================================
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
		DebugPortOut.TFSM												<= TFSM_DebugPortOut;
		DebugPortOut.FISE												<= FISE_DebugPortOut;
		DebugPortOut.FISD												<= FISD_DebugPortOut;
		
		DebugPortOut.UpdateATAHostRegisters			<= UpdateATAHostRegisters;
		DebugPortOut.ATAHostRegisters						<= ATAHostRegisters_i;
		DebugPortOut.UpdateATADeviceRegisters		<= UpdateATADeviceRegisters;
		DebugPortOut.ATADeviceRegisters					<= ATADeviceRegisters_i;
		
		DebugPortOut.TX_Valid										<= TX_Valid;
		DebugPortOut.TX_Data										<= TX_Data;
		DebugPortOut.TX_SOT											<= TX_SOT;
		DebugPortOut.TX_EOT											<= TX_EOT;
		DebugPortOut.TX_Ack											<= TC_TX_Ack;
		
		DebugPortOut.RX_Valid										<= RXReg_RX_Valid;
		DebugPortOut.RX_Data										<= RXReg_RX_Data;
		DebugPortOut.RX_SOT											<= RXReg_RX_SOT;
		DebugPortOut.RX_EOT											<= RXReg_RX_EOT;
		DebugPortOut.RX_Ack											<= RX_Ack;
		DebugPortOut.RX_Commit									<= RXReg_RX_Commit;
		DebugPortOut.RX_Rollback								<= RXReg_RX_Rollback;
		
		-- RXReg?
		
		DebugPortOut.FISE_FISType								<= TFSM_FISType;
		DebugPortOut.FISE_Status								<= FISE_Status;
		
		DebugPortOut.FISD_FISType								<= FISD_FISType;
		DebugPortOut.FISD_Status								<= FISD_Status;
		
		DebugPortOut.Link_TX_Valid							<= FISE_Link_TX_Valid;
		DebugPortOut.Link_TX_Data								<= FISE_Link_TX_Data;
		DebugPortOut.Link_TX_SOF								<= FISE_Link_TX_SOF;
		DebugPortOut.Link_TX_EOF								<= FISE_Link_TX_EOF;
		DebugPortOut.Link_TX_Ack								<= Link_TX_Ack;
		DebugPortOut.Link_TX_FS_Valid						<= Link_TX_FS_Valid;
		DebugPortOut.Link_TX_FS_SendOK					<= Link_TX_FS_SendOK;
		DebugPortOut.Link_TX_FS_Abort						<= Link_TX_FS_Abort;
		DebugPortOut.Link_TX_FS_Ack							<= FISE_Link_TX_FS_Ack;
		
		DebugPortOut.Link_RX_Valid							<= Link_RX_Valid;
		DebugPortOut.Link_RX_Data								<= Link_RX_Data;
		DebugPortOut.Link_RX_SOF								<= Link_RX_SOF;
		DebugPortOut.Link_RX_EOF								<= Link_RX_EOF;
		DebugPortOut.Link_RX_Ack								<= FISD_Link_RX_Ack;
		DebugPortOut.Link_RX_FS_Valid						<= Link_RX_FS_Valid;
		DebugPortOut.Link_RX_FS_CRCOK						<= Link_RX_FS_CRCOK;
		DebugPortOut.Link_RX_FS_Abort						<= Link_RX_FS_Abort;
		DebugPortOut.Link_RX_FS_Ack							<= FISD_Link_RX_FS_Ack;
	end generate;
end;
