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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.sata.all;


package satadbg is
	-- ===========================================================================
	-- SATA Transceiver Types
	-- ===========================================================================
	TYPE T_SATADBG_TRANSCEIVER_OUT IS RECORD
		ClockNetwork_Reset				: STD_LOGIC;
		ClockNetwork_ResetDone		: STD_LOGIC;
		Reset											: STD_LOGIC;
		ResetDone									: STD_LOGIC;
		PowerDown									: STD_LOGIC;
		CPLL_Reset								: STD_LOGIC;
		CPLL_Locked								: STD_LOGIC;
		OOB_Clock									: STD_LOGIC;
		RP_SATAGeneration					: T_SATA_GENERATION;
		RP_Reconfig								: STD_LOGIC;
		RP_ReconfigComplete				: STD_LOGIC;
		RP_ConfigRealoaded				: STD_LOGIC;
		DD_NoDevice								: STD_LOGIC;
		DD_NewDevice							: STD_LOGIC;
		TX_RateSelection					: STD_LOGIC_VECTOR(2 DOWNTo 0);
		RX_RateSelection					: STD_LOGIC_VECTOR(2 DOWNTo 0);
		TX_RateSelectionDone			: STD_LOGIC;
		RX_RateSelectionDone			: STD_LOGIC;
		TX_Reset									: STD_LOGIC;
		RX_Reset									: STD_LOGIC;
		TX_ResetDone							: STD_LOGIC;
		RX_ResetDone							: STD_LOGIC;
		
		TX_Data										: T_SLV_32;
		TX_CharIsK								: T_SLV_4;
		TX_ComInit								: STD_LOGIC;
		TX_ComWake								: STD_LOGIC;
		TX_ComFinish							: STD_LOGIC;
		TX_ElectricalIDLE					: STD_LOGIC;

		RX_Data										: T_SLV_32;
		RX_CharIsK								: T_SLV_4;
		RX_CharIsComma						: T_SLV_4;
		RX_CommaDetected					: STD_LOGIC;
		RX_ByteIsAligned					: STD_LOGIC;
		RX_ElectricalIDLE					: STD_LOGIC;
		RX_ComInitDetected				: STD_LOGIC;
		RX_ComWakeDetected				: STD_LOGIC;
		RX_Valid									: STD_LOGIC;
		RX_Status									: STD_LOGIC_VECTOR(2 DOWNTO 0);
		RX_ClockCorrectionStatus	: STD_LOGIC_VECTOR(1 DOWNTO 0);
	END RECORD;
	
	TYPE T_SATADBG_TRANSCEIVER_IN IS RECORD
		ForceOOBCommand						: T_SATA_OOB;
		ForceTXElectricalIdle			: STD_LOGIC;
	END RECORD;
	
	-- ===========================================================================
	-- SATA Physical Layer Types
	-- ===========================================================================
	TYPE T_SATADBG_PHYSICAL_OOBCONTROL_OUT IS RECORD
		TX_OOB_Command						: T_SATA_OOB;
		TX_OOB_Complete						: STD_LOGIC;
		RX_OOB_Status							: T_SATA_OOB;
		OOB_HandshakingComplete		: STD_LOGIC;
		
		FSM												: STD_LOGIC_VECTOR(3 DOWNTO 0);
	END RECORD;
	
	TYPE T_SATADBG_PHYSICAL_SPEEDCONTROL_OUT IS RECORD
		FSM												: STD_LOGIC_VECTOR(2 DOWNTO 0);
		GenerationChanges					: STD_LOGIC_VECTOR(7 DOWNTO 0);
		TrysPerGeneration					: STD_LOGIC_VECTOR(7 DOWNTO 0);
		SATAGeneration						: T_SATA_GENERATION;
	END RECORD;
	
	TYPE T_SATADBG_PHYSICAL_OUT IS RECORD
		OOB_Retry									: STD_LOGIC;
		OOB_Timeout								: STD_LOGIC;
		Link_OK										: STD_LOGIC;
		Link_Dead									: STD_LOGIC;
	
		RX_Data										: T_SLV_32;
		RX_CiK										: T_SLV_4;
		TX_Data										: T_SLV_32;
		TX_CiK										: T_SLV_4;
		
		OOBControl								: T_SATADBG_PHYSICAL_OOBCONTROL_OUT;
		SpeedControl							: T_SATADBG_PHYSICAL_SPEEDCONTROL_OUT;
	END RECORD;
	
	
	-- ===========================================================================
	-- SATA Link Layer Types
	-- ===========================================================================
	TYPE T_SATADBG_LINK_OUT IS RECORD
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
		RX_DataReg_en1							: STD_LOGIC;
		RX_DataReg_en2							: STD_LOGIC;
		-- RX: before RX_FIFO
		RX_FIFO_SpaceAvailable			: STD_LOGIC;
		RX_FIFO_rst									: STD_LOGIC;
		RX_FIFO_put									: STD_LOGIC;
		RX_FSFIFO_rst								: STD_LOGIC;
		RX_FSFIFO_put								: STD_LOGIC;
		-- RX: after RX_FIFO
		RX_Data											: T_SLV_32;
		RX_Valid										: STD_LOGIC;
		RX_Ready										: STD_LOGIC;
		RX_SOF											: STD_LOGIC;
		RX_EOF											: STD_LOGIC;
		RX_FS_Valid									: STD_LOGIC;
		RX_FS_Ready									: STD_LOGIC;
		RX_FS_CRCOK									: STD_LOGIC;
		RX_FS_Abort									: STD_LOGIC;
		--																													=> 125 bit
		-- TX: from Link Layer
		TX_Data											: T_SLV_32;
		TX_Valid										: STD_LOGIC;
		TX_Ready										: STD_LOGIC;
		TX_SOF											: STD_LOGIC;
		TX_EOF											: STD_LOGIC;
		TX_FS_Valid									: STD_LOGIC;
		TX_FS_Ready									: STD_LOGIC;
		TX_FS_Send_OK								: STD_LOGIC;
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
	END RECORD;		--																							=> 120 bit
	
	
	-- ===========================================================================
	-- SATA Controller Types
	-- ===========================================================================
	TYPE T_SATADBG_SATAC_OUT IS RECORD
		-- Transceiver Layer
		Transceiver						: T_SATADBG_TRANSCEIVER_OUT;
		Transceiver_Command		: T_SATA_TRANSCEIVER_COMMAND;
		Transceiver_Status		: T_SATA_TRANSCEIVER_STATUS;
		Transceiver_TX_Error	: T_SATA_TRANSCEIVER_TX_ERROR;
		Transceiver_RX_Error	: T_SATA_TRANSCEIVER_RX_ERROR;
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
	END RECORD;
	
	TYPE T_SATADBG_SATAC_IN IS RECORD
		Transceiver						: T_SATADBG_TRANSCEIVER_IN;
	END RECORD;
	-- ===========================================================================
	-- ATA Command Layer types
	-- ===========================================================================
	
	
	
	

	-- ===========================================================================
	-- SATA Transport Layer Types
	-- ===========================================================================
	
	
	
	
	
	-- ===========================================================================
	-- SATA StreamingController Types
	-- ===========================================================================

	
	
	type T_SATADBG_TRANSCEIVER_OUT_VECTOR		is array (NATURAL range <>)	of T_SATADBG_TRANSCEIVER_OUT;
	type T_SATADBG_TRANSCEIVER_IN_VECTOR		is array (NATURAL range <>)	of T_SATADBG_TRANSCEIVER_IN;
	type T_SATADBG_PHYSICAL_OUT_VECTOR			is array (NATURAL range <>)	of T_SATADBG_PHYSICAL_OUT;
	type T_SATADBG_LINK_OUT_VECTOR					is array (NATURAL range <>)	of T_SATADBG_LINK_OUT;
	type T_SATADBG_SATAC_OUT_VECTOR					is array (NATURAL range <>)	of T_SATADBG_SATAC_OUT;
	type T_SATADBG_SATAC_IN_VECTOR					is array (NATURAL range <>)	of T_SATADBG_SATAC_IN;
	
--	TYPE T_DBG_PHYOUT IS RECORD
--		GenerationChanges		: UNSIGNED(3 DOWNTO 0);
--		TrysPerGeneration		: UNSIGNED(3 DOWNTO 0);
--		SATAGeneration			: T_SATA_GENERATION;
--		SATAStatus					: T_SATA_STATUS;
--		SATAError						: T_SATA_ERROR;
--	END RECORD;
--
--	TYPE T_DBG_LINKOUT IS RECORD
--		RX_Primitive				: T_SATA_PRIMITIVE;
--	END RECORD;

--	TYPE T_DBG_COMMAND_OUT IS RECORD
--		Command											: T_SATA_CMD_COMMAND;
--		Status											: T_SATA_CMD_STATUS;
--		Error												: T_SATA_CMD_ERROR;
--		
--		SOR													: STD_LOGIC;
--		EOR													: STD_LOGIC;
--		
--		DriveInformation						: T_DRIVE_INFORMATION;
--	END RECORD;
--	
--	TYPE T_DBG_TRANSPORT_OUT IS RECORD
--		Command											: T_SATA_TRANS_COMMAND;
--		Status											: T_SATA_TRANS_STATUS;
--		Error												: T_SATA_TRANS_ERROR;
--		
--		UpdateATAHostRegisters			: STD_LOGIC;
--		ATAHostRegisters						: T_SATA_HOST_REGISTERS;
--		UpdateATADeviceRegisters		: STD_LOGIC;
--		ATADeviceRegisters					: T_SATA_DEVICE_REGISTERS;
--		
--		FISE_FISType								: T_SATA_FISTYPE;
--		FISE_Status									: T_FISENCODER_STATUS;
--		FISD_FISType								: T_SATA_FISTYPE;
--		FISD_Status									: T_FISDECODER_STATUS;
--		
--		SOF													: STD_LOGIC;
--		EOF													: STD_LOGIC;
--		SOT													: STD_LOGIC;
--		EOT													: STD_LOGIC;
--	END RECORD;
--
--	TYPE T_DBG_SATA_STREAMC_OUT IS RECORD
--		CommandLayer								: T_DBG_COMMAND_OUT;
--		TransportLayer							: T_DBG_TRANSPORT_OUT;
--	END RECORD;
--	
--	TYPE T_DBG_SATA_STREAMCM_OUT IS RECORD
--		RunAC_Address : STD_LOGIC_VECTOR(4 DOWNTO 0);
--		Run_Complete  : STD_LOGIC;
--		Error         : STD_LOGIC;
--		Idle          : STD_LOGIC;
--		DataOut       : T_SLV_32;
--	END RECORD;
--
--	TYPE T_DBG_SATA_STREAMCM_IN IS RECORD
--		SATAC_DebugPortOut	: T_DBG_SATAOUT;
--		SATA_STREAMC_DebugPortOut	: T_DBG_SATA_STREAMC_OUT;
--	END RECORD;
	
END;

PACKAGE BODY satadbg IS


END PACKAGE BODY;
