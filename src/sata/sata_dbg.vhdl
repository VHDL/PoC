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
use			PoC.sata_TransceiverTypes.all;


package satadbg is
	-- ===========================================================================
	-- SATA Transceiver Types
	-- ===========================================================================
	TYPE T_SATADBG_TRANSCEIVEROUT IS RECORD
		RX_ElectricalIDLE			: STD_LOGIC;
		RX_Data								: T_SLV_32;
		RX_CiK								: T_SATA_CIK;
		TX_Data								: T_SLV_32;
		TX_CiK								: T_SATA_CIK;
	END RECORD;
	
	
	-- ===========================================================================
	-- SATA Physical Layer Types
	-- ===========================================================================
	TYPE T_SATADBG_PHYSICALOUT IS RECORD
		GenerationChanges			: UNSIGNED(3 DOWNTO 0);
		TrysPerGeneration			: UNSIGNED(3 DOWNTO 0);
		SATAGeneration				: T_SATA_GENERATION;
		RX_Data								: T_SLV_32;
		RX_CiK								: T_SATA_CIK;
		TX_Data								: T_SLV_32;
		TX_CiK								: T_SATA_CIK;
	END RECORD;
	
	
	-- ===========================================================================
	-- SATA Link Layer Types
	-- ===========================================================================
	TYPE T_SATADBG_LINKOUT IS RECORD
		RX_ElectricalIDLE			: STD_LOGIC;
		RX_Data								: T_SLV_32;
		RX_CiK								: T_SATA_CIK;
		TX_Data								: T_SLV_32;
		TX_CiK								: T_SATA_CIK;
	END RECORD;
	
	
	-- ===========================================================================
	-- SATA Controller Types
	-- ===========================================================================
	TYPE T_SATADBG_SATACOUT IS RECORD
		Transceiver						: T_SATADBG_TRANSCEIVEROUT;
		Physical							: T_SATADBG_PHYSICALOUT;
		Link									: T_SATADBG_LINKOUT;
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

	
	
	
	
	-- ===========================================================================
	-- ATA Drive Information
	-- ===========================================================================
	
	
	
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

-- 	TYPE T_DBG_TRANSIN IS RECORD
-- -- 		ClkMux							: STD_LOGIC;
-- 		
-- 	END RECORD;

--	TYPE T_DBG_TRANSOUT IS RECORD
-- 		PLL_Reset						: STD_LOGIC;
-- 		TXPLL_Locked				: STD_LOGIC;
-- 		RXPLL_Locked				: STD_LOGIC;
-- 
-- 		MMCM_Reset					: STD_LOGIC;
-- 		MMCM_Locked					: STD_LOGIC;
-- 
-- 		RefClock						: STD_LOGIC;
-- 		TXOutClock					: STD_LOGIC;
-- 		RXRecClock					: STD_LOGIC;
-- 		SATAClock						: STD_LOGIC;
--		leds 		: std_logic_vector(7 downto 0);
--		seg7		: std_logic_vector(15 downto 0);
--	END RECORD;

-- 	TYPE T_DBG_SATAIN IS RECORD
-- 		LinkLayer						: T_DBG_LINKIN;
-- 		PhysicalLayer				: T_DBG_PHYIN;
-- 		Transceiverlayer		: T_DBG_TRANSIN;
-- 	END RECORD;

--	TYPE T_DBG_SATAOUT IS RECORD
--		LinkLayer						: T_DBG_LINKOUT;
--		PhysicalLayer				: T_DBG_PHYOUT;
--		TransceiverLayer		: T_DBG_TRANSOUT;
--	END RECORD;

--	TYPE T_DBG_PHYIN_VECTOR			IS ARRAY(NATURAL RANGE <>) OF T_DBG_PHYIN;
--	TYPE T_DBG_PHYOUT_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_DBG_PHYOUT;

--	TYPE T_DBG_TRANSIN_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_DBG_TRANSIN;
--	TYPE T_DBG_TRANSOUT_VECTOR	IS ARRAY(NATURAL RANGE <>) OF T_DBG_TRANSOUT;

--	TYPE T_DBG_LINKOUT_VECTOR	IS ARRAY(NATURAL RANGE <>) OF T_DBG_LINKOUT;
	
--	TYPE T_DBG_SATAIN_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_DBG_SATAIN;
--	TYPE T_DBG_SATAOUT_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_DBG_SATAOUT;
	
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
