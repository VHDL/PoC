-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Stefan Unrein, Max Kraft-Kugler
--
-- Entity:          A slave-side bus termination module for AXI4-Lite.
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4-Lite that represents a
-- dummy slave.
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
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

use     work.axi4lite.all;
use     work.fifo.all;


entity AXI4Lite_Termination_Subordinate is
	generic(
		RESPONSE_CODE : T_AXI4_Response := C_AXI4_RESPONSE_SLAVE_ERROR
	);
	port (
		Clock        : in std_logic;
		Reset        : in std_logic;
		AXI4Lite_M2S : in  T_AXI4LITE_BUS_M2S;
		AXI4Lite_S2M : out T_AXI4LITE_BUS_S2M
	);
end entity;


architecture rtl of AXI4Lite_Termination_Subordinate is
	signal fifo_aw_valid : std_logic;
	signal fifo_w_valid  : std_logic;
	signal AWFull_i      : std_logic;
	signal WFull_i       : std_logic;
	signal ARFull_i      : std_logic;
begin
	AXI4Lite_S2M.AWReady <= not AWFull_i;

	AXI4Lite_S2M.WReady  <= not WFull_i;

	AXI4Lite_S2M.BValid  <= fifo_aw_valid and fifo_w_valid;
	AXI4Lite_S2M.BResp   <= RESPONSE_CODE;

	AXI4Lite_S2M.ARReady <= not ARFull_i;

	AXI4Lite_S2M.RData   <= (others => '0');
	AXI4Lite_S2M.RResp   <= RESPONSE_CODE;

	fifo_aw: fifo_cc_got
	generic map(
		D_BITS    => 1,
		MIN_DEPTH => 4
	)
	port map(
		clk   => Clock,
		rst   => Reset,
		put   => AXI4Lite_M2S.AWValid,
		din   => "0",
		full  => AWFull_i,
		got   => AXI4Lite_M2S.BReady and fifo_w_valid,
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
		put   => AXI4Lite_M2S.WValid,
		din   => "0",
		full  => WFull_i,
		got   => AXI4Lite_M2S.BReady and fifo_aw_valid,
		valid => fifo_w_valid
	);

	fifo_r: fifo_cc_got
	generic map(
		D_BITS    => 1,
		MIN_DEPTH => 4
	)
	port map(
		clk   => Clock,
		rst   => Reset,
		din   => "0",
		put   => AXI4Lite_M2S.ARValid,
		full  => ARFull_i,
		got   => AXI4Lite_M2S.RReady,
		valid => AXI4Lite_S2M.RValid
	);
end architecture;
