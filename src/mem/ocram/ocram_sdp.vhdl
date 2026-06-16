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
-- For simulation, always our dedicated simulation model :ref:`IP:ocram_tdp_sim`
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


entity ocram_SimpleDualPort is
	generic (
		RAM_TYPE     : T_RAM_TYPE := RAM_TYPE_AUTO;
		ADDRESS_BITS : positive;                              -- number of address bits
		DATA_BITS    : positive;                              -- number of data bits
		FILENAME     : string    := ""                        -- file-name for RAM initialization
	);
	port (
		Write_Clock       : in  std_logic;                            -- write clock
		Write_ClockEnable : in  std_logic;                            -- write clock-enable
		Write_WriteEnable : in  std_logic;                            -- write enable
		Write_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);          -- write address
		Write_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);  -- data in

		Read_Clock        : in  std_logic;                            -- read clock
		Read_ClockEnable  : in  std_logic;                            -- read clock-enable
		Read_Address      : in  unsigned(ADDRESS_BITS-1 downto 0);          -- read address
		Read_DataOut      : out std_logic_vector(DATA_BITS-1 downto 0)    -- data out
	);
end entity;


architecture rtl of ocram_SimpleDualPort is
	constant DEPTH : positive := 2**ADDRESS_BITS;

begin

	gInfer : if not SIMULATION and ((VENDOR = VENDOR_ALTERA) or (VENDOR = VENDOR_LATTICE) or (VENDOR = VENDOR_XILINX)) generate
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
		attribute ram_style : string;
		attribute ramstyle : string;

		subtype  word_t  is std_logic_vector(DATA_BITS - 1 downto 0);
		type    ram_t    is array(0 to DEPTH - 1) of word_t;     -- XXX: T_SLVV

		-- Compute the initialization of a RAM array, if specified, from the passed file.
		impure function ocram_InitMemory(FilePath : string) return ram_t is
			variable Memory    : T_SLM(DEPTH - 1 downto 0, word_t'range);
			variable res      : ram_t;
		begin
			if str_length(FilePath) = 0 then
				-- shortcut required by Vivado
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

		signal ram : ram_t  := ocram_InitMemory(FILENAME);
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
	end generate gInfer;

	gSim: if SIMULATION generate
		-- Use component instantiation so that simulation model can be excluded
		-- from synthesis.
		component ocram_TrueDualPort_sim is
			generic (
				ADDRESS_BITS   : positive;
				DATA_BITS   : positive;
				FILENAME : string);
			port (
				clk1 : in  std_logic;
				clk2 : in  std_logic;
				ce1  : in  std_logic;
				ce2  : in  std_logic;
				we1  : in  std_logic;
				we2  : in  std_logic;
				a1   : in  unsigned(ADDRESS_BITS-1 downto 0);
				a2   : in  unsigned(ADDRESS_BITS-1 downto 0);
				d1   : in  std_logic_vector(DATA_BITS-1 downto 0);
				d2   : in  std_logic_vector(DATA_BITS-1 downto 0);
				q1   : out std_logic_vector(DATA_BITS-1 downto 0);
				q2   : out std_logic_vector(DATA_BITS-1 downto 0));
		end component ocram_TrueDualPort_sim;
	begin
		sim_tdp: ocram_TrueDualPort_sim
			generic map (
				ADDRESS_BITS   => ADDRESS_BITS,
				DATA_BITS   => DATA_BITS,
				FILENAME => FILENAME)
			port map (
				clk1 => Write_Clock,
				clk2 => Read_Clock,
				ce1  => Write_ClockEnable,
				ce2  => Read_ClockEnable,
				we1  => Write_WriteEnable,
				we2  => '0',
				a1   => Write_Address,
				a2   => Read_Address,
				d1   => Write_DataIn,
				d2   => (others => '0'),
				q1   => open,
				q2   => Read_DataOut);
	end generate gSim;

	assert ((VENDOR = VENDOR_ALTERA) or (VENDOR = VENDOR_GENERIC and SIMULATION) or (VENDOR = VENDOR_LATTICE) or (VENDOR = VENDOR_XILINX))
		report "Vendor '" & T_VENDOR'image(VENDOR) & "' not yet supported."
		severity failure;
end architecture;
