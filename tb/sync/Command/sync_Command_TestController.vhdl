-- =============================================================================
-- Authors:          Patrick Lehmann
--                   Gustavo Martin
--
-- Entity:           sync_Command_TestController
--
-- Description:
-- -------------------------------------
-- OSVVM test controller entity for command signal synchronizer
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
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

library osvvm;
context osvvm.OsvvmContext;


entity sync_Command_TestController is
	port (
		Clock1  : in  std_logic;
		Clock2  : in  std_logic;
		Input   : out std_logic_vector;
		Output  : in  std_logic_vector;
		Busy    : in  std_logic;
		Changed : in  std_logic
	);
end entity;
