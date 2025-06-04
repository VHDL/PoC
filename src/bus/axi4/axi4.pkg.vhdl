-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:				 	Generic AMBA AXI4 bus description
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4 description for:
--
-- * AXI4 (full)
-- * AXI4-Lite
-- * AXI4-Stream
--
-- License:
-- =============================================================================
-- Copyright 2024      PLC2 Design GmbH - Endingen, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.AXI4_Common.all;
use     work.AXI4Stream.all;
use     work.AXI4Lite.all;
use     work.AXI4_Full.all;

package AXI4 is
	--ATTENTION::Whe using this function, keep in mind that return id is always zero!
	--           Use only when connected AXI4Full is not using ID!
	--           If ID is needed, use Moduel "AXI4_to_AXI4Lite"
	function to_AXI4LITE_BUS(full : T_AXI4_BUS_M2S; databit : natural := 0) return T_AXI4LITE_BUS_M2S;
	function to_AXI4LITE_BUS(full : T_AXI4_BUS_S2M; databit : natural := 0) return T_AXI4LITE_BUS_S2M;

	function to_AXI4_BUS(lite : T_AXI4LITE_BUS_M2S; databit : natural := 0; id_bits : positive := 1; user_bits : positive := 1) return T_AXI4_BUS_M2S;
	function to_AXI4_BUS(lite : T_AXI4LITE_BUS_S2M; databit : natural := 0; id_bits : positive := 1; user_bits : positive := 1) return T_AXI4_BUS_S2M;

	-- AXI4 common types and constants
	alias T_AXI4_Response is work.AXI4_Common.T_AXI4_Response;
	alias C_AXI4_RESPONSE_OKAY is work.AXI4_Common.C_AXI4_RESPONSE_OKAY;
	alias C_AXI4_RESPONSE_EX_OKAY is work.AXI4_Common.C_AXI4_RESPONSE_EX_OKAY;
	alias C_AXI4_RESPONSE_SLAVE_ERROR is work.AXI4_Common.C_AXI4_RESPONSE_SLAVE_ERROR;
	alias C_AXI4_RESPONSE_DECODE_ERROR is work.AXI4_Common.C_AXI4_RESPONSE_DECODE_ERROR;
	alias C_AXI4_RESPONSE_INIT is work.AXI4_Common.C_AXI4_RESPONSE_INIT;

	alias T_AXI4_Cache is work.AXI4_Common.T_AXI4_Cache;
	alias C_AXI4_CACHE_INIT is work.AXI4_Common.C_AXI4_CACHE_INIT;
	alias C_AXI4_CACHE is work.AXI4_Common.C_AXI4_CACHE;

	alias T_AXI4_QoS is work.AXI4_Common.T_AXI4_QoS;
	alias C_AXI4_QOS_INIT is work.AXI4_Common.C_AXI4_QOS_INIT;

	alias T_AXI4_Region is work.AXI4_Common.T_AXI4_Region;
	alias C_AXI4_REGION_INIT is work.AXI4_Common.C_AXI4_REGION_INIT;

	alias T_AXI4_Size is work.AXI4_Common.T_AXI4_Size;
	alias C_AXI4_SIZE_1 is work.AXI4_Common.C_AXI4_SIZE_1;
	alias C_AXI4_SIZE_2 is work.AXI4_Common.C_AXI4_SIZE_2;
	alias C_AXI4_SIZE_4 is work.AXI4_Common.C_AXI4_SIZE_4;
	alias C_AXI4_SIZE_8 is work.AXI4_Common.C_AXI4_SIZE_8;
	alias C_AXI4_SIZE_16 is work.AXI4_Common.C_AXI4_SIZE_16;
	alias C_AXI4_SIZE_32 is work.AXI4_Common.C_AXI4_SIZE_32;
	alias C_AXI4_SIZE_64 is work.AXI4_Common.C_AXI4_SIZE_64;
	alias C_AXI4_SIZE_128 is work.AXI4_Common.C_AXI4_SIZE_128;
	alias C_AXI4_SIZE_INIT is work.AXI4_Common.C_AXI4_SIZE_INIT;

	alias T_AXI4_Burst is work.AXI4_Common.T_AXI4_Burst;
	alias C_AXI4_BURST_FIXED is work.AXI4_Common.C_AXI4_BURST_FIXED;
	alias C_AXI4_BURST_INCR is work.AXI4_Common.C_AXI4_BURST_INCR;
	alias C_AXI4_BURST_WRAP is work.AXI4_Common.C_AXI4_BURST_WRAP;
	alias C_AXI4_BURST_INIT is work.AXI4_Common.C_AXI4_BURST_INIT;

	alias T_AXI4_Protect is work.AXI4_Common.T_AXI4_Protect;
	alias C_AXI4_PROTECT_INIT is work.AXI4_Common.C_AXI4_PROTECT_INIT;
	alias C_AXI4_PROTECT is work.AXI4_Common.C_AXI4_PROTECT;
end package;
package body AXI4 is

	function to_AXI4LITE_BUS(full : T_AXI4_BUS_M2S; databit : natural := 0) return T_AXI4LITE_BUS_M2S is
		constant addrbit   : natural                                      := full.AWAddr'length;
		constant databit_i : natural                                      := ite(databit = 0, full.WData'length, databit);
		variable temp      : T_AXI4LITE_BUS_M2S(AWAddr(addrbit - 1 downto 0), WData(databit_i - 1 downto 0), WStrb((databit_i/8) - 1 downto 0), ARAddr(addrbit - 1 downto 0));
	begin
		temp.AWValid := full.AWValid;
		temp.AWAddr  := full.AWAddr;
		temp.AWCache := full.AWCache;
		temp.AWProt  := full.AWProt;
		temp.WValid  := full.WValid;
		temp.WData   := resize(full.WData, databit_i);
		temp.WStrb   := resize(full.WStrb, databit_i/8);
		temp.BReady  := full.BReady;
		temp.ARValid := full.ARValid;
		temp.ARAddr  := full.ARAddr;
		temp.ARCache := full.ARCache;
		temp.ARProt  := full.ARProt;
		temp.RReady  := full.RReady;
		return temp;
	end function;

	function to_AXI4LITE_BUS(full : T_AXI4_BUS_S2M; databit : natural := 0) return T_AXI4LITE_BUS_S2M is
		constant databit_i : natural                                      := ite(databit = 0, full.RData'length, databit);
		variable temp      : T_AXI4LITE_BUS_S2M(RData(databit_i - 1 downto 0));
	begin
		temp.WReady  := full.WReady;
		temp.BValid  := full.BValid;
		temp.BResp   := full.BResp;
		temp.ARReady := full.ARReady;
		temp.AWReady := full.AWReady;
		temp.RValid  := full.RValid;
		temp.RData   := resize(full.RData, databit_i);
		temp.RResp   := full.RResp;
		return temp;
	end function;

	function to_AXI4_BUS(lite : T_AXI4LITE_BUS_M2S; databit : natural := 0; id_bits : positive := 1; user_bits : positive := 1) return T_AXI4_BUS_M2S is
		constant addrbit   : natural := lite.AWAddr'length;
		constant databit_i : natural := ite(databit = 0, lite.WData'length, databit);
		variable temp      : T_AXI4_BUS_M2S(AWAddr(addrbit - 1 downto 0), WData(databit_i - 1 downto 0), WStrb((databit_i/8) - 1 downto 0),
		ARAddr(addrbit - 1 downto 0), AWID(id_bits - 1 downto 0), AWUser(user_bits - 1 downto 0),
		WUser(user_bits - 1 downto 0), ARID(id_bits - 1 downto 0), ARUser(user_bits - 1 downto 0));
	begin
		temp.AWAddr   := lite.AWAddr;
		temp.AWValid  := lite.AWValid;
		temp.WValid   := lite.WValid;
		temp.WLast    := '1';
		temp.WData    := resize(lite.WData, databit_i);
		temp.WStrb    := resize(lite.WStrb, databit_i/8);
		temp.BReady   := lite.BReady;
		temp.ARValid  := lite.ARValid;
		temp.ARAddr   := lite.ARAddr;
		temp.RReady   := lite.RReady;
		temp.AWCache  := lite.AWCache;
		temp.AWProt   := lite.AWProt;
		temp.ARCache  := lite.ARCache;
		temp.ARProt   := lite.ARProt;
		temp.ARLen    := (others => '0');
		temp.AWLen    := (others => '0');
		temp.ARLock   := (others => '0');
		temp.AWLock   := (others => '0');
		temp.ARQOS    := (others => '0');
		temp.ARRegion := (others => '0');
		temp.AWQOS    := (others => '0');
		temp.AWRegion := (others => '0');
		temp.AWBurst  := C_AXI4_BURST_FIXED;
		temp.ARBurst  := C_AXI4_BURST_FIXED;
		temp.ARSize   := std_logic_vector(to_unsigned(log2ceil(ite(databit_i >= lite.WData'length, lite.WData'length, databit) /8), 3));
		temp.AWSize   := std_logic_vector(to_unsigned(log2ceil(ite(databit_i >= lite.WData'length, lite.WData'length, databit) /8), 3));
		temp.ARUser   := (others => '0');
		temp.WUser    := (others => '0');
		temp.AWUser   := (others => '0');
		temp.AWID     := (others => '0');
		temp.ARID     := (others => '0');
		return temp;
	end function;

	function to_AXI4_BUS(lite : T_AXI4LITE_BUS_S2M; databit : natural := 0; id_bits : positive := 1; user_bits : positive := 1) return T_AXI4_BUS_S2M is
		constant databit_i : natural := ite(databit = 0, lite.RData'length, databit);
		variable temp      : T_AXI4_Bus_S2M(RData(databit_i - 1 downto 0), BID(id_bits - 1 downto 0), BUser(user_bits - 1 downto 0), RID(id_bits - 1 downto 0), RUser(user_bits - 1 downto 0));
	begin
		temp.AWReady := lite.AWReady;
		temp.WReady  := lite.WReady;
		temp.BValid  := lite.BValid;
		temp.BResp   := lite.BResp;
		temp.ARReady := lite.ARReady;
		temp.RValid  := lite.RValid;
		temp.RData   := resize(lite.RData, databit_i);
		temp.RResp   := lite.RResp;
		temp.RLast   := '1';
		temp.BID     := (others => '0');
		temp.BUser   := (others => '0');
		temp.RID     := (others => '0');
		temp.RUser   := (others => '0');
		return temp;
	end function;
end package body;
