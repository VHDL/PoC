-- =============================================================================
-- Authors:          Patrick Lehmann
--
-- Testbench:        Testbench to verify a stretched strobe signal
--
-- Description:
-- ------------------------------------
--    Converted to OSVVM style. Checker assertions are pending (TODO).
--
-- License:
-- =============================================================================
-- Copyright 2017-2020 Patrick Lehmann - Boetzingen, Germany
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly
-- prohibited.
-- Proprietary and confidential
-- =============================================================================

library IEEE;
use     IEEE.STD_LOGIC_1164.all;
use     IEEE.NUMERIC_STD.all;

library PoC;
use     PoC.utils.all;

library osvvm;
context osvvm.OsvvmContext;


entity Tb_misc_StrobeStretcher is
end entity;


architecture tb of Tb_misc_StrobeStretcher is
	constant TestName   : string := "Tb_misc_StrobeStretcher";
	constant CLK_PERIOD : time   := 10 ns;

	signal Clock      : std_logic;
	signal Strobe_in  : std_logic := '0';
	signal Strobe_out : std_logic;
	signal TestDone   : integer_barrier := 1;

begin

	Osvvm.ClockResetPkg.CreateClock(Clk => Clock, Period => CLK_PERIOD);

	ControlProc : process
	begin
		SetTestName(TestName);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		Log("NOTE: This is a mechanically converted old-style testbench and needs a proper OSVVM port.", INFO);
		WaitForBarrier(TestDone, 10 ms);
		AlertIf(now >= 10 ms, "Test timed out");
		EndOfTestReports;
		std.env.stop;
	end process;

	procStimuli : process
	begin
		Strobe_in <= '0';
		wait until rising_edge(Clock);

		Strobe_in <= '1';
		wait until rising_edge(Clock);

		Strobe_in <= '0';
		wait until rising_edge(Clock);
		wait until rising_edge(Clock);
		wait until rising_edge(Clock);
		wait until rising_edge(Clock);
		wait until rising_edge(Clock);

		Strobe_in <= '1';
		wait until rising_edge(Clock);

		Strobe_in <= '0';
		wait until rising_edge(Clock);
		wait until rising_edge(Clock);
		wait until rising_edge(Clock);
		wait until rising_edge(Clock);
		wait until rising_edge(Clock);

		WaitForBarrier(TestDone);
		wait;
	end process;

	UUT : entity PoC.misc_StrobeStretcher
		generic map (
			OUTPUT_CYCLES => 3
		)
		port map (
			Clock     => Clock,
			Input(0)  => Strobe_in,
			Output(0) => Strobe_out
		);
end architecture;
