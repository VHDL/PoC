-- =============================================================================
-- Authors:
--
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

use     work.utils.all;


entity clock_Counter is
	generic (
		MODULO : positive;
		BITS   : natural := log2ceilnz(MODULO)
	);
	port (
		Clock      : in  std_logic;
		Reset      : in  std_logic := '0';
		Enable     : in  std_logic := '1';
		Load       : in  std_logic := '0';

		LoadValue  : in  unsigned(BITS - 1 downto 0);
		Value      : out unsigned(BITS - 1 downto 0);
		WrapAround : out std_logic
	);
end entity;


architecture rtl of clock_Counter is

	signal Load_d        : std_logic := '0';
	signal Load_re       : std_logic;
	signal CounterValue  : unsigned(log2ceilnz(MODULO) - 1 downto 0) := (others => '0');

begin
	Load_d  <= Load when rising_edge(Clock);
	Load_re <= not Load_d and Load;

	process (Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset or WrapAround) = '1') then
				CounterValue <= (others => '0');
			elsif Load_re = '1' then
				CounterValue <= LoadValue;
			elsif Enable = '1' then
				CounterValue <= CounterValue + 1;
			end if;
		end if;
	end process;

	Value      <= resize(CounterValue, BITS);
	WrapAround <= Enable when (CounterValue = MODULO - 1) else '0';
end architecture;
