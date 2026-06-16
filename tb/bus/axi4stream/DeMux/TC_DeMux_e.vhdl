-- =============================================================================
-- Authors:
--
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

library IEEE ;
use     IEEE.std_logic_1164.all ;
use     IEEE.numeric_std.all ;

library PoC;
use     PoC.stream.all;

library OSVVM ;
context OSVVM.OsvvmContext ;
use     OSVVM.ScoreBoardPkg_slv.all;

library OSVVM_AXI4;
context OSVVM_AXI4.AxiStreamContext;


entity TestControl is
	generic (
		MIN_PACKET_SIZE    : positive := 1;
		MAX_PACKET_SIZE    : positive := 500;
		NUM_PACKETS        : positive := 15;
		MIN_WAIT_CYCLE     : natural  := 1;
		MAX_WAIT_CYCLE     : natural  := 1000;
		MIN_BACKPRESS_CYCLE: natural  := 1;
		MAX_BACKPRESS_CYCLE: natural  := 500
	);
	port (
		-- Global Signal Interface
		Clock_sys           : In    std_logic ;
		Reset_sys           : In    std_logic ;

		Stream_RX_Pause     : out std_logic_vector;
		Hit_Vector          : out std_logic_vector;

		Stream_TX_Transaction       : inout StreamRecType;
		Stream_RX_Transaction       : inout StreamRecArrayType
	);
end entity;
