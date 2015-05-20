-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Package:					TODO
--
-- Description:
-- ------------------------------------
--		TODO
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
		PowerDown									: STD_LOGIC;
		ClockNetwork_Reset				: STD_LOGIC;
		ClockNetwork_ResetDone		: STD_LOGIC;
		Reset											: STD_LOGIC;
		ResetDone									: STD_LOGIC;
		
		UserClock									: STD_LOGIC;
		UserClock_Stable					: STD_LOGIC;

		GTX_CPLL_PowerDown				: STD_LOGIC;
		GTX_TX_PowerDown					: STD_LOGIC;
		GTX_RX_PowerDown					: STD_LOGIC;

		GTX_CPLL_Reset						: STD_LOGIC;
		GTX_CPLL_Locked						: STD_LOGIC;

		GTX_TX_Reset							: STD_LOGIC;
		GTX_RX_Reset							: STD_LOGIC;
		GTX_TX_ResetDone					: STD_LOGIC;
		GTX_RX_ResetDone					: STD_LOGIC;
		
		FSM												: STD_LOGIC_VECTOR(3 DOWNTO 0);
		
		OOB_Clock									: STD_LOGIC;
		RP_SATAGeneration					: T_SATA_GENERATION;
		RP_Reconfig								: STD_LOGIC;
		RP_ReconfigComplete				: STD_LOGIC;
		RP_ConfigRealoaded				: STD_LOGIC;
		DD_NoDevice								: STD_LOGIC;
		DD_NewDevice							: STD_LOGIC;
		TX_RateSelection					: STD_LOGIC_VECTOR(2 downto 0);
		RX_RateSelection					: STD_LOGIC_VECTOR(2 downto 0);
		TX_RateSelectionDone			: STD_LOGIC;
		RX_RateSelectionDone			: STD_LOGIC;
		RX_CDR_Locked							: STD_LOGIC;
		RX_CDR_Hold								: STD_LOGIC;
		
		TX_Data										: T_SLV_32;
		TX_CharIsK								: T_SLV_4;
		TX_BufferStatus						: STD_LOGIC_VECTOR(1 downto 0);
		TX_ComInit								: STD_LOGIC;
		TX_ComWake								: STD_LOGIC;
		TX_ComFinish							: STD_LOGIC;
		TX_ElectricalIDLE					: STD_LOGIC;

		RX_Data										: T_SLV_32;
		RX_CharIsK								: T_SLV_4;
		RX_CharIsComma						: T_SLV_4;
		RX_CommaDetected					: STD_LOGIC;
		RX_ByteIsAligned					: STD_LOGIC;
		RX_DisparityError					: T_SLV_4;
		RX_NotInTableError				: T_SLV_4;
		RX_ElectricalIDLE					: STD_LOGIC;
		RX_ComInitDetected				: STD_LOGIC;
		RX_ComWakeDetected				: STD_LOGIC;
		RX_Valid									: STD_LOGIC;
		RX_BufferStatus						: STD_LOGIC_VECTOR(2 downto 0);
		RX_ClockCorrectionStatus	: STD_LOGIC_VECTOR(1 downto 0);
		
		DRP												: T_XIL_DRP_BUS_OUT;
		DigitalMonitor						: T_SLV_8;
		RX_Monitor_Data						: T_SLV_8;
	end record;
	
	type T_SATADBG_TRANSCEIVER_IN is record
		ForceOOBCommand						: T_SATA_OOB;
		ForceTXElectricalIdle			: STD_LOGIC;
		InsertBitErrorTX 					: STD_LOGIC;
		InsertBitErrorRX 					: STD_LOGIC;
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
		FSM												: STD_LOGIC_VECTOR(3 downto 0);
		Timeout										: STD_LOGIC;
		DeviceOrHostDetected			: STD_LOGIC;
		LinkOK										: STD_LOGIC;
		LinkDead									: STD_LOGIC;
		OOB_TX_Command						: T_SATA_OOB;
		OOB_TX_Complete						: STD_LOGIC;
		OOB_RX_Received						: T_SATA_OOB;
		OOB_HandshakeComplete			: STD_LOGIC;
	end record;
	
	type T_SATADBG_PHYSICAL_PFSM_OUT is record
		FSM												: STD_LOGIC_VECTOR(3 downto 0);
		Command 									: T_SATA_PHY_COMMAND;
		Status										: T_SATA_PHY_STATUS;
		Error 										: T_SATA_PHY_ERROR;
		SATAGeneration						: T_SATA_GENERATION;
		SATAGeneration_Reset			: STD_LOGIC;
		SATAGeneration_Change			: STD_LOGIC;
		SATAGeneration_Changed		: STD_LOGIC;
		OOBC_Reset 								: STD_LOGIC;
		Trans_Reconfig						: STD_LOGIC;
		Trans_ConfigReloaded			: STD_LOGIC;
		GenerationChanges					: STD_LOGIC_VECTOR(7 downto 0);
		TrysPerGeneration					: STD_LOGIC_VECTOR(7 downto 0);
	end record;
	
	type T_SATADBG_PHYSICAL_OUT is record
		TX_Data										: T_SLV_32;
		TX_CharIsK								: T_SLV_4;		
		RX_Data										: T_SLV_32;
		RX_CharIsK								: T_SLV_4;
		RX_Valid									: STD_LOGIC;
		
		OOBControl								: T_SATADBG_PHYSICAL_OOBCONTROL_OUT;
		PFSM											: T_SATADBG_PHYSICAL_PFSM_OUT;
	end record;
	
	
	-- ===========================================================================
	-- SATA Link Layer Types
	-- ===========================================================================
	type T_SATADBG_LINK_LLFSM_OUT is record
		FSM													: STD_LOGIC_VECTOR(4 downto 0);
	end record;
	
	type T_SATADBG_LINK_OUT is record
		LLFSM												: T_SATADBG_LINK_LLFSM_OUT;
	
		-- from physical layer
		Phy_Ready										: STD_LOGIC;
		-- RX: from physical layer
		RX_Phy_Data									: T_SLV_32;
		RX_Phy_CiK									: T_SLV_4;										-- 4 bit
		-- RX: after primitive detector
		RX_Primitive								: T_SATA_PRIMITIVE;							-- 5 bit
		-- RX: after unscrambling
		RX_DataUnscrambler_rst			: STD_LOGIC;
		RX_DataUnscrambler_en				: STD_LOGIC;
		RX_DataUnscrambler_DataOut	:	T_SLV_32;
		-- RX: CRC control
		RX_CRC_rst									: STD_LOGIC;
		RX_CRC_en										: STD_LOGIC;
		-- RX: DataRegisters
		RX_DataReg_shift						: STD_LOGIC;
		-- RX: before RX_FIFO
		RX_FIFO_SpaceAvailable			: STD_LOGIC;
		RX_FIFO_rst									: STD_LOGIC;
		RX_FIFO_put									: STD_LOGIC;
		RX_FIFO_commit							: STD_LOGIC;
		RX_FIFO_rollback						: STD_LOGIC;
		RX_FSFIFO_rst								: STD_LOGIC;
		RX_FSFIFO_put								: STD_LOGIC;
		-- RX: after RX_FIFO
		RX_Data											: T_SLV_32;
		RX_Valid										: STD_LOGIC;
		RX_Ack											: STD_LOGIC;
		RX_SOF											: STD_LOGIC;
		RX_EOF											: STD_LOGIC;
		RX_FS_Valid									: STD_LOGIC;
		RX_FS_Ack										: STD_LOGIC;
		RX_FS_CRCOK									: STD_LOGIC;
		RX_FS_SyncEsc								: STD_LOGIC;
		--																													=> 125 bit
		-- TX: from Link Layer
		TX_Data											: T_SLV_32;
		TX_Valid										: STD_LOGIC;
		TX_Ack											: STD_LOGIC;
		TX_SOF											: STD_LOGIC;
		TX_EOF											: STD_LOGIC;
		TX_InsertEOF 								: STD_LOGIC;
		TX_FS_Valid									: STD_LOGIC;
		TX_FS_Ack										: STD_LOGIC;
		TX_FS_SendOK								: STD_LOGIC;
		TX_FS_Abort									: STD_LOGIC;
		-- TX: TXFIFO
		TX_FIFO_got									: STD_LOGIC;
		TX_FSFIFO_got								: STD_LOGIC;
		-- TX: CRC control
		TX_CRC_rst									: STD_LOGIC;
		TX_CRC_en										: STD_LOGIC;
		TX_CRC_mux									: STD_LOGIC;
		-- TX: after scrambling
		TX_DataScrambler_rst				: STD_LOGIC;
		TX_DataScrambler_en					: STD_LOGIC;
		TX_DataScrambler_DataOut		:	T_SLV_32;
		-- TX: PrimitiveMux
		TX_Primitive								: T_SATA_PRIMITIVE;							-- 5 bit ?
		-- TX: to Physical Layer
		TX_Phy_Data									: T_SLV_32;											
		TX_Phy_CiK									: T_SLV_4;										-- 4 bit
	end record;		--																							=> 120 bit
	
	
	-- ===========================================================================
	-- SATA Controller Types
	-- ===========================================================================
	type T_SATADBG_SATAC_OUT is record
		-- Transceiver Layer
		Transceiver						: T_SATADBG_TRANSCEIVER_OUT;
		Transceiver_Command		: T_SATA_TRANSCEIVER_COMMAND;
		Transceiver_Status		: T_SATA_TRANSCEIVER_STATUS;
		Transceiver_Error			: T_SATA_TRANSCEIVER_ERROR;
		-- Physical Layer
		Physical							: T_SATADBG_PHYSICAL_OUT;
		Physical_Command			: T_SATA_PHY_COMMAND;
		Physical_Status				: T_SATA_PHY_STATUS;									-- 3 bit
		Physical_Error				: T_SATA_PHY_ERROR;
		-- Link Layer
		Link									: T_SATADBG_LINK_OUT;									-- RX: 125 + TX: 120 bit
		Link_Command					: T_SATA_LINK_COMMAND;								-- 1 bit
		Link_Status						: T_SATA_LINK_STATUS;									-- 3 bit
		Link_Error						: T_SATA_LINK_ERROR;									-- 2 bit
	end record;
	
	type T_SATADBG_SATAC_IN is record
		Transceiver						: T_SATADBG_TRANSCEIVER_IN;
	end record;


	-- ===========================================================================
	-- ATA Command Layer types
	-- ===========================================================================

  type T_SATADBG_CMD_CFSM_OUT is record
    FSM          : std_logic_Vector(3 downto 0);
    Load         : std_logic;
    NextTransfer : std_logic;
    LastTransfer : std_logic;
	end record;
	
  type T_SATADBG_CMD_OUT is record
    Command              : T_SATA_CMD_COMMAND;
    Status               : T_SATA_CMD_STATUS;
    Error                : T_SATA_CMD_ERROR;
    Address_AppLB        : T_SLV_48;
    BlockCount_AppLB     : T_SLV_48;
    Address_DevLB        : T_SLV_48;
    BlockCount_DevLB     : T_SLV_48;
    IDF_Reset            : STD_LOGIC;
    IDF_Enable           : STD_LOGIC;
    IDF_Error            : STD_LOGIC;
    IDF_Finished         : STD_LOGIC;
    IDF_DriveInformation : T_SATA_DRIVE_INFORMATION;
    CFSM                 : T_SATADBG_CMD_CFSM_OUT;
    RX_Valid             : STD_LOGIC;
    RX_Data              : T_SLV_32;
    RX_SOR               : STD_LOGIC;
    RX_EOR               : STD_LOGIC;
    RX_Ack               : STD_LOGIC;
    CFSM_RX_Valid        : STD_LOGIC;
    CFSM_RX_SOR          : STD_LOGIC;
    CFSM_RX_EOR          : STD_LOGIC;
    CFSM_RX_Ack          : STD_LOGIC;
    Trans_RX_Valid       : STD_LOGIC;
    Trans_RX_Data        : T_SLV_32;
    Trans_RX_SOT         : STD_LOGIC;
    Trans_RX_EOT         : STD_LOGIC;
    Trans_RX_Ack         : STD_LOGIC;
    TX_Valid             : STD_LOGIC;
    TX_Data              : T_SLV_32;
    TX_SOR               : STD_LOGIC;
    TX_EOR               : STD_LOGIC;
    TX_Ack               : STD_LOGIC;
    TC_TX_Valid          : STD_LOGIC;
    TC_TX_Data           : T_SLV_32;
    TC_TX_SOT            : STD_LOGIC;
    TC_TX_EOT            : STD_LOGIC;
    TC_TX_Ack            : STD_LOGIC;
    TC_TX_LastWord 		   : STD_LOGIC;
    TC_TX_InsertEOT 		 : STD_LOGIC;
	end record;
	

	-- ===========================================================================
	-- SATA Transport Layer Types
	-- ===========================================================================
	type T_SATADBG_TRANS_TFSM_OUT is record
		FSM													: STD_LOGIC_VECTOR(4 downto 0);				-- 5 bits
	end record;
	
	type T_SATADBG_TRANS_FISE_OUT is record
		FSM													: STD_LOGIC_VECTOR(3 downto 0);				-- 4 bits
	end record;
	
	type T_SATADBG_TRANS_FISD_OUT is record
		FSM													: STD_LOGIC_VECTOR(4 downto 0);				-- 5 bits
	end record;
	
	type T_SATADBG_TRANS_OUT is record
		TFSM												: T_SATADBG_TRANS_TFSM_OUT;						-- 5 bits
		FISE												: T_SATADBG_TRANS_FISE_OUT;						-- 4 bits
		FISD												: T_SATADBG_TRANS_FISD_OUT;						-- 5 bits
		
		UpdateATAHostRegisters			: STD_LOGIC;
		ATAHostRegisters						: T_SATA_ATA_HOST_REGISTERS;
		UpdateATADeviceRegisters		: STD_LOGIC;
		ATADeviceRegisters					: T_SATA_ATA_DEVICE_REGISTERS;
		
		TX_Data											: T_SLV_32;
		TX_Valid										: STD_LOGIC;
		TX_Ack											: STD_LOGIC;
		TX_SOT											: STD_LOGIC;
		TX_EOT											: STD_LOGIC;
		
		RX_Data											: T_SLV_32;
		RX_Valid										: STD_LOGIC;
		RX_Ack											: STD_LOGIC;
		RX_SOT											: STD_LOGIC;
		RX_EOT											: STD_LOGIC;
		RX_LastWord									: STD_LOGIC;
		
		FISE_FISType								: T_SATA_FISTYPE;							-- 4 bit
		FISE_Status									: T_SATA_FISENCODER_STATUS;		-- 3 bit
		
		FISD_FISType								: T_SATA_FISTYPE;							-- 4 bit
		FISD_Status									: T_SATA_FISDECODER_STATUS;		-- 3 bit
		
		Link_TX_Data								: T_SLV_32;
		Link_TX_Valid								: STD_LOGIC;
		Link_TX_Ack									: STD_LOGIC;
		Link_TX_SOF									: STD_LOGIC;
		Link_TX_EOF									: STD_LOGIC;
		Link_TX_FS_Valid						: STD_LOGIC;
		Link_TX_FS_Ack							: STD_LOGIC;
		Link_TX_FS_SendOK						: STD_LOGIC;
		Link_TX_FS_Abort						: STD_LOGIC;
		
		Link_RX_Data								: T_SLV_32;
		Link_RX_Valid								: STD_LOGIC;
		Link_RX_Ack									: STD_LOGIC;
		Link_RX_SOF									: STD_LOGIC;
		Link_RX_EOF									: STD_LOGIC;
		Link_RX_FS_Valid						: STD_LOGIC;
		Link_RX_FS_Ack							: STD_LOGIC;
		Link_RX_FS_CRCOK						: STD_LOGIC;
		Link_RX_FS_SyncEsc					: STD_LOGIC;
	end record;
	
	
	-- ===========================================================================
	-- SATA StreamingController Types
	-- ===========================================================================
	type T_SATADBG_SATASC_OUT is record
		-- Transceiver Layer
		TransportLayer			: T_SATADBG_TRANS_OUT;
		Transport_Command		: T_SATA_TRANS_COMMAND;								-- 2 bit
		Transport_Status		: T_SATA_TRANS_STATUS;								-- 3 bit
		Transport_Error			: T_SATA_TRANS_ERROR;									-- 3 bit
		-- Physical Layer
		CommandLayer				: T_SATADBG_CMD_OUT;
		Command_Command			: T_SATA_CMD_COMMAND;									-- 3 bit
		Command_Status			: T_SATA_CMD_STATUS;									-- 3 bit
		Command_Error				: T_SATA_CMD_ERROR;										-- 3 bit
	end record;
	
	-- ===========================================================================
	-- SATA StreamingController Types
	-- ===========================================================================
	type T_SATADBG_SATAS_OUT is record
		-- Transceiver Layer
		TransceiverLayer		: T_SATADBG_TRANSCEIVER_OUT;
		Transceiver_Command	: T_SATA_TRANSCEIVER_COMMAND;
		Transceiver_Status	: T_SATA_TRANSCEIVER_STATUS;
		Transceiver_Error		: T_SATA_TRANSCEIVER_ERROR;
		-- Physical Layer
		PhysicalLayer				: T_SATADBG_PHYSICAL_OUT;
		Physical_Command		: T_SATA_PHY_COMMAND;
		Physical_Status			: T_SATA_PHY_STATUS;									-- 3 bit
		Physical_Error			: T_SATA_PHY_ERROR;
		-- Link Layer
		LinkLayer						: T_SATADBG_LINK_OUT;									-- RX: 125 + TX: 120 bit
		Link_Command				: T_SATA_LINK_COMMAND;								-- 1 bit
		Link_Status					: T_SATA_LINK_STATUS;									-- 3 bit
		Link_Error					: T_SATA_LINK_ERROR;									-- 2 bit
	
		-- Transceiver Layer
		TransportLayer			: T_SATADBG_TRANS_OUT;
		Transport_Command		: T_SATA_TRANS_COMMAND;								-- 2 bit
		Transport_Status		: T_SATA_TRANS_STATUS;								-- 3 bit
		Transport_Error			: T_SATA_TRANS_ERROR;									-- 3 bit
		-- Physical Layer
		CommandLayer				: T_SATADBG_CMD_OUT;
		Command_Command			: T_SATA_CMD_COMMAND;									-- 3 bit
		Command_Status			: T_SATA_CMD_STATUS;									-- 3 bit
		Command_Error				: T_SATA_CMD_ERROR;										-- 3 bit
	end record;
	
	type T_SATADBG_SATAS_IN is record
		TransceiverLayer		: T_SATADBG_TRANSCEIVER_IN;
	end record;
	
	type T_SATADBG_TRANSCEIVER_OUT_VECTOR		is array (NATURAL range <>)	of T_SATADBG_TRANSCEIVER_OUT;
	type T_SATADBG_TRANSCEIVER_IN_VECTOR		is array (NATURAL range <>)	of T_SATADBG_TRANSCEIVER_IN;
	type T_SATADBG_PHYSICAL_OUT_VECTOR			is array (NATURAL range <>)	of T_SATADBG_PHYSICAL_OUT;
	type T_SATADBG_LINK_OUT_VECTOR					is array (NATURAL range <>)	of T_SATADBG_LINK_OUT;
	type T_SATADBG_SATAC_OUT_VECTOR					is array (NATURAL range <>)	of T_SATADBG_SATAC_OUT;
	type T_SATADBG_SATAC_IN_VECTOR					is array (NATURAL range <>)	of T_SATADBG_SATAC_IN;
	
	type T_SATADBG_TRANS_OUT_VECTOR					is array (NATURAL range <>)	of T_SATADBG_TRANS_OUT;
	type T_SATADBG_CMD_OUT_VECTOR						is array (NATURAL range <>)	of T_SATADBG_CMD_OUT;
	type T_SATADBG_SATASC_OUT_VECTOR				is array (NATURAL range <>)	of T_SATADBG_SATASC_OUT;
	
end;

package body satadbg is


end package body;
