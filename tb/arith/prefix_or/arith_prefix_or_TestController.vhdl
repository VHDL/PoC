-- =============================================================================
-- Authors:			Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:			arith_prefix_or_TestController
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


entity arith_prefix_or_TestController is
	port (
		Clock : in  std_logic;
		Reset : in  std_logic;
		x     : out std_logic_vector;
		y     : in  std_logic_vector
	);
end entity;
