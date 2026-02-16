-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Gustavo Martin
--
-- Entity:					arith_sqrt_TestController
--
-- Description:
-- -------------------------------------
-- Simple test for arith_sqrt component (Iterative Square Root)
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

architecture Simple of arith_sqrt_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
	ControlProc: process
		constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("arith_sqrt_Simple");

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
		
		type test_vector is record
			input    : natural;
			expected : natural;
		end record;
		
		type test_array is array (natural range <>) of test_vector;
		constant test_cases : test_array := (
			(0, 0),     -- sqrt(0) = 0
			(1, 1),     -- sqrt(1) = 1
			(4, 2),     -- sqrt(4) = 2
			(9, 3),     -- sqrt(9) = 3
			(16, 4),    -- sqrt(16) = 4
			(25, 5),    -- sqrt(25) = 5
			(36, 6),    -- sqrt(36) = 6
			(49, 7),    -- sqrt(49) = 7
			(64, 8),    -- sqrt(64) = 8
			(81, 9),    -- sqrt(81) = 9
			(100, 10),  -- sqrt(100) = 10
			(121, 11),  -- sqrt(121) = 11
			(144, 12),  -- sqrt(144) = 12
			(169, 13),  -- sqrt(169) = 13
			(196, 14),  -- sqrt(196) = 14
			(225, 15),  -- sqrt(225) = 15
			(255, 15)   -- sqrt(255) = 15
		);
		
	begin
		wait until Reset = '0';
		WaitForClock(Clock);

		for i in test_cases'range loop
			-- Set input and start computation
			arg <= std_logic_vector(to_unsigned(test_cases(i).input, arg'length));
			start <= '1';
			WaitForClock(Clock);
			start <= '0';
			
			-- Wait for computation to start (rdy goes low)
			wait until rdy = '0';
			-- Wait for computation to complete (rdy goes high)
			wait until rdy = '1';
			WaitForClock(Clock);
			
			-- Check result
			AffirmIf(ProcID, 
				unsigned(sqrt) = test_cases(i).expected, 
				"sqrt(" & integer'image(test_cases(i).input) & ") = " & 
				integer'image(test_cases(i).expected) & 
				", got " & integer'image(to_integer(unsigned(sqrt)))
			);
			
			WaitForClock(Clock);
		end loop;

		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;

configuration arith_sqrt_Simple of arith_sqrt_TestHarness is
	for TestHarness
		for TestCtrl: arith_sqrt_TestController
			use entity work.arith_sqrt_TestController(Simple);
		end for;
	end for;
end configuration;
