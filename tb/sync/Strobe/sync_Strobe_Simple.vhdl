-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:          Patrick Lehmann
--                   Gustavo Martin
--
-- Entity:           sync_Strobe_TestController (Simple architecture)
--
-- Description:
-- -------------------------------------
-- OSVVM simple test for strobe signal synchronizer.
-- Tests that strobe signals propagate correctly across clock domains.
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


architecture Simple of sync_Strobe_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType := NewID("TestCtrl");
	
	constant INIT : std_logic_vector(Output'range) := (others => '0');

begin
	ControlProc : process
		constant ProcID  : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("sync_Strobe_Simple");

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

		-- First strobe pulse
		Input <= "1";
		WaitForClock(Clock1, 1);

		-- Return to idle
		Input <= "0";
		WaitForClock(Clock1, 1);

		-- Second strobe pulse
		Input <= "1";
		WaitForClock(Clock1, 1);

		-- Return to idle
		Input <= "0";
		WaitForClock(Clock1, 2);

		-- Third strobe pulse
		Input <= "1";
		WaitForClock(Clock1, 1);

		Input <= "0";
		WaitForClock(Clock1, 6);

		-- Long strobe (may be gated by busy)
		Input <= "1";
		WaitForClock(Clock1, 16);

		-- Return to idle
		Input <= "0";
		WaitForClock(Clock1, 1);

		-- Final strobe pulse
		Input <= "1";
		WaitForClock(Clock1, 1);

		Input <= "0";
		WaitForClock(Clock1, 6);

		wait;
	end process;

	CheckerProc : process
		constant ProcID    : AlertLogIDType := NewID("CheckerProc", TCID);
		variable StrobeCnt : natural := 0;
	begin
		WaitForClock(Clock2, 2);

		-- Count Output strobe pulses for a maximum of 100 clock cycles
		for i in 1 to 100 loop
			WaitForClock(Clock2);
			if Output(0) = '1' then
				StrobeCnt := StrobeCnt + 1;
			end if;
		end loop;

		-- Should see at least 1 output strobe based on stimuli
		AffirmIf(ProcID, StrobeCnt >= 1, 
			"Expected at least 1 output strobe, got " & integer'image(StrobeCnt));

		WaitForBarrier(TestDone);
		wait;
	end process;

end architecture;


configuration sync_Strobe_Simple of sync_Strobe_TestHarness is
	for TestHarness
		for TestCtrl : sync_Strobe_TestController
			use entity work.sync_Strobe_TestController(Simple);
		end for;
	end for;
end configuration;
