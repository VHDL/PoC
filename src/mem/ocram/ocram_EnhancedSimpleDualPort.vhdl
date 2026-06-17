-- =============================================================================
-- Authors:           Martin Zabel
--                  Patrick Lehmann
--
-- Entity:           Enhanced simple dual-port memory.
--
-- Description:
-- -------------------------------------
-- Inferring / instantiating enhanced simple dual-port memory, with:
--
-- * dual clock, clock enable,
-- * 1 read/write port (1st port) plus 1 read port (2nd port).
--
-- .. deprecated:: 1.1
--
--    **Please use** :ref:`IP:ocram_TrueDualPort` **for new designs.
--    This component has been provided because older FPGA compilers where not
--    able to infer true dual-port memory from an RTL description.**
--
-- Command truth table for port 1:
--
-- === === ================
-- ce1 we1 Command
-- === === ================
-- 0   X   No operation
-- 1   0   Read from memory
-- 1   1   Write to memory
-- === === ================
--
-- Command truth table for port 2:
--
-- === ================
-- ce2 Command
-- === ================
-- 0   No operation
-- 1   Read from memory
-- === ================
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
-- Mixed-Port Read-During-Write
--   When reading at the write address, the read value will be unknown which is
--   aka. "don't care behavior". This applies to all reads (at the same
--   address) which are issued during the write-cycle time, which starts at the
--   rising-edge of the write clock (``clk1``) and (in the worst case) extends
--   until the next rising-edge of the write clock.
--
-- For simulation, always our dedicated simulation model :ref:`IP:ocram_TrueDualPort_Simulation`
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

use     STD.TextIO.all;

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.config.all;
use     work.utils.all;
use     work.strings.all;
use     work.vectors.all;
use     work.mem.all;
use     work.ocram.all;


entity ocram_EnhancedSimpleDualPort is
	generic (
		ADDRESS_BITS  : positive;                              -- number of address bits
		DATA_BITS      : positive;                              -- number of data bits
		FILENAME      : string    := ""                        -- file-name for RAM initialization
	);
	port (
		PortA_Clock       : in  std_logic;                              -- clock for 1st port
		PortA_ClockEnable : in  std_logic;                              -- clock-enable for 1st port
		PortA_WriteEnable : in  std_logic;                              -- write-enable for 1st port
		PortA_Address      : in  unsigned(ADDRESS_BITS-1 downto 0);            -- address for 1st port
		PortA_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);    -- write-data for 1st port
		PortA_DataOut      : out std_logic_vector(DATA_BITS-1 downto 0);    -- read-data from 1st port

		PortB_Clock       : in  std_logic;                              -- clock for 2nd port
		PortB_ClockEnable : in  std_logic;                              -- clock-enable for 2nd port
		PortB_Address      : in  unsigned(ADDRESS_BITS-1 downto 0);            -- address for 2nd port
		PortB_DataOut      : out std_logic_vector(DATA_BITS-1 downto 0)     -- read-data from 2nd port
	);
end entity;


architecture rtl of ocram_EnhancedSimpleDualPort is
	constant DEPTH : positive := 2**ADDRESS_BITS;

begin
	gen: if gInfer: not SIMULATION and ((VENDOR = VENDOR_LATTICE) or (VENDOR = VENDOR_XILINX)) generate
		-- For Xilinx ISE, Xilinx Vivado and Lattice LSE we can reuse the ocram_TrueDualPort.
		--
		-- **Attention**: This encapsulation is mandatory for Xilinx Vivado,
		-- otherwise Vivado synthesizes a lot of LUT-RAM instead of Block-RAM.
		tdp: entity work.ocram_TrueDualPort
			generic map (
				ADDRESS_BITS => ADDRESS_BITS,
				DATA_BITS    => DATA_BITS,
				FILENAME     => FILENAME
			)
			port map (
				PortA_Clock        => PortA_Clock,
				PortA_ClockEnable  => PortA_ClockEnable,
				PortA_WriteEnable  => PortA_WriteEnable,
				PortA_Address      => PortA_Address,
				PortA_DataIn       => PortA_DataIn,
				PortA_DataOut      => PortA_DataOut,

				PortB_Clock        => PortB_Clock,
				PortB_ClockEnable  => PortB_ClockEnable,
				PortB_WriteEnable  => '0',
				PortB_Address      => PortB_Address,
				PortB_DataIn       => (others => '0'),
				PortB_DataOut      => PortB_DataOut
			);
	elsif gAltera: not SIMULATION and (VENDOR = VENDOR_ALTERA) generate
		-- Direct instantiation of altsyncram (including component
		-- declaration above) is not sufficient for ModelSim.
		-- That requires also usage of altera_mf library.
		tdp: component ocram_TrueDualPort_Altera
			generic map (
				ADDRESS_BITS => ADDRESS_BITS,
				DATA_BITS    => DATA_BITS,
				FILENAME     => FILENAME
			)
			port map (
				PortA_Clock       => PortA_Clock,
				PortA_ClockEnable => PortA_ClockEnable,
				PortA_WriteEnable => PortA_WriteEnable,
				PortA_Address     => PortA_Address,
				PortA_DataIn      => PortA_DataIn,
				PortA_DataOut     => PortA_DataOut,

				PortB_Clock       => PortB_Clock,
				PortB_ClockEnable => PortB_ClockEnable,
				PortB_WriteEnable => '0',
				PortB_Address     => PortB_Address,
				PortB_DataIn      => (others => '0'),
				PortB_DataOut     => PortB_DataOut
			);
	elsif gSim: SIMULATION generate
		tdp: component ocram_TrueDualPort_Simulation  -- XXX: why is this not a second architecture?
			generic map (
				ADDRESS_BITS => ADDRESS_BITS,
				DATA_BITS    => DATA_BITS,
				FILENAME     => FILENAME
			)
			port map (
				PortA_Clock       => PortA_Clock,
				PortA_ClockEnable => PortA_ClockEnable,
				PortA_WriteEnable => PortA_WriteEnable,
				PortA_Address     => PortA_Address,
				PortA_DataIn      => PortA_DataIn,
				PortA_DataOut     => PortA_DataOut,

				PortB_Clock       => PortB_Clock,
				PortB_ClockEnable => PortB_ClockEnable,
				PortB_WriteEnable => '0',
				PortB_Address     => PortB_Address,
				PortB_DataIn      => (others => '0'),
				PortB_DataOut     => PortB_DataOut
			);
	else generate
		assert FALSE report "Vendor '" & T_VENDOR'image(VENDOR) & "' not yet supported." severity failure;
	end generate;
end architecture;
