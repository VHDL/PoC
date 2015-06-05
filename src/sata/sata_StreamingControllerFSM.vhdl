-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Module:					FSM for SATA Streaming Controller
--
-- Description:
-- ------------------------------------
-- See notes on module 'sata_StreamingController'.
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
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
use			PoC.debug.all;
USE			PoC.sata.ALL;
use			PoC.satadbg.all;


ENTITY sata_StreamingControllerFSM IS
	GENERIC (
		DEBUG															: BOOLEAN								:= FALSE;
		ENABLE_DEBUGPORT									: BOOLEAN								:= FALSE;			-- export internal signals to upper layers for debug purposes
		SIM_EXECUTE_IDENTIFY_DEVICE				: BOOLEAN								:= TRUE				-- required by CommandLayer: load device parameters
	);
	PORT (
		Clock															: IN	STD_LOGIC;
		MyReset														: IN	STD_LOGIC;

		-- for measurement purposes only
		Config_BurstSize									: IN	T_SLV_16;

		-- ATAStreamingController interface
		Command														: IN	T_SATA_STREAMINGCONTROLLER_COMMAND;
		Status														: OUT	T_SATA_STREAMINGCONTROLLER_STATUS;
		Error															: OUT	T_SATA_STREAMINGCONTROLLER_ERROR;

		DebugPortOut 											: out T_SATADBG_STREAMINGCONTROLLER_SCFSM_OUT;
		
		Address_LB												: IN	T_SLV_48;
		BlockCount_LB											: IN	T_SLV_48;

		TX_FIFO_Valid											: IN	STD_LOGIC;
		TX_FIFO_EOR												: IN	STD_LOGIC;
		TX_FIFO_ForceGot									: OUT	STD_LOGIC;
		
		SATAC_TX_Ack											: IN	STD_LOGIC;
		TX_en															: OUT	STD_LOGIC;
		TX_ForceEOT												: OUT	STD_LOGIC;

		RX_SOR														: OUT	STD_LOGIC;
		RX_EOR														: OUT	STD_LOGIC;
		RX_ForcePut												: OUT	STD_LOGIC;

		-- SATA Controller interface
		SATAC_Command											: OUT	T_SATA_SATACONTROLLER_COMMAND;
		Trans_Status											: IN	T_SATA_TRANS_STATUS;
		
		SATAC_ATAHostRegisters						: OUT T_SATA_ATA_HOST_REGISTERS;
		
		SATAC_RX_SOT											: IN	STD_LOGIC;
		SATAC_RX_EOT											: IN	STD_LOGIC;
		
		-- IdentifyDeviceFilter interface
		IDF_Enable												: OUT	STD_LOGIC;
		IDF_DriveInformation							: IN	T_SATA_DRIVE_INFORMATION;
		IDF_Error													: IN	STD_LOGIC
	);
END;


ARCHITECTURE rtl OF sata_StreamingControllerFSM IS
	ATTRIBUTE KEEP												: BOOLEAN;
	ATTRIBUTE FSM_ENCODING								: STRING;

	CONSTANT MAX_BLOCKCOUNT								: POSITIVE												:= ite(SIMULATION, C_SIM_MAX_BLOCKCOUNT, C_SATA_ATA_MAX_BLOCKCOUNT);

	-- 1 => single transfer
	-- F => first transfer
	-- N => next transfer
	-- L => last transfer
	TYPE T_STATE IS (
		ST_RESET,
		ST_INIT,
		ST_IDLE,
		ST_IDENTIFY_DEVICE_WAIT,	ST_IDENTIFY_DEVICE_CHECK,
		ST_READ_1_WAIT,		ST_READ_F_WAIT,		ST_READ_N_WAIT,		ST_READ_L_WAIT,
		ST_WRITE_1_WAIT,	ST_WRITE_F_WAIT,	ST_WRITE_N_WAIT,	ST_WRITE_L_WAIT,
		ST_WRITE_ABORT_TRANSFER, ST_WRITE_DISCARD_REQUEST, ST_WRITE_WAIT_IDLE,
		ST_FLUSH_CACHE_WAIT,
		ST_DEVICE_RESET_WAIT,
		ST_ERROR
	);
	
	SIGNAL State													: T_STATE													:= ST_RESET;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State			: SIGNAL IS getFSMEncoding_gray(DEBUG);

	signal Error_nxt 											: T_SATA_STREAMINGCONTROLLER_ERROR;
	
	SIGNAL SATAC_Command_i								: T_SATA_SATACONTROLLER_COMMAND;
	
	SIGNAL Load														: STD_LOGIC;
	SIGNAL NextTransfer										: STD_LOGIC;
	SIGNAL LastTransfer										: STD_LOGIC;
	SIGNAL BurstCount_us									: UNSIGNED(16 DOWNTO 0);
	SIGNAL Address_LB_us									: UNSIGNED(47 DOWNTO 0);
	SIGNAL Address_LB_us_d								: UNSIGNED(47 DOWNTO 0)						:= (OTHERS => '0');
	SIGNAL Address_LB_us_d_nx							: UNSIGNED(47 DOWNTO 0);
	SIGNAL BlockCount_LB_us								: UNSIGNED(47 DOWNTO 0);
	SIGNAL BlockCount_LB_us_d							: UNSIGNED(47 DOWNTO 0)						:= (OTHERS => '0');
	SIGNAL BlockCount_LB_us_d_nx					: UNSIGNED(47 DOWNTO 0);
	
	SIGNAL ATA_Address_LB_us							: UNSIGNED(47 DOWNTO 0);
	SIGNAL ATA_BlockCount_LB_us						: UNSIGNED(15 DOWNTO 0);
	
	SIGNAL ATA_Address_LB									: T_SLV_48;
	SIGNAL ATA_BlockCount_LB							: T_SLV_16;
	
	ATTRIBUTE KEEP OF Load								: SIGNAL IS DEBUG					;
	ATTRIBUTE KEEP OF NextTransfer				: SIGNAL IS DEBUG					;
	ATTRIBUTE KEEP OF LastTransfer				: SIGNAL IS DEBUG					;
	
BEGIN
-- ATA_Device_register => TD=0 -> 40   / TD=1 -> 50

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (MyReset = '1') THEN
				State						<= ST_RESET;
				Error 					<= SATA_STREAMCTRL_ERROR_NONE;
	
			ELSE
				State						<= NextState;
				
				if (State /= ST_ERROR) and (NextState = ST_ERROR) then
					Error 				<= Error_nxt;
				elsif (Command /= SATA_STREAMCTRL_CMD_NONE) then
					Error 				<= SATA_STREAMCTRL_ERROR_NONE; -- clear when issuing new command
				end if;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(State, Command, Trans_Status, IDF_Error, IDF_DriveInformation, ATA_Address_LB, ATA_BlockCount_LB,
					LastTransfer, SATAC_RX_SOT, SATAC_RX_EOT, TX_FIFO_Valid, TX_FIFO_EOR, SATAC_TX_Ack)
	BEGIN
		NextState																		<= State;
		
		Status																			<= SATA_STREAMCTRL_STATUS_RESET; -- just in case
		Error_nxt																		<= SATA_STREAMCTRL_ERROR_NONE;
		
		Load																				<= '0';
		NextTransfer																<= '0';
		
		TX_en																				<= '0';
		TX_ForceEOT																	<= '0';
		TX_FIFO_ForceGot														<= '0';
		
		RX_SOR																			<= '0';
		RX_EOR																			<= '0';
		RX_ForcePut																	<= '0';
		
		SATAC_Command_i															<= SATA_SATACTRL_CMD_NONE;
		SATAC_ATAHostRegisters.Flag_C								<= '0';
		SATAC_ATAHostRegisters.Command							<= to_slv(SATA_ATA_CMD_NONE);	-- Command register
		SATAC_ATAHostRegisters.Control							<= (OTHERS => '0');						-- Control register
		SATAC_ATAHostRegisters.Feature							<= (OTHERS => '0');						-- Feature register
		SATAC_ATAHostRegisters.LBlockAddress				<= (OTHERS => '0');						-- logical block address (LBA)
		SATAC_ATAHostRegisters.SectorCount					<= (OTHERS => '0');						-- 
		
		IDF_Enable																	<= '0';
		
		CASE State IS
			WHEN ST_RESET =>
				-- Clock might be unstable is this state. In this case either
				-- a) MyReset is asserted because inital reset of the SATAController is
				--    not finished yet.
				-- b) Trans_Status is constant and not equal to SATA_TRANS_STATUS_IDLE.
				--    This may happen during reconfiguration due to speed negotiation.
				Status																			<= SATA_STREAMCTRL_STATUS_RESET;
        
        IF (Trans_Status = SATA_TRANS_STATUS_IDLE) THEN
					IF (SIM_EXECUTE_IDENTIFY_DEVICE = TRUE) THEN
						NextState																<= ST_INIT;
					ELSE
						NextState																<= ST_IDLE;
					END IF;
        END IF;
			
			WHEN ST_INIT =>
        -- assert Trans_Status = SATA_TRANS_STATUS_IDLE
				Status																			<= SATA_STREAMCTRL_STATUS_INITIALIZING;
						
				-- TransportLayer
				SATAC_Command_i															<= SATA_SATACTRL_CMD_TRANSFER;
				SATAC_ATAHostRegisters.Flag_C								<= '1';
				SATAC_ATAHostRegisters.Command							<= to_slv(SATA_ATA_CMD_IDENTIFY_DEVICE);	-- Command register
				SATAC_ATAHostRegisters.Control							<= (OTHERS => '0');												-- Control register
				SATAC_ATAHostRegisters.Feature							<= (OTHERS => '0');												-- Feature register
				SATAC_ATAHostRegisters.LBlockAddress				<= (OTHERS => '0');												-- logical block address (LBA)
				SATAC_ATAHostRegisters.SectorCount					<= (OTHERS => '0');												-- 
			
				-- IdentifyDeviceFilter
				IDF_Enable																	<= '1';
			
				NextState																		<= ST_IDENTIFY_DEVICE_WAIT;
			
			WHEN ST_IDLE =>
        -- assert Trans_Status = SATA_TRANS_STATUS_IDLE
				Status																			<= SATA_STREAMCTRL_STATUS_IDLE;
			
				CASE Command IS
					WHEN SATA_STREAMCTRL_CMD_NONE =>
						NULL;
					
					WHEN SATA_STREAMCTRL_CMD_IDENTIFY_DEVICE =>
						-- TransportLayer
						SATAC_Command_i													<= SATA_SATACTRL_CMD_TRANSFER;
						SATAC_ATAHostRegisters.Flag_C						<= '1';
						SATAC_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_IDENTIFY_DEVICE);	-- Command register
						SATAC_ATAHostRegisters.Control					<= (OTHERS => '0');												-- Control register
						SATAC_ATAHostRegisters.Feature					<= (OTHERS => '0');												-- Feature register
						SATAC_ATAHostRegisters.LBlockAddress		<= (OTHERS => '0');												-- logical block address (LBA)
						SATAC_ATAHostRegisters.SectorCount			<= (OTHERS => '0');												-- 
					
						-- IdentifyDeviceFilter
						IDF_Enable															<= '1';
					
						NextState																<= ST_IDENTIFY_DEVICE_WAIT;
						
					WHEN SATA_STREAMCTRL_CMD_READ =>
						-- TransferGenerator
						Load																		<= '1';
						
						-- TransportLayer
						SATAC_Command_i													<= SATA_SATACTRL_CMD_TRANSFER;
						SATAC_ATAHostRegisters.Flag_C						<= '1';
						SATAC_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_DMA_READ_EXT);		-- Command register
						SATAC_ATAHostRegisters.Control					<= (OTHERS => '0');											-- Control register
						SATAC_ATAHostRegisters.Feature					<= (OTHERS => '0');											-- Feature register
						SATAC_ATAHostRegisters.LBlockAddress		<= ATA_Address_LB;											-- logical block address (LBA)
						SATAC_ATAHostRegisters.SectorCount			<= ATA_BlockCount_LB;										-- 
			
						IF (LastTransfer = '0') THEN
							NextState															<= ST_READ_F_WAIT;
						ELSE
							NextState															<= ST_READ_1_WAIT;
						END IF;
						
					WHEN SATA_STREAMCTRL_CMD_WRITE =>
						-- TransferGenerator
						Load																		<= '1';
						
						-- TransportLayer
						SATAC_Command_i													<= SATA_SATACTRL_CMD_TRANSFER;
						SATAC_ATAHostRegisters.Flag_C						<= '1';
						SATAC_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_DMA_WRITE_EXT);	-- Command register
						SATAC_ATAHostRegisters.Control					<= (OTHERS => '0');											-- Control register
						SATAC_ATAHostRegisters.Feature					<= (OTHERS => '0');											-- Feature register
						SATAC_ATAHostRegisters.LBlockAddress		<= ATA_Address_LB;											-- logical block address (LBA)
						SATAC_ATAHostRegisters.SectorCount			<= ATA_BlockCount_LB;										-- 
			
						IF (LastTransfer = '0') THEN
							NextState															<= ST_WRITE_F_WAIT;
						ELSE
							NextState															<= ST_WRITE_1_WAIT;
						END IF;

					when SATA_STREAMCTRL_CMD_FLUSH_CACHE =>
						-- TransportLayer
						SATAC_Command_i													<= SATA_SATACTRL_CMD_TRANSFER;
						SATAC_ATAHostRegisters.Flag_C						<= '1';
						SATAC_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_FLUSH_CACHE_EXT);	-- Command register
						SATAC_ATAHostRegisters.Control					<= (others => '0');												-- Control register
						SATAC_ATAHostRegisters.Feature					<= (others => '0');												-- Feature register
						SATAC_ATAHostRegisters.LBlockAddress		<= (others => '0');												-- logical block address (LBA)
						SATAC_ATAHostRegisters.SectorCount			<= (others => '0');												-- 
			
						NextState																<= ST_FLUSH_CACHE_WAIT;
						
					when SATA_STREAMCTRL_CMD_DEVICE_RESET =>
						-- TransportLayer
						SATAC_Command_i													<= SATA_SATACTRL_CMD_TRANSFER;
						SATAC_ATAHostRegisters.Flag_C						<= '1';
						SATAC_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_DEVICE_RESET);			-- Command register
						SATAC_ATAHostRegisters.Control					<= (others => '0');												-- Control register
						SATAC_ATAHostRegisters.Feature					<= (others => '0');												-- Feature register
						SATAC_ATAHostRegisters.LBlockAddress		<= (others => '0');												-- logical block address (LBA)
						SATAC_ATAHostRegisters.SectorCount			<= (others => '0');												-- 
			
						NextState																<= ST_DEVICE_RESET_WAIT;
						
					when others =>
						Error_nxt																<= SATA_STREAMCTRL_ERROR_FSM;
						NextState																<= ST_ERROR;

				end case;

				-- A link error may occur at any time, e.g., if:
				-- - the other end (e.g. device) requests a link reset via COMRESET
				-- - or the other end was detached and a new device or host connected.
				-- This event is signaled via a TRANSPORT_ERROR.
				-- Transport Layer will ignore above assigned command.
				if(Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt																	<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState 																<= ST_ERROR;
				end if;
				
			WHEN ST_IDENTIFY_DEVICE_WAIT =>
				IF (IDF_DriveInformation.Valid = '0') THEN
					Status																		<= SATA_STREAMCTRL_STATUS_INITIALIZING;
				ELSE
					Status																		<= SATA_STREAMCTRL_STATUS_EXECUTING;
				END IF;
			
				IDF_Enable																	<= '1';
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					IF (IDF_Error = '1') THEN
						Error_nxt																<= SATA_STREAMCTRL_ERROR_IDENTIFY_DEVICE_ERROR;
						NextState																<= ST_ERROR;
					END IF;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					IF (IDF_Error = '0') THEN
						NextState																<= ST_IDENTIFY_DEVICE_CHECK;
					ELSE
						Error_nxt																<= SATA_STREAMCTRL_ERROR_IDENTIFY_DEVICE_ERROR;
						NextState																<= ST_ERROR;
					END IF;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) THEN
					Error_nxt																	<= SATA_STREAMCTRL_ERROR_ATA_ERROR;
					NextState																	<= ST_ERROR;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					Error_nxt																	<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState																	<= ST_ERROR;
				END IF;
				
			WHEN ST_IDENTIFY_DEVICE_CHECK =>
				Status																			<= SATA_STREAMCTRL_STATUS_INITIALIZING;
			
				IF (IDF_DriveInformation.Valid = '1') THEN
					IF ((IDF_DriveInformation.ATACapabilityFlags.SupportsDMA = '1') AND
							(IDF_DriveInformation.ATACapabilityFlags.SupportsLBA = '1') AND
							(IDF_DriveInformation.ATACapabilityFlags.Supports48BitLBA = '1') AND
							(IDF_DriveInformation.ATACapabilityFlags.SupportsFLUSH_CACHE = '1') AND
							(IDF_DriveInformation.ATACapabilityFlags.SupportsFLUSH_CACHE_EXT = '1')) THEN
						NextState																<= ST_IDLE;
					ELSE	-- device not supported
						Error_nxt																<= SATA_STREAMCTRL_ERROR_DEVICE_NOT_SUPPORTED;
						NextState																<= ST_ERROR;
					END IF;
				ELSE
					-- information are not valid
					Error_nxt																	<= SATA_STREAMCTRL_ERROR_IDENTIFY_DEVICE_ERROR;
					NextState																	<= ST_ERROR;
				END IF;
				
			-- ============================================================
			-- ATA command: ATA_CMD_CMD_READ
			-- ============================================================
			WHEN ST_READ_1_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_RECEIVING;
				
				RX_SOR																	<= SATAC_RX_SOT;
				RX_EOR																	<= SATAC_RX_EOT;
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					NextState															<= ST_IDLE;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) THEN
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAMCTRL_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;
			
			WHEN ST_READ_F_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_RECEIVING;
				
				RX_SOR																	<= SATAC_RX_SOT;
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					-- TransferGenerator
					NextTransfer													<= '1';
					
					-- TransportLayer
					SATAC_Command_i												<= SATA_SATACTRL_CMD_TRANSFER;
					SATAC_ATAHostRegisters.Flag_C					<= '1';
					SATAC_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_DMA_READ_EXT);				-- Command register
					SATAC_ATAHostRegisters.Control				<= (OTHERS => '0');											-- Control register
					SATAC_ATAHostRegisters.Feature				<= (OTHERS => '0');											-- Feature register
					SATAC_ATAHostRegisters.LBlockAddress	<= ATA_Address_LB;											-- logical block address (LBA)
					SATAC_ATAHostRegisters.SectorCount		<= ATA_BlockCount_LB;										-- 
					
					IF (LastTransfer = '0') THEN
						NextState														<= ST_READ_N_WAIT;
					ELSE
						NextState														<= ST_READ_L_WAIT;
					END IF;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) THEN
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAMCTRL_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;
			
			WHEN ST_READ_N_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_RECEIVING;
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					-- TransferGenerator
					NextTransfer													<= '1';
					
					-- TransportLayer
					SATAC_Command_i												<= SATA_SATACTRL_CMD_TRANSFER;
					SATAC_ATAHostRegisters.Flag_C					<= '1';
					SATAC_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_DMA_READ_EXT);				-- Command register
					SATAC_ATAHostRegisters.Control				<= (OTHERS => '0');											-- Control register
					SATAC_ATAHostRegisters.Feature				<= (OTHERS => '0');											-- Feature register
					SATAC_ATAHostRegisters.LBlockAddress	<= ATA_Address_LB;											-- logical block address (LBA)
					SATAC_ATAHostRegisters.SectorCount		<= ATA_BlockCount_LB;										-- 
					
					IF (LastTransfer = '0') THEN
						NextState														<= ST_READ_N_WAIT;
					ELSE
						NextState														<= ST_READ_L_WAIT;
					END IF;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) THEN
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAMCTRL_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;
			
			WHEN ST_READ_L_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_RECEIVING;
				
				RX_EOR																	<= SATAC_RX_EOT;
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					NextState															<= ST_IDLE;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) THEN
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAMCTRL_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;
			
			-- ============================================================
			-- ATA command: ATA_CMD_CMD_WRITE
			-- ============================================================
			WHEN ST_WRITE_1_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_SENDING;
				TX_en																		<= '1';
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					NextState															<= ST_IDLE;
				elsif (Trans_Status = SATA_TRANS_STATUS_DISCARD_TXDATA) then
					NextState 														<= ST_WRITE_ABORT_TRANSFER;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;
				
			WHEN ST_WRITE_F_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_SENDING;
				TX_en																		<= '1';
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					-- TransferGenerator
					NextTransfer													<= '1';
					
					-- TransportLayer
					SATAC_Command_i												<= SATA_SATACTRL_CMD_TRANSFER;
					SATAC_ATAHostRegisters.Flag_C					<= '1';
					SATAC_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_DMA_WRITE_EXT);				-- Command register
					SATAC_ATAHostRegisters.Control				<= (OTHERS => '0');											-- Control register
					SATAC_ATAHostRegisters.Feature				<= (OTHERS => '0');											-- Feature register
					SATAC_ATAHostRegisters.LBlockAddress	<= ATA_Address_LB;											-- logical block address (LBA)
					SATAC_ATAHostRegisters.SectorCount		<= ATA_BlockCount_LB;										-- 
					
					IF (LastTransfer = '0') THEN
						NextState														<= ST_WRITE_N_WAIT;
					ELSE
						NextState														<= ST_WRITE_L_WAIT;
					END IF;
				elsif (Trans_Status = SATA_TRANS_STATUS_DISCARD_TXDATA) then
					NextState 														<= ST_WRITE_ABORT_TRANSFER;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;
			
			WHEN ST_WRITE_N_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_SENDING;
				TX_en																		<= '1';
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					-- TransferGenerator
					NextTransfer													<= '1';
					
					-- TransportLayer
					SATAC_Command_i												<= SATA_SATACTRL_CMD_TRANSFER;
					SATAC_ATAHostRegisters.Flag_C					<= '1';
					SATAC_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_DMA_WRITE_EXT);				-- Command register
					SATAC_ATAHostRegisters.Control				<= (OTHERS => '0');											-- Control register
					SATAC_ATAHostRegisters.Feature				<= (OTHERS => '0');											-- Feature register
					SATAC_ATAHostRegisters.LBlockAddress	<= ATA_Address_LB;											-- logical block address (LBA)
					SATAC_ATAHostRegisters.SectorCount		<= ATA_BlockCount_LB;										-- 
					
					IF (LastTransfer = '0') THEN
						NextState														<= ST_WRITE_N_WAIT;
					ELSE
						NextState														<= ST_WRITE_L_WAIT;
					END IF;
				elsif (Trans_Status = SATA_TRANS_STATUS_DISCARD_TXDATA) then
					NextState 														<= ST_WRITE_ABORT_TRANSFER;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;
			
			WHEN ST_WRITE_L_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_SENDING;
				TX_en																		<= '1';
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					NextState															<= ST_IDLE;
				elsif (Trans_Status = SATA_TRANS_STATUS_DISCARD_TXDATA) then
					NextState 														<= ST_WRITE_ABORT_TRANSFER;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;

			when ST_WRITE_ABORT_TRANSFER =>
					-- Close transfer for Transport Layer
				Status 																	<= SATA_STREAMCTRL_STATUS_DISCARD_TXDATA;
				TX_ForceEOT															<= '1';
				if (SATAC_TX_Ack = '1') then
					NextState															<= ST_WRITE_DISCARD_REQUEST;
				end if;
				
			when ST_WRITE_DISCARD_REQUEST =>
				-- Transfer for Transport Layer has been closed.
				-- Signal DISCARD for Application Layer and wait until that layer
				-- inserts TX_EOR.
				Status 																	<= SATA_STREAMCTRL_STATUS_DISCARD_TXDATA;
				TX_FIFO_ForceGot 												<= '1';

				if (TX_FIFO_Valid and TX_FIFO_EOR) = '1' then
					NextState 														<= ST_WRITE_WAIT_IDLE;
				end if;

			when ST_WRITE_WAIT_IDLE =>
				-- Wait until TransportLayer signals IDLE or ERROR.
				-- Transport status depends on wether the TransportLayer (IDLE) or the
				-- CommandLayer (ERROR) is faster in discarding data. Timing depends on
				-- FIFO depth between both layers.
				Status 																	<= SATA_STREAMCTRL_STATUS_DISCARD_TXDATA;
				if (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					-- fatal error in Transport Layer
					NextState 														<= ST_ERROR;
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
				elsif ((Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) or
							 (Trans_Status = SATA_TRANS_STATUS_IDLE)) then
					-- transport will be ready for new ATA command
					NextState 														<= ST_ERROR;
					Error_nxt															<= SATA_STREAMCTRL_ERROR_ATA_ERROR;
				end if;
				
			-- ============================================================
			-- ATA command: ATA_CMD_CMD_FLUSH_CACHE
			-- ============================================================
			WHEN ST_FLUSH_CACHE_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_EXECUTING;
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					NextState															<= ST_IDLE;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) THEN
					Error_nxt															<= SATA_STREAMCTRL_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;
				
			-- ============================================================
			-- ATA command: ATA_CMD_CMD_DEVICE_RESET
			-- ============================================================
			WHEN ST_DEVICE_RESET_WAIT =>
				Status																	<= SATA_STREAMCTRL_STATUS_EXECUTING;
				
				IF (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) THEN
					NULL;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) THEN
					NextState															<= ST_IDLE;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) THEN
					Error_nxt															<= SATA_STREAMCTRL_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				ELSIF (Trans_Status = SATA_TRANS_STATUS_ERROR) THEN
					Error_nxt															<= SATA_STREAMCTRL_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				END IF;

			-- ============================================================
			-- Error
			-- stay here if IDENTIFY DEVICE failed, previous error is hold
			-- ============================================================
			WHEN ST_ERROR =>
				Status																	<= SATA_STREAMCTRL_STATUS_ERROR;

				if (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					-- A fatal error occured. Notify above layers and stay here until the above layers
					-- acknowledge this event, e.g. via a command.
					-- TODO Feature Request: Re-initialize via Command.
					NULL;
				elsif (IDF_DriveInformation.Valid = '1') then
					-- ready for new command
					NextState 														<= ST_IDLE;
				elsif (Command = SATA_STREAMCTRL_CMD_IDENTIFY_DEVICE) then
					-- TransportLayer
					SATAC_Command_i												<= SATA_SATACTRL_CMD_TRANSFER;
					SATAC_ATAHostRegisters.Flag_C					<= '1';
					SATAC_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_IDENTIFY_DEVICE);	-- Command register
					SATAC_ATAHostRegisters.Control				<= (OTHERS => '0');												-- Control register
					SATAC_ATAHostRegisters.Feature				<= (OTHERS => '0');												-- Feature register
					SATAC_ATAHostRegisters.LBlockAddress	<= (OTHERS => '0');												-- logical block address (LBA)
					SATAC_ATAHostRegisters.SectorCount		<= (OTHERS => '0');												-- 
					
					-- IdentifyDeviceFilter
					IDF_Enable														<= '1';
					
					NextState															<= ST_IDENTIFY_DEVICE_WAIT;
				end if;

		END CASE;
	END PROCESS;

	SATAC_Command <= SATAC_Command_i;
	
	-- transfer and address generation
	Address_LB_us				<= unsigned(Address_LB);
	BlockCount_LB_us		<= unsigned(BlockCount_LB);
	
	LastTransfer				<= to_sl(ite((Load = '1'), BlockCount_LB_us, BlockCount_LB_us_d) <= BurstCount_us);
	
	PROCESS(Load, LastTransfer, Address_LB_us, BlockCount_LB_us, Address_LB_us_d, BlockCount_LB_us_d, Address_LB_us_d_nx, BlockCount_LB_us_d_nx, Config_BurstSize)
	BEGIN
		IF (Load = '1') THEN
			Address_LB_us_d_nx														<= Address_LB_us;
			BlockCount_LB_us_d_nx													<= BlockCount_LB_us;
		ELSE
			Address_LB_us_d_nx														<= Address_LB_us_d;
			BlockCount_LB_us_d_nx													<= BlockCount_LB_us_d;
		END IF;

		ATA_Address_LB_us			<= Address_LB_us_d_nx;
		
		IF (LastTransfer = '0') THEN
			IF (MAX_BLOCKCOUNT = unsigned(Config_BurstSize)) THEN
				ATA_BlockCount_LB_us												<= (OTHERS => '0');
			ELSE
				ATA_BlockCount_LB_us												<= unsigned(Config_BurstSize);													-- => ATA_MAX_BLOCKCOUNT is encoded as 0x0000000000
			END IF;
		ELSE
			ATA_BlockCount_LB_us													<= BlockCount_LB_us_d_nx(ATA_BlockCount_LB_us'range);		--
		END IF;
	END PROCESS;

	ATA_Address_LB				<= std_logic_vector(ATA_Address_LB_us);
	ATA_BlockCount_LB			<= std_logic_vector(ATA_BlockCount_LB_us);
	
	BurstCount_us					<= ite((Config_BurstSize = (Config_BurstSize'range => '0')), to_unsigned(MAX_BLOCKCOUNT, BurstCount_us'length), unsigned('0' & Config_BurstSize));
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (MyReset = '1') THEN
				Address_LB_us_d						<= (OTHERS => '0');
				BlockCount_LB_us_d				<= (OTHERS => '0');
			ELSE
				IF ((Load = '1') OR (NextTransfer = '1')) THEN
					Address_LB_us_d					<= Address_LB_us_d_nx			+ BurstCount_us;
					BlockCount_LB_us_d			<= BlockCount_LB_us_d_nx	- BurstCount_us;
				END IF;
			END IF;
		END IF;
	END PROCESS;


	-- debug port
	-- ===========================================================================
	genDebugPort : IF (ENABLE_DEBUGPORT = TRUE) GENERATE
		function dbg_EncodeState(st : T_STATE) return STD_LOGIC_VECTOR is
		begin
			return to_slv(T_STATE'pos(st), log2ceilnz(T_STATE'pos(T_STATE'high) + 1));
		end function;
	begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_GenerateEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_STATE loop
					STD.TextIO.write(l, str_replace(T_STATE'image(i), "st_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			constant dummy : boolean := dbg_ExportEncoding("Command Layer", dbg_GenerateEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/FSM_CommandLayer.tok");
		begin
		end generate;
		
    DebugPortOut.FSM          <= dbg_EncodeState(State);
    DebugPortOut.Load         <= Load;
    DebugPortOut.NextTransfer <= NextTransfer;
    DebugPortOut.LastTransfer <= LastTransfer;
	end generate;
end;
