-- =============================================================================
-- Authors:					Gustavo Martin
--
-- Entity:					arith_cca_TestController
--
-- Description:
-- -------------------------------------
-- Simple test for arith_cca component (Carry-Compact Adder)
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

architecture Simple of arith_cca_TestController is
	signal TestDone : integer_barrier := 1;

	constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
	ControlProc: process
		constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		SetTestName("arith_cca_Simple");

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
		variable expected : unsigned(s'range);
		variable result_with_carry : unsigned(s'length downto 0);
	begin
		wait until Reset = '0';
		WaitForClock(Clock);

		-- Test basic addition without carry
		c <= '0';
		
		a <= x"00";
		b <= x"00";
		wait for 1 ns;
		expected := x"00";
		AffirmIf(ProcID, unsigned(s) = expected, "0x00 + 0x00 + 0 = 0x00");

		a <= x"01";
		b <= x"01";
		wait for 1 ns;
		expected := x"02";
		AffirmIf(ProcID, unsigned(s) = expected, "0x01 + 0x01 + 0 = 0x02");

		a <= x"0F";
		b <= x"0F";
		wait for 1 ns;
		expected := x"1E";
		AffirmIf(ProcID, unsigned(s) = expected, "0x0F + 0x0F + 0 = 0x1E");

		a <= x"FF";
		b <= x"01";
		wait for 1 ns;
		expected := x"00";
		AffirmIf(ProcID, unsigned(s) = expected, "0xFF + 0x01 + 0 = 0x00 (overflow)");

		a <= x"55";
		b <= x"AA";
		wait for 1 ns;
		expected := x"FF";
		AffirmIf(ProcID, unsigned(s) = expected, "0x55 + 0xAA + 0 = 0xFF");

		-- Test addition with carry = 1
		c <= '1';
		
		a <= x"00";
		b <= x"00";
		wait for 1 ns;
		expected := x"01";
		AffirmIf(ProcID, unsigned(s) = expected, "0x00 + 0x00 + 1 = 0x01");

		a <= x"FF";
		b <= x"00";
		wait for 1 ns;
		expected := x"00";
		AffirmIf(ProcID, unsigned(s) = expected, "0xFF + 0x00 + 1 = 0x00 (overflow)");

		a <= x"7F";
		b <= x"7F";
		wait for 1 ns;
		expected := x"FF";
		AffirmIf(ProcID, unsigned(s) = expected, "0x7F + 0x7F + 1 = 0xFF");

		a <= x"10";
		b <= x"20";
		wait for 1 ns;
		expected := x"31";
		AffirmIf(ProcID, unsigned(s) = expected, "0x10 + 0x20 + 1 = 0x31");

		WaitForClock(Clock);
		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;

configuration arith_cca_Simple of arith_cca_TestHarness is
	for TestHarness
		for TestCtrl: arith_cca_TestController
			use entity work.arith_cca_TestController(Simple);
		end for;
	end for;
end configuration;
