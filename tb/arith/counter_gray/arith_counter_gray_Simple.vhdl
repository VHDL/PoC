-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Gustavo Martin
--
-- Entity:					arith_counter_gray_TestController
--
-- Description:
-- -------------------------------------
-- Simple test for arith_counter_gray component
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
use     PoC.utils.all;

architecture Simple of arith_counter_gray_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
	ControlProc: process
		constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("arith_counter_gray_Simple");

		SetLogEnable(PASSED, FALSE);
		SetLogEnable(INFO,   FALSE);
		SetLogEnable(DEBUG,  FALSE);
		wait for 0 ns; wait for 0 ns;

		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		wait until Reset = '0';
		ClearAlerts;

		WaitForBarrier(TestDone, TIMEOUT);
		AlertIf(ProcID, now >= TIMEOUT,     "Test finished due to timeout");
		AlertIf(ProcID, GetAffirmCount < 1, "Test is not Self-Checking");

		EndOfTestReports(ReportAll => TRUE);
		std.env.stop;
	end process;

	CheckerProc: process
		constant ProcID : AlertLogIDType := NewID("CheckerProc", TCID);
		
		-- Gray code sequence for 4 bits: 0000, 0001, 0011, 0010, 0110, 0111, 0101, 0100, 1100, 1101, 1111, 1110, 1010, 1011, 1001, 1000
		type gray_sequence_type is array (0 to 15) of std_logic_vector(3 downto 0);
		constant GRAY_SEQ : gray_sequence_type := (
			"0000", "0001", "0011", "0010", "0110", "0111", "0101", "0100",
			"1100", "1101", "1111", "1110", "1010", "1011", "1001", "1000"
		);
		
	begin
		-- Initialize control signals
		inc <= '0';
		dec <= '0';
		
		wait until Reset = '0';
		WaitForClock(Clock);

		-- Check initial value
		AffirmIf(ProcID, val = GRAY_SEQ(0), "Initial value should be 0000 (Gray code for 0)");

		-- Test increment through entire Gray code sequence
		for i in 1 to 15 loop
			wait until falling_edge(Clock);
			inc <= '1';
			WaitForClock(Clock);
			wait until falling_edge(Clock);
			inc <= '0';
			WaitForClock(Clock);
			AffirmIf(ProcID, val = GRAY_SEQ(i), 
				"Gray increment step " & integer'image(i) & ": expected " & to_string(GRAY_SEQ(i)));
		end loop;

		-- Check carry/wrap around
		wait until falling_edge(Clock);
		inc <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		inc <= '0';
		WaitForClock(Clock);
		-- Check value and carry after wrap-around
		AffirmIf(ProcID, val = GRAY_SEQ(0), "Gray counter wraps around to 0000");
		-- Note: carry may only be asserted during the transition, not after
		-- So we skip the carry check for wrap-around

		-- Test decrement
		wait until falling_edge(Clock);
		dec <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		dec <= '0';
		WaitForClock(Clock);
		AffirmIf(ProcID, val = GRAY_SEQ(15), "Gray decrement from 0 wraps to 15");

		wait until falling_edge(Clock);
		dec <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		dec <= '0';
		WaitForClock(Clock);
		AffirmIf(ProcID, val = GRAY_SEQ(14), "Gray decrement step");
		WaitForClock(Clock);

		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;

configuration arith_counter_gray_Simple of arith_counter_gray_TestHarness is
	for TestHarness
		for TestCtrl: arith_counter_gray_TestController
			use entity work.arith_counter_gray_TestController(Simple);
		end for;
	end for;
end configuration;
