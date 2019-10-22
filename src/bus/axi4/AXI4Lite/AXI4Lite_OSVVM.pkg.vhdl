-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	Generic AMBA AXI4-Lite bus description
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4-Lite description.
--
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
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.AXI4Lite.all;

library OSVVM_AXI4;
use     OSVVM_AXI4.Axi4LiteInterfacePkg.all;

package AXI4Lite_OSVVM is

	procedure to_PoC_XI4Lite_Bus_Slave(signal PoC_M2S : in T_AXI4LITE_BUS_M2S; signal PoC_S2M : out T_AXI4LITE_BUS_S2M; signal OSVVM_Bus : inout Axi4LiteRecType);

	procedure to_PoC_XI4Lite_Bus_Master(signal PoC_M2S : out T_AXI4LITE_BUS_M2S; signal PoC_S2M : in T_AXI4LITE_BUS_S2M; signal OSVVM_Bus : inout Axi4LiteRecType);

end package;

package body AXI4Lite_OSVVM is

		procedure to_PoC_AXI4Lite_Bus_Slave(signal PoC_M2S : in T_AXI4LITE_BUS_M2S; signal PoC_S2M : out T_AXI4LITE_BUS_S2M; signal OSVVM_Bus : inout Axi4LiteRecType) is
		begin
			OSVVM_Bus.WriteAddress.AWValid <= PoC_M2S.AWValid;
			OSVVM_Bus.WriteAddress.AWAddr  <= PoC_M2S.AWAddr ;
			-- OSVVM_Bus.WriteAddress.AWCache <= PoC_M2S.AWCache;
			OSVVM_Bus.WriteAddress.AWProt  <= PoC_M2S.AWProt ;
			OSVVM_Bus.WriteData.WValid     <= PoC_M2S.WValid ;
			OSVVM_Bus.WriteData.WData      <= PoC_M2S.WData  ;
			OSVVM_Bus.WriteData.WStrb      <= PoC_M2S.WStrb  ;
			OSVVM_Bus.WriteResponse.BReady <= PoC_M2S.BReady ;
			OSVVM_Bus.ReadAddress.ARValid  <= PoC_M2S.ARValid;
			OSVVM_Bus.ReadAddress.ARAddr   <= PoC_M2S.ARAddr ;
			-- OSVVM_Bus.ReadAddress.ARCache <= PoC_M2S.ARCache;
			OSVVM_Bus.ReadAddress.ARProt   <= PoC_M2S.ARProt ;
			OSVVM_Bus.ReadData.RReady      <= PoC_M2S.RReady ;
			
			PoC_S2M.AWReady <= OSVVM_Bus.WriteAddress.AWReady;
			PoC_S2M.WReady  <= OSVVM_Bus.WriteData.WReady    ;
			PoC_S2M.BValid  <= OSVVM_Bus.WriteResponse.BValid;
			PoC_S2M.BResp   <= OSVVM_Bus.WriteResponse.BResp ;
			PoC_S2M.ARReady <= OSVVM_Bus.ReadAddress.ARReady ;
			PoC_S2M.RValid  <= OSVVM_Bus.ReadData.RValid     ;
			PoC_S2M.RData   <= OSVVM_Bus.ReadData.RData      ;
			PoC_S2M.RResp   <= OSVVM_Bus.ReadData.RResp      ;
		end procedure;
		
		procedure to_PoC_AXI4Lite_Bus_Master(signal PoC_M2S : out T_AXI4LITE_BUS_M2S; signal PoC_S2M : in T_AXI4LITE_BUS_S2M; signal OSVVM_Bus : inout Axi4LiteRecType) is
		begin
			PoC_M2S.AWValid <= OSVVM_Bus.WriteAddress.AWValid;
			PoC_M2S.AWAddr  <= OSVVM_Bus.WriteAddress.AWAddr ;
			-- PoC_M2S.AWCache <= OSVVM_Bus.WriteAddress.AWCache;
			PoC_M2S.AWProt  <= OSVVM_Bus.WriteAddress.AWProt ;
			PoC_M2S.WValid  <= OSVVM_Bus.WriteData.WValid    ;
			PoC_M2S.WData   <= OSVVM_Bus.WriteData.WData     ;
			PoC_M2S.WStrb   <= OSVVM_Bus.WriteData.WStrb     ;
			PoC_M2S.BReady  <= OSVVM_Bus.WriteResponse.BReady;
			PoC_M2S.ARValid <= OSVVM_Bus.ReadAddress.ARValid ;
			PoC_M2S.ARAddr  <= OSVVM_Bus.ReadAddress.ARAddr  ;
			-- PoC_M2S.ARCache <= OSVVM_Bus.ReadAddress.ARCache ;
			PoC_M2S.ARProt  <= OSVVM_Bus.ReadAddress.ARProt  ;
			PoC_M2S.RReady  <= OSVVM_Bus.ReadData.RReady     ;
			
			OSVVM_Bus.WriteAddress.AWReady <= PoC_S2M.AWReady;
			OSVVM_Bus.WriteData.WReady     <= PoC_S2M.WReady ;
			OSVVM_Bus.WriteResponse.BValid <= PoC_S2M.BValid ;
			OSVVM_Bus.WriteResponse.BResp  <= PoC_S2M.BResp  ;
			OSVVM_Bus.ReadAddress.ARReady  <= PoC_S2M.ARReady;
			OSVVM_Bus.ReadData.RValid      <= PoC_S2M.RValid ;
			OSVVM_Bus.ReadData.RData       <= PoC_S2M.RData  ;
			OSVVM_Bus.ReadData.RResp       <= PoC_S2M.RResp  ;
		end procedure;
		
end package body;
