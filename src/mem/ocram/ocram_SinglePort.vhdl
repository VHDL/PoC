-- =============================================================================
-- Authors:           Martin Zabel
--                  Patrick Lehmann
--
-- Entity:           Single-port memory.
--
-- Description:
-- -------------------------------------
-- Inferring / instantiating single port memory, with:
--
-- * single clock, clock enable,
-- * 1 read/write port.
--
-- Command Truth Table:
--
-- == == ================
-- ce we Command
-- == == ================
-- 0  X  No operation
-- 1  0  Read from memory
-- 1  1  Write to memory
-- == == ================
--
-- Both reading and writing are synchronous to the rising-edge of the clock.
-- Thus, when reading, the memory data will be outputted after the
-- clock edge, i.e, in the following clock cycle.
--
-- When writing data, the read output will output the new data (in the
-- following clock cycle) which is aka. "write-first behavior". This behavior
-- also applies to Altera M20K memory blocks as described in the Altera:
-- "Stratix 5 Device Handbook" (S5-5V1). The documentation in the Altera:
-- "Embedded Memory User Guide" (UG-01068) is wrong.
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

use     work.config.all;
use     work.utils.all;
use     work.strings.all;
use     work.vectors.all;
use     work.mem.all;


entity ocram_SinglePort is
	generic (
		-- FIXME: RAM_STYLE?
		ADDRESS_BITS : positive;                              -- number of address bits
		DATA_BITS    : positive;                              -- number of data bits
		FILENAME     : string    := ""                        -- file-name for RAM initialization
	);
	port (
		Clock       : in  std_logic;                               -- clock
		ClockEnable : in  std_logic;                               -- clock enable
		WriteEnable : in  std_logic;                               -- write enable
		Address     : in  unsigned(ADDRESS_BITS-1 downto 0);       -- address
		DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);  -- write data
		DataOut     : out std_logic_vector(DATA_BITS-1 downto 0)   -- read output
	);
end entity;


architecture rtl of ocram_SinglePort is
	constant DEPTH : positive := 2**ADDRESS_BITS;

begin
	gen: if gInfer: (VENDOR = VENDOR_GENERIC) or (VENDOR = VENDOR_LATTICE) or (VENDOR = VENDOR_XILINX) generate
		signal ram   : T_SLVV    := mem_InitMemory(FILENAME, DEPTH, DATA_BITS);
		signal a_reg : unsigned(ADDRESS_BITS-1 downto 0);

	begin
		process (Clock)
		begin
			if rising_edge(Clock) then
				if ClockEnable = '1' then
					if WriteEnable = '1' then
						ram(to_integer(Address)) <= DataIn;
					end if;

					a_reg <= Address;
				end if;
			end if;
		end process;

		DataOut <= (others => 'X') when SIMULATION and is_x(std_logic_vector(a_reg)) else ram(to_integer(a_reg));          -- gets new data
	elsif gAltera: VENDOR = VENDOR_ALTERA generate
		component ocram_SimplePort_Altera
			generic (
				ADDRESS_BITS : positive;
				DATA_BITS    : positive;
				FILENAME     : string    := ""
			);
			port (
				Clock       : in  std_logic;
				ClockEnable : in  std_logic;
				WriteEnable : in  std_logic;
				Address     : in  unsigned(ADDRESS_BITS-1 downto 0);
				DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);
				DataOut     : out std_logic_vector(DATA_BITS-1 downto 0));
		end component;
	begin
		-- Direct instantiation of altsyncram (including component
		-- declaration above) is not sufficient for ModelSim.
		-- That requires also usage of altera_mf library.
		ram_altera: ocram_SimplePort_Altera
			generic map (
				ADDRESS_BITS    => ADDRESS_BITS,
				DATA_BITS    => DATA_BITS,
				FILENAME  => FILENAME
			)
			port map (
				Clock       => Clock,
				ClockEnable => ClockEnable,
				WriteEnable => WriteEnable,
				Address     => Address,
				DataIn      => DataIn,
				DataOut     => DataOut
			);
	else generate
		assert FALSE report "Vendor '" & T_VENDOR'image(VENDOR) & "' not yet supported." severity failure;
	end generate;
end architecture;
