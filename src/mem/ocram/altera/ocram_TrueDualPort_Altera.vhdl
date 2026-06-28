-- =============================================================================
-- Authors:         Martin Zabel
--                  Patrick Lehmann
--
-- Entity:           Instantiate true dual-port memory on Altera FPGAs.
--
-- Description:
-- -------------------------------------
-- Quartus synthesis does not infer this RAM type correctly.
-- Instead, altsyncram is instantiated directly.
--
-- For further documentation see module "ocram_TrueDualPort"
-- (src/mem/ocram/ocram_TrueDualPort.vhdl).
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

entity ocram_TrueDualPort_Altera is
	generic (
		ADDRESS_BITS : positive;
		DATA_BITS    : positive;
		FILENAME     : string    := ""
	);
	port (
		PortA_Clock       : in  std_logic;
		PortA_ClockEnable : in  std_logic;
		PortA_WriteEnable : in  std_logic;
		PortA_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);
		PortA_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);
		PortA_DataOut     : out std_logic_vector(DATA_BITS-1 downto 0);

		PortB_Clock       : in  std_logic;
		PortB_ClockEnable : in  std_logic;
		PortB_WriteEnable : in  std_logic;
		PortB_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);
		PortB_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);
		PortB_DataOut     : out std_logic_vector(DATA_BITS-1 downto 0)
	);
end entity;


architecture rtl of ocram_TrueDualPort_Altera is
	constant DEPTH      : positive  := 2**ADDRESS_BITS;
	constant INIT_FILE  : string    := ite((str_length(FILENAME) = 0), "UNUSED", FILENAME);
begin
	mem : component altsyncram
		generic map (
			address_aclr_a            => "NONE",
			address_aclr_b            => "NONE",
			address_reg_b             => "CLOCK1",
			indata_aclr_a             => "NONE",
			indata_aclr_b             => "NONE",
			indata_reg_b              => "CLOCK1",
			init_file                 => INIT_FILE,
			intended_device_family    => getAlteraDeviceName(DEVICE),
			lpm_type                  => "altsyncram",
			numwords_a                => DEPTH,
			numwords_b                => DEPTH,
			operation_mode            => "BIDIR_DUAL_PORT",
			outdata_aclr_a            => "NONE",
			outdata_aclr_b            => "NONE",
			outdata_reg_a             => "UNREGISTERED",
			outdata_reg_b             => "UNREGISTERED",
			power_up_uninitialized    => "FALSE",
			widthad_a                 => ADDRESS_BITS,
			widthad_b                 => ADDRESS_BITS,
			width_a                   => DATA_BITS,
			width_b                   => DATA_BITS,
			width_byteena_a           => 1,
			width_byteena_b           => 1,
			wrcontrol_aclr_a          => "NONE",
			wrcontrol_aclr_b          => "NONE",
			wrcontrol_wraddress_reg_b => "CLOCK1"
		)
		port map (
			clock0                    => PortA_Clock,
			clock1                    => PortB_Clock,
			clocken0                  => PortA_ClockEnable,
			clocken1                  => PortB_ClockEnable,
			wren_a                    => PortA_WriteEnable,
			wren_b                    => PortB_WriteEnable,
			address_a                 => std_logic_vector(PortA_Address),
			address_b                 => std_logic_vector(PortB_Address),
			data_a                    => PortA_DataIn,
			data_b                    => PortB_DataIn,
			q_a                       => PortA_DataOut,
			q_b                       => PortB_DataOut
		);
end architecture;
