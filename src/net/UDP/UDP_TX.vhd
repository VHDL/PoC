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


ENTITY UDP_TX IS
	GENERIC (
		DEBUG												: BOOLEAN									:= FALSE;
		IP_VERSION									: POSITIVE								:= 6
	);
	PORT (
		Clock												: IN	STD_LOGIC;									-- 
		Reset												: IN	STD_LOGIC;									-- 
		-- IN port
		In_Valid										: IN	STD_LOGIC;
		In_Data											: IN	T_SLV_8;
		In_SOF											: IN	STD_LOGIC;
		In_EOF											: IN	STD_LOGIC;
		In_Ready										: OUT	STD_LOGIC;
		In_Meta_rst									: OUT	STD_LOGIC;
		In_Meta_SrcIPAddress_nxt		: OUT	STD_LOGIC;
		In_Meta_SrcIPAddress_Data		: IN	T_SLV_8;
		In_Meta_DestIPAddress_nxt		: OUT	STD_LOGIC;
		In_Meta_DestIPAddress_Data	: IN	T_SLV_8;
		In_Meta_SrcPort							: IN	T_SLV_16;
		In_Meta_DestPort						: IN	T_SLV_16;
		In_Meta_Length							: IN	T_SLV_16;
		In_Meta_Checksum						: IN	T_SLV_16;
		-- OUT port
		Out_Valid										: OUT	STD_LOGIC;
		Out_Data										: OUT	T_SLV_8;
		Out_SOF											: OUT	STD_LOGIC;
		Out_EOF											: OUT	STD_LOGIC;
		Out_Ready										: IN	STD_LOGIC;
		Out_Meta_rst								: IN	STD_LOGIC;
		Out_Meta_SrcIPAddress_nxt		: IN	STD_LOGIC;
		Out_Meta_SrcIPAddress_Data	: OUT	T_SLV_8;
		Out_Meta_DestIPAddress_nxt	: IN	STD_LOGIC;
		Out_Meta_DestIPAddress_Data	: OUT	T_SLV_8;
		Out_Meta_Length							: OUT	T_SLV_16
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

ARCHITECTURE rtl OF UDP_TX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_CHECKSUMV4_IPV4_ADDRESSES,
				ST_CHECKSUMV4_LENGTH_UDP_TYPE_0,	ST_CHECKSUMV4_LENGTH_UDP_TYPE_1,
				ST_CHECKSUMV4_PORT_NUMBER_0,			ST_CHECKSUMV4_PORT_NUMBER_1,
				ST_CHECKSUMV4_CHECKSUM_LENGTH_0,	ST_CHECKSUMV4_CHECKSUM_LENGTH_1,
			ST_CHECKSUMV6_IPV6_ADDRESSES,
				ST_CHECKSUMV6_LENGTH_UDP_TYPE_0,	ST_CHECKSUMV6_LENGTH_UDP_TYPE_1,
				ST_CHECKSUMV6_PORT_NUMBER_0,			ST_CHECKSUMV6_PORT_NUMBER_1,
				ST_CHECKSUMV6_CHECKSUM_LENGTH_0,	ST_CHECKSUMV6_CHECKSUM_LENGTH_1,
			ST_CARRY_0,  ST_CARRY_1,
			ST_SEND_SOURCE_PORT_0,
			ST_SEND_SOURCE_PORT_1,
			ST_SEND_DEST_PORT_0,	ST_SEND_DEST_PORT_1,
			ST_SEND_LENGTH_0,			ST_SEND_LENGTH_1,
			ST_SEND_CHECKSUM_0,		ST_SEND_CHECKSUM_1,
			ST_SEND_DATA,
		ST_ERROR
	);

	SIGNAL State											: T_STATE											:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL In_Ready_i									: STD_LOGIC;

	SIGNAL UpperLayerPacketLength			: STD_LOGIC_VECTOR(15 DOWNTO 0);
	
	SIGNAL IPSeqCounter_rst						: STD_LOGIC;
	SIGNAL IPSeqCounter_en						: STD_LOGIC;
	SIGNAL IPSeqCounter_us						: UNSIGNED(3 DOWNTO 0)																	:= (OTHERS => '0');
	
	SIGNAL Checksum_rst								: STD_LOGIC;
	SIGNAL Checksum_en								: STD_LOGIC;
	SIGNAL Checksum_Addend0_us				: UNSIGNED(T_SLV_8'range);
	SIGNAL Checksum_Addend1_us				: UNSIGNED(T_SLV_8'range);
	SIGNAL Checksum0_nxt0_us					: UNSIGNED(T_SLV_8'high + 1 DOWNTO 0);
	SIGNAL Checksum0_nxt1_us					: UNSIGNED(T_SLV_8'high + 1 DOWNTO 0);
	SIGNAL Checksum0_d_us							: UNSIGNED(T_SLV_8'high DOWNTO 0)												:= (OTHERS => '0');
	SIGNAL Checksum0_cy								: UNSIGNED(T_SLV_2'range);
	SIGNAL Checksum1_nxt_us						: UNSIGNED(T_SLV_8'range);
	SIGNAL Checksum1_d_us							: UNSIGNED(T_SLV_8'range)																:= (OTHERS => '0');
	SIGNAL Checksum0_cy0							: STD_LOGIC;
	SIGNAL Checksum0_cy0_d						: STD_LOGIC																							:= '0';
	SIGNAL Checksum0_cy1							: STD_LOGIC;
	SIGNAL Checksum0_cy1_d						: STD_LOGIC																							:= '0';

	SIGNAL Checksum_i									: T_SLV_16;
	SIGNAL Checksum										: T_SLV_16;
	SIGNAL Checksum_mux_rst						: STD_LOGIC;
	SIGNAL Checksum_mux_set						: STD_LOGIC;
	SIGNAL Checksum_mux_r							: STD_LOGIC																							:= '0';

BEGIN
	ASSERT ((IP_VERSION = 6) OR (IP_VERSION = 4)) REPORT "Internet Protocol Version not supported." SEVERITY ERROR;

	UpperLayerPacketLength		<= std_logic_vector(unsigned(In_Meta_Length) + 8);
	
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
					In_Valid, In_SOF, In_EOF, In_Data,
					Out_Ready, Out_Meta_rst,
					Out_Meta_SrcIPAddress_nxt,	In_Meta_SrcIPAddress_Data,
					Out_Meta_DestIPAddress_nxt, In_Meta_DestIPAddress_Data,
					In_Meta_SrcPort, In_Meta_DestPort, In_Meta_Checksum,
					IPSeqCounter_us, Checksum0_cy, Checksum,
					UpperLayerPacketLength)
	BEGIN
		NextState										<= State;
		
		In_Ready_i									<= '0';
		
		Out_Valid										<= '0';
		Out_Data										<= In_Data;
		Out_SOF											<= '0';
		Out_EOF											<= '0';
		
		In_Meta_rst									<= '0';
		In_Meta_SrcIPAddress_nxt		<= Out_Meta_SrcIPAddress_nxt;
		In_Meta_DestIPAddress_nxt		<= Out_Meta_DestIPAddress_nxt;

		Out_Meta_SrcIPAddress_Data	<= In_Meta_SrcIPAddress_Data;
		Out_Meta_DestIPAddress_Data	<= In_Meta_DestIPAddress_Data;

		IPSeqCounter_rst						<= '0';
		IPSeqCounter_en							<= '0';
	
		Checksum_rst								<= '0';
		Checksum_en									<= '0';
		Checksum_Addend0_us					<= (OTHERS => '0');
		Checksum_Addend1_us					<= (OTHERS => '0');
		Checksum_mux_rst						<= '0';
		Checksum_mux_set						<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				In_Meta_rst							<= '1';
		
				IPSeqCounter_rst				<= '1';
				Checksum_rst						<= '1';

				IF ((In_Valid AND In_SOF) = '1') THEN
					IF (IP_VERSION = 4) THEN
						NextState			<= ST_CHECKSUMV4_IPV4_ADDRESSES;
					ELSIF (IP_VERSION = 6) THEN
						NextState			<= ST_CHECKSUMV6_IPV6_ADDRESSES;
					ELSE
						NextState			<= ST_ERROR;
					END IF;
				END IF;
			
			-- calculate checksum for IPv4 pseudo header
			-- ----------------------------------------------------------------------
			WHEN ST_CHECKSUMV4_IPV4_ADDRESSES =>
				In_Meta_SrcIPAddress_nxt	<= '1';
				In_Meta_DestIPAddress_nxt	<= '1';
				
				IPSeqCounter_en						<= '1';
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(In_Meta_SrcIPAddress_Data);
				Checksum_Addend1_us				<= unsigned(In_Meta_DestIPAddress_Data);
				
				IF (IPSeqCounter_us = 3) THEN
					NextState								<= ST_CHECKSUMV4_LENGTH_UDP_TYPE_0;
				END IF;
			
			WHEN ST_CHECKSUMV4_LENGTH_UDP_TYPE_0 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(UpperLayerPacketLength(15 DOWNTO 8));
				Checksum_Addend1_us				<= (OTHERS => '0');
				
				NextState									<= ST_CHECKSUMV4_LENGTH_UDP_TYPE_1;

			WHEN ST_CHECKSUMV4_LENGTH_UDP_TYPE_1 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(UpperLayerPacketLength(7 DOWNTO 0));
				Checksum_Addend1_us				<= unsigned(C_NET_IP_PROTOCOL_UDP);
			
				NextState									<= ST_CHECKSUMV4_PORT_NUMBER_0;

			WHEN ST_CHECKSUMV4_PORT_NUMBER_0 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(In_Meta_SrcPort(15 DOWNTO 8));
				Checksum_Addend1_us				<= unsigned(In_Meta_DestPort(15 DOWNTO 8));
			
				NextState									<= ST_CHECKSUMV4_PORT_NUMBER_1;

			WHEN ST_CHECKSUMV4_PORT_NUMBER_1 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(In_Meta_SrcPort(7 DOWNTO 0));
				Checksum_Addend1_us				<= unsigned(In_Meta_DestPort(7 DOWNTO 0));
				
				NextState									<= ST_CHECKSUMV4_CHECKSUM_LENGTH_0;
			
			WHEN ST_CHECKSUMV4_CHECKSUM_LENGTH_0 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(UpperLayerPacketLength(15 DOWNTO 8));
				Checksum_Addend1_us				<= unsigned(In_Meta_Checksum(15 DOWNTO 8));
				
				NextState									<= ST_CHECKSUMV4_CHECKSUM_LENGTH_1;

			WHEN ST_CHECKSUMV4_CHECKSUM_LENGTH_1 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(UpperLayerPacketLength(7 DOWNTO 0));
				Checksum_Addend1_us				<= unsigned(In_Meta_Checksum(7 DOWNTO 0));
			
				IF (Checksum0_cy = "00") THEN
					NextState								<= ST_SEND_SOURCE_PORT_0;
				ELSE
					NextState								<= ST_CARRY_0;
				END IF;
			
			-- calculate checksum for IPv6 pseudo header
			-- ----------------------------------------------------------------------
			WHEN ST_CHECKSUMV6_IPV6_ADDRESSES =>
				In_Meta_SrcIPAddress_nxt	<= '1';
				In_Meta_DestIPAddress_nxt	<= '1';
				
				IPSeqCounter_en						<= '1';
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(In_Meta_SrcIPAddress_Data);
				Checksum_Addend1_us				<= unsigned(In_Meta_DestIPAddress_Data);
				
				IF (IPSeqCounter_us = 15) THEN
					NextState								<= ST_CHECKSUMV6_LENGTH_UDP_TYPE_0;
				END IF;
			
			WHEN ST_CHECKSUMV6_LENGTH_UDP_TYPE_0 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(UpperLayerPacketLength(15 DOWNTO 8));
				Checksum_Addend1_us				<= (OTHERS => '0');
				
				NextState									<= ST_CHECKSUMV6_LENGTH_UDP_TYPE_1;

			WHEN ST_CHECKSUMV6_LENGTH_UDP_TYPE_1 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(UpperLayerPacketLength(7 DOWNTO 0));
				Checksum_Addend1_us				<= unsigned(C_NET_IP_PROTOCOL_UDP);
			
				NextState									<= ST_CHECKSUMV6_PORT_NUMBER_0;

			WHEN ST_CHECKSUMV6_PORT_NUMBER_0 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(In_Meta_SrcPort(15 DOWNTO 8));
				Checksum_Addend1_us				<= unsigned(In_Meta_DestPort(15 DOWNTO 8));
			
				NextState									<= ST_CHECKSUMV6_PORT_NUMBER_1;

			WHEN ST_CHECKSUMV6_PORT_NUMBER_1 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(In_Meta_SrcPort(7 DOWNTO 0));
				Checksum_Addend1_us				<= unsigned(In_Meta_DestPort(7 DOWNTO 0));
				
				NextState									<= ST_CHECKSUMV6_CHECKSUM_LENGTH_0;
			
			WHEN ST_CHECKSUMV6_CHECKSUM_LENGTH_0 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(UpperLayerPacketLength(15 DOWNTO 8));
				Checksum_Addend1_us				<= unsigned(In_Meta_Checksum(15 DOWNTO 8));
				
				NextState									<= ST_CHECKSUMV6_CHECKSUM_LENGTH_1;

			WHEN ST_CHECKSUMV6_CHECKSUM_LENGTH_1 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(UpperLayerPacketLength(7 DOWNTO 0));
				Checksum_Addend1_us				<= unsigned(In_Meta_Checksum(7 DOWNTO 0));
			
				IF (Checksum0_cy = "00") THEN
					NextState								<= ST_SEND_SOURCE_PORT_0;
				ELSE
					NextState								<= ST_CARRY_0;
				END IF;
			
			-- circulate carry bit
			-- ----------------------------------------------------------------------
			WHEN ST_CARRY_0 =>
				In_Meta_rst								<= Out_Meta_rst;
				
				Checksum_en								<= '1';
				Checksum_mux_set					<= '1';
				
				IF (Checksum0_cy = "00") THEN
					NextState								<= ST_SEND_SOURCE_PORT_0;
				ELSE
					NextState								<= ST_CARRY_1;
				END IF;
			
			WHEN ST_CARRY_1 =>
				In_Meta_rst								<= Out_Meta_rst;
			
				Checksum_en								<= '1';
				Checksum_mux_rst					<= '1';
				
				NextState									<= ST_SEND_SOURCE_PORT_0;
			
			-- assamble header
			-- ----------------------------------------------------------------------
			WHEN ST_SEND_SOURCE_PORT_0 =>
				Out_Valid									<= '1';
				Out_Data									<= In_Meta_SrcPort(15 DOWNTO 8);
				Out_SOF										<= '1';
				
				In_Meta_rst								<= Out_Meta_rst;
				
				IF (Out_Ready = '1') THEN
					NextState								<= ST_SEND_SOURCE_PORT_1;
				END IF;				
			
			WHEN ST_SEND_SOURCE_PORT_1 =>
				Out_Valid					<= '1';
				Out_Data					<= In_Meta_SrcPort(7 DOWNTO 0);
			
				IF (Out_Ready = '1') THEN
					NextState				<= ST_SEND_DEST_PORT_0;
				END IF;
				
			WHEN ST_SEND_DEST_PORT_0 =>
				Out_Valid					<= '1';
				Out_Data					<= In_Meta_DestPort(15 DOWNTO 8);
			
				IF (Out_Ready = '1') THEN
					NextState				<= ST_SEND_DEST_PORT_1;
				END IF;
			
			WHEN ST_SEND_DEST_PORT_1 =>
				Out_Valid					<= '1';
				Out_Data					<= In_Meta_DestPort(7 DOWNTO 0);
			
				IF (Out_Ready = '1') THEN
					NextState				<= ST_SEND_LENGTH_0;
				END IF;
			
			WHEN ST_SEND_LENGTH_0 =>
				Out_Valid					<= '1';
				Out_Data					<= UpperLayerPacketLength(15 DOWNTO 8);
			
				IF (Out_Ready = '1') THEN
					NextState				<= ST_SEND_LENGTH_1;
				END IF;
				
			WHEN ST_SEND_LENGTH_1 =>
				Out_Valid					<= '1';
				Out_Data					<= UpperLayerPacketLength(7 DOWNTO 0);
			
				IF (Out_Ready = '1') THEN
					NextState				<= ST_SEND_CHECKSUM_0;
				END IF;
				
			WHEN ST_SEND_CHECKSUM_0 =>
				Out_Valid					<= '1';
				Out_Data					<= Checksum(15 DOWNTO 8);
			
				IF (Out_Ready = '1') THEN
					NextState				<= ST_SEND_CHECKSUM_1;
				END IF;

			WHEN ST_SEND_CHECKSUM_1 =>
				Out_Valid					<= '1';
				Out_Data					<= Checksum(7 DOWNTO 0);
			
				IF (Out_Ready = '1') THEN
					NextState				<= ST_SEND_DATA;
				END IF;

			WHEN ST_SEND_DATA =>
				Out_Valid					<= In_Valid;
				Out_Data					<= In_Data;
				Out_EOF						<= In_EOF;
				In_Ready_i				<= Out_Ready;
				
				IF ((In_EOF AND Out_Ready) = '1') THEN
					NextState				<= ST_IDLE;
				END IF;
			
			WHEN ST_ERROR =>
				NULL;
		END CASE;
	END PROCESS;

	-- IPSeqCounter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR IPSeqCounter_rst) = '1') THEN
				IPSeqCounter_us			<= to_unsigned(0, IPSeqCounter_us'length);
			ELSE
				IF (IPSeqCounter_en = '1') THEN
					IPSeqCounter_us			<= IPSeqCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Checksum0_nxt0_us		<= ("0" & Checksum1_d_us)
													+ ("0" & Checksum_Addend0_us)
													+ ((Checksum_Addend0_us'range => '0') & Checksum0_cy0_d);
	Checksum0_nxt1_us		<= ("0" & Checksum0_nxt0_us(Checksum0_nxt0_us'high - 1 DOWNTO 0))
													+ ("0" & Checksum_Addend1_us)
													+ ((Checksum_Addend1_us'range => '0') & Checksum0_cy1_d);
	Checksum1_nxt_us		<= Checksum0_d_us(Checksum1_d_us'range);
	
	Checksum0_cy0				<= Checksum0_nxt0_us(Checksum0_nxt0_us'high);
	Checksum0_cy1				<= Checksum0_nxt1_us(Checksum0_nxt1_us'high);
	Checksum0_cy				<= Checksum0_cy1 & Checksum0_cy0;

					
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Checksum_rst = '1') THEN
				Checksum0_d_us			<= (OTHERS => '0');
				Checksum1_d_us			<= (OTHERS => '0');
			ELSE
				IF (Checksum_en = '1') THEN
					Checksum0_d_us		<= Checksum0_nxt1_us(Checksum0_nxt1_us'high - 1 DOWNTO 0);
					Checksum1_d_us		<= Checksum1_nxt_us;
					
					Checksum0_cy0_d		<= Checksum0_cy0;
					Checksum0_cy1_d		<= Checksum0_cy1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Checksum_i		<= not (std_logic_vector(Checksum0_nxt1_us(Checksum0_nxt1_us'high - 1 DOWNTO 0)) & std_logic_vector(Checksum1_nxt_us));
	Checksum			<= ite((Checksum_mux_r = '0'), Checksum_i, swap(Checksum_i, 8));

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Checksum_mux_rst) = '1') THEN
				Checksum_mux_r		<= '0';
			ELSIF (Checksum_mux_set = '1') THEN
				Checksum_mux_r		<= '1';
			END IF;
		END IF;
	END PROCESS;

	In_Ready					<= In_Ready_i;
	Out_Meta_Length		<= UpperLayerPacketLength;

END;