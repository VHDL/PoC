-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	Truncate address bits in an AXI4-Lite bus.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
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
use     IEEE.std_logic_1164.all;

use     work.utils.all;
use     work.axi4lite.all;


entity AXI4Lite_AddressTruncate is
	port (
		S_AXI_m2s               : in  T_AXI4Lite_BUS_M2S;
		S_AXI_s2m               : out T_AXI4Lite_BUS_S2M;
		
    M_AXI_m2s               : out T_AXI4Lite_BUS_M2S;
    M_AXI_s2m               : in  T_AXI4Lite_BUS_S2M
	);
end entity;


architecture rtl of AXI4Lite_AddressTruncate is
  constant ADDR_IN_BITS  : positive := S_AXI_m2s.AWAddr'length;
  constant ADDR_OUT_BITS : positive := M_AXI_m2s.AWAddr'length;

begin
  --SLAVE
  S_AXI_s2m.WReady     <= M_AXI_s2m.WReady ;
	S_AXI_s2m.BValid     <= M_AXI_s2m.BValid ;
	S_AXI_s2m.BResp      <= M_AXI_s2m.BResp  ;
	S_AXI_s2m.ARReady    <= M_AXI_s2m.ARReady;
	S_AXI_s2m.AWReady    <= M_AXI_s2m.AWReady;
	S_AXI_s2m.RValid     <= M_AXI_s2m.RValid ;
	S_AXI_s2m.RData      <= M_AXI_s2m.RData  ;
	S_AXI_s2m.RResp      <= M_AXI_s2m.RResp  ;

	--MASTER
	M_AXI_m2s.AWValid    <= S_AXI_m2s.AWValid ;
	M_AXI_m2s.AWAddr     <= ite(    ADDR_OUT_BITS > ADDR_IN_BITS, 
                                  (ADDR_IN_BITS - ADDR_OUT_BITS - 1 downto 0 => '0') & S_AXI_m2s.AWAddr, 
                                  S_AXI_m2s.AWAddr(ADDR_OUT_BITS - 1 downto 0));
  M_AXI_m2s.AWCache    <= S_AXI_m2s.AWCache ;
	M_AXI_m2s.AWProt     <= S_AXI_m2s.AWProt  ;
	M_AXI_m2s.WValid     <= S_AXI_m2s.WValid  ;
	M_AXI_m2s.WData      <= S_AXI_m2s.WData   ;
	M_AXI_m2s.WStrb      <= S_AXI_m2s.WStrb   ;
	M_AXI_m2s.BReady     <= S_AXI_m2s.BReady  ;
	M_AXI_m2s.ARValid    <= S_AXI_m2s.ARValid ;
	M_AXI_m2s.ARAddr     <= ite(    ADDR_OUT_BITS > ADDR_IN_BITS, 
                                  (ADDR_IN_BITS - ADDR_OUT_BITS - 1 downto 0 => '0') & S_AXI_m2s.AWAddr, 
                                  S_AXI_m2s.AWAddr(ADDR_OUT_BITS - 1 downto 0));
  M_AXI_m2s.ARCache    <= S_AXI_m2s.ARCache ;
	M_AXI_m2s.ARProt     <= S_AXI_m2s.ARProt  ;
	M_AXI_m2s.RReady     <= S_AXI_m2s.RReady  ;
end architecture;
