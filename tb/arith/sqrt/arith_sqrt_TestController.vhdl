-- =============================================================================
-- Authors:					Gustavo Martin
--
-- Entity:					arith_sqrt_TestController
--
-- Description:
-- -------------------------------------
-- Test controller for arith_sqrt component
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

library IEEE;
use     IEEE.std_logic_1164.all;

library osvvm;
context osvvm.OsvvmContext;


entity arith_sqrt_TestController is
	port (
		Clock : in  std_logic;
		Reset : in  std_logic;
		arg   : out std_logic_vector;
		start : out std_logic := '0';
		sqrt  : in  std_logic_vector;
		rdy   : in  std_logic
	);
end entity;
