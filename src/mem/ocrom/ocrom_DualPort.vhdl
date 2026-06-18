-- =============================================================================
-- Authors:           Martin Zabel
--                  Patrick Lehmann
--
-- Entity:           True dual-port memory.
--
-- Description:
-- -------------------------------------
-- Inferring / instantiating dual-port read-only memory, with:
--
-- * dual clock, clock enable,
-- * 2 read ports.
--
-- The generalized behavior across Altera and Xilinx FPGAs since
-- Stratix/Cyclone and Spartan-3/Virtex-5, respectively, is as follows:
--
-- WARNING: The simulated behavior on RT-level is not correct.
--
-- TODO: add timing diagram
-- TODO: implement correct behavior for RT-level simulation
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

use     STD.TextIO.all;

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;
use     IEEE.std_logic_textio.all;

use     work.config.all;
use     work.utils.all;
use     work.strings.all;
use     work.vectors.all;
use     work.mem.all;
use     work.ocram.all;


entity ocrom_DualPort is
	generic (
		ADDRESS_BITS : positive;
		DATA_BITS    : positive;
		FILENAME     : string    := ""
	);
	port (
		PortA_Clock       : in  std_logic;
		PortA_ClockEnable : in  std_logic;
		PortA_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);
		PortA_DataOut     : out std_logic_vector(DATA_BITS-1 downto 0);

		PortB_Clock       : in  std_logic;
		PortB_ClockEnable : in  std_logic;
		PortB_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);
		PortB_DataOut     : out std_logic_vector(DATA_BITS-1 downto 0)
	);
end entity;


architecture rtl of ocrom_DualPort is
	constant DEPTH        : positive := 2**ADDRESS_BITS;

begin
	assert (str_length(FILENAME) /= 0) report "Do you really want to generate a block of zeros?" severity FAILURE;

	gen: if gInfer: (VENDOR = VENDOR_GENERIC) or (VENDOR = VENDOR_XILINX) generate
		constant rom    : T_SLVV      := mem_InitMemory(FILENAME, DEPTH, DATA_BITS);
		signal a1_reg   : unsigned(ADDRESS_BITS-1 downto 0);
		signal a2_reg   : unsigned(ADDRESS_BITS-1 downto 0);

	begin
		process(PortA_Clock)
		begin
			if rising_edge(PortA_Clock) then
				if PortA_ClockEnable = '1' then
					a1_reg <= PortA_Address;
				end if;
			end if;
		end process;

		process(PortB_Clock)
		begin
			if rising_edge(PortB_Clock) then
				if PortB_ClockEnable = '1' then
					a2_reg <= PortB_Address;
				end if;
			end if;
		end process;

		PortA_DataOut <= rom(to_integer(a1_reg));    -- returns new data
		PortB_DataOut <= rom(to_integer(a2_reg));    -- returns new data
	elsif gAltera: VENDOR = VENDOR_ALTERA generate
		-- Direct instantiation of altsyncram (including component
		-- declaration above) is not sufficient for ModelSim.
		-- That requires also usage of altera_mf library.

		rom: component ocram_TrueDualPort_Altera
			generic map (
				ADDRESS_BITS => ADDRESS_BITS,
				DATA_BITS    => DATA_BITS,
				FILENAME     => FILENAME
			)
			port map (
				PortA_Clock        => PortA_Clock,
				PortB_Clock        => PortB_Clock,
				PortA_ClockEnable  => PortA_ClockEnable,
				PortB_ClockEnable  => PortB_ClockEnable,
				PortA_WriteEnable  => '0',
				PortB_WriteEnable  => '0',
				PortA_Address      => PortA_Address,
				PortB_Address      => PortB_Address,
				PortA_DataIn       => (others => '0'),
				PortB_DataIn       => (others => '0'),
				PortA_DataOut      => PortA_DataOut,
				PortB_DataOut      => PortB_DataOut
			);
	else generate
		assert FALSE report "Vendor '" & T_VENDOR'image(VENDOR) & "' not yet supported." severity failure;
	end generate;
end architecture;
