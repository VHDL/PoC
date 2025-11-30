-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:          Gustavo Martin
--
-- Entity:           sync_Bits_TestHarness
--
-- Description:
-- -------------------------------------
-- OSVVM testbench harness for flag signal synchronizer
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


entity sync_Bits_TestHarness is
end entity;


architecture TestHarness of sync_Bits_TestHarness is
	-- Clock periods (100 MHz and 60 MHz)
	constant TPERIOD_CLOCK_1 : time := 10 ns;
	constant TPERIOD_CLOCK_2 : time := 16.667 ns;

	constant BITS : positive := 1;
	constant INIT : std_logic_vector(BITS - 1 downto 0) := (others => '0');

	signal Clock1 : std_logic := '1';
	signal Clock2 : std_logic := '1';
	signal Reset  : std_logic := '1';

	signal Sync_in  : std_logic_vector(BITS - 1 downto 0);
	signal Sync_out : std_logic_vector(BITS - 1 downto 0);


	component sync_Bits_TestController is
		port (
			Clock1   : in  std_logic;
			Clock2   : in  std_logic;
			Reset    : in  std_logic;
			Sync_in  : out std_logic_vector;
			Sync_out : in  std_logic_vector
		);
	end component;

begin
	Osvvm.ClockResetPkg.CreateClock(
		Clk    => Clock1,
		Period => TPERIOD_CLOCK_1
	);

	Osvvm.ClockResetPkg.CreateClock(
		Clk    => Clock2,
		Period => TPERIOD_CLOCK_2
	);

	Osvvm.ClockResetPkg.CreateReset(
		Reset       => Reset,
		ResetActive => '1',
		Clk         => Clock1,
		Period      => 5 * TPERIOD_CLOCK_1,
		tpd         => 0 ns
	);

	DUT : entity PoC.sync_Bits
		generic map (
			BITS => BITS,
			INIT => INIT
		)
		port map (
			Clock  => Clock2,
			Input  => Sync_in,
			Output => Sync_out
		);

	TestCtrl : component sync_Bits_TestController
		port map (
			Clock1   => Clock1,
			Clock2   => Clock2,
			Reset    => Reset,
			Sync_in  => Sync_in,
			Sync_out => Sync_out
		);

end architecture;
