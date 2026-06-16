-- =============================================================================
-- Authors:
--   Iqbal Asif (PLC2 Design GmbH)
--   Patrick Lehmann (PLC2 Design GmbH)
--   Adrian Weiland (PLC2 Design GmbH)
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

library IEEE ;
use     IEEE.std_logic_1164.all ;
use     IEEE.numeric_std.all ;
use     IEEE.numeric_std_unsigned.all ;

library OSVVM ;
context OSVVM.OsvvmContext ;

--library osvvm_Axi4;
--  context osvvm_Axi4.Axi4Context ;

library osvvm_Axi4;
context osvvm_Axi4.Axi4LiteContext ;

library PoC;
use     PoC.vectors.all;

entity AXI4Lite_OCRAM_Adapter_TestController is
	generic (
		constant OCRAM_ADDRESS_BITS : positive := 8;
		constant OCRAM_DATA_BITS    : positive := 32
	);
	port (
		-- Global Signal Interface
		Clock : in  std_logic ;
		Reset : in  std_logic ;
		-- Transaction Interfaces
		MasterRec  : inout AddressBusRecType
	);

	constant AXI_ADDR_WIDTH : integer := MasterRec.Address'length ;
	constant AXI_DATA_WIDTH : integer := MasterRec.DataToModel'length ;

	constant TCID    : AlertLogIDType := NewID("TestCtrl");
	constant TIMEOUT : time := 30 ms;
	signal TestDone  : integer_barrier := 1;

	-- access RAM through external name
	alias DATA_BITS is <<constant ^.OCRAM.gSim.sim_tdp.DATA_BITS : positive>>;  -- WORKAROUND: NVC 1.20.1 - Size of unconstrained datatype not propagated through ext. name
	alias DEPTH  is <<constant ^.OCRAM.gSim.sim_tdp.DEPTH : positive>>;   -- WORKAROUND: NVC 1.20.1 - Size of unconstrained datatype not propagated through ext. name
	alias ram    is <<signal ^.OCRAM.gSim.sim_tdp.ram : T_SLVV(0 to DEPTH - 1)(DATA_BITS - 1 downto 0)>>;

-- Not currently used in the Axi4Lite model - future use for Axi4Lite Burst Emulation modes
--  alias WriteBurstFifo is <<variable .TbAxi4.Master_1.WriteBurstFifo : osvvm.ScoreboardPkg_slv.ScoreboardPType>> ;
--  alias ReadBurstFifo  is <<variable .TbAxi4.Master_1.ReadBurstFifo  : osvvm.ScoreboardPkg_slv.ScoreboardPType>> ;
end entity;
