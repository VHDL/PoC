-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Module:					sata_SATAController
--
-- Package:					sata
--
-- Authors:					Patrick Lehmann
--									Steffen Koehler
--									Martin Zabel
--
-- Description:
-- ------------------------------------
-- Provides a SATA link to transport ATA commands and data from host to device
-- and vice versa.
--
-- Reset Procedure:
-- ----------------
-- The SATAController automatically powers up, if inputs PowerDown and
-- ClockNetwork_Reset are low. The SATAController synchronously asserts
-- ResetDone when his Command-Status-Error interface is ready after power-up.
-- It is only deasserted asynchronously in case of asynchronously asserting
-- PowerDown or ClockNetwork_Reset, but both are optional features.
--
-- All upper layers must be hold in reset as long as ResetDone is deasserted.
--
-- The output SATA_Clock_Stable is synchronously asserted if the output
-- SATA_Clock delivers a stable clock signal, so it can be used as clock
-- enable. SATA_Clock_Stable is hight at least one cycle before ResetDone
-- is asserted. 
--
-- SATA_Clock_Stable might be deasserted synchronously when a change of the
-- SATA generation is needed and SATA_Clock is instable for a while. ResetDone
-- is kept asserted because Status and Error are still valid but are not
-- changing until the SATA_Clock is stable again. The inputs Command and
-- (synchronous) Reset are ignored when SATA_Clock_Stable is low.
-- 
-- ClockNetwork_ResetDone is asserted asynchronously when all internal clock
-- networks are stable. This signal can be used for debugging or if another
-- PLL/DLL is connected to SATA_Clock.
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
USE			PoC.physical.ALL;
USE			PoC.sata.ALL;
USE			PoC.satadbg.ALL;
USE			PoC.sata_TransceiverTypes.ALL;


ENTITY sata_SATAController IS
	GENERIC (
		DEBUG												: BOOLEAN														:= FALSE;
		ENABLE_DEBUGPORT						: BOOLEAN														:= FALSE;
		CLOCK_IN_FREQ								: FREQ															:= 150.0 MHz;
--		CLOCK_IN_FREQ_MHZ						: REAL															:= 150.0;
		PORTS												: POSITIVE													:= 2;	-- Port 0									Port 1
		CONTROLLER_TYPES						: T_SATA_DEVICE_TYPE_VECTOR					:= (0 => SATA_DEVICE_TYPE_HOST,	1 => SATA_DEVICE_TYPE_HOST);
		INITIAL_SATA_GENERATIONS		: T_SATA_GENERATION_VECTOR					:= (0 => SATA_GENERATION_2,			1 => SATA_GENERATION_2);
		ALLOW_SPEED_NEGOTIATION			: T_BOOLVEC													:= (0 => TRUE,									1 => TRUE);
		ALLOW_STANDARD_VIOLATION		: T_BOOLVEC													:= (0 => TRUE,									1 => TRUE);
		ALLOW_AUTO_RECONNECT				: T_BOOLVEC													:= (0 => TRUE,									1 => TRUE);
		OOB_TIMEOUT									: T_TIMEVEC													:= (0 => TIME'low,							1 => TIME'low);
--		OOB_TIMEOUT_US							: T_INTVEC													:= (0 => 0,											1 => 0);
		GENERATION_CHANGE_COUNT			: T_INTVEC													:= (0 => 8,											1 => 8);
		ATTEMPTS_PER_GENERATION			: T_INTVEC													:= (0 => 5,											1 => 3);
		AHEAD_CYCLES_FOR_INSERT_EOF	: T_INTVEC													:= (0 => 1,											1 => 1);
		MAX_FRAME_SIZE_B						: T_INTVEC													:= (0 => 4 * (2048 + 1),				1 => 4 * (2048 + 1))
	);
	PORT (
		ClockNetwork_Reset					: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async:			asynchronous reset
		ClockNetwork_ResetDone			: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async:			all clocks are stable
		PowerDown										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async:			
		Reset												: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock:	synchronous reset, done in next cycle
		ResetDone										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock: layers have been resetted after powerup / hard reset
		
		SATAGenerationMin						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);		-- 
		SATAGenerationMax						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);		-- 
		SATAGeneration          	  : OUT T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
		
		SATA_Clock									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		SATA_Clock_Stable						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		Command											: IN	T_SATA_SATACONTROLLER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
		Status											: OUT T_SATA_SATACONTROLLER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
		Error												: OUT	T_SATA_SATACONTROLLER_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

		-- Debug ports
		DebugPortIn									: IN	T_SATADBG_SATAC_IN_VECTOR(PORTS - 1 DOWNTO 0);
		DebugPortOut								: OUT	T_SATADBG_SATAC_OUT_VECTOR(PORTS - 1 DOWNTO 0);
    
		-- TX port
		TX_SOF											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_EOF											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Valid										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Data											: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
		TX_Ack											: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_InsertEOF								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		TX_FS_Ack										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_FS_Valid									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_FS_SendOK								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_FS_Abort									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		-- RX port
		RX_SOF											: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_EOF											: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Valid										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Data											: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
		RX_Ack											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		RX_FS_Ack										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_FS_Valid									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_FS_CRCOK									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_FS_SyncEsc								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		-- vendor specific signals
		VSS_Common_In								: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In							: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS - 1 DOWNTO 0);
		VSS_Private_Out							: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF sata_SATAController IS
	ATTRIBUTE KEEP													: BOOLEAN;

	CONSTANT CONTROLLER_TYPES_I							: T_SATA_DEVICE_TYPE_VECTOR(0 TO PORTS - 1)	:= CONTROLLER_TYPES;
	CONSTANT INITIAL_SATA_GENERATIONS_I			: T_SATA_GENERATION_VECTOR(0 TO PORTS - 1)	:= INITIAL_SATA_GENERATIONS;
	CONSTANT ALLOW_SPEED_NEGOTIATION_I			: T_BOOLVEC(0 TO PORTS - 1)									:= ALLOW_SPEED_NEGOTIATION;
	CONSTANT ALLOW_STANDARD_VIOLATION_I			: T_BOOLVEC(0 TO PORTS - 1)									:= ALLOW_STANDARD_VIOLATION;
	CONSTANT ALLOW_AUTO_RECONNECT_I					: T_BOOLVEC(0 TO PORTS - 1)									:= ALLOW_AUTO_RECONNECT;
	CONSTANT OOB_TIMEOUT_I									: T_TIMEVEC(0 TO PORTS - 1)									:= OOB_TIMEOUT;
--	CONSTANT OOB_TIMEOUT_US_I								: T_INTVEC(0 TO PORTS - 1)									:= OOB_TIMEOUT_US;
	CONSTANT GENERATION_CHANGE_COUNT_I			: T_INTVEC(0 TO PORTS - 1)									:= GENERATION_CHANGE_COUNT;
	CONSTANT ATTEMPTS_PER_GENERATION_I			: T_INTVEC(0 TO PORTS - 1)									:= ATTEMPTS_PER_GENERATION;
	CONSTANT AHEAD_CYCLES_FOR_INSERT_EOF_I	: T_INTVEC(0 TO PORTS - 1)									:= AHEAD_CYCLES_FOR_INSERT_EOF;
	CONSTANT MAX_FRAME_SIZE_B_I							: T_INTVEC(0 TO PORTS - 1)									:= MAX_FRAME_SIZE_B;

	-- Clocking & ResetDone, provided by transceiver layer
	SIGNAL SATA_Clock_i									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL SATA_Clock_Stable_i					: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	-- physical layer <=> transceiver layer signals
	SIGNAL Phy_RP_Reconfig							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_RP_SATAGeneration				: T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_RP_ReconfigComplete		: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_RP_ConfigReloaded			: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_RP_Lock									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_RP_Locked							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	signal Trans_ResetDone							: STD_LOGIC_VECTOR(PORTS-1 DOWNTO 0);
	SIGNAL Trans_Command								: T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_Status									: T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_Error									: T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL Phy_OOB_TX_Command						: T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_OOB_TX_Complete				: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);	
	SIGNAL Trans_OOB_RX_Received				: T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_OOB_HandshakeComplete		: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);	
	signal Phy_OOB_AlignDetected    		: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);	

	SIGNAL Phy_TX_Data									: T_SLVV_32(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_TX_CharIsK								: T_SLVV_4(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_RX_Data								: T_SLVV_32(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_RX_CharIsK							: T_SLVV_4(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_RX_Valid								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL Trans_DebugPortIn						: T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_DebugPortOut						: T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS - 1 DOWNTO 0);
	
	ATTRIBUTE KEEP OF SATA_Clock_i			: SIGNAL IS DEBUG;

BEGIN
	genReport : FOR I IN 0 TO PORTS - 1 GENERATE
		ASSERT FALSE REPORT "Port:    " & INTEGER'image(I)																											SEVERITY NOTE;
		ASSERT FALSE REPORT "  ControllerType:         " & T_SATA_DEVICE_TYPE'image(CONTROLLER_TYPES_I(I))			SEVERITY NOTE;
		ASSERT FALSE REPORT "  AllowSpeedNegotiation:  " & to_string(ALLOW_SPEED_NEGOTIATION_I(I))							SEVERITY NOTE;
		ASSERT FALSE REPORT "  AllowAutoReconnect:     " & to_string(ALLOW_AUTO_RECONNECT_I(I))									SEVERITY NOTE;
		ASSERT FALSE REPORT "  AllowStandardViolation: " & to_string(ALLOW_STANDARD_VIOLATION_I(I))							SEVERITY NOTE;
		ASSERT FALSE REPORT "  Init. SATA Generation:  Gen" & INTEGER'image(INITIAL_SATA_GENERATIONS_I(I) + 1)	SEVERITY NOTE;
	END GENERATE;

	-- generate layer moduls per port
	gen1 : FOR I IN 0 TO PORTS - 1 GENERATE
		
		-- link layer signals
		SIGNAL Link_Reset							: STD_LOGIC;
		signal Link_ResetDone 				: STD_LOGIC;
		SIGNAL Link_Command						: T_SATA_LINK_COMMAND;
		SIGNAL Link_Status						: T_SATA_LINK_STATUS;
		SIGNAL Link_Error							: T_SATA_LINK_ERROR;
		
		-- SATAController <=> link layer signals
		SIGNAL SATAC_TX_SOF						: STD_LOGIC;
		SIGNAL SATAC_TX_EOF						: STD_LOGIC;
		SIGNAL SATAC_TX_Valid					: STD_LOGIC;
		SIGNAL SATAC_TX_Data					: T_SLV_32;
		SIGNAL SATAC_TX_FS_Ack				: STD_LOGIC;
		SIGNAL SATAC_RX_Ack						: STD_LOGIC;
		SIGNAL SATAC_RX_FS_Ack				: STD_LOGIC;

		SIGNAL Link_TX_Ack						: STD_LOGIC;
		SIGNAl Link_TX_InsertEOF			: STD_LOGIC;
		SIGNAL Link_TX_FS_Valid				: STD_LOGIC;
		SIGNAL Link_TX_FS_SendOK			: STD_LOGIC;
		SIGNAL Link_TX_FS_Abort				: STD_LOGIC;
		
		SIGNAL Link_RX_SOF						: STD_LOGIC;
		SIGNAL Link_RX_EOF						: STD_LOGIC;
		SIGNAL Link_RX_Valid					: STD_LOGIC;
		SIGNAL Link_RX_Data						: T_SLV_32;
		SIGNAL Link_RX_FS_Valid				: STD_LOGIC;
		SIGNAL Link_RX_FS_CRCOK				: STD_LOGIC;
		SIGNAL Link_RX_FS_SyncEsc			: STD_LOGIC;

		-- physical layer signals
		signal Phy_ResetDone 					: STD_LOGIC;
		SIGNAL Phy_Command						: T_SATA_PHY_COMMAND;
		SIGNAL Phy_Status							: T_SATA_PHY_STATUS;
		SIGNAl Phy_Error							: T_SATA_PHY_ERROR;

		-- link layer <=> physical layer signals
		SIGNAL Link_TX_Data						: T_SLV_32;
		SIGNAL Link_TX_CharIsK				: T_SLV_4;

		SIGNAL Phy_RX_Data						: T_SLV_32;
		SIGNAL Phy_RX_CharIsK					: T_SLV_4;
		
		-- debug ports
		SIGNAL Link_DebugPortOut			: T_SATADBG_LINK_OUT;
		SIGNAL Phy_DebugPortOut				: T_SATADBG_PHYSICAL_OUT;
		
	BEGIN
		-- =========================================================================
		-- SATAController interface
		-- =========================================================================
		-- common signals
		SATAGeneration(I)							<= Phy_RP_SATAGeneration(I);

		Status(I).LinkLayer						<= Link_Status;
		Status(I).PhysicalLayer				<= Phy_Status;
		Status(I).TransceiverLayer		<= Trans_Status(I);
		
		Error(I).LinkLayer						<= Link_Error;
		Error(I).PhysicalLayer				<= Phy_Error;
		Error(I).TransceiverLayer			<= Trans_Error(I);

		ResetDone(i) 									<= Link_ResetDone;
		
		-- TX port
		SATAC_TX_SOF									<= TX_SOF(I);
		SATAC_TX_EOF									<= TX_EOF(I);
		SATAC_TX_Valid								<= TX_Valid(I);
		SATAC_TX_Data									<= TX_Data(I);
		TX_Ack(I)											<= Link_TX_Ack;
		TX_InsertEOF(I)								<= Link_TX_InsertEOF;
		
		SATAC_TX_FS_Ack								<= TX_FS_Ack(I);
		TX_FS_Valid(I)								<= Link_TX_FS_Valid;
		TX_FS_SendOK(I)								<= Link_TX_FS_SendOK;
		TX_FS_Abort(I)								<= Link_TX_FS_Abort;
		
		-- RX port
		RX_SOF(I)											<= Link_RX_SOF;
		RX_EOF(I)											<= Link_RX_EOF;
		RX_Valid(I)										<= Link_RX_Valid;
		RX_Data(I)										<= Link_RX_Data;
		SATAC_RX_Ack									<= RX_Ack(I);
		
		SATAC_RX_FS_Ack								<= RX_FS_Ack(I);
		RX_FS_Valid(I)								<= Link_RX_FS_Valid;
		RX_FS_CRCOK(I)								<= Link_RX_FS_CRCOK;
		RX_FS_SyncEsc(I)							<= Link_RX_FS_SyncEsc;
		

		-- =======================================================================
		-- Command decoding for SATAController.
		-- 
		-- TODO CHECK: PhysicalLayer accepts commands only in same states.
		-- =======================================================================
		PROCESS(Command, Trans_Status, Reset)
		BEGIN
			
			Link_Reset 										<= Reset(i);
			Link_Command									<= SATA_LINK_CMD_NONE;
			Phy_Command										<= SATA_PHY_CMD_NONE;

			CASE Command(I) IS
				WHEN SATA_SATACTRL_CMD_INIT_CONNECTION =>
					-- Init new conenction with speed negotation
					Link_Reset								<= '1';
					Phy_Command								<= SATA_PHY_CMD_INIT_CONNECTION;
				
				WHEN SATA_SATACTRL_CMD_REINIT_CONNECTION =>
					-- Reinit conenction at same speed as last time
					Link_Reset								<= '1';
					Phy_Command								<= SATA_PHY_CMD_REINIT_CONNECTION;

				WHEN SATA_SATACTRL_CMD_SYNC_LINK =>													
					-- Reset LinkLayer => send SYNC-primitives
					Link_Reset								<= '1';

				when SATA_SATACTRL_CMD_NONE =>
					null;
			end CASE;
		END PROCESS;

		-- =========================================================================
		-- link layer
		-- =========================================================================
		Link : ENTITY PoC.sata_LinkLayer
			GENERIC MAP (
				DEBUG												=> DEBUG,
				ENABLE_DEBUGPORT						=> ENABLE_DEBUGPORT,
				CONTROLLER_TYPE							=> CONTROLLER_TYPES_I(I),
				AHEAD_CYCLES_FOR_INSERT_EOF	=> AHEAD_CYCLES_FOR_INSERT_EOF_I(I),
				MAX_FRAME_SIZE_B						=> MAX_FRAME_SIZE_B_I(I)
			)
			PORT MAP (
				Clock										=> SATA_Clock_i(I),
				ClockEnable							=> SATA_Clock_Stable_i(I),
				Reset										=> Link_Reset,
				
				Command									=> Link_Command,
				Status									=> Link_Status,
				Error										=> Link_Error,
				
				-- Debug ports
				DebugPortOut					 	=> Link_DebugPortOut,
				
				-- TX port
				TX_SOF									=> SATAC_TX_SOF,
				TX_EOF									=> SATAC_TX_EOF,
				TX_Valid								=> SATAC_TX_Valid,
				TX_Data									=> SATAC_TX_Data,
				TX_Ack									=> Link_TX_Ack,
				TX_InsertEOF						=> Link_TX_InsertEOF,
				
				TX_FS_Ack								=> SATAC_TX_FS_Ack,
				TX_FS_Valid							=> Link_TX_FS_Valid,
				TX_FS_SendOK						=> Link_TX_FS_SendOK,
				TX_FS_Abort							=> Link_TX_FS_Abort,
				
				-- RX port
				RX_SOF									=> Link_RX_SOF,
				RX_EOF									=> Link_RX_EOF,
				RX_Valid								=> Link_RX_Valid,
				RX_Data									=> Link_RX_Data,
				RX_Ack									=> SATAC_RX_Ack,
				
				RX_FS_Ack								=> SATAC_RX_FS_Ack,
				RX_FS_Valid							=> Link_RX_FS_Valid,
				RX_FS_CRCOK							=> Link_RX_FS_CRCOK,
				RX_FS_SyncEsc						=> Link_RX_FS_SyncEsc,
				
				-- physical layer interface
				Phy_ResetDone 					=> Phy_ResetDone,
				Phy_Status							=> Phy_Status,
				
				Phy_RX_Data							=> Phy_RX_Data,
				Phy_RX_CharIsK					=> Phy_RX_CharIsK,
				
				Phy_TX_Data							=> Link_TX_Data,
				Phy_TX_CharIsK					=> Link_TX_CharIsK
			);

		-- The CSE interface of the Linklayer is ready, when the CSE interface
		-- of the PHY is ready.
		Link_ResetDone <= Phy_ResetDone;

		-- =========================================================================
		-- physical layer
		-- =========================================================================
		Phy : ENTITY PoC.sata_PhysicalLayer
			GENERIC MAP (
				DEBUG													=> DEBUG,
				ENABLE_DEBUGPORT							=> ENABLE_DEBUGPORT,
				CLOCK_FREQ										=> CLOCK_IN_FREQ,
				CONTROLLER_TYPE								=> CONTROLLER_TYPES_I(I),
				ALLOW_SPEED_NEGOTIATION				=> ALLOW_SPEED_NEGOTIATION_I(I),
				INITIAL_SATA_GENERATION				=> INITIAL_SATA_GENERATIONS_I(I),
				ALLOW_AUTO_RECONNECT					=> ALLOW_AUTO_RECONNECT_I(I),
				ALLOW_STANDARD_VIOLATION			=> ALLOW_STANDARD_VIOLATION_I(I),
				OOB_TIMEOUT										=> OOB_TIMEOUT_I(I),		--ite(SIMULATION, 15, OOB_TIMEOUT_US(I)),			-- simulation: limit OOBTimeout to 15 us 
				GENERATION_CHANGE_COUNT				=> GENERATION_CHANGE_COUNT_I(I),
				ATTEMPTS_PER_GENERATION				=> ATTEMPTS_PER_GENERATION_I(I)
			)
			PORT MAP (
				Clock													=> SATA_Clock_i(I),
				ClockEnable										=> SATA_Clock_Stable_i(i),
				Reset													=> Reset(i),
				SATAGenerationMin							=> SATAGenerationMin(I),
				SATAGenerationMax							=> SATAGenerationMax(I),

				Command												=> Phy_Command,
				Status												=> Phy_Status,
				Error													=> Phy_Error,

				DebugPortOut									=> Phy_DebugPortOut,
				
				Link_RX_Data									=> Phy_RX_Data,
				Link_RX_CharIsK								=> Phy_RX_CharIsK,
				
				Link_TX_Data									=> Link_TX_Data,
				Link_TX_CharIsK								=> Link_TX_CharIsK,

				-- transceiver interface
				Trans_ResetDone								=> Trans_ResetDone(i),
				
				Trans_Command									=> Trans_Command(I),
				Trans_Status									=> Trans_Status(I),
				Trans_Error										=> Trans_Error(I),
				
				-- reconfiguration interface
				Trans_RP_Reconfig							=> Phy_RP_Reconfig(I),
				Trans_RP_SATAGeneration				=> Phy_RP_SATAGeneration(I),
				Trans_RP_ConfigReloaded				=> Trans_RP_ConfigReloaded(I),
				Trans_RP_Lock									=> Phy_RP_Lock(I),
				Trans_RP_Locked								=> Trans_RP_Locked(I),
				
				Trans_OOB_TX_Command					=> Phy_OOB_TX_Command(I),
				Trans_OOB_TX_Complete					=> Trans_OOB_TX_Complete(I),
				Trans_OOB_RX_Received					=> Trans_OOB_RX_Received(I),
				Trans_OOB_HandshakeComplete		=> Phy_OOB_HandshakeComplete(I),
				Trans_OOB_AlignDetected				=> Phy_OOB_AlignDetected(i),
				
				Trans_TX_Data									=> Phy_TX_Data(I),
				Trans_TX_CharIsK							=> Phy_TX_CharIsK(I),
				
				Trans_RX_Data									=> Trans_RX_Data(I),
				Trans_RX_CharIsK							=> Trans_RX_CharIsK(I),
				Trans_RX_Valid								=> Trans_RX_Valid(I)
			);

		-- The CSE interface of the PHY is ready, when the CSE interface
		-- of the transceiver is ready.
		Phy_ResetDone <= Trans_ResetDone(i);
		
		-- =========================================================================
		-- debug port
		-- =========================================================================
		genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
			-- Link Layer
			DebugPortOut(I).Link									<= Link_DebugPortOut;				-- RX: 125 + TX: 120 bit
			DebugPortOut(I).Link_Command					<= Link_Command;						-- 1 bit
			DebugPortOut(I).Link_Status						<= Link_Status;							-- 3 bit
			DebugPortOut(I).Link_Error						<= Link_Error;						
			
			-- Physical Layer
			DebugPortOut(I).Physical							<= Phy_DebugPortOut;				-- 
			DebugPortOut(I).Physical_Command			<= Phy_Command;							-- 
			DebugPortOut(I).Physical_Status				<= Phy_Status;							-- 3 bit
			DebugPortOut(I).Physical_Error				<= Phy_Error;								-- 

			-- Transceiver Layer
			Trans_DebugPortIn(I)									<= DebugPortIn(I).Transceiver;
			
			DebugPortOut(I).Transceiver						<= Trans_DebugPortOut(I);		-- 
			DebugPortOut(I).Transceiver_Command		<= Trans_Command(I);				-- 
			DebugPortOut(I).Transceiver_Status		<= Trans_Status(I);					-- 
			DebugPortOut(I).Transceiver_Error			<= Trans_Error(I);					--

		end generate;

		genNoDebug : if not(ENABLE_DEBUGPORT = TRUE) generate
			Trans_DebugPortIn(I)	<= C_SATADBG_TRANSCEIVER_IN_EMPTY;
		end generate;

	END GENERATE;
  
	-- ===========================================================================
	-- transceiver layer
	-- ===========================================================================

	
	Trans : ENTITY PoC.sata_TransceiverLayer
		GENERIC MAP (
			DEBUG											=> DEBUG,
			ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
			CLOCK_IN_FREQ							=> CLOCK_IN_FREQ,
--			CLOCK_IN_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,
			PORTS											=> PORTS,
			INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS_I
		)
		PORT MAP (
			ClockNetwork_Reset				=> ClockNetwork_Reset,
			ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

			PowerDown									=> PowerDown,
			Reset											=> Reset,
			
			-- CSE interface
			ResetDone									=> Trans_ResetDone,
			Command										=> Trans_Command,
			Status										=> Trans_Status,
			Error											=> Trans_Error,

			-- debug ports
			DebugPortIn								=> Trans_DebugPortIn,
			DebugPortOut							=> Trans_DebugPortOut,

			SATA_Clock								=> SATA_Clock_i,
			SATA_Clock_Stable					=> SATA_Clock_Stable_i,
			
			RP_Reconfig								=> Phy_RP_Reconfig,
			RP_SATAGeneration					=> Phy_RP_SATAGeneration,
			RP_ReconfigComplete				=> Trans_RP_ReconfigComplete,
			RP_ConfigReloaded					=> Trans_RP_ConfigReloaded,
			RP_Lock										=> Phy_RP_Lock,
			RP_Locked									=> Trans_RP_Locked,
			
			OOB_TX_Command						=> Phy_OOB_TX_Command,
			OOB_TX_Complete						=> Trans_OOB_TX_Complete,
			OOB_RX_Received						=> Trans_OOB_RX_Received,
			OOB_HandshakeComplete			=> Phy_OOB_HandshakeComplete,
			OOB_AlignDetected 				=> Phy_OOB_AlignDetected,
			
			TX_Data										=> Phy_TX_Data,
			TX_CharIsK								=> Phy_TX_CharIsK,

			RX_Data										=> Trans_RX_Data,
			RX_CharIsK								=> Trans_RX_CharIsK,
			RX_Valid									=> Trans_RX_Valid,
			
			-- vendor specific signals
			VSS_Common_In							=> VSS_Common_In,
			VSS_Private_In						=> VSS_Private_In,
			VSS_Private_Out						=> VSS_Private_Out
		);

	SATA_Clock 				<= SATA_Clock_i;
	SATA_Clock_Stable <= SATA_Clock_Stable_i;
	
END;
