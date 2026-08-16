-- =============================================================================
-- Authors:          Thomas B. Preusser
--                   Stefan Unrein
--
-- Entity:           Tb_fifo_cc_got_tempput
--
-- Description:
-- -------------------------------------
-- Testbench for fifo_cc_got_tempput (common clock, temporary put with
-- commit/rollback). Runs 8 configurations varying DATA_REG, STATE_REG,
-- OUTPUT_REG.
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

entity Tb_fifo_cc_got_tempput is
end entity;

architecture tb of Tb_fifo_cc_got_tempput is
	constant TestName        : string   := "Tb_fifo_cc_got_tempput";
	constant CLOCK_PERIOD    : time     := 10 ns;
	constant TIMEOUT         : time     := 10 ms;

	constant DATA_BITS        : positive := 8;
	constant MIN_DEPTH        : positive := 8;
	constant EMPTY_STATE_BITS : natural  := 2;
	constant FILL_STATE_BITS  : natural  := 2;

	constant ISPEC      : string      := "C C Cccccpppp pppp c ccc pp         Cppppp ppp rp RpC";
	constant OSPEC      : string      := "ggg                      gggggggg  ggg G           G";
	constant POLYNOMIAL : bit_vector  := "100110001";

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
		AlertIf(now >= TIMEOUT,     "Test timed out");
		AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

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
	genTests : for c in 0 to 7 generate
		constant DATA_REG   : boolean := c mod 2 > 0;
		constant STATE_REG  : boolean := c mod 4 > 1;
		constant OUTPUT_REG : boolean := c mod 8 > 3;

		signal Put      : std_logic;
		signal PutX     : std_logic;
		signal DataIn   : std_logic_vector(DATA_BITS - 1 downto 0);
		signal Full     : std_logic;
		signal Commit   : std_logic;
		signal Rollback : std_logic;
		signal Got      : std_logic;
		signal GotX     : std_logic;
		signal DataOut  : std_logic_vector(DATA_BITS - 1 downto 0);
		signal DataRef  : std_logic_vector(DATA_BITS - 1 downto 0);
		signal Valid    : std_logic;

	begin

		PutX <= Put and not Full;

		-- Input reference sequence generator
		genInp : entity PoC.comm_Scramble
			generic map (
				POLYNOMIAL => POLYNOMIAL,
				BITS       => DATA_BITS
			)
			port map (
				Clock  => Clock,
				Load   => Reset,
				Enable => PutX,
				Value  => DataIn
			);

		procWriter : process
		begin
			wait until rising_edge(Clock);

			for i in ISPEC'range loop
				Put      <= '0';
				Commit   <= '0';
				Rollback <= '0';
				case ISPEC(i) is
					when ' ' =>
						wait until rising_edge(Clock);
					when 'p' =>
						Put <= '1';
						wait until rising_edge(Clock) and Full = '0';
					when 'c' =>
						Commit <= '1';
						wait until rising_edge(Clock);
					when 'C' =>
						Put    <= '1';
						Commit <= '1';
						wait until rising_edge(Clock) and Full = '0';
					when 'r' =>
						Rollback <= '1';
						wait until rising_edge(Clock);
					when 'R' =>
						Put      <= '1';
						Rollback <= '1';
						wait until rising_edge(Clock) and Full = '0';
					when others =>
						report "Illegal ISPEC character." severity failure;
				end case;
			end loop;
			Put    <= '0';
			Commit <= '0';
			wait;
		end process;

		DUT : entity PoC.fifo_cc_got_tempput
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
				EmptyState => open,
				Commit     => Commit,
				Rollback   => Rollback,
				Got        => Got,
				DataOut    => DataOut,
				Valid      => Valid,
				FillState  => open
			);

		procReader : process
		begin
			for i in OSPEC'range loop
				case OSPEC(i) is
					when ' ' =>
						Got <= '0';
						wait until rising_edge(Clock);
					when 'g' =>
						Got <= '1';
						wait until rising_edge(Clock) and Valid = '1';
						AffirmIf(DataOut = DataRef,
							"Test #" & integer'image(c) & ": Output Mismatch at OSPEC pos " & integer'image(i));
					when 'G' =>
						Got <= '1';
						wait until rising_edge(Clock) and Valid = '1';
						AffirmIf(DataOut /= DataRef,
							"Test #" & integer'image(c) & ": Expected mismatch at OSPEC pos " & integer'image(i));
					when others =>
						report "Illegal OSPEC character." severity failure;
				end case;
			end loop;
			WaitForBarrier(TestDone);
			wait;
		end process;

		GotX <= Got and Valid;

		-- Output reference sequence generator
		genOut : entity PoC.comm_Scramble
			generic map (
				POLYNOMIAL => POLYNOMIAL,
				BITS       => DATA_BITS
			)
			port map (
				Clock  => Clock,
				Load   => Reset,
				Enable => GotX,
				Value  => DataRef
			);

	end generate;
end architecture;
