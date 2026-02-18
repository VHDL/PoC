-- =============================================================================
-- Authors:
--   Stefan Unrein
--   Patrick Lehmann
--   Max Kraft-Kugler
--
-- Entity: A slave-side bus termination module for AXI4 (full).
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4 (full) that represents a
-- dummy slave.
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

use     work.axi4_Full.all;
use     work.fifo.all;


entity AXI4_Termination_Subordinate is
	generic(
		RESPONSE_CODE : T_AXI4_Response := C_AXI4_RESPONSE_SLAVE_ERROR
	);
	port (
		Clock    : in std_logic;
		Reset    : in std_logic;
		AXI4_M2S : in  T_AXI4_Bus_M2S;
		AXI4_S2M : out T_AXI4_Bus_S2M
	);
end entity;


architecture rtl of AXI4_Termination_Subordinate is
	signal fifo_aw_valid : std_logic;
	signal fifo_w_valid  : std_logic;
	signal AWFull_i      : std_logic;
	signal WFull_i       : std_logic;
	signal ARFull_i      : std_logic;
begin
	AXI4_S2M.AWReady <= not AWFull_i;

	AXI4_S2M.WReady  <= not WFull_i;

	AXI4_S2M.BValid  <= fifo_aw_valid and fifo_w_valid;
	AXI4_S2M.BResp   <= RESPONSE_CODE;
	AXI4_S2M.BUser   <= (others => '0');

	AXI4_S2M.ARReady <= not ARFull_i;

	AXI4_S2M.RData   <= (others => '0');
	AXI4_S2M.RResp   <= RESPONSE_CODE;
	AXI4_S2M.RLast   <= '1';
	AXI4_S2M.RUser   <= (others => '0');

	fifo_aw: fifo_cc_got
	generic map(
		D_BITS    => AXI4_M2S.AWID'length,
		MIN_DEPTH => 4
	)
	port map(
		clk   => Clock,
		rst   => Reset,
		put   => AXI4_M2S.AWValid,
		din   => AXI4_M2S.AWID,
		full  => AWFull_i,
		got   => AXI4_M2S.BReady and fifo_w_valid,
		dout  => AXI4_S2M.BID,
		valid => fifo_aw_valid
	);

	fifo_w: fifo_cc_got
	generic map(
		D_BITS    => 1,
		MIN_DEPTH => 4
	)
	port map(
		clk   => Clock,
		rst   => Reset,
		put   => AXI4_M2S.WValid,
		din   => "0",
		full  => WFull_i,
		got   => AXI4_M2S.BReady and fifo_aw_valid,
		valid => fifo_w_valid
	);

	fifo_r: fifo_cc_got
	generic map(
		D_BITS    => AXI4_M2S.ARID'length,
		MIN_DEPTH => 4
	)
	port map(
		clk   => Clock,
		rst   => Reset,
		put   => AXI4_M2S.ARValid,
		din   => AXI4_M2S.ARID,
		full  => ARFull_i,
		got   => AXI4_M2S.RReady,
		dout  => AXI4_S2M.RID,
		valid => AXI4_S2M.RValid
	);
end architecture;
