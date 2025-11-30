-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:          Patrick Lehmann
--                   Gustavo Martin
--
-- Entity:           sync_Vector_TestController (Simple architecture)
--
-- Description:
-- -------------------------------------
-- OSVVM simple test for vector signal synchronizer.
-- Tests that vector signals propagate correctly across clock domains.
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
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


architecture Simple of sync_Vector_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType := NewID("TestCtrl");
	
	constant INIT : std_logic_vector(Output'range) := (others => '0');

begin
	ControlProc : process
		constant ProcID  : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("sync_Vector_Simple");

		SetLogEnable(PASSED, FALSE);
		SetLogEnable(INFO,   FALSE);
		SetLogEnable(DEBUG,  FALSE);
		wait for 0 ns; wait for 0 ns;

		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		WaitForClock(Clock1, 4);
		ClearAlerts;

		WaitForBarrier(TestDone, TIMEOUT);
		AlertIf(ProcID, now >= TIMEOUT,     "Test finished due to timeout");
		AlertIf(ProcID, GetAffirmCount < 1, "Test is not Self-Checking");

		EndOfTestReports(ReportAll => TRUE);
		std.env.stop;
	end process;

	StimuliProc : process
		constant ProcID : AlertLogIDType := NewID("StimuliProc", TCID);
	begin
		-- Initialize
		Input <= INIT;
		
		WaitForClock(Clock1, 4);

		-- Send "01" vector
		Input <= "01";
		WaitForClock(Clock1, 1);

		-- Keep vector stable
		WaitForClock(Clock1, 1);

		-- Continue with same vector
		WaitForClock(Clock1, 1);

		WaitForClock(Clock1, 2);

		-- Another cycle
		WaitForClock(Clock1, 1);

		-- Return to "00"
		Input <= "00";
		WaitForClock(Clock1, 6);

		-- Send "10" vector
		Input <= "10";
		WaitForClock(Clock1, 16);

		-- Return to "00"
		Input <= "00";
		WaitForClock(Clock1, 1);

		-- Final "01" vector
		Input <= "01";
		WaitForClock(Clock1, 1);

		-- Return to "00"
		Input <= "00";
		WaitForClock(Clock1, 6);

		wait;
	end process;

	CheckerProc : process
		constant ProcID     : AlertLogIDType := NewID("CheckerProc", TCID);
		variable ChangedCnt : natural := 0;
	begin
		WaitForClock(Clock2, 2);

		-- Count Changed events for a maximum of 100 clock cycles
		for i in 1 to 100 loop
			WaitForClock(Clock2);
			if Changed = '1' then
				ChangedCnt := ChangedCnt + 1;
			end if;
		end loop;

		-- Should see at least 2 Changed events based on stimuli
		AffirmIf(ProcID, ChangedCnt >= 2, 
			"Expected at least 2 Changed events, got " & integer'image(ChangedCnt));

		WaitForBarrier(TestDone);
		wait;
	end process;

end architecture;


configuration sync_Vector_Simple of sync_Vector_TestHarness is
	for TestHarness
		for TestCtrl : sync_Vector_TestController
			use entity work.sync_Vector_TestController(Simple);
		end for;
	end for;
end configuration;
