-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:       Gustavo Martin
--
-- Entity:        arith_cca_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for arith_cca component
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


entity arith_cca_TestHarness is
end entity;


architecture TestHarness of arith_cca_TestHarness is
	constant TPERIOD_CLOCK : time := 10 ns;

	constant N : positive := 8;
	constant L : natural  := 20;

	signal Clock : std_logic := '1';
	signal Reset : std_logic := '1';

	signal a : std_logic_vector(N - 1 downto 0);
	signal b : std_logic_vector(N - 1 downto 0);
	signal c : std_logic;
	signal s : std_logic_vector(N - 1 downto 0);


	component arith_cca_TestController is
		port (
			Clock : in  std_logic;
			Reset : in  std_logic;
			a     : out std_logic_vector;
			b     : out std_logic_vector;
			c     : out std_logic;
			s     : in  std_logic_vector
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

	DUT : entity PoC.arith_cca
		generic map (
			N => N,
			L => L,
			X => 0
		)
		port map (
			a => a,
			b => b,
			c => c,
			s => s
		);

	TestCtrl: component arith_cca_TestController
		port map (
			Clock => Clock,
			Reset => Reset,
			a     => a,
			b     => b,
			c     => c,
			s     => s
		);

end architecture;
