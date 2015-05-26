-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Package:					SATA Components
--
-- Description:
-- ------------------------------------
-- For end users:
-- Provides component declarations of the main components
-- "sata_StreamingController" and "sata_SATAController".
--
-- For internal use:
-- Provides component declarations of device-specific transceivers.
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
use			PoC.physical.all;
use			PoC.sata.all;
use			PoC.satadbg.all;
use			PoC.sata_transceivertypes.all;


package satacomp is
	-- ===========================================================================
	-- Component Declarations
	-- ===========================================================================
	COMPONENT sata_StreamingController IS
		GENERIC (
			SIM_WAIT_FOR_INITIAL_REGDH_FIS		: BOOLEAN                     := TRUE;      -- required by ATA/SATA standard
			SIM_EXECUTE_IDENTIFY_DEVICE				: BOOLEAN											:= TRUE;			-- required by CommandLayer: load device parameters
			DEBUG															: BOOLEAN											:= FALSE;			-- generate ChipScope DBG_* signals
			LOGICAL_BLOCK_SIZE_ldB						: POSITIVE										:= 13					-- accessable logical block size: 8 kB (independant from device)
		);
		PORT (
			Clock											: IN	STD_LOGIC;
			ClockEnable								: IN	STD_LOGIC;
			Reset											: IN	STD_LOGIC;
			
			-- ATAStreamingController interface
			-- ========================================================================
			Command										: IN	T_SATA_STREAMC_COMMAND;
			Status										: OUT	T_SATA_STREAMC_STATUS;
			Error											: OUT	T_SATA_STREAMC_ERROR;

			-- debug ports
--			DebugPort									: OUT	T_DBG_SATA_STREAMC_OUT;

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
--			SATA_Command							: OUT	T_SATA_SATACONTROLLER_COMMAND;
			SATA_Status								: IN	T_SATA_SATACONTROLLER_STATUS;
--			SATA_Error								: IN	T_SATA_SATACONTROLLER_ERROR;
		
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
			SATA_TX_FS_SyncEsc				: IN	STD_LOGIC;
			
			-- RX port
			SATA_RX_SOF								: IN	STD_LOGIC;
			SATA_RX_EOF								: IN	STD_LOGIC;
			SATA_RX_Valid							: IN	STD_LOGIC;
			SATA_RX_Data							: IN	T_SLV_32;
			SATA_RX_Ack								: OUT	STD_LOGIC;
			
			SATA_RX_FS_Ack						: OUT	STD_LOGIC;
			SATA_RX_FS_Valid					: IN	STD_LOGIC;
			SATA_RX_FS_CRC_OK					: IN	STD_LOGIC;
			SATA_RX_FS_SyncEsc				: IN	STD_LOGIC
		);
	END COMPONENT;
	
	COMPONENT sata_SATAController IS
		GENERIC (
			DEBUG												: BOOLEAN														:= TRUE;
			CLOCK_IN_FREQ								: FREQ															:= 150.0 MHz;
			PORTS												: POSITIVE													:= 1;												-- Port 0									Port 1
			CONTROLLER_TYPES						: T_SATA_DEVICE_TYPE_VECTOR					:= T_SATA_DEVICE_TYPE_VECTOR'(0 => SATA_DEVICE_TYPE_HOST,	1 => SATA_DEVICE_TYPE_DEVICE);
			INITIAL_SATA_GENERATIONS		: T_SATA_GENERATION_VECTOR					:= T_SATA_GENERATION_VECTOR'(	0 => SATA_GENERATION_1,			1 => SATA_GENERATION_1);
			ALLOW_SPEED_NEGOTIATION			: T_BOOLVEC													:= T_BOOLVEC'(								0 => TRUE,							1 => TRUE);
			ALLOW_STANDARD_VIOLATION		: T_BOOLVEC													:= T_BOOLVEC'(								0 => TRUE,							1 => TRUE);
			ALLOW_AUTO_RECONNECT				: T_BOOLVEC													:= T_BOOLVEC'(								0 => TRUE,							1 => TRUE);
			OOB_TIMEOUT									: T_TIMEVEC													:= T_TIMEVEC'(								0 => TIME'low,					1 => TIME'low);
			GENERATION_CHANGE_COUNT			: T_INTVEC													:= T_INTVEC'(									0 => 8,									1 => 8);
			TRYS_PER_GENERATION					: T_INTVEC													:= T_INTVEC'(									0 => 5,									1 => 3);
			AHEAD_CYCLES_FOR_INSERT_EOF	: T_INTVEC													:= T_INTVEC'(									0 => 1,									1 => 1);
			MAX_FRAME_SIZE_B						: T_INTVEC													:= T_INTVEC'(									0 => 4 * (2048 + 1),		1 => 4 * (2048 + 1))
		);
		PORT (
			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock: initialisation done
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async: reset all / hard reset
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async: all clocks are stable
			
			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			SATA_Reset								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock: clock is stable
			
			-- Debug ports
			DebugPortIn								: IN	T_SATADBG_SATAC_IN_VECTOR(PORTS - 1 DOWNTO 0);
			DebugPortOut							: OUT	T_SATADBG_SATAC_OUT_VECTOR(PORTS - 1 DOWNTO 0);
			
			Command										: IN	T_SATA_SATACONTROLLER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT T_SATA_SATACONTROLLER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			Error											: OUT	T_SATA_SATACONTROLLER_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
			SATAGeneration            : OUT T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- TX port
			TX_SOF										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_EOF										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Valid									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_Ack										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_InsertEOF							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_FS_Ack									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_FS_Valid								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_FS_SendOK							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_FS_SyncEsc							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- RX port
			RX_SOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_EOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Valid									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_Ack										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			RX_FS_Ack									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_FS_Valid								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_FS_CRC_OK							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_FS_SyncEsc							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT sata_Transceiver_Virtex5_GTP IS
		GENERIC (
			DEBUG											: BOOLEAN											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
			ENABLE_DEBUGPORT					: BOOLEAN											:= FALSE;																		-- enables the assignment of signals to the debugport
			CLOCK_IN_FREQ							: FREQ												:= 150.0 MHz;																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																				-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3	=> C_SATA_GENERATION_MAX)				-- intial SATA Generation
		);
		PORT (
			Reset											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			PowerDown									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			Error											: OUT	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

			-- debug ports
			DebugPortIn								: IN	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 DOWNTO 0);
			DebugPortOut							: OUT	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 DOWNTO 0);

			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_SATAGeneration					: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			OOB_TX_Command						: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_TX_Complete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_RX_Received						: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);		
			OOB_HandshakeComplete			: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SLVV_4(PORTS - 1 DOWNTO 0);

			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SLVV_4(PORTS - 1 DOWNTO 0);
			RX_Valid									: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT sata_Transceiver_Virtex6_GTXE1 IS
		GENERIC (
			DEBUG											: BOOLEAN											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
			ENABLE_DEBUGPORT					: BOOLEAN											:= FALSE;																		-- enables the assignment of signals to the debugport
			CLOCK_IN_FREQ							: FREQ												:= 150.0 MHz;																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																				-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3	=> C_SATA_GENERATION_MAX)			-- intial SATA Generation
		);
		PORT (
			Reset											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			PowerDown									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			Error											: OUT	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

			-- debug ports
			DebugPortIn								: IN	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 DOWNTO 0);
			DebugPortOut							: OUT	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 DOWNTO 0);

			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_SATAGeneration					: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			OOB_TX_Command						: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_TX_Complete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_RX_Received						: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);		
			OOB_HandshakeComplete			: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SLVV_4(PORTS - 1 DOWNTO 0);

			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SLVV_4(PORTS - 1 DOWNTO 0);
			RX_Valid									: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;
	
	COMPONENT sata_Transceiver_Series7_GTXE2 IS
		GENERIC (
			DEBUG											: BOOLEAN											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
			ENABLE_DEBUGPORT					: BOOLEAN											:= FALSE;																		-- enables the assignment of signals to the debugport
			CLOCK_IN_FREQ							: FREQ												:= 150.0 MHz;																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																				-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3	=> C_SATA_GENERATION_MAX)			-- intial SATA Generation
		);
		PORT (
			Reset											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			PowerDown									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			Error											: OUT	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

			-- debug ports
			DebugPortIn								: IN	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 DOWNTO 0);
			DebugPortOut							: OUT	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 DOWNTO 0);

			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			SATA_Clock_Stable					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_SATAGeneration					: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			OOB_TX_Command						: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_TX_Complete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_RX_Received						: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);		
			OOB_HandshakeComplete			: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_AlignDetected    			: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SLVV_4(PORTS - 1 DOWNTO 0);

			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SLVV_4(PORTS - 1 DOWNTO 0);
			RX_Valid									: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;
	
	COMPONENT sata_Transceiver_Stratix2GX_GXB IS
		GENERIC (
			CLOCK_IN_FREQ							: FREQ												:= 150.0 MHz;																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		PORT (
			Reset											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			PowerDown									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			Error											: OUT	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

			-- debug ports
--			DebugPortIn								: IN	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 DOWNTO 0);
--			DebugPortOut							: OUT	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 DOWNTO 0);

			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_SATAGeneration					: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			OOB_TX_Command						: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_TX_Complete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_RX_Received						: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);		
			OOB_HandshakeComplete			: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SLVV_4(PORTS - 1 DOWNTO 0);

			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SLVV_4(PORTS - 1 DOWNTO 0);
			RX_Valid									: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;
	
	COMPONENT sata_Transceiver_Stratix4GX_GXB IS
		GENERIC (
			CLOCK_IN_FREQ							: FREQ												:= 150.0 MHz;																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		PORT (
			Reset											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			PowerDown									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			Error											: OUT	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

			-- debug ports
--			DebugPortIn								: IN	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 DOWNTO 0);
--			DebugPortOut							: OUT	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 DOWNTO 0);

			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_SATAGeneration					: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			OOB_TX_Command						: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_TX_Complete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_RX_Received						: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);		
			OOB_HandshakeComplete			: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SLVV_4(PORTS - 1 DOWNTO 0);

			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SLVV_4(PORTS - 1 DOWNTO 0);
			RX_Valid									: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;

END;

PACKAGE BODY satacomp IS

END PACKAGE BODY;
