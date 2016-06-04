-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Entity:					FSM for SATA Transport Layer
--
-- Description:
-- ------------------------------------
-- See notes on module 'sata_TransportLayer'.
--
-- The Clock might be only unstable in the FSM state ST_RESET.
-- During Power-up or a ClockNetwork_Reset this unit is hold in the
-- reset state ST_RESET due to MyReset = '1'.
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
use 	  PoC.components.ALL;
use 		PoC.physical.all;
use			PoC.debug.all;
USE			PoC.sata.ALL;
use			PoC.satadbg.all;


ENTITY sata_TransportFSM IS
  GENERIC (
		DEV_INIT_TIMEOUT 									: TIME 												:= 500 ms;
		NODATA_RETRY_TIMEOUT 							: TIME 												:=   1 ms;
		DATA_READ_TIMEOUT 								: TIME 												:= 100 ms;
		DATA_WRITE_TIMEOUT 								: TIME 												:= 100 ms;
		DEBUG															: BOOLEAN											:= FALSE;
		ENABLE_DEBUGPORT									: BOOLEAN											:= FALSE;
    SIM_WAIT_FOR_INITIAL_REGDH_FIS    : BOOLEAN                     := TRUE -- required by ATA/SATA standard
  );
	PORT (
		Clock															: IN	STD_LOGIC;
		MyReset														: IN	STD_LOGIC;

		-- TransportFSM interface
		Command														: IN	T_SATA_TRANS_COMMAND;
		Status														: OUT	T_SATA_TRANS_STATUS;
		Error															: OUT	T_SATA_TRANS_ERROR;

		-- DebugPort
		DebugPortOut											: out	T_SATADBG_TRANS_TFSM_OUT;

		-- ATA
		UpdateATAHostRegisters 						: OUT	STD_LOGIC;
		CopyATADeviceRegisterStatus				: OUT	STD_LOGIC;
		ATAHostRegisters									: IN	T_SATA_ATA_HOST_REGISTERS;
		ATADeviceRegisters								: IN	T_SATA_ATA_DEVICE_REGISTERS;

		TX_en															: OUT	STD_LOGIC;
		TX_ForceAck												: OUT	STD_LOGIC;
		TX_Valid													: IN	STD_LOGIC;
		TX_EOT														: IN	STD_LOGIC;

		RX_LastWord												: OUT	STD_LOGIC;
		RX_SOT														: OUT	STD_LOGIC;
		RX_EOT														: OUT	STD_LOGIC;

		-- SATAController Status
		Link_Status												: IN	T_SATA_LINK_STATUS;
		SATAGeneration 										: in 	T_SATA_GENERATION;

		-- FIS-FSM interface
		FISD_FISType											: IN	T_SATA_FISTYPE;
		FISD_Status												: IN	T_SATA_FISDECODER_STATUS;
		FISD_SOP													: IN	STD_LOGIC;
		FISD_EOP													: IN	STD_LOGIC;

		FISE_FISType											: OUT	T_SATA_FISTYPE;
		FISE_Status												: IN	T_SATA_FISENCODER_STATUS
	);
end entity;


ARCHITECTURE rtl OF sata_TransportFSM IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;

	TYPE T_STATE IS (
		ST_RESET, ST_IDLE, ST_CHECK_ATA_HOST_REG, ST_ERROR,
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
			ST_CMDCAT_DMAOUT_DISCARD_TRANSFER,
			ST_TRANSFER_OK,
			ST_TRANSFER_ERROR
	);

	SIGNAL State													: T_STATE													:= ST_RESET;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State			: SIGNAL IS getFSMEncoding_gray(DEBUG);

	SIGNAL ATA_Command_Category						: T_SATA_COMMAND_CATEGORY;
	SIGNAL Error_nxt											: T_SATA_TRANS_ERROR;
	signal Error_en 											: STD_LOGIC;
	signal Error_r 												: T_SATA_TRANS_ERROR;

	-- Used by timing counters.
	constant CLOCK_GEN1_FREQ							: FREQ				:= 37500 kHz;		-- SATAClock frequency for SATA generation 1
	constant CLOCK_GEN2_FREQ							: FREQ				:= 75 MHz;			-- SATAClock frequency for SATA generation 2
	constant CLOCK_GEN3_FREQ							: FREQ				:= 150 MHz;			-- SATAClock frequency for SATA generation 3

	function TC_Slot(Orig_Slot : natural; SATAGen : T_SATA_GENERATION) return natural is
		variable result : natural;
  begin
		result := Orig_Slot;
		if (SATAGen = SATA_GENERATION_2) then
			result := Orig_Slot + 1;
		elsif (SATAGen = SATA_GENERATION_3) then
			result := Orig_Slot + 2;
		end if;
		return result;
	end;

	-- Timing Counter to check for timeouts of device responses.
	constant DATA_READ_TIMEOUT_SLOT			: NATURAL			:= 0;
	constant DATA_WRITE_TIMEOUT_SLOT		: NATURAL			:= 3;
	constant DEV_INIT_TIMEOUT_SLOT			: NATURAL			:= 6;
	constant NODATA_RETRY_TIMEOUT_SLOT	: NATURAL			:= 9;

	constant TC_DEV_RESPONSE_TABLE				: T_NATVEC				:= (
		(DATA_READ_TIMEOUT_SLOT+0) 		=> TimingToCycles(DATA_READ_TIMEOUT,		CLOCK_GEN1_FREQ),			-- slot 0
		(DATA_READ_TIMEOUT_SLOT+1) 		=> TimingToCycles(DATA_READ_TIMEOUT,		CLOCK_GEN2_FREQ),			-- slot 1
		(DATA_READ_TIMEOUT_SLOT+2) 		=> TimingToCycles(DATA_READ_TIMEOUT,		CLOCK_GEN3_FREQ),			-- slot 2
		(DATA_WRITE_TIMEOUT_SLOT+0) 	=> TimingToCycles(DATA_WRITE_TIMEOUT,		CLOCK_GEN1_FREQ),			-- slot 3
		(DATA_WRITE_TIMEOUT_SLOT+1) 	=> TimingToCycles(DATA_WRITE_TIMEOUT,		CLOCK_GEN2_FREQ),			-- slot 4
		(DATA_WRITE_TIMEOUT_SLOT+2) 	=> TimingToCycles(DATA_WRITE_TIMEOUT,		CLOCK_GEN3_FREQ),			-- slot 5
		(DEV_INIT_TIMEOUT_SLOT+0) 		=> TimingToCycles(DEV_INIT_TIMEOUT,			CLOCK_GEN1_FREQ),			-- slot 6
		(DEV_INIT_TIMEOUT_SLOT+1) 		=> TimingToCycles(DEV_INIT_TIMEOUT,			CLOCK_GEN2_FREQ),			-- slot 7
		(DEV_INIT_TIMEOUT_SLOT+2) 		=> TimingToCycles(DEV_INIT_TIMEOUT,			CLOCK_GEN3_FREQ),			-- slot 8
		(NODATA_RETRY_TIMEOUT_SLOT+0) => TimingToCycles(NODATA_RETRY_TIMEOUT,	CLOCK_GEN1_FREQ),			-- slot 9
		(NODATA_RETRY_TIMEOUT_SLOT+1) => TimingToCycles(NODATA_RETRY_TIMEOUT,	CLOCK_GEN2_FREQ),			-- slot 10
		(NODATA_RETRY_TIMEOUT_SLOT+2) => TimingToCycles(NODATA_RETRY_TIMEOUT,	CLOCK_GEN3_FREQ)			-- slot 11
	);


	signal TC_DevResponse_Enable	 : STD_LOGIC;
	signal TC_DevResponse_Load		 : STD_LOGIC;
	signal TC_DevResponse_Slot		 : NATURAL range 0 to (TC_DEV_RESPONSE_TABLE'length - 1);
	signal TC_DevResponse_Timeout  : STD_LOGIC;

	-- Flag register, set if the response to an ATA command of category NO_DATA
	-- had an CRC error.
	signal NoData_ResponseCRCError_r   : std_Logic;
	signal NoData_ResponseCRCError_rst : std_Logic;
	signal NoData_ResponseCRCError_set : std_Logic;
BEGIN

	ATA_Command_Category	<= to_sata_cmdcat(to_sata_ata_command(ATAHostRegisters.Command));

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (MyReset = '1') THEN
				State						<= ST_RESET;
				Error_r					<= SATA_TRANS_ERROR_NONE;
			ELSE
				State						<= NextState;

				if Error_en = '1' then
					Error_r				<= Error_nxt;
				end if;
			END IF;

			NoData_ResponseCRCError_r <= ffrs(q => NoData_ResponseCRCError_r, rst => NoData_ResponseCRCError_rst, set => NoData_ResponseCRCError_set);
		END IF;
	END PROCESS;

	Error <= Error_r;

	PROCESS(State, Command, ATA_Command_Category, ATADeviceRegisters, TC_DevResponse_Timeout, Error_r,
					NoData_ResponseCRCError_r,
					FISE_Status, FISD_Status, FISD_FISType, FISD_SOP, FISD_EOP,
          Link_Status, SATAGeneration, TX_Valid, TX_EOT)
	BEGIN
		NextState																<= State;

		Status																	<= SATA_TRANS_STATUS_TRANSFERING;
    Error_en 																<= '0';
		Error_nxt																<= SATA_TRANS_ERROR_NONE;

		UpdateATAHostRegisters			            <= '0';
		CopyATADeviceRegisterStatus	            <= '0';

		TX_en																		<= '0';
		TX_ForceAck															<= '0';
		FISE_FISType														<= SATA_FISTYPE_UNKNOWN;

		RX_LastWord															<= '0';
		RX_SOT																	<= '0';
		RX_EOT																	<= '0';

		TC_DevResponse_Enable 									<= '0';
		TC_DevResponse_Load	 										<= '0';
		TC_DevResponse_Slot	 										<= 0;
		NoData_ResponseCRCError_rst 						<= '0';
		NoData_ResponseCRCError_set 						<= '0';

		CASE State IS
      WHEN ST_RESET =>
				-- Clock might be unstable is this state. In this case either
				-- a) MyReset is asserted because inital reset of the SATAController is
				--    not finished yet.
				-- b) Link_Status is constant and not equal to SATA_LINK_STATUS_IDLE
				--    This may happen during reconfiguration due to speed negotiation.
        Status															<= SATA_TRANS_STATUS_RESET;

        if (Link_Status = SATA_LINK_STATUS_IDLE) then
          IF (SIM_WAIT_FOR_INITIAL_REGDH_FIS = TRUE) THEN
            NextState 										<= ST_INIT_AWAIT_FIS;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(DEV_INIT_TIMEOUT_SLOT, SATAGeneration);
          ELSE
            NextState <= ST_IDLE;
          END IF;
        end if;

			-- ============================================================
			-- Receive initial register FIS
			-- ============================================================
      WHEN ST_INIT_AWAIT_FIS =>
        -- Await initial RegDH FIS. Init TC_DevResponse before.
        Status														<= SATA_TRANS_STATUS_INITIALIZING;
				TC_DevResponse_Enable 						<= '1';

 				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState											<= ST_INIT_RECEIVE_FIS;
					ELSE
						Error_en 											<= '1';
						Error_nxt											<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- Register FIS with CRC error received, will be
					-- automatically retried by device. Wait for FIS with valid CRC.
					NULL;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_en 												<= '1';
					Error_nxt												<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

      WHEN ST_INIT_RECEIVE_FIS =>
				-- Register FIS with valid CRC received.
        Status															<= SATA_TRANS_STATUS_INITIALIZING;

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- register FIS with correct content, check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						Error_en 											<= '1';
						Error_nxt											<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					ELSE
						NextState											<= ST_IDLE;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					-- register FIS with invalid content
					Error_en 												<= '1';
					Error_nxt												<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				END IF;

			-- ============================================================
			-- IDLE / Check for command
			-- ============================================================
			WHEN ST_IDLE =>
				Status															<= SATA_TRANS_STATUS_IDLE;

				IF (Command = SATA_TRANS_CMD_TRANSFER) THEN
					Error_en 													<= '1'; -- clear error
					Error_nxt													<= SATA_TRANS_ERROR_NONE;
					UpdateATAHostRegisters 						<= '1';
					NextState 												<= ST_CHECK_ATA_HOST_REG;
				end if;

			when ST_CHECK_ATA_HOST_REG =>
				CASE ATA_Command_Category IS																			-- choose SATA FIS transfer sequence by ATA command category
					WHEN SATA_CMDCAT_NON_DATA | SATA_CMDCAT_CONTROL =>
						-- assumes, that FlagC bit is cleared for control FIS transfer
						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
						NextState											<= ST_CMDCAT_NODATA_SEND_REGISTER_WAIT;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(NODATA_RETRY_TIMEOUT_SLOT, SATAGeneration);

					WHEN SATA_CMDCAT_PIO_IN =>
						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
						NextState											<= ST_CMDCAT_PIOIN_SEND_REGISTER_WAIT;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);

--					WHEN ATA_CMDCAT_PIO_OUT =>
--						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
--						NextState											<= ST_CMDCAT_PIOOUT_SEND_REGISTER_WAIT;
--						TC_DevResponse_Load 					<= '1';
--						TC_DevResponse_Slot 					<= TC_Slot(DATA_WRITE_TIMEOUT_SLOT, SATAGeneration);

					WHEN SATA_CMDCAT_DMA_IN =>
						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
						NextState											<= ST_CMDCAT_DMAIN_SEND_REGISTER_WAIT;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);

					WHEN SATA_CMDCAT_DMA_OUT =>
						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
						NextState											<= ST_CMDCAT_DMAOUT_SEND_REGISTER_WAIT;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(DATA_WRITE_TIMEOUT_SLOT, SATAGeneration);

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
						Error_en 											<= '1';
						Error_nxt											<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;

				END CASE;

			-- ============================================================
			-- ATA command category: NO-DATA
			-- ============================================================
			WHEN ST_CMDCAT_NODATA_SEND_REGISTER_WAIT =>
				-- Try to send register to device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					NextState													<= ST_CMDCAT_NODATA_AWAIT_FIS;
					NoData_ResponseCRCError_rst 			<= '1'; -- reset flag
					TC_DevResponse_Load 							<= '1'; -- preload timer
					TC_DevResponse_Slot 							<= TC_Slot(NODATA_RETRY_TIMEOUT_SLOT, SATAGeneration);
				ELSIF (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) THEN
					-- Retry finally failed.
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TRANSMIT_ERROR;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_NODATA_AWAIT_FIS =>
				-- Wait for response from device. Init TC_DevResponse before.
				-- Timeout only if response was once corrupted.
				TC_DevResponse_Enable <= NoData_ResponseCRCError_r;

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState												<= ST_CMDCAT_NODATA_RECEIVE_REGISTER;
					ELSE
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- Register FIS with CRC error received, will be
					-- automatically retried by device. Wait for FIS with valid CRC.
					-- Timer has already been initialized.
					NoData_ResponseCRCError_set 			<= '1'; -- set flag -> enables timer
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_NODATA_RECEIVE_REGISTER =>
				-- Register FIS with valid CRC received.
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- register FIS with correct content, check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						NextState												<= ST_TRANSFER_ERROR;
					ELSE
						NextState												<= ST_TRANSFER_OK;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					-- register FIS with invalid content
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;

			-- ============================================================
			-- ATA command category: PIO-IN
			-- Timer is reseted every time a data FIS is received completely.
			-- ============================================================
			WHEN ST_CMDCAT_PIOIN_SEND_REGISTER_WAIT =>
				-- Try to send register to device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					NextState													<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_F;
				ELSIF (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) THEN
					-- Retry finally failed.
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TRANSMIT_ERROR;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_F =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_PIO_SETUP) THEN
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_F;
					ELSE
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- PIO setup FIS with CRC error received, will be
					-- automatically retried by device. Wait for FIS with valid CRC.
					NULL;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_F =>
				-- PIO setup FIS with valid CRC received.
				-- Decode response from device. Keep timer running, but don't check.
				TC_DevResponse_Enable <= '1';

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- correct content, check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						NextState												<= ST_TRANSFER_ERROR;
					ELSIF (ATADeviceRegisters.Flags.Direction = '0') THEN							-- (Direction = 0) => PIO-OUT
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSIF ((ATADeviceRegisters.Status.DataReady = '0') AND
								 (ATADeviceRegisters.Status.DataRequest = '0')) THEN				-- (DataReady = 0) => something is wrong ....
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSE
						NextState												<= ST_CMDCAT_PIOIN_AWAIT_DATA_F;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					-- incorrect content
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_PIOIN_AWAIT_DATA_F =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_DATA_F;
					ELSE
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- TODO: do we have to await a register FIS?
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_PIOIN_RECEIVE_DATA_F =>
				-- Receiving data packet with valid CRC.
				IF (FISD_SOP = '1') THEN
					RX_SOT														<= '1';
				END IF;

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.EndStatus.Error = '1') THEN
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						NextState												<= ST_TRANSFER_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataReady = '0') THEN						-- (DataReady = 0) => something is wrong ....
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataRequest = '1') THEN					-- (DataRequest = 1) => something is wrong ....
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSE
						IF (ATADeviceRegisters.EndStatus.Busy = '0') THEN
							RX_LastWord										<= '1';
							RX_EOT												<= '1';
							CopyATADeviceRegisterStatus		<= '1';
							NextState											<= ST_TRANSFER_OK;
						ELSE
							-- Closing of actual frame must be delayed until next valid data
							-- frame starts. Start new timeout cycle.
							NextState											<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N;
							TC_DevResponse_Load 					<= '1';
							TC_DevResponse_Slot 					<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);
						END IF;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_PIO_SETUP) THEN
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_N;
					ELSE
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- TODO: do we have to await a register FIS?
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_N =>
				-- PIO setup FIS with valid CRC received.
				-- Decode response from device. Keep timer running, but don't check.
				TC_DevResponse_Enable <= '1';

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- correct content, check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						NextState												<= ST_TRANSFER_ERROR;
					ELSIF (ATADeviceRegisters.Flags.Direction = '0') THEN							-- (Direction = 0) => PIO-OUT
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSIF ((ATADeviceRegisters.Status.DataReady = '0') AND
								 (ATADeviceRegisters.Status.DataRequest = '0')) THEN				-- (DataReady = 0) => something is wrong ....
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSE
						NextState												<= ST_CMDCAT_PIOIN_AWAIT_DATA_N;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					-- incorrect content
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_PIOIN_AWAIT_DATA_N =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						-- Next data frame starts, close previous one.
						RX_LastWord											<= '1';
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_DATA_N;
					ELSE
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- TODO: do we have to await a register FIS?
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_PIOIN_RECEIVE_DATA_N =>
				-- Receiving data packet with valid CRC.
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- check ATADeviceRegisters
					IF (ATADeviceRegisters.EndStatus.Error = '1') THEN
						NextState												<= ST_TRANSFER_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataReady = '0') THEN						-- (DataReady = 0) => something is wrong ....
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					ELSIF (ATADeviceRegisters.EndStatus.DataRequest = '1') THEN					-- (DataRequest = 1) => something is wrong ....
						Error_en 												<= '1';
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
							-- frame starts. Start new timeout cycle.
							NextState											<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N;
							TC_DevResponse_Load 					<= '1';
							TC_DevResponse_Slot 					<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);
						END IF;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;


			-- ============================================================
			-- ATA command category: DMA-IN
			-- Timer is reseted every time a data FIS is received completely.
			-- ============================================================
			WHEN ST_CMDCAT_DMAIN_SEND_REGISTER_WAIT =>
				-- Try to send register to device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					NextState													<= ST_CMDCAT_DMAIN_AWAIT_FIS_DATA;
				ELSIF (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) THEN
					-- Retry finally failed.
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TRANSMIT_ERROR;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_DMAIN_AWAIT_FIS_DATA =>
				-- SOT not yet set.
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DATA) THEN
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_DATA_F;
					ELSIF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_REGISTER;
					ELSE
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- Data or register FIS with CRC error received. Register FIS will be
					-- automatically retried by device. Wait for register dev->host FIS with valid
					-- CRC.
					NULL;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_DMAIN_RECEIVE_DATA_F =>
				-- Receiving data packet with valid CRC.
				IF (FISD_SOP = '1') THEN
					RX_SOT													<= '1';
				END IF;

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- End of packet. Closing of actual frame must be delayed until next
					-- valid data / register frame starts. Start new timeout cycle.
					NextState													<= ST_CMDCAT_DMAIN_AWAIT_FIS;
					TC_DevResponse_Load 							<= '1';
					TC_DevResponse_Slot 							<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_DMAIN_AWAIT_FIS =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

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
						Error_en 												<= '1';
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
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_DMAIN_RECEIVE_DATA_N =>
				-- Receiving data packet with valid CRC.
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- End of packet. Closing of actual frame must be delayed until next
					-- valid data / register frame starts. Start new timeout cycle.
					NextState													<= ST_CMDCAT_DMAIN_AWAIT_FIS;
					TC_DevResponse_Load 							<= '1';
					TC_DevResponse_Slot 							<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;

			WHEN ST_CMDCAT_DMAIN_RECEIVE_REGISTER =>
				-- EOT already signaled or no SOT/EOT.
				-- Register FIS with valid CRC received.
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- register FIS with correct content, check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						NextState												<= ST_TRANSFER_ERROR;
					ELSE
						NextState												<= ST_TRANSFER_OK;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					-- register FIS with invalid content
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				END IF;

			-- ============================================================
			-- ATA command category: DMA-OUT
			-- Timer is reseted every time we send a new FIS to the device.
			-- ============================================================
			WHEN ST_CMDCAT_DMAOUT_SEND_REGISTER_WAIT =>
				-- Try to send register to device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					NextState													<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				ELSIF (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) THEN
					-- Retry finally failed.
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TRANSMIT_ERROR;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				END IF;

			WHEN ST_CMDCAT_DMAOUT_AWAIT_FIS =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				IF (FISD_Status = SATA_FISD_STATUS_RECEIVING) THEN
					IF (FISD_FISType = SATA_FISTYPE_DMA_ACTIVATE) THEN
						NextState												<= ST_CMDCAT_DMAOUT_RECEIVE_DMA_ACTIVATE;
					ELSIF (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) THEN
						NextState												<= ST_CMDCAT_DMAOUT_RECEIVE_REGISTER;
					ELSE
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) THEN
					-- DMA activate or register FIS with CRC error received. Both FIS will be
					-- automatically retried by device. Wait for FIS with valid CRC.
					-- Do not reset timeout.
					NULL;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				END IF;

			WHEN ST_CMDCAT_DMAOUT_RECEIVE_DMA_ACTIVATE =>
				-- Receiving DMA activate with valid CRC.
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- End of FIS and valid content. Start new timeout cycle.
					FISE_FISType											<= SATA_FISTYPE_DATA;
					NextState													<= ST_CMDCAT_DMAOUT_SEND_DATA;
					TC_DevResponse_Load 							<= '1';
					TC_DevResponse_Slot 							<= TC_Slot(DATA_WRITE_TIMEOUT_SLOT, SATAGeneration);
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				END IF;

			WHEN ST_CMDCAT_DMAOUT_SEND_DATA =>
				-- Sending data. Might timeout if Data FIS is not recognized by device
				-- due to transmission error in FIS header. Init TC_DevResponse before.
				TX_en																<= '1';
				TC_DevResponse_Enable 							<= '1';

				IF (FISE_Status = SATA_FISE_STATUS_SEND_OK) THEN
					-- DMA Active FIS (if more data is required) or Register Dev->Host FIS
					-- (if transfer is complete) follows.
					NextState													<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				ELSIF (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) THEN
					-- R_ERR while sending data FIS. Must not be retried.
					-- Wait for register dev->host FIS with valid CRC.
					NextState 												<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				elsif (FISE_Status = SATA_FISE_STATUS_SYNC_ESC) THEN
					-- Sending data FIS aborted with SYNC. Must not be retried.
					-- We can wait for a register dev->host FIS, but the test device was
					-- not ready for any other ATA command afterwards. Thus, go to
					-- blocking error state.
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TRANSMIT_ERROR;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				elsif (TC_DevResponse_Timeout = '1') then
					-- TODO (Minor): Cancel transport in FISEncoder (-> SyncEsc in LinkLayer).
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				END IF;

			WHEN ST_CMDCAT_DMAOUT_RECEIVE_REGISTER =>
				-- Register FIS with valid CRC received.
				IF (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) THEN
					-- register FIS with correct content, check ATADeviceRegisters
					IF (ATADeviceRegisters.Status.Error = '1') THEN
						-- do not set Error_r, just report STATUS_TRANSFER_ERROR below
						NextState												<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
					ELSE
						NextState												<= ST_TRANSFER_OK;
					END IF;
				ELSIF (FISD_Status = SATA_FISD_STATUS_ERROR) THEN
					-- register FIS with invalid content
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				END IF;

			when ST_CMDCAT_DMAOUT_DISCARD_TRANSFER =>
				-- Abort due to any error. Wait for EOT
				-- Error already set.
				Status 															<= SATA_TRANS_STATUS_DISCARD_TXDATA;
				TX_ForceAck 												<= '1';

				if (TX_Valid and TX_EOT) = '1' then
					if (Error_r /= SATA_TRANS_ERROR_NONE) then
						-- fatal error occured
						NextState 											<= ST_ERROR;
					else
						NextState 											<= ST_TRANSFER_ERROR;
					end if;
				end if;

			-- ============================================================
			-- Finished
			-- ============================================================
			WHEN ST_TRANSFER_OK =>
				-- assert(Error = ERROR_NONE)
				Status			<= SATA_TRANS_STATUS_TRANSFER_OK;

				if (Command = SATA_TRANS_CMD_TRANSFER) then
					UpdateATAHostRegisters 						<= '1';
					NextState 												<= ST_CHECK_ATA_HOST_REG;
				else
					NextState		<= ST_IDLE;
				end if;

			WHEN ST_TRANSFER_ERROR =>
				-- assert(Error = ERROR_NONE)
				Status			<= SATA_TRANS_STATUS_TRANSFER_ERROR;

				if (Command = SATA_TRANS_CMD_TRANSFER) then
					UpdateATAHostRegisters 						<= '1';
					NextState 												<= ST_CHECK_ATA_HOST_REG;
				else
					NextState		<= ST_IDLE;
				end if;

			WHEN ST_ERROR =>
				-- A fatal error occured. Notify above layers and stay here until the above layers
				-- acknowledge this event, e.g. via a command.
				-- We might come from any state, so reinitialize to a known state in
				-- agreement with above layer, e.g. clear FIFOs, reset FISE and FISD and
				-- so on.
				-- TODO Feature Request: Re-initialize via Command.
				Status			<= SATA_TRANS_STATUS_ERROR;

		END CASE;

		-- ============================================================
		-- Link Error
		-- Override NextState if LinkLayer reports an error
		-- A link error may occur if:
		-- - the other end (e.g. device) requests a link reset via COMRESET
		-- - or the other end was detached and a new device or host connected.
		-- ============================================================
		if (Link_Status = SATA_LINK_STATUS_ERROR)	then
			NextState														<= ST_ERROR;
			Error_en 														<= '1';
			Error_nxt 													<= SATA_TRANS_ERROR_LINK_ERROR;
		end if;

	END PROCESS;


	-- Timing Counter to check for timeouts of device responses.
	-- ===========================================================================
	TimingCounter_DevResponse: entity work.io_TimingCounter
		generic map (
			TIMING_TABLE => TC_DEV_RESPONSE_TABLE)
		port map (
			Clock		=> Clock,
			Enable	=> TC_DevResponse_Enable,
			Load		=> TC_DevResponse_Load,
			Slot		=> TC_DevResponse_Slot,
			Timeout => TC_DevResponse_Timeout);

	-- debug ports
	-- ===========================================================================
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
