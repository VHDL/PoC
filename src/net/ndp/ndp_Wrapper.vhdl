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
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.cache.all;
use			PoC.net.all;


entity NDP_Wrapper is
	generic (
		CLOCK_FREQ_MHZ											: REAL																	:= 125.0;
		INTERFACE_MACADDRESS								: T_NET_MAC_ADDRESS											:= C_NET_MAC_ADDRESS_EMPTY;
		INITIAL_IPV6ADDRESSES								: T_NET_IPV6_ADDRESS_VECTOR							:= (others => C_NET_IPV6_ADDRESS_EMPTY);
		INITIAL_DESTINATIONCACHE_CONTENT		: T_NET_NDP_DESTINATIONCACHE_VECTOR;
		INITIAL_NEIGHBORCACHE_CONTENT				: T_NET_NDP_NEIGHBORCACHE_VECTOR
	);
	port (
		Clock																: in	STD_LOGIC;
		Reset																: in	STD_LOGIC;

		NextHop_Query												: in	STD_LOGIC;
		NextHop_IPv6Address_rst							: out	STD_LOGIC;
		NextHop_IPv6Address_nxt							: out	STD_LOGIC;
		NextHop_IPv6Address_Data						: in	T_SLV_8;

		NextHop_Valid												: out	STD_LOGIC;
		NextHop_MACAddress_rst							: in	STD_LOGIC;
		NextHop_MACAddress_nxt							: in	STD_LOGIC;
		NextHop_MACAddress_Data							: out	T_SLV_8
	);
end entity;

-- translations
-- -------------------------------------
--								|		german
-- Solicitation		|	Aufforderung
-- Advertisement	|	Ankndigung
-- -------------------------------------


architecture rtl of NDP_Wrapper is

	signal FSMQuery_DCache_Lookup										: STD_LOGIC;
	signal FSMQuery_DCache_IPv6Address_Data					: T_SLV_8;
	signal FSMQuery_DCache_NextHopIPv6Address_rst		: STD_LOGIC;
	signal FSMQuery_DCache_NextHopIPv6Address_nxt		: STD_LOGIC;

	signal FSMQuery_NCache_Lookup										: STD_LOGIC;
	signal FSMQuery_NCache_IPv6Address_Data					: T_SLV_8;
	signal FSMQuery_NCache_MACAddress_rst						: STD_LOGIC;
	signal FSMQuery_NCache_MACAddress_nxt						: STD_LOGIC;

--	signal FSMCache_NewIPv4Address						: T_NDPIPV4_ADDRESS;
--	signal FSMCache_NewMACAddress							: T_NDPMAC_ADDRESS;
	signal FSMCache_Lookup													: STD_LOGIC;
	signal FSMCache_IPv6Address											: T_NET_IPV6_ADDRESS;

	-- NDP IPPool
	signal IPPool_PoolResult												: T_CACHE_RESULT;

	-- NDP NeighborCache
	signal NCache_CacheResult												: T_CACHE_RESULT;
	signal NCache_IPv6Address_rst										: STD_LOGIC;
	signal NCache_IPv6Address_nxt										: STD_LOGIC;
	signal NCache_MACAddress_Data										: T_SLV_8;
	signal NCache_Reachability											: T_NET_NDP_REACHABILITY_STATE;

	-- NDP DestinationCache
	signal DCache_IPv6Address_rst										: STD_LOGIC;
	signal DCache_IPv6Address_nxt										: STD_LOGIC;
	signal DCache_CacheResult												: T_CACHE_RESULT;
	signal DCache_NextHopIPv6Address_Data						: T_SLV_8;
	signal DCache_PathMUT														: T_SLV_16;

	signal FSMPrefix_Lookup													: STD_LOGIC;
	signal FSMPrefix_IPv6Address										: T_NET_IPV6_ADDRESS;

	-- NDP PrefixList
	signal PList_CacheHit														: STD_LOGIC;
	signal PList_CacheMiss													: STD_LOGIC;
	signal PList_MACAddress													: T_NET_MAC_ADDRESS;
begin

	FSMQuery : entity PoC.ndp_FSMQuery
		port map (
			Clock															=> Clock,
			Reset															=> Reset,

			NextHop_Query											=> NextHop_Query,
			NextHop_IPv6Address_rst						=> NextHop_IPv6Address_rst,
			NextHop_IPv6Address_nxt						=> NextHop_IPv6Address_nxt,
			NextHop_IPv6Address_Data					=> NextHop_IPv6Address_Data,

			NextHop_Valid											=> NextHop_Valid,
			NextHop_MACAddress_rst						=> NextHop_MACAddress_rst,
			NextHop_MACAddress_nxt						=> NextHop_MACAddress_nxt,
			NextHop_MACAddress_Data						=> NextHop_MACAddress_Data,

			DCache_Lookup											=> FSMQuery_DCache_Lookup,
			DCache_IPv6Address_rst						=> DCache_IPv6Address_rst,
			DCache_IPv6Address_nxt						=> DCache_IPv6Address_nxt,
			DCache_IPv6Address_Data						=> FSMQuery_DCache_IPv6Address_Data,

			DCache_CacheResult								=> DCache_CacheResult,
			DCache_NextHopIPv6Address_rst			=> FSMQuery_DCache_NextHopIPv6Address_rst,
			DCache_NextHopIPv6Address_nxt			=> FSMQuery_DCache_NextHopIPv6Address_nxt,
			DCache_NextHopIPv6Address_Data		=> DCache_NextHopIPv6Address_Data,
			DCache_PathMUT										=> DCache_PathMUT,

			NCache_Lookup											=> FSMQuery_NCache_Lookup,
			NCache_IPv6Address_rst						=> NCache_IPv6Address_rst,
			NCache_IPv6Address_nxt						=> NCache_IPv6Address_nxt,
			NCache_IPv6Address_Data						=> FSMQuery_NCache_IPv6Address_Data,

			NCache_CacheResult								=> NCache_CacheResult,
			NCache_MACAddress_rst							=> FSMQuery_NCache_MACAddress_rst,
			NCache_MACAddress_nxt							=> FSMQuery_NCache_MACAddress_nxt,
			NCache_MACAddress_Data						=> NCache_MACAddress_Data,
			NCache_Reachability								=> NCache_Reachability
		);

	IPPool : entity PoC.ndp_IPPool
		generic map (
			IPPOOL_SIZE												=> 8,
			INITIAL_IPV6ADDRESSES							=> INITIAL_IPV6ADDRESSES
		)
		port map (
			Clock															=> Clock,
			Reset															=> Reset,

--			Command														=> IPPool_Command,
--			IPv4Address												=> (others => '0'),
--			MACAddress												=> (others => '0'),

			Lookup														=> '0',--FSMPool_IPPool_Lookup,
			IPv6Address_rst										=> open,--IPPool_IPv6Address_rst,
			IPv6Address_nxt										=> open,--IPPool_IPv6Address_nxt,
			IPv6Address_Data									=> x"00",--FSMPool_IPPool_IPv6Address_Data,

			PoolResult												=> IPPool_PoolResult
		);


	-- ==========================================================================================================================================================
	-- DestinationCache
	-- ==========================================================================================================================================================
	DCache : entity PoC.ndp_DestinationCache
		generic map (
			CLOCK_FREQ_MHZ						=> CLOCK_FREQ_MHZ,
			REPLACEMENT_POLICY				=> "LRU",
			TAG_BYTE_ORDER						=> BIG_ENDIAN,
			DATA_BYTE_ORDER						=> LITTLE_ENDIAN,
			INITIAL_CACHE_CONTENT			=> INITIAL_DESTINATIONCACHE_CONTENT
		)
		port map (
			Clock											=> Clock,
			Reset											=> Reset,

			Lookup										=> FSMQuery_DCache_Lookup,
			IPv6Address_rst						=> DCache_IPv6Address_rst,
			IPv6Address_nxt						=> DCache_IPv6Address_nxt,
			IPv6Address_Data					=> FSMQuery_DCache_IPv6Address_Data,

			CacheResult								=> DCache_CacheResult,
			NextHopIPv6Address_rst		=> FSMQuery_DCache_NextHopIPv6Address_rst,
			NextHopIPv6Address_nxt		=> FSMQuery_DCache_NextHopIPv6Address_nxt,
			NextHopIPv6Address_Data		=> DCache_NextHopIPv6Address_Data,
			PathMTU										=> DCache_PathMUT
		);

	-- ==========================================================================================================================================================
	-- NeighborCache
	-- ==========================================================================================================================================================
	NCache : entity PoC.ndp_NeighborCache
		generic map (
			REPLACEMENT_POLICY				=> "LRU",
			TAG_BYTE_ORDER						=> LITTLE_ENDIAN,
			DATA_BYTE_ORDER						=> BIG_ENDIAN,
			INITIAL_CACHE_CONTENT			=> INITIAL_NEIGHBORCACHE_CONTENT
		)
		port map (
			Clock											=> Clock,
			Reset											=> Reset,

			Lookup										=> FSMQuery_NCache_Lookup,
			IPv6Address_rst						=> NCache_IPv6Address_rst,
			IPv6Address_nxt						=> NCache_IPv6Address_nxt,
			IPv6Address_Data					=> FSMQuery_NCache_IPv6Address_Data,

			CacheResult								=> NCache_CacheResult,
			MACAddress_rst						=> FSMQuery_NCache_MACAddress_rst,
			MACAddress_nxt						=> FSMQuery_NCache_MACAddress_nxt,
			MACAddress_Data						=> NCache_MACAddress_Data,
			Reachability							=> NCache_Reachability
		);


	-- ============================================================================================================================================================
	-- PrefixList
	-- ============================================================================================================================================================
	FSMPrefix_Lookup				<= '0';--NextHop_Query;
	FSMPrefix_IPv6Address		<= (others => (others => '0'));--NextHop_IPv6Address;

	PList : entity PoC.ndp_PrefixList
		port map (
			Clock											=> Clock,
			Reset											=> Reset,

			Insert										=> '0',
			NewIPv6Prefix							=> C_NET_IPV6_ADDRESS_EMPTY,
			NewIPv6Mask								=> C_NET_IPV6_ADDRESS_EMPTY,

			Lookup										=> FSMPrefix_Lookup,
			IPv6Address								=> FSMPrefix_IPv6Address,

			CacheHit									=> PList_CacheHit,
			CacheMiss									=> PList_CacheMiss,
			MACAddress								=> PList_MACAddress
		);
end architecture;
