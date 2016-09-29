-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Package:					SATA Debug Types and Functions
--
-- Description:
-- -------------------------------------
-- Declares types and function for debugging purpose.
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
use			PoC.xil.all;


package satadbg is
	-- ===========================================================================
	-- SATA Transceiver Types
	-- ===========================================================================
	type T_SATADBG_TRANSCEIVER_OUT is record
		PowerDown									: std_logic;
		ClockNetwork_Reset				: std_logic;
		ClockNetwork_ResetDone		: std_logic;
		Reset											: std_logic;
		ResetDone									: std_logic;

		UserClock									: std_logic;
		UserClock_Stable					: std_logic;

		GTX_CPLL_PowerDown				: std_logic;
		GTX_TX_PowerDown					: std_logic;
		GTX_RX_PowerDown					: std_logic;

		GTX_CPLL_Reset						: std_logic;
		GTX_CPLL_Locked						: std_logic;

		GTX_TX_Reset							: std_logic;
		GTX_RX_Reset							: std_logic;
		GTX_RX_PMAReset						: std_logic;
		GTX_TX_ResetDone					: std_logic;
		GTX_RX_ResetDone					: std_logic;
		GTX_RX_PMAResetDone				: std_logic;

		FSM												: std_logic_vector(3 downto 0);

		OOB_Clock									: std_logic;
		RP_SATAGeneration					: T_SATA_GENERATION;
		RP_Reconfig								: std_logic;
		RP_ReconfigComplete				: std_logic;
		RP_ConfigRealoaded				: std_logic;
		DD_NoDevice								: std_logic;
		DD_NewDevice							: std_logic;
		TX_RateSelection					: std_logic_vector(2 downto 0);
		RX_RateSelection					: std_logic_vector(2 downto 0);
		TX_RateSelectionDone			: std_logic;
		RX_RateSelectionDone			: std_logic;
		RX_CDR_Locked							: std_logic;
		RX_CDR_Hold								: std_logic;

		TX_Data										: T_SLV_32;
		TX_CharIsK								: T_SLV_4;
		TX_BufferStatus						: std_logic_vector(1 downto 0);
		TX_ComInit								: std_logic;
		TX_ComWake								: std_logic;
		TX_ComFinish							: std_logic;
		TX_ElectricalIDLE					: std_logic;

		RX_Data										: T_SLV_32;
		RX_CharIsK								: T_SLV_4;
		RX_CharIsComma						: T_SLV_4;
		RX_CommaDetected					: std_logic;
		RX_ByteIsAligned					: std_logic;
		RX_DisparityError					: T_SLV_4;
		RX_NotInTableError				: T_SLV_4;
		RX_ElectricalIDLE					: std_logic;
		RX_ComInitDetected				: std_logic;
		RX_ComWakeDetected				: std_logic;
		RX_Valid									: std_logic;
		RX_BufferStatus						: std_logic_vector(2 downto 0);
		RX_ClockCorrectionStatus	: std_logic_vector(1 downto 0);

		DRP												: T_XIL_DRP_BUS_OUT;
		DigitalMonitor						: T_SLV_16;
		RX_Monitor_Data						: T_SLV_8;
	end record;

	constant C_SATADBG_TRANSCEIVER_OUT_EMPTY : T_SATADBG_TRANSCEIVER_OUT := (
		FSM											 => (others => '0'),
		RP_SATAGeneration				 => SATA_GENERATION_1,
		TX_RateSelection				 => (others => '0'),
		RX_RateSelection				 => (others => '0'),
		TX_Data									 => (others => '0'),
		TX_CharIsK							 => (others => '0'),
		TX_BufferStatus					 => (others => '0'),
		RX_Data									 => (others => '0'),
		RX_CharIsK							 => (others => '0'),
		RX_CharIsComma					 => (others => '0'),
		RX_DisparityError				 => (others => '0'),
		RX_NotInTableError			 => (others => '0'),
		RX_BufferStatus					 => (others => '0'),
		RX_ClockCorrectionStatus => (others => '0'),
		DRP											 => C_XIL_DRP_BUS_OUT_EMPTY,
		DigitalMonitor					 => (others => '0'),
		RX_Monitor_Data					 => (others => '0'),
		others									 => '0');

	type T_SATADBG_TRANSCEIVER_IN is record
		ForceOOBCommand						: T_SATA_OOB;
		ForceTXElectricalIdle			: std_logic;
		InsertBitErrorTX 					: std_logic;
		InsertBitErrorRX 					: std_logic;
		DRP												: T_XIL_DRP_BUS_IN;
		RX_Monitor_sel						: T_SLV_2;
	end record;

	constant C_SATADBG_TRANSCEIVER_IN_EMPTY : T_SATADBG_TRANSCEIVER_IN := (
		ForceOOBCommand => SATA_OOB_NONE,
		DRP							=> C_XIL_DRP_BUS_IN_EMPTY,
		RX_Monitor_sel	=> "00",
		others					=> '0');

	-- ===========================================================================
	-- SATA Physical Layer Types
	-- ===========================================================================
	type T_SATADBG_PHYSICAL_OOBCONTROL_OUT is record
		FSM												: std_logic_vector(3 downto 0);
		Timeout										: std_logic;
		DeviceOrHostDetected			: std_logic;
		LinkOK										: std_logic;
		LinkDead									: std_logic;
		OOB_TX_Command						: T_SATA_OOB;
		OOB_TX_Complete						: std_logic;
		OOB_RX_Received						: T_SATA_OOB;
		OOB_HandshakeComplete			: std_logic;
	end record;

	constant C_SATADBG_PHYSICAL_OOBCONTROL_OUT_EMPTY : T_SATADBG_PHYSICAL_OOBCONTROL_OUT := (
		FSM							=> (others => '0'),
		OOB_TX_Command	=> SATA_OOB_NONE,
		OOB_RX_Received => SATA_OOB_NONE,
		others					=> '0');

	type T_SATADBG_PHYSICAL_PFSM_OUT is record
		FSM												: std_logic_vector(3 downto 0);
		Command 									: T_SATA_PHY_COMMAND;
		Status										: T_SATA_PHY_STATUS;
		Error 										: T_SATA_PHY_ERROR;
		SATAGeneration						: T_SATA_GENERATION;
		SATAGeneration_Reset			: std_logic;
		SATAGeneration_Change			: std_logic;
		SATAGeneration_Changed		: std_logic;
		OOBC_Reset 								: std_logic;
		Trans_Reconfig						: std_logic;
		Trans_ConfigReloaded			: std_logic;
		GenerationChanges					: std_logic_vector(7 downto 0);
		TrysPerGeneration					: std_logic_vector(7 downto 0);
	end record;

	constant C_SATADBG_PHYSICAL_PFSM_OUT_EMPTY : T_SATADBG_PHYSICAL_PFSM_OUT := (
		FSM								=> (others => '0'),
		Command						=> SATA_PHY_CMD_NONE,
		Status						=> SATA_PHY_STATUS_RESET,
		Error							=> SATA_PHY_ERROR_NONE,
		SATAGeneration		=> SATA_GENERATION_1,
		GenerationChanges => (others => '0'),
		TrysPerGeneration => (others => '0'),
		others						=> '0');

	type T_SATADBG_PHYSICAL_OUT is record
		TX_Data										: T_SLV_32;
		TX_CharIsK								: T_SLV_4;
		RX_Data										: T_SLV_32;
		RX_CharIsK								: T_SLV_4;
		RX_Valid									: std_logic;

		OOBControl								: T_SATADBG_PHYSICAL_OOBCONTROL_OUT;
		PFSM											: T_SATADBG_PHYSICAL_PFSM_OUT;
	end record;

	constant C_SATADBG_PHYSICAL_OUT_EMPTY : T_SATADBG_PHYSICAL_OUT := (
		TX_Data		 => (others => '0'),
		TX_CharIsK => (others => '0'),
		RX_Data		 => (others => '0'),
		RX_CharIsK => (others => '0'),
		OOBControl => C_SATADBG_PHYSICAL_OOBCONTROL_OUT_EMPTY,
		PFSM			 => C_SATADBG_PHYSICAL_PFSM_OUT_EMPTY,
		others		 => '0');


	-- ===========================================================================
	-- SATA Link Layer Types
	-- ===========================================================================
	type T_SATADBG_LINK_LLFSM_OUT is record
		FSM													: std_logic_vector(4 downto 0);
		-- TX: Retry
		TX_IsLongFrame							: std_logic;
		TX_RetryFailed							: std_logic;
	end record;

	constant C_SATADBG_LINK_LLFSM_OUT_EMPTY : T_SATADBG_LINK_LLFSM_OUT := (
		FSM		 => (others => '0'),
		others => '0');

	type T_SATADBG_LINK_OUT is record
		LLFSM												: T_SATADBG_LINK_LLFSM_OUT;

		-- from physical layer
		Phy_Ready										: std_logic;
		-- RX: from physical layer
		RX_Phy_Data									: T_SLV_32;
		RX_Phy_CiK									: T_SLV_4;										-- 4 bit
		-- RX: after primitive detector
		RX_Primitive								: T_SATA_PRIMITIVE;							-- 5 bit
		-- RX: after unscrambling
		RX_DataUnscrambler_rst			: std_logic;
		RX_DataUnscrambler_en				: std_logic;
		RX_DataUnscrambler_DataOut	:	T_SLV_32;
		-- RX: CRC control
		RX_CRC_rst									: std_logic;
		RX_CRC_en										: std_logic;
		-- RX: DataRegisters
		RX_DataReg_shift						: std_logic;
		-- RX: before RX_FIFO
		RX_FIFO_SpaceAvailable			: std_logic;
		RX_FIFO_rst									: std_logic;
		RX_FIFO_put									: std_logic;
		RX_FIFO_commit							: std_logic;
		RX_FIFO_rollback						: std_logic;
		RX_FSFIFO_rst								: std_logic;
		RX_FSFIFO_put								: std_logic;
		-- RX: after RX_FIFO
		RX_Data											: T_SLV_32;
		RX_Valid										: std_logic;
		RX_Ack											: std_logic;
		RX_SOF											: std_logic;
		RX_EOF											: std_logic;
		RX_FS_Valid									: std_logic;
		RX_FS_Ack										: std_logic;
		RX_FS_CRCOK									: std_logic;
		RX_FS_SyncEsc								: std_logic;
		--																													=> 125 bit
		-- TX: from Link Layer
		TX_Data											: T_SLV_32;
		TX_Valid										: std_logic;
		TX_Ack											: std_logic;
		TX_SOF											: std_logic;
		TX_EOF											: std_logic;
		TX_InsertEOF 								: std_logic;
		TX_FS_Valid									: std_logic;
		TX_FS_Ack										: std_logic;
		TX_FS_SendOK								: std_logic;
		TX_FS_SyncEsc								: std_logic;
		-- TX: TXFIFO
		TX_FIFO_got									: std_logic;
		TX_FSFIFO_got								: std_logic;
		-- TX: CRC control
		TX_CRC_rst									: std_logic;
		TX_CRC_en										: std_logic;
		TX_CRC_mux									: std_logic;
		-- TX: after scrambling
		TX_DataScrambler_rst				: std_logic;
		TX_DataScrambler_en					: std_logic;
		TX_DataScrambler_DataOut		:	T_SLV_32;
		-- TX: PrimitiveMux
		TX_Primitive								: T_SATA_PRIMITIVE;							-- 5 bit ?
		-- TX: to Physical Layer
		TX_Phy_Data									: T_SLV_32;
		TX_Phy_CiK									: T_SLV_4;										-- 4 bit
	end record;		--																							=> 120 bit

	constant C_SATADBG_LINK_OUT_EMPTY : T_SATADBG_LINK_OUT := (
		LLFSM											 => C_SATADBG_LINK_LLFSM_OUT_EMPTY,
		RX_Phy_Data								 => (others => '0'),
		RX_Phy_CiK								 => (others => '0'),
		RX_Primitive							 => SATA_PRIMITIVE_NONE,
		RX_DataUnscrambler_DataOut => (others => '0'),
		RX_Data										 => (others => '0'),
		TX_Data										 => (others => '0'),
		TX_DataScrambler_DataOut	 => (others => '0'),
		TX_Primitive							 => SATA_PRIMITIVE_NONE,
		TX_Phy_Data								 => (others => '0'),
		TX_Phy_CiK								 => (others => '0'),
		others										 => '0');

	type T_SATADBG_LINK_IN is record
		InsertBitErrorHeaderTX			: std_logic;
	end record;

	constant C_SATADBG_LINK_IN_EMPTY : T_SATADBG_LINK_IN := (
		others					=> '0');

	-- ===========================================================================
	-- SATA Transport Layer Types
	-- ===========================================================================
	type T_SATADBG_TRANS_TFSM_OUT is record
		FSM													: std_logic_vector(4 downto 0);				-- 5 bits
	end record;

	constant C_SATADBG_TRANS_TFSM_OUT_EMPTY : T_SATADBG_TRANS_TFSM_OUT := (
		FSM => (others => '0'));

	type T_SATADBG_TRANS_FISE_OUT is record
		FSM													: std_logic_vector(3 downto 0);				-- 4 bits
	end record;

	constant C_SATADBG_TRANS_FISE_OUT_EMPTY : T_SATADBG_TRANS_FISE_OUT := (
		FSM => (others => '0'));

	type T_SATADBG_TRANS_FISD_OUT is record
		FSM													: std_logic_vector(4 downto 0);				-- 5 bits
	end record;

	constant C_SATADBG_TRANS_FISD_OUT_EMPTY : T_SATADBG_TRANS_FISD_OUT := (
		FSM => (others => '0'));

	type T_SATADBG_TRANS_OUT is record
		TFSM												: T_SATADBG_TRANS_TFSM_OUT;						-- 5 bits
		FISE												: T_SATADBG_TRANS_FISE_OUT;						-- 4 bits
		FISD												: T_SATADBG_TRANS_FISD_OUT;						-- 5 bits

		UpdateATAHostRegisters			: std_logic;
		ATAHostRegisters						: T_SATA_ATA_HOST_REGISTERS;
		UpdateATADeviceRegisters		: std_logic;
		ATADeviceRegisters					: T_SATA_ATA_DEVICE_REGISTERS;

		TX_Data											: T_SLV_32;
		TX_Valid										: std_logic;
		TX_Ack											: std_logic;
		TX_SOT											: std_logic;
		TX_EOT											: std_logic;

		RX_Data											: T_SLV_32;
		RX_Valid										: std_logic;
		RX_Ack											: std_logic;
		RX_SOT											: std_logic;
		RX_EOT											: std_logic;
		RX_LastWord									: std_logic;

		FISE_FISType								: T_SATA_FISTYPE;							-- 4 bit
		FISE_Status									: T_SATA_FISENCODER_STATUS;		-- 3 bit

		FISD_FISType								: T_SATA_FISTYPE;							-- 4 bit
		FISD_Status									: T_SATA_FISDECODER_STATUS;		-- 3 bit

		Link_TX_Data								: T_SLV_32;
		Link_TX_Valid								: std_logic;
		Link_TX_Ack									: std_logic;
		Link_TX_SOF									: std_logic;
		Link_TX_EOF									: std_logic;
		Link_TX_FS_Valid						: std_logic;
		Link_TX_FS_Ack							: std_logic;
		Link_TX_FS_SendOK						: std_logic;
		Link_TX_FS_SyncEsc					: std_logic;

		Link_RX_Data								: T_SLV_32;
		Link_RX_Valid								: std_logic;
		Link_RX_Ack									: std_logic;
		Link_RX_SOF									: std_logic;
		Link_RX_EOF									: std_logic;
		Link_RX_FS_Valid						: std_logic;
		Link_RX_FS_Ack							: std_logic;
		Link_RX_FS_CRCOK						: std_logic;
		Link_RX_FS_SyncEsc					: std_logic;
	end record;

	constant C_SATADBG_TRANS_OUT_EMPTY : T_SATADBG_TRANS_OUT := (
		TFSM							 => C_SATADBG_TRANS_TFSM_OUT_EMPTY,
		FISE							 => C_SATADBG_TRANS_FISE_OUT_EMPTY,
		FISD							 => C_SATADBG_TRANS_FISD_OUT_EMPTY,
		ATAHostRegisters	 => C_SATA_ATA_HOST_REGISTERS_EMPTY,
		ATADeviceRegisters => C_SATA_ATA_DEVICE_REGISTERS_EMPTY,
		TX_Data						 => (others => '0'),
		RX_Data						 => (others => '0'),
		FISE_FISType			 => SATA_FISTYPE_UNKNOWN,
		FISE_Status				 => SATA_FISE_STATUS_RESET,
		FISD_FISType			 => SATA_FISTYPE_UNKNOWN,
		FISD_Status				 => SATA_FISD_STATUS_RESET,
		Link_TX_Data			 => (others => '0'),
		Link_RX_Data			 => (others => '0'),
		others						 => '0');

	-- ===========================================================================
	-- SATA Controller Types
	-- ===========================================================================
	type T_SATADBG_SATACONTROLLER_OUT is record
		-- Transceiver Layer
		TransceiverLayer			: T_SATADBG_TRANSCEIVER_OUT;
		Transceiver_Command		: T_SATA_TRANSCEIVER_COMMAND;
		Transceiver_Status		: T_SATA_TRANSCEIVER_STATUS;
		Transceiver_Error			: T_SATA_TRANSCEIVER_ERROR;
		-- Physical Layer
		PhysicalLayer					: T_SATADBG_PHYSICAL_OUT;
		Physical_Command			: T_SATA_PHY_COMMAND;
		Physical_Status				: T_SATA_PHY_STATUS;									-- 3 bit
		Physical_Error				: T_SATA_PHY_ERROR;
		-- Link Layer
		LinkLayer							: T_SATADBG_LINK_OUT;									-- RX: 125 + TX: 120 bit
		Link_Command					: T_SATA_LINK_COMMAND;								-- 1 bit
		Link_Status						: T_SATA_LINK_STATUS;									-- 3 bit
		Link_Error						: T_SATA_LINK_ERROR;									-- 2 bit
		-- Transport Layer
		TransportLayer				: T_SATADBG_TRANS_OUT;
		Transport_Command			: T_SATA_TRANS_COMMAND;								-- 2 bit
		Transport_Status			: T_SATA_TRANS_STATUS;								-- 3 bit
		Transport_Error				: T_SATA_TRANS_ERROR;									-- 3 bit
	end record;

	constant C_SATADBG_SATACONTROLLER_OUT_EMPTY : T_SATADBG_SATACONTROLLER_OUT := (
		TransceiverLayer		=> C_SATADBG_TRANSCEIVER_OUT_EMPTY,
		Transceiver_Command => SATA_TRANSCEIVER_CMD_NONE,
		Transceiver_Status	=> SATA_TRANSCEIVER_STATUS_INIT,
		Transceiver_Error		=> C_SATA_TRANSCEIVER_ERROR_EMPTY,
		PhysicalLayer				=> C_SATADBG_PHYSICAL_OUT_EMPTY,
		Physical_Command		=> SATA_PHY_CMD_NONE,
		Physical_Status			=> SATA_PHY_STATUS_RESET,
		Physical_Error			=> SATA_PHY_ERROR_NONE,
		LinkLayer						=> C_SATADBG_LINK_OUT_EMPTY,
		Link_Command				=> SATA_LINK_CMD_NONE,
		Link_Status					=> SATA_LINK_STATUS_NO_COMMUNICATION,
		Link_Error					=> SATA_LINK_ERROR_NONE,
		TransportLayer			=> C_SATADBG_TRANS_OUT_EMPTY,
		Transport_Command		=> SATA_TRANS_CMD_NONE,
		Transport_Status		=> SATA_TRANS_STATUS_RESET,
		Transport_Error			=> SATA_TRANS_ERROR_NONE);

	type T_SATADBG_SATACONTROLLER_IN is record
		TransceiverLayer			: T_SATADBG_TRANSCEIVER_IN;
		LinkLayer							: T_SATADBG_LINK_IN;
	end record;


	-- ===========================================================================
	-- SATA StreamingLayer Types
	-- ===========================================================================

  type T_SATADBG_STREAMING_SFSM_OUT is record
    FSM          : std_logic_vector(4 downto 0);
    Load         : std_logic;
    NextTransfer : std_logic;
    LastTransfer : std_logic;
	end record;

	constant C_SATADBG_STREAMING_SFSM_OUT_EMPTY : T_SATADBG_STREAMING_SFSM_OUT := (
		FSM => (others => '0'),
		others => '0');

  type T_SATADBG_STREAMING_OUT is record
    Command             	: T_SATA_STREAMING_COMMAND;
    Status              	: T_SATA_STREAMING_STATUS;
    Error               	: T_SATA_STREAMING_ERROR;
    Address_AppLB       	: T_SLV_48;
    BlockCount_AppLB    	: T_SLV_48;
    Address_DevLB       	: T_SLV_48;
    BlockCount_DevLB    	: T_SLV_48;
    IDF_Reset           	: std_logic;
    IDF_Enable          	: std_logic;
    IDF_Error           	: std_logic;
    IDF_Finished        	: std_logic;
    IDF_DriveInformation	: T_SATA_DRIVE_INFORMATION;
    SFSM									: T_SATADBG_STREAMING_SFSM_OUT;
    RX_Valid          		: std_logic;
    RX_Data           		: T_SLV_32;
    RX_SOR            		: std_logic;
    RX_EOR            		: std_logic;
    RX_Ack            		: std_logic;
    SFSM_RX_Valid    			: std_logic;
    SFSM_RX_SOR      			: std_logic;
    SFSM_RX_EOR      			: std_logic;
    SFSM_RX_Ack      			: std_logic;
    Trans_RX_Valid    		: std_logic;
    Trans_RX_Data     		: T_SLV_32;
    Trans_RX_SOT      		: std_logic;
    Trans_RX_EOT      		: std_logic;
    Trans_RX_Ack      		: std_logic;
    SFSM_TX_ForceEOT 			: std_logic;
    TX_Valid          		: std_logic;
    TX_Data           		: T_SLV_32;
    TX_SOR            		: std_logic;
    TX_EOR            		: std_logic;
    TX_Ack            		: std_logic;
    TC_TX_Valid       		: std_logic;
    TC_TX_Data        		: T_SLV_32;
    TC_TX_SOT         		: std_logic;
    TC_TX_EOT         		: std_logic;
    TC_TX_Ack         		: std_logic;
    TC_TX_InsertEOT 			: std_logic;
	end record;

	constant C_SATADBG_STREAMING_OUT_EMPTY : T_SATADBG_STREAMING_OUT := (
		Command							 => SATA_STREAM_CMD_NONE,
		Status							 => SATA_STREAM_STATUS_RESET,
		Error								 => SATA_STREAM_ERROR_NONE,
		Address_AppLB				 => (others => '0'),
		BlockCount_AppLB		 => (others => '0'),
		Address_DevLB				 => (others => '0'),
		BlockCount_DevLB		 => (others => '0'),
		IDF_DriveInformation => C_SATA_DRIVE_INFORMATION_EMPTY,
		SFSM								 => C_SATADBG_STREAMING_SFSM_OUT_EMPTY,
		RX_Data							 => (others => '0'),
		Trans_RX_Data				 => (others => '0'),
		TX_Data							 => (others => '0'),
		TC_TX_Data					 => (others => '0'),
		others							 => '0');


	-- ===========================================================================
	-- SATA Streaming Stack Types
	-- ===========================================================================
	type T_SATADBG_STREAMINGSTACK_OUT is record
		-- Transceiver Layer
		TransceiverLayer		: T_SATADBG_TRANSCEIVER_OUT;
		Transceiver_Command	: T_SATA_TRANSCEIVER_COMMAND;
		Transceiver_Status	: T_SATA_TRANSCEIVER_STATUS;
		Transceiver_Error		: T_SATA_TRANSCEIVER_ERROR;
		-- Physical Layer
		PhysicalLayer				: T_SATADBG_PHYSICAL_OUT;
		Physical_Command		: T_SATA_PHY_COMMAND;
		Physical_Status			: T_SATA_PHY_STATUS;
		Physical_Error			: T_SATA_PHY_ERROR;
		-- Link Layer
		LinkLayer						: T_SATADBG_LINK_OUT;
		Link_Command				: T_SATA_LINK_COMMAND;
		Link_Status					: T_SATA_LINK_STATUS;
		Link_Error					: T_SATA_LINK_ERROR;
		-- Transport Layer
		TransportLayer			: T_SATADBG_TRANS_OUT;
		Transport_Command		: T_SATA_TRANS_COMMAND;
		Transport_Status		: T_SATA_TRANS_STATUS;
		Transport_Error			: T_SATA_TRANS_ERROR;
		-- Streaming Controller
		StreamingLayer			: T_SATADBG_STREAMING_OUT;
		Streaming_Command		: T_SATA_STREAMING_COMMAND;
		Streaming_Status		: T_SATA_STREAMING_STATUS;
		Streaming_Error			: T_SATA_STREAMING_ERROR;
	end record;

	constant C_SATADBG_STREAMINGSTACK_OUT_EMPTY : T_SATADBG_STREAMINGSTACK_OUT := (
		TransceiverLayer		=> C_SATADBG_TRANSCEIVER_OUT_EMPTY,
		Transceiver_Command => SATA_TRANSCEIVER_CMD_NONE,
		Transceiver_Status	=> SATA_TRANSCEIVER_STATUS_INIT,
		Transceiver_Error		=> C_SATA_TRANSCEIVER_ERROR_EMPTY,
		PhysicalLayer				=> C_SATADBG_PHYSICAL_OUT_EMPTY,
		Physical_Command		=> SATA_PHY_CMD_NONE,
		Physical_Status			=> SATA_PHY_STATUS_RESET,
		Physical_Error			=> SATA_PHY_ERROR_NONE,
		LinkLayer						=> C_SATADBG_LINK_OUT_EMPTY,
		Link_Command				=> SATA_LINK_CMD_NONE,
		Link_Status					=> SATA_LINK_STATUS_NO_COMMUNICATION,
		Link_Error					=> SATA_LINK_ERROR_NONE,
		TransportLayer			=> C_SATADBG_TRANS_OUT_EMPTY,
		Transport_Command		=> SATA_TRANS_CMD_NONE,
		Transport_Status		=> SATA_TRANS_STATUS_RESET,
		Transport_Error			=> SATA_TRANS_ERROR_NONE,
		StreamingLayer			=> C_SATADBG_STREAMING_OUT_EMPTY,
		Streaming_Command		=> SATA_STREAM_CMD_NONE,
		Streaming_Status		=> SATA_STREAM_STATUS_RESET,
		Streaming_Error			=> SATA_STREAM_ERROR_NONE);

	type T_SATADBG_STREAMINGSTACK_IN is record
		TransceiverLayer		: T_SATADBG_TRANSCEIVER_IN;
		LinkLayer						: T_SATADBG_LINK_IN;
	end record;

	constant C_SATADBG_STREAMINGSTACK_IN_EMPTY : T_SATADBG_STREAMINGSTACK_IN := (
		TransceiverLayer => C_SATADBG_TRANSCEIVER_IN_EMPTY,
		LinkLayer				 => C_SATADBG_LINK_IN_EMPTY);

	type T_SATADBG_TRANSCEIVER_OUT_VECTOR			is array (natural range <>)	of T_SATADBG_TRANSCEIVER_OUT;
	type T_SATADBG_TRANSCEIVER_IN_VECTOR			is array (natural range <>)	of T_SATADBG_TRANSCEIVER_IN;
	type T_SATADBG_PHYSICAL_OUT_VECTOR				is array (natural range <>)	of T_SATADBG_PHYSICAL_OUT;
	type T_SATADBG_LINK_OUT_VECTOR						is array (natural range <>)	of T_SATADBG_LINK_OUT;
	type T_SATADBG_SATACONTROLLER_OUT_VECTOR	is array (natural range <>)	of T_SATADBG_SATACONTROLLER_OUT;
	type T_SATADBG_SATACONTROLLER_IN_VECTOR		is array (natural range <>)	of T_SATADBG_SATACONTROLLER_IN;

end package;
