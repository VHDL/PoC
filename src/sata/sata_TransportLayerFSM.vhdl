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
-- -------------------------------------
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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use 	  PoC.components.all;
use 		PoC.physical.all;
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_TransportLayerFSM is
  generic (
		DEV_INIT_TIMEOUT 									: time 												:= 500 ms;
		NODATA_RETRY_TIMEOUT 							: time 												:=   1 ms;
		DATA_READ_TIMEOUT 								: time 												:= 100 ms;
		DATA_WRITE_TIMEOUT 								: time 												:= 100 ms;
		DEBUG															: boolean											:= FALSE;
		ENABLE_DEBUGPORT									: boolean											:= FALSE;
    SIM_WAIT_FOR_INITIAL_REGDH_FIS    : boolean                     := TRUE -- required by ATA/SATA standard
  );
	port (
		Clock															: in	std_logic;
		MyReset														: in	std_logic;

		-- TransportFSM interface
		Command														: in	T_SATA_TRANS_COMMAND;
		Status														: out	T_SATA_TRANS_STATUS;
		Error															: out	T_SATA_TRANS_ERROR;

		-- DebugPort
		DebugPortOut											: out	T_SATADBG_TRANS_TFSM_OUT;

		-- ATA
		UpdateATAHostRegisters 						: out	std_logic;
		CopyATADeviceRegisterStatus				: out	std_logic;
		ATAHostRegisters									: in	T_SATA_ATA_HOST_REGISTERS;
		ATADeviceRegisters								: in	T_SATA_ATA_DEVICE_REGISTERS;

		TX_en															: out	std_logic;
		TX_ForceAck												: out	std_logic;
		TX_Valid													: in	std_logic;
		TX_EOT														: in	std_logic;

		RX_LastWord												: out	std_logic;
		RX_SOT														: out	std_logic;
		RX_EOT														: out	std_logic;

		-- SATAController Status
		Link_Status												: in	T_SATA_LINK_STATUS;
		SATAGeneration 										: in 	T_SATA_GENERATION;

		-- FIS-FSM interface
		FISD_FISType											: in	T_SATA_FISTYPE;
		FISD_Status												: in	T_SATA_FISDECODER_STATUS;
		FISD_SOP													: in	std_logic;
		FISD_EOP													: in	std_logic;

		FISE_FISType											: out	T_SATA_FISTYPE;
		FISE_Status												: in	T_SATA_FISENCODER_STATUS
	);
end entity;


architecture rtl of sata_TransportLayerFSM is
	attribute KEEP									: boolean;
	attribute FSM_ENCODING					: string;

	type T_STATE is (
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

	signal State													: T_STATE													:= ST_RESET;
	signal NextState											: T_STATE;
	attribute FSM_ENCODING	of State			: signal is getFSMEncoding_gray(DEBUG);

	signal ATA_Command_Category						: T_SATA_COMMAND_CATEGORY;
	signal Error_nxt											: T_SATA_TRANS_ERROR;
	signal Error_en 											: std_logic;
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
	constant DATA_READ_TIMEOUT_SLOT			: natural			:= 0;
	constant DATA_WRITE_TIMEOUT_SLOT		: natural			:= 3;
	constant DEV_INIT_TIMEOUT_SLOT			: natural			:= 6;
	constant NODATA_RETRY_TIMEOUT_SLOT	: natural			:= 9;

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


	signal TC_DevResponse_Enable	 : std_logic;
	signal TC_DevResponse_Load		 : std_logic;
	signal TC_DevResponse_Slot		 : natural range 0 to (TC_DEV_RESPONSE_TABLE'length - 1);
	signal TC_DevResponse_Timeout  : std_logic;

	-- Flag register, set if the response to an ATA command of category NO_DATA
	-- had an CRC error.
	signal NoData_ResponseCRCError_r   : std_logic;
	signal NoData_ResponseCRCError_rst : std_logic;
	signal NoData_ResponseCRCError_set : std_logic;
begin

	ATA_Command_Category	<= to_sata_cmdcat(to_sata_ata_command(ATAHostRegisters.Command));

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (MyReset = '1') then
				State						<= ST_RESET;
				Error_r					<= SATA_TRANS_ERROR_NONE;
			else
				State						<= NextState;

				if Error_en = '1' then
					Error_r				<= Error_nxt;
				end if;
			end if;

			NoData_ResponseCRCError_r <= ffrs(q => NoData_ResponseCRCError_r, rst => NoData_ResponseCRCError_rst, set => NoData_ResponseCRCError_set);
		end if;
	end process;

	Error <= Error_r;

	process(State, Command, ATA_Command_Category, ATADeviceRegisters, TC_DevResponse_Timeout, Error_r,
					NoData_ResponseCRCError_r,
					FISE_Status, FISD_Status, FISD_FISType, FISD_SOP, FISD_EOP,
          Link_Status, SATAGeneration, TX_Valid, TX_EOT)
	begin
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

		case State is
      when ST_RESET =>
				-- Clock might be unstable is this state. In this case either
				-- a) MyReset is asserted because inital reset of the SATAController is
				--    not finished yet.
				-- b) Link_Status is constant and not equal to SATA_LINK_STATUS_IDLE
				--    This may happen during reconfiguration due to speed negotiation.
        Status															<= SATA_TRANS_STATUS_RESET;

        if (Link_Status = SATA_LINK_STATUS_IDLE) then
          if (SIM_WAIT_FOR_INITIAL_REGDH_FIS = TRUE) then
            NextState 										<= ST_INIT_AWAIT_FIS;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(DEV_INIT_TIMEOUT_SLOT, SATAGeneration);
          else
            NextState <= ST_IDLE;
          end if;
        end if;

			-- ============================================================
			-- Receive initial register FIS
			-- ============================================================
      when ST_INIT_AWAIT_FIS =>
        -- Await initial RegDH FIS. Init TC_DevResponse before.
        Status														<= SATA_TRANS_STATUS_INITIALIZING;
				TC_DevResponse_Enable 						<= '1';

 				if (FISD_Status = SATA_FISD_STATUS_RECEIVING) then
					if (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) then
						NextState											<= ST_INIT_RECEIVE_FIS;
					else
						Error_en 											<= '1';
						Error_nxt											<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) then
					-- Register FIS with CRC error received, will be
					-- automatically retried by device. Wait for FIS with valid CRC.
					null;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					Error_en 												<= '1';
					Error_nxt												<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

      when ST_INIT_RECEIVE_FIS =>
				-- Register FIS with valid CRC received.
        Status															<= SATA_TRANS_STATUS_INITIALIZING;

				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- register FIS with correct content, check ATADeviceRegisters
					if (ATADeviceRegisters.Status.Error = '1') then
						Error_en 											<= '1';
						Error_nxt											<= SATA_TRANS_ERROR_DEVICE_ERROR;
						NextState											<= ST_ERROR;
					else
						NextState											<= ST_IDLE;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					-- register FIS with invalid content
					Error_en 												<= '1';
					Error_nxt												<= SATA_TRANS_ERROR_FISDECODER;
					NextState												<= ST_ERROR;
				end if;

			-- ============================================================
			-- IDLE / Check for command
			-- ============================================================
			when ST_IDLE =>
				Status															<= SATA_TRANS_STATUS_IDLE;

				if (Command = SATA_TRANS_CMD_TRANSFER) then
					Error_en 													<= '1'; -- clear error
					Error_nxt													<= SATA_TRANS_ERROR_NONE;
					UpdateATAHostRegisters 						<= '1';
					NextState 												<= ST_CHECK_ATA_HOST_REG;
				end if;

			when ST_CHECK_ATA_HOST_REG =>
				case ATA_Command_Category is																			-- choose SATA FIS transfer sequence by ATA command category
					when SATA_CMDCAT_NON_DATA | SATA_CMDCAT_CONTROL =>
						-- assumes, that FlagC bit is cleared for control FIS transfer
						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
						NextState											<= ST_CMDCAT_NODATA_SEND_REGISTER_WAIT;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(NODATA_RETRY_TIMEOUT_SLOT, SATAGeneration);

					when SATA_CMDCAT_PIO_IN =>
						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
						NextState											<= ST_CMDCAT_PIOIN_SEND_REGISTER_WAIT;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);

--					when ATA_CMDCAT_PIO_OUT =>
--						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
--						NextState											<= ST_CMDCAT_PIOOUT_SEND_REGISTER_WAIT;
--						TC_DevResponse_Load 					<= '1';
--						TC_DevResponse_Slot 					<= TC_Slot(DATA_WRITE_TIMEOUT_SLOT, SATAGeneration);

					when SATA_CMDCAT_DMA_IN =>
						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
						NextState											<= ST_CMDCAT_DMAIN_SEND_REGISTER_WAIT;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);

					when SATA_CMDCAT_DMA_OUT =>
						FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
						NextState											<= ST_CMDCAT_DMAOUT_SEND_REGISTER_WAIT;
						TC_DevResponse_Load 					<= '1';
						TC_DevResponse_Slot 					<= TC_Slot(DATA_WRITE_TIMEOUT_SLOT, SATAGeneration);

--						when ATA_CMDCAT_DMA_IN_QUEUED =>
--							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
--							NextState											<= ST_CMDCAT_DMAINQ_SEND_REGISTER_WAIT;

--						when ATA_CMDCAT_DMA_IN_QUEUED =>
--							FISE_FISType									<= SATA_FISTYPE_REG_HOST_DEV;
--							NextState											<= ST_CMDCAT_DMAOUTQ_SEND_REGISTER_WAIT;

--						when ATA_CMDCAT_PACKET =>
--							NextState									<= ST_IDLE;

--						when ATA_CMDCAT_SERVICE =>
--							NextState									<= ST_IDLE;

--						when ATA_CMDCAT_DEVICE_RESET =>
--							NextState									<= ST_IDLE;

--						when ATA_CMDCAT_DEVICE_DIAGNOSTICS =>
--							NextState									<= ST_IDLE;

--						when ATA_CMDCAT_UNKNOWN =>
--							NextState									<= ST_IDLE;

					when others =>
						Error_en 											<= '1';
						Error_nxt											<= SATA_TRANS_ERROR_FSM;
						NextState											<= ST_ERROR;

				end case;

			-- ============================================================
			-- ATA command category: NO-DATA
			-- ============================================================
			when ST_CMDCAT_NODATA_SEND_REGISTER_WAIT =>
				-- Try to send register to device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISE_Status = SATA_FISE_STATUS_SEND_OK) then
					NextState													<= ST_CMDCAT_NODATA_AWAIT_FIS;
					NoData_ResponseCRCError_rst 			<= '1'; -- reset flag
					TC_DevResponse_Load 							<= '1'; -- preload timer
					TC_DevResponse_Slot 							<= TC_Slot(NODATA_RETRY_TIMEOUT_SLOT, SATAGeneration);
				elsif (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) then
					-- Retry finally failed.
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TRANSMIT_ERROR;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_NODATA_AWAIT_FIS =>
				-- Wait for response from device. Init TC_DevResponse before.
				-- Timeout only if response was once corrupted.
				TC_DevResponse_Enable <= NoData_ResponseCRCError_r;

				if (FISD_Status = SATA_FISD_STATUS_RECEIVING) then
					if (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) then
						NextState												<= ST_CMDCAT_NODATA_RECEIVE_REGISTER;
					else
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) then
					-- Register FIS with CRC error received, will be
					-- automatically retried by device. Wait for FIS with valid CRC.
					-- Timer has already been initialized.
					NoData_ResponseCRCError_set 			<= '1'; -- set flag -> enables timer
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_NODATA_RECEIVE_REGISTER =>
				-- Register FIS with valid CRC received.
				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- register FIS with correct content, check ATADeviceRegisters
					if (ATADeviceRegisters.Status.Error = '1') then
						NextState												<= ST_TRANSFER_ERROR;
					else
						NextState												<= ST_TRANSFER_OK;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					-- register FIS with invalid content
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				end if;

			-- ============================================================
			-- ATA command category: PIO-IN
			-- Timer is reseted every time a data FIS is received completely.
			-- ============================================================
			when ST_CMDCAT_PIOIN_SEND_REGISTER_WAIT =>
				-- Try to send register to device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISE_Status = SATA_FISE_STATUS_SEND_OK) then
					NextState													<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_F;
				elsif (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) then
					-- Retry finally failed.
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TRANSMIT_ERROR;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_F =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISD_Status = SATA_FISD_STATUS_RECEIVING) then
					if (FISD_FISType = SATA_FISTYPE_PIO_SETUP) then
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_F;
					else
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) then
					-- PIO setup FIS with CRC error received, will be
					-- automatically retried by device. Wait for FIS with valid CRC.
					null;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_F =>
				-- PIO setup FIS with valid CRC received.
				-- Decode response from device. Keep timer running, but don't check.
				TC_DevResponse_Enable <= '1';

				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- correct content, check ATADeviceRegisters
					if (ATADeviceRegisters.Status.Error = '1') then
						NextState												<= ST_TRANSFER_ERROR;
					elsif (ATADeviceRegisters.Flags.Direction = '0') then							-- (Direction = 0) => PIO-OUT
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					elsif ((ATADeviceRegisters.Status.DataReady = '0') and
								 (ATADeviceRegisters.Status.DataRequest = '0')) then				-- (DataReady = 0) => something is wrong ....
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					else
						NextState												<= ST_CMDCAT_PIOIN_AWAIT_DATA_F;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					-- incorrect content
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_PIOIN_AWAIT_DATA_F =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISD_Status = SATA_FISD_STATUS_RECEIVING) then
					if (FISD_FISType = SATA_FISTYPE_DATA) then
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_DATA_F;
					else
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) then
					-- TODO: do we have to await a register FIS?
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_PIOIN_RECEIVE_DATA_F =>
				-- Receiving data packet with valid CRC.
				if (FISD_SOP = '1') then
					RX_SOT														<= '1';
				end if;

				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- check ATADeviceRegisters
					if (ATADeviceRegisters.EndStatus.Error = '1') then
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						NextState												<= ST_TRANSFER_ERROR;
					elsif (ATADeviceRegisters.EndStatus.DataReady = '0') then						-- (DataReady = 0) => something is wrong ....
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					elsif (ATADeviceRegisters.EndStatus.DataRequest = '1') then					-- (DataRequest = 1) => something is wrong ....
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					else
						if (ATADeviceRegisters.EndStatus.Busy = '0') then
							RX_LastWord										<= '1';
							RX_EOT												<= '1';
							CopyATADeviceRegisterStatus		<= '1';
							NextState											<= ST_TRANSFER_OK;
						else
							-- Closing of actual frame must be delayed until next valid data
							-- frame starts. Start new timeout cycle.
							NextState											<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N;
							TC_DevResponse_Load 					<= '1';
							TC_DevResponse_Slot 					<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);
						end if;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISD_Status = SATA_FISD_STATUS_RECEIVING) then
					if (FISD_FISType = SATA_FISTYPE_PIO_SETUP) then
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_N;
					else
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) then
					-- TODO: do we have to await a register FIS?
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_PIOIN_RECEIVE_PIO_SETUP_N =>
				-- PIO setup FIS with valid CRC received.
				-- Decode response from device. Keep timer running, but don't check.
				TC_DevResponse_Enable <= '1';

				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- correct content, check ATADeviceRegisters
					if (ATADeviceRegisters.Status.Error = '1') then
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						NextState												<= ST_TRANSFER_ERROR;
					elsif (ATADeviceRegisters.Flags.Direction = '0') then							-- (Direction = 0) => PIO-OUT
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					elsif ((ATADeviceRegisters.Status.DataReady = '0') and
								 (ATADeviceRegisters.Status.DataRequest = '0')) then				-- (DataReady = 0) => something is wrong ....
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					else
						NextState												<= ST_CMDCAT_PIOIN_AWAIT_DATA_N;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					-- incorrect content
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_PIOIN_AWAIT_DATA_N =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISD_Status = SATA_FISD_STATUS_RECEIVING) then
					if (FISD_FISType = SATA_FISTYPE_DATA) then
						-- Next data frame starts, close previous one.
						RX_LastWord											<= '1';
						NextState												<= ST_CMDCAT_PIOIN_RECEIVE_DATA_N;
					else
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) then
					-- TODO: do we have to await a register FIS?
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_RECEIVE_ERROR;
					NextState													<= ST_ERROR;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_PIOIN_RECEIVE_DATA_N =>
				-- Receiving data packet with valid CRC.
				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- check ATADeviceRegisters
					if (ATADeviceRegisters.EndStatus.Error = '1') then
						NextState												<= ST_TRANSFER_ERROR;
					elsif (ATADeviceRegisters.EndStatus.DataReady = '0') then						-- (DataReady = 0) => something is wrong ....
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					elsif (ATADeviceRegisters.EndStatus.DataRequest = '1') then					-- (DataRequest = 1) => something is wrong ....
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					else
						if (ATADeviceRegisters.EndStatus.Busy = '0') then
							RX_LastWord										<= '1';
							RX_EOT												<= '1';
							CopyATADeviceRegisterStatus	<= '1';
							NextState											<= ST_TRANSFER_OK;
						else
							-- Closing of actual frame must be delayed until next valid data
							-- frame starts. Start new timeout cycle.
							NextState											<= ST_CMDCAT_PIOIN_AWAIT_PIO_SETUP_N;
							TC_DevResponse_Load 					<= '1';
							TC_DevResponse_Slot 					<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);
						end if;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				end if;


			-- ============================================================
			-- ATA command category: DMA-IN
			-- Timer is reseted every time a data FIS is received completely.
			-- ============================================================
			when ST_CMDCAT_DMAIN_SEND_REGISTER_WAIT =>
				-- Try to send register to device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISE_Status = SATA_FISE_STATUS_SEND_OK) then
					NextState													<= ST_CMDCAT_DMAIN_AWAIT_FIS_DATA;
				elsif (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) then
					-- Retry finally failed.
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TRANSMIT_ERROR;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_DMAIN_AWAIT_FIS_DATA =>
				-- SOT not yet set.
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISD_Status = SATA_FISD_STATUS_RECEIVING) then
					if (FISD_FISType = SATA_FISTYPE_DATA) then
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_DATA_F;
					elsif (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) then
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_REGISTER;
					else
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) then
					-- Data or register FIS with CRC error received. Register FIS will be
					-- automatically retried by device. Wait for register dev->host FIS with valid
					-- CRC.
					null;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_DMAIN_RECEIVE_DATA_F =>
				-- Receiving data packet with valid CRC.
				if (FISD_SOP = '1') then
					RX_SOT													<= '1';
				end if;

				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- End of packet. Closing of actual frame must be delayed until next
					-- valid data / register frame starts. Start new timeout cycle.
					NextState													<= ST_CMDCAT_DMAIN_AWAIT_FIS;
					TC_DevResponse_Load 							<= '1';
					TC_DevResponse_Slot 							<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_DMAIN_AWAIT_FIS =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISD_Status = SATA_FISD_STATUS_RECEIVING) then
					if (FISD_FISType = SATA_FISTYPE_DATA) then
						-- Next data frame starts, close previous one.
						RX_LastWord											<= '1';
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_DATA_N;
					elsif (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) then
						-- Final register frame starts, close previous data frame.
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						NextState												<= ST_CMDCAT_DMAIN_RECEIVE_REGISTER;
					else
						RX_LastWord											<= '1';
						RX_EOT													<= '1';
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_ERROR;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) then
					-- Data or register FIS with CRC error received. Register FIS will be
					-- automatically retried by device. Wait for register dev->host FIS with valid
					-- CRC.
					null;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_DMAIN_RECEIVE_DATA_N =>
				-- Receiving data packet with valid CRC.
				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- End of packet. Closing of actual frame must be delayed until next
					-- valid data / register frame starts. Start new timeout cycle.
					NextState													<= ST_CMDCAT_DMAIN_AWAIT_FIS;
					TC_DevResponse_Load 							<= '1';
					TC_DevResponse_Slot 							<= TC_Slot(DATA_READ_TIMEOUT_SLOT, SATAGeneration);
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					RX_LastWord												<= '1';
					RX_EOT														<= '1';
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				end if;

			when ST_CMDCAT_DMAIN_RECEIVE_REGISTER =>
				-- EOT already signaled or no SOT/EOT.
				-- Register FIS with valid CRC received.
				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- register FIS with correct content, check ATADeviceRegisters
					if (ATADeviceRegisters.Status.Error = '1') then
						NextState												<= ST_TRANSFER_ERROR;
					else
						NextState												<= ST_TRANSFER_OK;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					-- register FIS with invalid content
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_ERROR;
				end if;

			-- ============================================================
			-- ATA command category: DMA-OUT
			-- Timer is reseted every time we send a new FIS to the device.
			-- ============================================================
			when ST_CMDCAT_DMAOUT_SEND_REGISTER_WAIT =>
				-- Try to send register to device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISE_Status = SATA_FISE_STATUS_SEND_OK) then
					NextState													<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				elsif (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) then
					-- Retry finally failed.
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TRANSMIT_ERROR;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				end if;

			when ST_CMDCAT_DMAOUT_AWAIT_FIS =>
				-- Wait for response from device. Init TC_DevResponse before.
				TC_DevResponse_Enable <= '1';

				if (FISD_Status = SATA_FISD_STATUS_RECEIVING) then
					if (FISD_FISType = SATA_FISTYPE_DMA_ACTIVATE) then
						NextState												<= ST_CMDCAT_DMAOUT_RECEIVE_DMA_ACTIVATE;
					elsif (FISD_FISType = SATA_FISTYPE_REG_DEV_HOST) then
						NextState												<= ST_CMDCAT_DMAOUT_RECEIVE_REGISTER;
					else
						Error_en 												<= '1';
						Error_nxt												<= SATA_TRANS_ERROR_FSM;
						NextState												<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_CRC_ERROR) then
					-- DMA activate or register FIS with CRC error received. Both FIS will be
					-- automatically retried by device. Wait for FIS with valid CRC.
					-- Do not reset timeout.
					null;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				elsif (TC_DevResponse_Timeout = '1') then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_TIMEOUT;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				end if;

			when ST_CMDCAT_DMAOUT_RECEIVE_DMA_ACTIVATE =>
				-- Receiving DMA activate with valid CRC.
				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- End of FIS and valid content. Start new timeout cycle.
					FISE_FISType											<= SATA_FISTYPE_DATA;
					NextState													<= ST_CMDCAT_DMAOUT_SEND_DATA;
					TC_DevResponse_Load 							<= '1';
					TC_DevResponse_Slot 							<= TC_Slot(DATA_WRITE_TIMEOUT_SLOT, SATAGeneration);
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				end if;

			when ST_CMDCAT_DMAOUT_SEND_DATA =>
				-- Sending data. Might timeout if Data FIS is not recognized by device
				-- due to transmission error in FIS header. Init TC_DevResponse before.
				TX_en																<= '1';
				TC_DevResponse_Enable 							<= '1';

				if (FISE_Status = SATA_FISE_STATUS_SEND_OK) then
					-- DMA Active FIS (if more data is required) or Register Dev->Host FIS
					-- (if transfer is complete) follows.
					NextState													<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				elsif (FISE_Status = SATA_FISE_STATUS_SEND_ERROR) then
					-- R_ERR while sending data FIS. Must not be retried.
					-- Wait for register dev->host FIS with valid CRC.
					NextState 												<= ST_CMDCAT_DMAOUT_AWAIT_FIS;
				elsif (FISE_Status = SATA_FISE_STATUS_SYNC_ESC) then
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
				end if;

			when ST_CMDCAT_DMAOUT_RECEIVE_REGISTER =>
				-- Register FIS with valid CRC received.
				if (FISD_Status = SATA_FISD_STATUS_RECEIVE_OK) then
					-- register FIS with correct content, check ATADeviceRegisters
					if (ATADeviceRegisters.Status.Error = '1') then
						-- do not set Error_r, just report STATUS_TRANSFER_ERROR below
						NextState												<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
					else
						NextState												<= ST_TRANSFER_OK;
					end if;
				elsif (FISD_Status = SATA_FISD_STATUS_ERROR) then
					-- register FIS with invalid content
					Error_en 													<= '1';
					Error_nxt													<= SATA_TRANS_ERROR_FISDECODER;
					NextState													<= ST_CMDCAT_DMAOUT_DISCARD_TRANSFER;
				end if;

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
			when ST_TRANSFER_OK =>
				-- assert(Error = ERROR_NONE)
				Status			<= SATA_TRANS_STATUS_TRANSFER_OK;

				if (Command = SATA_TRANS_CMD_TRANSFER) then
					UpdateATAHostRegisters 						<= '1';
					NextState 												<= ST_CHECK_ATA_HOST_REG;
				else
					NextState		<= ST_IDLE;
				end if;

			when ST_TRANSFER_ERROR =>
				-- assert(Error = ERROR_NONE)
				Status			<= SATA_TRANS_STATUS_TRANSFER_ERROR;

				if (Command = SATA_TRANS_CMD_TRANSFER) then
					UpdateATAHostRegisters 						<= '1';
					NextState 												<= ST_CHECK_ATA_HOST_REG;
				else
					NextState		<= ST_IDLE;
				end if;

			when ST_ERROR =>
				-- A fatal error occured. Notify above layers and stay here until the above layers
				-- acknowledge this event, e.g. via a command.
				-- We might come from any state, so reinitialize to a known state in
				-- agreement with above layer, e.g. clear FIFOs, reset FISE and FISD and
				-- so on.
				-- TODO Feature Request: Re-initialize via Command.
				Status			<= SATA_TRANS_STATUS_ERROR;

		end case;

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

	end process;


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
	genNoDebugPort: if not ENABLE_DEBUGPORT generate
		DebugPortOut <= C_SATADBG_TRANS_TFSM_OUT_EMPTY;
	end generate genNoDebugPort;

	genDebugPort : if (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_EncodeState(st : T_STATE) return std_logic_vector is
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
end;
