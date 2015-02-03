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


ENTITY UDP_FrameLoopback IS
	GENERIC (
		IP_VERSION										: POSITIVE						:= 6;
		MAX_FRAMES										: POSITIVE						:= 4
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		-- IN port
		In_Valid											: IN	STD_LOGIC;
		In_Data												: IN	T_SLV_8;
		In_SOF												: IN	STD_LOGIC;
		In_EOF												: IN	STD_LOGIC;
		In_Ack												: OUT	STD_LOGIC;
		In_Meta_rst										: OUT	STD_LOGIC;
		In_Meta_DestIPAddress_nxt			: OUT	STD_LOGIC;
		In_Meta_DestIPAddress_Data		: IN	T_SLV_8;
		In_Meta_SrcIPAddress_nxt			: OUT	STD_LOGIC;
		In_Meta_SrcIPAddress_Data			: IN	T_SLV_8;
		In_Meta_DestPort							: IN	T_NET_UDP_PORT;
		In_Meta_SrcPort								: IN	T_NET_UDP_PORT;
		-- OUT port
		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ack												: IN	STD_LOGIC;
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_DestIPAddress_nxt		: IN	STD_LOGIC;
		Out_Meta_DestIPAddress_Data		: OUT	T_SLV_8;
		Out_Meta_SrcIPAddress_nxt			: IN	STD_LOGIC;
		Out_Meta_SrcIPAddress_Data		: OUT	T_SLV_8;
		Out_Meta_DestPort							: OUT	T_NET_UDP_PORT;
		Out_Meta_SrcPort							: OUT	T_NET_UDP_PORT
	);
END;


ARCHITECTURE rtl OF UDP_FrameLoopback IS
	ATTRIBUTE KEEP										: BOOLEAN;
	
	CONSTANT IPADDRESS_LENGTH					: POSITIVE				:= ite((IP_VERSION = 4), 4, 16);
	
	CONSTANT META_STREAMID_SRCADDR		: NATURAL					:= 0;
	CONSTANT META_STREAMID_DESTADDR		: NATURAL					:= 1;
	CONSTANT META_STREAMID_SRCPORT		: NATURAL					:= 2;
	CONSTANT META_STREAMID_DESTPORT		: NATURAL					:= 3;
	
	CONSTANT META_BITS								: T_POSVEC				:= (
		META_STREAMID_SRCADDR			=> 8,
		META_STREAMID_DESTADDR		=> 8,
		META_STREAMID_SRCPORT			=> 16,
		META_STREAMID_DESTPORT		=> 16
	);
	
	CONSTANT META_FIFO_DEPTHS					: T_POSVEC				:= (
		META_STREAMID_SRCADDR			=> IPADDRESS_LENGTH,
		META_STREAMID_DESTADDR		=> IPADDRESS_LENGTH,
		META_STREAMID_SRCPORT			=> 1,
		META_STREAMID_DESTPORT		=> 1
	);
	
	SIGNAL StmBuf_MetaIn_nxt					: STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
	SIGNAL StmBuf_MetaIn_Data					: STD_LOGIC_VECTOR(isum(META_BITS) - 1 DOWNTO 0);
	SIGNAL StmBuf_MetaOut_nxt					: STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
	SIGNAL StmBuf_MetaOut_Data				: STD_LOGIC_VECTOR(isum(META_BITS) - 1 DOWNTO 0);
	
BEGIN
	StmBuf_MetaIn_Data(high(META_BITS, META_STREAMID_SRCADDR)		DOWNTO low(META_BITS, META_STREAMID_SRCADDR))		<= In_Meta_SrcIPAddress_Data;
	StmBuf_MetaIn_Data(high(META_BITS, META_STREAMID_DESTADDR)	DOWNTO low(META_BITS, META_STREAMID_DESTADDR))	<= In_Meta_DestIPAddress_Data;
	StmBuf_MetaIn_Data(high(META_BITS, META_STREAMID_SRCPORT)		DOWNTO low(META_BITS, META_STREAMID_SRCPORT))		<= In_Meta_SrcPort;
	StmBuf_MetaIn_Data(high(META_BITS, META_STREAMID_DESTPORT)	DOWNTO low(META_BITS, META_STREAMID_DESTPORT))	<= In_Meta_DestPort;
	
	In_Meta_SrcIPAddress_nxt		<= StmBuf_MetaIn_nxt(META_STREAMID_SRCADDR);
	In_Meta_DestIPAddress_nxt		<= StmBuf_MetaIn_nxt(META_STREAMID_DESTADDR);

	StmBuf : ENTITY PoC.stream_Buffer
		GENERIC MAP (
			FRAMES												=> MAX_FRAMES,
			DATA_BITS											=> 8,
			DATA_FIFO_DEPTH								=> 1024,
			META_BITS											=> META_BITS,
			META_FIFO_DEPTH								=> META_FIFO_DEPTHS
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			In_Valid											=> In_Valid,
			In_Data												=> In_Data,
			In_SOF												=> In_SOF,
			In_EOF												=> In_EOF,
			In_Ack												=> In_Ack,
			In_Meta_rst										=> In_Meta_rst,
			In_Meta_nxt										=> StmBuf_MetaIn_nxt,
			In_Meta_Data									=> StmBuf_MetaIn_Data,
			
			Out_Valid											=> Out_Valid,
			Out_Data											=> Out_Data,
			Out_SOF												=> Out_SOF,
			Out_EOF												=> Out_EOF,
			Out_Ack												=> Out_Ack,
			Out_Meta_rst									=> Out_Meta_rst,
			Out_Meta_nxt									=> StmBuf_MetaOut_nxt,
			Out_Meta_Data									=> StmBuf_MetaOut_Data
		);
	
	-- unpack buffer metadata to signals
	Out_Meta_SrcIPAddress_Data									<= StmBuf_MetaOut_Data(high(META_BITS, META_STREAMID_DESTADDR)	DOWNTO low(META_BITS, META_STREAMID_DESTADDR));			-- Crossover: Source <= Destination
	Out_Meta_DestIPAddress_Data									<= StmBuf_MetaOut_Data(high(META_BITS, META_STREAMID_SRCADDR)		DOWNTO low(META_BITS, META_STREAMID_SRCADDR));			-- Crossover: Destination <= Source
	Out_Meta_SrcPort														<= StmBuf_MetaOut_Data(high(META_BITS, META_STREAMID_DESTPORT)	DOWNTO low(META_BITS, META_STREAMID_DESTPORT));			-- Crossover: Source <= Destination
	Out_Meta_DestPort														<= StmBuf_MetaOut_Data(high(META_BITS, META_STREAMID_SRCPORT)		DOWNTO low(META_BITS, META_STREAMID_SRCPORT));			-- Crossover: Destination <= Source
	
	-- pack metadata nxt signals to StmBuf meta vector
	StmBuf_MetaOut_nxt(META_STREAMID_SRCADDR)		<= Out_Meta_DestIPAddress_nxt;
	StmBuf_MetaOut_nxt(META_STREAMID_DESTADDR)	<= Out_Meta_SrcIPAddress_nxt;
	StmBuf_MetaOut_nxt(META_STREAMID_SRCPORT)		<= '0';
	StmBuf_MetaOut_nxt(META_STREAMID_DESTPORT)	<= '0';
	
END ARCHITECTURE;
