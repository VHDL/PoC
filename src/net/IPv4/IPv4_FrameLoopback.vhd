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


ENTITY IPv4_FrameLoopback IS
	GENERIC (
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
		In_Ready											: OUT	STD_LOGIC;
		In_Meta_rst										: OUT	STD_LOGIC;
		In_Meta_SrcIPv4Address_nxt		: OUT	STD_LOGIC;
		In_Meta_SrcIPv4Address_Data		: IN	T_SLV_8;
		In_Meta_DestIPv4Address_nxt		: OUT	STD_LOGIC;
		In_Meta_DestIPv4Address_Data	: IN	T_SLV_8;
		In_Meta_Length								: IN	T_SLV_16;
		-- OUT port
		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ready											: IN	STD_LOGIC;
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_SrcIPv4Address_nxt		: IN	STD_LOGIC;
		Out_Meta_SrcIPv4Address_Data	: OUT	T_SLV_8;
		Out_Meta_DestIPv4Address_nxt	: IN	STD_LOGIC;
		Out_Meta_DestIPv4Address_Data	: OUT	T_SLV_8;
		Out_Meta_Length								: OUT	T_SLV_16
	);
END;


ARCHITECTURE rtl OF IPv4_FrameLoopback IS
	ATTRIBUTE KEEP										: BOOLEAN;
	
	CONSTANT META_STREAMID_SRCADDR		: NATURAL					:= 0;
	CONSTANT META_STREAMID_DESTADDR		: NATURAL					:= 1;
	CONSTANT META_STREAMID_LENGTH			: NATURAL					:= 2;
	
	CONSTANT META_BITS								: T_POSVEC				:= (
		META_STREAMID_SRCADDR			=> 8,
		META_STREAMID_DESTADDR		=> 8,
		META_STREAMID_LENGTH			=> 16
	);

	CONSTANT META_FIFO_DEPTHS					: T_POSVEC				:= (
		META_STREAMID_SRCADDR			=> 4,
		META_STREAMID_DESTADDR		=> 4,
		META_STREAMID_LENGTH			=> 1
	);

	SIGNAL StmBuf_MetaIn_nxt					: STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
	SIGNAL StmBuf_MetaIn_Data					: STD_LOGIC_VECTOR(isum(META_BITS) - 1 DOWNTO 0);
	SIGNAL StmBuf_MetaOut_nxt					: STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
	SIGNAL StmBuf_MetaOut_Data				: STD_LOGIC_VECTOR(isum(META_BITS) - 1 DOWNTO 0);
	
BEGIN
	StmBuf_MetaIn_Data(high(META_BITS, META_STREAMID_SRCADDR)		DOWNTO low(META_BITS, META_STREAMID_SRCADDR))		<= In_Meta_SrcIPv4Address_Data;
	StmBuf_MetaIn_Data(high(META_BITS, META_STREAMID_DESTADDR)	DOWNTO low(META_BITS, META_STREAMID_DESTADDR))	<= In_Meta_DestIPv4Address_Data;
	StmBuf_MetaIn_Data(high(META_BITS, META_STREAMID_LENGTH)		DOWNTO low(META_BITS, META_STREAMID_LENGTH))		<= In_Meta_Length;
	
	In_Meta_SrcIPv4Address_nxt		<= StmBuf_MetaIn_nxt(META_STREAMID_SRCADDR);
	In_Meta_DestIPv4Address_nxt		<= StmBuf_MetaIn_nxt(META_STREAMID_DESTADDR);

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
			In_Ready											=> In_Ready,
			In_Meta_rst										=> In_Meta_rst,
			In_Meta_nxt										=> StmBuf_MetaIn_nxt,
			In_Meta_Data									=> StmBuf_MetaIn_Data,
			
			Out_Valid											=> Out_Valid,
			Out_Data											=> Out_Data,
			Out_SOF												=> Out_SOF,
			Out_EOF												=> Out_EOF,
			Out_Ready											=> Out_Ready,
			Out_Meta_rst									=> Out_Meta_rst,
			Out_Meta_nxt									=> StmBuf_MetaOut_nxt,
			Out_Meta_Data									=> StmBuf_MetaOut_Data
		);
	
	-- unpack StmBuf metadata to signals
	Out_Meta_SrcIPv4Address_Data								<= StmBuf_MetaOut_Data(high(META_BITS, META_STREAMID_DESTADDR)	DOWNTO low(META_BITS, META_STREAMID_DESTADDR));			-- Crossover: Source <= Destination
	Out_Meta_DestIPv4Address_Data								<= StmBuf_MetaOut_Data(high(META_BITS, META_STREAMID_SRCADDR)		DOWNTO low(META_BITS, META_STREAMID_SRCADDR));			-- Crossover: Destination <= Source
	Out_Meta_Length															<= StmBuf_MetaOut_Data(high(META_BITS, META_STREAMID_LENGTH)		DOWNTO low(META_BITS, META_STREAMID_LENGTH));
	
	-- pack metadata nxt signals to StmBuf meta vector
	StmBuf_MetaOut_nxt(META_STREAMID_DESTADDR)		<= Out_Meta_SrcIPv4Address_nxt;
	StmBuf_MetaOut_nxt(META_STREAMID_SRCADDR)		<= Out_Meta_DestIPv4Address_nxt;
	StmBuf_MetaOut_nxt(META_STREAMID_LENGTH)			<= '0';

END ARCHITECTURE;
