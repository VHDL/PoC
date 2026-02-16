-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:          Patrick Lehmann
--                   Gustavo Martin
--
-- Entity:           sync_Bits_TestController (Simple architecture)
--
-- Description:
-- -------------------------------------
-- OSVVM simple test for flag signal synchronizer.
-- Tests that signals propagate correctly across clock domains.
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


architecture Simple of sync_Bits_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType := NewID("TestCtrl");
	
	constant INIT : std_logic_vector(Sync_out'range) := (others => '0');

begin
	ControlProc : process
		constant ProcID  : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("sync_Bits_Simple");

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

	StimuliProc : process
		constant ProcID : AlertLogIDType := NewID("StimuliProc", TCID);
	begin
		-- Initialize
		Sync_in <= INIT;
		
		wait until Reset = '0';
		WaitForClock(Clock1, 4);

		-- Toggle input several times with different patterns
		Sync_in <= "1";
		WaitForClock(Clock1, 2);
		
		Sync_in <= "0";
		WaitForClock(Clock1, 2);
		
		Sync_in <= "1";
		WaitForClock(Clock1, 2);
		
		Sync_in <= "0";
		WaitForClock(Clock1, 6);
		
		Sync_in <= "1";
		WaitForClock(Clock1, 16);
		
		Sync_in <= "0";
		WaitForClock(Clock1, 2);
		
		Sync_in <= "1";
		WaitForClock(Clock1, 2);
		
		Sync_in <= "0";
		WaitForClock(Clock1, 6);

		wait;
	end process;

	CheckerProc : process
		constant ProcID       : AlertLogIDType := NewID("CheckerProc", TCID);
		variable toggled      : natural := 0;
		variable Sync_out_old : std_logic_vector(Sync_out'range);
	begin
		wait until Reset = '0';
		WaitForClock(Clock2);
		
		-- Check initial value
		AffirmIf(ProcID, Sync_out = INIT, "Initial value should be " & to_string(INIT));
		Sync_out_old := Sync_out;

		-- Count toggle events for a maximum of 50 clock cycles
		for i in 1 to 50 loop
			WaitForClock(Clock2);
			if Sync_out /= Sync_out_old then
				toggled := toggled + 1;
				Sync_out_old := Sync_out;
			end if;
		end loop;

		-- Should see 8 toggle events based on stimuli
		AffirmIf(ProcID, toggled = 8, 
			"Expected 8 toggle events, got " & integer'image(toggled));

		WaitForBarrier(TestDone);
		wait;
	end process;

end architecture;


configuration sync_Bits_Simple of sync_Bits_TestHarness is
	for TestHarness
		for TestCtrl : sync_Bits_TestController
			use entity work.sync_Bits_TestController(Simple);
		end for;
	end for;
end configuration;
