-- =============================================================================
-- Authors:
--
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

library IEEE;
use     IEEE.std_logic_1164.ALL;
use     IEEE.numeric_std.ALL;

library OSVVM_AXI4 ;
context OSVVM_AXI4.Axi4Context;

entity TestControl is
	generic (
		AXI_ADDR_WIDTH : natural;
		AXI_DATA_WIDTH : natural
	);
	port (
		Clock         : in  std_logic;
		Reset         : in  std_logic;

		AXI4_Manager_Transaction     : inout AddressBusRecArrayType;
		AXI4_Subordinate_Transaction : inout AddressBusRecType
	);
end entity;
