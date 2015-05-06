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
--		TODO
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


entity sata_LinkLayerFSM is
	generic (
		DEBUG										: BOOLEAN																:= FALSE;
		ENABLE_DEBUGPORT				: BOOLEAN																:= FALSE;
		CONTROLLER_TYPE					: T_SATA_DEVICE_TYPE										:= SATA_DEVICE_TYPE_HOST;
		INSERT_ALIGN_INTERVAL		: POSITIVE															:= 256
	);
	port (
		Clock										: IN	STD_LOGIC;
		ClockEnable							: IN	STD_LOGIC;
		Reset										: IN	STD_LOGIC;

		Status									: OUT	T_SATA_LINK_STATUS;
		Error										: OUT	T_SATA_LINK_ERROR;
			-- normal vs. dma modus
			-- bad transition ??
			
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
		Trans_RXFS_Abort				: OUT	STD_LOGIC;

		-- physical layer interface
		Phy_ResetDone						: IN	STD_LOGIC;
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
		RX_FIFO_Full						: IN	STD_LOGIC;
		RX_FIFO_SpaceAvailable	: IN	STD_LOGIC;
		
		-- RX FIFO input/hold register interface
		RX_DataReg_en1					: OUT	STD_LOGIC;
		RX_DataReg_en2					: OUT	STD_LOGIC;

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
	
	TYPE T_TXFSM_STATE IS (
		ST_TXFSM_IDLE,
		ST_TXFSM_RESET,
		ST_TXFSM_NO_COMMUNICATION,
		ST_TXFSM_NO_COMMUNICATION_ERROR,
		
		ST_TXFSM_RECEIVING,
		
		ST_TXFSM_SEND_TX_RDY,
		ST_TXFSM_SEND_DATA,
		ST_TXFSM_SEND_HOLD,
		ST_TXFSM_RECEIVED_HOLD,
		ST_TXFSM_SEND_CRC,
		ST_TXFSM_SEND_EOF,
		ST_TXFSM_WAIT,

		ST_TXFSM_FSM_ERROR
	);
	
	TYPE T_RXFSM_STATE IS (
		ST_RXFSM_IDLE,
		ST_RXFSM_RESET,
		ST_RXFSM_NO_COMMUNICATION,
		ST_RXFSM_NO_COMMUNICATION_ERROR,

		ST_RXFSM_SENDING,
		ST_RXFSM_SENDING2,

		ST_RXFSM_WAIT_FIFO,
		ST_RXFSM_SEND_RX_RDY,
		ST_RXFSM_RECEIVE_DATA,
		ST_RXFSM_SEND_HOLD,
		ST_RXFSM_RECEIVED_HOLD_ACK,
		ST_RXFSM_RECEIVED_HOLD,
		ST_RXFSM_SEND_R_OK,
		ST_RXFSM_SEND_R_ERROR,
		ST_RXFSM_RXFIFO_FULL,
		ST_RXFSM_SEND_DMA_TERM,

		ST_RXFSM_FSM_ERROR
	);
	ATTRIBUTE SYN_ENCODING	OF T_TXFSM_STATE		: TYPE IS "gray";		-- altera state machine encoding
	ATTRIBUTE SYN_ENCODING	OF T_RXFSM_STATE		: TYPE IS "gray";		-- altera state machine encoding
	
	-- LinkLayer - Statemachines
	SIGNAL TXFSM_State					: T_TXFSM_STATE																		:= ST_TXFSM_RESET;
	SIGNAL TXFSM_NextState			: T_TXFSM_STATE;
	
	SIGNAL RXFSM_State					: T_RXFSM_STATE																		:= ST_RXFSM_RESET;
	SIGNAL RXFSM_NextState			: T_RXFSM_STATE;
	
	ATTRIBUTE FSM_ENCODING	OF TXFSM_State		: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	ATTRIBUTE FSM_ENCODING	OF RXFSM_State		: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));


	CONSTANT INSERT_ALIGN_COUNTER_BITS	: POSITIVE																:= log2ceilnz(INSERT_ALIGN_INTERVAL);

	SIGNAL IAC_inc									: STD_LOGIC;
	SIGNAL IAC_Load									: STD_LOGIC;
	SIGNAL IAC_Finished							: STD_LOGIC;
	SIGNAL IAC_Finished_d						: STD_LOGIC																	:= '0';
	SIGNAL InsertALIGN							: STD_LOGIC;

	SIGNAL TXFSM_IDLE								: STD_LOGIC;
	SIGNAL TXFSM_Error							: STD_LOGIC;
	SIGNAL TXFSM_Sending						: STD_LOGIC;
	SIGNAL TXFSM_Primitive					: T_SATA_PRIMITIVE;
	
	SIGNAL RXFSM_IDLE								: STD_LOGIC;
	SIGNAL RXFSM_Error							: STD_LOGIC;
	SIGNAL RXFSM_Receiving					: STD_LOGIC;
	SIGNAL RXFSM_Primitive					: T_SATA_PRIMITIVE;

	SIGNAL RXFSM_IsSOF							: STD_LOGIC;
	SIGNAL RXFSM_IsEOF							: STD_LOGIC;
	SIGNAL RXFSM_IsData							: STD_LOGIC;
	SIGNAL RXFSM_IsData_d						: STD_LOGIC																	:= '0';
	SIGNAL RXFSM_IsData_re					: STD_LOGIC;

	SIGNAL RX_SOF_r									: STD_LOGIC																	:= '0';

	SIGNAL RX_DataReg_en1_i					: STD_LOGIC;
	SIGNAL RX_DataReg_en1_d					: STD_LOGIC																	:= '0';
	SIGNAL RX_DataReg_Valid1				: STD_LOGIC																	:= '0';
	
	SIGNAL RX_DataReg_en2_i					: STD_LOGIC;
	SIGNAL RX_DataReg_en2_d					: STD_LOGIC																	:= '0';
	SIGNAL RX_DataReg_Valid2				: STD_LOGIC																	:= '0';

	SIGNAL RX_SOFReg_d1							: STD_LOGIC																	:= '0';
	SIGNAL RX_SOFReg_d2							: STD_LOGIC																	:= '0';
	
	SIGNAL RX_CRC_OKReg_set					: STD_LOGIC;
	SIGNAL RX_CRC_OKReg_rst					: STD_LOGIC;
	SIGNAL RX_CRC_OKReg_r						: STD_LOGIC																	:= '0';
	
BEGIN

-- ==================================================================
-- LinkLayer - Status
-- ==================================================================
	Error	<= SATA_LINK_ERROR_LINK_RXFIFO_FULL WHEN RX_FIFO_Full = '1' ELSE SATA_LINK_ERROR_NONE;

	PROCESS(Phy_Status, TXFSM_Error, RXFSM_Error, TXFSM_IDLE, RXFSM_IDLE, TXFSM_Sending, RXFSM_Receiving)
	BEGIN
		Status			<= SATA_LINK_STATUS_COMMUNICATION_ERROR;
		-- TODO:
		-- evaluate FIFO fill grades
		-- 	=> receive error
		
		IF (Phy_Status /= SATA_PHY_STATUS_LINK_OK) THEN
			Status			<= SATA_LINK_STATUS_COMMUNICATION_ERROR;
		ELSIF ((TXFSM_Error				OR	RXFSM_Error)			= '1') THEN				-- error
			Status			<= SATA_LINK_STATUS_ERROR;
		ELSIF ((TXFSM_IDLE				AND RXFSM_IDLE)				= '1')	THEN			-- idle
			Status			<= SATA_LINK_STATUS_IDLE;
		ELSIF ((TXFSM_Sending 		AND RXFSM_IDLE)				= '1') THEN				-- sending
			Status			<= SATA_LINK_STATUS_SENDING;
		ELSIF ((TXFSM_IDLE				AND RXFSM_Receiving)	= '1') THEN				-- receiving
			Status			<= SATA_LINK_STATUS_RECEIVING;
		ELSE
			Status			<= SATA_LINK_STATUS_ERROR;
		END IF;
	END PROCESS;

-- ==================================================================
-- LinkLayer - TX Statemachine
-- ==================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			if Phy_ResetDone = '0' then
				TXFSM_State 		<= ST_TXFSM_RESET;
			elsif ClockEnable = '1' then
				if Reset = '1' then
					TXFSM_State 	<= ST_TXFSM_RESET;
				else
					TXFSM_State 	<= TXFSM_NextState;
				end if;
			end if;
		END IF;
	END PROCESS;


	PROCESS(TXFSM_State, Phy_Status, RX_Primitive, Trans_TX_SOF, Trans_TX_EOF, TX_FIFO_Valid, InsertALIGN)
	BEGIN
		TXFSM_NextState								<= TXFSM_State;

		-- internal state signals
		TXFSM_IDLE										<= '0';
		TXFSM_Error										<= '0';
		TXFSM_Sending									<= '0';

		-- primitive interface
		TXFSM_Primitive								<= SATA_PRIMITIVE_NONE;

		-- FIFO interface
		TX_FIFO_rst										<= '0';
		TX_FIFO_got										<= '0';
		TX_FSFIFO_rst									<= '0';
		TX_FSFIFO_put									<= '0';
		
		Trans_TXFS_SendOK							<= '0';
		Trans_TXFS_Abort							<= '0';
		
		-- CRC interface
		TX_CRC_rst										<= '0';
		TX_CRC_Valid									<= '0';
		
		-- scrambler interface
		DataScrambler_en							<= '0';
		DataScrambler_rst							<= '0';
--		DummyScrambler_en							<= '0';
--		DummyScrambler_rst						<= '0';
		
		-- MUX interface
		CRCMux_ctrl										<= '0';
--		ScramblerMux_ctrl							<= '0';
		
		-- handle PhyNotReady with highest priority
		IF ((Phy_Status /= SATA_PHY_STATUS_LINK_OK) AND NOT
				((TXFSM_State = ST_TXFSM_RESET) OR
				 (TXFSM_State = ST_TXFSM_NO_COMMUNICATION) OR
				 (TXFSM_State = ST_TXFSM_NO_COMMUNICATION_ERROR)
					)) THEN
			TXFSM_Primitive										<= SATA_PRIMITIVE_ALIGN;
			
			TXFSM_NextState										<= ST_TXFSM_NO_COMMUNICATION_ERROR;
--		ELSIF (InsertALIGN = '1') THEN
--			TXFSM_Primitive										<= SATA_PRIMITIVE_ALIGN;
		ELSE
			CASE TXFSM_State IS
				WHEN ST_TXFSM_RESET =>
					TXFSM_Primitive								<= SATA_PRIMITIVE_ALIGN;
					TX_FIFO_rst										<= '1';
					TX_FSFIFO_rst									<= '1';
					
					TXFSM_NextState								<= ST_TXFSM_NO_COMMUNICATION;
			
				WHEN ST_TXFSM_NO_COMMUNICATION =>
					TXFSM_Primitive								<= SATA_PRIMITIVE_ALIGN;
					TXFSM_Error										<= '1';
					
					IF (Phy_Status = SATA_PHY_STATUS_LINK_OK) THEN
						TXFSM_NextState							<= ST_TXFSM_IDLE;			-- ST_TXFSM_SEND_ALIGN;
					END IF;

				WHEN ST_TXFSM_NO_COMMUNICATION_ERROR =>
					TXFSM_Primitive								<= SATA_PRIMITIVE_ALIGN;
					TXFSM_Error										<= '1';
					
					TXFSM_NextState								<= ST_TXFSM_NO_COMMUNICATION;
				
				WHEN ST_TXFSM_IDLE =>
					TXFSM_IDLE										<= '1';
					
					IF (InsertALIGN = '1') THEN
						TXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
					
						IF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN												-- transmission attempt from other side => abort own transmission attempt => send RX_RDY
--							TXFSM_Primitive						<= SATA_PRIMITIVE_RX_RDY;
							
							TXFSM_NextState						<= ST_TXFSM_RECEIVING;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) OR
--									 (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_OK) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_ERROR) OR
									 (RX_Primitive = SATA_PRIMITIVE_SYNC))
						THEN																														-- normal response
							IF ((Trans_TX_SOF = '1') AND (TX_FIFO_Valid = '1')) THEN			-- valid TX_SOF signal
--								TXFSM_Primitive					<= SATA_PRIMITIVE_TX_RDY;							-- start TX_RDY handshaking
								TXFSM_IDLE							<= '0';
								TXFSM_Sending						<= '1';
							
								TXFSM_NextState					<= ST_TXFSM_SEND_TX_RDY;
							ELSE
								NULL;
							END IF;	
						ELSE																														-- catch illegal transitions
							TXFSM_IDLE								<= '0';
							TXFSM_Error								<= '1';
								
							TXFSM_NextState						<= ST_TXFSM_FSM_ERROR;
						END IF;
					ELSE		-- InsertALIGN
						TXFSM_Primitive							<= SATA_PRIMITIVE_SYNC;
					
						IF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN												-- transmission attempt from other side => abort own transmission attempt => send RX_RDY
							TXFSM_Primitive						<= SATA_PRIMITIVE_RX_RDY;
							
							TXFSM_NextState						<= ST_TXFSM_RECEIVING;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) OR
--									 (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_OK) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_ERROR) OR
									 (RX_Primitive = SATA_PRIMITIVE_SYNC))
						THEN																														-- normal response
							IF ((Trans_TX_SOF = '1') AND (TX_FIFO_Valid = '1')) THEN			-- valid TX_SOF signal
								TXFSM_Primitive					<= SATA_PRIMITIVE_TX_RDY;							-- start TX_RDY handshaking
								TXFSM_IDLE							<= '0';
								TXFSM_Sending						<= '1';
							
								TXFSM_NextState					<= ST_TXFSM_SEND_TX_RDY;
							ELSE
								NULL;
							END IF;	
						ELSE																														-- catch illegal transitions
							TXFSM_IDLE								<= '0';
							TXFSM_Error								<= '1';
								
							TXFSM_NextState						<= ST_TXFSM_FSM_ERROR;
						END IF;
					END IF;

				WHEN ST_TXFSM_RECEIVING =>
					TXFSM_Primitive								<= SATA_PRIMITIVE_SYNC;	
					TXFSM_IDLE										<= '1';
					
					IF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN												-- abort receiving, goto idle
						TXFSM_NextState							<= ST_TXFSM_IDLE;
					ELSIF (RX_Primitive = SATA_PRIMITIVE_ALIGN) THEN										-- ignore ALIGN primitives
						NULL;
					END IF;

				-- ----------------------------------------------------------
				-- sending
				-- ----------------------------------------------------------
				WHEN ST_TXFSM_SEND_TX_RDY =>
					TXFSM_Sending									<= '1';
					
					IF (InsertALIGN = '1') THEN
						TXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
						
						IF (RX_Primitive = SATA_PRIMITIVE_RX_RDY) THEN										-- other side is ready to receive
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN									-- transmission attempt from other side
							IF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) THEN								-- => abort own transmission attempt
								TXFSM_IDLE								<= '1';															-- => start receiving
								TXFSM_Sending							<= '0';

								TXFSM_NextState						<= ST_TXFSM_RECEIVING;
							ELSIF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) THEN					-- => ignore transmission attempt
								NULL;
							END IF;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_SYNC) OR										-- ignore SYNC primitives
									 (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) OR								-- ignore WAIT_TERM primitives
									 (RX_Primitive = SATA_PRIMITIVE_ALIGN)) THEN								-- filter ALIGN primitives
							NULL;
						ELSE																															-- catch illegal transitions
							TXFSM_Error								<= '1';
								
							TXFSM_NextState						<= ST_TXFSM_FSM_ERROR;
						END IF;
					ELSE		-- InsertALIGN
						TXFSM_Primitive							<= SATA_PRIMITIVE_TX_RDY;
						
						IF (RX_Primitive = SATA_PRIMITIVE_RX_RDY) THEN											-- other side is ready to receive
							TXFSM_Primitive						<= SATA_PRIMITIVE_SOF;
							
							TX_CRC_rst								<= '1';
							DataScrambler_rst					<= '1';
--							DummyScrambler_rst				<= '1';
							
							TXFSM_NextState						<= ST_TXFSM_SEND_DATA;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN									-- transmission attempt from other side
							IF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) THEN								-- => abort own transmission attempt
								TXFSM_IDLE								<= '1';													-- => start receiving
								TXFSM_Sending							<= '0';
								TXFSM_Primitive						<= SATA_PRIMITIVE_RX_RDY;

								TXFSM_NextState						<= ST_TXFSM_RECEIVING;
							ELSIF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) THEN					-- => ignore transmission attempt
								NULL;
							END IF;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_SYNC) OR											-- ignore SYNC primitives
									 (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) OR								-- ignore WAIT_TERM primitives
									 (RX_Primitive = SATA_PRIMITIVE_ALIGN)) THEN									-- filter ALIGN primitives
							NULL;
						ELSE																													-- catch illegal transitions
							TXFSM_Error								<= '1';
								
							TXFSM_NextState						<= ST_TXFSM_FSM_ERROR;
						END IF;
					END IF;
					
				WHEN ST_TXFSM_SEND_DATA =>
					TXFSM_Sending									<= '1';

					IF (InsertALIGN = '1') THEN
						TXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
						
						IF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN
							TXFSM_NextState						<= ST_TXFSM_IDLE;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) THEN
							TXFSM_NextState						<= ST_TXFSM_SEND_CRC;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_RX_RDY) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_IP) OR
									 (RX_Primitive = SATA_PRIMITIVE_HOLD) OR
									 (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
									 (RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN																													-- ignore normal primitives
							NULL;
						ELSE
							TXFSM_Error								<= '1';
							
							TXFSM_NextState						<= ST_TXFSM_FSM_ERROR;
						END IF;
					ELSE	-- InsertALIGN
						-- TODO: add DMAT and SYNC edge
					
						IF (TX_FIFO_Valid = '1') THEN																	-- valid data in TX_FIFO
							TXFSM_Primitive						<= SATA_PRIMITIVE_NONE;

							TX_FIFO_got								<= '1';
							TX_CRC_Valid							<= '1';
							DataScrambler_en					<= '1';
						
							IF (Trans_TX_EOF = '1') THEN																-- last payload word in Frame
								IF ((RX_Primitive = SATA_PRIMITIVE_R_IP) OR
										(RX_Primitive = SATA_PRIMITIVE_RX_RDY) OR									-- accept overlapping RX_RDY primitives
										(RX_Primitive = SATA_PRIMITIVE_HOLD) OR										-- send last payload word regardless of HOLD primitive
										(RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
										(RX_Primitive = SATA_PRIMITIVE_DMA_TERM) OR								-- send last Word regardless of HOLD primitive
										(RX_Primitive = SATA_PRIMITIVE_ALIGN))											-- ignore ALIGN
								THEN																											-- normal responses => keep sending
									TXFSM_NextState				<= ST_TXFSM_SEND_CRC;
								ELSE
									TXFSM_Error						<= '1';
									
									TXFSM_NextState				<= ST_TXFSM_FSM_ERROR;
								END IF;
							ELSE																												-- normal payload word
								IF ((RX_Primitive = SATA_PRIMITIVE_R_IP) OR
										(RX_Primitive = SATA_PRIMITIVE_RX_RDY) OR									-- 
										(RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
										(RX_Primitive = SATA_PRIMITIVE_ALIGN))
								THEN																											-- normal responses => keep sending
									NULL;
								ELSIF (RX_Primitive = SATA_PRIMITIVE_HOLD) THEN								-- hold on sending
									TXFSM_Primitive				<= SATA_PRIMITIVE_HOLD_ACK;
									
									TX_FIFO_got						<= '0';
									TX_CRC_Valid					<= '0';
									DataScrambler_en			<= '0';
									
									TXFSM_NextState				<= ST_TXFSM_RECEIVED_HOLD;
								ELSIF (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) THEN						-- insert CRC32 checksum
									CRCMux_ctrl						<= '1';
									DataScrambler_en			<= '1';
					
									TXFSM_NextState				<= ST_TXFSM_SEND_EOF;
								END IF;
							END IF;
						ELSE																													-- empty TX_FIFO => insert HOLD
							TXFSM_Primitive						<= SATA_PRIMITIVE_HOLD;
						
							TXFSM_NextState						<= ST_TXFSM_SEND_HOLD;
						END IF;
					END IF;
					
				WHEN ST_TXFSM_SEND_HOLD =>
					TXFSM_Sending									<= '1';
				
					IF (InsertAlign = '1') THEN
						TXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
						
						IF (TX_FIFO_Valid = '1') THEN
							IF (Trans_TX_EOF = '1') THEN																-- last payload word in frame
								IF ((RX_Primitive = SATA_PRIMITIVE_R_IP) OR
										(RX_Primitive = SATA_PRIMITIVE_RX_RDY) OR									-- 
										(RX_Primitive = SATA_PRIMITIVE_HOLD) OR										-- send last payload word regardless of HOLD primitive
										(RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
										(RX_Primitive = SATA_PRIMITIVE_DMA_TERM) OR								-- send last Word regardless of HOLD primitive
										(RX_Primitive = SATA_PRIMITIVE_ALIGN))											-- ignore ALIGN
								THEN
									TXFSM_NextState				<= ST_TXFSM_SEND_DATA;
								ELSE
									TXFSM_Error						<= '1';
									
									TXFSM_NextState				<= ST_TXFSM_FSM_ERROR;
								END IF;
							ELSE 																												-- normal payload word
								IF ((RX_Primitive = SATA_PRIMITIVE_R_IP) OR
										(RX_Primitive = SATA_PRIMITIVE_HOLD_ACK))
								THEN
									TXFSM_NextState				<= ST_TXFSM_SEND_DATA;
								ELSIF (RX_Primitive = SATA_PRIMITIVE_HOLD) THEN
									TXFSM_NextState				<= ST_TXFSM_RECEIVED_HOLD;
								ELSIF (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) THEN						-- insert CRC32 checksum
									TXFSM_NextState				<= ST_TXFSM_SEND_CRC;
								END IF;
							END IF;
						END IF;
					ELSE	-- InsertAlign
						IF (TX_FIFO_Valid = '1') THEN
							TXFSM_Primitive						<= SATA_PRIMITIVE_NONE;
						
							TX_FIFO_got								<= '1';
							TX_CRC_Valid							<= '1';
							DataScrambler_en					<= '1';
						
							IF (Trans_TX_EOF = '1') THEN																-- last payload word in frame
								IF ((RX_Primitive = SATA_PRIMITIVE_R_IP) OR
										(RX_Primitive = SATA_PRIMITIVE_RX_RDY) OR									-- 
										(RX_Primitive = SATA_PRIMITIVE_HOLD) OR										-- send last payload word regardless of HOLD primitive
										(RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
										(RX_Primitive = SATA_PRIMITIVE_DMA_TERM) OR								-- send last Word regardless of HOLD primitive
										(RX_Primitive = SATA_PRIMITIVE_ALIGN))											-- ignore ALIGN
								THEN
									TXFSM_NextState				<= ST_TXFSM_SEND_CRC;
								ELSE
									TXFSM_Error						<= '1';
									
									TXFSM_NextState				<= ST_TXFSM_FSM_ERROR;
								END IF;
							ELSE 																												-- normal payload word
								IF ((RX_Primitive = SATA_PRIMITIVE_R_IP) OR
										(RX_Primitive = SATA_PRIMITIVE_HOLD_ACK))
								THEN
									TXFSM_NextState				<= ST_TXFSM_SEND_DATA;
								ELSIF (RX_Primitive = SATA_PRIMITIVE_HOLD) THEN
									TXFSM_Primitive				<= SATA_PRIMITIVE_HOLD_ACK;
                  TX_FIFO_got								<= '0';
                  TX_CRC_Valid							<= '0';
                  DataScrambler_en					<= '0';
								
									TXFSM_NextState				<= ST_TXFSM_RECEIVED_HOLD;
								ELSIF (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) THEN						-- insert CRC32 checksum
									CRCMux_ctrl						<= '1';
					
									TXFSM_NextState				<= ST_TXFSM_SEND_EOF;
								END IF;
							END IF;
						ELSE																													-- empty FIFO => insert HOLD
							TXFSM_Primitive						<= SATA_PRIMITIVE_HOLD;
						END IF;
					END IF;
				
				WHEN ST_TXFSM_RECEIVED_HOLD =>
					TXFSM_Sending									<= '1';
					
					IF (InsertAlign = '1') THEN
						TXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
						
						IF ((RX_Primitive = SATA_PRIMITIVE_HOLD) OR
                (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN																													-- keep waiting
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_R_IP) THEN										-- resume sending data
							IF (TX_FIFO_Valid = '1') THEN
								IF (Trans_TX_EOF = '1') THEN															-- last payload word in frame
									TXFSM_NextState				<= ST_TXFSM_SEND_DATA;
								ELSE
									TXFSM_NextState				<= ST_TXFSM_SEND_DATA;
								END IF;
							ELSE
								TXFSM_NextState					<= ST_TXFSM_SEND_HOLD;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) THEN
							TXFSM_NextState						<= ST_TXFSM_SEND_CRC;
						ELSE
							TXFSM_Error								<= '1';
							
							TXFSM_NextState						<= ST_TXFSM_FSM_ERROR;
						END IF;
					
					ELSE	-- InsertAlign
						TXFSM_Primitive							<= SATA_PRIMITIVE_HOLD_ACK;
					
						IF ((RX_Primitive = SATA_PRIMITIVE_HOLD) OR
                (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN																													-- keep waiting
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_R_IP) THEN										-- resume sending data
							IF (TX_FIFO_Valid = '1') THEN
								TXFSM_Primitive						<= SATA_PRIMITIVE_NONE;
							
								TX_FIFO_got								<= '1';
								TX_CRC_Valid							<= '1';
								DataScrambler_en					<= '1';
							
								IF (Trans_TX_EOF = '1') THEN															-- last payload word in frame
									TXFSM_NextState					<= ST_TXFSM_SEND_CRC;
								ELSE
									TXFSM_NextState					<= ST_TXFSM_SEND_DATA;
								END IF;
							ELSE
								TXFSM_Primitive						<= SATA_PRIMITIVE_HOLD;
							
								TXFSM_NextState						<= ST_TXFSM_SEND_HOLD;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_DMA_TERM) THEN
							TXFSM_Primitive							<= SATA_PRIMITIVE_NONE;
							CRCMux_ctrl									<= '1';
							DataScrambler_en						<= '1';
					
							TXFSM_NextState							<= ST_TXFSM_SEND_EOF;
						ELSE
							TXFSM_Error									<= '1';
							
							TXFSM_NextState							<= ST_TXFSM_FSM_ERROR;
						END IF;
					END IF;
				
				WHEN ST_TXFSM_SEND_CRC =>
					TXFSM_Sending									<= '1';
					
					IF (InsertAlign = '1') THEN
						TXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
					ELSE
						TXFSM_Primitive							<= SATA_PRIMITIVE_NONE;
					
						CRCMux_ctrl									<= '1';
						DataScrambler_en						<= '1';
					
						TXFSM_NextState							<= ST_TXFSM_SEND_EOF;
					END IF;
				
				WHEN ST_TXFSM_SEND_EOF =>
					TXFSM_Sending									<= '1';
					
					IF (InsertAlign = '1') THEN
						TXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
					ELSE
						TXFSM_Primitive							<= SATA_PRIMITIVE_EOF;
						TXFSM_Sending								<= '1';
				
						TXFSM_NextState							<= ST_TXFSM_WAIT;
					END IF;

				WHEN ST_TXFSM_WAIT =>
					TXFSM_Sending									<= '1';
					
					IF (InsertAlign = '1') THEN
						TXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
					
						IF ((RX_Primitive = SATA_PRIMITIVE_R_IP) OR
								(RX_Primitive = SATA_PRIMITIVE_RX_RDY) OR									-- 
								(RX_Primitive = SATA_PRIMITIVE_HOLD) OR
								(RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_R_OK) THEN
							TX_FSFIFO_put							<= '1';
							Trans_TXFS_SendOK					<= '1';

							TXFSM_NextState						<= ST_TXFSM_IDLE;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_R_ERROR) THEN
							TX_FSFIFO_put							<= '1';
							Trans_TXFS_Abort					<= '1';
						
							TXFSM_NextState						<= ST_TXFSM_IDLE;
						ELSE
							TXFSM_Error								<= '1';
						
							TXFSM_NextState						<= ST_TXFSM_FSM_ERROR;
						END IF;
					ELSE	-- InsertAlign
						TXFSM_Primitive							<= SATA_PRIMITIVE_WAIT_TERM;
					
						IF ((RX_Primitive = SATA_PRIMITIVE_R_IP) OR
								(RX_Primitive = SATA_PRIMITIVE_RX_RDY) OR									-- 
								(RX_Primitive = SATA_PRIMITIVE_HOLD) OR
								(RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_R_OK) THEN
							TXFSM_Primitive							<= SATA_PRIMITIVE_SYNC;
						
							TX_FSFIFO_put								<= '1';
							Trans_TXFS_SendOK						<= '1';
						
							TXFSM_NextState							<= ST_TXFSM_IDLE;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_R_ERROR) THEN
							TXFSM_Primitive							<= SATA_PRIMITIVE_SYNC;

							TX_FSFIFO_put								<= '1';
							Trans_TXFS_Abort						<= '1';
						
							TXFSM_NextState							<= ST_TXFSM_IDLE;
						ELSE
							TXFSM_Error									<= '1';
						
							TXFSM_NextState							<= ST_TXFSM_FSM_ERROR;
						END IF;
					END IF;
					
				-- ----------------------------------------------------------
				-- error handling
				-- ----------------------------------------------------------
				WHEN ST_TXFSM_FSM_ERROR =>
					TXFSM_Primitive								<= SATA_PRIMITIVE_SYNC;
					TXFSM_IDLE										<= '1';
					TXFSM_Error										<= '0';		-- '1';
					
					TXFSM_NextState								<= ST_TXFSM_IDLE;

			END CASE;
		END IF;
	END PROCESS;

-- ==================================================================
-- LinkLayer - RX Statemachine
-- ==================================================================
	-- 
	RXFSM_IsSOF 		<= to_sl(RX_Primitive = SATA_PRIMITIVE_SOF);
	RXFSM_IsEOF 		<= to_sl(RX_Primitive = SATA_PRIMITIVE_EOF);

	-- register for SOF
	-- -----------------------------
	-- update register if SOF is received, reset if DATA occurs
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (RXFSM_IsSOF = '1') THEN
				RX_SOF_r		<= '1';
			ELSIF (RXFSM_IsData = '1') THEN
				RX_SOF_r		<= '0';
			END IF;
		END IF;
	END PROCESS;

	-- register for CRC_OK
	-- -----------------------------
	-- update register if data is received, reset if EOF occurs
	RX_CRC_OKReg_set	<= RXFSM_IsData	AND RX_CRC_OK;
	RX_CRC_OKReg_rst	<= RXFSM_IsEOF	OR (NOT RX_CRC_OK AND RXFSM_IsData);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (RX_CRC_OKReg_set = '1') THEN
				RX_CRC_OKReg_r			<= '1';
			ELSIF (RX_CRC_OKReg_rst = '1') THEN
				RX_CRC_OKReg_r			<= '0';
			END IF;
		END IF;
	END PROCESS;
	
--	RX_CRC_OKReg_r	<= RX_CRC_OK;
	
	-- Statemachine
	-- -----------------------------
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			if Phy_ResetDone = '0' then
				RXFSM_State 		<= ST_RXFSM_RESET;
			elsif ClockEnable = '1' then
				if Reset = '1' then
					RXFSM_State 	<= ST_RXFSM_RESET;
				else
					RXFSM_State 	<= RXFSM_NextState;
				end if;
			end if;
		END IF;
	END PROCESS;


	PROCESS(RXFSM_State, Phy_Status, Trans_TX_SOF, TX_FIFO_Valid, RX_Primitive, RX_FIFO_Full, RX_FIFO_SpaceAvailable, RX_FSFIFO_Full, RX_CRC_OKReg_r, InsertALIGN)
	BEGIN
		RXFSM_NextState								<= RXFSM_State;

		-- internal state signals
		RXFSM_IDLE										<= '0';
		RXFSM_Error										<= '0';
		RXFSM_Receiving								<= '0';

		-- primitive interface
		RXFSM_Primitive								<= SATA_PRIMITIVE_NONE;

		-- FIFO interface
		RX_FIFO_rst										<= '0';
		RXFSM_IsData									<= '0';
		RX_FSFIFO_rst									<= '0';
		RX_FSFIFO_put									<= '0';
		
		Trans_RXFS_CRCOK							<= '0';
		Trans_RXFS_Abort							<= '0';
		
		-- CRC interface
		RX_CRC_rst										<= '0';
		RX_CRC_Valid									<= '0';
		
		-- scrambler interface
		DataUnscrambler_en						<= '0';
		DataUnscrambler_rst						<= '0';
		
		-- handle PhyNotReady with highest priority
		IF ((Phy_Status /= SATA_PHY_STATUS_LINK_OK) AND NOT
				((RXFSM_State = ST_RXFSM_RESET) OR
				 (RXFSM_State = ST_RXFSM_NO_COMMUNICATION) OR
				 (RXFSM_State = ST_RXFSM_NO_COMMUNICATION_ERROR)
					)) THEN
			RXFSM_Primitive										<= SATA_PRIMITIVE_ALIGN;
			
			RXFSM_NextState										<= ST_RXFSM_NO_COMMUNICATION_ERROR;
		ELSE
			CASE RXFSM_State IS
				WHEN ST_RXFSM_RESET =>
					RXFSM_Primitive								<= SATA_PRIMITIVE_ALIGN;
					RX_FIFO_rst										<= '1';
					RX_FSFIFO_rst									<= '1';
					
					RXFSM_NextState								<= ST_RXFSM_NO_COMMUNICATION;
			
				WHEN ST_RXFSM_NO_COMMUNICATION =>
					RXFSM_Primitive								<= SATA_PRIMITIVE_ALIGN;
					RXFSM_Error										<= '1';
					
					IF (Phy_Status = SATA_PHY_STATUS_LINK_OK) THEN
						RXFSM_NextState							<= ST_RXFSM_IDLE;
					END IF;

				WHEN ST_RXFSM_NO_COMMUNICATION_ERROR =>
					RXFSM_Primitive								<= SATA_PRIMITIVE_ALIGN;
					RXFSM_Error										<= '1';
					
					RXFSM_NextState								<= ST_RXFSM_NO_COMMUNICATION;
				
				WHEN ST_RXFSM_IDLE =>
					RXFSM_IDLE										<= '1';
				
					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
					
						IF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN											-- transmission attempt received => abort own transmission attempt => send RX_RDY
							IF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) THEN								-- 
								RXFSM_IDLE							<= '0';														-- end IDLE mode
								RXFSM_Receiving					<= '1';														-- start receiving

								IF (RX_FIFO_SpaceAvailable = '1') THEN										-- RX FIFO has space => send RX_RDY
									RXFSM_NextState				<= ST_RXFSM_SEND_RX_RDY;
								ELSE																											-- RX FIFO has no space => wait for space
									RXFSM_NextState				<= ST_RXFSM_WAIT_FIFO;
								END IF;
							ELSIF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) THEN					-- => ignore transmission attempt
								IF ((Trans_TX_SOF = '1') AND (TX_FIFO_Valid = '1')) THEN	-- start own transmission attempt?
									RXFSM_NextState				<= ST_RXFSM_SENDING;							-- go to sending; TXFSM is working
								ELSE
									RXFSM_IDLE						<= '0';														-- end IDLE mode
									RXFSM_Receiving				<= '1';														-- start receiving
									
									IF (RX_FIFO_SpaceAvailable = '1') THEN									-- RX FIFO has space => send RX_RDY
										RXFSM_NextState			<= ST_RXFSM_SEND_RX_RDY;
									ELSE																										-- RX FIFO has no space => wait for space
										RXFSM_NextState			<= ST_RXFSM_WAIT_FIFO;
									END IF;
								END IF;
							END IF;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) OR
									 (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_OK) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_ERROR) OR
									 (RX_Primitive = SATA_PRIMITIVE_SYNC))
						THEN																													-- 
							IF ((Trans_TX_SOF = '1') AND (TX_FIFO_Valid = '1')) THEN
								RXFSM_NextState					<= ST_RXFSM_SENDING;							-- go to sending; TXFSM is working
							ELSE
								NULL;																											-- nothing to do
							END IF;
						ELSE
							RXFSM_IDLE								<= '0';
							RXFSM_Error								<= '1';
								
							RXFSM_NextState						<= ST_RXFSM_FSM_ERROR;
						END IF;
					ELSE	-- InsertALIGN
						RXFSM_Primitive							<= SATA_PRIMITIVE_SYNC;
					
						IF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN											-- transmission attempt received => abort own transmission attempt => send RX_RDY
							IF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) THEN								-- 
								RXFSM_IDLE							<= '0';														-- end IDLE mode
								RXFSM_Receiving					<= '1';														-- start receiving

								IF (RX_FIFO_SpaceAvailable = '1') THEN										-- RX FIFO has space => send RX_RDY
									RXFSM_Primitive				<= SATA_PRIMITIVE_RX_RDY;
									RXFSM_NextState				<= ST_RXFSM_SEND_RX_RDY;
								ELSE																											-- RX FIFO has no space => wait for space
									RXFSM_Primitive				<= SATA_PRIMITIVE_SYNC;
									RXFSM_NextState				<= ST_RXFSM_WAIT_FIFO;
								END IF;
							ELSIF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) THEN					-- => ignore transmission attempt
								IF ((Trans_TX_SOF = '1') AND (TX_FIFO_Valid = '1')) THEN	-- start own transmission attempt?
									RXFSM_NextState				<= ST_RXFSM_SENDING;							-- go to sending; TXFSM is working
								ELSE
									RXFSM_IDLE						<= '0';														-- end IDLE mode
									RXFSM_Receiving				<= '1';														-- start receiving
								
									IF (RX_FIFO_SpaceAvailable = '1') THEN									-- RX FIFO has space => send RX_RDY
										RXFSM_Primitive			<= SATA_PRIMITIVE_RX_RDY;
										RXFSM_NextState			<= ST_RXFSM_SEND_RX_RDY;
									ELSE																										-- RX FIFO has no space => wait for space
										RXFSM_Primitive			<= SATA_PRIMITIVE_SYNC;
										RXFSM_NextState			<= ST_RXFSM_WAIT_FIFO;
									END IF;
								END IF;
							END IF;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) OR
									 (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_OK) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_ERROR) OR
									 (RX_Primitive = SATA_PRIMITIVE_SYNC))
						THEN																													-- 
							IF ((Trans_TX_SOF = '1') AND (TX_FIFO_Valid = '1')) THEN
								RXFSM_NextState					<= ST_RXFSM_SENDING;							-- go to sending; TXFSM is working
							END IF;
						ELSE
							RXFSM_IDLE								<= '0';
							RXFSM_Error								<= '1';
								
							RXFSM_NextState						<= ST_RXFSM_FSM_ERROR;
						END IF;
					END IF;

				WHEN ST_RXFSM_SENDING =>
					RXFSM_IDLE										<= '1';
					
					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
					
						IF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN
							IF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) THEN								-- transmission attempt received => abort own transmission attempt => send RX_RDY
								RXFSM_IDLE								<= '0';														-- end IDLE mode
								RXFSM_Receiving						<= '1';														-- start receiving
						
								IF (RX_FIFO_SpaceAvailable = '1') THEN											-- RX FIFO has space => send RX_RDY
									RXFSM_NextState					<= ST_RXFSM_SEND_RX_RDY;
								ELSE																												-- RX FIFO has no space => wait for space
									RXFSM_NextState					<= ST_RXFSM_WAIT_FIFO;
								END IF;
							ELSIF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) THEN	
								NULL;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_RX_RDY) THEN																													-- 
							RXFSM_NextState							<= ST_RXFSM_SENDING2;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) OR
									 (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_OK) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_ERROR) OR
									 (RX_Primitive = SATA_PRIMITIVE_SYNC))
						THEN																													-- 
							NULL;																												-- nothing to do
						ELSE
							RXFSM_IDLE								<= '0';
							RXFSM_Error								<= '1';
								
							RXFSM_NextState						<= ST_RXFSM_FSM_ERROR;
						END IF;
					ELSE	-- InsertALIGN
						RXFSM_Primitive							<= SATA_PRIMITIVE_SYNC;
					
						IF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN
							IF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_HOST) THEN								-- transmission attempt received => abort own transmission attempt => send RX_RDY
								RXFSM_IDLE								<= '0';														-- end IDLE mode
								RXFSM_Receiving						<= '1';														-- start receiving
							
								IF (RX_FIFO_SpaceAvailable = '1') THEN											-- RX FIFO has space => send RX_RDY
									RXFSM_Primitive					<= SATA_PRIMITIVE_RX_RDY;
									
									RXFSM_NextState					<= ST_RXFSM_SEND_RX_RDY;
								ELSE																												-- RX FIFO has no space => wait for space
									RXFSM_Primitive					<= SATA_PRIMITIVE_SYNC;
									
									RXFSM_NextState					<= ST_RXFSM_WAIT_FIFO;
								END IF;
							ELSIF (CONTROLLER_TYPE	= SATA_DEVICE_TYPE_DEVICE) THEN
								NULL;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_RX_RDY) THEN
							RXFSM_NextState						<= ST_RXFSM_SENDING2;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) OR
									 (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_OK) OR
									 (RX_Primitive = SATA_PRIMITIVE_R_ERROR) OR
									 (RX_Primitive = SATA_PRIMITIVE_SYNC))
						THEN																													-- 
							NULL;																											-- nothing to do
						ELSE
							RXFSM_IDLE								<= '0';
							RXFSM_Error								<= '1';
								
							RXFSM_NextState						<= ST_RXFSM_FSM_ERROR;
						END IF;
					END IF;
					
				WHEN ST_RXFSM_SENDING2 =>
					RXFSM_IDLE										<= '1';
					
					IF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN													-- abort receiving, goto idle
						RXFSM_NextState							<= ST_RXFSM_IDLE;
					ELSIF (RX_Primitive = SATA_PRIMITIVE_ALIGN) THEN											-- ignore ALIGN primitives
						NULL;
					ELSIF (RX_Primitive = SATA_PRIMITIVE_R_OK) THEN											-- receiving completed with OK
						RXFSM_NextState							<= ST_RXFSM_IDLE;
					ELSIF (RX_Primitive = SATA_PRIMITIVE_R_ERROR) THEN										-- receiving completed with ERROR
						RXFSM_NextState							<= ST_RXFSM_IDLE;
					END IF;

				-- ----------------------------------------------------------
				-- receiving
				-- ----------------------------------------------------------
				WHEN ST_RXFSM_WAIT_FIFO =>
					RXFSM_Receiving								<= '1';
					
					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
						
						IF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN
							IF (RX_FIFO_SpaceAvailable = '1') THEN
--								RXFSM_Primitive					<= SATA_PRIMITIVE_RX_RDY;
							
								RXFSM_NextState					<= ST_RXFSM_SEND_RX_RDY;
							ELSE
								NULL;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_ALIGN) THEN
							NULL;
						ELSE
							RXFSM_NextState						<= ST_RXFSM_IDLE;
						END IF;				
					ELSE		-- InsertALIGN
						RXFSM_Primitive							<= SATA_PRIMITIVE_SYNC;
						
						IF (RX_Primitive = SATA_PRIMITIVE_TX_RDY) THEN
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								RXFSM_Primitive					<= SATA_PRIMITIVE_RX_RDY;
							
								RXFSM_NextState					<= ST_RXFSM_SEND_RX_RDY;
							ELSE
								NULL;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_ALIGN) THEN
							NULL;
						ELSE
							RXFSM_NextState						<= ST_RXFSM_IDLE;
						END IF;				
					END IF;
					
				WHEN ST_RXFSM_SEND_RX_RDY =>
					RXFSM_Receiving								<= '1';

					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive								<= SATA_PRIMITIVE_ALIGN;
						
						IF ((RX_Primitive = SATA_PRIMITIVE_TX_RDY) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_SOF) THEN
							RX_CRC_rst									<= '1';
							DataUnscrambler_rst					<= '1';
						
							RXFSM_NextState							<= ST_RXFSM_RECEIVE_DATA;
						ELSE
							RXFSM_NextState							<= ST_RXFSM_IDLE;
						END IF;
					ELSE		-- InsertALIGN
						RXFSM_Primitive								<= SATA_PRIMITIVE_RX_RDY;
						
						IF ((RX_Primitive = SATA_PRIMITIVE_TX_RDY) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_SOF) THEN
							RXFSM_Primitive							<= SATA_PRIMITIVE_R_IP;
							
							RX_CRC_rst									<= '1';
							DataUnscrambler_rst					<= '1';
						
							RXFSM_NextState							<= ST_RXFSM_RECEIVE_DATA;
						ELSE
							RXFSM_NextState							<= ST_RXFSM_IDLE;
						END IF;
					END IF;
				
				WHEN ST_RXFSM_RECEIVE_DATA =>
					RXFSM_Receiving								<= '1';

					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;

						RXFSM_IsData								<= '1';
						RX_CRC_Valid								<= '1';
						DataUnscrambler_en					<= '1';
						
						IF (RX_Primitive = SATA_PRIMITIVE_HOLD) THEN
--							RXFSM_Primitive						<= SATA_PRIMITIVE_HOLD_ACK;
							
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
							RXFSM_NextState						<= ST_RXFSM_RECEIVED_HOLD;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
									 (RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
							RXFSM_NextState						<= ST_RXFSM_RECEIVE_DATA;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_EOF) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';

							RX_FSFIFO_put							<= '1';

							IF (RX_CRC_OKReg_r = '1') THEN
								Trans_RXFS_CRCOK				<= '1';
								RXFSM_NextState					<= ST_RXFSM_SEND_R_OK;
							ELSE
								RXFSM_NextState					<= ST_RXFSM_SEND_R_ERROR;
							END IF;
						
						ELSIF (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) THEN
							RX_FSFIFO_put							<= '1';
							Trans_RXFS_Abort					<= '1';
						
							RXFSM_NextState						<= ST_RXFSM_IDLE;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_NONE) THEN
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								NULL;
							ELSE
								RXFSM_NextState					<= ST_RXFSM_SEND_HOLD;
							END IF;
						ELSE
							RXFSM_Error								<= '1';
							RXFSM_NextState						<= ST_RXFSM_FSM_ERROR;
						END IF;
					ELSE		-- InsertALIGN
						RXFSM_Primitive							<= SATA_PRIMITIVE_R_IP;

						RXFSM_IsData								<= '1';
						RX_CRC_Valid								<= '1';
						DataUnscrambler_en					<= '1';
						
						IF (RX_Primitive = SATA_PRIMITIVE_HOLD) THEN
							RXFSM_Primitive						<= SATA_PRIMITIVE_HOLD_ACK;
							
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
							RXFSM_NextState						<= ST_RXFSM_RECEIVED_HOLD;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
									 (RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
							RXFSM_NextState						<= ST_RXFSM_RECEIVE_DATA;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_EOF) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';

							RX_FSFIFO_put							<= '1';
							
							IF (RX_CRC_OKReg_r = '1') THEN
								RXFSM_Primitive					<= SATA_PRIMITIVE_R_OK;
								Trans_RXFS_CRCOK				<= '1';
								
								RXFSM_NextState					<= ST_RXFSM_SEND_R_OK;
							ELSE
								RXFSM_Primitive					<= SATA_PRIMITIVE_R_ERROR;
								RXFSM_NextState					<= ST_RXFSM_SEND_R_ERROR;
							END IF;
							
						ELSIF (RX_Primitive = SATA_PRIMITIVE_WAIT_TERM) THEN
							RX_FSFIFO_put							<= '1';
							Trans_RXFS_Abort					<= '1';
						
							RXFSM_NextState						<= ST_RXFSM_IDLE;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_NONE) THEN
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								NULL;
							ELSE
								RXFSM_Primitive					<= SATA_PRIMITIVE_HOLD;
								RXFSM_NextState					<= ST_RXFSM_SEND_HOLD;
							END IF;
						ELSE
							RXFSM_Error								<= '1';
							RXFSM_NextState						<= ST_RXFSM_FSM_ERROR;
						END IF;
					END IF;
				
					-- RXFIFO error => override all bits
					IF (RX_FIFO_Full = '1') THEN
						RXFSM_Error									<= '1';
						
						RXFSM_IsData								<= '0';
						RX_CRC_Valid								<= '0';
						DataUnscrambler_en					<= '0';
						
						RX_FSFIFO_put								<= '1';
						
						IF (InsertALIGN = '1') THEN
							RXFSM_Primitive						<= SATA_PRIMITIVE_ALIGN;
							RXFSM_NextState						<= ST_RXFSM_SEND_DMA_TERM;
						ELSE
							RXFSM_Primitive						<= SATA_PRIMITIVE_DMA_TERM;
							RXFSM_NextState						<= ST_RXFSM_RXFIFO_FULL;
						END IF;
					END IF;
				
				WHEN ST_RXFSM_SEND_HOLD =>
					RXFSM_Receiving								<= '1';

					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
						
						RXFSM_IsData								<= '1';
						RX_CRC_Valid								<= '1';
						DataUnscrambler_en					<= '1';
						
						IF (RX_Primitive = SATA_PRIMITIVE_HOLD) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
						ELSIF (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
							RXFSM_NextState						<= ST_RXFSM_RECEIVED_HOLD_ACK;
							
						ELSIF (RX_Primitive = SATA_PRIMITIVE_ALIGN) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
							
						ELSIF (RX_Primitive = SATA_PRIMITIVE_EOF) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
							RX_FSFIFO_put							<= '1';
						
							IF (RX_CRC_OKReg_r = '1') THEN
								Trans_RXFS_CRCOK				<= '1';
								RXFSM_NextState					<= ST_RXFSM_SEND_R_OK;
							ELSE
								RXFSM_NextState					<= ST_RXFSM_SEND_R_ERROR;
							END IF;
						ELSE
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								RXFSM_NextState					<= ST_RXFSM_RECEIVE_DATA;
							ELSE
								NULL;
							END IF;
						END IF;
					ELSE		-- InsertALIGN
						RXFSM_Primitive							<= SATA_PRIMITIVE_HOLD;
						
						RXFSM_IsData								<= '1';
						RX_CRC_Valid								<= '1';
						DataUnscrambler_en					<= '1';
						
						IF (RX_Primitive = SATA_PRIMITIVE_HOLD) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
						ELSIF (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
							RXFSM_NextState						<= ST_RXFSM_RECEIVED_HOLD_ACK;
							
						ELSIF (RX_Primitive = SATA_PRIMITIVE_ALIGN) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
							
						ELSIF (RX_Primitive = SATA_PRIMITIVE_EOF) THEN
							RXFSM_IsData							<= '0';
							RX_CRC_Valid							<= '0';
							DataUnscrambler_en				<= '0';
						
							RX_FSFIFO_put							<= '1';
							
							IF (RX_CRC_OKReg_r = '1') THEN
								RXFSM_Primitive					<= SATA_PRIMITIVE_R_OK;
								Trans_RXFS_CRCOK				<= '1';
								RXFSM_NextState					<= ST_RXFSM_SEND_R_OK;
							ELSE
								RXFSM_Primitive					<= SATA_PRIMITIVE_R_ERROR;
								RXFSM_NextState					<= ST_RXFSM_SEND_R_ERROR;
							END IF;
						ELSE
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								RXFSM_NextState					<= ST_RXFSM_RECEIVE_DATA;
							ELSE
								NULL;
							END IF;
						END IF;
					END IF;
				
					-- RXFIFO error => override all bits
					IF (RX_FIFO_Full = '1') THEN
						RXFSM_Receiving							<= '1';
						RXFSM_Error									<= '1';
						
						RXFSM_IsData								<= '0';
						RX_CRC_Valid								<= '0';
						DataUnscrambler_en					<= '0';
						
						RX_FSFIFO_put								<= '1';
						
						IF (InsertALIGN = '1') THEN
							RXFSM_Primitive						<= SATA_PRIMITIVE_ALIGN;
							RXFSM_NextState						<= ST_RXFSM_SEND_DMA_TERM;
						ELSE
							RXFSM_Primitive						<= SATA_PRIMITIVE_DMA_TERM;
							RXFSM_NextState						<= ST_RXFSM_RXFIFO_FULL;
						END IF;
					END IF;
				
				WHEN ST_RXFSM_RECEIVED_HOLD =>
					RXFSM_Receiving								<= '1';
					
					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
					
						IF ((RX_Primitive = SATA_PRIMITIVE_HOLD) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_NONE) THEN
							RXFSM_IsData							<= '1';
							RX_CRC_Valid							<= '1';
							DataUnscrambler_en				<= '1';
							
							RXFSM_NextState						<= ST_RXFSM_RECEIVE_DATA;
						ELSE
							NULL;
						END IF;
					ELSE		-- InsertALIGN
						RXFSM_Primitive							<= SATA_PRIMITIVE_HOLD_ACK;
					
						IF ((RX_Primitive = SATA_PRIMITIVE_HOLD) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_NONE) THEN
							RXFSM_Primitive						<= SATA_PRIMITIVE_R_IP;
							
							RXFSM_IsData							<= '1';
							RX_CRC_Valid							<= '1';
							DataUnscrambler_en				<= '1';
							
							RXFSM_NextState						<= ST_RXFSM_RECEIVE_DATA;
						ELSE
							NULL;
						END IF;
					END IF;
				
					-- RXFIFO error => override all bits
					IF (RX_FIFO_Full = '1') THEN
						RXFSM_Error									<= '1';
						
						RXFSM_IsData								<= '0';
						RX_CRC_Valid								<= '0';
						DataUnscrambler_en					<= '0';
						
						RX_FSFIFO_put								<= '1';
						
						IF (InsertALIGN = '1') THEN
							RXFSM_Primitive						<= SATA_PRIMITIVE_ALIGN;
							RXFSM_NextState						<= ST_RXFSM_SEND_DMA_TERM;
						ELSE
							RXFSM_Primitive						<= SATA_PRIMITIVE_DMA_TERM;
							RXFSM_NextState						<= ST_RXFSM_RXFIFO_FULL;
						END IF;
					END IF;
				
				WHEN ST_RXFSM_RECEIVED_HOLD_ACK =>
					RXFSM_Receiving								<= '1';
					
					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
						
						IF ((RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								RXFSM_NextState					<= ST_RXFSM_RECEIVE_DATA;
							ELSE
								NULL;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN
							-- TODO: SYNC edge
							NULL;
						END IF;
					ELSE		-- InsertALIGN
						RXFSM_Primitive							<= SATA_PRIMITIVE_HOLD;
						
						IF ((RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
								(RX_Primitive = SATA_PRIMITIVE_ALIGN))
						THEN
							IF (RX_FIFO_SpaceAvailable = '1') THEN
								RXFSM_Primitive					<= SATA_PRIMITIVE_R_IP;
								RXFSM_NextState					<= ST_RXFSM_RECEIVE_DATA;
							ELSE
								NULL;
							END IF;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN
							-- TODO: SYNC edge
							NULL;
						END IF;
					END IF;
				
					-- RXFIFO error => override all bits
					IF (RX_FIFO_Full = '1') THEN
						RXFSM_Error									<= '1';
						
						RXFSM_IsData								<= '0';
						RX_CRC_Valid								<= '0';
						DataUnscrambler_en					<= '0';
						
						RX_FSFIFO_put								<= '1';
						
						IF (InsertALIGN = '1') THEN
							RXFSM_Primitive						<= SATA_PRIMITIVE_ALIGN;
							RXFSM_NextState						<= ST_RXFSM_SEND_DMA_TERM;
						ELSE
							RXFSM_Primitive						<= SATA_PRIMITIVE_DMA_TERM;
							RXFSM_NextState						<= ST_RXFSM_RXFIFO_FULL;
						END IF;
					END IF;

-- ==================================================================
-- ST_RXFSM_SEND_R_OK
-- ==================================================================
				WHEN ST_RXFSM_SEND_R_OK =>
					RXFSM_Receiving											<= '1';
					
					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive										<= SATA_PRIMITIVE_ALIGN;
						
						CASE RX_Primitive IS
							WHEN SATA_PRIMITIVE_ALIGN =>					NULL;
							WHEN SATA_PRIMITIVE_SYNC =>
								RXFSM_IDLE										<= '1';
								RXFSM_Receiving								<= '0';
								RXFSM_NextState								<= ST_RXFSM_IDLE;
							WHEN SATA_PRIMITIVE_SOF =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_EOF =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_HOLD =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_HOLD_ACK =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_CONT =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_OK =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_ERROR =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_IP =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_RX_RDY =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_TX_RDY =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_DMA_TERM =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_WAIT_TERM =>		NULL;
							WHEN SATA_PRIMITIVE_PM_ACK =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_NACK =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_REQ_P =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_REQ_S =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_ILLEGAL =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_DIAL_TONE =>		RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_NONE =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
						END CASE;
					ELSE	-- InsertAlign
						RXFSM_Primitive										<= SATA_PRIMITIVE_R_OK;
						
						CASE RX_Primitive IS
							WHEN SATA_PRIMITIVE_ALIGN =>					NULL;
							WHEN SATA_PRIMITIVE_SYNC =>
								RXFSM_IDLE										<= '1';
								RXFSM_Receiving								<= '0';
								RXFSM_NextState								<= ST_RXFSM_IDLE;
							WHEN SATA_PRIMITIVE_SOF =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_EOF =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_HOLD =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_HOLD_ACK =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_CONT =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_OK =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_ERROR =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_IP =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_RX_RDY =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_TX_RDY =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_DMA_TERM =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_WAIT_TERM =>		NULL;
							WHEN SATA_PRIMITIVE_PM_ACK =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_NACK =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_REQ_P =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_REQ_S =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_ILLEGAL =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_DIAL_TONE =>		RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_NONE =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
						END CASE;
					END IF;

-- ==================================================================
-- ST_RXFSM_SEND_R_ERROR
-- ==================================================================
				WHEN ST_RXFSM_SEND_R_ERROR =>
					RXFSM_Receiving											<= '1';
					
					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive										<= SATA_PRIMITIVE_ALIGN;
						
						CASE RX_Primitive IS
							WHEN SATA_PRIMITIVE_ALIGN =>					NULL;
							WHEN SATA_PRIMITIVE_SYNC =>
								RXFSM_IDLE										<= '1';
								RXFSM_Receiving								<= '0';
								RXFSM_NextState								<= ST_RXFSM_IDLE;
							WHEN SATA_PRIMITIVE_SOF =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_EOF =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_HOLD =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_HOLD_ACK =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_CONT =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_OK =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_ERROR =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_IP =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_RX_RDY =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_TX_RDY =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_DMA_TERM =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_WAIT_TERM =>		NULL;
							WHEN SATA_PRIMITIVE_PM_ACK =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_NACK =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_REQ_P =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_REQ_S =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_ILLEGAL =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_DIAL_TONE =>		RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_NONE =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
						END CASE;
					ELSE	-- InsertAlign
						RXFSM_Primitive										<= SATA_PRIMITIVE_R_ERROR;
						
						CASE RX_Primitive IS
							WHEN SATA_PRIMITIVE_ALIGN =>					NULL;
							WHEN SATA_PRIMITIVE_SYNC =>
								RXFSM_IDLE										<= '1';
								RXFSM_Receiving								<= '0';
								RXFSM_NextState								<= ST_RXFSM_IDLE;
							WHEN SATA_PRIMITIVE_SOF =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_EOF =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_HOLD =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_HOLD_ACK =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_CONT =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_OK =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_ERROR =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_R_IP =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_RX_RDY =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_TX_RDY =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_DMA_TERM =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_WAIT_TERM =>		NULL;
							WHEN SATA_PRIMITIVE_PM_ACK =>				RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_NACK =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_REQ_P =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_PM_REQ_S =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_ILLEGAL =>			RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_DIAL_TONE =>		RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
							WHEN SATA_PRIMITIVE_NONE =>					RXFSM_Error		<= '1'; RXFSM_NextState		<= ST_RXFSM_FSM_ERROR;
						END CASE;
					END IF;

				WHEN ST_RXFSM_RXFIFO_FULL =>
					RXFSM_Receiving								<= '1';
					
					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
						
						IF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN
							RXFSM_NextState						<= ST_RXFSM_IDLE;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) OR
									 (RX_Primitive = SATA_PRIMITIVE_HOLD) OR
									 (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
									 (RX_Primitive = SATA_PRIMITIVE_NONE))
						THEN
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_EOF) THEN
							RX_FSFIFO_put							<= '1';
							RXFSM_NextState						<= ST_RXFSM_SEND_R_ERROR;
						ELSE
							RXFSM_Error								<= '1';
							RXFSM_NextState						<= ST_RXFSM_FSM_ERROR;
						END IF;
							
					ELSE		-- InsertALIGN
						RXFSM_Primitive							<= SATA_PRIMITIVE_R_IP;
						
						IF (RX_Primitive = SATA_PRIMITIVE_SYNC) THEN
							RXFSM_NextState						<= ST_RXFSM_IDLE;
						ELSIF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) OR
									 (RX_Primitive = SATA_PRIMITIVE_HOLD) OR
									 (RX_Primitive = SATA_PRIMITIVE_HOLD_ACK) OR
									 (RX_Primitive = SATA_PRIMITIVE_NONE))
						THEN
							NULL;
						ELSIF (RX_Primitive = SATA_PRIMITIVE_EOF) THEN
							RXFSM_Primitive						<= SATA_PRIMITIVE_R_ERROR;
							RX_FSFIFO_put							<= '1';
							RXFSM_NextState						<= ST_RXFSM_IDLE;
						ELSE
							RXFSM_Error								<= '1';
							RXFSM_NextState						<= ST_RXFSM_FSM_ERROR;
						END IF;
					END IF;
				
				WHEN ST_RXFSM_SEND_DMA_TERM =>
					RXFSM_Receiving								<= '1';
					
					IF (InsertALIGN = '1') THEN
						RXFSM_Primitive							<= SATA_PRIMITIVE_ALIGN;
					ELSE
						RXFSM_Primitive							<= SATA_PRIMITIVE_DMA_TERM;
						RX_FSFIFO_put								<= '1';
						RXFSM_NextState							<= ST_RXFSM_RXFIFO_FULL;
					END IF;
				
				WHEN ST_RXFSM_FSM_ERROR =>
					RXFSM_Primitive								<= SATA_PRIMITIVE_SYNC;
					RXFSM_IDLE										<= '1';
					RXFSM_Error										<= '0';		-- '1';
					
					RXFSM_NextState								<= ST_RXFSM_IDLE;

			END CASE;
		END IF;
	END PROCESS;
	
-- PrimitiveFSMMux
	TX_Primitive	<= TXFSM_Primitive WHEN (RXFSM_Receiving = '0') ELSE RXFSM_Primitive;
	
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
	RXFSM_IsData_d		<= RXFSM_IsData WHEN rising_edge(Clock);
	RXFSM_IsData_re		<= NOT RXFSM_IsData_d AND RXFSM_IsData;
	
	RX_DataReg_en1_i	<= RXFSM_IsData;
	RX_DataReg_en2_i	<= (RX_DataReg_en1_d AND RXFSM_IsData) OR (RXFSM_IsData_re AND NOT RX_SOF_r);

	RX_DataReg_en1		<= RX_DataReg_en1_i;
	RX_DataReg_en2		<= RX_DataReg_en2_i;

	RX_DataReg_en1_d	<= RX_DataReg_en1_i WHEN rising_edge(Clock);
	RX_DataReg_en2_d	<= RX_DataReg_en2_i WHEN rising_edge(Clock);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (RX_DataReg_en1_i = '1') THEN
				RX_SOFReg_d1		<= RX_SOF_r;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (RX_DataReg_en2_i = '1') THEN
				RX_SOFReg_d2		<= RX_SOFReg_d1;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (RXFSM_IsSOF = '1') THEN
				RX_DataReg_Valid1			<= '0';
			ELSE
				IF (RX_DataReg_en1_i = '1') THEN
					RX_DataReg_Valid1		<= RXFSM_IsData;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (RXFSM_IsSOF = '1') THEN
				RX_DataReg_Valid2			<= '0';
			ELSE
				IF (RX_DataReg_en2_i = '1') THEN
					RX_DataReg_Valid2		<= RX_DataReg_Valid1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	RX_FIFO_put				<= ((RX_DataReg_en2_d AND RXFSM_IsData) OR (RXFSM_IsData_re AND NOT RX_SOF_r) OR RXFSM_IsEOF) AND RX_DataReg_Valid2;
	
	Trans_RX_SOF			<= RX_SOFReg_d2;
	Trans_RX_EOF			<= RXFSM_IsEOF;

	-- debug port
	-- ===========================================================================
	genDebugPort : if (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_EncodeTXState(st : T_TXFSM_STATE) return STD_LOGIC_VECTOR is
		begin
			return to_slv(T_TXFSM_STATE'pos(st), log2ceilnz(T_TXFSM_STATE'pos(T_TXFSM_STATE'high) + 1));
		end function;
		
		function dbg_EncodeRXState(st : T_RXFSM_STATE) return STD_LOGIC_VECTOR is
		begin
			return to_slv(T_RXFSM_STATE'pos(st), log2ceilnz(T_RXFSM_STATE'pos(T_RXFSM_STATE'high) + 1));
		end function;
		
	begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_GenerateTXEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_TXFSM_STATE loop
					STD.TextIO.write(l, str_replace(T_TXFSM_STATE'image(i), "st_txfsm_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			function dbg_GenerateRXEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_RXFSM_STATE loop
					STD.TextIO.write(l, str_replace(T_RXFSM_STATE'image(i), "st_rxfsm_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			constant dummy : T_BOOLVEC := (
				0 => dbg_ExportEncoding("Link Layer", dbg_GenerateTXEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/FSM_LinkLayer_TX.tok"),
				1 => dbg_ExportEncoding("Link Layer", dbg_GenerateRXEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/FSM_LinkLayer_RX.tok")
			);
		begin
		end generate;
		
		DebugPortOut.TXFSM					<= dbg_EncodeTXState(TXFSM_State);
		DebugPortOut.RXFSM					<= dbg_EncodeRXState(RXFSM_State);
	end generate;
end;
