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


entity AXI4Lite_ErrorFilter is
	generic(
		Read_Data_on_Error      : std_logic_vector;
		Insert_Error_Code       : boolean
	);
	port (
		S_AXI_m2s               : in  T_AXI4Lite_BUS_M2S;
		S_AXI_s2m               : out T_AXI4Lite_BUS_S2M;
		
    M_AXI_m2s               : out T_AXI4Lite_BUS_M2S;
    M_AXI_s2m               : in  T_AXI4Lite_BUS_S2M;
		Read_Error              : out std_logic;
		Read_Error_Code         : out std_logic_vector(1 downto 0);
		Write_Error             : out std_logic;
		Write_Error_Code        : out std_logic_vector(1 downto 0)
	);
end entity;


architecture rtl of AXI4Lite_ErrorFilter is
	signal is_rerror : std_logic;
	signal is_werror : std_logic;
begin
	Read_Error  <= is_rerror;
	Write_Error <= is_werror;
	
	is_rerror   <= '1' when M_AXI_s2m.RResp /= C_AXI4_RESPONSE_OKAY else '0';
	Read_Error_Code <= M_AXI_s2m.RResp;
	is_werror   <= '1' when M_AXI_s2m.BResp /= C_AXI4_RESPONSE_OKAY else '0';
	Write_Error_Code <= M_AXI_s2m.BResp;
	
  --SLAVE
  S_AXI_s2m.WReady     <= M_AXI_s2m.WReady ;
	S_AXI_s2m.BValid     <= M_AXI_s2m.BValid ;
	S_AXI_s2m.ARReady    <= M_AXI_s2m.ARReady;
	S_AXI_s2m.AWReady    <= M_AXI_s2m.AWReady;
	S_AXI_s2m.RValid     <= M_AXI_s2m.RValid ;

	--MASTER
	M_AXI_m2s.AWValid    <= S_AXI_m2s.AWValid ;
	M_AXI_m2s.AWAddr     <= S_AXI_m2s.AWAddr  ;
  M_AXI_m2s.AWCache    <= S_AXI_m2s.AWCache ;
	M_AXI_m2s.AWProt     <= S_AXI_m2s.AWProt  ;
	M_AXI_m2s.WValid     <= S_AXI_m2s.WValid  ;
	M_AXI_m2s.WData      <= S_AXI_m2s.WData   ;
	M_AXI_m2s.WStrb      <= S_AXI_m2s.WStrb   ;
	M_AXI_m2s.BReady     <= S_AXI_m2s.BReady  ;
	M_AXI_m2s.ARValid    <= S_AXI_m2s.ARValid ;
	M_AXI_m2s.ARAddr     <= S_AXI_m2s.ARAddr  ;
  M_AXI_m2s.ARCache    <= S_AXI_m2s.ARCache ;
	M_AXI_m2s.ARProt     <= S_AXI_m2s.ARProt  ;
	M_AXI_m2s.RReady     <= S_AXI_m2s.RReady  ;
	
	process(all)
	begin
		S_AXI_s2m.RResp      <= M_AXI_s2m.RResp;
		S_AXI_s2m.BResp      <= M_AXI_s2m.BResp;
		S_AXI_s2m.RData      <= M_AXI_s2m.RData;
		
		if is_rerror /= '0' then
			S_AXI_s2m.RResp      <= C_AXI4_RESPONSE_OKAY;
			for i in S_AXI_s2m.RData'high downto 2 loop
				S_AXI_s2m.RData(i) <= Read_Data_on_Error(i);
			end loop;
			if Insert_Error_Code then
				S_AXI_s2m.RData(1 downto 0) <= M_AXI_s2m.RResp;
			else
				S_AXI_s2m.RData(0) <= Read_Data_on_Error(0);
				S_AXI_s2m.RData(1) <= Read_Data_on_Error(1);
			end if;
		end if;
		if is_werror /= '0' then
			S_AXI_s2m.BResp      <= C_AXI4_RESPONSE_OKAY;
		end if;
	end process;
end architecture;


