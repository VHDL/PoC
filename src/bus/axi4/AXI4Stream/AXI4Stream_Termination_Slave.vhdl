-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--                  Patrick Lehmann
--
-- Entity:				 	A slave-side bus termination module for AXI4-Stream.
--
-- Description:
-- -------------------------------------
-- This entity is a bus termination module for AXI4-Stream that represents a
-- dummy slave.
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

use     work.utils.all;
use     work.axi4stream.all;


entity AXI4Stream_Termination_Slave is
	generic (
		VALUE     : std_logic := '0'
	);
	port ( 
		-- IN Port
		In_M2S    : in  T_AXI4Stream_M2S;
		In_S2M    : out T_AXI4Stream_S2M
	);
end entity;


architecture rtl of AXI4Stream_Termination_Slave is
begin

	In_S2M <= Initialize_AXI4Stream_S2M(DataBits, UserBits, VALUE);

end architecture;
