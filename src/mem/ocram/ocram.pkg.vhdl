-- =============================================================================
-- Authors:           Martin Zabel
--                  Patrick Lehmann
--
-- Package:           VHDL package for component declarations, types and functions
--                  associated to the PoC.mem.ocram namespace
--
-- Description:
-- -------------------------------------
--    On-Chip RAMs (Random-Access-Memory/Read-Write-Memory - RWM) for FPGAs.
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

use     work.utils.all;
use     work.mem.all;


package ocram is
	attribute ram_style : string;
	attribute ramstyle  : string;

	function addressIsEqual(addressA : unsigned; addressB : unsigned) return X01;

	-- Single-Port
	component ocram_SinglePort
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

	-- Simple-Dual-Port
	component ocram_SimpleDualPort
		generic(
			ADDRESS_BITS   : positive;
			DATA_BITS   : positive;
			RAM_TYPE : T_RAM_TYPE := RAM_TYPE_AUTO;
			FILENAME : string     := ""
		);
		port(
			Read_Clock : in  std_logic;
			Read_ClockEnable  : in  std_logic;
			Write_Clock : in  std_logic;
			Write_ClockEnable  : in  std_logic;
			Write_WriteEnable   : in  std_logic;
			Read_Address   : in  unsigned(ADDRESS_BITS-1 downto 0);
			Write_Address   : in  unsigned(ADDRESS_BITS-1 downto 0);
			Write_DataIn    : in  std_logic_vector(DATA_BITS-1 downto 0);
			Read_DataOut    : out std_logic_vector(DATA_BITS-1 downto 0)
		);
	end component ocram_SimpleDualPort;

	-- Enhanced-Simple-Dual-Port
	component ocram_EnhancedSimpleDualPort
		generic (
			ADDRESS_BITS    : positive;
			DATA_BITS    : positive;
			FILENAME  : string    := ""
		);
		port (
			PortA_Clock : in  std_logic;
			PortB_Clock : in  std_logic;
			PortA_ClockEnable  : in  std_logic;
			PortB_ClockEnable  : in  std_logic;
			PortA_WriteEnable  : in  std_logic;
			PortA_Address   : in  unsigned(ADDRESS_BITS-1 downto 0);
			PortB_Address   : in  unsigned(ADDRESS_BITS-1 downto 0);
			PortA_DataIn   : in  std_logic_vector(DATA_BITS-1 downto 0);
			PortA_DataOut   : out std_logic_vector(DATA_BITS-1 downto 0);
			PortB_DataOut   : out std_logic_vector(DATA_BITS-1 downto 0));
	end component;

	-- True-Dual-Port
	component ocram_TrueDualPort
		generic (
			ADDRESS_BITS    : positive;
			DATA_BITS    : positive;
			FILENAME  : string    := ""
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
			PortB_DataOut   : out std_logic_vector(DATA_BITS-1 downto 0));
	end component;
end package;

package body ocram is
	-- Compares two addresses, returns 'X' if either ``a1`` or ``a2`` contains
	-- meta-values, otherwise returns '1' if ``a1 == a2`` is true else
	-- '0'. Returns 'X' even when the addresses contain '-' values, to signal an
	-- undefined outcome.
	function addressIsEqual(addressA : unsigned; addressB : unsigned) return X01 is
	begin
		-- synthesis translate_off
		if is_x(addressA) or is_x(addressB) then
			return 'X';
		end if;
		-- synthesis translate_on

		return to_sl(to_x01(std_logic_vector(addressA)) = to_x01(std_logic_vector(addressB)));
	end function;
end package body ocram;

