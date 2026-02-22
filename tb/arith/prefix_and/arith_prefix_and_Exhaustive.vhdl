-- =============================================================================
-- Authors:					Thomas B. Preusser
--									Patrick Lehmann
--                  Gustavo Martin
--
-- Entity:					arith_prefix_and_TestController
--
-- Description:
-- -------------------------------------
-- Exhaustive test for arith_prefix_and using OSVVM.
-- Tests all possible input patterns (2**N combinations).
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
use     PoC.vectors.all;
use     PoC.strings.all;

architecture Exhaustive of arith_prefix_and_TestController is
  signal TestDone : integer_barrier := 1;

  constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
  ControlProc: process
    constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 100 ms;
  begin
    SetTestName("arith_prefix_and_Exhaustive");

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
    variable test_pattern : unsigned(x'range);
    variable test_pattern_slv : std_logic_vector(x'range);

  begin
    wait until Reset = '0';
    WaitForClock(Clock);
    
    x(x'range) <= (others => '0');
    WaitForClock(Clock);

    -- Exhaustive Testing: test all possible input patterns
    for i in 0 to (2**x'length) - 1 loop
      test_pattern := to_unsigned(i, x'length);
      test_pattern_slv := std_logic_vector(test_pattern);
      x <= test_pattern_slv;
      WaitForClock(Clock);
      
      -- Check each bit position j
      for j in 0 to x'length - 1 loop
        -- y(j) should be '1' if and only if x(j downto 0) are all '1'
        -- This is equivalent to: x(j downto 0) = (j downto 0 => '1')
        AffirmIf(ProcID,
          (y(j) = '1') = (test_pattern_slv(j downto 0) = (j downto 0 => '1')),
          "Pattern " & to_string(i) & " / bit " & to_string(j) & 
          ": x = 0x" & to_hstring(test_pattern_slv) &
          ", y = 0x" & to_hstring(y) &
          ", y(" & to_string(j) & ") = " & to_string(y(j))
        );
      end loop;
    end loop;

    x(x'range) <= (others => '0');
    WaitForClock(Clock);

    WaitForBarrier(TestDone);
    wait;
  end process;
end architecture;

configuration arith_prefix_and_Exhaustive of arith_prefix_and_TestHarness is
  for TestHarness
    for TestCtrl: arith_prefix_and_TestController
      use entity work.arith_prefix_and_TestController(Exhaustive);
    end for;
  end for;
end configuration;
