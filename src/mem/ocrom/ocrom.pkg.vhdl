-- =============================================================================
-- Authors:           Martin Zabel
--                  Patrick Lehmann
--
-- Package:           VHDL package for component declarations, types and functions
--                  associated to the PoC.mem.ocram namespace
--
-- Description:
-- -------------------------------------
--    On-Chip ROMs (Read-Only-Memory) for FPGAs.
--
--    A detailed documentation is included in each module.
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


package ocrom is
	-- Single-Port
	component ocrom_SinglePort is
		generic (
			ADDRESS_BITS    : positive;
			DATA_BITS    : positive;
			FILENAME  : string    := ""
		);
		port (
			Clock  : in  std_logic;
			ClockEnable  : in  std_logic;
			Address    : in  unsigned(ADDRESS_BITS-1 downto 0);
			DataOut    : out std_logic_vector(DATA_BITS-1 downto 0)
		);
	end component;

	-- Dual-Port
	component ocrom_DualPort is
		generic (
			ADDRESS_BITS    : positive;
			DATA_BITS    : positive;
			FILENAME  : string    := ""
		);
		port (
			clk1 : in  std_logic;
			clk2 : in  std_logic;
			ce1  : in  std_logic;
			ce2  : in  std_logic;
			a1   : in  unsigned(ADDRESS_BITS-1 downto 0);
			a2   : in  unsigned(ADDRESS_BITS-1 downto 0);
			q1   : out std_logic_vector(DATA_BITS-1 downto 0);
			q2   : out std_logic_vector(DATA_BITS-1 downto 0)
		);
	end component;
end package;
