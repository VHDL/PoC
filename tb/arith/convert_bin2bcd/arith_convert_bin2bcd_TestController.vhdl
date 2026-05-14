-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Gustavo Martin
--
-- Entity:					arith_convert_bin2bcd_TestController
--
-- Description:
-- -------------------------------------
-- Test controller for arith_convert_bin2bcd
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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

library osvvm;
context osvvm.OsvvmContext;

library PoC;
use PoC.utils.all;

entity arith_convert_bin2bcd_TestController is
  generic (
    CONV1_BITS   : positive;
    CONV1_DIGITS : positive;
    CONV2_BITS   : positive;
    CONV2_DIGITS : positive
  );
  port (
    Clock     : in  std_logic;
    Reset     : in  std_logic;
    
    -- DUT signals
    Start           : out std_logic;
    
    Conv1_Binary    : out std_logic_vector(CONV1_BITS - 1 downto 0);
    Conv1_BCDDigits : in  T_BCD_VECTOR(CONV1_DIGITS - 1 downto 0);
    Conv1_Sign      : in  std_logic;
    
    Conv2_Binary    : out std_logic_vector(CONV2_BITS - 1 downto 0);
    Conv2_BCDDigits : in  T_BCD_VECTOR(CONV2_DIGITS - 1 downto 0);
    Conv2_Sign      : in  std_logic
  );
end entity;
