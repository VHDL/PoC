-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_firstone_Simple
--
-- Description:
-- -------------------------------------
-- Simple OSVVM test for arith_firstone
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

architecture Simple of arith_firstone_TestController is
  constant TCID : AlertLogIDType := NewID("FirstOneTest");
  signal TestDone : integer_barrier := 1;
begin

  ControlProc: process
    constant ProcID : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 10 ms;
  begin
    SetTestName("arith_firstone_Simple");

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
  begin
    tin  <= '0';
    rqst <= (others => '0');
    wait until Reset = '0';

    -- Exhaustive Testing for all possible request patterns
    for i in natural range 0 to 2**N-1 loop
      rqst <= std_logic_vector(to_unsigned(i, N));

      -- Test with tin = '0': no token input, should have no grants
      tin <= '0';
      WaitForClock(Clock);
      AffirmIf(ProcID, 
               grnt = (grnt'range => '0') and tout = '0',
               "Unexpected token output with tin='0' in testcase #" & integer'image(i));

      -- Test with tin = '1': token input, check grant pattern
      tin <= '1';
      wait until falling_edge(Clock);
      
      -- Check each bit of grant output
      for j in 0 to N-1 loop
        -- Grant(j) should be '1' if and only if:
        -- - rqst(j) = '1' (bit j is requesting)
        -- - AND all lower bits rqst(j-1 downto 0) are '0' (no lower priority request)
        if j = 0 then
          -- For bit 0, only check if rqst(0) is '1'
          AffirmIf(ProcID,
                   (grnt(j) = '1') = (rqst(j) = '1'),
                   "Wrong grant for bit " & integer'image(j) & 
                   " in testcase #" & integer'image(i) &
                   " (rqst=" & to_hxstring(rqst) & 
                   ", grnt=" & to_hxstring(grnt) & ")");
        else
          -- For higher bits, check if this is the first '1' from the right
          AffirmIf(ProcID,
                   (grnt(j) = '1') = ((rqst(j) = '1') and (rqst(j-1 downto 0) = (j-1 downto 0 => '0'))),
                   "Wrong grant for bit " & integer'image(j) & 
                   " in testcase #" & integer'image(i) &
                   " (rqst=" & to_hxstring(rqst) & 
                   ", grnt=" & to_hxstring(grnt) & ")");
        end if;
      end loop;

      -- Verify that tout is '1' only if rqst is all zeros
      AffirmIf(ProcID,
               (tout = '1') = (rqst = (N-1 downto 0 => '0')),
               "Wrong tout in testcase #" & integer'image(i) &
               " (rqst=" & to_hxstring(rqst) & 
               ", tout=" & std_logic'image(tout) & ")");

      -- Verify binary output bin points to the granted bit
      if rqst /= (N-1 downto 0 => '0') then
        for k in 0 to N-1 loop
          if grnt(k) = '1' then
            AffirmIf(ProcID,
                     to_integer(unsigned(bin)) = k,
                     "Wrong bin output in testcase #" & integer'image(i) &
                     " (expected=" & integer'image(k) &
                     ", got=" & integer'image(to_integer(unsigned(bin))) & ")");
          end if;
        end loop;
      end if;
      
    end loop;

    Log(ProcID, "Exhaustively tested all " & integer'image(2**N) & " request patterns", INFO);

    -- Finalize
    WaitForBarrier(TestDone);
    wait;
  end process;
end architecture;

configuration arith_firstone_Simple of arith_firstone_TestHarness is
  for TestHarness
    for TestCtrl: arith_firstone_TestController
      use entity work.arith_firstone_TestController(Simple);
    end for;
  end for;
end configuration;
