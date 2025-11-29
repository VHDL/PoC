-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_scaler_Simple
--
-- Description:
-- -------------------------------------
-- Simple OSVVM test for arith_scaler
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
use     PoC.utils.all;

architecture Simple of arith_scaler_TestController is
  constant TCID : AlertLogIDType := NewID("ScalerTest");
  signal TestDone : integer_barrier := 1;
  
  -- Test argument values
  constant ARGS : T_NATVEC := (0, 1, 2, 3, 4, 31, 32, 33, 63, 64, 65, 95, 96, 97, 127, 128, 129, 196, 254, 255);
begin

  ControlProc: process
    constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 100 ms;
  begin
    SetTestName("arith_scaler_Simple");

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
    variable expected : natural;
    variable test_count : natural := 0;
  begin
    start <= '0';
    arg   <= (others => '0');
    msel  <= (others => '0');
    dsel  <= (others => '0');
    wait until Reset = '0';

    WaitForClock(Clock, 5);
    
    -- Exhaustive testing: all combinations of multipliers, divisors, and arguments
    for i in MULS'range loop
      for j in DIVS'range loop
        for k in ARGS'range loop
          WaitForClock(Clock);
          -- Set up inputs
          arg  <= std_logic_vector(to_unsigned(ARGS(k), arg'length));
          msel <= std_logic_vector(to_unsigned(i, msel'length));
          dsel <= std_logic_vector(to_unsigned(j, dsel'length));
          start <= '1';
          WaitForClock(Clock);
          
          -- Release start and set inputs to don't-care
          arg   <= (others => '-');
          msel  <= (others => '-');
          dsel  <= (others => '-');
          start <= '0';
          WaitForClock(Clock);
          
          -- Wait for completion
          wait until rising_edge(Clock) and done = '1';
          
          
          -- Calculate expected result: (arg * mul + div/2) / div, modulo 2^width
          expected := ((ARGS(k) * MULS(i) + DIVS(j)/2) / DIVS(j)) mod 2**res'length;
          
          AffirmIf(ProcID,
                   res = std_logic_vector(to_unsigned(expected, res'length)),
                   "Computation error: " & 
                   integer'image(ARGS(k)) & "*" & integer'image(MULS(i)) & "/" & integer'image(DIVS(j)) &
                   " -> expected " & integer'image(expected) & 
                   ", got " & integer'image(to_integer(unsigned(res))));
          
          test_count := test_count + 1;
        end loop;
      end loop;
    end loop;

    Log(ProcID, "Completed " & integer'image(test_count) & " scaler computations", INFO);

    -- Finalize
    WaitForBarrier(TestDone);
    wait;
  end process;
end architecture;

configuration arith_scaler_Simple of arith_scaler_TestHarness is
  for TestHarness
    for TestCtrl: arith_scaler_TestController
      use entity work.arith_scaler_TestController(Simple);
    end for;
  end for;
end configuration;
