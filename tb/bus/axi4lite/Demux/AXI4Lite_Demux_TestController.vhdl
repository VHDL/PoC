-- =============================================================================
-- Authors:
--  Iqbal Asif (PLC2 Design GmbH)
--  Patrick Lehmann (PLC2 Design GmbH)
--
-- License:
-- =============================================================================
-- Copyright 2026 The PoC-Library Authors
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

library IEEE ;
use     IEEE.std_logic_1164.all ;
use     IEEE.numeric_std.all ;
use     IEEE.numeric_std_unsigned.all ;

library OSVVM ;
context OSVVM.OsvvmContext ;

library osvvm_Axi4;
context osvvm_Axi4.Axi4LiteContext ;

entity AXI4Lite_Demux_TestController is
	port (
		-- Global Signal Interface
		Clk    : in  std_logic ;
		nReset : in  std_logic ;
		-- Transaction Interfaces
		ManagerRec     : inout AddressBusRecType;
		SubordinateRec : inout AddressBusRecArrayType
	) ;
	constant AXI_ADDR_WIDTH : integer  := ManagerRec.Address'length ;
	constant AXI_DATA_WIDTH : integer  := ManagerRec.DataToModel'length ;
	constant CHANNELS       : positive := SubordinateRec'length;

end entity;
