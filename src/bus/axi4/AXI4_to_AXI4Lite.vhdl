-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:.
--
-- Description:
-- -------------------------------------
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
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

use			work.utils.all;
use			work.vectors.all;
use			work.components.all;
use			work.axi4_Full.all;
use			work.axi4Lite.all;


entity AXI4_to_AXI4Lite is
	generic (
		RESPONSE_FIFO_DEPTH : positive := 16 --Using SRL16E, depth is maximum 16
	);
	port (
		Clock             : in  std_logic;
		Reset             : in  std_logic;
		-- IN Port
		In_M2S            : in  T_AXI4_Bus_M2S;
		In_S2M            : out T_AXI4_Bus_S2M;
		-- OUT Port
		Out_M2S           : out T_AXI4Lite_Bus_M2S;
		Out_S2M           : in  T_AXI4Lite_Bus_S2M
	);
end entity;


architecture rtl of AXI4_to_AXI4Lite is
	signal Response_B_fifo_ful  : std_logic;
	signal Response_R_fifo_ful  : std_logic;
begin


	Out_M2S.AWValid     <= In_M2S.AWValid and not Response_B_fifo_ful;
	Out_M2S.AWAddr      <= resize(In_M2S.AWAddr, Out_M2S.AWAddr'length) ;
	Out_M2S.AWCache     <= In_M2S.AWCache;
	Out_M2S.AWProt      <= In_M2S.AWProt ;
	Out_M2S.WValid      <= In_M2S.WValid ;
	Out_M2S.WData       <= In_M2S.WData;
	Out_M2S.WStrb       <= In_M2S.WStrb;
	Out_M2S.BReady      <= In_M2S.BReady ;
	Out_M2S.ARValid     <= In_M2S.ARValid and not Response_R_fifo_ful;
	Out_M2S.ARAddr      <= resize(In_M2S.ARAddr, Out_M2S.ARAddr'length) ;
	Out_M2S.ARCache     <= In_M2S.ARCache;
	Out_M2S.ARProt      <= In_M2S.ARProt ;
	Out_M2S.RReady      <= In_M2S.RReady ;

	In_S2M.AWReady     <= Out_S2M.AWReady and not Response_B_fifo_ful;
	In_S2M.WReady      <= Out_S2M.WReady ;
	In_S2M.BValid      <= Out_S2M.BValid ;
	In_S2M.BResp       <= Out_S2M.BResp  ;
	In_S2M.ARReady     <= Out_S2M.ARReady and not Response_R_fifo_ful;
	In_S2M.RValid      <= Out_S2M.RValid ;
	In_S2M.RData       <= Out_S2M.RData;
	In_S2M.RResp       <= Out_S2M.RResp  ;
	In_S2M.RLast       <= '1';

	In_S2M.BUser       <= (others => '0');
	In_S2M.RUser       <= (others => '0');

	Response_R_fifo : entity work.fifo_shift
	generic map(
		D_BITS    => In_M2S.AWID'length,
		MIN_DEPTH => RESPONSE_FIFO_DEPTH
	)
	port map(
		-- Global Control
		clk => Clock,
		rst => Reset,

		-- Writing Interface
		put => In_M2S.ARValid and Out_S2M.ARReady and not Response_R_fifo_ful,
		din => In_M2S.ARID,
		ful => Response_R_fifo_ful,

		-- Reading Interface
		got  => Out_S2M.RValid and In_M2S.RReady,
		dout => In_S2M.RID,
		vld  => open
	);

	Response_B_fifo : entity work.fifo_shift
	generic map(
		D_BITS    => In_M2S.AWID'length,
		MIN_DEPTH => RESPONSE_FIFO_DEPTH
	)
	port map(
		-- Global Control
		clk => Clock,
		rst => Reset,

		-- Writing Interface
		put => In_M2S.AWValid and Out_S2M.AWReady and not Response_B_fifo_ful,
		din => In_M2S.AWID,
		ful => Response_B_fifo_ful,

		-- Reading Interface
		got  => Out_S2M.BValid and In_M2S.BReady,
		dout => In_S2M.BID,
		vld  => open
	);


end architecture;
