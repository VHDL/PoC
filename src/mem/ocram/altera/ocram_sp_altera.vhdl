-- =============================================================================
-- Authors:					Martin Zabel
--									Patrick Lehmann
--
-- Entity:				 	Instantiate single-port memory on Altera FPGAs.
--
-- Description:
-- -------------------------------------
-- Quartus synthesis does not infer this RAM type correctly.
-- Instead, altsyncram is instantiated directly.
--
-- For further documentation see module "ocram_sp"
-- (src/mem/ocram/ocram_sp.vhdl).
--
-- License:
-- =============================================================================
-- Copyright 2008-2015 Technische Universitaet Dresden - Germany
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

library	IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library	Altera_mf;
use     Altera_mf.Altera_MF_Components.all;

use     work.config.all;
use     work.utils.all;
use     work.strings.all;


entity ocram_sp_altera is
	generic (
		A_BITS		: positive;
		D_BITS		: positive;
		FILENAME	: string		:= ""
	);
	port (
		clk : in	std_logic;
		ce	: in	std_logic;
		we	: in	std_logic;
		a		: in	unsigned(A_BITS-1 downto 0);
		d		: in	std_logic_vector(D_BITS-1 downto 0);
		q		: out std_logic_vector(D_BITS-1 downto 0)
	);
end entity;


architecture rtl of ocram_sp_altera is
	constant DEPTH			: positive	:= 2**A_BITS;
	constant INIT_FILE	: string		:= ite((str_length(FILENAME) = 0), "UNUSED", FILENAME);

	signal a_sl : std_logic_vector(A_BITS-1 downto 0);

begin
	a_sl <= std_logic_vector(a);

	mem : component altsyncram
		generic map (
			address_aclr_a					=> "NONE",
			indata_aclr_a						=> "NONE",
			init_file								=> INIT_FILE,
			intended_device_family	=> getAlteraDeviceName(DEVICE),
			lpm_hint								=> "ENABLE_RUNTIME_MOD = NO",
			lpm_type								=> "altsyncram",
			numwords_a							=> DEPTH,
			operation_mode					=> "SINGLE_PORT",
			outdata_aclr_a					=> "NONE",
			outdata_reg_a						=> "UNREGISTERED",
			power_up_uninitialized	=> "FALSE",
			widthad_a								=> A_BITS,
			width_a									=> D_BITS,
			width_byteena_a					=> 1,
			wrcontrol_aclr_a				=> "NONE"
		)
		port map (
			clocken0								=> ce,
			wren_a									=> we,
			clock0									=> clk,
			address_a								=> a_sl,
			data_a									=> d,
			q_a											=> q
		);
end architecture;
