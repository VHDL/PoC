-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--									Steffen Koehler
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
USE			PoC.strings.ALL;
USE			PoC.sata.ALL;
USE			PoC.satadbg.ALL;
USE			PoC.sata_TransceiverTypes.ALL;


ENTITY sata_SATAController IS
	GENERIC (
		DEBUG												: BOOLEAN														:= FALSE;
		ENABLE_DEBUGPORT						: BOOLEAN														:= FALSE;
		CLOCK_IN_FREQ_MHZ						: REAL															:= 150.0;
		PORTS												: POSITIVE													:= 2;	-- Port 0									Port 1
		CONTROLLER_TYPES						: T_SATA_DEVICE_TYPE_VECTOR					:= (0 => SATA_DEVICE_TYPE_HOST,	1 => SATA_DEVICE_TYPE_HOST);
		INITIAL_SATA_GENERATIONS		: T_SATA_GENERATION_VECTOR					:= (0 => SATA_GENERATION_2,			1 => SATA_GENERATION_2);
		ALLOW_SPEED_NEGOTIATION			: T_BOOLVEC													:= (0 => TRUE,									1 => TRUE);
		ALLOW_STANDARD_VIOLATION		: T_BOOLVEC													:= (0 => TRUE,									1 => TRUE);
		ALLOW_AUTO_RECONNECT				: T_BOOLVEC													:= (0 => TRUE,									1 => TRUE);
		OOB_TIMEOUT_US							: T_INTVEC													:= (0 => 0,											1 => 0);
		GENERATION_CHANGE_COUNT			: T_INTVEC													:= (0 => 8,											1 => 8);
		ATTEMPTS_PER_GENERATION			: T_INTVEC													:= (0 => 5,											1 => 3);
		AHEAD_CYCLES_FOR_INSERT_EOF	: T_INTVEC													:= (0 => 1,											1 => 1);
		MAX_FRAME_SIZE_B						: T_INTVEC													:= (0 => 4 * (2048 + 1),				1 => 4 * (2048 + 1))
	);
	PORT (
		ResetDone										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock: initialisation done
		ClockNetwork_Reset					: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async: reset all / hard reset
		ClockNetwork_ResetDone			: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async: all clocks are stable
		
		SATAGenerationMin						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);		-- 
		SATAGenerationMax						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);		-- 
		SATAGeneration          	  : OUT T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
		
		SATA_Clock									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		SATA_Reset									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock: clock is stable
		
		PowerDown										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		Command											: IN	T_SATA_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
		Status											: OUT T_SATA_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
		Error												: OUT	T_SATA_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

		-- Debug ports
		DebugPortOut								: OUT T_SATADBG_SATACOUT_VECTOR(PORTS - 1 DOWNTO 0);
    
		-- TX port
		TX_SOF											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_EOF											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Valid										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Data											: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
		TX_Ready										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_InsertEOF								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		TX_FS_Ready									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_FS_Valid									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_FS_SendOK								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_FS_Abort									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		-- RX port
		RX_SOF											: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_EOF											: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Valid										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Data											: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
		RX_Ready										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		RX_FS_Ready									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_FS_Valid									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_FS_CRCOK								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_FS_Abort									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		-- vendor specific signals
		VSS_Common_In								: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In							: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS - 1 DOWNTO 0);
		VSS_Private_Out							: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF sata_SATAController IS
	ATTRIBUTE KEEP															: BOOLEAN;

	SIGNAL SATA_Clock_i									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL SATA_ResetDone								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL SATA_Reset_i									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	-- SATAController <=> link layer signals
	SIGNAL Link_Command									: T_SATA_LINK_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_Status									: T_SATA_LINK_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_Error										: T_SATA_LINK_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL SATAC_TX_SOF									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL SATAC_TX_EOF									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL SATAC_TX_Valid								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL SATAC_TX_Data								: T_SLVV_32(PORTS - 1 DOWNTO 0);
	SIGNAL SATAC_TX_FS_Ready						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL SATAC_RX_Ready								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL SATAC_RX_FS_Ready						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL Link_TX_Ready								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAl Link_TX_InsertEOF						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_TX_FS_Valid							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_TX_FS_SendOK						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_TX_FS_Abort							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL Link_RX_SOF									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_RX_EOF									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_RX_Valid								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_RX_Data									: T_SLVV_32(PORTS - 1 DOWNTO 0);
	SIGNAL Link_RX_FS_Valid							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_RX_FS_CRCOK						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_RX_FS_Abort							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	-- link layer <=> physical layer signals
	SIGNAL Phy_Command									: T_SATA_PHY_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_Status										: T_SATA_PHY_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAl Phy_Error										: T_SATA_PHY_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL Link_TX_Data									: T_SLVV_32(PORTS - 1 DOWNTO 0);
	SIGNAL Link_TX_CharIsK							: T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL Phy_Reconfig									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_Lock											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
	SIGNAL Phy_SATA_Generation					: T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_OOB_HandshakingComplete	: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL Phy_RX_Data									: T_SLVV_32(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_RX_CharIsK								: T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);	

	-- physical layer <=> transceiver layer signals
	SIGNAL Phy_TX_OOBCommand						: T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_TX_OOBComplete						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_TX_Data									: T_SLVV_32(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_TX_CharIsK								: T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL Trans_Reset									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_ResetDone							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_ClockNetwork_ResetDone	: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL Trans_ReconfigComplete				: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_ConfigReloaded					: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_Locked									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL Trans_Command								: T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_Status									: T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_RX_Error								: T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_TX_Error								: T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL Trans_RX_OOBStatus						: T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_RX_IsAligned						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL Trans_RX_Data								: T_SLVV_32(PORTS - 1 DOWNTO 0);
	SIGNAL Trans_RX_CharIsK							: T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL Trans_DebugPortOut						: T_SATADBG_TRANSCEIVEROUT_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Phy_DebugPortOut							: T_SATADBG_PHYSICALOUT_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Link_DebugPortOut						: T_SATADBG_LINKOUT_VECTOR(PORTS - 1 DOWNTO 0);
	
	ATTRIBUTE KEEP OF Link_Status				: SIGNAL IS DEBUG;
	ATTRIBUTE KEEP OF SATA_Clock_i			: SIGNAL IS DEBUG;

BEGIN
	genReport : FOR I IN 0 TO PORTS - 1 GENERATE
		ASSERT FALSE REPORT "Port:    " & INTEGER'image(I)																										SEVERITY NOTE;
		ASSERT FALSE REPORT "  ControllerType:         " & T_SATA_DEVICE_TYPE'image(CONTROLLER_TYPES(I))			SEVERITY NOTE;
		ASSERT FALSE REPORT "  AllowSpeedNegotiation:  " & to_string(ALLOW_SPEED_NEGOTIATION(I))							SEVERITY NOTE;
		ASSERT FALSE REPORT "  AllowAutoReconnect:     " & to_string(ALLOW_AUTO_RECONNECT(I))									SEVERITY NOTE;
		ASSERT FALSE REPORT "  AllowStandardViolation: " & to_string(ALLOW_STANDARD_VIOLATION(I))							SEVERITY NOTE;
		ASSERT FALSE REPORT "  Init. SATA Generation:  Gen" & INTEGER'image(INITIAL_SATA_GENERATIONS(I) + 1)	SEVERITY NOTE;
	END GENERATE;

-- ==================================================================
-- Reset control
-- ==================================================================
	-- *_ResetDone
	ClockNetwork_ResetDone	<= Trans_ClockNetwork_ResetDone;
	ResetDone								<= Trans_ResetDone;
	
	SATA_Reset							<= SATA_Reset_i;


	PROCESS(Command, Trans_ClockNetwork_ResetDone, Trans_Status)
	BEGIN
		-- reset network
		SATA_Reset_i										<= (OTHERS => '0');
		Link_Command										<= (OTHERS => SATA_LINK_CMD_NONE);
		Phy_Command											<= (OTHERS => SATA_PHY_CMD_NONE);
		Trans_Command										<= (OTHERS => SATA_TRANSCEIVER_CMD_NONE);
		Trans_Reset											<= (OTHERS => '0');
		
		FOR I IN 0 TO PORTS - 1 LOOP
			SATA_Reset_i(I)								<= NOT Trans_ClockNetwork_ResetDone(I);

			CASE Command(I) IS
				WHEN SATA_CMD_RESET =>
					SATA_Reset_i(I)						<= '1';
					Link_Command(I)						<= SATA_LINK_CMD_RESET;					-- reset all logic
					Phy_Command(I)						<= SATA_PHY_CMD_RESET;					-- reset all logic, incl. SATA_Generation and AttemptCounters
				
				WHEN SATA_CMD_RESET_CONNECTION =>														-- invoke COMRESET / COMINIT at same SATA_Generation, reset TrysPerGeneration counter
					SATA_Reset_i(I)						<= '1';
					Link_Command(I)						<= SATA_LINK_CMD_RESET;
					Phy_Command(I)						<= SATA_PHY_CMD_NEWLINK_UP;

				WHEN SATA_CMD_RESET_LINKLAYER =>														-- reset LinkLayer => send SYNC-primitives
					Link_Command(I)						<= SATA_LINK_CMD_RESET;
			
				WHEN OTHERS =>
					-- check for auto reconnect
					IF ((ALLOW_AUTO_RECONNECT(I)	= TRUE) AND
							(CONTROLLER_TYPES(I)			= SATA_DEVICE_TYPE_HOST) AND
							(Trans_Status(I)					= SATA_TRANSCEIVER_STATUS_NEW_DEVICE))
					THEN
						SATA_Reset_i(I)					<= '1';
						Link_Command(I)					<= SATA_LINK_CMD_RESET;					-- reset all logic
						Phy_Command(I)					<= SATA_PHY_CMD_RESET;					-- reset all logic, incl. SATA_Generation and AttemptCounters
					END IF;
	
			END CASE;
		
		END LOOP;
	END PROCESS;


	-- generate layer moduls per port
	gen1 : FOR I IN 0 TO PORTS - 1 GENERATE
	BEGIN
-- ==================================================================
-- SATAController interface
-- ==================================================================
		-- common signals
		SATA_Clock(I)									<= SATA_Clock_i(I);

		-- TX port
		SATAC_TX_SOF(I)								<= TX_SOF(I);
		SATAC_TX_EOF(I)								<= TX_EOF(I);
		SATAC_TX_Valid(I)							<= TX_Valid(I);
		SATAC_TX_Data(I)							<= TX_Data(I);
		TX_Ready(I)										<= Link_TX_Ready(I);
		TX_InsertEOF(I)								<= Link_TX_InsertEOF(I);
		
		SATAC_TX_FS_Ready(I)					<= TX_FS_Ready(I);
		TX_FS_Valid(I)								<= Link_TX_FS_Valid(I);
		TX_FS_SendOK(I)								<= Link_TX_FS_SendOK(I);
		TX_FS_Abort(I)								<= Link_TX_FS_Abort(I);
		
		-- RX port
		RX_SOF(I)											<= Link_RX_SOF(I);
		RX_EOF(I)											<= Link_RX_EOF(I);
		RX_Valid(I)										<= Link_RX_Valid(I);
		RX_Data(I)										<= Link_RX_Data(I);
		SATAC_RX_Ready(I)							<= RX_Ready(I);
		
		SATAC_RX_FS_Ready(I)					<= RX_FS_Ready(I);
		RX_FS_Valid(I)								<= Link_RX_FS_Valid(I);
		RX_FS_CRCOK(I)								<= Link_RX_FS_CRCOK(I);
		RX_FS_Abort(I)								<= Link_RX_FS_Abort(I);
		
-- ==================================================================
-- SATAController logic
-- ==================================================================
		Status(I).LinkLayer						<= Link_Status(I);
		Status(I).PhysicalLayer				<= Phy_Status(I);
		Status(I).TransceiverLayer		<= Trans_Status(I);
		
		Error(I).LinkLayer						<= Link_Error(I);
		Error(I).PhysicalLayer				<= Phy_Error(I);
		Error(I).TransceiverLayer_TX	<= Trans_TX_Error(I);
		Error(I).TransceiverLayer_RX	<= Trans_RX_Error(I);
		
-- ==================================================================
-- link layer
-- ==================================================================
		Link : ENTITY PoC.sata_LinkLayer
			GENERIC MAP (
				DEBUG													=> DEBUG,
				ENABLE_DEBUGPORT							=> ENABLE_DEBUGPORT,
				CONTROLLER_TYPE								=> CONTROLLER_TYPES(I),
				AHEAD_CYCLES_FOR_INSERT_EOF		=> AHEAD_CYCLES_FOR_INSERT_EOF(I),
				MAX_FRAME_SIZE_B							=> MAX_FRAME_SIZE_B(I)
			)
			PORT MAP (
				Clock										=> SATA_Clock_i(I),
				Reset										=> SATA_Reset_i(I),
				
				Command									=> Link_Command(I),
				Status									=> Link_Status(I),
				Error										=> Link_Error(I),
				
				-- Debug ports
				DebugPortOut					 	=> Link_DebugPortOut(I),
				
				-- TX port
				TX_SOF									=> SATAC_TX_SOF(I),
				TX_EOF									=> SATAC_TX_EOF(I),
				TX_Valid								=> SATAC_TX_Valid(I),
				TX_Data									=> SATAC_TX_Data(I),
				TX_Ready								=> Link_TX_Ready(I),
				TX_InsertEOF						=> Link_TX_InsertEOF(I),
				
				TX_FS_Ready							=> SATAC_TX_FS_Ready(I),
				TX_FS_Valid							=> Link_TX_FS_Valid(I),
				TX_FS_SendOK						=> Link_TX_FS_SendOK(I),
				TX_FS_Abort							=> Link_TX_FS_Abort(I),
				
				-- RX port
				RX_SOF									=> Link_RX_SOF(I),
				RX_EOF									=> Link_RX_EOF(I),
				RX_Valid								=> Link_RX_Valid(I),
				RX_Data									=> Link_RX_Data(I),
				RX_Ready								=> SATAC_RX_Ready(I),
				
				RX_FS_Ready							=> SATAC_RX_FS_Ready(I),
				RX_FS_Valid							=> Link_RX_FS_Valid(I),
				RX_FS_CRCOK							=> Link_RX_FS_CRCOK(I),
				RX_FS_Abort							=> Link_RX_FS_Abort(I),
				
				-- physical layer interface
				Phy_Status							=> Phy_Status(I),
				
				Phy_RX_Data							=> Phy_RX_Data(I),
				Phy_RX_CharIsK					=> Phy_RX_CharIsK(I),
				
				Phy_TX_Data							=> Link_TX_Data(I),
				Phy_TX_CharIsK					=> Link_TX_CharIsK(I)
			);


-- ==================================================================
-- physical layer
-- ==================================================================
		Phy : ENTITY PoC.sata_PhysicalLayer
			GENERIC MAP (
				DEBUG													=> DEBUG,
				ENABLE_DEBUGPORT							=> ENABLE_DEBUGPORT,
				CLOCK_IN_FREQ_MHZ							=> CLOCK_IN_FREQ_MHZ,
				CONTROLLER_TYPE								=> CONTROLLER_TYPES(I),
				ALLOW_SPEED_NEGOTIATION				=> ALLOW_SPEED_NEGOTIATION(I),
				INITIAL_SATA_GENERATION				=> INITIAL_SATA_GENERATIONS(I),
				ALLOW_AUTO_RECONNECT					=> ALLOW_AUTO_RECONNECT(I),
				ALLOW_STANDARD_VIOLATION			=> ALLOW_STANDARD_VIOLATION(I),
				OOB_TIMEOUT_US								=> OOB_TIMEOUT_US(I),		--ite(SIMULATION, 15, OOB_TIMEOUT_US(I)),			-- simulation: limit OOBTimeout to 15 us 
				GENERATION_CHANGE_COUNT				=> GENERATION_CHANGE_COUNT(I),
				ATTEMPTS_PER_GENERATION				=> ATTEMPTS_PER_GENERATION(I)
			)
			PORT MAP (
				Clock													=> SATA_Clock_i(I),
				Reset													=> SATA_Reset_i(I),										-- general logic reset without some counter resets while Clock is unstable
																																						--   => preserve SATA_Generation between connection-cycles
				SATAGenerationMin							=> SATAGenerationMin(I),							-- 
				SATAGenerationMax							=> SATAGenerationMax(I),							-- 
				SATA_Generation								=> Phy_SATA_Generation(I),

				Command												=> Phy_Command(I),
				Status												=> Phy_Status(I),
				Error													=> Phy_Error(I),

				DebugPortOut									=> Phy_DebugPortOut(I),
				
				Link_RX_Data									=> Phy_RX_Data(I),
				Link_RX_CharIsK								=> Phy_RX_CharIsK(I),
				
				Link_TX_Data									=> Link_TX_Data(I),
				Link_TX_CharIsK								=> Link_TX_CharIsK(I),
				
				-- reconfiguration interface
				Trans_Reconfig								=> Phy_Reconfig(I),
--				Trans_ReconfigComplete				=> Trans_ReconfigComplete(I),
				Trans_ConfigReloaded					=> Trans_ConfigReloaded(I),
				Trans_Lock										=> Phy_Lock(I),
				Trans_Locked									=> Trans_Locked(I),
				
				Trans_OOB_HandshakingComplete	=> Phy_OOB_HandshakingComplete(I),
				
				Trans_ResetDone								=> Trans_ResetDone(I),
				Trans_Status									=> Trans_Status(I),
				Trans_RX_Error								=> Trans_RX_Error(I),
				Trans_TX_Error								=> Trans_TX_Error(I),

				Trans_RX_OOBStatus						=> Trans_RX_OOBStatus(I),
				Trans_RX_Data									=> Trans_RX_Data(I),
				Trans_RX_CharIsK							=> Trans_RX_CharIsK(I),
				Trans_RX_IsAligned						=> Trans_RX_IsAligned(I),
			
				Trans_TX_OOBCommand						=> Phy_TX_OOBCommand(I),
				Trans_TX_OOBComplete					=> Phy_TX_OOBComplete(I),
				Trans_TX_Data									=> Phy_TX_Data(I),
				Trans_TX_CharIsK							=> Phy_TX_CharIsK(I)
			);
	END GENERATE;
  
  SATAGeneration <= Phy_SATA_Generation;

-- ==================================================================
-- transceiver layer
-- ==================================================================
	Trans : ENTITY PoC.sata_TransceiverLayer
		GENERIC MAP (
			DEBUG											=> DEBUG,
			ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
			CLOCK_IN_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,
			PORTS											=> PORTS,
			INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS
		)
		PORT MAP (
			Reset											=> Trans_Reset,
			ResetDone									=> Trans_ResetDone,
			ClockNetwork_Reset				=> ClockNetwork_Reset,
			ClockNetwork_ResetDone		=> Trans_ClockNetwork_ResetDone,
			
			SATA_Clock								=> SATA_Clock_i,
			
			PowerDown									=> PowerDown,
			
			RP_Reconfig								=> Phy_Reconfig,
			RP_ReconfigComplete				=> OPEN,													-- Trans_ReconfigComplete,
			RP_ConfigReloaded					=> Trans_ConfigReloaded,
			RP_Lock										=> Phy_Lock,
			RP_Locked									=> Trans_Locked,
			
			SATA_Generation						=> Phy_SATA_Generation,

			OOB_HandshakingComplete		=> Phy_OOB_HandshakingComplete,
			
			Command										=> Trans_Command,
			Status										=> Trans_Status,
			TX_Error									=> Trans_TX_Error,
			RX_Error									=> Trans_RX_Error,

			DebugPortOut							=> Trans_DebugPortOut,

			TX_OOBCommand							=> Phy_TX_OOBCommand,
			TX_OOBComplete						=> Phy_TX_OOBComplete,
			TX_Data										=> Phy_TX_Data,
			TX_CharIsK								=> Phy_TX_CharIsK,

			RX_OOBStatus							=> Trans_RX_OOBStatus,
			RX_Data										=> Trans_RX_Data,
			RX_CharIsK								=> Trans_RX_CharIsK,
			RX_IsAligned							=> Trans_RX_IsAligned,
			
			-- vendor specific signals
			VSS_Common_In							=> VSS_Common_In,
			VSS_Private_In						=> VSS_Private_In,
			VSS_Private_Out						=> VSS_Private_Out
		);
	
	-- ================================================================
	-- debug port
	-- ================================================================
	genDebugLoop : for I in 0 to PORTS - 1 generate
		genDebug1 : if (ENABLE_DEBUGPORT = TRUE) generate
			-- Transceiver Layer
			DebugPortOut(I).Transceiver						<= Trans_DebugPortOut(I);		-- 
			DebugPortOut(I).Transceiver_Command		<= Trans_Command(I);				-- 
			DebugPortOut(I).Transceiver_Status		<= Trans_Status(I);					-- 
			DebugPortOut(I).Transceiver_TX_Error	<= Trans_TX_Error(I);				-- 
			DebugPortOut(I).Transceiver_RX_Error	<= Trans_RX_Error(I);				-- 
			-- Physical Layer
			DebugPortOut(I).Physical							<= Phy_DebugPortOut(I);			-- 
			DebugPortOut(I).Physical_Command			<= Phy_Command(I);					-- 
			DebugPortOut(I).Physical_Status				<= Phy_Status(I);						-- 3 bit
			DebugPortOut(I).Physical_Error				<= Phy_Error(I);						-- 
			-- Link Layer
			DebugPortOut(I).Link									<= Link_DebugPortOut(I);		-- RX: 125 + TX: 120 bit
			DebugPortOut(I).Link_Command					<= Link_Command(I);					-- 1 bit
			DebugPortOut(I).Link_Status						<= Link_Status(I);					-- 3 bit
			DebugPortOut(I).Link_Error						<= Link_Error(I);						
		end generate genDebug1;
	end generate genDebugLoop;

END;
