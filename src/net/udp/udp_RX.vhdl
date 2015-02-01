-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
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
-- ============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY UDP_RX IS
	GENERIC (
		DEBUG														: BOOLEAN													:= FALSE;
		IP_VERSION											: POSITIVE												:= 6
	);
	PORT (
		Clock														: IN	STD_LOGIC;																	-- 
		Reset														: IN	STD_LOGIC;																	-- 
		-- STATUS port
		Error														: OUT	STD_LOGIC;
		-- IN port
		In_Valid												: IN	STD_LOGIC;
		In_Data													: IN	T_SLV_8;
		In_SOF													: IN	STD_LOGIC;
		In_EOF													: IN	STD_LOGIC;
		In_Ack													: OUT	STD_LOGIC;
		In_Meta_rst											: OUT	STD_LOGIC;
		In_Meta_SrcMACAddress_nxt				: OUT	STD_LOGIC;
		In_Meta_SrcMACAddress_Data			: IN	T_SLV_8;
		In_Meta_DestMACAddress_nxt			: OUT	STD_LOGIC;
		In_Meta_DestMACAddress_Data			: IN	T_SLV_8;
		In_Meta_EthType									: IN	T_SLV_16;
		In_Meta_SrcIPAddress_nxt				: OUT	STD_LOGIC;
		In_Meta_SrcIPAddress_Data				: IN	T_SLV_8;
		In_Meta_DestIPAddress_nxt				: OUT	STD_LOGIC;
		In_Meta_DestIPAddress_Data			: IN	T_SLV_8;
--		In_Meta_TrafficClass						: IN	T_SLV_8;
--		In_Meta_FlowLabel								: IN	T_SLV_24;
		In_Meta_Length									: IN	T_SLV_16;
		In_Meta_Protocol								: IN	T_SLV_8;
		-- OUT port
		Out_Valid												: OUT	STD_LOGIC;
		Out_Data												: OUT	T_SLV_8;
		Out_SOF													: OUT	STD_LOGIC;
		Out_EOF													: OUT	STD_LOGIC;
		Out_Ack													: IN	STD_LOGIC;
		Out_Meta_rst										: IN	STD_LOGIC;
		Out_Meta_SrcMACAddress_nxt			: IN	STD_LOGIC;
		Out_Meta_SrcMACAddress_Data			: OUT	T_SLV_8;
		Out_Meta_DestMACAddress_nxt			: IN	STD_LOGIC;
		Out_Meta_DestMACAddress_Data		: OUT	T_SLV_8;
		Out_Meta_EthType								: OUT	T_SLV_16;
		Out_Meta_SrcIPAddress_nxt				: IN	STD_LOGIC;
		Out_Meta_SrcIPAddress_Data			: OUT	T_SLV_8;
		Out_Meta_DestIPAddress_nxt			: IN	STD_LOGIC;
		Out_Meta_DestIPAddress_Data			: OUT	T_SLV_8;
--		Out_Meta_TrafficClass						: OUT	T_SLV_8;
--		Out_Meta_FlowLabel							: OUT	T_SLV_24;
		Out_Meta_Length									: OUT	T_SLV_16;
		Out_Meta_Protocol								: OUT	T_SLV_8;
		Out_Meta_SrcPort								: OUT	T_SLV_16;
		Out_Meta_DestPort								: OUT	T_SLV_16
	);
END;


-- Endianess: big-endian
-- Alignment: 1 byte
--
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+================================+================================+================================+================================+
--	| SourcePort 							 																				| DestinationPort																									|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| PayloadLength																										| Checksum																												|
--	+================================+================================+================================+================================+
--	| Payload																																																														|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+================================+================================+================================+================================+


-- UDP pseudo header for IPv4
-- 
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+================================+================================+================================+================================+
--	| SourceAddress 							 																																																			|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| DestinationAddress																																																								|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| 0x00 							 						 | Protocol												| Length																													|
--	+================================+================================+================================+================================+
--	| UDP header (see above)																																																						|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+================================+================================+================================+================================+
--	| Payload																																																														|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+================================+================================+================================+================================+


-- UDP pseudo header for IPv6
-- 
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+================================+================================+================================+================================+
--	| SourceAddress 							 																																																			|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| DestinationAddress																																																								|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| Length																																																														|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| 0x000000																																												 | NextHeader											|
--	+================================+================================+================================+================================+
--	| UDP header (see above)																																																						|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+================================+================================+================================+================================+
--	| Payload																																																														|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+================================+================================+================================+================================+


ARCHITECTURE rtl OF UDP_RX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_RECEIVE_SOURCE_PORT_1,
			ST_RECEIVE_DEST_PORT_0,		ST_RECEIVE_DEST_PORT_1,
			ST_RECEIVE_LENGTH_0,			ST_RECEIVE_LENGTH_1,
			ST_RECEIVE_CHECKSUM_0,		ST_RECEIVE_CHECKSUM_1,
			ST_RECEIVE_DATA_1,				ST_RECEIVE_DATA_N,
		ST_DISCARD_FRAME,
		ST_ERROR
	);

	SIGNAL State													: T_STATE											:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State				: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL In_Ack_i											: STD_LOGIC;
	SIGNAL Is_DataFlow										: STD_LOGIC;
	SIGNAL Is_SOF													: STD_LOGIC;
	SIGNAL Is_EOF													: STD_LOGIC;

	SIGNAL Out_Valid_i										: STD_LOGIC;
	SIGNAL Out_SOF_i											: STD_LOGIC;
	SIGNAL Out_EOF_i											: STD_LOGIC;

	SIGNAL Register_rst										: STD_LOGIC;
	
	-- UDP header fields
	SIGNAL SourcePort_en0									: STD_LOGIC;
	SIGNAL SourcePort_en1									: STD_LOGIC;
	SIGNAL DestinationPort_en0						: STD_LOGIC;
	SIGNAL DestinationPort_en1						: STD_LOGIC;
	SIGNAL Length_en0											: STD_LOGIC;
	SIGNAL Length_en1											: STD_LOGIC;
	
	SIGNAL SourcePort_d										: T_SLV_16										:= (OTHERS => '0');
	SIGNAL DestinationPort_d							: T_SLV_16										:= (OTHERS => '0');
	SIGNAL Length_d												: T_SLV_16										:= (OTHERS => '0');
	
BEGIN

	In_Ack				<= In_Ack_i;
	Is_DataFlow		<= In_Valid AND In_Ack_i;
	Is_SOF				<= In_Valid AND In_SOF;
	Is_EOF				<= In_Valid AND In_EOF;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_IDLE;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Is_DataFlow, Is_SOF, Is_EOF, In_Valid, In_Data, In_EOF, Out_Ack)
	BEGIN
		NextState											<= State;
		
		Error													<= '0';

		In_Ack_i										<= '0';
		Out_Valid_i										<= '0';
		Out_SOF_i											<= '0';
		Out_EOF_i											<= '0';
		
		-- UDP header fields
		Register_rst									<= '0';
		SourcePort_en0								<= '0';
		SourcePort_en1								<= '0';
		DestinationPort_en0						<= '0';
		DestinationPort_en1						<= '0';
		Length_en0										<= '0';
		Length_en1										<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				IF (Is_SOF = '1') THEN
					In_Ack_i							<= '1';
				
					IF (Is_EOF = '0') THEN
						SourcePort_en0				<= '1';
						NextState							<= ST_RECEIVE_SOURCE_PORT_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_SOURCE_PORT_1 =>
				IF (In_Valid = '1') THEN
					In_Ack_i							<= '1';
				
					IF (Is_EOF = '0') THEN
						SourcePort_en1				<= '1';
						NextState							<= ST_RECEIVE_DEST_PORT_0;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_DEST_PORT_0 =>
				IF (In_Valid = '1') THEN
					In_Ack_i							<= '1';
				
					IF (Is_EOF = '0') THEN
						DestinationPort_en0		<= '1';
						NextState							<= ST_RECEIVE_DEST_PORT_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_DEST_PORT_1 =>
				IF (In_Valid = '1') THEN
					In_Ack_i							<= '1';
				
					IF (Is_EOF = '0') THEN
						DestinationPort_en1		<= '1';
						NextState							<= ST_RECEIVE_LENGTH_0;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;

			WHEN ST_RECEIVE_LENGTH_0 =>
				IF (In_Valid = '1') THEN
					In_Ack_i							<= '1';
				
					IF (Is_EOF = '0') THEN
						Length_en0						<= '1';
						NextState							<= ST_RECEIVE_LENGTH_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_LENGTH_1 =>
				IF (In_Valid = '1') THEN
					In_Ack_i							<= '1';
				
					IF (Is_EOF = '0') THEN
						Length_en1						<= '1';
						NextState							<= ST_RECEIVE_CHECKSUM_0;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_CHECKSUM_0 =>
				IF (In_Valid = '1') THEN
					In_Ack_i							<= '1';
				
					IF (Is_EOF = '0') THEN
						NextState							<= ST_RECEIVE_CHECKSUM_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_CHECKSUM_1 =>
				IF (In_Valid = '1') THEN
					In_Ack_i							<= '1';
				
					IF (Is_EOF = '0') THEN
						NextState							<= ST_RECEIVE_DATA_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_DATA_1 =>
				In_Ack_i								<= Out_Ack;
				Out_Valid_i								<= In_Valid;
				Out_SOF_i									<= '1';
				Out_EOF_i									<= In_EOF;
			
				IF (Is_DataFlow = '1') THEN
					IF (Is_EOF = '0') THEN
						NextState							<= ST_RECEIVE_DATA_N;
					ELSE
						NextState							<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_DATA_N =>
				In_Ack_i								<= Out_Ack;
				Out_Valid_i								<= In_Valid;
				Out_EOF_i									<= In_EOF;
				
				IF (Is_EOF = '1') THEN
					NextState								<= ST_IDLE;
				END IF;
			
			-- TODO: if no checksum is set in IPv6 mode
			WHEN ST_DISCARD_FRAME =>
				In_Ack_i								<= '1';
				
				IF (Is_EOF = '1') THEN
					NextState								<= ST_ERROR;
				END IF;
			
			WHEN ST_ERROR =>
				Error											<= '1';
				NextState									<= ST_IDLE;
			
		END CASE;
	END PROCESS;
	
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Register_rst) = '1') THEN
				SourcePort_d												<= (OTHERS => '0');
				DestinationPort_d										<= (OTHERS => '0');
				Length_d														<= (OTHERS => '0');
			ELSE
				IF (SourcePort_en0 = '1') THEN
					SourcePort_d(7 DOWNTO 0)					<= In_Data;
				END IF;
				IF (SourcePort_en1 = '1') THEN
					SourcePort_d(15 DOWNTO 8)					<= In_Data;
				END IF;
				
				IF (DestinationPort_en0 = '1') THEN
					DestinationPort_d(7 DOWNTO 0)			<= In_Data;
				END IF;
				IF (DestinationPort_en1 = '1') THEN
					DestinationPort_d(15 DOWNTO 8)		<= In_Data;
				END IF;
				
				IF (Length_en0 = '1') THEN
					Length_d(7 DOWNTO 0)							<= In_Data;
				END IF;
				IF (Length_en1 = '1') THEN
					Length_d(15 DOWNTO 8)							<= In_Data;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	In_Meta_rst												<= Out_Meta_rst;
	In_Meta_SrcMACAddress_nxt					<= Out_Meta_SrcMACAddress_nxt;
	In_Meta_DestMACAddress_nxt				<= Out_Meta_DestMACAddress_nxt;
	In_Meta_SrcIPAddress_nxt					<= Out_Meta_SrcIPAddress_nxt;
	In_Meta_DestIPAddress_nxt					<= Out_Meta_DestIPAddress_nxt;

	Out_Valid													<= Out_Valid_i;
	Out_Data													<= In_Data;
	Out_SOF														<= Out_SOF_i;
	Out_EOF														<= Out_EOF_i;
	Out_Meta_SrcMACAddress_Data				<= In_Meta_SrcMACAddress_Data;
	Out_Meta_DestMACAddress_Data			<= In_Meta_DestMACAddress_Data;
	Out_Meta_EthType									<= In_Meta_EthType;
	Out_Meta_SrcIPAddress_Data				<= In_Meta_SrcIPAddress_Data;
	Out_Meta_DestIPAddress_Data				<= In_Meta_DestIPAddress_Data;
--	Out_Meta_TrafficClass							<= In_Meta_TrafficClass;
--	Out_Meta_FlowLabel								<= In_Meta_FlowLabel;
	Out_Meta_Length										<= Length_d;
	Out_Meta_Protocol									<= In_Meta_Protocol;
	Out_Meta_SrcPort									<= SourcePort_d;
	Out_Meta_DestPort									<= DestinationPort_d;
END;
