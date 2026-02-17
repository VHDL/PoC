-- =============================================================================
-- Authors:					Thomas B. Preusser
--									Patrick Lehmann
--                  Gustavo Martin
--
-- Entity:					arith_prefix_and_TestController
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
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

architecture Simple of arith_prefix_and_TestController is
  signal TestDone : integer_barrier := 1;

  constant TCID : AlertLogIDType :=  NewID("TestCtrl");

begin
  ControlProc: process
    constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 10 ms;
  begin
    SetTestName("arith_prefix_and_Simple");

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
    
    -- Helper function to compute expected prefix AND
    function compute_prefix_and(x : std_logic_vector) return std_logic_vector is
      variable result : std_logic_vector(x'range);
      variable all_ones : boolean;
    begin
      for i in x'range loop
        all_ones := true;
        for j in x'low to i loop
          if x(j) /= '1' then
            all_ones := false;
            exit;
          end if;
        end loop;
        if all_ones then
          result(i) := '1';
        else
          result(i) := '0';
        end if;
      end loop;
      return result;
    end function;
    
    variable expected : std_logic_vector(y'range);
    variable test_input : std_logic_vector(y'range);

  begin
    wait until Reset = '0';
    WaitForClock(Clock);
    
    x(x'range) <= (others => '0');
    WaitForClock(Clock);

    -- Test Case 1: All zeros
    test_input := (others => '0');
    x <= test_input;
    WaitForClock(Clock);
    expected := compute_prefix_and(test_input);
    AffirmIf(ProcID,
      y = expected,
      "Test all zeros: y = 0x" & to_hstring(y),
      " Expected = 0x" & to_hstring(expected)
    );

    -- Test Case 2: All ones
    test_input := (others => '1');
    x <= test_input;
    WaitForClock(Clock);
    expected := compute_prefix_and(test_input);
    AffirmIf(ProcID,
      y = expected,
      "Test all ones: y = 0x" & to_hstring(y),
      " Expected = 0x" & to_hstring(expected)
    );

    -- Test Case 3: Alternating pattern 0101...
    for i in test_input'range loop
      if (i mod 2) = 0 then
        test_input(i) := '1';
      else
        test_input(i) := '0';
      end if;
    end loop;
    x <= test_input;
    WaitForClock(Clock);
    expected := compute_prefix_and(test_input);
    AffirmIf(ProcID,
      y = expected,
      "Test alternating 0101: y = 0x" & to_hstring(y),
      " Expected = 0x" & to_hstring(expected)
    );

    -- Test Case 4: Consecutive ones from LSB
    for len in 0 to test_input'length loop
      test_input := (others => '0');
      for i in 0 to len-1 loop
        test_input(i) := '1';
      end loop;
      x <= test_input;
      WaitForClock(Clock);
      expected := compute_prefix_and(test_input);
      AffirmIf(ProcID,
        y = expected,
        "Test " & to_string(len) & " ones from LSB: y = 0x" & to_hstring(y),
        " Expected = 0x" & to_hstring(expected)
      );
    end loop;

    -- Test Case 5: Single bit set at each position
    for pos in test_input'range loop
      test_input := (others => '0');
      test_input(pos) := '1';
      x <= test_input;
      WaitForClock(Clock);
      expected := compute_prefix_and(test_input);
      AffirmIf(ProcID,
        y = expected,
        "Test bit " & to_string(pos) & " set: y = 0x" & to_hstring(y),
        " Expected = 0x" & to_hstring(expected)
      );
    end loop;

    -- Test Case 6: Random patterns (if using 8-bit width)
    if y'length = 8 then
      -- Test some specific 8-bit patterns
      test_input := "10101010";
      x <= test_input;
      WaitForClock(Clock);
      expected := compute_prefix_and(test_input);
      AffirmIf(ProcID,
        y = expected,
        "Test pattern 10101010: y = 0x" & to_hstring(y),
        " Expected = 0x" & to_hstring(expected)
      );

      test_input := "11110000";
      x <= test_input;
      WaitForClock(Clock);
      expected := compute_prefix_and(test_input);
      AffirmIf(ProcID,
        y = expected,
        "Test pattern 11110000: y = 0x" & to_hstring(y),
        " Expected = 0x" & to_hstring(expected)
      );

      test_input := "00001111";
      x <= test_input;
      WaitForClock(Clock);
      expected := compute_prefix_and(test_input);
      AffirmIf(ProcID,
        y = expected,
        "Test pattern 00001111: y = 0x" & to_hstring(y),
        " Expected = 0x" & to_hstring(expected)
      );

      test_input := "11111110";
      x <= test_input;
      WaitForClock(Clock);
      expected := compute_prefix_and(test_input);
      AffirmIf(ProcID,
        y = expected,
        "Test pattern 11111110: y = 0x" & to_hstring(y),
        " Expected = 0x" & to_hstring(expected)
      );
    end if;

    x(x'range) <= (others => '0');
    WaitForClock(Clock);

    WaitForBarrier(TestDone);
    wait;
  end process;
end architecture;

configuration arith_prefix_and_Simple of arith_prefix_and_TestHarness is
  for TestHarness
    for TestCtrl: arith_prefix_and_TestController
      use entity work.arith_prefix_and_TestController(Simple);
    end for;
  end for;
end configuration;
