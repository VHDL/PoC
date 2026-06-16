-- =============================================================================
-- Authors:           Martin Zabel
--                  Patrick Lehmann
--
-- Entity:           Single-port memory.
--
-- Description:
-- -------------------------------------
-- Inferring / instantiating single-port read-only memory
--
-- - single clock, clock enable
-- - 1 read port
--
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


entity ocrom_SinglePort is
	generic (
		ADDRESS_BITS    : positive;
		DATA_BITS    : positive;
		FILENAME  : string    := ""
	);
	port (
		Clock        : in  std_logic;
		ClockEnable : in  std_logic;
		Address     : in  unsigned(ADDRESS_BITS-1 downto 0);
		DataOut      : out std_logic_vector(DATA_BITS-1 downto 0)
	);
end entity;


architecture rtl of ocrom_SinglePort is
	constant DEPTH        : positive := 2**ADDRESS_BITS;

begin
	assert (str_length(FILENAME) /= 0) report "Do you really want to generate a block of zeros?" severity FAILURE;

	gInfer: if (VENDOR = VENDOR_GENERIC) or (VENDOR = VENDOR_XILINX) generate
		-- RAM can be inferred correctly
		-- XST Advanced HDL Synthesis generates single-port memory as expected.
		subtype word_t  is std_logic_vector(DATA_BITS - 1 downto 0);
		type    rom_t    is array(0 to DEPTH - 1) of word_t;   -- XXX: T_SLVV

		-- Compute the initialization of a RAM array, if specified, from the passed file.
		impure function ocrom_InitMemory(FilePath : string) return rom_t is
			variable Memory    : T_SLM(DEPTH - 1 downto 0, word_t'range);
			variable res      : rom_t;
		begin
			if str_length(FilePath) = 0 then
				-- shortcut required by Vivado (assert above is ignored)
				return (others => (others => ite(SIMULATION, 'U', '0')));
			elsif mem_FileExtension(FilePath) = "mem" then
				Memory  := mem_ReadMemoryFile(FilePath, DEPTH, word_t'length, MEM_FILEFORMAT_XILINX_MEM, MEM_CONTENT_HEX);
			else
				Memory  := mem_ReadMemoryFile(FilePath, DEPTH, word_t'length, MEM_FILEFORMAT_INTEL_HEX, MEM_CONTENT_HEX);
			end if;

			for i in Memory'range(1) loop
				for j in word_t'range loop
					res(i)(j)    := Memory(i, j);
				end loop;
			end loop;
			return  res;
		end function;

		constant rom  : rom_t    := ocrom_InitMemory(FILENAME);
		signal a_reg  : unsigned(ADDRESS_BITS-1 downto 0);
	begin
		process (Clock)
		begin
			if rising_edge(Clock) then
				if ClockEnable = '1' then
					a_reg <= Address;
				end if;
			end if;
		end process;

		DataOut <= rom(to_integer(a_reg));          -- gets new data
	end generate gInfer;

	gAltera: if VENDOR = VENDOR_ALTERA generate
		component ocram_SimplePort_Altera
			generic (
				ADDRESS_BITS    : positive;
				DATA_BITS    : positive;
				FILENAME  : string    := ""
			);
			port (
				Clock : in  std_logic;
				ClockEnable  : in  std_logic;
				WriteEnable  : in  std_logic;
				Address   : in  unsigned(ADDRESS_BITS-1 downto 0);
				DataIn   : in  std_logic_vector(DATA_BITS-1 downto 0);
				DataOut   : out std_logic_vector(DATA_BITS-1 downto 0));
		end component;
	begin
		-- Direct instantiation of altsyncram (including component
		-- declaration above) is not sufficient for ModelSim.
		-- That requires also usage of altera_mf library.
		rom: ocram_SimplePort_Altera
			generic map (
				ADDRESS_BITS    => ADDRESS_BITS,
				DATA_BITS    => DATA_BITS,
				FILENAME  => FILENAME
			)
			port map (
				Clock => Clock,
				ClockEnable  => ClockEnable,
				WriteEnable  => '0',
				Address   => Address,
				DataIn   => (others => '0'),
				DataOut   => DataOut
			);
	end generate gAltera;

	assert ((VENDOR = VENDOR_ALTERA) or (VENDOR = VENDOR_GENERIC) or (VENDOR = VENDOR_XILINX))
		report "Vendor '" & T_VENDOR'image(VENDOR) & "' not yet supported."
		severity failure;
end architecture;
