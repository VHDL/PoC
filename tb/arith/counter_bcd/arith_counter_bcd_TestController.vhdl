-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Martin Zabel
--                  Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_counter_bcd_TestController
--
-- Description:
-- -------------------------------------
-- Test controller for arith_counter_bcd
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

library osvvm;
context osvvm.OsvvmContext;

library PoC;
use PoC.utils.all;

entity arith_counter_bcd_TestController is
  generic (
    DIGITS : positive := 3
  );
  port (
    Clock     : in  std_logic;
    Reset     : in  std_logic;
    Reset_aux : out  std_logic;
    
    -- DUT signals arith_counter_bcd
    inc     : out std_logic;
    Value   : in  T_BCD_VECTOR(DIGITS - 1 downto 0)
  );
end entity;
