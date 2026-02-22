-- =============================================================================
-- Authors:
--   Jonas Schreiner
--
-- Description:
-- -------------------------------------
-- This package implements two procedures to split an OSVVM Axi4RecType into
-- PoC T_AXI4_BUS_M2S and T_AXI4_BUS_S2M
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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
use     IEEE.numeric_std.all;

library osvvm_axi4;
use     osvvm_axi4.Axi4InterfacePkg.all;

use     work.utils.all;
use     work.AXI4.all;
use     work.AXI4_FULL.all;


package AXI4_OSVVM is
	procedure to_PoC_AXI4_Bus_Slave(signal PoC_M2S : in T_AXI4_BUS_M2S; signal PoC_S2M : out T_AXI4_BUS_S2M; signal OSVVM_Bus : inout Axi4RecType);
	procedure to_PoC_AXI4_Bus_Master(signal PoC_M2S : out T_AXI4_BUS_M2S; signal PoC_S2M : in T_AXI4_BUS_S2M; signal OSVVM_Bus : inout Axi4RecType);
end package;


package body AXI4_OSVVM is
	procedure to_PoC_AXI4_Bus_Slave(signal PoC_M2S : in T_AXI4_BUS_M2S; signal PoC_S2M : out T_AXI4_BUS_S2M; signal OSVVM_Bus : inout Axi4RecType) is
	begin
		InitAxi4Rec (AxiBusRec => OSVVM_Bus) ;

		OSVVM_Bus.WriteAddress.ID     <= PoC_M2S.AWID;
		OSVVM_Bus.WriteAddress.Addr   <= PoC_M2S.AWAddr;
		OSVVM_Bus.WriteAddress.Len    <= PoC_M2S.AWLen;
		OSVVM_Bus.WriteAddress.Size   <= PoC_M2S.AWSize;
		OSVVM_Bus.WriteAddress.Burst  <= PoC_M2S.AWBurst;
		OSVVM_Bus.WriteAddress.Lock   <= PoC_M2S.AWLock(0);
		OSVVM_Bus.WriteAddress.QOS    <= PoC_M2S.AWQOS;
		OSVVM_Bus.WriteAddress.Region <= PoC_M2S.AWRegion;
		OSVVM_Bus.WriteAddress.User   <= PoC_M2S.AWUser;
		OSVVM_Bus.WriteAddress.Valid  <= PoC_M2S.AWValid;
		OSVVM_Bus.WriteAddress.Cache  <= PoC_M2S.AWCache;
		OSVVM_Bus.WriteAddress.Prot   <= PoC_M2S.AWProt;
		OSVVM_Bus.WriteData.Valid     <= PoC_M2S.WValid;
		OSVVM_Bus.WriteData.Last      <= PoC_M2S.WLast;
		OSVVM_Bus.WriteData.User      <= PoC_M2S.WUser;
		OSVVM_Bus.WriteData.Data      <= PoC_M2S.WData;
		OSVVM_Bus.WriteData.Strb      <= PoC_M2S.WStrb;
		OSVVM_Bus.WriteResponse.Ready <= PoC_M2S.BReady;
		OSVVM_Bus.ReadAddress.Valid   <= PoC_M2S.ARValid;
		OSVVM_Bus.ReadAddress.Addr    <= PoC_M2S.ARAddr;
		OSVVM_Bus.ReadAddress.Cache   <= PoC_M2S.ARCache;
		OSVVM_Bus.ReadAddress.Prot    <= PoC_M2S.ARProt;
		OSVVM_Bus.ReadAddress.ID      <= PoC_M2S.ARID;
		OSVVM_Bus.ReadAddress.Len     <= PoC_M2S.ARLen;
		OSVVM_Bus.ReadAddress.Size    <= PoC_M2S.ARSize;
		OSVVM_Bus.ReadAddress.Burst   <= PoC_M2S.ARBurst;
		OSVVM_Bus.ReadAddress.Lock    <= PoC_M2S.ARLock(0);
		OSVVM_Bus.ReadAddress.QOS     <= PoC_M2S.ARQOS;
		OSVVM_Bus.ReadAddress.Region  <= PoC_M2S.ARRegion;
		OSVVM_Bus.ReadAddress.User    <= PoC_M2S.ARUser;
		OSVVM_Bus.ReadData.Ready      <= PoC_M2S.RReady;
	--
		PoC_S2M.AWReady               <= OSVVM_Bus.WriteAddress.Ready;
		PoC_S2M.WReady                <= OSVVM_Bus.WriteData.Ready;
		PoC_S2M.BValid                <= OSVVM_Bus.WriteResponse.Valid;
		PoC_S2M.BResp                 <= OSVVM_Bus.WriteResponse.Resp;
		PoC_S2M.BID                   <= OSVVM_Bus.WriteResponse.ID;
		PoC_S2M.BUser                 <= OSVVM_Bus.WriteResponse.User;
		PoC_S2M.ARReady               <= OSVVM_Bus.ReadAddress.Ready;
		PoC_S2M.RValid                <= OSVVM_Bus.ReadData.Valid;
		PoC_S2M.RData                 <= OSVVM_Bus.ReadData.Data;
		PoC_S2M.RResp                 <= OSVVM_Bus.ReadData.Resp;
		PoC_S2M.RID                   <= OSVVM_Bus.ReadData.ID;
		PoC_S2M.RLast                 <= OSVVM_Bus.ReadData.Last;
		PoC_S2M.RUser                 <= OSVVM_Bus.ReadData.User;
	end procedure;

	procedure to_PoC_AXI4_Bus_Master(signal PoC_M2S : out T_AXI4_BUS_M2S; signal PoC_S2M : in T_AXI4_BUS_S2M; signal OSVVM_Bus : inout Axi4RecType) is
	begin
		InitAxi4Rec (AxiBusRec => OSVVM_Bus) ;

		PoC_M2S.AWID                  <= OSVVM_Bus.WriteAddress.ID;
		PoC_M2S.AWAddr                <= OSVVM_Bus.WriteAddress.Addr;
		PoC_M2S.AWLen                 <= OSVVM_Bus.WriteAddress.Len;
		PoC_M2S.AWSize                <= OSVVM_Bus.WriteAddress.Size;
		PoC_M2S.AWBurst               <= OSVVM_Bus.WriteAddress.Burst;
		PoC_M2S.AWLock(0)             <= OSVVM_Bus.WriteAddress.Lock;
		PoC_M2S.AWQOS                 <= OSVVM_Bus.WriteAddress.QOS;
		PoC_M2S.AWRegion              <= OSVVM_Bus.WriteAddress.Region;
		PoC_M2S.AWUser                <= OSVVM_Bus.WriteAddress.User;
		PoC_M2S.AWValid               <= OSVVM_Bus.WriteAddress.Valid;
		PoC_M2S.AWCache               <= OSVVM_Bus.WriteAddress.Cache;
		PoC_M2S.AWProt                <= OSVVM_Bus.WriteAddress.Prot;
		PoC_M2S.WValid                <= OSVVM_Bus.WriteData.Valid;
		PoC_M2S.WLast                 <= OSVVM_Bus.WriteData.Last;
		PoC_M2S.WUser                 <= OSVVM_Bus.WriteData.User;
		PoC_M2S.WData                 <= OSVVM_Bus.WriteData.Data;
		PoC_M2S.WStrb                 <= OSVVM_Bus.WriteData.Strb;
		PoC_M2S.BReady                <= OSVVM_Bus.WriteResponse.Ready;
		PoC_M2S.ARValid               <= OSVVM_Bus.ReadAddress.Valid;
		PoC_M2S.ARAddr                <= OSVVM_Bus.ReadAddress.Addr;
		PoC_M2S.ARCache               <= OSVVM_Bus.ReadAddress.Cache;
		PoC_M2S.ARProt                <= OSVVM_Bus.ReadAddress.Prot;
		PoC_M2S.ARID                  <= OSVVM_Bus.ReadAddress.ID;
		PoC_M2S.ARLen                 <= OSVVM_Bus.ReadAddress.Len;
		PoC_M2S.ARSize                <= OSVVM_Bus.ReadAddress.Size;
		PoC_M2S.ARBurst               <= OSVVM_Bus.ReadAddress.Burst;
		PoC_M2S.ARLock(0)             <= OSVVM_Bus.ReadAddress.Lock;
		PoC_M2S.ARQOS                 <= OSVVM_Bus.ReadAddress.QOS;
		PoC_M2S.ARRegion              <= OSVVM_Bus.ReadAddress.Region;
		PoC_M2S.ARUser                <= OSVVM_Bus.ReadAddress.User;
		PoC_M2S.RReady                <= OSVVM_Bus.ReadData.Ready;
		--
		OSVVM_Bus.WriteAddress.Ready  <= PoC_S2M.AWReady;
		OSVVM_Bus.WriteData.Ready     <= PoC_S2M.WReady;
		OSVVM_Bus.WriteResponse.Valid <= PoC_S2M.BValid;
		OSVVM_Bus.WriteResponse.Resp  <= PoC_S2M.BResp;
		OSVVM_Bus.WriteResponse.ID    <= PoC_S2M.BID;
		OSVVM_Bus.WriteResponse.User  <= PoC_S2M.BUser;
		OSVVM_Bus.ReadAddress.Ready   <= PoC_S2M.ARReady;
		OSVVM_Bus.ReadData.Valid      <= PoC_S2M.RValid;
		OSVVM_Bus.ReadData.Data       <= PoC_S2M.RData;
		OSVVM_Bus.ReadData.Resp       <= PoC_S2M.RResp;
		OSVVM_Bus.ReadData.ID         <= PoC_S2M.RID;
		OSVVM_Bus.ReadData.Last       <= PoC_S2M.RLast;
		OSVVM_Bus.ReadData.User       <= PoC_S2M.RUser;
	end procedure;

end package body;
