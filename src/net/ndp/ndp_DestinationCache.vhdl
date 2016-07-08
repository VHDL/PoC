-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.cache.all;
use			PoC.net.all;


entity ndp_DestinationCache is
	generic (
		CLOCK_FREQ_MHZ						: REAL																	:= 125.0;					-- 125 MHz
		REPLACEMENT_POLICY				: STRING																:= "LRU";
		TAG_BYTE_ORDER						: T_BYTE_ORDER													:= BIG_ENDIAN;
		DATA_BYTE_ORDER						: T_BYTE_ORDER													:= BIG_ENDIAN;
		INITIAL_CACHE_CONTENT			: T_NET_NDP_DESTINATIONCACHE_VECTOR
	);
	port (
		Clock											: in	STD_LOGIC;																	--
		Reset											: in	STD_LOGIC;																	--

		Lookup										: in	STD_LOGIC;
		IPv6Address_rst						: out	STD_LOGIC;
		IPv6Address_nxt						: out	STD_LOGIC;
		IPv6Address_Data					: in	T_SLV_8;

		CacheResult								: out	T_CACHE_RESULT;
		NextHopIPv6Address_rst		: in	STD_LOGIC;
		NextHopIPv6Address_nxt		: in	STD_LOGIC;
		NextHopIPv6Address_Data		: out	T_SLV_8;
		PathMTU										: out T_SLV_16
	);
end entity;


architecture rtl of ndp_DestinationCache is
	attribute KEEP										: BOOLEAN;

	constant CACHE_LINES							: POSITIVE			:= 8;
	constant TAG_BITS									: POSITIVE			:= 128;
	constant DATA_BITS								:	POSITIVE			:= 128;
	constant TAGCHUNK_BITS						: POSITIVE			:= 8;
	constant DATACHUNK_BITS						: POSITIVE			:= 8;

	constant DATACHUNKS								: POSITIVE	:= div_ceil(DATA_BITS, DATACHUNK_BITS);
	constant DATACHUNK_INDEX_BITS			: POSITIVE	:= log2ceilnz(DATACHUNKS);
	constant CACHEMEMORY_INDEX_BITS		: POSITIVE	:= log2ceilnz(CACHE_LINES);

	function to_TagData(CacheContent : T_NET_NDP_DESTINATIONCACHE_VECTOR) return T_SLM is
		variable slvv		: T_SLVV_128(CACHE_LINES - 1 downto 0)	:= (others => (others => '0'));
	begin
		for i in CacheContent'range loop
			slvv(I)	:= to_slv(CacheContent(I).Tag);
		end loop;
		return to_slm(slvv);
	END function;

	function to_CacheData_slvv_128(CacheContent : T_NET_NDP_DESTINATIONCACHE_VECTOR) return T_SLVV_128 is
		variable slvv		: T_SLVV_128(CACHE_LINES - 1 downto 0)	:= (others => (others => '0'));
	begin
		for i in CacheContent'range loop
			slvv(I)	:= to_slv(CacheContent(I).NextHop);
		end loop;
		return slvv;
	END function;

	function to_CacheMemory(CacheContent : T_NET_NDP_DESTINATIONCACHE_VECTOR) return T_SLVV_8 is
		constant BYTES_PER_LINE	: POSITIVE																								:= 16;
		constant slvv						: T_SLVV_128(CACHE_LINES - 1 downto 0)										:= to_CacheData_slvv_128(CacheContent);
		variable result					: T_SLVV_8((CACHE_LINES * BYTES_PER_LINE) - 1 downto 0);
	begin
		for i in slvv'range loop
			for j in 0 to BYTES_PER_LINE - 1 loop
				result((I * BYTES_PER_LINE) + J)	:= slvv(I)((J * 8) + 7 downto J * 8);
			end loop;
		end loop;
		return result;
	END function;

	constant INITIAL_TAGS						: T_SLM			:= to_TagData(INITIAL_CACHE_CONTENT);
	constant INITIAL_DATALINES			: T_SLVV_8	:= to_CacheMemory(INITIAL_CACHE_CONTENT);

	signal ReadWrite								: STD_LOGIC;

	signal Insert										: STD_LOGIC;
	signal TU_NewTag_rst						: STD_LOGIC;
	signal TU_NewTag_nxt						: STD_LOGIC;
	signal NewTag_Data							: T_SLV_8;
	signal NewCacheLine_rst					: STD_LOGIC;
	signal NewCacheLine_nxt					: STD_LOGIC;
	signal NewCacheLine_Data				: T_SLV_8;
	signal TU_Tag_rst								: STD_LOGIC;
	signal TU_Tag_nxt								: STD_LOGIC;
	signal TU_Tag_Data							: T_SLV_8;
	signal CacheHit									: STD_LOGIC;
	signal CacheMiss								: STD_LOGIC;

	signal TU_Index									: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 downto 0);
	signal TU_Index_d								: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 downto 0);
	signal TU_Index_us							: UNSIGNED(CACHEMEMORY_INDEX_BITS - 1 downto 0);
	signal TU_NewIndex							: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 downto 0);
	signal TU_Replace								: STD_LOGIC;

	signal TU_TagHit								: STD_LOGIC;
	signal TU_TagMiss								: STD_LOGIC;

	signal DataChunkIndex_us				: UNSIGNED(DATACHUNK_INDEX_BITS - 1 downto 0)													:= (others => '0');
	signal CacheMemory							: T_SLVV_8((CACHE_LINES * T_NET_IPV6_ADDRESS'length) - 1 downto 0)		:= INITIAL_DATALINES;
	signal Memory_ReadWrite					: STD_LOGIC;
	signal MemoryIndex_us						: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 downto 0);
	signal ReplaceIndex_us					: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 downto 0);
	signal ReplacedIndex_us					: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 downto 0);


begin
--	process(Command)
--	begin
--		Insert		<= '0';
--
--		case Command is
--			when ETHERNET_NET_NDP_NeighborCache_CMD_NONE =>		NULL;
--			when ETHERNET_NET_NDP_NeighborCache_CMD_ADD =>		Insert <= '1';
--
--		end case;
--	end process;

	-- FIXME: add correct assignment
	Insert							<= '0';


	ReadWrite						<= '0';
	NewTag_Data					<= (others => '0');
	NewCacheLine_Data		<= (others => '0');

	TU_Tag_Data					<= IPv6Address_Data;
	IPv6Address_rst			<= TU_Tag_rst;
	IPv6Address_nxt			<= TU_Tag_nxt;

	CacheResult					<= to_Cache_Result(CacheHit, CacheMiss);

	-- Cache TagUnit
--	TU : entity PoC.Cache_TagUnit_seq
	TU : entity PoC.cache_TagUnit_seq
		generic map (
			REPLACEMENT_POLICY				=> REPLACEMENT_POLICY,
			CACHE_LINES								=> CACHE_LINES,
			ASSOCIATIVITY							=> CACHE_LINES,
			TAG_BITS									=> TAG_BITS,
			CHUNK_BITS								=> TAGCHUNK_BITS,
			TAG_BYTE_ORDER						=> BIG_ENDIAN,
			INITIAL_TAGS							=> INITIAL_TAGS
		)
		port map (
			Clock											=> Clock,
			Reset											=> Reset,

			Replace										=> Insert,
			Replace_NewTag_rst				=> TU_NewTag_rst,
			Replace_NewTag_rev				=> open,
			Replace_NewTag_nxt				=> TU_NewTag_nxt,
			Replace_NewTag_Data				=> NewTag_Data,
			Replace_NewIndex					=> TU_NewIndex,
			Replaced									=> TU_Replace,

			Request										=> Lookup,
			Request_ReadWrite					=> '0',
			Request_Invalidate				=> '0',--Invalidate,
			Request_Tag_rst						=> TU_Tag_rst,
			Request_Tag_rev						=> open,
			Request_Tag_nxt						=> TU_Tag_nxt,
			Request_Tag_Data					=> TU_Tag_Data,
			Request_Index							=> TU_Index,
			Request_TagHit						=> TU_TagHit,
			Request_TagMiss						=> TU_TagMiss
		);

	-- latch TU_Index on TagHit
	TU_Index_us		<= unsigned(TU_Index) when rising_edge(Clock) AND (TU_TagHit = '1');

	-- ChunkIndex counter
	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset OR NextHopIPv6Address_rst) = '1') then
				if (DATA_BYTE_ORDER = LITTLE_ENDIAN) then
					DataChunkIndex_us			<= to_unsigned(0,									DataChunkIndex_us'length);
				else
					DataChunkIndex_us			<= to_unsigned((DATACHUNKS - 1),	DataChunkIndex_us'length);
				end if;
			else
				if (NextHopIPv6Address_nxt = '1') then
					if (DATA_BYTE_ORDER = LITTLE_ENDIAN) then
						DataChunkIndex_us		<= DataChunkIndex_us + 1;
					else
						DataChunkIndex_us		<= DataChunkIndex_us - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- Cache Memory - port 1
	Memory_ReadWrite	<= ReadWrite;
	MemoryIndex_us		<= TU_Index_us & DataChunkIndex_us;

	-- Cache Memory - port 2
	ReplaceIndex_us		<= unsigned(TU_NewIndex) & DataChunkIndex_us;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Memory_ReadWrite AND TU_TagHit) = '1') then
--					CacheMemory(to_integer(MemoryIndex_us))	<= CacheLineIn;
			end if;

			if (TU_Replace = '1') then
--					CacheMemory(to_integer(ReplaceIndex_us))	<= NewCacheLine_Data;
			end if;
		end if;
	end process;

	CacheHit									<= TU_TagHit;
	CacheMiss									<= TU_TagMiss;
	NextHopIPv6Address_Data		<= CacheMemory(to_integer(MemoryIndex_us));

--	CacheResult						<= to_cache_result(CacheHit, CacheMiss);
--	PathMTU								<= CacheLine(143 downto 128);

--		Replaced					<= TU_Replace;
end architecture;
