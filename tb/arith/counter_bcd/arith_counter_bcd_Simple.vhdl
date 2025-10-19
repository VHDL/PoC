-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					G. Martin
--
-- Entity:					arith_counter_bcd_Simple
--
-- Description:
-- -------------------------------------
-- Simple OSVVM test for arith_counter_bcd
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
use     PoC.strings.all;
use     PoC.physical.all;
-- simulation only packages
--use     PoC.sim_types.all;
--use     PoC.simulation.all;
--use			PoC.waveform.all;

architecture Simple of arith_counter_bcd_TestController is
  constant TCID : AlertLogIDType := NewID("CntBCDTest");
  signal TestDone : integer_barrier := 1;
  
  signal Expected : T_BCD_VECTOR(DIGITS - 1 downto 0);
begin

  -- Stimulus generation
  StimulusProc: process
  begin
    Reset_aux		<= '0';
    wait until Reset = '0';
    Reset_aux <= '0';
    inc			  <= '0';

    wait until falling_edge(Clock);
    Reset_aux <= '1';
    inc       <= '0';

    wait until falling_edge(Clock);
    Reset_aux <= '1';
    inc       <= '1';

    wait until falling_edge(Clock);
    Reset_aux <= '0';
    inc       <= '0';
    
    for i in 0 to 10**DIGITS - 1 loop
      wait until falling_edge(Clock);
      inc <= '1';
      
      wait until falling_edge(Clock);
      inc <= '0';
    end loop;
    
    wait until falling_edge(Clock);
    inc <= '1';
    
    -- Wait 4 more falling edges
    for j in 1 to 4 loop
      wait until falling_edge(Clock);
    end loop;
    Reset_aux <= '1';
    inc       <= '0';

    wait until falling_edge(Clock);
    Reset_aux <= '0';
    inc       <= '0';
    
    -- Finalize
    WaitForBarrier(TestDone);
  end process;

  ControlProc: process
    constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 10 ms;
  begin
    SetTestName("arith_counter_bcd_Simple");

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
    variable Expected : T_BCD_VECTOR(DIGITS - 1 downto 0);
  begin
    WaitForClock(Clock);
    WaitForClock(Clock);
    Expected := to_BCD_Vector(0, DIGITS);
    AffirmIf(ProcID, (Value = Expected), "Wrong initial state. Value=" & to_string(Value));

    WaitForClock(Clock);
    AffirmIf(ProcID, (Value = Expected), "Wrong initial state. Value=" & to_string(Value));

    WaitForClock(Clock);
    for i in 1 to 10**DIGITS - 1 loop
      Expected := to_BCD_Vector(i, DIGITS);
      WaitForClock(Clock);
      AffirmIf(ProcID, (Value = Expected), "Must be incremented to state " & to_string(Expected) & "  Value=" & to_string(Value));
      WaitForClock(Clock);
      AffirmIf(ProcID, (Value = Expected), "Must keep the state " & to_string(Expected) & "  Value=" & to_string(Value));
    end loop;

    WaitForClock(Clock);
    AffirmIf(ProcID, Value = (DIGITS - 1 downto 0 => x"0"), "Should be wrapped to 0000.");

    for j in 1 to 5 loop
      WaitForClock(Clock);
    end loop;

    WaitForClock(Clock);
    AffirmIf(ProcID, Value = (DIGITS - 1 downto 0 => x"0"), "Should be resetted again.");

    -- Finalize
    WaitForBarrier(TestDone);
    wait;
  end process;
end architecture;

configuration arith_counter_bcd_Simple of arith_counter_bcd_TestHarness is
  for TestHarness
    for TestCtrl: arith_counter_bcd_TestController
      use entity work.arith_counter_bcd_TestController(Simple);
    end for;
  end for;
end configuration;