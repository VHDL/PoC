-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:       Gustavo Martin
--
-- Entity:        arith_counter_gray_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for arith_counter_gray component
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
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


entity arith_counter_gray_TestHarness is
end entity;


architecture TestHarness of arith_counter_gray_TestHarness is
	constant TPERIOD_CLOCK : time := 10 ns;

	constant BITS : positive := 4;
	constant INIT : natural  := 0;

	signal Clock_100 : std_logic := '1';
	signal Reset_100 : std_logic := '1';

	signal inc : std_logic;
	signal dec : std_logic;
	signal val : std_logic_vector(BITS - 1 downto 0);
	signal cry : std_logic;


	component arith_counter_gray_TestController is
		port (
			Clock : in  std_logic;
			Reset : in  std_logic;
			inc   : out std_logic;
			dec   : out std_logic;
			val   : in  std_logic_vector;
			cry   : in  std_logic
		);
	end component;

begin
	Osvvm.ClockResetPkg.CreateClock(
		Clk    => Clock_100,
		Period => TPERIOD_CLOCK
	);

	Osvvm.ClockResetPkg.CreateReset(
		Reset       => Reset_100,
		ResetActive => '1',
		Clk         => Clock_100,
		Period      => 5 * TPERIOD_CLOCK,
		tpd         => 0 ns
	);

	DUT : entity PoC.arith_counter_gray
		generic map (
			BITS => BITS,
			INIT => INIT
		)
		port map (
			clk => Clock_100,
			rst => Reset_100,
			inc => inc,
			dec => dec,
			val => val,
			cry => cry
		);

	TestCtrl: component arith_counter_gray_TestController
		port map (
			Clock => Clock_100,
			Reset => Reset_100,
			inc   => inc,
			dec   => dec,
			val   => val,
			cry   => cry
		);

end architecture;
