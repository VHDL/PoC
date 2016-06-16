-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
--
-- Entity: 					SATA Transport Layer
--
-- Description:
-- -------------------------------------
-- Provides transport of frames via SATA links for the Host endpoint.
--
-- Automatically awaits a Register Frame after the link has been established.
-- To initiate a new connection (later on), synchronously reset this layer and
-- the underlying SATAController at the same time.
--
-- Configuration
-- -------------
-- DEV_INIT_TIMEOUT:  Maximum time to wait for the initial register FIS after
--   the link has been established. During this period, the device boots its
--   firmware and may execute a (short) self diagnostic.
--
-- NODATA_RETRY_TIMEOUT: For ATA commands of category NO-DATA:
--   a) maximum time to transmit register FIS (ATA command) to the device,
--      including necessary retries, as well as
--   b) maximum time to wait for a correct register FIS (ATA command completion
--      status) from the device after it was once corrupted  (e.g. CRC error).
--
--   Note: This timeout does not cover the execution time of the ATA command
--   required by the device (time between a) and b) defined above). This is because
--   the execution time highly depends on the ATA command and drive
--   characteristics. A FLUSH CACHE might complete in some seconds, a (full)
--   DRIVE DIAGNOSTICS may take several minutes.
--
-- DATA_READ_TIMEOUT: Maximum time to wait for a data FIS and the final
--   register FIS from the device during reads (PIO or DMA).
--
-- DATA_WRITE_TIMEOUT: Maximum time to wait until device is ready to receive
--   data as well as maximum time to wait for final register FIS from device
--   during writes (PIO or DMA).
--
-- CSE Interface:
-- --------------
-- New commands are accepted when Status is *_STATUS_IDLE, *_STATUS_TRANSFER_OK
-- or *_STATUS_TRANSFER_ERROR.
-- ATAHostHostRegisters must be applied with command *_CMD_TRANSFER.
--
-- After issuing a command, status means:
-- *_STATUS_TRANSFER_OK:    Transfer completed with no error.
-- *_STATUS_TRANSFER_ERROR: Transfer completed with error bit in ATA register set.
-- *_STATUS_ERROR: 					Fatal error occured. Synchronous reset of whole
-- 													SATA stack must be applied.
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
use 		PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use 		PoC.components.all;
use 		PoC.physical.all;
use 		PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_TransportLayer is
  generic (
		DEV_INIT_TIMEOUT 								: TIME 							:= 1000 ms;
		NODATA_RETRY_TIMEOUT 						: TIME 							:=    1 ms;
		DATA_READ_TIMEOUT 							: TIME 							:= 1000 ms;
		DATA_WRITE_TIMEOUT 							: TIME 							:= 1000 ms;
		DEBUG														: BOOLEAN						:= FALSE;					-- generate ChipScope DBG_* signals
		ENABLE_DEBUGPORT								: BOOLEAN						:= FALSE;
		SIM_WAIT_FOR_INITIAL_REGDH_FIS	: BOOLEAN						:= TRUE						-- required by ATA/SATA standard
  );
	port (
		Clock														: in	STD_LOGIC;
		ClockEnable											: in	STD_LOGIC;
		Reset														: in	STD_LOGIC;

		-- TransportLayer interface
		Command													: in	T_SATA_TRANS_COMMAND;
		Status													: out	T_SATA_TRANS_STATUS;
		Error														: out	T_SATA_TRANS_ERROR;

		DebugPortOut										: out T_SATADBG_TRANS_OUT;

		-- ATA registers
		ATAHostRegisters								: in	T_SATA_ATA_HOST_REGISTERS;
		ATADeviceRegisters							: out	T_SATA_ATA_DEVICE_REGISTERS;

		-- TX path
		TX_Ack												: out	STD_LOGIC;
		TX_SOT												: in	STD_LOGIC;
		TX_EOT												: in	STD_LOGIC;
		TX_Data												: in	T_SLV_32;
		TX_Valid											: in	STD_LOGIC;

		-- RX path
		RX_Ack												: in	STD_LOGIC;
		RX_SOT												: out STD_LOGIC;
		RX_EOT												: out STD_LOGIC;
		RX_Data												: out	T_SLV_32;
		RX_Valid											: out	STD_LOGIC;

		-- SATAController Status
		Link_ResetDone 								: in  STD_LOGIC;
		Link_Command									: out	T_SATA_LINK_COMMAND;
		Link_Status										: in	T_SATA_LINK_STATUS;
		SATAGeneration 								: in 	T_SATA_GENERATION;

		-- TX path
		Link_TX_Ack										: in	STD_LOGIC;
		Link_TX_Data									: out	T_SLV_32;
		Link_TX_SOF										: out	STD_LOGIC;
		Link_TX_EOF										: out	STD_LOGIC;
		Link_TX_Valid									: out	STD_LOGIC;
		Link_TX_InsertEOF							: in	STD_LOGIC;															-- helper signal: insert EOF - max frame size reached

		Link_TX_FS_Ack								: out	STD_LOGIC;
		Link_TX_FS_SendOK							: in	STD_LOGIC;
		Link_TX_FS_SyncEsc 						: in	STD_LOGIC;
		Link_TX_FS_Valid							: in	STD_LOGIC;

		-- RX path
		Link_RX_Ack										: out	STD_LOGIC;
		Link_RX_Data									: in	T_SLV_32;
		Link_RX_SOF										: in	STD_LOGIC;
		Link_RX_EOF										: in	STD_LOGIC;
		Link_RX_Valid									: in	STD_LOGIC;

		Link_RX_FS_Ack								: out	STD_LOGIC;
		Link_RX_FS_CRCOK							: in	STD_LOGIC;
		Link_RX_FS_SyncEsc						: in	STD_LOGIC;
		Link_RX_FS_Valid							: in	STD_LOGIC
	);
end entity;


architecture rtl of sata_TransportLayer is
	attribute KEEP											: BOOLEAN;

	-- my reset
	signal MyReset 											: STD_LOGIC;

	-- ATA register
	signal ATAHostRegisters_r						: T_SATA_ATA_HOST_REGISTERS;

	signal UpdateATAHostRegisters				: STD_LOGIC;
	signal UpdateATADeviceRegisters			: STD_LOGIC;
	signal CopyATADeviceRegisterStatus	: STD_LOGIC;
	signal ATADeviceRegisters_i					: T_SATA_ATA_DEVICE_REGISTERS;
	signal ATADeviceRegisters_r					: T_SATA_ATA_DEVICE_REGISTERS;

	-- TransportFSM
	signal Status_i											: T_SATA_TRANS_STATUS;
	signal Error_i											: T_SATA_TRANS_ERROR;

	signal TFSM_FISType									: T_SATA_FISTYPE;
	signal TFSM_TX_en										: STD_LOGIC;
	signal TFSM_TX_ForceAck							: STD_LOGIC;
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
	signal FISD_ATADeviceRegisters			: T_SATA_ATA_DEVICE_REGISTERS;
	signal FISD_Link_RX_Ack							: STD_LOGIC;
	signal FISD_Link_RX_FS_Ack					: STD_LOGIC;

	signal TFSM_DebugPortOut						: T_SATADBG_TRANS_TFSM_OUT;
	signal FISE_DebugPortOut						: T_SATADBG_TRANS_FISE_OUT;
	signal FISD_DebugPortOut						: T_SATADBG_TRANS_FISD_OUT;

begin
	-- Reset sub-components until initial reset of SATAController has been
	-- completed. Allow synchronous 'Reset' only when ClockEnable = '1'.
	-- ===========================================================================
	MyReset <= (not Link_ResetDone) or (Reset and ClockEnable);

	-- ================================================================
	-- TransportLayer FSM
	-- ================================================================
	TFSM : entity PoC.sata_TransportLayerFSM
    generic map (
			DATA_READ_TIMEOUT 								=> DATA_READ_TIMEOUT,
			DATA_WRITE_TIMEOUT 								=> DATA_WRITE_TIMEOUT,
			DEBUG															=> DEBUG,
			ENABLE_DEBUGPORT									=> ENABLE_DEBUGPORT,
      SIM_WAIT_FOR_INITIAL_REGDH_FIS    => SIM_WAIT_FOR_INITIAL_REGDH_FIS
    )
		port map (
			Clock															=> Clock,
			MyReset														=> MyReset,

			-- TransportLayer interface
			Command														=> Command,
			Status														=> Status_i,
			Error															=> Error_i,

			-- DebugPort
			DebugPortOut											=> TFSM_DebugPortOut,

			-- ATA
      UpdateATAHostRegisters       			=> UpdateATAHostRegisters,
      CopyATADeviceRegisterStatus       => CopyATADeviceRegisterStatus,
			ATAHostRegisters									=> ATAHostRegisters_r,
			ATADeviceRegisters								=> ATADeviceRegisters_i,

			TX_en															=> TFSM_TX_en,
			TX_ForceAck												=> TFSM_TX_ForceAck,
			TX_Valid													=> TX_Valid,
			TX_EOT														=> TX_EOT,

			RX_LastWord												=> TFSM_RX_LastWord,
			RX_SOT														=> TFSM_RX_SOT,
			RX_EOT														=> TFSM_RX_EOT,

			-- SATAController Status
			Link_Status 											=> Link_Status,
			SATAGeneration 										=> SATAGeneration,

			-- FISDecoder interface
			FISD_FISType											=> FISD_FISType,
			FISD_Status												=> FISD_Status,
			FISD_SOP													=> FISD_RX_SOP,
			FISD_EOP													=> FISD_RX_EOP,

			-- FISEncoder interface
			FISE_FISType											=> TFSM_FISType,
			FISE_Status												=> FISE_Status
		);

	Status	<= Status_i;
	Error		<= Error_i;

	TX_Ack					<= TC_TX_Ack or TFSM_TX_ForceAck; -- when editing also update DebugPort

	-- TODO: controlled by TFSM?
	Link_Command		<= SATA_LINK_CMD_NONE;

	-- ===========================================================================
	-- ATA registers
	-- ===========================================================================
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (MyReset = '1') then
				ATAHostRegisters_r.Flag_C								<= '0';												-- set C flag => access Command register on device
				ATAHostRegisters_r.Command							<= (others => '0');						-- Command register
				ATAHostRegisters_r.Control							<= (others => '0');						-- Control register
				ATAHostRegisters_r.Feature							<= (others => '0');						-- Feature register
				ATAHostRegisters_r.LBlockAddress				<= (others => '0');						-- logical block address (LBA)
				ATAHostRegisters_r.SectorCount					<= (others => '0');						--

--				ATAHostRegisters_r											<= (Flag_C => '0', others => (others => '0'));

				ATADeviceRegisters_r.Flags							<= (others => '0');						--
				ATADeviceRegisters_r.Status							<= (others => '0');						--
				ATADeviceRegisters_r.EndStatus					<= (others => '0');						--
				ATADeviceRegisters_r.Error							<= (others => '0');						--
				ATADeviceRegisters_r.LBlockAddress			<= (others => '0');						--
				ATADeviceRegisters_r.SectorCount				<= (others => '0');						--
				ATADeviceRegisters_r.TransferCount			<= (others => '0');						--
			else
				if (UpdateATAHostRegisters = '1') then
					ATAHostRegisters_r										<= ATAHostRegisters;
				end if;

				if (UpdateATADeviceRegisters = '1') then
					ATADeviceRegisters_r									<= FISD_ATADeviceRegisters;
				end if;

				if (CopyATADeviceRegisterStatus = '1') then
					ATADeviceRegisters_r.Status						<= ATADeviceRegisters_r.EndStatus;
				end if;
			end if;
		end if;
	end process;

	-- assign internal signals
	ATADeviceRegisters_i	<= ATADeviceRegisters_r;

	-- assign output signals
	ATADeviceRegisters	<= ATADeviceRegisters_i;


	-- TX FrameCutter logic
	-- ==========================================================================================================================================================
	FrameCutter : block
		signal TC_TX_DataFlow								: STD_LOGIC;

		signal InsertEOP_d									: STD_LOGIC						:= '0';
		signal InsertEOP_re									: STD_LOGIC;
		signal InsertEOP_re_d								: STD_LOGIC						:= '0';
		signal InsertEOP_re_d2							: STD_LOGIC						:= '0';

	begin
		-- enable TX data path
		TC_TX_Valid					<= TX_Valid				AND TFSM_TX_en;
		TC_TX_Ack						<= FISE_TX_Ack		AND TFSM_TX_en;

		TC_TX_DataFlow			<= TC_TX_Valid		AND TC_TX_Ack;

		InsertEOP_d					<= ffdre(q => InsertEOP_d,     rst => MyReset, en => TC_TX_DataFlow, d => FISE_TX_InsertEOP) 	when rising_edge(Clock);
		InsertEOP_re				<= FISE_TX_InsertEOP	AND NOT InsertEOP_d;
		InsertEOP_re_d			<= ffdre(q => InsertEOP_re_d,  rst => MyReset, en => TC_TX_DataFlow, d => InsertEOP_re  ) 		when rising_edge(Clock);
		InsertEOP_re_d2			<= ffdre(q => InsertEOP_re_d2, rst => MyReset, en => TC_TX_DataFlow, d => InsertEOP_re_d) 		when rising_edge(Clock);

		TC_TX_SOP						<= TX_SOT OR InsertEOP_re_d2;
		TC_TX_EOP						<= TX_EOT	OR InsertEOP_re_d;
		TC_TX_Data					<= TX_Data;
	end block;	-- TransferCutter

	-- RX registers
	-- ==========================================================================================================================================================
	RXReg : block
		signal RXReg_mux_set										: STD_LOGIC;
		signal RXReg_mux_rst										: STD_LOGIC;
		signal RXReg_mux_r											: STD_LOGIC												:= '0';
		signal RXReg_mux												: STD_LOGIC;
		signal RXReg_Data_en										: STD_LOGIC;
		signal RXReg_Data_d											: T_SLV_32												:= (others => '0');
		signal RXReg_EOT_r											: STD_LOGIC												:= '0';

		signal RXReg_LastWord										: STD_LOGIC;
		signal RXReg_LastWord_r									: STD_LOGIC												:= '0';
		signal RXReg_LastWordAck								: STD_LOGIC;

		signal RXReg_SOT												: STD_LOGIC;
		signal RXReg_EOT												: STD_LOGIC;
	begin

		RXReg_Data_en					<= FISD_RX_Valid AND FISD_RX_EOP;
		RXReg_mux_set					<= FISD_RX_Valid AND FISD_RX_EOP;
		RXReg_mux_rst					<= RXReg_LastWordAck;

		RXReg_RX_Data					<= FISD_RX_Data when (RXReg_mux = '0') else RXReg_Data_d;
		RXReg_RX_Valid				<= (FISD_RX_Valid AND NOT RXReg_Data_en) OR RXReg_LastWord;

		RXReg_Ack							<= (RX_Ack	 OR RXReg_Data_en) AND NOT RXReg_mux;
		RXReg_LastWordAck			<= RXReg_LastWord AND RX_Ack;

		RXReg_SOT							<= TFSM_RX_SOT;
		RXReg_EOT							<= RXReg_EOT_r				OR TFSM_RX_EOT;
		RXReg_LastWord				<= RXReg_LastWord_r 	OR TFSM_RX_LastWord;
		RXReg_mux							<= RXReg_mux_r;

		process(Clock)
		begin
			if rising_edge(Clock) then
				if (MyReset = '1') then
					RXReg_Data_d				<= (others => '0');
					RXReg_mux_r					<= '0';
					RXReg_EOT_r					<= '0';
				else
					if (RXReg_Data_en = '1') then
						RXReg_Data_d			<= FISD_RX_Data;
					end if;

					if (RXReg_mux_rst = '1') then
						RXReg_mux_r				<= '0';
					ELSif (RXReg_mux_set = '1') then
						RXReg_mux_r				<= '1';
					end if;

					if (RXReg_mux_rst = '1') then
						RXReg_LastWord_r	<= '0';
					ELSif (TFSM_RX_LastWord = '1') then
						RXReg_LastWord_r	<= '1';
					end if;

					if (RXReg_mux_rst = '1') then
						RXReg_EOT_r		<= '0';
					ELSif (TFSM_RX_EOT = '1') then
						RXReg_EOT_r		<= '1';
					end if;
				end if;
			end if;
		end process;

		RXReg_RX_SOT				<= RXReg_SOT;
		RXReg_RX_EOT				<= RXReg_EOT;
	end block;

	RX_Valid			<= RXReg_RX_Valid;
	RX_Data				<= RXReg_RX_Data;
	RX_SOT				<= RXReg_RX_SOT;
	RX_EOT				<= RXReg_RX_EOT;


	FISE : entity PoC.sata_FISEncoder
		generic map (
			DEBUG												=> DEBUG		,
			ENABLE_DEBUGPORT						=> ENABLE_DEBUGPORT
		)
		port map (
			Clock												=> Clock,
			Reset												=> MyReset,

			-- FISEncoder interface
			Status											=> FISE_Status,
			FISType											=> TFSM_FISType,

			-- DebugPort
			DebugPortOut								=> FISE_DebugPortOut,

			ATARegisters								=> ATAHostRegisters_r,

			-- TransportLayer TX_FIFO interface
			TX_Ack											=> FISE_TX_Ack,
			TX_SOP											=> TC_TX_SOP,
			TX_EOP											=> TC_TX_EOP,
			TX_Data											=> TC_TX_Data,
			TX_Valid										=> TC_TX_Valid,
			TX_InsertEOP								=> FISE_TX_InsertEOP,

			-- LinkLayer CSE
			Link_Status 								=> Link_Status,

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
			Link_TX_FS_SyncEsc					=> Link_TX_FS_SyncEsc,
			Link_TX_FS_Ack							=> FISE_Link_TX_FS_Ack
		);

	-- ================================================================
	-- RX path
	-- ================================================================
	FISD : entity PoC.sata_FISDecoder
		generic map (
			DEBUG												=> DEBUG,
			ENABLE_DEBUGPORT						=> ENABLE_DEBUGPORT
		)
		port map (
			Clock												=> Clock,
			Reset												=> MyReset,

			Status											=> FISD_Status,
			FISType											=> FISD_FISType,

			-- DebugPort
			DebugPortOut								=> FISD_DebugPortOut,

			UpdateATARegisters					=> UpdateATADeviceRegisters,
			ATADeviceRegisters					=> FISD_ATADeviceRegisters,

			-- TransportLayer FIFO interface
			RX_Valid										=> FISD_RX_Valid,
			RX_Data											=> FISD_RX_Data,
			RX_SOP											=> FISD_RX_SOP,
			RX_EOP											=> FISD_RX_EOP,
			RX_Ack											=> RXReg_Ack,

			-- SATAController Status
			Link_Status 								=> Link_Status,

			-- LinkLayer FIFO interface
			Link_RX_Valid								=> Link_RX_Valid,
			Link_RX_Data								=> Link_RX_Data,
			Link_RX_SOF									=> Link_RX_SOF,
			Link_RX_EOF									=> Link_RX_EOF,
			Link_RX_Ack									=> FISD_Link_RX_Ack,
			-- LinkLayer FS-FIFO interface
			Link_RX_FS_Valid						=> Link_RX_FS_Valid,
			Link_RX_FS_CRCOK						=> Link_RX_FS_CRCOK,
			Link_RX_FS_SyncEsc					=> Link_RX_FS_SyncEsc,
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
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_generateCommandEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_TRANS_COMMAND loop
					STD.TextIO.write(l, str_replace(T_SATA_TRANS_COMMAND'image(i), "sata_trans_cmd", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			function dbg_generateStatusEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_TRANS_STATUS loop
					STD.TextIO.write(l, str_replace(T_SATA_TRANS_STATUS'image(i), "sata_trans_status_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			function dbg_generateErrorEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_TRANS_ERROR loop
					STD.TextIO.write(l, str_replace(T_SATA_TRANS_ERROR'image(i), "sata_trans_error_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			constant dummy : T_BOOLVEC := (
				0 => dbg_ExportEncoding("Trans Layer - Command Enum",	dbg_generateCommandEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Trans_Command.tok"),
				1 => dbg_ExportEncoding("Trans Layer - Status Enum",		dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Trans_Status.tok"),
				2 => dbg_ExportEncoding("Trans Layer - Error Enum",		dbg_generateErrorEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Trans_Error.tok")
			);
		begin
		end generate;

		DebugPortOut.TFSM												<= TFSM_DebugPortOut;
		DebugPortOut.FISE												<= FISE_DebugPortOut;
		DebugPortOut.FISD												<= FISD_DebugPortOut;

		DebugPortOut.UpdateATAHostRegisters			<= UpdateATAHostRegisters;
		DebugPortOut.ATAHostRegisters						<= ATAHostRegisters_r;
		DebugPortOut.UpdateATADeviceRegisters		<= UpdateATADeviceRegisters;
		DebugPortOut.ATADeviceRegisters					<= ATADeviceRegisters_i;

		DebugPortOut.TX_Valid										<= TX_Valid;
		DebugPortOut.TX_Data										<= TX_Data;
		DebugPortOut.TX_SOT											<= TX_SOT;
		DebugPortOut.TX_EOT											<= TX_EOT;
		DebugPortOut.TX_Ack											<= TC_TX_Ack or TFSM_TX_ForceAck;

		DebugPortOut.RX_Valid										<= RXReg_RX_Valid;
		DebugPortOut.RX_Data										<= RXReg_RX_Data;
		DebugPortOut.RX_SOT											<= RXReg_RX_SOT;
		DebugPortOut.RX_EOT											<= RXReg_RX_EOT;
		DebugPortOut.RX_Ack											<= RX_Ack;
		DebugPortOut.RX_LastWord								<= TFSM_RX_LastWord;

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
		DebugPortOut.Link_TX_FS_SyncEsc					<= Link_TX_FS_SyncEsc;
		DebugPortOut.Link_TX_FS_Ack							<= FISE_Link_TX_FS_Ack;

		DebugPortOut.Link_RX_Valid							<= Link_RX_Valid;
		DebugPortOut.Link_RX_Data								<= Link_RX_Data;
		DebugPortOut.Link_RX_SOF								<= Link_RX_SOF;
		DebugPortOut.Link_RX_EOF								<= Link_RX_EOF;
		DebugPortOut.Link_RX_Ack								<= FISD_Link_RX_Ack;
		DebugPortOut.Link_RX_FS_Valid						<= Link_RX_FS_Valid;
		DebugPortOut.Link_RX_FS_CRCOK						<= Link_RX_FS_CRCOK;
		DebugPortOut.Link_RX_FS_SyncEsc					<= Link_RX_FS_SyncEsc;
		DebugPortOut.Link_RX_FS_Ack							<= FISD_Link_RX_FS_Ack;
	end generate;
end;
