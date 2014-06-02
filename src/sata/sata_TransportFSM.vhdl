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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.strings.ALL;
--USE			PoC.sata.ALL;


ENTITY sata_TransportFSM IS
  GENERIC (
		DEBUG															: BOOLEAN											:= FALSE;
    SIM_WAIT_FOR_INITIAL_REGDH_FIS    : BOOLEAN                     := TRUE -- required by ATA/SATA standard
  );
	PORT (
		Clock															: IN	STD_LOGIC;
		Reset															: IN	STD_LOGIC;

		-- TransportFSM interface
		Command														: IN	T_SATA_TRANS_COMMAND;
		Status														: OUT	T_SATA_TRANS_STATUS;
		Error															: OUT	T_SATA_TRANS_ERROR;
		
		CopyATADeviceRegisterStatus				: OUT	STD_LOGIC;
		ATAHostRegisters									: IN	T_ATA_HOST_REGISTERS;
		ATADeviceRegisters								: IN	T_ATA_DEVICE_REGISTERS;
		
		TX_en															: OUT	STD_LOGIC;
		--TODO: TX_LastWord												: IN	STD_LOGIC;
		TX_SOT														: IN	STD_LOGIC;
		TX_EOT														: IN	STD_LOGIC;
		
		RX_LastWord												: OUT	STD_LOGIC;
		RX_SOT														: OUT	STD_LOGIC;
		RX_EOT														: OUT	STD_LOGIC;
		
		-- LinkLayer interface
		Link_Command											: OUT	T_SATA_COMMAND;
		Link_Status												: IN	T_SATA_STATUS;
		Link_Error												: IN	T_SATA_ERROR;
		
		-- FIS-FSM interface
		FISD_FISType											: IN	T_SATA_FISTYPE;
		FISD_Status												: IN	T_FISDECODER_STATUS;
		FISD_SOP													: IN	STD_LOGIC;
		FISD_EOP													: IN	STD_LOGIC;
		
		FISE_FISType											: OUT	T_SATA_FISTYPE;
		FISE_Status												: IN	T_FISENCODER_STATUS;
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
	ATTRIBUTE FSM_ENCODING	OF State			: SIGNAL IS ite(DEBUG					, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	SIGNAL ATA_Command_Category						: T_ATA_COMMAND_CATEGORY;
	SIGNAL Error_i													: T_SATA_TRANS_ERROR;
BEGIN

	ATA_Command_Category	<= to_ata_cmdcat(to_ata_cmd(ATAHostRegisters.Command));

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset = '1') OR (Command = SATA_TRANS_CMD_RESET)) THEN
				State			<= ST_RESET;
				Link_Command		<= SATA_CMD_RESET_LINKLAYER;
			ELSE
				State			<= NextState;
				Link_Command		<= SATA_CMD_NONE;
			END IF;
		END IF;
	END PROCESS;
	
	Error <= Error_i WHEN rising_edge(Clock);
	
	PROCESS(State, Command, ATA_Command_Category, ATADeviceRegisters, FISE_Status, FISD_Status, FISD_FISType, FISD_SOP, FISD_EOP, 
          Link_Status)
	BEGIN
		NextState																<= State;
		
		Status																	<= SATA_TRANS_STATUS_TRANSFERING;
		Error_i																		<= SATA_TRANS_ERROR_NONE;
    
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
        Status															<= SATA_TRANS_STATUS_RESET;
        
        IF (Link_Status.PhysicalLayer = SATA_PHY_STATUS_LINK_OK) THEN
          IF (SIM_WAIT_FOR_INITIAL_REGDH_FIS = TRUE) THEN
            NextState <= ST_INIT_AWAIT_FIS;
          ELSE
            NextState <= ST_IDLE;
          END IF;
        END IF;
        
      WHEN ST_INIT_AWAIT_FIS =>
        -- await initial RegDH FIS
 				IF (FISD_Status = FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState											<= ST_INIT_RECEIVE_FIS;
					ELSE
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
     
      WHEN ST_INIT_RECEIVE_FIS =>
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						Error_i													<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					ELSE
						NextState											<= ST_IDLE;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
      
			WHEN ST_IDLE =>
				Status															<= SATA_TRANS_Status_IDLE;

				IF (Command = SATA_TRANS_CMD_TRANSFER) THEN
					CASE ATA_Command_Category IS																			-- choose SATA FIS transfer sequence by ATA command category
						WHEN ATA_CMDCAT_NON_DATA =>
							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
							NextState											<= ST_CMDCAT_NODATA_SEND_REGISTER_WAIT;
						
						WHEN ATA_CMDCAT_PIO_IN =>
							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
							NextState											<= ST_CMDCAT_PIOIN_SEND_REGISTER_WAIT;
							
--						WHEN ATA_CMDCAT_PIO_OUT =>
--							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
--							NextState											<= ST_CMDCAT_PIOOUT_SEND_REGISTER_WAIT;
							
						WHEN ATA_CMDCAT_DMA_IN =>
							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
							NextState											<= ST_CMDCAT_DMAIN_SEND_REGISTER_WAIT;
							
						WHEN ATA_CMDCAT_DMA_OUT =>
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
							Error_i												<= SATA_TRANS_ERROR_FSM;
							NextState										<= ST_ERROR;
							
					END CASE;
				END IF;
			
			-- ============================================================
			-- ATA command category: NO-DATA
			-- ============================================================
			WHEN ST_CMDCAT_NODATA_SEND_REGISTER_WAIT =>
				IF (FISE_Status = FISE_STATUS_SEND_OK) THEN
					NextState												<= ST_CMDCAT_NODATA_AWAIT_FIS;
				ELSIF (FISE_Status = FISE_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISENCODER;
					NextState												<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_NODATA_AWAIT_FIS =>
				IF (FISD_Status = FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState											<= ST_CMDCAT_NODATA_RECEIVE_REGISTER;
					ELSE
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_NODATA_RECEIVE_REGISTER =>
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.EndStatus.Error = '1') THEN
						Error_i													<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					ELSE
						NextState											<= ST_TRANSFER_OK;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			-- ============================================================
			-- ATA command category: PIO-IN
			-- ============================================================
			WHEN ST_CMDCAT_PIOIN_SEND_REGISTER_WAIT =>
				IF (FISE_Status = FISE_STATUS_SEND_OK) THEN
					NextState												<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_F;
				ELSIF (FISE_Status = FISE_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISENCODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_F =>
				IF (FISD_Status = FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_PIO_SETUP) THEN
						NextState											<= ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_F;
					ELSE
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_F =>
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						Error_i													<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					ELSIF (ATADeviceRegisters.Flags.Direction = '0') THEN							-- (Direction = 0) => PIO-OUT
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					ELSIF ((ATADeviceRegisters.Status.DataReady = '0') AND
								 (ATADeviceRegisters.Status.DataRequest = '0')) THEN				-- (DataReady = 0) => something is wrong ....
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;					
					ELSE
						NextState											<= ST_CMDCAT_PIOIN_AWAIT_DATA_F;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_AWAIT_DATA_F =>
				IF (FISD_Status = FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						NextState											<= ST_CMDCAT_PIOIN_RECEIVE_DATA_F;
					ELSE
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_RECEIVE_DATA_F =>
				IF (FISD_SOP = '1') THEN
					RX_SOT													<= '1';
				END IF;
				
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.EndStatus.Error = '1') THEN
						Error_i													<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataReady = '0') THEN						-- (DataReady = 0) => something is wrong ....
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataRequest = '1') THEN					-- (DataRequest = 1) => something is wrong ....
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;	
					ELSE
						IF (ATADeviceRegisters.EndStatus.Busy = '0') THEN
							RX_LastWord									<= '1';
							RX_EOT											<= '1';
							CopyATADeviceRegisterStatus	<= '1';
							NextState										<= ST_TRANSFER_OK;
						ELSE
							RX_LastWord									<= '1';
							NextState										<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N;
						END IF;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N =>
				IF (FISD_Status = FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_PIO_SETUP) THEN
						NextState											<= ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_N;
					ELSE
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_N =>
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						Error_i													<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					ELSIF (ATADeviceRegisters.Flags.Direction = '0') THEN							-- (Direction = 0) => PIO-OUT
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					ELSIF ((ATADeviceRegisters.Status.DataReady = '0') AND
								 (ATADeviceRegisters.Status.DataRequest = '0')) THEN				-- (DataReady = 0) => something is wrong ....
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;	
					ELSE
						NextState											<= ST_CMDCAT_PIOIN_AWAIT_DATA_N;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_AWAIT_DATA_N =>
				IF (FISD_Status = FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						NextState											<= ST_CMDCAT_PIOIN_RECEIVE_DATA_N;
					ELSE
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_PIOIN_RECEIVE_DATA_N =>
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.EndStatus.Error = '1') THEN
						Error_i													<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataReady = '0') THEN						-- (DataReady = 0) => something is wrong ....
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataRequest = '1') THEN					-- (DataRequest = 1) => something is wrong ....
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;	
					ELSE
						IF (ATADeviceRegisters.EndStatus.Busy = '0') THEN
							RX_LastWord									<= '1';
							RX_EOT											<= '1';
							CopyATADeviceRegisterStatus	<= '1';
							NextState										<= ST_TRANSFER_OK;
						ELSE
							RX_LastWord									<= '1';
							NextState										<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N;
						END IF;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;

			
			-- ============================================================
			-- ATA command category: DMA-IN
			-- ============================================================
			WHEN ST_CMDCAT_DMAIN_SEND_REGISTER_WAIT =>
				IF (FISE_Status = FISE_STATUS_SEND_OK) THEN
					NextState												<= ST_CMDCAT_DMAIN_AWAIT_FIS_DATA;
				ELSIF (FISE_Status = FISE_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISENCODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAIN_AWAIT_FIS_DATA =>
				IF (FISD_Status = FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						NextState											<= ST_CMDCAT_DMAIN_RECEIVE_DATA_F;
					ELSIF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState											<= ST_CMDCAT_DMAIN_RECEIVE_REGISTER;
					ELSE
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
				
			WHEN ST_CMDCAT_DMAIN_RECEIVE_DATA_F =>
				IF (FISD_SOP = '1') THEN
					RX_SOT													<= '1';
				END IF;
				
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					NextState												<= ST_CMDCAT_DMAIN_AWAIT_FIS;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAIN_AWAIT_FIS =>
				IF (FISD_Status = FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						RX_LastWord										<= '1';
						NextState											<= ST_CMDCAT_DMAIN_RECEIVE_DATA_N;
					ELSIF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						RX_LastWord										<= '1';
						RX_EOT												<= '1';
						NextState											<= ST_CMDCAT_DMAIN_RECEIVE_REGISTER;
					ELSE
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAIN_RECEIVE_DATA_N =>
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					NextState												<= ST_CMDCAT_DMAIN_AWAIT_FIS;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAIN_RECEIVE_REGISTER =>
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.EndStatus.Error = '1') THEN
						Error_i													<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					ELSE
						NextState											<= ST_TRANSFER_OK;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			-- ============================================================
			-- ATA command category: DMA-OUT
			-- ============================================================
			WHEN ST_CMDCAT_DMAOUT_SEND_REGISTER_WAIT =>
				IF (FISE_Status = FISE_STATUS_SEND_OK) THEN
					NextState												<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				ELSIF (FISE_Status = FISE_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISENCODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAOUT_AWAIT_FIS =>
				IF (FISD_Status = FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DMA_ACTIVATE) THEN
						NextState											<= ST_CMDCAT_DMAOUT_RECEIVE_DMA_ACTIVATE;
					ELSIF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState											<= ST_CMDCAT_DMAOUT_RECEIVE_REGISTER;
					ELSE
						Error_i													<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAOUT_RECEIVE_DMA_ACTIVATE =>
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					FISE_FISType										<= SATA_FISTYPE_DATA;
					NextState												<= ST_CMDCAT_DMAOUT_SEND_DATA;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAOUT_SEND_DATA =>
				TX_en															<= '1';
			
				IF (FISE_Status = FISE_STATUS_SEND_OK) THEN
					NextState												<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				ELSIF (FISE_Status = FISE_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISENCODER;
					NextState												<= ST_ERROR;
				END IF;
			
			WHEN ST_CMDCAT_DMAOUT_RECEIVE_REGISTER =>
				IF (FISD_Status = FISD_STATUS_RECEIVE_OK) THEN
					NextState												<= ST_TRANSFER_OK;
				ELSIF (FISD_Status = FISD_STATUS_CRC_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState												<= ST_ERROR;
				ELSIF (FISD_Status = FISD_STATUS_ERROR) THEN
					Error_i														<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;

			WHEN ST_TRANSFER_OK =>
				Status <= SATA_TRANS_STATUS_TRANSFER_OK;
				NextState <= ST_IDLE;
				
			WHEN ST_ERROR =>
				Status <= SATA_TRANS_STATUS_ERROR;
				NextState	 <= ST_IDLE;
				
		END CASE;
	END PROCESS;
	
END;
