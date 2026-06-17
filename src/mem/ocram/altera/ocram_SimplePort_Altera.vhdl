-- =============================================================================
-- Authors:          Martin Zabel
--                  Patrick Lehmann
--
-- Entity:           Instantiate single-port memory on Altera FPGAs.
--
-- Description:
-- -------------------------------------
-- Quartus synthesis does not infer this RAM type correctly.
-- Instead, altsyncram is instantiated directly.
--
-- For further documentation see module "ocram_SinglePort"
-- (src/mem/ocram/ocram_SinglePort.vhdl).
--
-- License:
-- =============================================================================
-- Copyright 2008-2015 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
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

library Altera_mf;
use     Altera_mf.Altera_MF_Components.all;

use     work.config.all;
use     work.utils.all;
use     work.strings.all;


entity ocram_SimplePort_Altera is
	generic (
		ADDRESS_BITS : positive;
		DATA_BITS     : positive;
		FILENAME     : string    := ""
	);
	port (
		Clock : in  std_logic;
		ClockEnable  : in  std_logic;
		WriteEnable  : in  std_logic;
		Address      : in  unsigned(ADDRESS_BITS-1 downto 0);
		DataIn       : in  std_logic_vector(DATA_BITS-1 downto 0);
		DataOut     : out std_logic_vector(DATA_BITS-1 downto 0)
	);
end entity;


architecture rtl of ocram_SimplePort_Altera is
begin
	mem : component altsyncram
		generic map (
			address_aclr_a          => "NONE",
			indata_aclr_a            => "NONE",
			init_file                => ite((str_length(FILENAME) = 0), "UNUSED", FILENAME),
			intended_device_family  => getAlteraDeviceName(DEVICE),
			lpm_hint                => "ENABLE_RUNTIME_MOD = NO",
			lpm_type                => "altsyncram",
			numwords_a              => 2**ADDRESS_BITS,
			operation_mode          => "SINGLE_PORT",
			outdata_aclr_a          => "NONE",
			outdata_reg_a            => "UNREGISTERED",
			power_up_uninitialized  => "FALSE",
			widthad_a                => ADDRESS_BITS,
			width_a                  => DATA_BITS,
			width_byteena_a          => 1,
			wrcontrol_aclr_a        => "NONE"
		)
		port map (
			clocken0                => ClockEnable,
			wren_a                  => WriteEnable,
			clock0                  => Clock,
			address_a                => std_logic_vector(Address),
			data_a                  => DataIn,
			q_a                      => DataOut
		);
end architecture;
