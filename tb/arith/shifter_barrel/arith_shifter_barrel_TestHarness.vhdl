-- =============================================================================
-- Authors:       Gustavo Martin
--
-- Entity:        arith_shifter_barrel_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for arith_shifter_barrel component
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
use     PoC.utils.all;


entity arith_shifter_barrel_TestHarness is
end entity;


architecture TestHarness of arith_shifter_barrel_TestHarness is
	constant TPERIOD_CLOCK : time := 10 ns;

	constant BITS : positive := 8;

	signal Clock : std_logic := '1';
	signal Reset : std_logic := '1';

	signal Input           : std_logic_vector(BITS - 1 downto 0);
	signal ShiftAmount     : std_logic_vector(log2ceilnz(BITS) - 1 downto 0);
	signal ShiftRotate     : std_logic;
	signal LeftRight       : std_logic;
	signal ArithmeticLogic : std_logic;
	signal Output          : std_logic_vector(BITS - 1 downto 0);


	component arith_shifter_barrel_TestController is
		port (
			Clock           : in  std_logic;
			Reset           : in  std_logic;
			Input           : out std_logic_vector;
			ShiftAmount     : out std_logic_vector;
			ShiftRotate     : out std_logic;
			LeftRight       : out std_logic;
			ArithmeticLogic : out std_logic;
			Output          : in  std_logic_vector
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

	DUT : entity PoC.arith_shifter_barrel
		generic map (
			BITS => BITS
		)
		port map (
			Input           => Input,
			ShiftAmount     => ShiftAmount,
			ShiftRotate     => ShiftRotate,
			LeftRight       => LeftRight,
			ArithmeticLogic => ArithmeticLogic,
			Output          => Output
		);

	TestCtrl: component arith_shifter_barrel_TestController
		port map (
			Clock           => Clock,
			Reset           => Reset,
			Input           => Input,
			ShiftAmount     => ShiftAmount,
			ShiftRotate     => ShiftRotate,
			LeftRight       => LeftRight,
			ArithmeticLogic => ArithmeticLogic,
			Output          => Output
		);

end architecture;
