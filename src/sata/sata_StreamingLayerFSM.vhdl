-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Entity:					FSM for SATA Streaming Layer
--
-- Description:
-- -------------------------------------
-- See notes on module 'sata_StreamingLayer'.
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
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_StreamingLayerFSM is
	generic (
		DEBUG															: boolean								:= FALSE;
		ENABLE_DEBUGPORT									: boolean								:= FALSE;			-- export internal signals to upper layers for debug purposes
		SIM_EXECUTE_IDENTIFY_DEVICE				: boolean								:= TRUE				-- required by CommandLayer: load device parameters
	);
	port (
		Clock															: in	std_logic;
		MyReset														: in	std_logic;

		-- for measurement purposes only
		Config_BurstSize									: in	T_SLV_16;

		-- StreamingLayer interface
		Command														: in	T_SATA_STREAMING_COMMAND;
		Status														: out	T_SATA_STREAMING_STATUS;
		Error															: out	T_SATA_STREAMING_ERROR;

		DebugPortOut 											: out T_SATADBG_STREAMING_SFSM_OUT;

		Address_LB												: in	T_SLV_48;
		BlockCount_LB											: in	T_SLV_48;

		TX_FIFO_Valid											: in	std_logic;
		TX_FIFO_EOR												: in	std_logic;
		TX_FIFO_ForceGot									: out	std_logic;

		Trans_TX_Ack											: in	std_logic;
		TX_en															: out	std_logic;
		TX_ForceEOT												: out	std_logic;

		RX_SOR														: out	std_logic;
		RX_EOR														: out	std_logic;
		RX_ForcePut												: out	std_logic;

		-- SATA Controller interface
		Trans_Command											: out	T_SATA_TRANS_COMMAND;
		Trans_Status											: in	T_SATA_TRANS_STATUS;

		Trans_ATAHostRegisters						: out T_SATA_ATA_HOST_REGISTERS;

		Trans_RX_SOT											: in	std_logic;
		Trans_RX_EOT											: in	std_logic;

		-- IdentifyDeviceFilter interface
		IDF_Enable												: out	std_logic;
		IDF_DriveInformation							: in	T_SATA_DRIVE_INFORMATION;
		IDF_Error													: in	std_logic
	);
end entity;


architecture rtl of sata_StreamingLayerFSM is
	attribute KEEP												: boolean;
	attribute FSM_ENCODING								: string;

	-- 1 => single transfer
	-- F => first transfer
	-- N => next transfer
	-- L => last transfer
	type T_STATE is (
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

	signal State													: T_STATE													:= ST_RESET;
	signal NextState											: T_STATE;
	attribute FSM_ENCODING	of State			: signal is getFSMEncoding_gray(DEBUG);

	signal Error_nxt 											: T_SATA_STREAMING_ERROR;

	signal Trans_Command_i								: T_SATA_TRANS_COMMAND;

	signal Load														: std_logic;
	signal NextTransfer										: std_logic;
	signal LastTransfer										: std_logic;
	signal BurstCount_us									: unsigned(16 downto 0);
	signal Address_LB_us									: unsigned(47 downto 0);
	signal Address_LB_us_d								: unsigned(47 downto 0)						:= (others => '0');
	signal Address_LB_us_d_nx							: unsigned(47 downto 0);
	signal BlockCount_LB_us								: unsigned(47 downto 0);
	signal BlockCount_LB_us_d							: unsigned(47 downto 0)						:= (others => '0');
	signal BlockCount_LB_us_d_nx					: unsigned(47 downto 0);

	signal ATA_Address_LB_us							: unsigned(47 downto 0);
	signal ATA_BlockCount_LB_us						: unsigned(15 downto 0);

	signal ATA_Address_LB									: T_SLV_48;
	signal ATA_BlockCount_LB							: T_SLV_16;

	attribute KEEP of Load								: signal is DEBUG					;
	attribute KEEP of NextTransfer				: signal is DEBUG					;
	attribute KEEP of LastTransfer				: signal is DEBUG					;

begin
-- ATA_Device_register => TD=0 -> 40   / TD=1 -> 50

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (MyReset = '1') then
				State						<= ST_RESET;
				Error 					<= SATA_STREAM_ERROR_NONE;

			else
				State						<= NextState;

				if (State /= ST_ERROR) and (NextState = ST_ERROR) then
					Error 				<= Error_nxt;
				elsif (Command /= SATA_STREAM_CMD_NONE) then
					Error 				<= SATA_STREAM_ERROR_NONE; -- clear when issuing new command
				end if;
			end if;
		end if;
	end process;

	process(State, Command, Trans_Status, IDF_Error, IDF_DriveInformation, ATA_Address_LB, ATA_BlockCount_LB,
					LastTransfer, Trans_RX_SOT, Trans_RX_EOT, TX_FIFO_Valid, TX_FIFO_EOR, Trans_TX_Ack)
	begin
		NextState																		<= State;

		Status																			<= SATA_STREAM_STATUS_RESET; -- just in case
		Error_nxt																		<= SATA_STREAM_ERROR_NONE;

		Load																				<= '0';
		NextTransfer																<= '0';

		TX_en																				<= '0';
		TX_ForceEOT																	<= '0';
		TX_FIFO_ForceGot														<= '0';

		RX_SOR																			<= '0';
		RX_EOR																			<= '0';
		RX_ForcePut																	<= '0';

		Trans_Command_i															<= SATA_TRANS_CMD_NONE;
		Trans_ATAHostRegisters.Flag_C								<= '0';
		Trans_ATAHostRegisters.Command							<= to_slv(SATA_ATA_CMD_NONE);	-- Command register
		Trans_ATAHostRegisters.Control							<= (others => '0');						-- Control register
		Trans_ATAHostRegisters.Feature							<= (others => '0');						-- Feature register
		Trans_ATAHostRegisters.LBlockAddress				<= (others => '0');						-- logical block address (LBA)
		Trans_ATAHostRegisters.SectorCount					<= (others => '0');						--

		IDF_Enable																	<= '0';

		case State is
			when ST_RESET =>
				-- Clock might be unstable is this state. In this case either
				-- a) MyReset is asserted because inital reset of the SATAController is
				--    not finished yet.
				-- b) Trans_Status is constant and not equal to SATA_TRANS_STATUS_IDLE.
				--    This may happen during reconfiguration due to speed negotiation.
				Status																			<= SATA_STREAM_STATUS_RESET;

        if (Trans_Status = SATA_TRANS_STATUS_IDLE) then
					if (SIM_EXECUTE_IDENTIFY_DEVICE = TRUE) then
						NextState																<= ST_INIT;
					else
						NextState																<= ST_IDLE;
					end if;
        elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt																	<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState																	<= ST_ERROR;
        end if;

			when ST_INIT =>
        -- assert Trans_Status = SATA_TRANS_STATUS_IDLE
				Status																			<= SATA_STREAM_STATUS_INITIALIZING;

				-- TransportLayer
				Trans_Command_i															<= SATA_TRANS_CMD_TRANSFER;
				Trans_ATAHostRegisters.Flag_C								<= '1';
				Trans_ATAHostRegisters.Command							<= to_slv(SATA_ATA_CMD_IDENTIFY_DEVICE);	-- Command register
				Trans_ATAHostRegisters.Control							<= (others => '0');												-- Control register
				Trans_ATAHostRegisters.Feature							<= (others => '0');												-- Feature register
				Trans_ATAHostRegisters.LBlockAddress				<= (others => '0');												-- logical block address (LBA)
				Trans_ATAHostRegisters.SectorCount					<= (others => '0');												--

				-- IdentifyDeviceFilter
				IDF_Enable																	<= '1';

				NextState																		<= ST_IDENTIFY_DEVICE_WAIT;

			when ST_IDLE =>
        -- assert Trans_Status = SATA_TRANS_STATUS_IDLE
				Status																			<= SATA_STREAM_STATUS_IDLE;

				case Command is
					when SATA_STREAM_CMD_NONE =>
						null;

					when SATA_STREAM_CMD_IDENTIFY_DEVICE =>
						-- TransportLayer
						Trans_Command_i													<= SATA_TRANS_CMD_TRANSFER;
						Trans_ATAHostRegisters.Flag_C						<= '1';
						Trans_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_IDENTIFY_DEVICE);	-- Command register
						Trans_ATAHostRegisters.Control					<= (others => '0');												-- Control register
						Trans_ATAHostRegisters.Feature					<= (others => '0');												-- Feature register
						Trans_ATAHostRegisters.LBlockAddress		<= (others => '0');												-- logical block address (LBA)
						Trans_ATAHostRegisters.SectorCount			<= (others => '0');												--

						-- IdentifyDeviceFilter
						IDF_Enable															<= '1';

						NextState																<= ST_IDENTIFY_DEVICE_WAIT;

					when SATA_STREAM_CMD_READ =>
						-- TransferGenerator
						Load																		<= '1';

						-- TransportLayer
						Trans_Command_i													<= SATA_TRANS_CMD_TRANSFER;
						Trans_ATAHostRegisters.Flag_C						<= '1';
						Trans_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_DMA_READ_EXT);		-- Command register
						Trans_ATAHostRegisters.Control					<= (others => '0');											-- Control register
						Trans_ATAHostRegisters.Feature					<= (others => '0');											-- Feature register
						Trans_ATAHostRegisters.LBlockAddress		<= ATA_Address_LB;											-- logical block address (LBA)
						Trans_ATAHostRegisters.SectorCount			<= ATA_BlockCount_LB;										--

						if (LastTransfer = '0') then
							NextState															<= ST_READ_F_WAIT;
						else
							NextState															<= ST_READ_1_WAIT;
						end if;

					when SATA_STREAM_CMD_WRITE =>
						-- TransferGenerator
						Load																		<= '1';

						-- TransportLayer
						Trans_Command_i													<= SATA_TRANS_CMD_TRANSFER;
						Trans_ATAHostRegisters.Flag_C						<= '1';
						Trans_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_DMA_WRITE_EXT);	-- Command register
						Trans_ATAHostRegisters.Control					<= (others => '0');											-- Control register
						Trans_ATAHostRegisters.Feature					<= (others => '0');											-- Feature register
						Trans_ATAHostRegisters.LBlockAddress		<= ATA_Address_LB;											-- logical block address (LBA)
						Trans_ATAHostRegisters.SectorCount			<= ATA_BlockCount_LB;										--

						if (LastTransfer = '0') then
							NextState															<= ST_WRITE_F_WAIT;
						else
							NextState															<= ST_WRITE_1_WAIT;
						end if;

					when SATA_STREAM_CMD_FLUSH_CACHE =>
						-- TransportLayer
						Trans_Command_i													<= SATA_TRANS_CMD_TRANSFER;
						Trans_ATAHostRegisters.Flag_C						<= '1';
						Trans_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_FLUSH_CACHE_EXT);	-- Command register
						Trans_ATAHostRegisters.Control					<= (others => '0');												-- Control register
						Trans_ATAHostRegisters.Feature					<= (others => '0');												-- Feature register
						Trans_ATAHostRegisters.LBlockAddress		<= (others => '0');												-- logical block address (LBA)
						Trans_ATAHostRegisters.SectorCount			<= (others => '0');												--

						NextState																<= ST_FLUSH_CACHE_WAIT;

					when SATA_STREAM_CMD_DEVICE_RESET =>
						-- TransportLayer
						Trans_Command_i													<= SATA_TRANS_CMD_TRANSFER;
						Trans_ATAHostRegisters.Flag_C						<= '1';
						Trans_ATAHostRegisters.Command					<= to_slv(SATA_ATA_CMD_DEVICE_RESET);			-- Command register
						Trans_ATAHostRegisters.Control					<= (others => '0');												-- Control register
						Trans_ATAHostRegisters.Feature					<= (others => '0');												-- Feature register
						Trans_ATAHostRegisters.LBlockAddress		<= (others => '0');												-- logical block address (LBA)
						Trans_ATAHostRegisters.SectorCount			<= (others => '0');												--

						NextState																<= ST_DEVICE_RESET_WAIT;

					when others =>
						Error_nxt																<= SATA_STREAM_ERROR_FSM;
						NextState																<= ST_ERROR;

				end case;

				-- A link error may occur at any time, e.g., if:
				-- - the other end (e.g. device) requests a link reset via COMRESET
				-- - or the other end was detached and a new device or host connected.
				-- This event is signaled via a TRANSPORT_ERROR.
				-- Transport Layer will ignore above assigned command.
				if(Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt																	<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState 																<= ST_ERROR;
				end if;

			when ST_IDENTIFY_DEVICE_WAIT =>
				if (IDF_DriveInformation.Valid = '0') then
					Status																		<= SATA_STREAM_STATUS_INITIALIZING;
				else
					Status																		<= SATA_STREAM_STATUS_EXECUTING;
				end if;

				IDF_Enable																	<= '1';

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					if (IDF_Error = '1') then
						Error_nxt																<= SATA_STREAM_ERROR_IDENTIFY_DEVICE_ERROR;
						NextState																<= ST_ERROR;
					end if;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					if (IDF_Error = '0') then
						NextState																<= ST_IDENTIFY_DEVICE_CHECK;
					else
						Error_nxt																<= SATA_STREAM_ERROR_IDENTIFY_DEVICE_ERROR;
						NextState																<= ST_ERROR;
					end if;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) then
					Error_nxt																	<= SATA_STREAM_ERROR_ATA_ERROR;
					NextState																	<= ST_ERROR;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt																	<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState																	<= ST_ERROR;
				end if;

			when ST_IDENTIFY_DEVICE_CHECK =>
				Status																			<= SATA_STREAM_STATUS_INITIALIZING;

				if (IDF_DriveInformation.Valid = '1') then
					if ((IDF_DriveInformation.ATACapabilityFlags.SupportsDMA = '1') and
							(IDF_DriveInformation.ATACapabilityFlags.SupportsLBA = '1') and
							(IDF_DriveInformation.ATACapabilityFlags.Supports48BitLBA = '1') and
							(IDF_DriveInformation.ATACapabilityFlags.SupportsFLUSH_CACHE = '1') and
							(IDF_DriveInformation.ATACapabilityFlags.SupportsFLUSH_CACHE_EXT = '1')) then
						NextState																<= ST_IDLE;
					else	-- device not supported
						Error_nxt																<= SATA_STREAM_ERROR_DEVICE_NOT_SUPPORTED;
						NextState																<= ST_ERROR;
					end if;
				else
					-- information are not valid
					Error_nxt																	<= SATA_STREAM_ERROR_IDENTIFY_DEVICE_ERROR;
					NextState																	<= ST_ERROR;
				end if;

			-- ============================================================
			-- ATA command: ATA_CMD_CMD_READ
			-- ============================================================
			when ST_READ_1_WAIT =>
				Status																	<= SATA_STREAM_STATUS_RECEIVING;

				RX_SOR																	<= Trans_RX_SOT;
				RX_EOR																	<= Trans_RX_EOT;

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					NextState															<= ST_IDLE;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) then
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAM_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			when ST_READ_F_WAIT =>
				Status																	<= SATA_STREAM_STATUS_RECEIVING;

				RX_SOR																	<= Trans_RX_SOT;

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					-- TransferGenerator
					NextTransfer													<= '1';

					-- TransportLayer
					Trans_Command_i												<= SATA_TRANS_CMD_TRANSFER;
					Trans_ATAHostRegisters.Flag_C					<= '1';
					Trans_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_DMA_READ_EXT);				-- Command register
					Trans_ATAHostRegisters.Control				<= (others => '0');											-- Control register
					Trans_ATAHostRegisters.Feature				<= (others => '0');											-- Feature register
					Trans_ATAHostRegisters.LBlockAddress	<= ATA_Address_LB;											-- logical block address (LBA)
					Trans_ATAHostRegisters.SectorCount		<= ATA_BlockCount_LB;										--

					if (LastTransfer = '0') then
						NextState														<= ST_READ_N_WAIT;
					else
						NextState														<= ST_READ_L_WAIT;
					end if;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) then
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAM_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			when ST_READ_N_WAIT =>
				Status																	<= SATA_STREAM_STATUS_RECEIVING;

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					-- TransferGenerator
					NextTransfer													<= '1';

					-- TransportLayer
					Trans_Command_i												<= SATA_TRANS_CMD_TRANSFER;
					Trans_ATAHostRegisters.Flag_C					<= '1';
					Trans_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_DMA_READ_EXT);				-- Command register
					Trans_ATAHostRegisters.Control				<= (others => '0');											-- Control register
					Trans_ATAHostRegisters.Feature				<= (others => '0');											-- Feature register
					Trans_ATAHostRegisters.LBlockAddress	<= ATA_Address_LB;											-- logical block address (LBA)
					Trans_ATAHostRegisters.SectorCount		<= ATA_BlockCount_LB;										--

					if (LastTransfer = '0') then
						NextState														<= ST_READ_N_WAIT;
					else
						NextState														<= ST_READ_L_WAIT;
					end if;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) then
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAM_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			when ST_READ_L_WAIT =>
				Status																	<= SATA_STREAM_STATUS_RECEIVING;

				RX_EOR																	<= Trans_RX_EOT;

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					NextState															<= ST_IDLE;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) then
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAM_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					RX_EOR 																<= '1';
					RX_ForcePut 													<= '1';
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			-- ============================================================
			-- ATA command: ATA_CMD_CMD_WRITE
			-- ============================================================
			when ST_WRITE_1_WAIT =>
				Status																	<= SATA_STREAM_STATUS_SENDING;
				TX_en																		<= '1';

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					NextState															<= ST_IDLE;
				elsif (Trans_Status = SATA_TRANS_STATUS_DISCARD_TXDATA) then
					NextState 														<= ST_WRITE_ABORT_TRANSFER;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			when ST_WRITE_F_WAIT =>
				Status																	<= SATA_STREAM_STATUS_SENDING;
				TX_en																		<= '1';

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					-- TransferGenerator
					NextTransfer													<= '1';

					-- TransportLayer
					Trans_Command_i												<= SATA_TRANS_CMD_TRANSFER;
					Trans_ATAHostRegisters.Flag_C					<= '1';
					Trans_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_DMA_WRITE_EXT);				-- Command register
					Trans_ATAHostRegisters.Control				<= (others => '0');											-- Control register
					Trans_ATAHostRegisters.Feature				<= (others => '0');											-- Feature register
					Trans_ATAHostRegisters.LBlockAddress	<= ATA_Address_LB;											-- logical block address (LBA)
					Trans_ATAHostRegisters.SectorCount		<= ATA_BlockCount_LB;										--

					if (LastTransfer = '0') then
						NextState														<= ST_WRITE_N_WAIT;
					else
						NextState														<= ST_WRITE_L_WAIT;
					end if;
				elsif (Trans_Status = SATA_TRANS_STATUS_DISCARD_TXDATA) then
					NextState 														<= ST_WRITE_ABORT_TRANSFER;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			when ST_WRITE_N_WAIT =>
				Status																	<= SATA_STREAM_STATUS_SENDING;
				TX_en																		<= '1';

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					-- TransferGenerator
					NextTransfer													<= '1';

					-- TransportLayer
					Trans_Command_i												<= SATA_TRANS_CMD_TRANSFER;
					Trans_ATAHostRegisters.Flag_C					<= '1';
					Trans_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_DMA_WRITE_EXT);				-- Command register
					Trans_ATAHostRegisters.Control				<= (others => '0');											-- Control register
					Trans_ATAHostRegisters.Feature				<= (others => '0');											-- Feature register
					Trans_ATAHostRegisters.LBlockAddress	<= ATA_Address_LB;											-- logical block address (LBA)
					Trans_ATAHostRegisters.SectorCount		<= ATA_BlockCount_LB;										--

					if (LastTransfer = '0') then
						NextState														<= ST_WRITE_N_WAIT;
					else
						NextState														<= ST_WRITE_L_WAIT;
					end if;
				elsif (Trans_Status = SATA_TRANS_STATUS_DISCARD_TXDATA) then
					NextState 														<= ST_WRITE_ABORT_TRANSFER;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			when ST_WRITE_L_WAIT =>
				Status																	<= SATA_STREAM_STATUS_SENDING;
				TX_en																		<= '1';

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					NextState															<= ST_IDLE;
				elsif (Trans_Status = SATA_TRANS_STATUS_DISCARD_TXDATA) then
					NextState 														<= ST_WRITE_ABORT_TRANSFER;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			when ST_WRITE_ABORT_TRANSFER =>
					-- Close transfer for Transport Layer
				Status 																	<= SATA_STREAM_STATUS_DISCARD_TXDATA;
				TX_ForceEOT															<= '1';
				if (Trans_TX_Ack = '1') then
					NextState															<= ST_WRITE_DISCARD_REQUEST;
				end if;

			when ST_WRITE_DISCARD_REQUEST =>
				-- Transfer for Transport Layer has been closed.
				-- Signal DISCARD for Application Layer and wait until that layer
				-- inserts TX_EOR.
				Status 																	<= SATA_STREAM_STATUS_DISCARD_TXDATA;
				TX_FIFO_ForceGot 												<= '1';

				if (TX_FIFO_Valid and TX_FIFO_EOR) = '1' then
					NextState 														<= ST_WRITE_WAIT_IDLE;
				end if;

			when ST_WRITE_WAIT_IDLE =>
				-- Wait until TransportLayer signals IDLE or ERROR.
				-- Transport status depends on wether the TransportLayer (IDLE) or the
				-- CommandLayer (ERROR) is faster in discarding data. Timing depends on
				-- FIFO depth between both layers.
				Status 																	<= SATA_STREAM_STATUS_DISCARD_TXDATA;
				if (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					-- fatal error in Transport Layer
					NextState 														<= ST_ERROR;
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
				elsif ((Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) or
							 (Trans_Status = SATA_TRANS_STATUS_IDLE)) then
					-- transport will be ready for new ATA command
					NextState 														<= ST_ERROR;
					Error_nxt															<= SATA_STREAM_ERROR_ATA_ERROR;
				end if;

			-- ============================================================
			-- ATA command: ATA_CMD_CMD_FLUSH_CACHE
			-- ============================================================
			when ST_FLUSH_CACHE_WAIT =>
				Status																	<= SATA_STREAM_STATUS_EXECUTING;

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					NextState															<= ST_IDLE;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) then
					Error_nxt															<= SATA_STREAM_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			-- ============================================================
			-- ATA command: ATA_CMD_CMD_DEVICE_RESET
			-- ============================================================
			when ST_DEVICE_RESET_WAIT =>
				Status																	<= SATA_STREAM_STATUS_EXECUTING;

				if (Trans_Status = SATA_TRANS_STATUS_TRANSFERING) then
					null;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_OK) then
					NextState															<= ST_IDLE;
				elsif (Trans_Status = SATA_TRANS_STATUS_TRANSFER_ERROR) then
					Error_nxt															<= SATA_STREAM_ERROR_ATA_ERROR;
					NextState															<= ST_ERROR;
				elsif (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					Error_nxt															<= SATA_STREAM_ERROR_TRANSPORT_ERROR;
					NextState															<= ST_ERROR;
				end if;

			-- ============================================================
			-- Error
			-- stay here if IDENTIFY DEVICE failed, previous error is hold
			-- ============================================================
			when ST_ERROR =>
				Status																	<= SATA_STREAM_STATUS_ERROR;

				if (Trans_Status = SATA_TRANS_STATUS_ERROR) then
					-- A fatal error occured. Notify above layers and stay here until the above layers
					-- acknowledge this event, e.g. via a command.
					-- TODO Feature Request: Re-initialize via Command.
					null;
				elsif (IDF_DriveInformation.Valid = '1') then
					-- ready for new command
					NextState 														<= ST_IDLE;
				elsif (Command = SATA_STREAM_CMD_IDENTIFY_DEVICE) then
					-- TransportLayer
					Trans_Command_i												<= SATA_TRANS_CMD_TRANSFER;
					Trans_ATAHostRegisters.Flag_C					<= '1';
					Trans_ATAHostRegisters.Command				<= to_slv(SATA_ATA_CMD_IDENTIFY_DEVICE);	-- Command register
					Trans_ATAHostRegisters.Control				<= (others => '0');												-- Control register
					Trans_ATAHostRegisters.Feature				<= (others => '0');												-- Feature register
					Trans_ATAHostRegisters.LBlockAddress	<= (others => '0');												-- logical block address (LBA)
					Trans_ATAHostRegisters.SectorCount		<= (others => '0');												--

					-- IdentifyDeviceFilter
					IDF_Enable														<= '1';

					NextState															<= ST_IDENTIFY_DEVICE_WAIT;
				end if;

		end case;
	end process;

	Trans_Command <= Trans_Command_i;

	-- transfer and address generation
	Address_LB_us				<= unsigned(Address_LB);
	BlockCount_LB_us		<= unsigned(BlockCount_LB);

	LastTransfer				<= to_sl(ite((Load = '1'), BlockCount_LB_us, BlockCount_LB_us_d) <= BurstCount_us);

	process(Load, LastTransfer, Address_LB_us, BlockCount_LB_us, Address_LB_us_d, BlockCount_LB_us_d, Address_LB_us_d_nx, BlockCount_LB_us_d_nx, Config_BurstSize)
	begin
		if (Load = '1') then
			Address_LB_us_d_nx														<= Address_LB_us;
			BlockCount_LB_us_d_nx													<= BlockCount_LB_us;
		else
			Address_LB_us_d_nx														<= Address_LB_us_d;
			BlockCount_LB_us_d_nx													<= BlockCount_LB_us_d;
		end if;

		ATA_Address_LB_us			<= Address_LB_us_d_nx;

		if (LastTransfer = '0') then
			if (C_SATA_ATA_MAX_BLOCKCOUNT = unsigned(Config_BurstSize)) then
				ATA_BlockCount_LB_us												<= (others => '0');	-- => ATA_MAX_BLOCKCOUNT is encoded as 0x0000000000
			else
				ATA_BlockCount_LB_us												<= unsigned(Config_BurstSize);
			end if;
		else
			ATA_BlockCount_LB_us													<= BlockCount_LB_us_d_nx(ATA_BlockCount_LB_us'range);		--
		end if;
	end process;

	ATA_Address_LB				<= std_logic_vector(ATA_Address_LB_us);
	ATA_BlockCount_LB			<= std_logic_vector(ATA_BlockCount_LB_us);

	BurstCount_us					<= ite((Config_BurstSize = (Config_BurstSize'range => '0')), to_unsigned(C_SATA_ATA_MAX_BLOCKCOUNT, BurstCount_us'length), unsigned('0' & Config_BurstSize));

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (MyReset = '1') then
				Address_LB_us_d						<= (others => '0');
				BlockCount_LB_us_d				<= (others => '0');
			else
				if ((Load = '1') or (NextTransfer = '1')) then
					Address_LB_us_d					<= Address_LB_us_d_nx			+ BurstCount_us;
					BlockCount_LB_us_d			<= BlockCount_LB_us_d_nx	- BurstCount_us;
				end if;
			end if;
		end if;
	end process;


	-- debug port
	-- ===========================================================================
	genNoDebugPort: if not ENABLE_DEBUGPORT generate
		DebugPortOut <= C_SATADBG_STREAMING_SFSM_OUT_EMPTY;
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

			constant dummy : boolean := dbg_ExportEncoding("Streaming Layer", dbg_GenerateEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/FSM_StreamingLayer.tok");
		begin
		end generate;

    DebugPortOut.FSM          <= dbg_EncodeState(State);
    DebugPortOut.Load         <= Load;
    DebugPortOut.NextTransfer <= NextTransfer;
    DebugPortOut.LastTransfer <= LastTransfer;
	end generate;
end;
