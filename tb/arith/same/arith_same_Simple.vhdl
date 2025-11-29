-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Gustavo Martin
--
-- Entity:					arith_same_TestController
--
-- Description:
-- -------------------------------------
-- Simple test for arith_same component
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

architecture Simple of arith_same_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
	ControlProc: process
		constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("arith_same_Simple");

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
	begin
		wait until Reset = '0';
		WaitForClock(Clock);

		-- Test with guard = 1 (active)
		g <= '1';
		
		-- Test all zeros
		x <= (x'range => '0');
		WaitForClock(Clock);
		AffirmIf(ProcID, y = '1', "All zeros should return '1'");

		-- Test all ones
		x <= (x'range => '1');
		WaitForClock(Clock);
		AffirmIf(ProcID, y = '1', "All ones should return '1'");

		-- Test mixed values (should return '0')
		x <= "10101010";
		WaitForClock(Clock);
		AffirmIf(ProcID, y = '0', "Mixed values should return '0'");

		x <= "01010101";
		WaitForClock(Clock);
		AffirmIf(ProcID, y = '0', "Mixed values should return '0'");

		x <= "11111110";
		WaitForClock(Clock);
		AffirmIf(ProcID, y = '0', "Almost all ones should return '0'");

		x <= "00000001";
		WaitForClock(Clock);
		AffirmIf(ProcID, y = '0', "Almost all zeros should return '0'");

		-- Test with guard = 0 (inactive, should always return 0)
		g <= '0';
		
		x <= (x'range => '0');
		WaitForClock(Clock);
		AffirmIf(ProcID, y = '0', "Guard=0 should return '0' even for all zeros");

		x <= (x'range => '1');
		WaitForClock(Clock);
		AffirmIf(ProcID, y = '0', "Guard=0 should return '0' even for all ones");

		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;

configuration arith_same_Simple of arith_same_TestHarness is
	for TestHarness
		for TestCtrl: arith_same_TestController
			use entity work.arith_same_TestController(Simple);
		end for;
	end for;
end configuration;
