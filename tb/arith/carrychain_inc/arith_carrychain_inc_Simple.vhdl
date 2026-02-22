-- =============================================================================
-- Authors:					Gustavo Martin
--
-- Entity:					arith_carrychain_inc_TestController
--
-- Description:
-- -------------------------------------
-- Simple test for arith_carrychain_inc component
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

architecture Simple of arith_carrychain_inc_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
	ControlProc: process
		constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("arith_carrychain_inc_Simple");

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
		variable expected : unsigned(Y'range);
	begin
		wait until Reset = '0';
		WaitForClock(Clock);

		-- Test with CIn = 1 (increment)
		CIn <= '1';
		
		X <= x"00";
		wait for 1 ns;
		expected := to_unsigned(1, Y'length);
		AffirmIf(ProcID, unsigned(Y) = expected, "0x00 + 1 = 0x01");

		X <= x"0F";
		wait for 1 ns;
		expected := to_unsigned(16, Y'length);
		AffirmIf(ProcID, unsigned(Y) = expected, "0x0F + 1 = 0x10");

		X <= x"FF";
		wait for 1 ns;
		expected := to_unsigned(0, Y'length);
		AffirmIf(ProcID, unsigned(Y) = expected, "0xFF + 1 = 0x00 (overflow)");

		X <= x"7F";
		wait for 1 ns;
		expected := to_unsigned(128, Y'length);
		AffirmIf(ProcID, unsigned(Y) = expected, "0x7F + 1 = 0x80");

		X <= x"55";
		wait for 1 ns;
		expected := to_unsigned(86, Y'length);
		AffirmIf(ProcID, unsigned(Y) = expected, "0x55 + 1 = 0x56");

		-- Test with CIn = 0 (no increment, just pass through)
		CIn <= '0';
		
		X <= x"00";
		wait for 1 ns;
		expected := to_unsigned(0, Y'length);
		AffirmIf(ProcID, unsigned(Y) = expected, "0x00 + 0 = 0x00");

		X <= x"FF";
		wait for 1 ns;
		expected := to_unsigned(255, Y'length);
		AffirmIf(ProcID, unsigned(Y) = expected, "0xFF + 0 = 0xFF");

		X <= x"A5";
		wait for 1 ns;
		expected := to_unsigned(165, Y'length);
		AffirmIf(ProcID, unsigned(Y) = expected, "0xA5 + 0 = 0xA5");

		WaitForClock(Clock);
		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;

configuration arith_carrychain_inc_Simple of arith_carrychain_inc_TestHarness is
	for TestHarness
		for TestCtrl: arith_carrychain_inc_TestController
			use entity work.arith_carrychain_inc_TestController(Simple);
		end for;
	end for;
end configuration;
