-- =============================================================================
-- Authors:           Martin Zabel
--                  Patrick Lehmann
--
-- Entity:           True dual-port memory.
--
-- Description:
-- -------------------------------------
-- Inferring / instantiating true dual-port memory, with:
--
-- * dual clock, clock enable,
-- * 2 read/write ports.
--
-- Command truth table for port 1, same applies to port 2:
--
-- === === ================
-- ce1 we1 Command
-- === === ================
-- 0   X   No operation
-- 1   0   Read from memory
-- 1   1   Write to memory
-- === === ================
--
-- Both reading and writing are synchronous to the rising-edge of the clock.
-- Thus, when reading, the memory data will be outputted after the
-- clock edge, i.e, in the following clock cycle.
--
-- The generalized behavior across Altera and Xilinx FPGAs since
-- Stratix/Cyclone and Spartan-3/Virtex-5, respectively, is as follows:
--
-- Same-Port Read-During-Write
--   When writing data through port 1, the read output of the same port
--   (``q1``) will output the new data (``d1``, in the following clock cycle)
--   which is aka. "write-first behavior".
--
--   Same applies to port 2.
--
-- Mixed-Port Read-During-Write
--   When reading at the write address, the read value will be unknown which is
--   aka. "don't care behavior". This applies to all reads (at the same
--   address) which are issued during the write-cycle time, which starts at the
--   rising-edge of the write clock and (in the worst case) extends
--   until the next rising-edge of that write clock.
--
-- For simulation, always our dedicated simulation model :ref:`IP:ocram_tdp_sim`
-- is used.
--
-- License:
-- =============================================================================
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


entity ocram_TrueDualPort is
	generic (
		ADDRESS_BITS : positive;                              -- number of address bits
		DATA_BITS    : positive;                              -- number of data bits
		FILENAME     : string    := ""                        -- file-name for RAM initialization
	);
	port (
		PortA_Clock : in  std_logic;                              -- clock for 1st port
		PortA_ClockEnable  : in  std_logic;                              -- clock-enable for 1st port
		PortA_WriteEnable  : in  std_logic;                              -- write-enable for 1st port
		PortA_Address   : in  unsigned(ADDRESS_BITS-1 downto 0);            -- address for 1st port
		PortA_DataIn   : in  std_logic_vector(DATA_BITS-1 downto 0);    -- write-data for 1st port
		PortA_DataOut   : out std_logic_vector(DATA_BITS-1 downto 0);    -- read-data from 1st port

		PortB_Clock : in  std_logic;                              -- clock for 2nd port
		PortB_ClockEnable  : in  std_logic;                              -- clock-enable for 2nd port
		PortB_WriteEnable  : in  std_logic;                              -- write-enable for 2nd port
		PortB_Address   : in  unsigned(ADDRESS_BITS-1 downto 0);            -- address for 2nd port
		PortB_DataIn   : in  std_logic_vector(DATA_BITS-1 downto 0);    -- write-data for 2nd port
		PortB_DataOut   : out std_logic_vector(DATA_BITS-1 downto 0)     -- read-data from 2nd port
	);
end entity;


architecture rtl of ocram_TrueDualPort is
	constant DEPTH : positive := 2**ADDRESS_BITS;

begin
	gInfer : if not SIMULATION and ((VENDOR = VENDOR_LATTICE) or (VENDOR = VENDOR_XILINX)) generate
		-- RAM can be inferred correctly only if '-use_new_parser yes' is enabled in XST options
		subtype word_t  is std_logic_vector(DATA_BITS - 1 downto 0);
		type    ram_t    is array(0 to DEPTH - 1) of word_t;      -- XXX: T_SLVV

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

		signal ram      : ram_t    := ocram_InitMemory(FILENAME);
		signal a1_reg    : unsigned(ADDRESS_BITS-1 downto 0) := (others => 'U');
		signal a2_reg    : unsigned(ADDRESS_BITS-1 downto 0) := (others => 'U');

	begin

		process (PortA_Clock, PortB_Clock)
		begin  -- process
			if rising_edge(PortA_Clock) then
				if PortA_ClockEnable = '1' then
					if PortA_WriteEnable = '1' then
						ram(to_integer(PortA_Address)) <= PortA_DataIn;
					end if;

					a1_reg <= PortA_Address;
				end if;
			end if;

			if rising_edge(PortB_Clock) then
				if PortB_ClockEnable = '1' then
					if PortB_WriteEnable = '1' then
						ram(to_integer(PortB_Address)) <= PortB_DataIn;
					end if;

					a2_reg <= PortB_Address;
				end if;
			end if;
		end process;

		PortA_DataOut <= (others => 'X') when SIMULATION and is_x(std_logic_vector(a1_reg)) else
					ram(to_integer(a1_reg));    -- returns new data
		PortB_DataOut <= (others => 'X') when SIMULATION and is_x(std_logic_vector(a2_reg)) else
					ram(to_integer(a2_reg));    -- returns new data
	end generate gInfer;

	gAltera: if not SIMULATION and (VENDOR = VENDOR_ALTERA) generate
		component ocram_TrueDualPort_Altera
			generic (
				ADDRESS_BITS : positive;
				DATA_BITS    : positive;
				FILENAME     : string    := ""
			);
			port (
				PortA_Clock : in  std_logic;
				PortB_Clock : in  std_logic;
				PortA_ClockEnable  : in  std_logic;
				PortB_ClockEnable  : in  std_logic;
				PortA_WriteEnable  : in  std_logic;
				PortB_WriteEnable  : in  std_logic;
				PortA_Address   : in  unsigned(ADDRESS_BITS-1 downto 0);
				PortB_Address   : in  unsigned(ADDRESS_BITS-1 downto 0);
				PortA_DataIn   : in  std_logic_vector(DATA_BITS-1 downto 0);
				PortB_DataIn   : in  std_logic_vector(DATA_BITS-1 downto 0);
				PortA_DataOut   : out std_logic_vector(DATA_BITS-1 downto 0);
				PortB_DataOut   : out std_logic_vector(DATA_BITS-1 downto 0)
			);
		end component;
	begin
		-- Direct instantiation of altsyncram (including component
		-- declaration above) is not sufficient for ModelSim.
		-- That requires also usage of altera_mf library.

		ram_altera: ocram_TrueDualPort_Altera
			generic map (
				ADDRESS_BITS => ADDRESS_BITS,
				DATA_BITS     => DATA_BITS,
				FILENAME     => FILENAME
			)
			port map (
				PortA_Clock        => PortA_Clock,
				PortA_ClockEnable  => PortA_ClockEnable,
				PortA_WriteEnable  => PortA_WriteEnable,
				PortA_Address      => PortA_Address,
				PortA_DataIn      => PortA_DataIn,
				PortA_DataOut      => PortA_DataOut,

				PortB_Clock        => PortB_Clock,
				PortB_ClockEnable  => PortB_ClockEnable,
				PortB_WriteEnable  => PortB_WriteEnable,
				PortB_Address     => PortB_Address,
				PortB_DataIn      => PortB_DataIn,
				PortB_DataOut      => PortB_DataOut
			);
	end generate gAltera;

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
				ce1   : in  std_logic;
				ce2   : in  std_logic;
				we1   : in  std_logic;
				we2   : in  std_logic;
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
				clk1 => PortA_Clock,
				clk2 => PortB_Clock,
				ce1   => PortA_ClockEnable,
				ce2   => PortB_ClockEnable,
				we1   => PortA_WriteEnable,
				we2   => PortB_WriteEnable,
				a1   => PortA_Address,
				a2   => PortB_Address,
				d1   => PortA_DataIn,
				d2   => PortB_DataIn,
				q1   => PortA_DataOut,
				q2   => PortB_DataOut);
	end generate gSim;

	assert ((VENDOR = VENDOR_ALTERA) or (VENDOR = VENDOR_GENERIC and SIMULATION) or (VENDOR = VENDOR_LATTICE) or (VENDOR = VENDOR_XILINX))
		report "Vendor '" & T_VENDOR'image(VENDOR) & "' not yet supported."
		severity failure;
end architecture;
