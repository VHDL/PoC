-- =============================================================================
-- Authors:           Stefan Unrein
--
-- Entity:            AXI4 Lite De-Multiplexer
--
-- Description:
-- -------------------------------------
-- This module provides a demultiplexing functionality for AXI4 busses.
-- Based on the provided address on write or read channels, the packets are
-- forwarded to the matching output interface. The address of the connected
-- subordinates is defined by the BASE_ADDRESS and the corresponding
-- BASE_ADDRESS_MASK. Every transaction not matching any outputs is internally
-- discarted and a decode-error response is generated.
-- PIPELINE_IN and PIPELINE_OUT provide the settings for input and ouput
-- pipelining stages as a timing relaxantion setting.
--
-- Example configuration:
-- 3 Subordinates with 512kB each, starting at 0x0008_0000
-- BASE_ADDRESS => (0 => 32x"x0008_0000", 1 => 32x"x0009_0000", 2 => 32x"x000A_0000")
-- BASE_ADDRESS_MASK => (0 to 2 => 32x"x0007_FFFF")
--
-- Utilization compared to Xilinx Crossbar (2.1) 1 Slave => 4 Master (32 Addr/Data)
-- | LUT  | FF   | Comment        |
-- | ---- | ---- | -------------- |
-- | 104  | 126  | Xilinx Crosbar |
-- | 193  | 46   | 0 Glue         |
-- | 452  | 1191 | 1 Glue         |
--
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.components.all;
use     work.axi4.all;
use     work.axi4_Full.all;
use     work.axi4lite.all;


entity axi4lite_DeMux is
	generic(
		BASE_ADDRESS      : T_SLUV;
		BASE_ADDRESS_MASK : BASE_ADDRESS'subtype;
		PIPELINE_IN       : natural                       := 0;
		PIPELINE_OUT      : natural_vector(BASE_ADDRESS'range)  := (others => 0)
	);
	port (
		Clock             : in  std_logic;
		Reset             : in  std_logic;
		-- IN Port
		In_M2S            : in  T_AXI4Lite_Bus_M2S;
		In_S2M            : out T_AXI4Lite_Bus_S2M;
		-- OUT Port
		Out_M2S           : out T_AXI4Lite_Bus_M2S_VECTOR;
		Out_S2M           : in  T_AXI4Lite_Bus_S2M_VECTOR
	);
end entity;


architecture rtl of axi4lite_DeMux is
	package full_record is
		new work.AXI4Full_Sized
			generic map(
				ADDRESS_BITS  => In_M2S.AWAddr'length,
				DATA_BITS     => In_M2S.WData'length
			);
	signal In_M2S_full            : full_record.Sized_M2S;
	signal In_S2M_full            : full_record.Sized_S2M;
	signal Out_M2S_full           : full_record.Sized_M2S_Vector(Out_M2S'range);
	signal Out_S2M_full           : full_record.Sized_S2M_Vector(Out_M2S'range);


begin
	In_M2S_full <= to_AXI4_BUS(In_M2S);
	In_S2M      <= to_AXI4LITE_BUS(In_S2M_full);

	assign_gen : for i in Out_M2S'range generate
		Out_M2S(i)      <= to_AXI4LITE_BUS(Out_M2S_full(i));
		Out_S2M_full(i) <= to_AXI4_BUS(Out_S2M(i));
	end generate;

	Full_DeMux : entity work.axi4_DeMux
	generic map(
		BASE_ADDRESS           => BASE_ADDRESS,
		BASE_ADDRESS_MASK      => BASE_ADDRESS_MASK,
		PIPELINE_IN            => PIPELINE_IN,
		PIPELINE_OUT           => PIPELINE_OUT,
		NUM_OUTSTANDING_READS  => 1,
		NUM_OUTSTANDING_WRITES => 1
	)
	port map(
		Clock             => Clock,
		Reset             => Reset,
		-- IN Port
		In_M2S            => In_M2S_full,
		In_S2M            => In_S2M_full,
		-- OUT Port
		Out_M2S           => Out_M2S_full,
		Out_S2M           => Out_S2M_full
	);
end architecture;
