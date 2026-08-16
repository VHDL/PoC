-- =============================================================================
-- Authors:          Thomas B. Preusser
--                   Stefan Unrein
--
-- Entity:           Tb_fifo_cc_got
--
-- Description:
-- -------------------------------------
-- Testbench for fifo_cc_got (common clock, got interface).
-- Runs 8 configurations varying DATA_REG, STATE_REG, OUTPUT_REG.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
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

library PoC;
use     PoC.utils.all;

library osvvm;
context osvvm.OsvvmContext;

entity Tb_fifo_cc_got is
end entity;

architecture tb of Tb_fifo_cc_got is
	constant TestName        : string   := "Tb_fifo_cc_got";
	constant CLOCK_PERIOD    : time     := 10 ns;
	constant TIMEOUT         : time     := 10 ms;

	constant DATA_BITS        : positive := 8;
	constant MIN_DEPTH        : positive := 30;
	constant EMPTY_STATE_BITS : natural  := 2;
	constant FILL_STATE_BITS  : natural  := 2;

	signal Clock    : std_logic;
	signal Reset    : std_logic;
	signal TestDone : integer_barrier := 8;

begin

	------------------------------------------------------------
	-- ControlProc
	------------------------------------------------------------
	ControlProc : process
	begin
		SetTestName(TestName);
		SetLogEnable(PASSED, FALSE);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		Log("NOTE: This is a mechanically converted old-style testbench and needs a proper OSVVM port.", INFO);

		wait until Reset = '0';
		ClearAlerts;

		WaitForBarrier(TestDone, TIMEOUT);
		AlertIf(now >= TIMEOUT,         "Test timed out");
		AlertIf(GetAffirmCount < 1,     "Test is not Self-Checking");

		EndOfTestReports;
		std.env.stop;
	end process;

	Osvvm.ClockResetPkg.CreateClock(Clk => Clock, Period => CLOCK_PERIOD);
	Osvvm.ClockResetPkg.CreateReset(
		Reset       => Reset,
		ResetActive => '1',
		Clk         => Clock,
		Period      => 10 * CLOCK_PERIOD,
		tpd         => 0 ns
	);

	------------------------------------------------------------
	-- Generate 8 DUT configurations
	------------------------------------------------------------
	genDUTs : for c in 0 to 7 generate
		constant DATA_REG   : boolean := c mod 2 > 0;
		constant STATE_REG  : boolean := c mod 4 > 1;
		constant OUTPUT_REG : boolean := c mod 8 > 3;

		signal Put        : std_logic;
		signal DataIn     : std_logic_vector(DATA_BITS - 1 downto 0);
		signal Full       : std_logic;
		signal EmptyState : std_logic_vector(EMPTY_STATE_BITS - 1 downto 0);
		signal Got        : std_logic;
		signal DataOut    : std_logic_vector(DATA_BITS - 1 downto 0);
		signal Valid      : std_logic;
		signal FillState  : std_logic_vector(FILL_STATE_BITS - 1 downto 0);

	begin

		DUT : entity PoC.fifo_cc_got
			generic map (
				DATA_BITS        => DATA_BITS,
				MIN_DEPTH        => MIN_DEPTH,
				DATA_REG         => DATA_REG,
				STATE_REG        => STATE_REG,
				OUTPUT_REG       => OUTPUT_REG,
				EMPTY_STATE_BITS => EMPTY_STATE_BITS,
				FILL_STATE_BITS  => FILL_STATE_BITS
			)
			port map (
				Clock      => Clock,
				Reset      => Reset,
				Put        => Put,
				DataIn     => DataIn,
				Full       => Full,
				EmptyState => EmptyState,
				Got        => Got,
				DataOut    => DataOut,
				Valid      => Valid,
				FillState  => FillState
			);

		procWriter : process
		begin
			DataIn <= (others => '-');
			Put    <= '0';
			wait until rising_edge(Clock) and Reset = '0';

			for i in 0 to 2**(DATA_BITS - 1) - 1 loop
				DataIn <= std_logic_vector(to_unsigned(i, DATA_BITS));
				Put    <= '1';
				wait until rising_edge(Clock) and Full = '0';
			end loop;

			for i in 2**(DATA_BITS - 1) to 2**DATA_BITS - 1 loop
				DataIn <= (others => '-');
				Put    <= '0';
				wait until rising_edge(Clock) and Valid = '0';
				DataIn <= std_logic_vector(to_unsigned(i, DATA_BITS));
				Put    <= '1';
				wait until rising_edge(Clock);
			end loop;

			DataIn <= (others => '-');
			Put    <= '0';
			wait;
		end process;

		procReader : process
		begin
			Got <= '0';
			for i in 0 to 2**DATA_BITS - 1 loop
				wait until rising_edge(Clock) and Valid = '1';
				AffirmIf(DataOut = std_logic_vector(to_unsigned(i, DATA_BITS)),
					"Output failure in config " & integer'image(c) & " @ pos " & integer'image(i) &
					": got " & to_hstring(DataOut));
				Got <= '1';
				wait until rising_edge(Clock);
				Got <= '0';
				wait until rising_edge(Clock);
			end loop;
			WaitForBarrier(TestDone);
			wait;
		end process;

	end generate;
end architecture;
