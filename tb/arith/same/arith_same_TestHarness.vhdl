-- =============================================================================
-- Authors:       Gustavo Martin
--
-- Entity:        arith_same_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for arith_same component
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

library osvvm;
context osvvm.OsvvmContext;

library PoC;


entity arith_same_TestHarness is
end entity;


architecture TestHarness of arith_same_TestHarness is
	constant TPERIOD_CLOCK : time := 10 ns;

	constant BITS : positive := 8;

	signal Clock : std_logic := '1';
	signal Reset : std_logic := '1';

	signal g : std_logic;
	signal x : std_logic_vector(BITS - 1 downto 0);
	signal y : std_logic;


	component arith_same_TestController is
		port (
			Clock : in  std_logic;
			Reset : in  std_logic;
			g     : out std_logic;
			x     : out std_logic_vector;
			y     : in  std_logic
		);
	end component;

begin
	Osvvm.ClockResetPkg.CreateClock(
		Clk    => Clock,
		Period => TPERIOD_CLOCK
	);

	Osvvm.ClockResetPkg.CreateReset(
		Reset       => Reset,
		ResetActive => '1',
		Clk         => Clock,
		Period      => 5 * TPERIOD_CLOCK,
		tpd         => 0 ns
	);

	DUT : entity PoC.arith_same
		generic map (
			N => BITS
		)
		port map (
			g => g,
			x => x,
			y => y
		);

	TestCtrl: component arith_same_TestController
		port map (
			Clock => Clock,
			Reset => Reset,
			g     => g,
			x     => x,
			y     => y
		);

end architecture;
