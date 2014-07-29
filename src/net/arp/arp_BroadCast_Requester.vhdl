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
-- ============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY ARP_BroadCast_Requester IS
	GENERIC (
		ALLOWED_PROTOCOL_IPV4					: BOOLEAN												:= TRUE;
		ALLOWED_PROTOCOL_IPV6					: BOOLEAN												:= FALSE
	);
	PORT (
		Clock													: IN	STD_LOGIC;																	-- 
		Reset													: IN	STD_LOGIC;																	-- 

		SendRequest										: IN	STD_LOGIC;
		Complete											: OUT	STD_LOGIC;
		
		Address_rst										: OUT	STD_LOGIC;
		SenderMACAddress_nxt					: OUT	STD_LOGIC;
		SenderMACAddress_Data					: IN	T_SLV_8;
		SenderIPv4Address_nxt					: OUT	STD_LOGIC;
		SenderIPv4Address_Data				: IN	T_SLV_8;
		TargetMACAddress_nxt					: OUT	STD_LOGIC;
		TargetMACAddress_Data					: IN	T_SLV_8;
		TargetIPv4Address_nxt					: OUT	STD_LOGIC;
		TargetIPv4Address_Data				: IN	T_SLV_8;
		
		TX_Valid											: OUT	STD_LOGIC;
		TX_Data												: OUT	T_SLV_8;
		TX_SOF												: OUT	STD_LOGIC;
		TX_EOF												: OUT	STD_LOGIC;
		TX_Ready											: IN	STD_LOGIC;
		TX_Meta_DestMACAddress_rst		: IN	STD_LOGIC;
		TX_Meta_DestMACAddress_nxt		: IN	STD_LOGIC;
		TX_Meta_DestMACAddress_Data		: OUT	T_SLV_8
	);
END;

-- Endianess: big-endian
-- Alignment: 1 byte
--
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| HardwareType (Ethernet = 0x0001)																| ProtocolType (IPv4 = 0x0800; IPv6 = 0x86DD)											|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| Hardware_Length (= 0x06)			 | Protocol_Length (= 0x04; 0x10) | Operation (Request = 0x0001)																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| SenderMACAddress																																																									|
--	+                                +                                +--------------------------------+--------------------------------+
--	|																																	| SenderIPAddress																									|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	|																																	| TargetMACAddress (= 00:00:00:00:00:00)													|
--	+--------------------------------+--------------------------------+                                +                                +
--	|																																																																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| TargetIPAddress																																																										|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+


ARCHITECTURE rtl OF ARP_BroadCast_Requester IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_SEND_HARDWARE_TYPE_0,	ST_SEND_HARDWARE_TYPE_1,
			ST_SEND_PROTOCOL_TYPE_0,	ST_SEND_PROTOCOL_TYPE_1,
			ST_SEND_HARDWARE_ADDRESS_LENGTH, ST_SEND_PROTOCOL_ADDRESS_LENGTH,
			ST_SEND_OPERATION_0,			ST_SEND_OPERATION_1,
			ST_SEND_SENDER_MAC,				ST_SEND_SENDER_IP,
			ST_SEND_TARGET_MAC,				ST_SEND_TARGET_IP,
		ST_COMPLETE
	);

	SIGNAL State													: T_STATE																												:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State				: SIGNAL IS "gray";

	CONSTANT HARDWARE_ADDRESS_LENGTH			: POSITIVE																											:= 6;			-- MAC -> 6 bytes
	CONSTANT PROTOCOL_IPV4_ADDRESS_LENGTH	: POSITIVE																											:= 4;			-- IPv4 -> 4 bytes
	CONSTANT PROTOCOL_IPV6_ADDRESS_LENGTH	: POSITIVE																											:= 16;		-- IPv6 -> 16 bytes
	CONSTANT PROTOCOL_ADDRESS_LENGTH			: POSITIVE																											:= ite((ALLOWED_PROTOCOL_IPV6 = FALSE), PROTOCOL_IPV4_ADDRESS_LENGTH, PROTOCOL_IPV6_ADDRESS_LENGTH);		-- IPv4 -> 4 bytes; IPv6 -> 16 bytes

	SIGNAL IsIPv4_l												: STD_LOGIC																											:= '1';
	SIGNAL IsIPv6_l												: STD_LOGIC																											:= '0';

	CONSTANT READER_COUNTER_BITS					: POSITIVE																											:= log2ceilnz(imax(HARDWARE_ADDRESS_LENGTH, PROTOCOL_ADDRESS_LENGTH));
	SIGNAL Reader_Counter_rst							: STD_LOGIC;
	SIGNAL Reader_Counter_en							: STD_LOGIC;
	SIGNAL Reader_Counter_us							: UNSIGNED(READER_COUNTER_BITS - 1 DOWNTO 0)										:= (OTHERS => '0');

BEGIN
	IsIPv4_l		<= '1';
	IsIPv6_l		<= '0';

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

	PROCESS(State,
					SendRequest,
					IsIPv4_l, IsIPv6_l,
					TX_Ready, TX_Meta_DestMACAddress_rst, TX_Meta_DestMACAddress_nxt,
					SenderMACAddress_Data, SenderIPv4Address_Data, TargetMACAddress_Data, TargetIPv4Address_Data,
					Reader_Counter_us)
	BEGIN
		NextState											<= State;
		
		Complete											<= '0';

		TX_Valid											<= '0';
		TX_Data												<= (OTHERS => '0');
		TX_SOF												<= '0';
		TX_EOF												<= '0';
		TX_Meta_DestMACAddress_Data		<= x"FF";
		
		Address_rst										<= '0';
		SenderMACAddress_nxt					<= '0';
		SenderIPv4Address_nxt					<= '0';
		TargetMACAddress_nxt					<= '0';
		TargetIPv4Address_nxt					<= '0';
		
		Reader_Counter_rst						<= '0';
		Reader_Counter_en							<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				IF (SendRequest = '1') THEN
					Address_rst							<= '1';
					NextState								<= ST_SEND_HARDWARE_TYPE_0;
				END IF;
			
			WHEN ST_SEND_HARDWARE_TYPE_0 =>
				TX_Valid									<= '1';
				TX_Data										<= x"00";
				TX_SOF										<= '1';
			
--				Address_rst								<= TX_Meta_DestMACAddress_rst;
--				TargetMACAddress_nxt			<= TX_Meta_DestMACAddress_nxt;
			
				IF (TX_Ready = '1') THEN
					NextState								<= ST_SEND_HARDWARE_TYPE_1;
				END IF;

			WHEN ST_SEND_HARDWARE_TYPE_1 =>
				TX_Valid									<= '1';
				TX_Data										<= x"01";
			
				IF (TX_Ready = '1') THEN
					NextState								<= ST_SEND_PROTOCOL_TYPE_0;
				END IF;

			WHEN ST_SEND_PROTOCOL_TYPE_0 =>
				TX_Valid									<= '1';
				
				IF (IsIPv4_l = '1') THEN
					TX_Data									<= x"08";
				ELSIF (IsIPv6_l = '1') THEN
					TX_Data									<= x"86";
				END IF;
			
				IF (TX_Ready = '1') THEN
					NextState								<= ST_SEND_PROTOCOL_TYPE_1;
				END IF;

			WHEN ST_SEND_PROTOCOL_TYPE_1 =>
				TX_Valid									<= '1';
				
				IF (IsIPv4_l = '1') THEN
					TX_Data									<= x"00";
				ELSIF (IsIPv6_l = '1') THEN
					TX_Data									<= x"DD";
				END IF;
			
				IF (TX_Ready = '1') THEN
					NextState								<= ST_SEND_HARDWARE_ADDRESS_LENGTH;
				END IF;

			WHEN ST_SEND_HARDWARE_ADDRESS_LENGTH =>
				TX_Valid									<= '1';
				TX_Data										<= x"06";
			
				IF (TX_Ready = '1') THEN
					NextState								<= ST_SEND_PROTOCOL_ADDRESS_LENGTH;
				END IF;

			WHEN ST_SEND_PROTOCOL_ADDRESS_LENGTH =>
				TX_Valid									<= '1';
				
				IF (IsIPv4_l = '1') THEN
					TX_Data									<= x"04";
				ELSIF (IsIPv6_l = '1') THEN
					TX_Data									<= x"10";
				END IF;
				
				IF (TX_Ready = '1') THEN
					NextState								<= ST_SEND_OPERATION_0;
				END IF;

			WHEN ST_SEND_OPERATION_0 =>
				TX_Valid									<= '1';
				TX_Data										<= x"00";
			
				IF (TX_Ready = '1') THEN
					NextState								<= ST_SEND_OPERATION_1;
				END IF;

			WHEN ST_SEND_OPERATION_1 =>
				TX_Valid									<= '1';
				TX_Data										<= x"01";
				
				Address_rst								<= '1';
			
				IF (TX_Ready = '1') THEN
					NextState								<= ST_SEND_SENDER_MAC;
				END IF;

			WHEN ST_SEND_SENDER_MAC =>
				TX_Valid									<= '1';
				TX_Data										<= SenderMACAddress_Data;
			
				IF (TX_Ready = '1') THEN
					SenderMACAddress_nxt		<= '1';
					Reader_Counter_en				<= '1';
					
					IF (Reader_Counter_us = (HARDWARE_ADDRESS_LENGTH - 1)) THEN
						Reader_Counter_rst		<= '1';	
						NextState							<= ST_SEND_SENDER_IP;
					END IF;
				END IF;
				
			WHEN ST_SEND_SENDER_IP =>
				TX_Valid									<= '1';
				TX_Data										<= SenderIPv4Address_Data;
			
				IF (TX_Ready = '1') THEN
					SenderIPv4Address_nxt		<= '1';
					Reader_Counter_en				<= '1';
					
					IF ((IsIPv4_l = '1') AND (Reader_Counter_us = (PROTOCOL_IPV4_ADDRESS_LENGTH - 1))) THEN
						Reader_Counter_rst		<= '1';	
						NextState							<= ST_SEND_TARGET_MAC;
					ELSIF ((IsIPv6_l = '1') AND (Reader_Counter_us = (PROTOCOL_IPV6_ADDRESS_LENGTH - 1))) THEN
						Reader_Counter_rst		<= '1';	
						NextState							<= ST_SEND_TARGET_MAC;
					END IF;
				END IF;
				
			WHEN ST_SEND_TARGET_MAC =>
				TX_Valid									<= '1';
				TX_Data										<= TargetMACAddress_Data;
			
				IF (TX_Ready = '1') THEN
					TargetMACAddress_nxt		<= '1';
					Reader_Counter_en				<= '1';
					
					IF (Reader_Counter_us = (HARDWARE_ADDRESS_LENGTH - 1)) THEN
						Reader_Counter_rst		<= '1';	
						NextState							<= ST_SEND_TARGET_IP;
					END IF;
				END IF;
				
			WHEN ST_SEND_TARGET_IP =>
				TX_Valid									<= '1';
				TX_Data										<= TargetIPv4Address_Data;
			
				IF (TX_Ready = '1') THEN
					TargetIPv4Address_nxt	<= '1';
					Reader_Counter_en				<= '1';
					
					IF ((IsIPv4_l = '1') AND (Reader_Counter_us = (PROTOCOL_IPV4_ADDRESS_LENGTH - 1))) THEN
						TX_EOF								<= '1';
						Reader_Counter_rst		<= '1';	
						NextState							<= ST_COMPLETE;
					ELSIF ((IsIPv6_l = '1') AND (Reader_Counter_us = (PROTOCOL_IPV6_ADDRESS_LENGTH - 1))) THEN
						TX_EOF								<= '1';
						Reader_Counter_rst		<= '1';	
						NextState							<= ST_COMPLETE;
					END IF;
				END IF;

			WHEN ST_COMPLETE =>
				Complete									<= '1';
				NextState									<= ST_IDLE;

		END CASE;
	END PROCESS;
	
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Reader_Counter_rst) = '1') THEN
				Reader_Counter_us					<= (OTHERS => '0');
			ELSE
				IF (Reader_Counter_en = '1') THEN
					Reader_Counter_us				<= Reader_Counter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END;
