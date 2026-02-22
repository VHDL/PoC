-- =============================================================================
-- Authors:
--   Adrian Weiland
--
-- Package: Variables and types needed for testing.
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
use     PoC.vectors.all;


package axi4lite_HighResolutionClock_tb_pkg is
	constant AXI_ADDR_WIDTH : integer := 32;
	constant AXI_DATA_WIDTH : integer := 32;
	constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH / 8;
	
	subtype AXIAddressType is std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
	subtype AXIDataType    is std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

	-- Register addresses
	constant Reg_reserved                  : AXIAddressType := 32x"00";
	constant Reg_Config_reg                : AXIAddressType := 32x"04";
	constant Reg_Nanoseconds_lower         : AXIAddressType := 32x"08";
	constant Reg_Nanoseconds_upper         : AXIAddressType := 32x"0C";
	constant Reg_Time_HMS                  : AXIAddressType := 32x"10";
	constant Reg_Date_Ymd                  : AXIAddressType := 32x"14";
	constant Reg_Time_sec_res              : AXIAddressType := 32x"18";
	constant Reg_Nanoseconds_to_load_lower : AXIAddressType := 32x"20";
	constant Reg_Nanoseconds_to_load_upper : AXIAddressType := 32x"24";
	constant Reg_Datetime_to_load_HMS      : AXIAddressType := 32x"28";
	constant Reg_Datetime_to_load_Ymd      : AXIAddressType := 32x"2C";

end package;

package body axi4lite_HighResolutionClock_tb_pkg is
end package body;
