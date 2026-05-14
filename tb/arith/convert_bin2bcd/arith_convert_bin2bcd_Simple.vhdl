-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Gustavo Martin
--
-- Entity:					arith_convert_bin2bcd_Simple
--
-- Description:
-- -------------------------------------
-- Simple OSVVM test for arith_convert_bin2bcd
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.strings.all;
use     PoC.physical.all;

architecture Simple of arith_convert_bin2bcd_TestController is
  constant TCID : AlertLogIDType := NewID("ConvBin2BCDTest");
  signal TestDone : integer_barrier := 1;
  
  constant INPUT_1			: integer					:= 38442113;
	constant INPUT_2			: integer					:= 78734531;
	constant INPUT_3			: integer					:= 14902385;

  function Check_Conv2(INPUT : integer; BITS : positive; DIGITS : positive; BCDDigits : T_BCD_VECTOR; Sign : std_logic) return boolean is
		variable nat : natural;
	begin
		if INPUT >= 2**(BITS-1) then
			nat := (-INPUT) mod 2**(BITS-1);
			if Sign /= '1' then
				return false;
			end if;
		else
			nat := INPUT;
			if Sign /= '0' then
				return false;
			end if;
		end if;

		return to_BCD_Vector(nat, DIGITS) = BCDDigits;
	end function;

begin

  ControlProc: process
    constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 10 ms;
  begin
    SetTestName("arith_convert_bin2bcd_Simple");

    SetLogEnable(PASSED, TRUE);
    SetLogEnable(INFO,   TRUE);
    SetLogEnable(DEBUG,  FALSE);
    wait for 0 ns; wait for 0 ns;

    TranscriptOpen;
    SetTranscriptMirror(TRUE);

    wait until Reset = '0';
    ClearAlerts;

    WaitForBarrier(TestDone, TIMEOUT);
    AlertIf(ProcID, now >= TIMEOUT,     "Test finished due to timeout");
    -- AlertIf(ProcID, GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports(ReportAll => TRUE);
    std.env.stop;
  end process;

  TestProc: process
    constant ProcID : AlertLogIDType := NewID("TestProc", TCID);
  begin
    Start <= '0';
    Conv1_Binary <= (others => '0');
    Conv2_Binary <= (others => '0');

    wait until Reset = '0';
    WaitForClock(Clock, 4);

    -- Test Case 1
    Start						<= '1';
		Conv1_Binary		<= to_slv(INPUT_1, CONV1_BITS);
		Conv2_Binary		<= to_slv(INPUT_1, CONV2_BITS);
    WaitForClock(Clock);

    Start						<= '0';
    WaitForClock(Clock);

    for i in 0 to (CONV1_BITS - 1) loop
      WaitForClock(Clock);
    end loop;

    AffirmIf(ProcID, to_BCD_Vector(INPUT_1, CONV1_DIGITS) = Conv1_BCDDigits, "Conv1_BCDDigits is wrong for INPUT_1.");
    AffirmIf(ProcID, Check_Conv2(INPUT_1, CONV2_BITS, CONV2_DIGITS, Conv2_BCDDigits, Conv2_Sign), "Conv2_BCDDigits is wrong for INPUT_1.");

    -- Test Case 2
    Start						<= '1';
		Conv1_Binary		<= to_slv(INPUT_2, CONV1_BITS);
		Conv2_Binary		<= to_slv(INPUT_2, CONV2_BITS);
    WaitForClock(Clock);

    Start						<= '0';
    WaitForClock(Clock);

    for i in 0 to (CONV1_BITS - 1) loop
      WaitForClock(Clock);
    end loop;

    AffirmIf(ProcID, to_BCD_Vector(INPUT_2, CONV1_DIGITS) = Conv1_BCDDigits, "Conv1_BCDDigits is wrong for INPUT_2.");
    AffirmIf(ProcID, Check_Conv2(INPUT_2, CONV2_BITS, CONV2_DIGITS, Conv2_BCDDigits, Conv2_Sign), "Conv2_BCDDigits is wrong for INPUT_2.");

    -- Test Case 3
    Start						<= '1';
		Conv1_Binary		<= to_slv(INPUT_3, CONV1_BITS);
		Conv2_Binary		<= to_slv(INPUT_3, CONV2_BITS);
    WaitForClock(Clock);

    Start						<= '0';
    WaitForClock(Clock);

    for i in 0 to (CONV1_BITS - 1) loop
      WaitForClock(Clock);
    end loop;

    AffirmIf(ProcID, to_BCD_Vector(INPUT_3, CONV1_DIGITS) = Conv1_BCDDigits, "Conv1_BCDDigits is wrong for INPUT_3.");
    AffirmIf(ProcID, Check_Conv2(INPUT_3, CONV2_BITS, CONV2_DIGITS, Conv2_BCDDigits, Conv2_Sign), "Conv2_BCDDigits is wrong for INPUT_3.");

    WaitForBarrier(TestDone);
    wait;
  end process;

end architecture;

configuration arith_convert_bin2bcd_Simple of arith_convert_bin2bcd_TestHarness is
  for TestHarness
    for TestCtrl: arith_convert_bin2bcd_TestController
      use entity work.arith_convert_bin2bcd_TestController(Simple);
    end for;
  end for;
end configuration;
