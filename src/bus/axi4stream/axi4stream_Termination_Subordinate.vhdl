-- =============================================================================
-- Authors:         Stefan Unrein
--                  Patrick Lehmann
--
-- Entity:          A slave-side bus termination module for AXI4-Stream.
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4-Stream that represents a
-- dummy slave.
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
use     IEEE.std_logic_1164.all;

use     work.utils.all;
use     work.axi4stream.all;


entity axi4stream_Termination_Subordinate is
	generic (
		VALUE     : std_logic := '0'
	);
	port (
		-- IN Port
		In_M2S    : in  T_AXI4Stream_M2S;
		In_S2M    : out T_AXI4Stream_S2M
	);
end entity;


architecture rtl of axi4stream_Termination_Subordinate is
  constant DataBits : natural := In_M2S.Data'length;
  constant UserBits : natural := In_M2S.User'length;
begin

	In_S2M <= Initialize_AXI4Stream_S2M(UserBits, VALUE);

end architecture;
