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


ENTITY ICMPv4_Wrapper IS
	GENERIC (
		DEBUG																: BOOLEAN								:= FALSE;
		SOURCE_IPV4ADDRESS									: T_NET_IPV4_ADDRESS		:= C_NET_IPV4_ADDRESS_EMPTY
	);
	PORT (
		Clock																: IN	STD_LOGIC;
		Reset																: IN	STD_LOGIC;
		-- CSE interface
		Command															: IN	T_NET_ICMPV4_COMMAND;
		Status															: OUT	T_NET_ICMPV4_STATUS;
		Error																: OUT	T_NET_ICMPV4_ERROR;
		-- Echo-Request destination address
		IPv4Address_rst											: OUT	STD_LOGIC;
		IPv4Address_nxt											: OUT	STD_LOGIC;
		IPv4Address_Data										: IN	T_SLV_8;
		-- to IPv4 layer
		IP_TX_Valid													: OUT	STD_LOGIC;
		IP_TX_Data													: OUT	T_SLV_8;
		IP_TX_SOF														: OUT	STD_LOGIC;
		IP_TX_EOF														: OUT	STD_LOGIC;
		IP_TX_Ack														: IN	STD_LOGIC;
		IP_TX_Meta_rst											: IN	STD_LOGIC;
		IP_TX_Meta_SrcIPv4Address_nxt				: IN	STD_LOGIC;
		IP_TX_Meta_SrcIPv4Address_Data			: OUT	T_SLV_8;
		IP_TX_Meta_DestIPv4Address_nxt			: IN	STD_LOGIC;
		IP_TX_Meta_DestIPv4Address_Data			: OUT	T_SLV_8;
		IP_TX_Meta_Length										: OUT	T_SLV_16;
		-- from IPv4 layer
		IP_RX_Valid													: IN	STD_LOGIC;
		IP_RX_Data													: IN	T_SLV_8;
		IP_RX_SOF														: IN	STD_LOGIC;
		IP_RX_EOF														: IN	STD_LOGIC;
		IP_RX_Ack														: OUT	STD_LOGIC;
		IP_RX_Meta_rst											: OUT	STD_LOGIC;
		IP_RX_Meta_SrcMACAddress_nxt				: OUT	STD_LOGIC;
		IP_RX_Meta_SrcMACAddress_Data				: IN	T_SLV_8;
		IP_RX_Meta_DestMACAddress_nxt				: OUT	STD_LOGIC;
		IP_RX_Meta_DestMACAddress_Data			: IN	T_SLV_8;
--		IP_RX_Meta_EthType									: IN	T_SLV_16;
		IP_RX_Meta_SrcIPv4Address_nxt				: OUT	STD_LOGIC;
		IP_RX_Meta_SrcIPv4Address_Data			: IN	T_SLV_8;
		IP_RX_Meta_DestIPv4Address_nxt			: OUT	STD_LOGIC;
		IP_RX_Meta_DestIPv4Address_Data			: IN	T_SLV_8;
--		IP_RX_Meta_TrafficClass							: IN	T_SLV_8;
--		IP_RX_Meta_FlowLabel								: IN	T_SLV_24;
		IP_RX_Meta_Length										: IN	T_SLV_16
--		IP_RX_Meta_Protocol									: IN	T_SLV_8
	);
END;


ARCHITECTURE rtl OF ICMPv4_Wrapper IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_SEND_ECHO_REQUEST,
				ST_SEND_ECHO_REQUEST_WAIT,
				ST_WAIT_FOR_ECHO_REPLY,
				ST_EVAL_ECHO_REPLY,
			ST_SEND_ECHO_REPLY,
				ST_SEND_ECHO_REPLY_WAIT,
				ST_SEND_ECHO_REPLY_FINISHED,
		ST_ERROR
	);

	SIGNAL FSM_State										: T_STATE											:= ST_IDLE;
	SIGNAL FSM_NextState								: T_STATE;
	ATTRIBUTE FSM_ENCODING OF FSM_State	: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	SIGNAL FSM_TX_Command								: T_NET_ICMPV4_TX_COMMAND;
	SIGNAL TX_Status										: T_NET_ICMPV4_TX_STATUS;
	SIGNAL TX_Error											: T_NET_ICMPV4_TX_ERROR;

	SIGNAL FSM_RX_Command								: T_NET_ICMPV4_RX_COMMAND;
	SIGNAL RX_Status										: T_NET_ICMPV4_RX_STATUS;
	SIGNAL RX_Error											: T_NET_ICMPV4_RX_ERROR;
	
	SIGNAL TX_Meta_rst									: STD_LOGIC;
	SIGNAL TX_Meta_IPv4Address_nxt			: STD_LOGIC;
	SIGNAL FSM_TX_Meta_IPv4Address_Data	: T_SLV_8;
	SIGNAL FSM_TX_Meta_Type							: T_SLV_8;
	SIGNAL FSM_TX_Meta_Code							: T_SLV_8;
	SIGNAL FSM_TX_Meta_Identification		: T_SLV_16;
	SIGNAL FSM_TX_Meta_SequenceNumber		: T_SLV_16;
	SIGNAL TX_Meta_Payload_nxt					: STD_LOGIC;
	SIGNAL FSM_TX_Meta_Payload_last			: STD_LOGIC;
	SIGNAL FSM_TX_Meta_Payload_Data			: T_SLV_8;
	
	SIGNAL RX_Meta_rst											: STD_LOGIC;
	SIGNAL FSM_RX_Meta_rst									: STD_LOGIC;
	SIGNAL FSM_RX_Meta_SrcMACAddress_nxt		: STD_LOGIC;
	SIGNAL RX_Meta_SrcMACAddress_Data				: T_SLV_8;
	SIGNAL FSM_RX_Meta_DestMACAddress_nxt		: STD_LOGIC;
	SIGNAL RX_Meta_DestMACAddress_Data			: T_SLV_8;
	SIGNAL FSM_RX_Meta_SrcIPv4Address_nxt		: STD_LOGIC;
	SIGNAL RX_Meta_SrcIPv4Address_Data			: T_SLV_8;
	SIGNAL FSM_RX_Meta_DestIPv4Address_nxt	: STD_LOGIC;
	SIGNAL RX_Meta_DestIPv4Address_Data			: T_SLV_8;
	SIGNAL RX_Meta_Length										: T_SLV_16;
	SIGNAL RX_Meta_Type											: T_SLV_8;
	SIGNAL RX_Meta_Code											: T_SLV_8;
	SIGNAL RX_Meta_Identification						: T_SLV_16;
	SIGNAL RX_Meta_SequenceNumber						: T_SLV_16;
	SIGNAL FSM_RX_Meta_Payload_nxt					: STD_LOGIC;
	SIGNAL RX_Meta_Payload_last							: STD_LOGIC;
	SIGNAL RX_Meta_Payload_Data							: T_SLV_8;
	
BEGIN
-- ============================================================================================================================================================
-- ICMPv4 FSM
-- ============================================================================================================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				FSM_State			<= ST_IDLE;
			ELSE
				FSM_State			<= FSM_NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(FSM_State,
					Command,
					TX_Status, TX_Error, TX_Meta_Payload_nxt,
					RX_Status, RX_Error, RX_Meta_Identification, RX_Meta_SequenceNumber, RX_Meta_Payload_Data, RX_Meta_Payload_last)
	BEGIN
		FSM_NextState											<= FSM_State;
		
		Status														<= NET_ICMPV4_STATUS_IDLE;
		Error															<= NET_ICMPV4_ERROR_NONE;
		
		FSM_TX_Command										<= NET_ICMPV4_TX_CMD_NONE;
		FSM_RX_Command										<= NET_ICMPV4_RX_CMD_NONE;
		
		FSM_TX_Meta_Type									<= C_NET_ICMPV4_TYPE_EMPTY;
		FSM_TX_Meta_Code									<= C_NET_ICMPV4_CODE_EMPTY;
		FSM_TX_Meta_Identification				<= x"0000";
		FSM_TX_Meta_SequenceNumber				<= x"0000";
		FSM_TX_Meta_Payload_last					<= RX_Meta_Payload_last;
		FSM_TX_Meta_Payload_Data					<= RX_Meta_Payload_Data;

		FSM_RX_Meta_rst										<= '0';
		FSM_RX_Meta_SrcMACAddress_nxt			<= '0';
		FSM_RX_Meta_DestMACAddress_nxt		<= '0';
		FSM_RX_Meta_SrcIPv4Address_nxt		<= '0';
		FSM_RX_Meta_DestIPv4Address_nxt		<= '0';
		FSM_RX_Meta_Payload_nxt						<= '0';
		
		CASE FSM_State IS
			WHEN ST_IDLE =>
				CASE Command IS
					WHEN NET_ICMPV4_CMD_NONE =>													NULL;
					WHEN NET_ICMPV4_CMD_ECHO_REQUEST =>									FSM_NextState		<= ST_SEND_ECHO_REQUEST;
					WHEN OTHERS =>																			FSM_NextState		<= ST_ERROR;
				END CASE;
				
				CASE RX_Status IS
					WHEN NET_ICMPV4_RX_STATUS_IDLE =>										NULL;
					WHEN NET_ICMPV4_RX_STATUS_RECEIVED_ECHO_REQUEST =>	FSM_NextState		<= ST_SEND_ECHO_REPLY;
					WHEN OTHERS =>																			FSM_NextState		<= ST_ERROR;
				END CASE;
			
			-- ======================================================================
			WHEN ST_SEND_ECHO_REQUEST =>
				FSM_TX_Command								<= NET_ICMPV4_TX_CMD_ECHO_REQUEST;

				IPv4Address_rst								<= TX_Meta_rst;
				IPv4Address_nxt								<= TX_Meta_IPv4Address_nxt;
				
				FSM_TX_Meta_IPv4Address_Data	<= IPv4Address_Data;
				FSM_TX_Meta_Type							<= C_NET_ICMPV4_TYPE_ECHO_REQUEST;
				FSM_TX_Meta_Code							<= C_NET_ICMPV4_CODE_ECHO_REQUEST;
				FSM_TX_Meta_Identification		<= x"C0FE";
				FSM_TX_Meta_SequenceNumber		<= x"BEAF";
				
				FSM_NextState									<= ST_SEND_ECHO_REQUEST_WAIT;
			
			WHEN ST_SEND_ECHO_REQUEST_WAIT =>
				IPv4Address_rst								<= TX_Meta_rst;
				IPv4Address_nxt								<= TX_Meta_IPv4Address_nxt;
				
				FSM_TX_Meta_IPv4Address_Data	<= IPv4Address_Data;
				FSM_TX_Meta_Type							<= C_NET_ICMPV4_TYPE_ECHO_REQUEST;
				FSM_TX_Meta_Code							<= C_NET_ICMPV4_CODE_ECHO_REQUEST;
				FSM_TX_Meta_Identification		<= x"C0FE";
				FSM_TX_Meta_SequenceNumber		<= x"BEAF";
			
				CASE TX_Status IS
					WHEN NET_ICMPV4_TX_STATUS_IDLE =>										NULL;
					WHEN NET_ICMPV4_TX_STATUS_SENDING =>								NULL;
					WHEN NET_ICMPV4_TX_STATUS_SEND_COMPLETE =>					FSM_NextState		<= ST_WAIT_FOR_ECHO_REPLY;
					WHEN NET_ICMPV4_TX_STATUS_ERROR =>									FSM_NextState		<= ST_ERROR;
					WHEN OTHERS =>																			FSM_NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_WAIT_FOR_ECHO_REPLY =>
				CASE RX_Status IS
					WHEN NET_ICMPV4_RX_STATUS_IDLE =>										NULL;
					WHEN NET_ICMPV4_RX_STATUS_RECEIVING =>							NULL;
					WHEN NET_ICMPV4_RX_STATUS_RECEIVED_ECHO_REPLY =>		FSM_NextState		<= ST_EVAL_ECHO_REPLY;
					WHEN NET_ICMPV4_RX_STATUS_ERROR =>									FSM_NextState		<= ST_ERROR;
					WHEN OTHERS =>																			FSM_NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_EVAL_ECHO_REPLY =>
			
				IF (TRUE) THEN
					FSM_NextState								<= ST_IDLE;
				ELSE
					FSM_NextState								<= ST_ERROR;
				END IF;

			-- ======================================================================
			WHEN ST_SEND_ECHO_REPLY =>
				FSM_TX_Command								<= NET_ICMPV4_TX_CMD_ECHO_REPLY;

				FSM_RX_Meta_rst									<= TX_Meta_rst;
				FSM_RX_Meta_SrcIPv4Address_nxt	<= TX_Meta_IPv4Address_nxt;
				
				FSM_TX_Meta_IPv4Address_Data		<= RX_Meta_SrcIPv4Address_Data;
				FSM_TX_Meta_Type								<= C_NET_ICMPV4_TYPE_ECHO_REPLY;
				FSM_TX_Meta_Code								<= C_NET_ICMPV4_CODE_ECHO_REPLY;
				FSM_TX_Meta_Identification			<= RX_Meta_Identification;
				FSM_TX_Meta_SequenceNumber			<= RX_Meta_SequenceNumber;
				FSM_RX_Meta_Payload_nxt					<= TX_Meta_Payload_nxt;
				
				FSM_NextState										<= ST_SEND_ECHO_REPLY;

			WHEN ST_SEND_ECHO_REPLY_WAIT =>
				FSM_RX_Meta_rst									<= TX_Meta_rst;
				FSM_RX_Meta_SrcIPv4Address_nxt	<= TX_Meta_IPv4Address_nxt;
				
				FSM_TX_Meta_IPv4Address_Data		<= RX_Meta_SrcIPv4Address_Data;
				FSM_TX_Meta_Type								<= C_NET_ICMPV4_TYPE_ECHO_REPLY;
				FSM_TX_Meta_Code								<= C_NET_ICMPV4_CODE_ECHO_REPLY;
				FSM_TX_Meta_Identification			<= RX_Meta_Identification;
				FSM_TX_Meta_SequenceNumber			<= RX_Meta_SequenceNumber;
				
				CASE TX_Status IS
					WHEN NET_ICMPV4_TX_STATUS_IDLE =>						NULL;
					WHEN NET_ICMPV4_TX_STATUS_SENDING =>				NULL;
					WHEN NET_ICMPV4_TX_STATUS_SEND_COMPLETE =>	FSM_NextState		<= ST_SEND_ECHO_REPLY_FINISHED;
					WHEN NET_ICMPV4_TX_STATUS_ERROR =>					FSM_NextState		<= ST_ERROR;
					WHEN OTHERS =>															FSM_NextState		<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_ECHO_REPLY_FINISHED =>
				Status												<= NET_ICMPV4_STATUS_IDLE;
				
				FSM_RX_Command								<= NET_ICMPV4_RX_CMD_CLEAR;
				
				FSM_NextState									<= ST_IDLE;
			
			-- ======================================================================
			WHEN ST_ERROR =>
				Status												<= NET_ICMPV4_STATUS_ERROR;
				Error													<= NET_ICMPV4_ERROR_FSM;
				FSM_NextState									<= ST_IDLE;
			
		END CASE;
	END PROCESS;

-- ============================================================================================================================================================
-- TX Path
-- ============================================================================================================================================================
	TX : ENTITY PoC.ICMPv4_TX
		GENERIC MAP (
			DEBUG								=> DEBUG,
			SOURCE_IPV4ADDRESS						=> SOURCE_IPV4ADDRESS
		)
		PORT MAP (
			Clock													=> Clock,	
			Reset													=> Reset,
			
			Command												=> FSM_TX_Command,
			Status												=> TX_Status,
			Error													=> TX_Error,
			
			Out_Valid											=> IP_TX_Valid,
			Out_Data											=> IP_TX_Data,
			Out_SOF												=> IP_TX_SOF,
			Out_EOF												=> IP_TX_EOF,
			Out_Ack												=> IP_TX_Ack,
			Out_Meta_rst									=> IP_TX_Meta_rst,
			Out_Meta_SrcIPv4Address_nxt		=> IP_TX_Meta_SrcIPv4Address_nxt,
			Out_Meta_SrcIPv4Address_Data	=> IP_TX_Meta_SrcIPv4Address_Data,
			Out_Meta_DestIPv4Address_nxt	=> IP_TX_Meta_DestIPv4Address_nxt,
			Out_Meta_DestIPv4Address_Data	=> IP_TX_Meta_DestIPv4Address_Data,
			Out_Meta_Length								=> IP_TX_Meta_Length,
			
			In_Meta_rst										=> TX_Meta_rst,
			In_Meta_IPv4Address_nxt				=> TX_Meta_IPv4Address_nxt,
			In_Meta_IPv4Address_Data			=> FSM_TX_Meta_IPv4Address_Data,
			In_Meta_Type									=> FSM_TX_Meta_Type,
			In_Meta_Code									=> FSM_TX_Meta_Code,
			In_Meta_Identification				=> FSM_TX_Meta_Identification,
			In_Meta_SequenceNumber				=> FSM_TX_Meta_SequenceNumber,
			In_Meta_Payload_nxt						=> TX_Meta_Payload_nxt,
			In_Meta_Payload_last					=> FSM_TX_Meta_Payload_last,
			In_Meta_Payload_Data					=> FSM_TX_Meta_Payload_Data
    );
	
-- ============================================================================================================================================================
-- RX Path
-- ============================================================================================================================================================
	RX : ENTITY PoC.ICMPv4_RX
		GENERIC MAP (
			DEBUG								=> DEBUG
		)
		PORT MAP (
			Clock													=> Clock,	
			Reset													=> Reset,
			
			Command												=> FSM_RX_Command,
			Status												=> RX_Status,
			Error													=> RX_Error,
			
			In_Valid											=> IP_RX_Valid,
			In_Data												=> IP_RX_Data,
			In_SOF												=> IP_RX_SOF,
			In_EOF												=> IP_RX_EOF,
			In_Ack												=> IP_RX_Ack,
			In_Meta_rst										=> IP_RX_Meta_rst,
			In_Meta_SrcMACAddress_nxt			=> IP_RX_Meta_SrcMACAddress_nxt,
			In_Meta_SrcMACAddress_Data		=> IP_RX_Meta_SrcMACAddress_Data,
			In_Meta_DestMACAddress_nxt		=> IP_RX_Meta_DestMACAddress_nxt,
			In_Meta_DestMACAddress_Data		=> IP_RX_Meta_DestMACAddress_Data,
			In_Meta_SrcIPv4Address_nxt		=> IP_RX_Meta_SrcIPv4Address_nxt,
			In_Meta_SrcIPv4Address_Data		=> IP_RX_Meta_SrcIPv4Address_Data,
			In_Meta_DestIPv4Address_nxt		=> IP_RX_Meta_DestIPv4Address_nxt,
			In_Meta_DestIPv4Address_Data	=> IP_RX_Meta_DestIPv4Address_Data,
			In_Meta_Length								=> IP_RX_Meta_Length,
			
			Out_Meta_rst									=> FSM_RX_Meta_rst,
			Out_Meta_SrcMACAddress_nxt		=> FSM_RX_Meta_SrcMACAddress_nxt,
			Out_Meta_SrcMACAddress_Data		=> RX_Meta_SrcMACAddress_Data,
			Out_Meta_DestMACAddress_nxt		=> FSM_RX_Meta_DestMACAddress_nxt,
			Out_Meta_DestMACAddress_Data	=> RX_Meta_DestMACAddress_Data,
			Out_Meta_SrcIPv4Address_nxt		=> FSM_RX_Meta_SrcIPv4Address_nxt,
			Out_Meta_SrcIPv4Address_Data	=> RX_Meta_SrcIPv4Address_Data,
			Out_Meta_DestIPv4Address_nxt	=> FSM_RX_Meta_DestIPv4Address_nxt,
			Out_Meta_DestIPv4Address_Data	=> RX_Meta_DestIPv4Address_Data,
			Out_Meta_Length								=> RX_Meta_Length,
			Out_Meta_Type									=> RX_Meta_Type,
			Out_Meta_Code									=> RX_Meta_Code,
			Out_Meta_Identification				=> RX_Meta_Identification,
			Out_Meta_SequenceNumber				=> RX_Meta_SequenceNumber,
			Out_Meta_Payload_nxt					=> FSM_RX_Meta_Payload_nxt,
			Out_Meta_Payload_last					=> RX_Meta_Payload_last,
			Out_Meta_Payload_Data					=> RX_Meta_Payload_Data
		);
END ARCHITECTURE;
