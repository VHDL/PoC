-- =============================================================================
-- Authors:         Martin Zabel
--                  Thomas B. Preusser
--                  Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:          Simple dual-port memory.
--
-- Description:
-- -------------------------------------
-- Inferring / instantiating simple dual-port memory, with:
--
-- * dual clock, clock enable,
-- * 1 read port plus 1 write port.
--
-- Both reading and writing are synchronous to the rising-edge of the clock.
-- Thus, when reading, the memory data will be outputted after the
-- clock edge, i.e, in the following clock cycle.
--
-- The generalized behavior across Altera and Xilinx FPGAs since
-- Stratix/Cyclone and Spartan-3/Virtex-5, respectively, is as follows:
--
-- Mixed-Port Read-During-Write
--   When reading at the write address, the read value will be unknown which is
--   aka. "don't care behavior". This applies to all reads (at the same
--   address) which are issued during the write-cycle time, which starts at the
--   rising-edge of the write clock and (in the worst case) extends until the
--   next rising-edge of the write clock.
--
-- For simulation, always our dedicated simulation model :ref:`IP:ocram_TrueDualPort_sim`
-- is used.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2008-2016 Technische Universitaet Dresden - Germany
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
use     work.ocram.all;


entity ocram_SimpleDualPort is
	generic (
		RAM_TYPE     : T_RAM_TYPE := RAM_TYPE_AUTO;
		ADDRESS_BITS : positive;                              -- number of address bits
		DATA_BITS    : positive;                              -- number of data bits
		FILENAME     : string    := ""                        -- file-name for RAM initialization
	);
	port (
		Write_Clock       : in  std_logic;                               -- write clock
		Write_ClockEnable : in  std_logic;                               -- write clock-enable
		Write_WriteEnable : in  std_logic;                               -- write enable
		Write_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);       -- write address
		Write_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);  -- data in

		Read_Clock        : in  std_logic;                               -- read clock
		Read_ClockEnable  : in  std_logic;                               -- read clock-enable
		Read_Address      : in  unsigned(ADDRESS_BITS-1 downto 0);       -- read address
		Read_DataOut      : out std_logic_vector(DATA_BITS-1 downto 0)   -- data out
	);
end entity;


architecture rtl of ocram_SimpleDualPort is
	constant DEPTH : positive := 2**ADDRESS_BITS;

begin
	gen: if gInfer: not SIMULATION and ((VENDOR = VENDOR_ALTERA) or (VENDOR = VENDOR_LATTICE) or (VENDOR = VENDOR_XILINX)) generate
		-- RAM can be inferred correctly
		-- Xilinx notes:
		--   WRITE_MODE is set to WRITE_FIRST, but this also means that read data
		--   is unknown on the opposite port. (As expected.)
		-- Altera notes:
		--   Setting attribute "ramstyle" to "no_rw_check" suppresses generation of
		--   bypass logic, when 'clk1'='clk2' and 'ra' is feed from a register.
		--   This is the expected behavior.
		--   With two different clocks, synthesis complains about an undefined
		--   read-write behavior, that can be ignored.

		signal ram : T_SLVV  := mem_InitMemory(FILENAME, DEPTH, DATA_BITS);
		attribute ramstyle  of ram : signal is get_ramstyle_string(RAM_TYPE);
		attribute ram_style of ram : signal is get_ram_style_string(RAM_TYPE);

	begin
		process(Write_Clock)
		begin
			if rising_edge(Write_Clock) then
				if (Write_ClockEnable and Write_WriteEnable) = '1' then
					ram(to_integer(Write_Address)) <= Write_DataIn;
				end if;
			end if;
		end process;

		process(Read_Clock)
		begin
			if rising_edge(Read_Clock) then
				if Read_ClockEnable = '1' then
					Read_DataOut <= ram(to_integer(Read_Address));
				end if;
			end if;
		end process;
	elsif gSim: SIMULATION generate
	begin
		sim_tdp: ocram_TrueDualPort_Simulation
			generic map (
				ADDRESS_BITS => ADDRESS_BITS,
				DATA_BITS    => DATA_BITS,
				FILENAME     => FILENAME
			)
			port map (
				PortA_Clock       => Write_Clock,
				PortA_ClockEnable => Write_ClockEnable,
				PortA_WriteEnable => Write_WriteEnable,
				PortA_Address     => Write_Address,
				PortA_DataIn      => Write_DataIn,
				PortA_DataOut     => open,

				PortB_Clock       => Read_Clock,
				PortB_ClockEnable => Read_ClockEnable,
				PortB_WriteEnable => '0',
				PortB_Address     => Read_Address,
				PortB_DataIn      => (others => '0'),
				PortB_DataOut     => Read_DataOut
			);
	else generate
		assert FALSE report "Vendor '" & T_VENDOR'image(VENDOR) & "' not yet supported." severity failure;
	end generate;
end architecture;
