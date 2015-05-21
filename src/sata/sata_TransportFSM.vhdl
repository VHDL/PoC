-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Module:					FSM for SATA Transport Layer
--
-- Description:
-- ------------------------------------
-- See notes on module 'sata_TransportLayer'.
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


ENTITY sata_TransportFSM IS
  GENERIC (
		DEBUG															: BOOLEAN											:= FALSE;
		ENABLE_DEBUGPORT									: BOOLEAN											:= FALSE;
    SIM_WAIT_FOR_INITIAL_REGDH_FIS    : BOOLEAN                     := TRUE -- required by ATA/SATA standard
  );
	PORT (
		Clock															: IN	STD_LOGIC;
		Reset															: IN	STD_LOGIC;

		-- TransportFSM interface
		Command														: IN	T_SATA_TRANS_COMMAND;
		Status														: OUT	T_SATA_TRANS_STATUS;
		Error															: OUT	T_SATA_TRANS_ERROR;
		
		-- DebugPort
		DebugPortOut											: out	T_SATADBG_TRANS_TFSM_OUT;

		-- ATA
		CopyATADeviceRegisterStatus				: OUT	STD_LOGIC;
		ATAHostRegisters									: IN	T_SATA_ATA_HOST_REGISTERS;
		ATADeviceRegisters								: IN	T_SATA_ATA_DEVICE_REGISTERS;
		
		TX_en															: OUT	STD_LOGIC;
		TX_SOT														: IN	STD_LOGIC;
		TX_EOT														: IN	STD_LOGIC;
		
		RX_LastWord												: OUT	STD_LOGIC;
		RX_SOT														: OUT	STD_LOGIC;
		RX_EOT														: OUT	STD_LOGIC;
		
		-- SATAController Status
		Phy_Status												: IN	T_SATA_PHY_STATUS;
		
		-- FIS-FSM interface
		FISD_FISType											: IN	T_SATA_FISTYPE;
		FISD_Status												: IN	T_SATA_FISDECODER_STATUS;
		FISD_SOP													: IN	STD_LOGIC;
		FISD_EOP													: IN	STD_LOGIC;
		
		FISE_FISType											: OUT	T_SATA_FISTYPE;
		FISE_Status												: IN	T_SATA_FISENCODER_STATUS;
		FISE_SOP													: OUT	STD_LOGIC;
		FISE_EOP													: OUT	STD_LOGIC
	);
END;


ARCHITECTURE rtl OF sata_TransportFSM IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;

	TYPE T_STATE IS (
		ST_RESET, ST_IDLE, ST_ERROR,
    ST_INIT_AWAIT_FIS, ST_INIT_RECEIVE_FIS,
		ST_CMDCAT_NODATA_SEND_REGISTER_WAIT,
			ST_CMDCAT_NODATA_AWAIT_FIS,
			ST_CMDCAT_NODATA_RECEIVE_REGISTER,
		ST_CMDCAT_PIOIN_SEND_REGISTER_WAIT,
			ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_F,
			ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_F,
			ST_CMDCAT_PIOIN_AWAIT_DATA_F,
			ST_CMDCAT_PIOIN_RECEIVE_DATA_F,
			ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N,
			ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_N,
			ST_CMDCAT_PIOIN_AWAIT_DATA_N,
			ST_CMDCAT_PIOIN_RECEIVE_DATA_N,
		ST_CMDCAT_DMAIN_SEND_REGISTER_WAIT,
			ST_CMDCAT_DMAIN_AWAIT_FIS_DATA,
			ST_CMDCAT_DMAIN_RECEIVE_DATA_F,
			ST_CMDCAT_DMAIN_AWAIT_FIS,
			ST_CMDCAT_DMAIN_RECEIVE_DATA_N,
			ST_CMDCAT_DMAIN_RECEIVE_REGISTER,
		ST_CMDCAT_DMAOUT_SEND_REGISTER_WAIT,
			ST_CMDCAT_DMAOUT_AWAIT_FIS,
			ST_CMDCAT_DMAOUT_RECEIVE_DMA_ACTIVATE,
			ST_CMDCAT_DMAOUT_RECEIVE_REGISTER,
			ST_CMDCAT_DMAOUT_SEND_DATA,
			ST_TRANSFER_OK
	);
	
	SIGNAL State													: T_STATE													:= ST_RESET;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State			: SIGNAL IS getFSMEncoding_gray(DEBUG);
	
	SIGNAL ATA_Command_Category						: T_SATA_COMMAND_CATEGORY;
	SIGNAL Error_nxt											: T_SATA_TRANS_ERROR;
BEGIN

	ATA_Command_Category	<= to_sata_cmdcat(to_sata_ata_command(ATAHostRegisters.Command));

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State						<= ST_RESET;
				Error 					<= SATA_TRANS_ERROR_NONE;
			ELSE
				State						<= NextState;
				
				if NextState = ST_ERROR then
					Error 				<= Error_nxt;
				elsif (Command /= SATA_TRANS_CMD_NONE) then
					Error 				<= SATA_TRANS_ERROR_NONE; -- clear when issuing new command
				end if;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(State, Command, ATA_Command_Category, ATADeviceRegisters, FISE_Status, FISD_Status, FISD_FISType, FISD_SOP, FISD_EOP, 
          Phy_Status)
	BEGIN
		NextState																<= State;
		
		Status																	<= SATA_TRANS_STATUS_TRANSFERING;
		Error_nxt																<= SATA_TRANS_ERROR_NONE;
    
		CopyATADeviceRegisterStatus	            <= '0';
		
		TX_en																		<= '0';
		FISE_FISType														<= SATA_FISTYPE_UNKNOWN;
		FISE_SOP																<= '0';
		FISE_EOP																<= '0';
		
		RX_LastWord															<= '0';
		RX_SOT																	<= '0';
		RX_EOT																	<= '0';
		
		CASE State IS
      WHEN ST_RESET =>
				-- Clock might be unstable is this state. In this case either
				-- a) Reset is asserted because inital reset of the SATAController is
				--    not finished yet.
				-- b) Phy_Status is constant and not equal to SATA_PHY_STATUS_LINK_OK.
				--    This may happen during reconfiguration due to speed negotiation.
        Status															<= SATA_TRANS_STATUS_RESET;
        
        if (Phy_Status = SATA_PHY_STATUS_COMMUNICATING) then
          IF (SIM_WAIT_FOR_INITIAL_REGDH_FIS = TRUE) THEN
            NextState <= ST_INIT_AWAIT_FIS;
          ELSE
            NextState <= ST_IDLE;
          END IF;
        end if;
        
      WHEN ST_INIT_AWAIT_FIS =>
        -- await initial RegDH FIS
 				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState											<= ST_INIT_RECEIVE_FIS;
					ELSE
						Error_nxt											<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt												<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt												<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
     
      WHEN ST_INIT_RECEIVE_FIS =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						Error_nxt											<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					ELSE
						NextState											<= ST_IDLE;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt												<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt												<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
      
			WHEN ST_IDLE =>
				Status															<= SATA_TRANS_Status_IDLE;

				IF (Command = SATA_TRANS_CMD_TRANSFER) THEN
					CASE ATA_Command_Category IS																			-- choose SATA FIS transfer sequence by ATA command category
						WHEN SATA_CMDCAT_NON_DATA =>
							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
							NextState											<= ST_CMDCAT_NODATA_SEND_REGISTER_WAIT;
						
						WHEN SATA_CMDCAT_PIO_IN =>
							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
							NextState											<= ST_CMDCAT_PIOIN_SEND_REGISTER_WAIT;
							
--						WHEN ATA_CMDCAT_PIO_OUT =>
--							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
--							NextState											<= ST_CMDCAT_PIOOUT_SEND_REGISTER_WAIT;
							
						WHEN SATA_CMDCAT_DMA_IN =>
							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
							NextState											<= ST_CMDCAT_DMAIN_SEND_REGISTER_WAIT;
							
						WHEN SATA_CMDCAT_DMA_OUT =>
							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
							NextState											<= ST_CMDCAT_DMAOUT_SEND_REGISTER_WAIT;
							
--						WHEN ATA_CMDCAT_DMA_IN_QUEUED =>
--							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
--							NextState											<= ST_CMDCAT_DMAINQ_SEND_REGISTER_WAIT;
							
--						WHEN ATA_CMDCAT_DMA_IN_QUEUED =>
--							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
--							NextState											<= ST_CMDCAT_DMAOUTQ_SEND_REGISTER_WAIT;
							
--						WHEN ATA_CMDCAT_PACKET =>
--							NextState									<= ST_IDLE;
							
--						WHEN ATA_CMDCAT_SERVICE =>
--							NextState									<= ST_IDLE;
							
--						WHEN ATA_CMDCAT_DEVICE_RESET =>
--							NextState									<= ST_IDLE;
							
--						WHEN ATA_CMDCAT_DEVICE_DIAGNOSTICS =>
--							NextState									<= ST_IDLE;
							
--						WHEN ATA_CMDCAT_UNKNOWN =>
--							NextState									<= ST_IDLE;
							
						WHEN OTHERS =>
							Error_nxt											<= SATA_TRANS_ERROR_FSM;
							NextState											<= ST_ERROR;
							
					END CASE;
				END IF;
			
			-- ============================================================
			-- ATA command category: NO-DATA
			-- ============================================================
			WHEN ST_CMDCAT_NODATA_SEND_REGISTER_WAIT =>
				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					NextState													<= ST_CMDCAT_NODATA_AWAIT_FIS;
				ELSIF (FISE_Status = SATA_FISE_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISENCODER;
					NextState													<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_NODATA_AWAIT_FIS =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState												<= ST_CMDCAT_NODATA_RECEIVE_REGISTER;
					ELSE
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_NODATA_RECEIVE_REGISTER =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.EndStatus.Error = '1') THEN
						Error_nxt												<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState												<= ST_ERROR;
					ELSE
						NextState												<= ST_TRANSFER_OK;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			-- ============================================================
			-- ATA command category: PIO-IN
			-- ============================================================
			WHEN ST_CMDCAT_PIOIN_SEND_REGISTER_WAIT =>
				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					NextState													<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_F;
				ELSIF (FISE_Status = SATA_FISE_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISENCODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_F =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_PIO_SETUP) THEN
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_F;
					ELSE
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_F =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						Error_nxt												<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState												<= ST_ERROR;
					ELSIF (ATADeviceRegisters.Flags.Direction = '0') THEN							-- (Direction = 0) => PIO-OUT
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSIF ((ATADeviceRegisters.Status.DataReady = '0') AND
								 (ATADeviceRegisters.Status.DataRequest = '0')) THEN				-- (DataReady = 0) => something is wrong ....
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;					
					ELSE
						NextState												<= ST_CMDCAT_PIOIN_AWAIT_DATA_F;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_AWAIT_DATA_F =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_DATA_F;
					ELSE
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_RECEIVE_DATA_F =>
				IF (FISD_SOP = '1') THEN
					RX_SOT													<= '1';
				END IF;
				
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.EndStatus.Error = '1') THEN
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState												<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataReady = '0') THEN						-- (DataReady = 0) => something is wrong ....
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataRequest = '1') THEN					-- (DataRequest = 1) => something is wrong ....
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;	
					ELSE
						IF (ATADeviceRegisters.EndStatus.Busy = '0') THEN
							RX_LastWord										<= '1';
							RX_EOT												<= '1';
							CopyATADeviceRegisterStatus	<= '1';
							NextState											<= ST_TRANSFER_OK;
						ELSE
							-- Closing of actual frame must be delayed until next valid data
							-- frame starts. 
							NextState											<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N;
						END IF;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_PIO_SETUP) THEN
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_N;
					ELSE
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_N =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState												<= ST_ERROR;
					ELSIF (ATADeviceRegisters.Flags.Direction = '0') THEN							-- (Direction = 0) => PIO-OUT
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSIF ((ATADeviceRegisters.Status.DataReady = '0') AND
								 (ATADeviceRegisters.Status.DataRequest = '0')) THEN				-- (DataReady = 0) => something is wrong ....
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;	
					ELSE
						NextState												<= ST_CMDCAT_PIOIN_AWAIT_DATA_N;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_AWAIT_DATA_N =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						-- Next data frame starts, close previous one.
						RX_LastWord											<= '1';
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_DATA_N;
					ELSE
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_RECEIVE_DATA_N =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.EndStatus.Error = '1') THEN
						Error_nxt												<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState												<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataReady = '0') THEN						-- (DataReady = 0) => something is wrong ....
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataRequest = '1') THEN					-- (DataRequest = 1) => something is wrong ....
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;	
					ELSE
						IF (ATADeviceRegisters.EndStatus.Busy = '0') THEN
							RX_LastWord										<= '1';
							RX_EOT												<= '1';
							CopyATADeviceRegisterStatus	<= '1';
							NextState											<= ST_TRANSFER_OK;
						ELSE
							-- Closing of actual frame must be delayed until next valid data
							-- frame starts. 
							NextState											<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N;
						END IF;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;

			
			-- ============================================================
			-- ATA command category: DMA-IN
			-- ============================================================
			WHEN ST_CMDCAT_DMAIN_SEND_REGISTER_WAIT =>
				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					NextState													<= ST_CMDCAT_DMAIN_AWAIT_FIS_DATA;
				ELSIF (FISE_Status = SATA_FISE_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISENCODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAIN_AWAIT_FIS_DATA =>
				-- SOT not yet set.
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_DATA_F;
					ELSIF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_REGISTER;
					ELSE
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- Data or register FIS with CRC error received. Register FIS will be
					-- automatically retried by device. Wait for register dev->host FIS with valid
					-- CRC. 
					NULL;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_DMAIN_RECEIVE_DATA_F =>
				-- Receiving data packet with valid CRC.
				IF (FISD_SOP = '1') THEN
					RX_SOT													<= '1';
				END IF;
				
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- End of packet. Closing of actual frame must be delayed until next
					-- valid data / register frame starts. 
					NextState													<= ST_CMDCAT_DMAIN_AWAIT_FIS;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAIN_AWAIT_FIS =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						-- Next data frame starts, close previous one.
						RX_LastWord											<= '1';
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_DATA_N;
					ELSIF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						-- Final register frame starts, close previous data frame.
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_REGISTER;
					ELSE
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- Data or register FIS with CRC error received. Register FIS will be
					-- automatically retried by device. Wait for register dev->host FIS with valid
					-- CRC. 
					NULL;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAIN_RECEIVE_DATA_N =>
				-- Receiving data packet with valid CRC.
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- End of packet. Closing of actual frame must be delayed until next
					-- valid data / register frame starts. 
					NextState													<= ST_CMDCAT_DMAIN_AWAIT_FIS;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAIN_RECEIVE_REGISTER =>
				-- EOT already signaled or no SOT/EOT.
				-- Register FIS with valid CRC received.
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- register FIS with correct content, check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						Error_nxt												<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState												<= ST_ERROR;
					ELSE
						NextState												<= ST_TRANSFER_OK;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					-- register FIS with invalid content 
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			-- ============================================================
			-- ATA command category: DMA-OUT
			-- ============================================================
			WHEN ST_CMDCAT_DMAOUT_SEND_REGISTER_WAIT =>
				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					NextState													<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				ELSIF (FISE_Status = SATA_FISE_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISENCODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAOUT_AWAIT_FIS =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DMA_ACTIVATE) THEN
						NextState												<= ST_CMDCAT_DMAOUT_RECEIVE_DMA_ACTIVATE;
					ELSIF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState												<= ST_CMDCAT_DMAOUT_RECEIVE_REGISTER;
					ELSE
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAOUT_RECEIVE_DMA_ACTIVATE =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					FISE_FISType											<= SATA_FISTYPE_DATA;
					NextState													<= ST_CMDCAT_DMAOUT_SEND_DATA;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAOUT_SEND_DATA =>
				TX_en																<= '1';
			
				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					NextState													<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				ELSIF (FISE_Status = SATA_FISE_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISENCODER;
					NextState													<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAOUT_RECEIVE_REGISTER =>
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					NextState													<= ST_TRANSFER_OK;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_TRANSFER_OK =>
				Status			<= SATA_TRANS_STATUS_TRANSFER_OK;
				NextState		<= ST_IDLE;
				
			WHEN ST_ERROR =>
				Status			<= SATA_TRANS_STATUS_ERROR;
				NextState		<= ST_IDLE;
				
		END CASE;
	END PROCESS;

	-- debug ports
	-- ==========================================================================================================================================================
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
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
			
			constant dummy : boolean := dbg_ExportEncoding("Transport Layer - TFSM", dbg_GenerateEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/FSM_TransLayer_TFSM.tok");
		begin
		end generate;
		
		DebugPortOut.FSM		<= dbg_EncodeState(State);
	end generate;
END;
