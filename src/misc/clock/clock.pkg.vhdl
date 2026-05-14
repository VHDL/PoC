-- =============================================================================
-- Authors:
--   Patrick Lehmann
--   Adrian Weiland
--
-- Entity:
--
-- Description:
-- -------------------------------------
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use work.physical.all;
use work.utils.all;


package clock is
	type T_TIME_VEC is array (natural range <>) of T_TIME;
	constant RESOLUTION_TIMES : T_TIME_VEC(0 to 2) := (1.0e-9, 1.0e-6, 1.0e-3);

	attribute Count : natural;
	attribute Bits  : natural;

	type T_SECOND_RESOLUTION is (NANOSECONDS, MICROSECONDS, MILLISECONDS);
	attribute Count of T_SECOND_RESOLUTION : type is T_SECOND_RESOLUTION'pos(T_SECOND_RESOLUTION'high) + 1;  -- to find the num of registers available
	attribute Bits  of T_SECOND_RESOLUTION : type is log2ceil(T_SECOND_RESOLUTION'Count);                    -- no of bits required to represent the num of registers	constant RESOLUTION_TIMES : T_TIME_VEC(0 to 2) := (1.0e-9, 1.0e-6, 1.0e-3);

	function to_enum(value : std_logic_vector)             return T_SECOND_RESOLUTION;
	function to_timebase(resolution : T_SECOND_RESOLUTION) return T_TIME;

	type T_CLOCK_DATETIME is record
		secondsResolution : unsigned(31 downto 0);  -- time in ns, us or ms
		seconds           : unsigned( 5 downto 0);
		minutes           : unsigned( 5 downto 0);
		hours             : unsigned( 4 downto 0);
		day               : unsigned( 4 downto 0);
		month             : unsigned( 3 downto 0);
		year              : unsigned(12 downto 0);
	end record;

	function slv_to_datetime(value_HMS: std_logic_vector(31 downto 0); value_Ymd: std_logic_vector(31 downto 0)) return T_CLOCK_DATETIME;
	function datetime_to_slv(value_slv: T_CLOCK_DATETIME)                                                        return std_logic_vector;
end package;

package body clock is

	function to_enum(value : std_logic_vector) return T_SECOND_RESOLUTION is
		constant pos : natural := to_integer(unsigned(value(T_SECOND_RESOLUTION'Bits - 1 downto 0)));
	begin
		return T_SECOND_RESOLUTION'val(minimum(pos, T_SECOND_RESOLUTION'Count - 1));
	end function;

	function to_timebase(resolution : T_SECOND_RESOLUTION) return T_TIME is
	begin
		return RESOLUTION_TIMES(T_SECOND_RESOLUTION'pos(resolution));
	end function;

	function slv_to_datetime(value_HMS: std_logic_vector(31 downto 0); value_Ymd: std_logic_vector(31 downto 0)) return T_CLOCK_DATETIME is
		variable datetime : T_CLOCK_DATETIME;
	begin
		datetime.secondsResolution := (others => '0');
		datetime.seconds           := unsigned(value_HMS( 5 downto  0));
		datetime.minutes           := unsigned(value_HMS(11 downto  6));
		datetime.hours             := unsigned(value_HMS(16 downto 12));
		datetime.day               := unsigned(value_Ymd( 4 downto  0));
		datetime.month             := unsigned(value_Ymd( 8 downto  5));
		datetime.year              := unsigned(value_Ymd(21 downto  9));
		return datetime;
	end function;

	function datetime_to_slv(value_slv: T_CLOCK_DATETIME) return std_logic_vector is
		variable value_Ymd: std_logic_vector(31 downto 0) := (others => '0');
		variable value_HMS: std_logic_vector(31 downto 0) := (others => '0');
	begin
		value_HMS( 5 downto  0) := std_logic_vector(value_slv.seconds);
		value_HMS(11 downto  6) := std_logic_vector(value_slv.minutes);
		value_HMS(16 downto 12) := std_logic_vector(value_slv.hours);
		value_Ymd( 4 downto  0) := std_logic_vector(value_slv.day);
		value_Ymd( 8 downto  5) := std_logic_vector(value_slv.month);
		value_Ymd(21 downto  9) := std_logic_vector(value_slv.year);
		return value_Ymd & value_HMS;
	end function;

end package body;
