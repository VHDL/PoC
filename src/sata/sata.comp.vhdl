-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Package:					SATA components
--
-- Description:
-- ------------------------------------
-- For end users:
-- Provides component declarations of the main components
-- "sata_StreamingLayer" and "sata_SATAController".
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
	-- component Declarations
	-- ===========================================================================
	component sata_StreamingLayer IS
		generic (
			ENABLE_DEBUGport							: BOOLEAN									:= FALSE;			-- export internal signals to upper layers for debug purposes
			DEBUG													: BOOLEAN									:= FALSE;
			SIM_EXECUTE_IDENTIFY_DEVICE		: BOOLEAN									:= TRUE;			-- required by CommandLayer: load device parameters
			LOGICAL_BLOCK_SIZE						: MEMORY 									:= 8 KiB			-- accessable logical block size: 8 KiB (independant from device)
		);																																			-- 8 KiB, maximum supported is 64 KiB, with 512 B device logical blocks
		port (
			Clock													: in	STD_LOGIC;
			ClockEnable										: in	STD_LOGIC;
			Reset													: in	STD_LOGIC;

			-- CommandLayer interface
			-- ========================================================================
			Command												: in	T_SATA_STREAMING_COMMAND;
			Status												: out	T_SATA_STREAMING_STATUS;
			Error													: out	T_SATA_STREAMING_ERROR;

			DebugportOut									: out T_SATADBG_STREAMING_OUT;

			-- for measurement purposes only
			Config_BurstSize							: in	T_SLV_16;
			
			-- address interface (valid on Command /= *_NONE)
			Address_AppLB									: in	T_SLV_48;
			BlockCount_AppLB							: in	T_SLV_48;
			
			-- 
			DriveInformation							: out T_SATA_DRIVE_INFORMATION;

			-- TX path
			TX_Valid											: in	STD_LOGIC;
			TX_Data												: in	T_SLV_32;
			TX_SOR												: in	STD_LOGIC;
			TX_EOR												: in	STD_LOGIC;
			TX_Ack												: out	STD_LOGIC;

			-- RX path
			RX_Valid											: out	STD_LOGIC;
			RX_Data												: out	T_SLV_32;
			RX_SOR												: out	STD_LOGIC;
			RX_EOR												: out	STD_LOGIC;
			RX_Ack												: in	STD_LOGIC;

			-- TransportLayer interface
			-- ========================================================================
			SATAC_ResetDone 							: in  STD_LOGIC;
			SATAC_Command									: out	T_SATA_TRANS_COMMAND;
			SATAC_Status									: in	T_SATA_SATACONTROLLER_STATUS;
			SATAC_Error										: in	T_SATA_SATACONTROLLER_ERROR;
			
			-- ATA registers
			SATAC_ATAHostRegisters				: out	T_SATA_ATA_HOST_REGISTERS;
			SATAC_ATADeviceRegisters			: in	T_SATA_ATA_DEVICE_REGISTERS;
			
			-- TX path
			SATAC_TX_Valid								: out	STD_LOGIC;
			SATAC_TX_Data									: out	T_SLV_32;
			SATAC_TX_SOT									: out	STD_LOGIC;
			SATAC_TX_EOT									: out	STD_LOGIC;
			SATAC_TX_Ack									: in	STD_LOGIC;

			-- RX path
			SATAC_RX_Valid								: in	STD_LOGIC;
			SATAC_RX_Data									: in	T_SLV_32;
			SATAC_RX_SOT									: in	STD_LOGIC;
			SATAC_RX_EOT									: in	STD_LOGIC;
			SATAC_RX_Ack									: out	STD_LOGIC
		);
	end component;
	
	component sata_SATAController IS
		generic (
			DEBUG														: BOOLEAN											:= FALSE;
			ENABLE_DEBUGport								: BOOLEAN											:= FALSE;
			-- transceiver settings
			REFCLOCK_FREQ										: FREQ												:= 150 MHz;
			PORTS														: POSITIVE										:= 2;	-- port 0									port 1
			-- physical layer settings
			CONTROLLER_TYPES								: T_SATA_DEVICE_TYPE_VECTOR		:= (0 => SATA_DEVICE_TYPE_HOST,	1 => SATA_DEVICE_TYPE_HOST);
			INITIAL_SATA_GENERATIONS				: T_SATA_GENERATION_VECTOR		:= (0 => C_SATA_GENERATION_MAX,	1 => C_SATA_GENERATION_MAX);
			ALLOW_SPEED_NEGOTIATION					: T_BOOLVEC										:= (0 => TRUE,									1 => TRUE);
			ALLOW_STANDARD_VIOLATION				: T_BOOLVEC										:= (0 => TRUE,									1 => TRUE);
			OOB_TIMEOUT											: T_TIMEVEC										:= (0 => TIME'low,							1 => TIME'low);
			GENERATION_CHANGE_COUNT					: T_INTVEC										:= (0 => 8,											1 => 8);
			ATTEMPTS_PER_GENERATION					: T_INTVEC										:= (0 => 5,											1 => 3);
			-- linklayer settings
			AHEAD_CYCLES_FOR_INSERT_EOF			: T_INTVEC										:= (0 => 1,											1 => 1);
			MAX_FRAME_SIZE									: T_MEMVEC										:= (0 => C_SATA_MAX_FRAMESIZE,	1 => C_SATA_MAX_FRAMESIZE);
			-- transport layer settings
			SIM_WAIT_FOR_INITIAL_REGDH_FIS	: BOOLEAN											:= TRUE;       -- required by ATA/SATA standard
			ENABLE_GLUE_FIFOS								: BOOLEAN											:= FALSE
		);
		port (
			ClockNetwork_Reset					: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);						-- @async:			asynchronous reset
			ClockNetwork_ResetDone			: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);						-- @async:			all clocks are stable
			PowerDown										: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);						-- @async:			
			Reset												: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);						-- @SATA_Clock:	synchronous reset, done in next cycle
			ResetDone										: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);						-- @SATA_Clock: layers have been resetted after powerup / hard reset
			
			SATAGenerationMin						: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);		-- 
			SATAGenerationMax						: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);		-- 
			SATAGeneration          	  : out T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);
			
			SATA_Clock									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			SATA_Clock_Stable						: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			Command											: in	T_SATA_TRANS_COMMAND_VECTOR(PORTS - 1 downto 0);
			Status											: out T_SATA_SATACONTROLLER_STATUS_VECTOR(PORTS - 1 downto 0);
			Error												: out	T_SATA_SATACONTROLLER_ERROR_VECTOR(PORTS - 1 downto 0);
			ATAHostRegisters						: in	T_SATA_ATA_HOST_REGISTERS_VECTOR(PORTS - 1 downto 0);
			ATADeviceRegisters					: out	T_SATA_ATA_DEVICE_REGISTERS_VECTOR(PORTS - 1 downto 0);

			-- Debug PORTS
			DebugportIn									: in	T_SATADBG_SATACONTROLLER_IN_VECTOR(PORTS - 1 downto 0);
			DebugportOut								: out	T_SATADBG_SATACONTROLLER_OUT_VECTOR(PORTS - 1 downto 0);
			
			-- TX port
			TX_SOT											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			TX_EOT											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			TX_Valid										: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			TX_Data											: in	T_SLVV_32(PORTS - 1 downto 0);
			TX_Ack											: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			-- RX port
			RX_SOT											: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RX_EOT											: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RX_Valid										: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RX_Data											: out	T_SLVV_32(PORTS - 1 downto 0);
			RX_Ack											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			-- vendor specific signals
			VSS_Common_In								: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In							: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS - 1 downto 0);
			VSS_Private_Out							: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 downto 0)
		);
	end component;

	component sata_Transceiver_Virtex5_GTP IS
		generic (
			DEBUG											: BOOLEAN											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
			ENABLE_DEBUGport					: BOOLEAN											:= FALSE;																		-- enables the assignment of signals to the debugport
			CLOCK_IN_FREQ							: FREQ												:= 150 MHz;																	-- 150 MHz
			PORTS											: POSITIVE										:= 2;																				-- Number of PORTS per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3	=> C_SATA_GENERATION_MAX)				-- intial SATA Generation
		);
		port (
			Reset											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ResetDone									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_Reset				: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_ResetDone		: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			PowerDown									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			Command										: in	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 downto 0);
			Status										: out	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 downto 0);
			Error											: out	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 downto 0);

			-- debug PORTS
			DebugportIn								: in	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 downto 0);
			DebugportOut							: out	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 downto 0);

			SATA_Clock								: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			RP_Reconfig								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_SATAGeneration					: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);
			RP_ReconfigComplete				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_ConfigReloaded					: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Locked									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			OOB_TX_Command						: in	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
			OOB_TX_Complete						: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			OOB_RX_Received						: out	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);		
			OOB_HandshakeComplete			: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			TX_Data										: in	T_SLVV_32(PORTS - 1 downto 0);
			TX_CharIsK								: in	T_SLVV_4(PORTS - 1 downto 0);

			RX_Data										: out	T_SLVV_32(PORTS - 1 downto 0);
			RX_CharIsK								: out	T_SLVV_4(PORTS - 1 downto 0);
			RX_Valid									: out STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			-- vendor specific signals
			VSS_Common_In							: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 downto 0);
			VSS_Private_Out						: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 downto 0)
		);
	end component;

	component sata_Transceiver_Virtex6_GTXE1 IS
		generic (
			DEBUG											: BOOLEAN											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
			ENABLE_DEBUGport					: BOOLEAN											:= FALSE;																		-- enables the assignment of signals to the debugport
			CLOCK_IN_FREQ							: FREQ												:= 150 MHz;																	-- 150 MHz
			PORTS											: POSITIVE										:= 2;																				-- Number of PORTS per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3	=> C_SATA_GENERATION_MAX)			-- intial SATA Generation
		);
		port (
			Reset											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ResetDone									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_Reset				: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_ResetDone		: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			PowerDown									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			Command										: in	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 downto 0);
			Status										: out	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 downto 0);
			Error											: out	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 downto 0);

			-- debug PORTS
			DebugportIn								: in	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 downto 0);
			DebugportOut							: out	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 downto 0);

			SATA_Clock								: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			RP_Reconfig								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_SATAGeneration					: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);
			RP_ReconfigComplete				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_ConfigReloaded					: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Locked									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			OOB_TX_Command						: in	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
			OOB_TX_Complete						: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			OOB_RX_Received						: out	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);		
			OOB_HandshakeComplete			: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			TX_Data										: in	T_SLVV_32(PORTS - 1 downto 0);
			TX_CharIsK								: in	T_SLVV_4(PORTS - 1 downto 0);

			RX_Data										: out	T_SLVV_32(PORTS - 1 downto 0);
			RX_CharIsK								: out	T_SLVV_4(PORTS - 1 downto 0);
			RX_Valid									: out STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			-- vendor specific signals
			VSS_Common_In							: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 downto 0);
			VSS_Private_Out						: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 downto 0)
		);
	end component;
	
	component sata_Transceiver_Series7_GTXE2 IS
		generic (
			DEBUG											: BOOLEAN											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
			ENABLE_DEBUGport					: BOOLEAN											:= FALSE;																		-- enables the assignment of signals to the debugport
			REFCLOCK_FREQ							: FREQ												:= 150 MHz;																	-- 150 MHz
			PORTS											: POSITIVE										:= 2;																				-- Number of PORTS per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3	=> C_SATA_GENERATION_MAX)			-- intial SATA Generation
		);
		port (
			Reset											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ResetDone									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_Reset				: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_ResetDone		: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			PowerDown									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			Command										: in	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 downto 0);
			Status										: out	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 downto 0);
			Error											: out	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 downto 0);

			-- debug PORTS
			DebugportIn								: in	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 downto 0);
			DebugportOut							: out	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 downto 0);

			SATA_Clock								: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			SATA_Clock_Stable					: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			RP_Reconfig								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_SATAGeneration					: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);
			RP_ReconfigComplete				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_ConfigReloaded					: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Locked									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			OOB_TX_Command						: in	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
			OOB_TX_Complete						: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			OOB_RX_Received						: out	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);		
			OOB_HandshakeComplete			: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			OOB_AlignDetected    			: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			TX_Data										: in	T_SLVV_32(PORTS - 1 downto 0);
			TX_CharIsK								: in	T_SLVV_4(PORTS - 1 downto 0);

			RX_Data										: out	T_SLVV_32(PORTS - 1 downto 0);
			RX_CharIsK								: out	T_SLVV_4(PORTS - 1 downto 0);
			RX_Valid									: out STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			-- vendor specific signals
			VSS_Common_In							: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 downto 0);
			VSS_Private_Out						: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 downto 0)
		);
	end component;
	
	component sata_Transceiver_Stratix2GX_GXB IS
		generic (
			CLOCK_IN_FREQ							: FREQ												:= 150 MHz;																	-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of PORTS per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		port (
			Reset											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ResetDone									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_Reset				: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_ResetDone		: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			PowerDown									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			Command										: in	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 downto 0);
			Status										: out	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 downto 0);
			Error											: out	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 downto 0);

			-- debug PORTS
--			DebugportIn								: in	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 downto 0);
--			DebugportOut							: out	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 downto 0);

			SATA_Clock								: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			RP_Reconfig								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_SATAGeneration					: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);
			RP_ReconfigComplete				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_ConfigReloaded					: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Locked									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			OOB_TX_Command						: in	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
			OOB_TX_Complete						: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			OOB_RX_Received						: out	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);		
			OOB_HandshakeComplete			: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			TX_Data										: in	T_SLVV_32(PORTS - 1 downto 0);
			TX_CharIsK								: in	T_SLVV_4(PORTS - 1 downto 0);

			RX_Data										: out	T_SLVV_32(PORTS - 1 downto 0);
			RX_CharIsK								: out	T_SLVV_4(PORTS - 1 downto 0);
			RX_Valid									: out STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			-- vendor specific signals
			VSS_Common_In							: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 downto 0);
			VSS_Private_Out						: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 downto 0)
		);
	end component;
	
	component sata_Transceiver_Stratix4GX_GXB IS
		generic (
			CLOCK_IN_FREQ							: FREQ												:= 150 MHz;																	-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of PORTS per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		port (
			Reset											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ResetDone									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_Reset				: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			ClockNetwork_ResetDone		: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			PowerDown									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			Command										: in	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 downto 0);
			Status										: out	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 downto 0);
			Error											: out	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 downto 0);

			-- debug PORTS
--			DebugportIn								: in	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 downto 0);
--			DebugportOut							: out	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 downto 0);

			SATA_Clock								: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			RP_Reconfig								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_SATAGeneration					: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);
			RP_ReconfigComplete				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_ConfigReloaded					: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			RP_Locked									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

			OOB_TX_Command						: in	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
			OOB_TX_Complete						: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			OOB_RX_Received						: out	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);		
			OOB_HandshakeComplete			: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			TX_Data										: in	T_SLVV_32(PORTS - 1 downto 0);
			TX_CharIsK								: in	T_SLVV_4(PORTS - 1 downto 0);

			RX_Data										: out	T_SLVV_32(PORTS - 1 downto 0);
			RX_CharIsK								: out	T_SLVV_4(PORTS - 1 downto 0);
			RX_Valid									: out STD_LOGIC_VECTOR(PORTS - 1 downto 0);
			
			-- vendor specific signals
			VSS_Common_In							: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 downto 0);
			VSS_Private_Out						: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 downto 0)
		);
	end component;

end;

package body satacomp is

end package body;
