-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_div_TestController
--
-- Description:
-- -------------------------------------
-- Test controller for arith_div
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
use     IEEE.numeric_std.all;

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.strings.all;

library osvvm;
context osvvm.OsvvmContext;

library tb_arith;
use     tb_arith.arith_div_TestController_pkg.all;

entity arith_div_TestController is
  port (
    Clock : in std_logic;
    Reset : in std_logic;

    Start : out std_logic;
    Ready : in  std_logic_vector(1 to 2*MAX_POW);
    A     : out std_logic_vector(A_BITS-1 downto 0);
    D     : out std_logic_vector(D_BITS-1 downto 0);
    Q     : in  T_SLVV(1 to 2*MAX_POW)(A_BITS-1 downto 0);
    R     : in  T_SLVV(1 to 2*MAX_POW)(D_BITS-1 downto 0);
    Z     : in  std_logic_vector(1 to 2*MAX_POW)
  );
end entity;
