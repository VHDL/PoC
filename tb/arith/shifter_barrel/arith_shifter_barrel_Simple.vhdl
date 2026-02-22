-- =============================================================================
-- Authors:					Gustavo Martin
--
-- Entity:					arith_shifter_barrel_TestController
--
-- Description:
-- -------------------------------------
-- Simple test for arith_shifter_barrel component
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

architecture Simple of arith_shifter_barrel_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
	ControlProc: process
		constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("arith_shifter_barrel_Simple");

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
		variable expected : std_logic_vector(Output'range);
	begin
		wait until Reset = '0';
		WaitForClock(Clock);

		-- Test Shift Left Logical (SLL)
		ShiftRotate     <= '0';  -- Shift mode
		LeftRight       <= '0';  -- Left
		ArithmeticLogic <= '0';  -- Logic (doesn't matter for left shift)
		
		Input       <= "10110011";
		ShiftAmount <= "001";  -- Shift by 1
		wait for 1 ns;
		expected := "01100110";
		AffirmIf(ProcID, Output = expected, "SLL: 10110011 << 1 = 01100110");

		Input       <= "10110011";
		ShiftAmount <= "010";  -- Shift by 2
		wait for 1 ns;
		expected := "11001100";
		AffirmIf(ProcID, Output = expected, "SLL: 10110011 << 2 = 11001100");

		-- Test Shift Right Logical (SRL)
		ShiftRotate     <= '0';  -- Shift mode
		LeftRight       <= '1';  -- Right
		ArithmeticLogic <= '1';  -- Logic
		
		Input       <= "10110011";
		ShiftAmount <= "001";  -- Shift by 1
		wait for 1 ns;
		expected := "01011001";
		AffirmIf(ProcID, Output = expected, "SRL: 10110011 >> 1 = 01011001");

		Input       <= "10110011";
		ShiftAmount <= "010";  -- Shift by 2
		wait for 1 ns;
		expected := "00101100";
		AffirmIf(ProcID, Output = expected, "SRL: 10110011 >> 2 = 00101100");

		-- Test Shift Right Arithmetic (SRA) - sign extension
		ShiftRotate     <= '0';  -- Shift mode
		LeftRight       <= '1';  -- Right
		ArithmeticLogic <= '0';  -- Arithmetic
		
		Input       <= "10110011";  -- Negative number
		ShiftAmount <= "001";  -- Shift by 1
		wait for 1 ns;
		expected := "11011001";  -- Sign bit extended
		AffirmIf(ProcID, Output = expected, "SRA: 10110011 >> 1 = 11011001 (sign extended)");

		Input       <= "01110011";  -- Positive number
		ShiftAmount <= "001";  -- Shift by 1
		wait for 1 ns;
		expected := "00111001";  -- Sign bit extended (0)
		AffirmIf(ProcID, Output = expected, "SRA: 01110011 >> 1 = 00111001");

		-- Test Rotate Left (RL)
		ShiftRotate     <= '1';  -- Rotate mode
		LeftRight       <= '0';  -- Left
		
		Input       <= "10110011";
		ShiftAmount <= "001";  -- Rotate by 1
		wait for 1 ns;
		expected := "01100111";
		AffirmIf(ProcID, Output = expected, "RL: 10110011 rotL 1 = 01100111");

		Input       <= "10110011";
		ShiftAmount <= "011";  -- Rotate by 3
		wait for 1 ns;
		expected := "10011101";
		AffirmIf(ProcID, Output = expected, "RL: 10110011 rotL 3 = 10011101");

		-- Test Rotate Right (RR)
		ShiftRotate     <= '1';  -- Rotate mode
		LeftRight       <= '1';  -- Right
		
		Input       <= "10110011";
		ShiftAmount <= "001";  -- Rotate by 1
		wait for 1 ns;
		expected := "11011001";
		AffirmIf(ProcID, Output = expected, "RR: 10110011 rotR 1 = 11011001");

		Input       <= "10110011";
		ShiftAmount <= "010";  -- Rotate by 2
		wait for 1 ns;
		expected := "11101100";
		AffirmIf(ProcID, Output = expected, "RR: 10110011 rotR 2 = 11101100");

		WaitForClock(Clock);
		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;

configuration arith_shifter_barrel_Simple of arith_shifter_barrel_TestHarness is
	for TestHarness
		for TestCtrl: arith_shifter_barrel_TestController
			use entity work.arith_shifter_barrel_TestController(Simple);
		end for;
	end for;
end configuration;
