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


entity ndp_FSMQuery is
	port (
		Clock														: in	STD_LOGIC;
		Reset														: in	STD_LOGIC;

		NextHop_Query										: in	STD_LOGIC;
		NextHop_IPv6Address_rst					: out	STD_LOGIC;
		NextHop_IPv6Address_nxt					: out	STD_LOGIC;
		NextHop_IPv6Address_Data				: in	T_SLV_8;

		NextHop_Valid										: out	STD_LOGIC;
		NextHop_MACAddress_rst					: in	STD_LOGIC;
		NextHop_MACAddress_nxt					: in	STD_LOGIC;
		NextHop_MACAddress_Data					: out	T_SLV_8;

		DCache_Lookup										: out STD_LOGIC;
		DCache_IPv6Address_rst					: in sTD_LOGIC;
		DCache_IPv6Address_nxt					: in sTD_LOGIC;
		DCache_IPv6Address_Data					: out T_SLV_8;

		DCache_CacheResult							: in	T_CACHE_RESULT;
		DCache_NextHopIPv6Address_rst		: out	STD_LOGIC;
		DCache_NextHopIPv6Address_nxt		: out	STD_LOGIC;
		DCache_NextHopIPv6Address_Data	: in	T_SLV_8;
		DCache_PathMUT									: in	T_SLV_16;

		NCache_Lookup										: out STD_LOGIC;
		NCache_IPv6Address_rst					: in sTD_LOGIC;
		NCache_IPv6Address_nxt					: in sTD_LOGIC;
		NCache_IPv6Address_Data					: out T_SLV_8;

		NCache_CacheResult							: in	T_CACHE_RESULT;
		NCache_MACAddress_rst						: out	STD_LOGIC;
		NCache_MACAddress_nxt						: out	STD_LOGIC;
		NCache_MACAddress_Data					: in	T_SLV_8;
		NCache_Reachability							: in	T_NET_NDP_REACHABILITY_STATE
	);
end entity;


architecture rtl of ndp_FSMQuery is

	type T_STATE is (
		ST_IDLE,
		ST_DESTCACHE_WAIT,
		ST_NEIGHBORCACHE_LOOKUP,	ST_NEIGHBORCACHE_WAIT,
		ST_PREFIXLIST_LOOKUP,			ST_PREFIXLIST_WAIT,
		ST_VALID
	);

	signal State								: T_STATE								:= ST_IDLE;
	signal NextState						: T_STATE;

--	signal NextHop_en						: STD_LOGIC;
	signal IPv6Address_d				: T_NET_IPV6_ADDRESS		:= C_NET_IPV6_ADDRESS_EMPTY;

	signal MAC_en								: STD_LOGIC;
	signal MACAddress_d					: T_NET_MAC_ADDRESS			:= C_NET_MAC_ADDRESS_EMPTY;

begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State				<= ST_IDLE;
			else
				State				<= NextState;
			end if;
		end if;
	end process;

	process(State,
					NextHop_Query,
					NextHop_MACAddress_rst, NextHop_MACAddress_nxt, NextHop_IPv6Address_Data,--NextHop_MACAddress_rev,
					DCache_CacheResult, DCache_IPv6Address_rst, DCache_IPv6Address_nxt, DCache_NextHopIPv6Address_Data,--DCache_IPv6Address_rev,
					NCache_CacheResult, NCache_IPv6Address_rst, NCache_IPv6Address_nxt, NCache_MACAddress_Data)--NCache_IPv6Address_rev,
	begin
		NextState												<= State;

		NextHop_IPv6Address_rst					<= DCache_IPv6Address_rst;
		NextHop_IPv6Address_nxt					<= DCache_IPv6Address_nxt;
		NextHop_Valid										<= '0';

		DCache_Lookup										<= '0';
		DCache_IPv6Address_Data					<= NextHop_IPv6Address_Data;
		DCache_NextHopIPv6Address_rst		<= NCache_IPv6Address_rst;
		DCache_NextHopIPv6Address_nxt		<= NCache_IPv6Address_nxt;

		NCache_Lookup										<= '0';
		NCache_IPv6Address_Data					<= DCache_NextHopIPv6Address_Data;
		NCache_MACAddress_rst						<= NextHop_MACAddress_rst;
		NCache_MACAddress_nxt						<= NextHop_MACAddress_nxt;

		NextHop_MACAddress_Data					<= NCache_MACAddress_Data;

--		NextHop_en								<= '0';
		MAC_en										<= '0';

		case State is
			when ST_IDLE =>
				if (NextHop_Query = '1') then
					DCache_Lookup		<= '1';

					if (DCache_CacheResult = CACHE_RESULT_NONE) then
						NextState				<= ST_DESTCACHE_WAIT;
					ELSif (DCache_CacheResult = CACHE_RESULT_HIT) then
--						NextHop_en			<= '1';
						NextState				<= ST_NEIGHBORCACHE_LOOKUP;
					else
						-- TODO: cachemiss
					end if;
				end if;

			when ST_DESTCACHE_WAIT =>
				if (DCache_CacheResult = CACHE_RESULT_HIT) then
--					NextHop_en			<= '1';
					NextState				<= ST_NEIGHBORCACHE_LOOKUP;
				ELSif (DCache_CacheResult = CACHE_RESULT_MISS) then
					-- TODO: cachemiss
				end if;

			when ST_NEIGHBORCACHE_LOOKUP =>
				NCache_Lookup				<= '1';

				if (NCache_CacheResult = CACHE_RESULT_NONE) then
					NextState				<= ST_NEIGHBORCACHE_WAIT;
				ELSif (NCache_CacheResult = CACHE_RESULT_HIT) then
					MAC_en					<= '1';
					NextState				<= ST_VALID;
				else
					-- TODO: cachemiss
				end if;

			when ST_NEIGHBORCACHE_WAIT =>
				if (NCache_CacheResult = CACHE_RESULT_HIT) then
					MAC_en					<= '1';
					NextState				<= ST_VALID;
				ELSif (NCache_CacheResult = CACHE_RESULT_MISS) then
					-- TODO: cachemiss
				end if;

			when ST_VALID =>
				NextHop_Valid			<= '1';
				NextState					<= ST_IDLE;

			when ST_PREFIXLIST_LOOKUP =>
				NULL;

			when ST_PREFIXLIST_WAIT =>
				NULL;

		end case;
	end process;


--	process(Clock)
--	begin
--		if rising_edge(Clock) then
--			if (Reset = '1') then
--				IPv6Address_d		<= C_NET_IPV6_ADDRESS_EMPTY;
--				MACAddress_d		<= C_ETH_MAC_ADDRESS_EMPTY;
--			else
--				if (NextHop_en = '1') then
--					IPv6Address_d		<= DCache_NextHopIPv6Address;
--				end if;
--
--				if (MAC_en = '1') then
--					MACAddress_d		<= NCache_MACAddress;
--				end if;
--			end if;
--		end if;
--	end process;

	NextHop_MACAddress_Data		<= NCache_MACAddress_Data;
end architecture;
