-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Description:
-- ------------------------------------
-- For input 'MyReset' see module 'sata_LinkLayer'.
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
		DEBUG										: BOOLEAN																:= FALSE;
		ENABLE_DEBUGPORT				: BOOLEAN																:= FALSE;
		CONTROLLER_TYPE					: T_SATA_DEVICE_TYPE										:= SATA_DEVICE_TYPE_HOST;
		INSERT_ALIGN_INTERVAL		: POSITIVE															:= 256
	);
	port (
		Clock										: IN	STD_LOGIC;
		MyReset									: IN	STD_LOGIC;

		Status									: OUT	T_SATA_LINK_STATUS;
		Error										: OUT	T_SATA_LINK_ERROR;
			
		-- DebugPort
		DebugPortOut						: out	T_SATADBG_LINK_LLFSM_OUT;

		-- transport layer interface
		Trans_TX_SOF						: IN	STD_LOGIC;
		Trans_TX_EOF						: IN	STD_LOGIC;
		--TODO: Trans_TX_Abort					: IN	STD_LOGIC;

		Trans_TXFS_SendOK				: OUT	STD_LOGIC;
		Trans_TXFS_Abort				: OUT	STD_LOGIC;

		Trans_RX_SOF						: OUT	STD_LOGIC;
		Trans_RX_EOF						: OUT	STD_LOGIC;
		--TODO: Trans_RX_Abort					: IN	STD_LOGIC;
		
		Trans_RXFS_CRCOK				: OUT	STD_LOGIC;
		Trans_RXFS_SyncEsc			: OUT	STD_LOGIC;

		-- physical layer interface
		Phy_Status							: IN	T_SATA_PHY_STATUS;
		
		TX_Primitive						: OUT	T_SATA_PRIMITIVE;
		RX_Primitive						: IN	T_SATA_PRIMITIVE;

		-- TX FIFO interface
		TX_FIFO_rst							: OUT	STD_LOGIC;
		TX_FIFO_Valid						: IN	STD_LOGIC;
		TX_FIFO_got							: OUT	STD_LOGIC;

		-- RX_FSFIFO interface
		TX_FSFIFO_rst						: OUT	STD_LOGIC;
		TX_FSFIFO_put						: OUT	STD_LOGIC;
		TX_FSFIFO_Full					: IN	STD_LOGIC;

		-- RX_FIFO interface
		RX_FIFO_rst							: OUT	STD_LOGIC;
		RX_FIFO_put							: OUT	STD_LOGIC;
		RX_FIFO_commit					: OUT	STD_LOGIC;
		RX_FIFO_rollback				: OUT	STD_LOGIC;
		RX_FIFO_Full						: IN	STD_LOGIC;
		RX_FIFO_SpaceAvailable	: IN	STD_LOGIC;
		
		-- RX FIFO input/hold register interface
		RX_DataReg_shift				: out	STD_LOGIC;

		-- RX_FSFIFO interface
		RX_FSFIFO_rst						: OUT	STD_LOGIC;
		RX_FSFIFO_put						: OUT	STD_LOGIC;
		RX_FSFIFO_Full					: IN	STD_LOGIC;

		-- RX_CRC interface
		RX_CRC_rst							: OUT	STD_LOGIC;
		RX_CRC_Valid						: OUT	STD_LOGIC;
		RX_CRC_OK								: IN	STD_LOGIC;
		
		-- TX_CRC interface
		TX_CRC_rst							: OUT	STD_LOGIC;
		TX_CRC_Valid						: OUT	STD_LOGIC;
		
		-- TX scrambler interface
		DataScrambler_en				: OUT	STD_LOGIC;
		DataScrambler_rst				: OUT	STD_LOGIC;
--		DummyScrambler_en				: OUT	STD_LOGIC;
--		DummyScrambler_rst			: OUT	STD_LOGIC;
		
		-- RX scrambler interface
		DataUnscrambler_en			: OUT	STD_LOGIC;
		DataUnscrambler_rst			: OUT	STD_LOGIC;
		
		-- TX MUX interface
		CRCMux_ctrl							: OUT	STD_LOGIC--;
--		ScramblerMux_ctrl				: OUT	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF sata_LinkLayerFSM IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;
	ATTRIBUTE SYN_ENCODING					: STRING;				-- Altera: FSM_ENCODING
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_RESET,
		ST_NO_COMMUNICATION,
		ST_NO_COMMUNICATION_ERROR,

		-- sending
		ST_TX_SEND_TX_RDY,
		ST_TX_SEND_DATA,
		ST_TX_SEND_HOLD,
		ST_TX_RECEIVED_HOLD,
		ST_TX_SEND_CRC,
		ST_TX_SEND_EOF,
		ST_TX_WAIT,

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
	ATTRIBUTE SYN_ENCODING	OF T_STATE		: TYPE IS "gray";		-- altera state machine encoding
	
	-- LinkLayer - Statemachines
	SIGNAL State										: T_STATE																		:= ST_RESET;
	SIGNAL NextState								: T_STATE;
	
	ATTRIBUTE FSM_ENCODING	OF State			: SIGNAL IS getFSMEncoding_gray(DEBUG);

	CONSTANT INSERT_ALIGN_COUNTER_BITS	: POSITIVE																:= log2ceilnz(INSERT_ALIGN_INTERVAL);

	SIGNAL IAC_inc									: STD_LOGIC;
	SIGNAL IAC_Load									: STD_LOGIC;
	SIGNAL IAC_Finished							: STD_LOGIC;
	SIGNAL IAC_Finished_d						: STD_LOGIC																	:= '0';
	SIGNAL InsertALIGN							: STD_LOGIC;

	SIGNAL RX_IsSOF									: STD_LOGIC;
	SIGNAL RX_IsEOF									: STD_LOGIC;
	SIGNAL RX_IsData								: STD_LOGIC;
	SIGNAL RX_IsData_d							: STD_LOGIC																	:= '0';
	SIGNAL RX_IsData_re							: STD_LOGIC;

	SIGNAL RX_SOF_r									: STD_LOGIC																	:= '0';

	SIGNAL RX_DataReg_Valid1				: STD_LOGIC																	:= '0';
	SIGNAL RX_DataReg_Valid2				: STD_LOGIC																	:= '0';

	signal RX_FIFO_put_i 						: STD_LOGIC;
	signal RX_FIFO_Overflow_r 			: STD_LOGIC 																:= '0';
	
	SIGNAL RX_SOFReg_d1							: STD_LOGIC																	:= '0';
	SIGNAL RX_SOFReg_d2							: STD_LOGIC																	:= '0';
	
	SIGNAL RX_CRC_OKReg_set					: STD_LOGIC;
	SIGNAL RX_CRC_OKReg_rst					: STD_LOGIC;
	SIGNAL RX_CRC_OKReg_r						: STD_LOGIC																	:= '0';
	
BEGIN

-- ==================================================================
-- LinkLayer - Status
--
-- TODO: Wishlist
--   Replace Frame-State FIFO by Status/Error reporting.
-- ==================================================================
	Error		<= SATA_LINK_ERROR_NONE;
	
-- ==================================================================
-- LinkLayer - Statemachine
-- ==================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			if MyReset = '1' then
				State 	<= ST_RESET;
			else
				State 	<= NextState;
			end if;
		END IF;
	END PROCESS;


	PROCESS(State, Phy_Status, RX_Primitive, Trans_TX_SOF, Trans_TX_EOF, TX_FIFO_Valid,
					RX_FIFO_Overflow_r, RX_FIFO_SpaceAvailable, RX_FSFIFO_Full,
					RX_DataReg_Valid2, RX_CRC_OKReg_r, InsertALIGN)
	BEGIN
		NextState											<= State;
		Status 												<= SATA_LINK_STATUS_IDLE;
		
		-- primitive interface
		TX_Primitive									<= SATA_PRIMITIVE_NONE;

		-- TX FIFO interface
		TX_FIFO_rst										<= '0';
		TX_FIFO_got										<= '0';
		TX_FSFIFO_rst									<= '0';
		TX_FSFIFO_put									<= '0';
		
		Trans_TXFS_SendOK							<= '0';
		Trans_TXFS_Abort							<= '0';
		
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
		
		-- handle PhyNotReady with highest priority
		if ((Phy_Status /= SATA_PHY_STATUS_COMMUNICATING) and not
				((State = ST_RESET) or
				 (State = ST_NO_COMMUNICATION) or
				 (State = ST_NO_COMMUNICATION_ERROR)
					)) then
			TX_Primitive											<= SATA_PRIMITIVE_ALIGN;
			
			NextState													<= ST_NO_COMMUNICATION_ERROR;
		else
			case State is
				-- ----------------------------------------------------------
				when ST_RESET =>
					Status												<= SATA_LINK_STATUS_COMMUNICATION_ERROR;
					TX_Primitive									<= SATA_PRIMITIVE_ALIGN;
					TX_FIFO_rst										<= '1';
					TX_FSFIFO_rst									<= '1';
					RX_FIFO_rst										<= '1';
					RX_FSFIFO_rst									<= '1';
					NextState											<= ST_NO_COMMUNICATION;
			
				-- ----------------------------------------------------------
				when ST_NO_COMMUNICATION =>
					Status												<= SATA_LINK_STATUS_COMMUNICATION_ERROR;
					TX_Primitive									<= SATA_PRIMITIVE_ALIGN;
					
					IF (Phy_Status = SATA_PHY_STATUS_COMMUNICATING) THEN
						NextState										<= ST_IDLE;
					END IF;

				-- ----------------------------------------------------------
				when ST_NO_COMMUNICATION_ERROR =>
					Status												<= SATA_LINK_STATUS_COMMUNICATION_ERROR;
					TX_Primitive									<= SATA_PRIMITIVE_ALIGN;
					NextState											<= ST_NO_COMMUNICATION;
				
				-- ----------------------------------------------------------
				when ST_IDLE =>
					Status 												<= SATA_LINK_STATUS_IDLE;
					
					IF (InsertALIGN = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						
						-- All cases are handled after InsertAlign is '0' again.

					ELSE	-- InsertALIGN
						TX_Primitive								<= SATA_PRIMITIVE_SYNC;
					
						if (RX_Primitive = SATA_PRIMITIVE_TX_RDY) then								-- transmission attempt received
							IF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) THEN						-- 
								IF (RX_FIFO_SpaceAvailable = '1') and (RX_FSFIFO_Full = '0') THEN		-- RX FIFOs have space => send RX_RDY
									TX_Primitive					<= SATA_PRIMITIVE_RX_RDY;
									NextState							<= ST_RX_SEND_RX_RDY;
								ELSE																											-- RX FIFO has no space => wait for space
									TX_Primitive					<= SATA_PRIMITIVE_SYNC;
									NextState							<= ST_RX_WAIT_FIFO;
								END IF;
							ELSIF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) THEN			--
								IF ((Trans_TX_SOF = '1') AND (TX_FIFO_Valid = '1')) THEN	-- start own transmission attempt?
									TX_Primitive					<= SATA_PRIMITIVE_TX_RDY;
									NextState							<= ST_TX_SEND_TX_RDY;
								ELSE
									IF (RX_FIFO_SpaceAvailable = '1') and (RX_FSFIFO_Full = '0') THEN	-- RX FIFOs have space => send RX_RDY
										TX_Primitive				<= SATA_PRIMITIVE_RX_RDY;
										NextState						<= ST_RX_SEND_RX_RDY;
									ELSE																										-- RX FIFO has no space => wait for space
										TX_Primitive				<= SATA_PRIMITIVE_SYNC;
										NextState						<= ST_RX_WAIT_FIFO;
									END IF;
								END IF;
							END IF;
						else
							IF ((Trans_TX_SOF = '1') AND (TX_FIFO_Valid = '1')) THEN
								TX_Primitive						<= SATA_PRIMITIVE_TX_RDY;
								NextState								<= ST_TX_SEND_TX_RDY;
							END IF;
						END IF;
					END IF;


				-- ----------------------------------------------------------
				-- sending
				-- ----------------------------------------------------------
				when ST_TX_SEND_TX_RDY =>
					Status												<= SATA_LINK_STATUS_SENDING;
						
					IF (InsertALIGN = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						
						IF (RX_Primitive = SATA_PRIMITIVE_RX_RDY) THEN										-- other side is ready to receive
							NULL; -- just send align, transistion after InsertAlign = '0'
						ELSIF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN									-- transmission attempt from other side
							IF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) THEN								-- => abort own transmission attempt
								IF (RX_FIFO_SpaceAvailable = '1') THEN												-- RX FIFO has space => send RX_RDY
									NextState							<= ST_RX_SEND_RX_RDY;
								ELSE																													-- RX FIFO has no space => wait for space
									NextState							<= ST_RX_WAIT_FIFO;
								END IF;
							ELSIF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) THEN					-- => ignore transmission attempt
								NULL;
							END IF;
						END IF;

					ELSE		-- InsertALIGN
						TX_Primitive								<= SATA_PRIMITIVE_TX_RDY;
						
						IF (RX_Primitive = SATA_PRIMITIVE_RX_RDY) THEN										-- other side is ready to receive
							TX_Primitive							<= SATA_PRIMITIVE_SOF;
							TX_CRC_rst								<= '1';
							DataScrambler_rst					<= '1';
--							DummyScrambler_rst				<= '1';
							NextState						<= ST_TX_SEND_DATA;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN									-- transmission attempt from other side
							IF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) THEN								-- => abort own transmission attempt
								IF (RX_FIFO_SpaceAvailable = '1') THEN												-- RX FIFO has space => send RX_RDY
									TX_Primitive						<= SATA_PRIMITIVE_RX_RDY;
									NextState								<= ST_RX_SEND_RX_RDY;
								ELSE																													-- RX FIFO has no space => wait for space
									TX_Primitive						<= SATA_PRIMITIVE_SYNC;
									NextState								<= ST_RX_WAIT_FIFO;
								END IF;
							ELSIF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) THEN					-- => ignore transmission attempt
								NULL;
							END IF;
						END IF;
					END IF;
					
				-- ----------------------------------------------------------
				when ST_TX_SEND_DATA =>
					Status												<= SATA_LINK_STATUS_SENDING;
						
					IF (InsertALIGN = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						
						if (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) then
							NextState									<= ST_TX_SEND_CRC;
						end if;

						-- Receiving HOLD and SYNC is handled after InsertAlign is low again.

					ELSE	-- InsertALIGN
						IF (TX_FIFO_Valid = '1') THEN																	-- valid data in TX_FIFO
							TX_Primitive							<= SATA_PRIMITIVE_NONE;
							TX_FIFO_got								<= '1';
							TX_CRC_Valid							<= '1';
							DataScrambler_en					<= '1';
						
							IF (Trans_TX_EOF = '1') THEN																-- last payload word in Frame
								if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 							-- abort
									TX_Primitive					<= SATA_PRIMITIVE_SYNC;
									TX_FSFIFO_put 				<= '1';
									NextState 						<= ST_IDLE;
								else 																											-- send CRC
									NextState							<= ST_TX_SEND_CRC;
								end if;
							ELSE																												-- normal payload word
								IF (RX_Primitive = SATA_PRIMITIVE_HOLD) THEN							-- hold on sending
									TX_Primitive					<= SATA_PRIMITIVE_HOLD_ACK;
									TX_FIFO_got						<= '0';
									TX_CRC_Valid					<= '0';
									DataScrambler_en			<= '0';
									NextState							<= ST_TX_RECEIVED_HOLD;
								ELSIF (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) THEN				-- insert CRC32	after this data word
									NextState							<= ST_TX_SEND_CRC;
								elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then 					-- abort
									TX_Primitive					<= SATA_PRIMITIVE_SYNC;
									TX_FSFIFO_put 				<= '1';
									NextState 						<= ST_IDLE;
								END IF;
							END IF;
						ELSE																													-- empty TX_FIFO => insert HOLD
							if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 								-- abort
								TX_Primitive						<= SATA_PRIMITIVE_SYNC;
								TX_FSFIFO_put 					<= '1';
								NextState 							<= ST_IDLE;
							else
								TX_Primitive						<= SATA_PRIMITIVE_HOLD;
								NextState								<= ST_TX_SEND_HOLD;
							end if;
						END IF;
					END IF;
					
				-- ----------------------------------------------------------
				WHEN ST_TX_SEND_HOLD =>
					Status												<= SATA_LINK_STATUS_SENDING;
						
					IF (InsertAlign = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						
						if (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) then
							NextState									<= ST_TX_SEND_CRC;
						end if;

						-- Receiving HOLD and SYNC is handled after InsertAlign is low again.

					ELSE	-- InsertAlign
						IF (TX_FIFO_Valid = '1') THEN
							TX_Primitive							<= SATA_PRIMITIVE_NONE;
							TX_FIFO_got								<= '1';
							TX_CRC_Valid							<= '1';
							DataScrambler_en					<= '1';
						
							IF (Trans_TX_EOF = '1') THEN																-- last payload word in frame
								if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 							-- abort
									TX_Primitive					<= SATA_PRIMITIVE_SYNC;
									TX_FSFIFO_put 				<= '1';
									NextState 						<= ST_IDLE;
								else
									NextState							<= ST_TX_SEND_CRC;
								END IF;
							ELSE 																												-- normal payload word
								if (RX_Primitive = SATA_PRIMITIVE_HOLD) then
									TX_Primitive					<= SATA_PRIMITIVE_HOLD_ACK;
                  TX_FIFO_got						<= '0';
                  TX_CRC_Valid					<= '0';
                  DataScrambler_en			<= '0';
									NextState							<= ST_TX_RECEIVED_HOLD;
								ELSIF (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) THEN				-- insert CRC32	after this data word
									NextState							<= ST_TX_SEND_CRC;
								elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then 					-- abort
									TX_Primitive					<= SATA_PRIMITIVE_SYNC;
									TX_FSFIFO_put 				<= '1';
									NextState 						<= ST_IDLE;
								END IF;
							END IF;
						ELSE																													-- empty FIFO => insert HOLD
							if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 								-- abort
								TX_Primitive						<= SATA_PRIMITIVE_SYNC;
								TX_FSFIFO_put 					<= '1';
								NextState 							<= ST_IDLE;
							elsif (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) then				-- insert CRC32	after HOLD
								TX_Primitive						<= SATA_PRIMITIVE_HOLD;
								NextState								<= ST_TX_SEND_CRC;
							else
								TX_Primitive						<= SATA_PRIMITIVE_HOLD;
							end if;
						END IF;
					END IF;
				
				-- ----------------------------------------------------------
				WHEN ST_TX_RECEIVED_HOLD =>
					-- assert(TX_Fifo_Valid = '1')
					Status												<= SATA_LINK_STATUS_SENDING;
						
					IF (InsertAlign = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						
						if (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) then
							NextState									<= ST_TX_SEND_CRC;
						end if;

						-- Receiving HOLD and SYNC is handled after InsertAlign is low again.
					
					ELSE	-- InsertAlign
						TX_Primitive								<= SATA_PRIMITIVE_HOLD_ACK;
					
						if ((RX_Primitive = SATA_PRIMITIVE_HOLD) or
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))	then
							NULL;
						elsif (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) then						-- insert CRC32	after HOLDA
							NextState									<= ST_TX_SEND_CRC;
						elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then 							-- abort
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							TX_FSFIFO_put 						<= '1';
							NextState 								<= ST_IDLE;
						else 																													-- resume sending data
							TX_Primitive							<= SATA_PRIMITIVE_NONE;
							TX_FIFO_got								<= '1';
							TX_CRC_Valid							<= '1';
							DataScrambler_en					<= '1';
							IF (Trans_TX_EOF = '1') THEN																-- last payload word in frame
								NextState								<= ST_TX_SEND_CRC;
							ELSE
								NextState								<= ST_TX_SEND_DATA;
							END IF;
						end if;
					END IF;
				
				-- ----------------------------------------------------------
				WHEN ST_TX_SEND_CRC =>
					Status												<= SATA_LINK_STATUS_SENDING;
						
					IF (InsertAlign = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						-- Receiving SYNC is handled after InsertAlign is low again.

					ELSE
						if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 									-- abort
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							TX_FSFIFO_put 						<= '1';
							NextState 								<= ST_IDLE;
						else
							TX_Primitive							<= SATA_PRIMITIVE_NONE;
							CRCMux_ctrl								<= '1';
							DataScrambler_en					<= '1';
							NextState									<= ST_TX_SEND_EOF;
						end if;
					END IF;
				
				-- ----------------------------------------------------------
				WHEN ST_TX_SEND_EOF =>
					Status												<= SATA_LINK_STATUS_SENDING;
						
					IF (InsertAlign = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						-- Receiving SYNC is handled after InsertAlign is low again.

					ELSE
						if (RX_Primitive = SATA_PRIMITIVE_SYNC) then 									-- abort
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							TX_FSFIFO_put 						<= '1';
							NextState 								<= ST_IDLE;
						else
							TX_Primitive							<= SATA_PRIMITIVE_EOF;
							NextState									<= ST_TX_WAIT;
						end if;
					END IF;

				-- ----------------------------------------------------------
				WHEN ST_TX_WAIT =>
					Status												<= SATA_LINK_STATUS_SENDING;
						
					IF (InsertAlign = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						-- Handle primitives after InsertAlign is low again.

					ELSE	-- InsertAlign
						TX_Primitive								<= SATA_PRIMITIVE_WAIT_TERM;
					
						IF (RX_Primitive = SATA_PRIMITIVE_R_OK) THEN
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							TX_FSFIFO_put							<= '1';
							Trans_TXFS_SendOK					<= '1';
							NextState									<= ST_IDLE;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_R_ERROR) THEN
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							TX_FSFIFO_put							<= '1';
							Trans_TXFS_Abort					<= '1';
							NextState									<= ST_IDLE;
						elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then 							-- abort
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							TX_FSFIFO_put 						<= '1';
							NextState 								<= ST_IDLE;
						END IF;
					END IF;

				-- ----------------------------------------------------------
				-- receiving
				-- ----------------------------------------------------------
				WHEN ST_RX_WAIT_FIFO =>
					Status												<= SATA_LINK_STATUS_RECEIVING;
						
					IF (InsertALIGN = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						-- All cases are handled after InsertAlign is deasserted.
						
					ELSE		-- InsertALIGN
						TX_Primitive								<= SATA_PRIMITIVE_SYNC;
						
						IF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN
							IF (RX_FIFO_SpaceAvailable = '1') and (RX_FSFIFO_Full = '0') THEN
								TX_Primitive						<= SATA_PRIMITIVE_RX_RDY;
								NextState								<= ST_RX_SEND_RX_RDY;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_ALIGN) THEN
							NULL;
						else 	-- may be caused by bit errors
							-- no frame started yet
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							NextState									<= ST_IDLE;
						END IF;				
					END IF;
					
				-- ----------------------------------------------------------
				WHEN ST_RX_SEND_RX_RDY =>
					-- assert(RX_FIFO_SpaceAvailable = '1')
					Status												<= SATA_LINK_STATUS_RECEIVING;
						
					IF (InsertALIGN = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						
						IF (RX_Primitive = SATA_PRIMITIVE_SOF) THEN
							RX_IsSOF 									<= '1';
							RX_CRC_rst								<= '1';
							DataUnscrambler_rst				<= '1';
							NextState									<= ST_RX_RECEIVE_DATA;
						END IF;
						-- All other cases are handled after InsertAlign is deasserted.

					ELSE		-- InsertALIGN
						TX_Primitive								<= SATA_PRIMITIVE_RX_RDY;
						
						IF ((RX_Primitive = SATA_PRIMITIVE_TX_RDY) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_SOF) THEN
							TX_Primitive							<= SATA_PRIMITIVE_R_IP;
							RX_IsSOF 									<= '1';
							RX_CRC_rst								<= '1';
							DataUnscrambler_rst				<= '1';
							NextState									<= ST_RX_RECEIVE_DATA;
						else  																												-- abort
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							NextState									<= ST_IDLE;
						END IF;
					END IF;
				
				-- ----------------------------------------------------------
				WHEN ST_RX_RECEIVE_DATA =>
					Status												<= SATA_LINK_STATUS_RECEIVING;
						
					IF (InsertALIGN = '1') THEN
						TX_Primitive 								<= SATA_PRIMITIVE_ALIGN;
						
						if (RX_Primitive = SATA_PRIMITIVE_NONE) then 						-- data
							RX_IsData									<= '1';
							RX_CRC_Valid							<= '1';
							DataUnscrambler_en				<= '1';
							IF (RX_FIFO_SpaceAvailable = '0') THEN
								NextState								<= ST_RX_SEND_HOLD;
							END IF;
						elsif (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) then
							null; -- stay here even Transport Layer requests abort in the future
						elsif (RX_Primitive = SATA_PRIMITIVE_HOLD) then
							NextState									<= ST_RX_RECEIVED_HOLD;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_EOF) THEN
							RX_IsEOF 									<= '1';
							NextState 								<= ST_RX_RECEIVED_EOF;
						end if;
						
						-- WTRM and SYNC are handled after InsertAlign is low again.

					ELSE		-- InsertALIGN
						TX_Primitive								<= SATA_PRIMITIVE_R_IP;
						
						if (RX_Primitive = SATA_PRIMITIVE_NONE) then 						-- data
							RX_IsData										<= '1';
							RX_CRC_Valid								<= '1';
							DataUnscrambler_en					<= '1';
							IF (RX_FIFO_SpaceAvailable = '0') THEN
								TX_Primitive						<= SATA_PRIMITIVE_HOLD;
								NextState								<= ST_RX_SEND_HOLD;
							END IF;
						elsif (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) then
							null; -- stay here even Transport Layer requests abort in the future
						elsif (RX_Primitive = SATA_PRIMITIVE_HOLD) then
							TX_Primitive							<= SATA_PRIMITIVE_HOLD_ACK;
							NextState									<= ST_RX_RECEIVED_HOLD;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_EOF) THEN
							RX_IsEOF 									<= '1';
							NextState 								<= ST_RX_RECEIVED_EOF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) THEN
							-- In case of bit errors, the single EOF might be missed. After that
							-- WTRM is received. Signal as CRC error.
							TX_Primitive							<= SATA_PRIMITIVE_R_ERROR;
							RX_FIFO_rollback 					<= '1';
							RX_FSFIFO_put							<= '1';
							NextState									<= ST_RX_SEND_R_ERROR;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN
							-- SyncEscape by sender.
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							RX_FIFO_rollback 					<= '1';
							RX_FSFIFO_put							<= '1';
							Trans_RXFS_SyncEsc				<= '1';
							NextState									<= ST_IDLE;
						END IF;
					END IF;
				
				-- ----------------------------------------------------------
				WHEN ST_RX_SEND_HOLD =>
					Status												<= SATA_LINK_STATUS_RECEIVING;
						
					IF (InsertALIGN = '1') THEN
						TX_Primitive 								<= SATA_PRIMITIVE_ALIGN;
						
						if (RX_Primitive = SATA_PRIMITIVE_NONE) then 						-- data
							RX_IsData									<= '1';
							RX_CRC_Valid							<= '1';
							DataUnscrambler_en				<= '1';
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								NextState								<= ST_RX_RECEIVE_DATA;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_EOF) THEN
							RX_IsEOF 									<= '1';
							NextState 								<= ST_RX_RECEIVED_EOF;
						END IF;

						-- All other primitives are handled after InsertAlign is low again.

					ELSE		-- InsertALIGN
						TX_Primitive								<= SATA_PRIMITIVE_HOLD;
						
						if (RX_Primitive = SATA_PRIMITIVE_NONE) then 						-- data
							RX_IsData									<= '1';
							RX_CRC_Valid							<= '1';
							DataUnscrambler_en				<= '1';
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								TX_Primitive						<= SATA_PRIMITIVE_R_IP;
								NextState								<= ST_RX_RECEIVE_DATA;
							END IF;
						elsif (RX_Primitive = SATA_PRIMITIVE_HOLD) then
							-- yes, only when FIFO space available!
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								TX_Primitive						<= SATA_PRIMITIVE_HOLD_ACK;
								NextState								<= ST_RX_RECEIVED_HOLD;
							END IF;
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
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								TX_Primitive						<= SATA_PRIMITIVE_R_IP;
								NextState								<= ST_RX_RECEIVE_DATA;
							END IF;
						END IF;
					END IF;
				
				-- ----------------------------------------------------------
				WHEN ST_RX_RECEIVED_HOLD =>
					Status												<= SATA_LINK_STATUS_RECEIVING;
						
					IF (InsertALIGN = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
					
						IF (RX_Primitive = SATA_PRIMITIVE_NONE) THEN
							RX_IsData									<= '1';
							RX_CRC_Valid							<= '1';
							DataUnscrambler_en				<= '1';
							NextState									<= ST_RX_RECEIVE_DATA;
						elsif (RX_Primitive = SATA_PRIMITIVE_EOF) then
							RX_IsEOF 									<= '1';
							NextState 								<= ST_RX_RECEIVED_EOF;
						END IF;
						
						-- All other primitives are handled after InsertAlign is low again.

					ELSE		-- InsertALIGN
						TX_Primitive								<= SATA_PRIMITIVE_HOLD_ACK;
						
						IF (RX_Primitive = SATA_PRIMITIVE_NONE) then 							-- data
							TX_Primitive							<= SATA_PRIMITIVE_R_IP;
							RX_IsData									<= '1';
							RX_CRC_Valid							<= '1';
							DataUnscrambler_en				<= '1';
							NextState									<= ST_RX_RECEIVE_DATA;
						elsif ((RX_Primitive = SATA_PRIMITIVE_HOLD) or
									 (RX_Primitive = SATA_PRIMITIVE_ALIGN)) then
							NULL;
						elsif (RX_Primitive = SATA_PRIMITIVE_EOF) then
							RX_IsEOF 									<= '1';
							NextState 								<= ST_RX_RECEIVED_EOF;
						elsif (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) then
							-- Extension to SATA specification:
							-- In case of bit errors, the single EOF might be missed. After that
							-- WTRM is received. Signal as CRC error here, instead of going
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
					END IF;
				
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
				WHEN ST_RX_SEND_R_OK =>
					Status												<= SATA_LINK_STATUS_RECEIVING;
						
					IF (InsertALIGN = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						-- All cases are handled after InsertAlign is deasserted

					ELSE	-- InsertAlign
						TX_Primitive								<= SATA_PRIMITIVE_R_OK;
						
						if (RX_Primitive = SATA_PRIMITIVE_SYNC) then
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							NextState									<= ST_IDLE;
						end if;
					END IF;

				-- ----------------------------------------------------------
				WHEN ST_RX_SEND_R_ERROR =>
					Status												<= SATA_LINK_STATUS_RECEIVING;
						
					IF (InsertALIGN = '1') THEN
						TX_Primitive								<= SATA_PRIMITIVE_ALIGN;
						-- All cases are handled after InsertAlign is deasserted

					ELSE	-- InsertAlign
						TX_Primitive								<= SATA_PRIMITIVE_R_ERROR;
						
						if (RX_Primitive = SATA_PRIMITIVE_SYNC) then
							TX_Primitive							<= SATA_PRIMITIVE_SYNC;
							NextState									<= ST_IDLE;
						end if;
					END IF;
			END CASE;
		END IF;
	END PROCESS;

-- ==================================================================
-- Flag registers
-- ==================================================================
	-- register for SOF
	-- -----------------------------
	-- update register if SOF is received, reset if DATA occurs
	-- reset when back in IDLE to allow error processing
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			if (State = ST_IDLE) then
				RX_SOF_r <= '0';
			elsif (RX_IsSOF = '1') THEN
				RX_SOF_r		<= '1';
			ELSIF (RX_IsData = '1') THEN
				RX_SOF_r		<= '0';
			END IF;
		END IF;
	END PROCESS;

	-- register for CRC_OK
	-- -----------------------------
	-- update register if data is received, reset if EOF occurs
	RX_CRC_OKReg_set	<= RX_IsData	AND RX_CRC_OK;
	RX_CRC_OKReg_rst	<= to_sl(RX_Primitive = SATA_PRIMITIVE_SYNC) OR (NOT RX_CRC_OK AND RX_IsData);

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
	IAC_inc							<= '1' AND NOT IAC_Finished;
	IAC_Load						<= IAC_Finished_d;
	
	IAC : BLOCK
		SIGNAL Counter_us				: UNSIGNED(INSERT_ALIGN_COUNTER_BITS - 1 DOWNTO 0)					:= (OTHERS => '0');
	BEGIN
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (IAC_Load = '1') THEN
					Counter_us				<= to_unsigned(0, INSERT_ALIGN_COUNTER_BITS);
				ELSE
					IF (IAC_inc = '1') THEN
						Counter_us			<= Counter_us + 1;
					END IF;
				END IF;
			END IF;
		END PROCESS;

		IAC_Finished	<= to_sl(Counter_us = to_unsigned(INSERT_ALIGN_INTERVAL - 3,	INSERT_ALIGN_COUNTER_BITS));
	END BLOCK;
	
	IAC_Finished_d	<= IAC_Finished WHEN rising_edge(Clock);
	InsertALIGN			<= IAC_Finished; -- OR IAC_Finished_d;

-- ==================================================================
-- delay for FIFO inputs
-- ==================================================================
	RX_DataReg_shift <= RX_IsData;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
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
			END IF;
		END IF;
	END PROCESS;
	
	RX_FIFO_put_i			<= (RX_IsData OR RX_IsEOF) AND RX_DataReg_Valid2;
	RX_FIFO_put 			<= RX_FIFO_put_i;
	
	Trans_RX_SOF			<= RX_SOFReg_d2;
	Trans_RX_EOF			<= RX_IsEOF;

	-- debug port
	-- ===========================================================================
	genDebugPort : if (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_EncodeState(st : T_STATE) return STD_LOGIC_VECTOR is
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
		
		DebugPortOut.FSM					<= dbg_EncodeState(State);
	end generate;
end;
