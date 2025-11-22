-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_addw_Simple
--
-- Description:
-- -------------------------------------
-- Simple OSVVM test for arith_addw
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
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;

library PoC;
use PoC.strings.all;
use PoC.physical.all;
use PoC.arith.all;

use work.arith_addw_TestController_pkg.all;

architecture Simple of arith_addw_TestController is
  signal TestDone : integer_barrier := 1;
  constant TCID : AlertLogIDType := NewID("AddWTest");
  constant TPERIOD_CLOCK : time := 10 ns;
  
begin

  ControlProc: process
    constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 10 ms;
  begin
    SetTestName("arith_addw_Simple");

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
    variable ai, bi : integer;
    variable expected : natural;
    variable actual_sum : unsigned(9 downto 0);
  begin
    wait until Reset = '0';
    WaitForClock(Clock);

    for i in 0 to 2**9-1 loop
      a <= std_logic_vector(to_unsigned(i, 9));
      for j in 0 to 2**9-1 loop
        b <= std_logic_vector(to_unsigned(j, 9));
        cin <= '0';
        WaitForClock(Clock);
        for arch in tArch loop
          for skip in tSkipping loop
            -- Test with P_INCLUSIVE = false
            expected := (i + j) mod 2**10;
            actual_sum := unsigned(cout(arch, skip, false) & s(arch, skip, false));
            AffirmIf(ProcID, expected = to_integer(actual_sum),
              "Output Error: " & integer'image(i) & "+" & integer'image(j) & 
              " arch=" & tArch'image(arch) & " skip=" & tSkipping'image(skip) & " incl=false"
            );
            
            -- Test with P_INCLUSIVE = true
            actual_sum := unsigned(cout(arch, skip, true) & s(arch, skip, true));
            AffirmIf(ProcID, expected = to_integer(actual_sum),
              "Output Error: " & integer'image(i) & "+" & integer'image(j) & 
              " arch=" & tArch'image(arch) & " skip=" & tSkipping'image(skip) & " incl=true"
            );
          end loop;
        end loop;

        cin <= '1';
        WaitForClock(Clock);
        for arch in tArch loop
          for skip in tSkipping loop
            -- Test with P_INCLUSIVE = false
            expected := (i + j + 1) mod 2**10;
            actual_sum := unsigned(cout(arch, skip, false) & s(arch, skip, false));
            AffirmIf(ProcID, expected = to_integer(actual_sum),
              "Output Error with carry: " & integer'image(i) & "+" & integer'image(j) & "+1" &
              " arch=" & tArch'image(arch) & " skip=" & tSkipping'image(skip) & " incl=false"
            );
            
            -- Test with P_INCLUSIVE = true
            actual_sum := unsigned(cout(arch, skip, true) & s(arch, skip, true));
            AffirmIf(ProcID, expected = to_integer(actual_sum),
              "Output Error with carry: " & integer'image(i) & "+" & integer'image(j) & "+1" &
              " arch=" & tArch'image(arch) & " skip=" & tSkipping'image(skip) & " incl=true"
            );
          end loop;
        end loop;

      end loop;
    end loop;

    WaitForBarrier(TestDone);
    wait;
  end process;
end architecture;

configuration arith_addw_Simple of arith_addw_TestHarness is
  for TestHarness
    for TestCtrl: arith_addw_TestController
      use entity work.arith_addw_TestController(Simple);
    end for;
  end for;
end configuration;
