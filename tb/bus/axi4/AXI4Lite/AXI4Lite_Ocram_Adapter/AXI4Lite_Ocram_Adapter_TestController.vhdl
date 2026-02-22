-- =============================================================================
-- Authors:
--   Iqbal Asif (PLC2 Design GmbH)
--   Patrick Lehmann (PLC2 Design GmbH)
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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

library ieee ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;
  use ieee.numeric_std_unsigned.all ;

library OSVVM ;
  context OSVVM.OsvvmContext ;

--library osvvm_Axi4;
--  context osvvm_Axi4.Axi4Context ;

library osvvm_Axi4;
  context osvvm_Axi4.Axi4LiteContext ;

entity AXI4Lite_Ocram_Adapter_TestController is
  port (
    -- Global Signal Interface
    Clk    : in std_logic ;
    nReset : in std_logic ;
    -- Transaction Interfaces
    MasterRec  : inout AddressBusRecType
  ) ;
    constant AXI_ADDR_WIDTH : integer := MasterRec.Address'length ;
    constant AXI_DATA_WIDTH : integer := MasterRec.DataToModel'length ;

-- Not currently used in the Axi4Lite model - future use for Axi4Lite Burst Emulation modes
--  alias WriteBurstFifo is <<variable .TbAxi4.Master_1.WriteBurstFifo : osvvm.ScoreboardPkg_slv.ScoreboardPType>> ;
--  alias ReadBurstFifo  is <<variable .TbAxi4.Master_1.ReadBurstFifo  : osvvm.ScoreboardPkg_slv.ScoreboardPType>> ;
end entity;
