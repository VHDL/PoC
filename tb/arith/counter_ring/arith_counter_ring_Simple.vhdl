-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Gustavo Martin
--
-- Entity:					arith_counter_ring_TestController
--
-- Description:
-- -------------------------------------
-- Simple test for arith_counter_ring component
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

architecture Simple of arith_counter_ring_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
	ControlProc: process
		constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("arith_counter_ring_Simple");

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
		variable expected : std_logic_vector(value'range);
	begin
		-- Initialize control signals
		inc <= '0';
		dec <= '0';
		
		wait until Reset = '0';
		WaitForClock(Clock);

		-- Check initial value (seed)
		expected := "00000001";
		AffirmIf(ProcID, value = expected, "Initial value should be seed");

		-- Test increment (ring counter shift left)
		-- Use same pattern as BCD counter test: pulse inc for each increment
		
		-- First increment
		wait until falling_edge(Clock);
		inc <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		inc <= '0';
		WaitForClock(Clock);
		expected := "00000010";
		AffirmIf(ProcID, value = expected, "Increment: 00000001 -> 00000010");

		-- Second increment
		wait until falling_edge(Clock);
		inc <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		inc <= '0';
		WaitForClock(Clock);
		expected := "00000100";
		AffirmIf(ProcID, value = expected, "Increment: 00000010 -> 00000100");

		-- Third increment
		wait until falling_edge(Clock);
		inc <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		inc <= '0';
		WaitForClock(Clock);
		expected := "00001000";
		AffirmIf(ProcID, value = expected, "Increment: 00000100 -> 00001000");

		-- Continue incrementing to wrap around
		for i in 4 to 7 loop
			wait until falling_edge(Clock);
			inc <= '1';
			WaitForClock(Clock);
			wait until falling_edge(Clock);
			inc <= '0';
			WaitForClock(Clock);
			expected := std_logic_vector(shift_left(to_unsigned(1, value'length), i));
			AffirmIf(ProcID, value = expected, "Increment step " & integer'image(i));
		end loop;

		-- Should wrap around to initial value
		wait until falling_edge(Clock);
		inc <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		inc <= '0';
		WaitForClock(Clock);
		expected := "00000001";
		AffirmIf(ProcID, value = expected, "Increment wraps around to 00000001");

		-- Test decrement (ring counter shift right)
		wait until falling_edge(Clock);
		dec <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		dec <= '0';
		WaitForClock(Clock);
		expected := "10000000";
		AffirmIf(ProcID, value = expected, "Decrement: 00000001 -> 10000000");

		wait until falling_edge(Clock);
		dec <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		dec <= '0';
		WaitForClock(Clock);
		expected := "01000000";
		AffirmIf(ProcID, value = expected, "Decrement: 10000000 -> 01000000");

		wait until falling_edge(Clock);
		dec <= '1';
		WaitForClock(Clock);
		wait until falling_edge(Clock);
		dec <= '0';
		WaitForClock(Clock);
		expected := "00100000";
		AffirmIf(ProcID, value = expected, "Decrement: 01000000 -> 00100000");

		dec <= '0';
		WaitForClock(Clock);

		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;

configuration arith_counter_ring_Simple of arith_counter_ring_TestHarness is
	for TestHarness
		for TestCtrl: arith_counter_ring_TestController
			use entity work.arith_counter_ring_TestController(Simple);
		end for;
	end for;
end configuration;
