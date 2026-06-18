-- =============================================================================
-- Authors:         Stefan Unrein
--                  Patrick Lehmann
--
-- Entity:          A master-side bus termination module for AXI4-Stream.
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4-Stream that represents a
-- dummy master.
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
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.axi4stream.all;


entity axi4stream_Termination_Transmitter is
	generic (
		VALUE     : std_logic := '0'
	);
	port (
		-- OUT Port
		Out_M2S   : out T_AXI4Stream_M2S;
		Out_S2M   : in  T_AXI4Stream_S2M
	);
end entity;


architecture rtl of axi4stream_Termination_Transmitter is
	constant DataBits : natural := Out_M2S.Data'length;
	constant UserBits : natural := Out_M2S.User'length;
	constant DestBits : natural := Out_M2S.Dest'length;
	constant IDBits   : natural := Out_M2S.ID'length;
begin

	Out_M2S <= Initialize_AXI4Stream_M2S(DataBits, UserBits, DestBits, IDBits, VALUE);

end architecture;
