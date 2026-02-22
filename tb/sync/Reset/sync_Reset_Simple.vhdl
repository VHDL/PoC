-- =============================================================================
-- Authors:          Patrick Lehmann
--                   Gustavo Martin
--
-- Entity:           sync_Reset_TestController (Simple architecture)
--
-- Description:
-- -------------------------------------
-- OSVVM simple test for reset signal synchronizer.
-- Tests that reset signals propagate correctly across clock domains.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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


architecture Simple of sync_Reset_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType := NewID("TestCtrl");

begin
	ControlProc : process
		constant ProcID  : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("sync_Reset_Simple");

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
		Input <= '0';
		
		WaitForClock(Clock1, 4);

		-- Short reset pulse
		Input <= '0';
		WaitForClock(Clock1, 1);

		Input <= '1';
		WaitForClock(Clock1, 1);

		Input <= '0';
		WaitForClock(Clock1, 2);

		-- Another short pulse
		Input <= '1';
		WaitForClock(Clock1, 1);

		Input <= '0';
		WaitForClock(Clock1, 6);

		-- Long reset pulse
		Input <= '1';
		WaitForClock(Clock1, 16);

		-- Reset low
		Input <= '0';
		WaitForClock(Clock1, 1);

		-- Final short pulse
		Input <= '1';
		WaitForClock(Clock1, 1);

		Input <= '0';
		WaitForClock(Clock1, 6);

		wait;
	end process;

	CheckerProc : process
		constant ProcID        : AlertLogIDType := NewID("CheckerProc", TCID);
		variable OutputHighCnt : natural := 0;
		variable Output_old    : std_logic := '0';
	begin
		WaitForClock(Clock2, 2);

		-- Count Output high transitions for a maximum of 100 clock cycles
		for i in 1 to 100 loop
			WaitForClock(Clock2);
			if Output = '1' and Output_old = '0' then
				OutputHighCnt := OutputHighCnt + 1;
			end if;
			Output_old := Output;
		end loop;

		-- Should see at least 1 Output high transition based on stimuli
		AffirmIf(ProcID, OutputHighCnt >= 1, 
			"Expected at least 1 Output high transition, got " & integer'image(OutputHighCnt));

		WaitForBarrier(TestDone);
		wait;
	end process;

end architecture;


configuration sync_Reset_Simple of sync_Reset_TestHarness is
	for TestHarness
		for TestCtrl : sync_Reset_TestController
			use entity work.sync_Reset_TestController(Simple);
		end for;
	end for;
end configuration;
