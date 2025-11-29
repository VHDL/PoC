-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Gustavo Martin
--
-- Entity:					arith_counter_free_TestController
--
-- Description:
-- -------------------------------------
-- Simple test for arith_counter_free component
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

architecture Simple of arith_counter_free_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
	ControlProc: process
		constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("arith_counter_free_Simple");

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
		constant DIVIDER : positive := 5;
	begin
		wait until Reset = '0';
		WaitForClock(Clock);

		-- Test with continuous increment
		inc <= '1';
		
		-- Should not assert strobe for first DIVIDER-1 cycles
		for i in 1 to DIVIDER-1 loop
			AffirmIf(ProcID, stb = '0', "Strobe should be low before divider count reached (cycle " & integer'image(i) & ")");
			WaitForClock(Clock);
		end loop;

		-- On DIVIDER-th cycle, strobe should be asserted
		AffirmIf(ProcID, stb = '1', "Strobe should be high after " & integer'image(DIVIDER) & " cycles");
		WaitForClock(Clock);

		-- Next cycle, strobe should be low again and start new count
		AffirmIf(ProcID, stb = '0', "Strobe should return to low after assertion");
		
		-- Test another cycle
		for i in 1 to DIVIDER-2 loop
			WaitForClock(Clock);
			AffirmIf(ProcID, stb = '0', "Strobe should be low in second cycle (iteration " & integer'image(i) & ")");
		end loop;

		WaitForClock(Clock);
		AffirmIf(ProcID, stb = '1', "Strobe should be high again after another " & integer'image(DIVIDER) & " cycles");

		inc <= '0';
		WaitForClock(Clock);

		-- Test with inc = 0, strobe should remain low
		for i in 1 to 10 loop
			AffirmIf(ProcID, stb = '0', "Strobe should remain low when inc=0 (cycle " & integer'image(i) & ")");
			WaitForClock(Clock);
		end loop;

		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;

configuration arith_counter_free_Simple of arith_counter_free_TestHarness is
	for TestHarness
		for TestCtrl: arith_counter_free_TestController
			use entity work.arith_counter_free_TestController(Simple);
		end for;
	end for;
end configuration;
