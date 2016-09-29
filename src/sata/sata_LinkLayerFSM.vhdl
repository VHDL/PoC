-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Entity:					FSM for SATA Link Layer
--
-- Description:
-- -------------------------------------
-- See notes on module 'sata_LinkLayer'.
--
-- For input 'MyReset' see assignment in module 'sata_LinkLayer'.
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
use			PoC.components.all;
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_LinkLayerFSM is
	generic (
		DEBUG										: boolean																:= FALSE;
		ENABLE_DEBUGPORT				: boolean																:= FALSE;
		CONTROLLER_TYPE					: T_SATA_DEVICE_TYPE										:= SATA_DEVICE_TYPE_HOST;
		INSERT_ALIGN_INTERVAL		: positive															:= 256
	);
	port (
		Clock										: in	std_logic;
		MyReset									: in	std_logic;

		Status									: out	T_SATA_LINK_STATUS;
		Error										: out	T_SATA_LINK_ERROR;

		-- DebugPort
		DebugPortOut						: out	T_SATADBG_LINK_LLFSM_OUT;

		-- transport layer interface
		Trans_TX_SOF						: in	std_logic;
		Trans_TX_EOF						: in	std_logic;
		--TODO Feature Request: Trans_TX_Abort					: in	STD_LOGIC; -- SyncEscape from Transport Layer

		Trans_TXFS_SendOK				: out	std_logic;
		Trans_TXFS_SyncEsc			: out	std_logic;

		Trans_RX_SOF						: out	std_logic;
		Trans_RX_EOF						: out	std_logic;
		--TODO Feature Request: Trans_RX_Abort					: in	STD_LOGIC; -- SyncEscape from Transport Layer

		Trans_RXFS_CRCOK				: out	std_logic;
		Trans_RXFS_SyncEsc			: out	std_logic;

		-- physical layer interface
		Phy_Status							: in	T_SATA_PHY_STATUS;

		TX_Primitive						: out	T_SATA_PRIMITIVE;
		RX_Primitive						: in	T_SATA_PRIMITIVE;

		-- TX FIFO interface
		TX_FIFO_rst							: out	std_logic;
		TX_FIFO_Valid						: in	std_logic;
		TX_FIFO_got							: out	std_logic;
		TX_FIFO_Commit					: out	std_logic;
		TX_FIFO_Rollback				: out	std_logic;

		-- RX_FSFIFO interface
		TX_FSFIFO_rst						: out	std_logic;
		TX_FSFIFO_put						: out	std_logic;
		TX_FSFIFO_Full					: in	std_logic;

		-- RX_FIFO interface
		RX_FIFO_rst							: out	std_logic;
		RX_FIFO_put							: out	std_logic;
		RX_FIFO_commit					: out	std_logic;
		RX_FIFO_rollback				: out	std_logic;
		RX_FIFO_Full						: in	std_logic;
		RX_FIFO_SpaceAvailable	: in	std_logic;

		-- RX FIFO input/hold register interface
		RX_DataReg_shift				: out	std_logic;

		-- RX_FSFIFO interface
		RX_FSFIFO_rst						: out	std_logic;
		RX_FSFIFO_put						: out	std_logic;
		RX_FSFIFO_Full					: in	std_logic;

		-- RX_CRC interface
		RX_CRC_rst							: out	std_logic;
		RX_CRC_Valid						: out	std_logic;
		RX_CRC_OK								: in	std_logic;

		-- TX_CRC interface
		TX_CRC_rst							: out	std_logic;
		TX_CRC_Valid						: out	std_logic;

		-- TX scrambler interface
		DataScrambler_en				: out	std_logic;
		DataScrambler_rst				: out	std_logic;
--		DummyScrambler_en				: out	STD_LOGIC;
--		DummyScrambler_rst			: out	STD_LOGIC;

		-- RX scrambler interface
		DataUnscrambler_en			: out	std_logic;
		DataUnscrambler_rst			: out	std_logic;

		-- TX MUX interface
		CRCMux_ctrl							: out	std_logic--;
--		ScramblerMux_ctrl				: out	STD_LOGIC
	);
end entity;


architecture rtl of sata_LinkLayerFSM is
	attribute KEEP									: boolean;
	attribute FSM_ENCODING					: string;
	attribute SYN_ENCODING					: string;				-- Altera: FSM_ENCODING

	constant LONG_FRAME_WORDS					: positive		:= 8;
	constant SHORT_FRAME_RETRY_COUNT	: positive		:= 16;

	type T_STATE is (
		ST_RESET,
		ST_NO_COMMUNICATION,
		ST_NO_COMMUNICATION_ERROR,
		ST_IDLE,
		ST_SYNC_ESCAPE,

		-- sending
		ST_TX_SEND_TX_RDY,
		ST_TX_SEND_DATA,
		ST_TX_SEND_HOLD,
		ST_TX_RECEIVED_HOLD,
		ST_TX_SEND_CRC,
		ST_TX_SEND_EOF,
		ST_TX_WAIT,
		ST_TX_DISCARD_FRAME,

		-- receiving
		ST_RX_WAIT_FIFO,
		ST_RX_SEND_RX_RDY,
		ST_RX_RECEIVE_DATA,
		ST_RX_SEND_HOLD,
		ST_RX_RECEIVED_HOLD,
		ST_RX_RECEIVED_EOF,
		ST_RX_SEND_R_OK,
		ST_RX_SEND_R_ERROR
	);
	attribute SYN_ENCODING	of T_STATE		: type is "gray";		-- altera state machine encoding

	-- LinkLayer - Statemachines
	signal State										: T_STATE																		:= ST_RESET;
	signal NextState								: T_STATE;

	attribute FSM_ENCODING	of State		: signal is getFSMEncoding_gray(DEBUG);

	constant INSERT_ALIGN_COUNTER_BITS	: positive															:= log2ceilnz(INSERT_ALIGN_INTERVAL);

	signal InsertAlign									: std_logic;

	signal TX_WordCounter_rst						: std_logic;
	signal TX_WordCounter_inc						: std_logic;
	signal TX_IsLongFrame								: std_logic;

	signal TX_RetryCounter_rst					: std_logic;
	signal TX_RetryCounter_inc					: std_logic;
	signal TX_RetryFailed								: std_logic;

	signal RX_IsSOF									: std_logic;
	signal RX_IsEOF									: std_logic;
	signal RX_IsData								: std_logic;
	signal RX_IsData_d							: std_logic																	:= '0';
	signal RX_IsData_re							: std_logic;

	signal RX_SOF_r									: std_logic																	:= '0';

	signal RX_DataReg_Valid1				: std_logic																	:= '0';
	signal RX_DataReg_Valid2				: std_logic																	:= '0';

	signal RX_FIFO_put_i 						: std_logic;
	signal RX_FIFO_Overflow_r 			: std_logic 																:= '0';

	signal RX_SOFReg_d1							: std_logic																	:= '0';
	signal RX_SOFReg_d2							: std_logic																	:= '0';

	signal RX_CRC_OKReg_set					: std_logic;
	signal RX_CRC_OKReg_rst					: std_logic;
	signal RX_CRC_OKReg_r						: std_logic																	:= '0';

begin

-- ==================================================================
-- LinkLayer - Statemachine
-- ==================================================================
	process(Clock)
	begin
		if rising_edge(Clock) then
			if MyReset = '1' then
				State 	<= ST_RESET;
			else
				State 	<= NextState;
			end if;
		end if;
	end process;


	process(State, Phy_Status, RX_Primitive, Trans_TX_SOF, Trans_TX_EOF, TX_FIFO_Valid,
					RX_FIFO_Full, RX_FIFO_Overflow_r, RX_FIFO_SpaceAvailable, RX_FSFIFO_Full,
					RX_DataReg_Valid2, RX_CRC_OKReg_r, InsertAlign, TX_IsLongFrame, TX_RetryFailed)
	begin
		NextState											<= State;
		Status 												<= SATA_LINK_STATUS_IDLE;
		Error 												<= SATA_LINK_ERROR_NONE;

		-- primitive interface
		TX_Primitive									<= SATA_PRIMITIVE_NONE;

		-- TX FIFO interface
		TX_FIFO_rst										<= '0';
		TX_FIFO_got										<= '0';
		TX_FIFO_Commit								<= '0';
		TX_FIFO_Rollback							<= '0';
		TX_FSFIFO_rst									<= '0';
		TX_FSFIFO_put									<= '0';

		Trans_TXFS_SendOK							<= '0';
		Trans_TXFS_SyncEsc						<= '0';

		TX_WordCounter_rst						<= '0';
		TX_WordCounter_inc						<= '0';

		TX_RetryCounter_rst						<= '0';
		TX_RetryCounter_inc						<= '0';

		-- TX CRC interface
		TX_CRC_rst										<= '0';
		TX_CRC_Valid									<= '0';

		-- TX scrambler interface
		DataScrambler_en							<= '0';
		DataScrambler_rst							<= '0';
--		DummyScrambler_en							<= '0';
--		DummyScrambler_rst						<= '0';

		-- TX MUX interface
		CRCMux_ctrl										<= '0';
--		ScramblerMux_ctrl							<= '0';

		-- RX FIFO interface
		RX_FIFO_rst										<= '0';
		RX_FIFO_commit								<= '0';
		RX_FIFO_rollback							<= '0';
		RX_IsData											<= '0';
		RX_IsSOF											<= '0';
		RX_IsEOF											<= '0';
		RX_FSFIFO_rst									<= '0';
		RX_FSFIFO_put									<= '0';

		Trans_RXFS_CRCOK							<= '0';
		Trans_RXFS_SyncEsc						<= '0';

		-- RX CRC interface
		RX_CRC_rst										<= '0';
		RX_CRC_Valid									<= '0';

		-- RX scrambler interface
		DataUnscrambler_en						<= '0';
		DataUnscrambler_rst						<= '0';

		case State is
			-- ----------------------------------------------------------
			when ST_RESET =>
				Status												<= SATA_LINK_STATUS_NO_COMMUNICATION;
				TX_Primitive									<= SATA_PRIMITIVE_ALIGN;
				TX_FIFO_rst										<= '1';
				TX_FSFIFO_rst									<= '1';
				RX_FIFO_rst										<= '1';
				RX_FSFIFO_rst									<= '1';
				TX_RetryCounter_rst						<= '1';
				NextState											<= ST_NO_COMMUNICATION;

				-- ----------------------------------------------------------
			when ST_NO_COMMUNICATION =>
				Status												<= SATA_LINK_STATUS_NO_COMMUNICATION;
				TX_Primitive									<= SATA_PRIMITIVE_ALIGN;

				if (Phy_Status = SATA_PHY_STATUS_COMMUNICATING) then
					NextState										<= ST_IDLE;
				end if;

				-- ----------------------------------------------------------
			when ST_NO_COMMUNICATION_ERROR =>
				Status												<= SATA_LINK_STATUS_ERROR;
				Error 												<= SATA_LINK_ERROR_PHY_ERROR;
				TX_Primitive									<= SATA_PRIMITIVE_ALIGN;
				-- A link error may occur if:
				-- - the other end (e.g. device) requests a link reset via COMRESET
				-- - or the other end was detached and a new device or host connected.
				-- Notify above layers and stay here until the above layers acknowledge
				-- this event e.g. via a command.
				-- We might come from any state, so reinitialize to a known state in
				-- agreement with above layer, e.g. clear FIFOs, reset RetryCounter and
				-- so on.
				-- TODO Feature Request: Re-initialize via Command.

				--TX_RetryCounter_rst						<= '1';
				--RX_FIFO_rollback							<= '1';
				--TX_FIFO_Commit								<= '1'; -- TODO: Discard?
				NextState											<= ST_NO_COMMUNICATION_ERROR;

				-- ----------------------------------------------------------
			when ST_IDLE =>
				Status 												<= SATA_LINK_STATUS_IDLE;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;

					-- All cases are handled after InsertAlign is '0' again.

				else	-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_SYNC;

					if (RX_Primitive = SATA_PRIMITIVE_TX_RDY) then								-- transmission attempt received
						if (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) then						--
							if (RX_FIFO_SpaceAvailable = '1') and (RX_FSFIFO_Full = '0') then		-- RX FIFOs have space => send RX_RDY
								TX_Primitive					<= SATA_PRIMITIVE_RX_RDY;
								NextState							<= ST_RX_SEND_RX_RDY;
							else																											-- RX FIFO has no space => wait for space
								TX_Primitive					<= SATA_PRIMITIVE_SYNC;
								NextState							<= ST_RX_WAIT_FIFO;
							end if;
						elsif (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) then			--
							if ((Trans_TX_SOF = '1') and (TX_FIFO_Valid = '1')) then	-- start own transmission attempt?
								TX_Primitive					<= SATA_PRIMITIVE_TX_RDY;
								NextState							<= ST_TX_SEND_TX_RDY;
							else
								if (RX_FIFO_SpaceAvailable = '1') and (RX_FSFIFO_Full = '0') then	-- RX FIFOs have space => send RX_RDY
									TX_Primitive				<= SATA_PRIMITIVE_RX_RDY;
									NextState						<= ST_RX_SEND_RX_RDY;
								else																										-- RX FIFO has no space => wait for space
									TX_Primitive				<= SATA_PRIMITIVE_SYNC;
									NextState						<= ST_RX_WAIT_FIFO;
								end if;
							end if;
						end if;
					else
						if ((Trans_TX_SOF = '1') and (TX_FIFO_Valid = '1')) then
							TX_Primitive						<= SATA_PRIMITIVE_TX_RDY;
							NextState								<= ST_TX_SEND_TX_RDY;
						end if;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_SYNC_ESCAPE =>
				Status 												<= SATA_LINK_STATUS_SYNC_ESCAPE;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;

					-- All cases are handled after InsertAlign is '0' again.

				else	-- InsertAlign
					TX_Primitive 								<= SATA_PRIMITIVE_SYNC;

					if ((RX_Primitive = SATA_PRIMITIVE_TX_RDY) or
							(RX_Primitive = SATA_PRIMITIVE_SYNC)) then
						NextState <= ST_IDLE;
					end if;
				end if;

				-- ----------------------------------------------------------
				-- sending
				-- ----------------------------------------------------------
			when ST_TX_SEND_TX_RDY =>
				Status												<= SATA_LINK_STATUS_SENDING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;

					if (RX_Primitive = SATA_PRIMITIVE_RX_RDY) then										-- other side is ready to receive
						null; -- just send align, transistion after InsertAlign = '0'
					elsif (RX_Primitive = SATA_PRIMITIVE_TX_RDY) then									-- transmission attempt from other side
						if (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) then								-- => abort own transmission attempt
							if (RX_FIFO_SpaceAvailable = '1') then												-- RX FIFO has space => send RX_RDY
								NextState							<= ST_RX_SEND_RX_RDY;
							else																													-- RX FIFO has no space => wait for space
								NextState							<= ST_RX_WAIT_FIFO;
							end if;
						elsif (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) then					-- => ignore transmission attempt
							null;
						end if;
					end if;

				else		-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_TX_RDY;

					if (RX_Primitive = SATA_PRIMITIVE_RX_RDY) then										-- other side is ready to receive
						TX_Primitive							<= SATA_PRIMITIVE_SOF;
						TX_WordCounter_rst				<= '1';
						TX_CRC_rst								<= '1';

						DataScrambler_rst					<= '1';
--							DummyScrambler_rst				<= '1';
						NextState						<= ST_TX_SEND_DATA;
					elsif (RX_Primitive = SATA_PRIMITIVE_TX_RDY) then									-- transmission attempt from other side
						if (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) then								-- => abort own transmission attempt
							if (RX_FIFO_SpaceAvailable = '1') then												-- RX FIFO has space => send RX_RDY
								TX_Primitive						<= SATA_PRIMITIVE_RX_RDY;
								NextState								<= ST_RX_SEND_RX_RDY;
							else																													-- RX FIFO has no space => wait for space
								TX_Primitive						<= SATA_PRIMITIVE_SYNC;
								NextState								<= ST_RX_WAIT_FIFO;
							end if;
						elsif (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) then					-- => ignore transmission attempt
							null;
						end if;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_TX_SEND_DATA =>
				Status												<= SATA_LINK_STATUS_SENDING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;

					-- Receiving HOLD and SYNC is handled after InsertAlign is low again.

				else	-- InsertAlign
					if (TX_FIFO_Valid = '1') then																	-- valid data in TX_FIFO
						TX_Primitive							<= SATA_PRIMITIVE_NONE;
						TX_WordCounter_inc				<= '1';
						TX_FIFO_got								<= '1';
						TX_FIFO_Commit 						<= TX_IsLongFrame;
						TX_CRC_Valid							<= '1';
						DataScrambler_en					<= '1';

						if (Trans_TX_EOF = '1') then																-- last payload word in Frame
							if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 							-- abort
								-- SyncEscape by receiver.
								TX_Primitive					<= SATA_PRIMITIVE_SYNC;
								TX_FSFIFO_put 				<= '1';
								Trans_TXFS_SyncEsc		<= '1';
								NextState 						<= ST_TX_DISCARD_FRAME;
							else 																											-- send CRC
								NextState							<= ST_TX_SEND_CRC;
							end if;
						else																												-- normal payload word
							if (RX_Primitive = SATA_PRIMITIVE_HOLD) then							-- hold on sending
								TX_Primitive					<= SATA_PRIMITIVE_HOLD_ACK;
								TX_WordCounter_inc		<= '0';
								TX_FIFO_got						<= '0';
								TX_FIFO_Commit 				<= '0';
								TX_CRC_Valid					<= '0';
								DataScrambler_en			<= '0';
								NextState							<= ST_TX_RECEIVED_HOLD;
							elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then 					-- abort
								-- SyncEscape by receiver.
								TX_Primitive					<= SATA_PRIMITIVE_SYNC;
								TX_FSFIFO_put 				<= '1';
								Trans_TXFS_SyncEsc		<= '1';
								NextState 						<= ST_TX_DISCARD_FRAME;
							end if;
						end if;
					else																													-- empty TX_FIFO => insert HOLD
						if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 								-- abort
								-- SyncEscape by receiver.
							TX_Primitive						<= SATA_PRIMITIVE_SYNC;
							TX_FSFIFO_put 					<= '1';
							Trans_TXFS_SyncEsc			<= '1';
							NextState 							<= ST_TX_DISCARD_FRAME;
						else
							TX_Primitive						<= SATA_PRIMITIVE_HOLD;
							NextState								<= ST_TX_SEND_HOLD;
						end if;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_TX_SEND_HOLD =>
				Status												<= SATA_LINK_STATUS_SENDING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;

					-- Receiving HOLD and SYNC is handled after InsertAlign is low again.

				else	-- InsertAlign
					if (TX_FIFO_Valid = '1') then
						TX_Primitive							<= SATA_PRIMITIVE_NONE;
						TX_WordCounter_inc				<= '1';
						TX_FIFO_got								<= '1';
						TX_FIFO_Commit 						<= TX_IsLongFrame;
						TX_CRC_Valid							<= '1';
						DataScrambler_en					<= '1';

						if (Trans_TX_EOF = '1') then																-- last payload word in frame
							if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 							-- abort
								-- SyncEscape by receiver.
								TX_Primitive					<= SATA_PRIMITIVE_SYNC;
								TX_FSFIFO_put 				<= '1';
								Trans_TXFS_SyncEsc		<= '1';
								NextState 						<= ST_TX_DISCARD_FRAME;
							else
								NextState							<= ST_TX_SEND_CRC;
							end if;
						else 																												-- normal payload word
							if (RX_Primitive = SATA_PRIMITIVE_HOLD) then
								TX_Primitive					<= SATA_PRIMITIVE_HOLD_ACK;
								TX_WordCounter_inc		<= '0';
								TX_FIFO_got						<= '0';
								TX_FIFO_Commit 				<= '0';
								TX_CRC_Valid					<= '0';
								DataScrambler_en			<= '0';
								NextState							<= ST_TX_RECEIVED_HOLD;
							elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then 					-- abort
								-- SyncEscape by receiver.
								TX_Primitive					<= SATA_PRIMITIVE_SYNC;
								TX_FSFIFO_put 				<= '1';
								Trans_TXFS_SyncEsc		<= '1';
								NextState 						<= ST_TX_DISCARD_FRAME;
							end if;
						end if;
					else																													-- empty FIFO => insert HOLD
						if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 								-- abort
								-- SyncEscape by receiver.
							TX_Primitive						<= SATA_PRIMITIVE_SYNC;
							TX_FSFIFO_put 					<= '1';
							Trans_TXFS_SyncEsc			<= '1';
							NextState 							<= ST_TX_DISCARD_FRAME;
						else
							TX_Primitive						<= SATA_PRIMITIVE_HOLD;
						end if;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_TX_RECEIVED_HOLD =>
				-- assert(TX_Fifo_Valid = '1')
				Status												<= SATA_LINK_STATUS_SENDING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;

					-- Receiving HOLD and SYNC is handled after InsertAlign is low again.

				else	-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_HOLD_ACK;

					if ((RX_Primitive = SATA_PRIMITIVE_HOLD) or
							(RX_Primitive = SATA_PRIMITIVE_ALIGN))	then
						null;
					elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then 							-- abort
						-- SyncEscape by receiver.
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						TX_FSFIFO_put 						<= '1';
						Trans_TXFS_SyncEsc				<= '1';
						NextState 								<= ST_TX_DISCARD_FRAME;
					else 																													-- resume sending data
						TX_Primitive							<= SATA_PRIMITIVE_NONE;
						TX_WordCounter_inc				<= '1';
						TX_FIFO_got								<= '1';
						TX_FIFO_Commit 						<= TX_IsLongFrame;
						TX_CRC_Valid							<= '1';
						DataScrambler_en					<= '1';
						if (Trans_TX_EOF = '1') then																-- last payload word in frame
							NextState								<= ST_TX_SEND_CRC;
						else
							NextState								<= ST_TX_SEND_DATA;
						end if;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_TX_SEND_CRC =>
				Status												<= SATA_LINK_STATUS_SENDING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
					-- Receiving SYNC is handled after InsertAlign is low again.

				else
					if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 									-- abort
						-- SyncEscape by receiver.
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						TX_RetryCounter_rst				<= '1';														-- frame finally failed -> reset counter
						TX_FIFO_Commit						<= '1';														-- Commit data FIFO
						TX_FSFIFO_put 						<= '1';
						Trans_TXFS_SyncEsc				<= '1';
						NextState 								<= ST_IDLE;  -- EOF already seen.
					else
						TX_Primitive							<= SATA_PRIMITIVE_NONE;
						CRCMux_ctrl								<= '1';
						DataScrambler_en					<= '1';
						NextState									<= ST_TX_SEND_EOF;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_TX_SEND_EOF =>
				Status												<= SATA_LINK_STATUS_SENDING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
					-- Receiving SYNC is handled after InsertAlign is low again.

				else
					if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 									-- abort
						-- SyncEscape by receiver.
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						TX_RetryCounter_rst				<= '1';														-- frame finally failed -> reset counter
						TX_FIFO_Commit						<= '1';														-- Commit data FIFO
						TX_FSFIFO_put 						<= '1';
						Trans_TXFS_SyncEsc				<= '1';
						NextState 								<= ST_IDLE;  -- EOF already seen.
					else
						TX_Primitive							<= SATA_PRIMITIVE_EOF;
						NextState									<= ST_TX_WAIT;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_TX_WAIT =>
				Status												<= SATA_LINK_STATUS_SENDING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
					-- Handle primitives after InsertAlign is low again.

				else	-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_WAIT_TERM;

					if (RX_Primitive = SATA_PRIMITIVE_R_OK) then
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						TX_RetryCounter_rst				<= '1';										-- frame successfully delivered -> reset counter
						TX_FIFO_Commit						<= '1';										-- Commit data FIFO
						TX_FSFIFO_put							<= '1';										-- Update frame state FIFO
						Trans_TXFS_SendOK					<= '1';										--   with SendOK
						NextState									<= ST_IDLE;
					elsif (RX_Primitive = SATA_PRIMITIVE_R_ERROR) then
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;

						if ((TX_IsLongFrame = '0') and 											-- retry short frame
								(TX_RetryFailed = '0')) then										-- try again
							TX_RetryCounter_inc			<= '1';
							TX_FIFO_Rollback				<= '1';
							NextState								<= ST_IDLE;
						else																								-- don't retry (too long or	finally failed)
							TX_RetryCounter_rst			<= '1';										-- frame finally failed -> reset counter
							TX_FIFO_Commit					<= '1';										-- Commit data FIFO
							TX_FSFIFO_put						<= '1';										-- update frame state FIFO
							NextState								<= ST_IDLE;
						end if;
					elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then 			-- abort
						-- SyncEscape by receiver.
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						TX_RetryCounter_rst				<= '1';										-- frame finally failed -> reset counter
						TX_FIFO_Commit						<= '1';										-- Commit data FIFO
						TX_FSFIFO_put 						<= '1';
						Trans_TXFS_SyncEsc				<= '1';
						NextState 								<= ST_IDLE;  -- EOF already seen.
					end if;
				end if;

			when ST_TX_DISCARD_FRAME =>
				-- SyncEsc requested. Discard remaining frame.
				if (InsertAlign = '1') then
					TX_Primitive 								<= SATA_PRIMITIVE_ALIGN;
				else
					TX_Primitive								<= SATA_PRIMITIVE_SYNC;
				end if;

				TX_RetryCounter_rst						<= '1';												-- frame finally failed -> reset counter
				TX_FIFO_got										<= '1';
				TX_FIFO_Commit 								<= '1';
				if (Trans_TX_EOF = '1') then																-- last payload word in frame
					NextState 									<= ST_IDLE;
				end if;

				-- ----------------------------------------------------------
				-- receiving
				-- ----------------------------------------------------------
			when ST_RX_WAIT_FIFO =>
				Status												<= SATA_LINK_STATUS_RECEIVING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
					-- All cases are handled after InsertAlign is deasserted.

				else		-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_SYNC;

					if (RX_Primitive = SATA_PRIMITIVE_TX_RDY) then
						if (RX_FIFO_SpaceAvailable = '1') and (RX_FSFIFO_Full = '0') then
							TX_Primitive						<= SATA_PRIMITIVE_RX_RDY;
							NextState								<= ST_RX_SEND_RX_RDY;
						end if;
					elsif (RX_Primitive = SATA_PRIMITIVE_ALIGN) then
						null;
					else 	-- may be caused by bit errors
						-- no frame started yet
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						NextState									<= ST_IDLE;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_RX_SEND_RX_RDY =>
				-- assert(RX_FIFO_SpaceAvailable = '1')
				Status												<= SATA_LINK_STATUS_RECEIVING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;

					if (RX_Primitive = SATA_PRIMITIVE_SOF) then
						RX_IsSOF 									<= '1';
						RX_CRC_rst								<= '1';
						DataUnscrambler_rst				<= '1';
						NextState									<= ST_RX_RECEIVE_DATA;
					end if;
					-- All other cases are handled after InsertAlign is deasserted.

				else		-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_RX_RDY;

					if ((RX_Primitive = SATA_PRIMITIVE_TX_RDY) or
							(RX_Primitive = SATA_PRIMITIVE_ALIGN))
					then
						null;
					elsif (RX_Primitive = SATA_PRIMITIVE_SOF) then
						TX_Primitive							<= SATA_PRIMITIVE_R_IP;
						RX_IsSOF 									<= '1';
						RX_CRC_rst								<= '1';
						DataUnscrambler_rst				<= '1';
						NextState									<= ST_RX_RECEIVE_DATA;
					else  																												-- abort
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						NextState									<= ST_IDLE;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_RX_RECEIVE_DATA =>
				Status												<= SATA_LINK_STATUS_RECEIVING;

				if (InsertAlign = '1') then
					TX_Primitive 								<= SATA_PRIMITIVE_ALIGN;

					if (RX_Primitive = SATA_PRIMITIVE_NONE) then 						-- data
						RX_IsData									<= '1';
						RX_CRC_Valid							<= '1';
						DataUnscrambler_en				<= '1';
						if (RX_FIFO_SpaceAvailable = '0') then
							NextState								<= ST_RX_SEND_HOLD;
						end if;
					elsif (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) then
						null; -- stay here even Transport Layer requests abort in the future
					elsif (RX_Primitive = SATA_PRIMITIVE_HOLD) then
						NextState									<= ST_RX_RECEIVED_HOLD;
					elsif (RX_Primitive = SATA_PRIMITIVE_EOF) then
						RX_IsEOF 									<= '1';
						NextState 								<= ST_RX_RECEIVED_EOF;
					end if;

					-- WTRM and SYNC are handled after InsertAlign is low again.

				else		-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_R_IP;

					if (RX_Primitive = SATA_PRIMITIVE_NONE) then 						-- data
						RX_IsData										<= '1';
						RX_CRC_Valid								<= '1';
						DataUnscrambler_en					<= '1';
						if (RX_FIFO_SpaceAvailable = '0') then
							TX_Primitive						<= SATA_PRIMITIVE_HOLD;
							NextState								<= ST_RX_SEND_HOLD;
						end if;
					elsif (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) then
						null; -- stay here even Transport Layer requests abort in the future
					elsif (RX_Primitive = SATA_PRIMITIVE_HOLD) then
						TX_Primitive							<= SATA_PRIMITIVE_HOLD_ACK;
						NextState									<= ST_RX_RECEIVED_HOLD;
					elsif (RX_Primitive = SATA_PRIMITIVE_EOF) then
						RX_IsEOF 									<= '1';
						NextState 								<= ST_RX_RECEIVED_EOF;
					elsif (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) then
						-- In case of bit errors, the single EOF might be missed. After that
						-- WTRM is received. signal as CRC error.
						TX_Primitive							<= SATA_PRIMITIVE_R_ERROR;
						RX_FIFO_rollback 					<= '1';
						RX_FSFIFO_put							<= '1';
						NextState									<= ST_RX_SEND_R_ERROR;
					elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then
						-- SyncEscape by sender.
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						RX_FIFO_rollback 					<= '1';
						RX_FSFIFO_put							<= '1';
						Trans_RXFS_SyncEsc				<= '1';
						NextState									<= ST_IDLE;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_RX_SEND_HOLD =>
				Status												<= SATA_LINK_STATUS_RECEIVING;

				if (InsertAlign = '1') then
					TX_Primitive 								<= SATA_PRIMITIVE_ALIGN;

					if (RX_Primitive = SATA_PRIMITIVE_NONE) then 						-- data
						RX_IsData									<= '1';
						RX_CRC_Valid							<= '1';
						DataUnscrambler_en				<= '1';
						if (RX_FIFO_SpaceAvailable = '1') then
							NextState								<= ST_RX_RECEIVE_DATA;
							-- FIFO overflow is handled later
						end if;
					elsif (RX_Primitive = SATA_PRIMITIVE_EOF) then
						RX_IsEOF 									<= '1';
						NextState 								<= ST_RX_RECEIVED_EOF;
					end if;

					-- All other primitives are handled after InsertAlign is low again.

				else		-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_HOLD;

					if (RX_Primitive = SATA_PRIMITIVE_NONE) then 						-- data
						RX_IsData									<= '1';
						RX_CRC_Valid							<= '1';
						DataUnscrambler_en				<= '1';
						if (RX_FIFO_SpaceAvailable = '1') then
							TX_Primitive						<= SATA_PRIMITIVE_R_IP;
							NextState								<= ST_RX_RECEIVE_DATA;
						elsif (RX_FIFO_Full = '1') then
							-- In case of bit errors, HOLDA / EOF might be missed and thus scrambled
							-- dummy data is put into FIFO. Do a SyncEscape here, because
							-- no FIFO space might get available.
							TX_Primitive 						<= SATA_PRIMITIVE_SYNC;
							RX_FIFO_rollback 				<= '1';
							RX_FSFIFO_put						<= '1';
							NextState 							<= ST_SYNC_ESCAPE;
						end if;
					elsif (RX_Primitive = SATA_PRIMITIVE_HOLD) then
						-- yes, only when FIFO space available!
						if (RX_FIFO_SpaceAvailable = '1') then
							TX_Primitive						<= SATA_PRIMITIVE_HOLD_ACK;
							NextState								<= ST_RX_RECEIVED_HOLD;
						end if;
					elsif (RX_Primitive = SATA_PRIMITIVE_EOF) then
						RX_IsEOF 									<= '1';
						NextState 								<= ST_RX_RECEIVED_EOF;
					elsif (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) then
						-- Extension to SATA specification:
						-- In case of bit errors, the single EOF might be missed. After that
						-- WTRM is received, but no FIFO space gets available.
						TX_Primitive							<= SATA_PRIMITIVE_R_ERROR;
						RX_FIFO_rollback 					<= '1';
						RX_FSFIFO_put							<= '1';
						NextState									<= ST_RX_SEND_R_ERROR;
					elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then
						-- SyncEscape by sender.
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						RX_FIFO_rollback 					<= '1';
						RX_FSFIFO_put							<= '1';
						Trans_RXFS_SyncEsc				<= '1';
						NextState									<= ST_IDLE;
					else
						if (RX_FIFO_SpaceAvailable = '1') then
							TX_Primitive						<= SATA_PRIMITIVE_R_IP;
							NextState								<= ST_RX_RECEIVE_DATA;
						end if;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_RX_RECEIVED_HOLD =>
				Status												<= SATA_LINK_STATUS_RECEIVING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;

					if (RX_Primitive = SATA_PRIMITIVE_NONE) then
						RX_IsData									<= '1';
						RX_CRC_Valid							<= '1';
						DataUnscrambler_en				<= '1';
						NextState									<= ST_RX_RECEIVE_DATA;
					elsif (RX_Primitive = SATA_PRIMITIVE_EOF) then
						RX_IsEOF 									<= '1';
						NextState 								<= ST_RX_RECEIVED_EOF;
					end if;

					-- All other primitives are handled after InsertAlign is low again.

				else		-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_HOLD_ACK;

					if (RX_Primitive = SATA_PRIMITIVE_NONE) then 							-- data
						TX_Primitive							<= SATA_PRIMITIVE_R_IP;
						RX_IsData									<= '1';
						RX_CRC_Valid							<= '1';
						DataUnscrambler_en				<= '1';
						NextState									<= ST_RX_RECEIVE_DATA;
					elsif ((RX_Primitive = SATA_PRIMITIVE_HOLD) or
								 (RX_Primitive = SATA_PRIMITIVE_ALIGN)) then
						null;
					elsif (RX_Primitive = SATA_PRIMITIVE_EOF) then
						RX_IsEOF 									<= '1';
						NextState 								<= ST_RX_RECEIVED_EOF;
					elsif (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) then
						-- Extension to SATA specification:
						-- In case of bit errors, the single EOF might be missed. After that
						-- WTRM is received. signal as CRC error here, instead of going
						-- to ST_RX_RECEIVE_DATA first.
						TX_Primitive							<= SATA_PRIMITIVE_R_ERROR;
						RX_FIFO_rollback 					<= '1';
						RX_FSFIFO_put							<= '1';
						NextState									<= ST_RX_SEND_R_ERROR;
					elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then
						-- SyncEscape by sender.
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						RX_FIFO_rollback 					<= '1';
						RX_FSFIFO_put							<= '1';
						Trans_RXFS_SyncEsc				<= '1';
						NextState									<= ST_IDLE;
					else -- all other primitives
						TX_Primitive						<= SATA_PRIMITIVE_R_IP;
						NextState								<= ST_RX_RECEIVE_DATA;
					end if;
				end if;

				-- ----------------------------------------------------------
				-- Frame Received
				-- ----------------------------------------------------------
			when ST_RX_RECEIVED_EOF =>
				Status												<= SATA_LINK_STATUS_RECEIVING;

				-- Last data word already inserted with EOF. Check error conditions.
				-- RX_FSFIFO_Full is checked before receive begins.
				if ((RX_CRC_OKReg_r = '0') or 			-- caused by bit errors
						(RX_FIFO_Overflow_r = '1') or 	-- send HOLD failed
						(RX_DataReg_Valid2 = '0')) 			-- frame too short
				then
					if (InsertAlign = '1') then
						TX_Primitive 							<= SATA_PRIMITIVE_ALIGN;
					else
						TX_Primitive 							<= SATA_PRIMITIVE_R_ERROR;
					end if;
					RX_FIFO_rollback 						<= '1';
					RX_FSFIFO_put 							<= '1';
					NextState 									<= ST_RX_SEND_R_ERROR;
				else
					if (InsertAlign = '1') then
						TX_Primitive 							<= SATA_PRIMITIVE_ALIGN;
					else
						TX_Primitive 							<= SATA_PRIMITIVE_R_OK;
					end if;
					RX_FIFO_commit 							<= '1';
					RX_FSFIFO_put 							<= '1';
					Trans_RXFS_CRCOK 						<= '1';
					NextState 									<= ST_RX_SEND_R_OK;
				end if;

				-- ----------------------------------------------------------
			when ST_RX_SEND_R_OK =>
				Status												<= SATA_LINK_STATUS_RECEIVING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
					-- All cases are handled after InsertAlign is deasserted

				else	-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_R_OK;

					if (RX_Primitive = SATA_PRIMITIVE_SYNC) then
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						NextState									<= ST_IDLE;
					end if;
				end if;

				-- ----------------------------------------------------------
			when ST_RX_SEND_R_ERROR =>
				Status												<= SATA_LINK_STATUS_RECEIVING;

				if (InsertAlign = '1') then
					TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
					-- All cases are handled after InsertAlign is deasserted

				else	-- InsertAlign
					TX_Primitive								<= SATA_PRIMITIVE_R_ERROR;

					if (RX_Primitive = SATA_PRIMITIVE_SYNC) then
						TX_Primitive							<= SATA_PRIMITIVE_SYNC;
						NextState									<= ST_IDLE;
					end if;
				end if;
		end case;

		-- Override NextState if PHY reports an error
		if (Phy_Status = SATA_PHY_STATUS_ERROR)	then
			NextState												<= ST_NO_COMMUNICATION_ERROR;
		end if;
	end process;

-- ==================================================================
-- Flag registers
-- ==================================================================
	-- register for SOF
	-- -----------------------------
	-- update register if SOF is received, reset if DATA occurs
	-- reset when back in IDLE to allow error processing
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (State = ST_IDLE) then
				RX_SOF_r <= '0';
			elsif (RX_IsSOF = '1') then
				RX_SOF_r		<= '1';
			elsif (RX_IsData = '1') then
				RX_SOF_r		<= '0';
			end if;
		end if;
	end process;

	-- register for CRC_OK
	-- -----------------------------
	-- update register if data is received, reset if EOF occurs
	RX_CRC_OKReg_set	<= RX_IsData	and RX_CRC_OK;
	RX_CRC_OKReg_rst	<= to_sl(RX_Primitive = SATA_PRIMITIVE_SYNC) or (not RX_CRC_OK and RX_IsData);

	RX_CRC_OKReg_r 		<= ffsr(q => RX_CRC_OKReg_r, set => RX_CRC_OKReg_set, rst => RX_CRC_OKReg_rst) when rising_edge(Clock);

	-- register for RX_FIFO overflow
	-- -----------------------------
	-- If other side continous sending data even if we send HOLD, then the
	-- RX_FIFO might overflow.
	-- Reset flag when back in IDLE to allow error processing.
	RX_FIFO_Overflow_r <= ffrs(q => RX_FIFO_Overflow_r, rst => to_sl(State = ST_IDLE), set => RX_FIFO_put_i and RX_FIFO_Full) when rising_edge(Clock);

-- ==================================================================
-- insert align counter
-- ==================================================================
	blkCounters : block
		signal InsertAlign_rst					: std_logic;
		signal InsertAlign_Counter_us		: unsigned(INSERT_ALIGN_COUNTER_BITS - 1 downto 0)		:= (others => '0');

		signal WordCounter_inc					: std_logic;
		signal WordCounter_us						: unsigned(4 downto 0)																:= (others => '0');

		signal RetryCounter_inc					: std_logic;
		signal RetryCounter_us					: unsigned(4 downto 0)																:= (others => '0');

	begin
		InsertAlign_rst							<= InsertAlign when rising_edge(Clock);		-- delay reload by one cycle -> asserts InsertAlign for 2 cycles.
		InsertAlign_Counter_us			<= upcounter_next(cnt => InsertAlign_Counter_us, rst => InsertAlign_rst, en => not InsertAlign) when rising_edge(Clock);
		InsertAlign									<= upcounter_equal(cnt => InsertAlign_Counter_us, value => (INSERT_ALIGN_INTERVAL - 3));

		WordCounter_inc							<= TX_WordCounter_inc and not TX_IsLongFrame;
		WordCounter_us							<= upcounter_next(cnt => WordCounter_us, rst => TX_WordCounter_rst, en => WordCounter_inc) when rising_edge(Clock);
		TX_IsLongFrame							<= upcounter_equal(cnt => WordCounter_us, value => LONG_FRAME_WORDS);

		RetryCounter_inc						<= TX_RetryCounter_inc and not TX_RetryFailed;
		RetryCounter_us							<= upcounter_next(cnt => RetryCounter_us, rst => TX_RetryCounter_rst, en => RetryCounter_inc) when rising_edge(Clock);
		TX_RetryFailed							<= upcounter_equal(cnt => RetryCounter_us, value => SHORT_FRAME_RETRY_COUNT);
	end block;

-- ==================================================================
-- delay for FIFO inputs
-- ==================================================================
	RX_DataReg_shift <= RX_IsData;

	process(Clock)
	begin
		if rising_edge(Clock) then
			-- reset when back in IDLE to allow error processing
			if (State = ST_IDLE) then
				RX_SOFReg_d1 			<= '0';
				RX_SOFReg_d2 			<= '0';
				RX_DataReg_Valid1	<= '0';
				RX_DataReg_Valid2	<= '0';
			elsif (RX_IsData = '1') then
				RX_SOFReg_d1			<= RX_SOF_r;
				RX_SOFReg_d2			<= RX_SOFReg_d1;
				RX_DataReg_Valid1	<= '1';
				RX_DataReg_Valid2	<= RX_DataReg_Valid1;
			end if;
		end if;
	end process;

	RX_FIFO_put_i			<= (RX_IsData or RX_IsEOF) and RX_DataReg_Valid2;
	RX_FIFO_put 			<= RX_FIFO_put_i;

	Trans_RX_SOF			<= RX_SOFReg_d2;
	Trans_RX_EOF			<= RX_IsEOF;

	-- debug port
	-- ===========================================================================
	genNoDebugPort: if not ENABLE_DEBUGPORT generate
		DebugPortOut <= C_SATADBG_LINK_LLFSM_OUT_EMPTY;
	end generate genNoDebugPort;

	genDebugPort : if (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_EncodeState(st : T_STATE) return std_logic_vector is
		begin
			return to_slv(T_STATE'pos(st), log2ceilnz(T_STATE'pos(T_STATE'high) + 1));
		end function;

	begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_GenerateStateEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_STATE loop
					STD.TextIO.write(l, str_replace(T_STATE'image(i), "st_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			function dbg_GeneratePrimitiveEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_PRIMITIVE loop
					STD.TextIO.write(l, str_replace(T_SATA_PRIMITIVE'image(i), "sata_primitive_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			constant dummy : T_BOOLVEC := (
				0 => dbg_ExportEncoding("Link Layer - FSM", 						dbg_GenerateStateEncodings,			PROJECT_DIR & "ChipScope/TokenFiles/FSM_LinkLayer.tok"),
				1 => dbg_ExportEncoding("Link Layer - Primitive Enum",	dbg_GeneratePrimitiveEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Link_Primitive.tok")
			);
		begin
		end generate;

		DebugPortOut.FSM						<= dbg_EncodeState(State);
		DebugPortOut.TX_IsLongFrame <= TX_IsLongFrame;
		DebugPortOut.TX_RetryFailed <= TX_RetryFailed;
	end generate;
end;
