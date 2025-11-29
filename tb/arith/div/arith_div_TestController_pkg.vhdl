-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_div_TestController_pkg
--
-- Description:
-- -------------------------------------
-- Test controller package for arith_div
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
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

package arith_div_TestController_pkg is
  constant A_BITS  : positive := 13;
  constant D_BITS  : positive :=  4;
  constant MAX_POW : positive := 3;

  subtype tA is std_logic_vector(A_BITS-1 downto 0);
  type tA_vector is array(positive range<>) of tA;
  subtype tD is std_logic_vector(D_BITS-1 downto 0);
  type tD_vector is array(positive range<>) of tD;
end package;
