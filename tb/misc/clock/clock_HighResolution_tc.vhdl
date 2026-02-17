-- =============================================================================
-- Authors:
--   Adrian Weiland
--
-- Entity: Test controller.
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
use     IEEE.numeric_std.all;

library PoC;
use     PoC.utils.all;
use     PoC.physical.all;
use     PoC.math.all;
use     PoC.clock.all;

library OSVVM; 
context OSVVM.OsvvmContext;

library osvvm_Axi4;
context osvvm_Axi4.Axi4LiteContext;


entity clock_HighResolution_tc is
	generic (
			CLOCK_FREQ : FREQ
		);
		port (
			Clock       : in std_logic;
			Reset       : in std_logic;
			AXI_Manager : inout AddressBusRecType;
			
			Load_nanoseconds    : out std_logic;
			Load_datetime       : out std_logic;
			Nanoseconds_to_load : out unsigned(63 downto 0);
			Datetime_to_load    : out T_CLOCK_Datetime;
			
			Nanoseconds : in unsigned(63 downto 0);
			Datetime    : in T_CLOCK_Datetime
		);
end entity;
