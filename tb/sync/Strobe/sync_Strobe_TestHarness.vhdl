-- =============================================================================
-- Authors:          Gustavo Martin
--
-- Entity:           sync_Strobe_TestHarness
--
-- Description:
-- -------------------------------------
-- OSVVM testbench harness for strobe signal synchronizer
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


entity sync_Strobe_TestHarness is
end entity;


architecture TestHarness of sync_Strobe_TestHarness is
	-- Clock periods (100 MHz and 60 MHz)
	constant TPERIOD_CLOCK_1 : time := 10 ns;
	constant TPERIOD_CLOCK_2 : time := 16.667 ns;

	constant BITS : positive := 1;

	signal Clock1 : std_logic := '1';
	signal Clock2 : std_logic := '1';

	signal Input  : std_logic_vector(BITS - 1 downto 0);
	signal Output : std_logic_vector(BITS - 1 downto 0);
	signal Busy   : std_logic_vector(BITS - 1 downto 0);


	component sync_Strobe_TestController is
		port (
			Clock1 : in  std_logic;
			Clock2 : in  std_logic;
			Input  : out std_logic_vector;
			Output : in  std_logic_vector;
			Busy   : in  std_logic_vector
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

	DUT : entity PoC.sync_Strobe
		generic map (
			BITS                => BITS,
			GATED_INPUT_BY_BUSY => TRUE
		)
		port map (
			Clock1 => Clock1,
			Clock2 => Clock2,
			Input  => Input,
			Output => Output,
			Busy   => Busy
		);

	TestCtrl : component sync_Strobe_TestController
		port map (
			Clock1 => Clock1,
			Clock2 => Clock2,
			Input  => Input,
			Output => Output,
			Busy   => Busy
		);

end architecture;
