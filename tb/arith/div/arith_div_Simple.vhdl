-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_div_Simple
--
-- Description:
-- -------------------------------------
-- Simple test for arith_div
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

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.strings.all;

library osvvm;
context osvvm.OsvvmContext;

library tb_arith;
use     tb_arith.arith_div_TestController_pkg.all;

architecture Simple of arith_div_TestController is
  signal TestDone : integer_barrier := 1;
  constant TCID : AlertLogIDType := NewID("AddWTest");
  constant TPERIOD_CLOCK : time := 10 ns;
begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
    constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 10 ms;
  begin
    -- Initialization of AlertLog
    SetTestName("arith_div_Simple");
    SetLogEnable(PASSED, FALSE);
    SetLogEnable(INFO,   FALSE);
    SetLogEnable(DEBUG,  FALSE);

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

  ------------------------------------------------------------
  -- TestProc
  --   Generate stimuli and check results
  ------------------------------------------------------------
  TestProc : process
    variable Random : RandomPType;

    procedure test(aval, dval : in integer) is
      variable QQ : tA_vector(1 to 2*MAX_POW);
      variable RR : tD_vector(1 to 2*MAX_POW);
      variable ZZ : std_logic_vector(1 to 2*MAX_POW);

      type boolean_vector is array(positive range<>) of boolean;
      variable done : boolean_vector(1 to 2*MAX_POW);
      variable all_done : boolean;
    begin
      -- Start
      WaitForClock(Clock, 5);
      Start <= '1';
      A     <= std_logic_vector(to_unsigned(aval, A'length));
      D     <= std_logic_vector(to_unsigned(dval, D'length));
      WaitForClock(Clock);
      wait for 1 ns;
      Start <= '0';
      A     <= (others => '-');
      D     <= (others => '-');
      done  := (others => false);
      
      loop
        all_done := true;
        for i in done'range loop
          if Ready(i) = '1' and not done(i) then
            QQ(i)   := Q(i);
            RR(i)   := R(i);
            ZZ(i)   := Z(i);
            done(i) := true;
          end if;
          if not done(i) then
            all_done := false;
          end if;
        end loop;
        exit when all_done;
        WaitForClock(Clock);
        wait for 1 ns;
      end loop;

      for i in done'range loop
        if dval = 0 then
          AffirmIf(ZZ(i) = '1', "INST=" & integer'image(i) & " Div by zero check failed: " & integer'image(aval) & "/" & integer'image(dval));
        else
          AffirmIf(ZZ(i) = '0', "INST=" & integer'image(i) & " Zero flag check failed: " & integer'image(aval) & "/" & integer'image(dval));
          AffirmIf(to_integer(unsigned(QQ(i)))*dval + to_integer(unsigned(RR(i))) = aval,
                   "INST=" & integer'image(i) & " Result check failed: " & integer'image(aval) & "/" & integer'image(dval) & 
                   " /= " & integer'image(to_integer(unsigned(QQ(i)))) & " R " & integer'image(to_integer(unsigned(RR(i)))));
        end if;
      end loop;
    end procedure;

  begin
    Start <= '0';
    A     <= (others => '-');
    D     <= (others => '-');

    -- Initialize Random
    Random.InitSeed(Random'instance_name);

    -- Reset
    wait until Reset = '0';
    
    -- Boundary Conditions
    test(0, 0);
    test(0, 2**D_BITS-1);
    test(0, 1);
    test(1, 0);
    test(2, 0);
    test(2**A_BITS-1, 0);
    test(2**A_BITS-1, 2**D_BITS-1);

    -- Run Random Tests
    for i in 0 to 1023 loop
      test(Random.Uniform(0, 2**A_BITS-1), Random.Uniform(0, 2**D_BITS-1));
    end loop;

    -- End of Test
    WaitForBarrier(TestDone);
    wait;
  end process;

end architecture;

configuration arith_div_Simple of arith_div_TestHarness is
  for tb
    for TestCtrl: arith_div_TestController
      use entity work.arith_div_TestController(Simple);
    end for;
  end for;
end configuration;
