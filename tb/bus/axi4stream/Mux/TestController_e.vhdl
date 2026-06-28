-- =============================================================================
-- Authors:         Iqbal Asif
--
--
-- Entity:          TestController for a AXI4 stream multiplexer.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
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

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;
use     IEEE.math_real.all;

library OSVVM;
context OSVVM.OsvvmContext;
use     osvvm.ScoreboardPkg_slv.all;

library OSVVM_AXI4;
context OSVVM_AXI4.Axi4Context;

entity TestController is
	generic (
		ID_LEN     : natural;
		DEST_LEN   : natural;
		USER_LEN   : natural
	);
	port (
		-- Global Signal Interface
		Reset : in std_logic;

		-- Transaction Interfaces
		StreamTxRec  : inout StreamRecArrayType;
		StreamRxRec  : inout StreamRecType
	);

	constant DEST_PORTS : positive := StreamTxRec'length;
	constant DATA_WIDTH : positive := StreamTxRec(0).DataToModel'length;
	constant DATA_BYTES : positive := DATA_WIDTH/8;

end entity TestController;
