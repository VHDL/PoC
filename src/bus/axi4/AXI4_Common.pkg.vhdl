-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:          Generic AMBA AXI4-Lite bus description
--
-- Description:
-- -------------------------------------
-- This package implements a constants and subtypes necessary for AMBA AXI4 bus.
--
--
-- License:
-- =============================================================================
-- Copyright 2017-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;


package AXI4_Common is
	subtype T_AXI4_Response is std_logic_vector(1 downto 0);
	constant C_AXI4_RESPONSE_OKAY         : T_AXI4_Response := "00";
	constant C_AXI4_RESPONSE_EX_OKAY      : T_AXI4_Response := "01";
	constant C_AXI4_RESPONSE_SLAVE_ERROR  : T_AXI4_Response := "10";
	constant C_AXI4_RESPONSE_DECODE_ERROR : T_AXI4_Response := "11";
	constant C_AXI4_RESPONSE_INIT         : T_AXI4_Response := "ZZ";

	subtype T_AXI4_Cache is std_logic_vector(3 downto 0);
	constant C_AXI4_CACHE_INIT : T_AXI4_Cache := "ZZZZ";
	constant C_AXI4_CACHE      : T_AXI4_Cache := "0011";

	subtype T_AXI4_QoS is std_logic_vector(3 downto 0);
	constant C_AXI4_QOS_INIT : T_AXI4_QoS := "ZZZZ";

	subtype T_AXI4_Region is std_logic_vector(3 downto 0);
	constant C_AXI4_REGION_INIT : T_AXI4_Region := "ZZZZ";

	subtype T_AXI4_Size is std_logic_vector(2 downto 0);
	constant C_AXI4_SIZE_1    : T_AXI4_Size := "000";
	constant C_AXI4_SIZE_2    : T_AXI4_Size := "001";
	constant C_AXI4_SIZE_4    : T_AXI4_Size := "010";
	constant C_AXI4_SIZE_8    : T_AXI4_Size := "011";
	constant C_AXI4_SIZE_16   : T_AXI4_Size := "100";
	constant C_AXI4_SIZE_32   : T_AXI4_Size := "101";
	constant C_AXI4_SIZE_64   : T_AXI4_Size := "110";
	constant C_AXI4_SIZE_128  : T_AXI4_Size := "111";
	constant C_AXI4_SIZE_INIT : T_AXI4_Size := "ZZZ";

	subtype T_AXI4_Burst is std_logic_vector(1 downto 0);
	constant C_AXI4_BURST_FIXED : T_AXI4_Burst := "00";
	constant C_AXI4_BURST_INCR  : T_AXI4_Burst := "01";
	constant C_AXI4_BURST_WRAP  : T_AXI4_Burst := "10";
	constant C_AXI4_BURST_INIT  : T_AXI4_Burst := "ZZ";

	subtype T_AXI4_Protect is std_logic_vector(2 downto 0);
	-- Bit 0: 0 Unprivileged access   1 Privileged access
	-- Bit 1: 0 Secure access         1 Non-secure access
	-- Bit 2: 0 Data access           1 Instruction access
	constant C_AXI4_PROTECT_INIT : T_AXI4_Protect := "ZZZ";
	constant C_AXI4_PROTECT      : T_AXI4_Protect := "000";
end package;
