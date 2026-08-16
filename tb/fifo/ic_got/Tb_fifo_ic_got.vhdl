-- =============================================================================
-- Authors:          Thomas B. Preusser
--                   Stefan Unrein
--
-- Entity:           Tb_fifo_ic_got
--
-- Description:
-- -------------------------------------
-- Testbench for fifo_ic_got (independent clocks).
-- Chains two FIFO instances across three clock domains (14 ns / 24 ns / 10 ns)
-- and verifies data integrity using comm_Scramble reference sequences.
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

entity Tb_fifo_ic_got is
end entity;

architecture tb of Tb_fifo_ic_got is
	constant TestName        : string  := "Tb_fifo_ic_got";
	constant TIMEOUT         : time    := 10 ms;

	constant DATA_BITS        : positive := 9;
	constant MIN_DEPTH        : positive := 8;
	constant OUTPUT_REG       : boolean  := true;
	constant EMPTY_STATE_BITS : natural  := 2;
	constant FILL_STATE_BITS  : natural  := 2;

	constant POLYNOMIAL : bit_vector  := "100110001";

	signal Reset  : std_logic;
	signal Clock0 : std_logic;
	signal Clock1 : std_logic;
	signal Clock2 : std_logic;

	signal TestDone : integer_barrier := 3;

	-- Clock0 → Clock1 transfer
	signal DataIn0  : std_logic_vector(DATA_BITS - 1 downto 0);
	signal Put0     : std_logic;
	signal Full0    : std_logic;

	signal DataOut1 : std_logic_vector(DATA_BITS - 1 downto 0);
	signal Valid1   : std_logic;
	signal Got1     : std_logic;

	-- Clock1 → Clock2 transfer
	signal DataIn1  : std_logic_vector(DATA_BITS - 1 downto 0);
	signal Put1     : std_logic;
	signal Full1    : std_logic;

	signal DataOut2 : std_logic_vector(DATA_BITS - 1 downto 0);
	signal Valid2   : std_logic;
	signal Got2     : std_logic;

	-- Clock2 reference sequence (for final output check)
	signal DataRef2 : std_logic_vector(DATA_BITS - 1 downto 0);

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

	Osvvm.ClockResetPkg.CreateClock(Clk => Clock0, Period => 14 ns);
	Osvvm.ClockResetPkg.CreateClock(Clk => Clock1, Period => 24 ns);
	Osvvm.ClockResetPkg.CreateClock(Clk => Clock2, Period => 10 ns);
	-- Reset driven by fastest clock, 30 ns pulse matches original
	Osvvm.ClockResetPkg.CreateReset(
		Reset       => Reset,
		ResetActive => '1',
		Clk         => Clock2,
		Period      => 3 * 10 ns,
		tpd         => 0 ns
	);

	------------------------------------------------------------
	-- Input sequence generator (Clock0 domain)
	------------------------------------------------------------
	gen0 : entity PoC.comm_Scramble
		generic map (
			POLYNOMIAL => POLYNOMIAL,
			BITS       => DATA_BITS
		)
		port map (
			Clock  => Clock0,
			Load   => Reset,
			Enable => Put0,
			Value  => DataIn0
		);

	------------------------------------------------------------
	-- Writer (Clock0 domain)
	------------------------------------------------------------
	procWriter : process
		variable cnt : natural := 0;
	begin
		Put0 <= '0';
		wait until Reset = '0' and rising_edge(Clock0);

		-- Slow input phase: write while FIFO has room and output is empty
		while cnt < 2 * MIN_DEPTH loop
			wait until falling_edge(Clock0);
			if Full0 = '0' and Valid1 = '0' then
				Put0 <= '1';
				cnt  := cnt + 1;
			else
				Put0 <= '0';
			end if;
		end loop;

		-- Fast input phase: write whenever not full
		while cnt < 4 * MIN_DEPTH loop
			wait until falling_edge(Clock0);
			if Full0 = '0' then
				Put0 <= '1';
				cnt  := cnt + 1;
			else
				Put0 <= '0';
			end if;
		end loop;

		wait until falling_edge(Clock0);
		Put0 <= '0';

		WaitForBarrier(TestDone);
		wait;
	end process;

	------------------------------------------------------------
	-- FIFO 0→1 (Clock0 write, Clock1 read)
	------------------------------------------------------------
	fifo0_1 : entity PoC.fifo_ic_got
		generic map (
			DATA_BITS        => DATA_BITS,
			MIN_DEPTH        => MIN_DEPTH,
			OUTPUT_REG       => OUTPUT_REG,
			EMPTY_STATE_BITS => EMPTY_STATE_BITS,
			FILL_STATE_BITS  => FILL_STATE_BITS
		)
		port map (
			Write_Clock      => Clock0,
			Write_Reset      => Reset,
			Write_Put        => Put0,
			Write_DataIn     => DataIn0,
			Write_Full       => Full0,
			Write_EmptyState => open,

			Read_Clock     => Clock1,
			Read_Reset     => Reset,
			Read_Got       => Got1,
			Read_Valid     => Valid1,
			Read_DataOut   => DataOut1,
			Read_FillState => open
		);

	------------------------------------------------------------
	-- Intermediate reference sequence generator (Clock1 domain)
	------------------------------------------------------------
	gen1 : entity PoC.comm_Scramble
		generic map (
			POLYNOMIAL => POLYNOMIAL,
			BITS       => DATA_BITS
		)
		port map (
			Clock  => Clock1,
			Load   => Reset,
			Enable => Put1,
			Value  => DataIn1
		);

	Got1 <= Valid1 and not Full1;
	Put1 <= Got1;

	------------------------------------------------------------
	-- Pass-through checker (Clock1 domain)
	------------------------------------------------------------
	procChecker : process
		variable cnt : natural := 0;
	begin
		while cnt < 4 * MIN_DEPTH loop
			wait until rising_edge(Clock1);
			AffirmIf((Reset = '1') or (Put1 = '0') or (DataOut1 = DataIn1),
				"Mismatch in Clock1 domain @ count " & integer'image(cnt));
			if Put1 = '1' then
				cnt := cnt + 1;
			end if;
		end loop;

		WaitForBarrier(TestDone);
		wait;
	end process;

	------------------------------------------------------------
	-- FIFO 1→2 (Clock1 write, Clock2 read)
	------------------------------------------------------------
	fifo1_2 : entity PoC.fifo_ic_got
		generic map (
			DATA_REG         => true,
			DATA_BITS        => DATA_BITS,
			MIN_DEPTH        => MIN_DEPTH,
			EMPTY_STATE_BITS => EMPTY_STATE_BITS,
			FILL_STATE_BITS  => FILL_STATE_BITS
		)
		port map (
			Write_Clock      => Clock1,
			Write_Reset      => Reset,
			Write_Put        => Put1,
			Write_DataIn     => DataIn1,
			Write_Full       => Full1,
			Write_EmptyState => open,

			Read_Clock     => Clock2,
			Read_Reset     => Reset,
			Read_Got       => Got2,
			Read_Valid     => Valid2,
			Read_DataOut   => DataOut2,
			Read_FillState => open
		);

	------------------------------------------------------------
	-- Final reference sequence generator (Clock2 domain)
	------------------------------------------------------------
	gen2 : entity PoC.comm_Scramble
		generic map (
			POLYNOMIAL => POLYNOMIAL,
			BITS       => DATA_BITS
		)
		port map (
			Clock  => Clock2,
			Load   => Reset,
			Enable => Got2,
			Value  => DataRef2
		);

	------------------------------------------------------------
	-- Reader / final checker (Clock2 domain)
	------------------------------------------------------------
	procReader : process
		variable cnt : natural := 0;
		variable del : natural := 0;
	begin
		while cnt < 4 * MIN_DEPTH loop
			wait until rising_edge(Clock2);
			Got2 <= '0';
			if Valid2 = '1' then
				del := del + 1;
				if del = 3 then
					Got2 <= '1';
					AffirmIf(DataRef2 = DataOut2,
						"Mismatch in Clock2 domain @ count " & integer'image(cnt));
					cnt := cnt + 1;
					del := 0;
				end if;
			end if;
		end loop;

		WaitForBarrier(TestDone);
		wait;
	end process;

end architecture;
