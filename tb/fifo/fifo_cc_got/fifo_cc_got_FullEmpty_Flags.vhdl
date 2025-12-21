-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Gustavo Martin
--
-- Architecture:    fifo_cc_got_FullEmpty_Flags
--
-- Description:
-- -------------------------------------
-- Full/Empty Flags OSVVM test for fifo_cc_got using Verification Components
-- Uses Transaction interface to test:
-- - Reaching Full state (full = '1') with single writes and bursts
-- - Reaching Empty state (valid = '0') with single reads and bursts
-- - Verifying flag transitions during fill/drain operations
--
-- Test Phases:
-- Phase 1: Fill to full using single Send() operations
-- Phase 2: Drain to empty using single Check() operations
-- Phase 3: Fill to full using SendBurst() operation
-- Phase 4: Drain to empty using CheckBurst() operation
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
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
use     osvvm.ScoreboardPkg_slv.all;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;
use     osvvm_common.FifoFillPkg_slv.all;

use     work.fifo_cc_got_TestController_pkg.all;

architecture FullEmpty_Flags of fifo_cc_got_TestController is
  -- Phase synchronization barriers
  signal TestDone    : integer_barrier := 1;
  signal Phase1Done  : integer_barrier := 1;  -- Phase 1: Single fill to full
  signal Phase2Done  : integer_barrier := 1;  -- Phase 2: Single drain to empty
  signal Phase3Done  : integer_barrier := 1;  -- Phase 3: Burst fill to full
  signal Phase4Done  : integer_barrier := 1;  -- Phase 4: Burst drain to empty

  -- Alert/Log IDs
  constant TCID : AlertLogIDType := NewID("FifoCcGotFullEmpty_" & ConfigToString(CONFIG_INDEX));

begin
  ----------------------------------------------------------------------------
  -- Control Process - manages test lifecycle
  ----------------------------------------------------------------------------
  ControlProc : process
    constant ProcID  : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 500 ms;
  begin
    SetTestName("fifo_cc_got_FullEmpty_Flags");

    SetLogEnable(PASSED, FALSE);
    SetLogEnable(INFO,   TRUE);
    SetLogEnable(DEBUG,  FALSE);
    wait for 0 ns; wait for 0 ns;

    TranscriptOpen;
    SetTranscriptMirror(TRUE);

    -- Initialize Burst FIFOs
    TxBurstFifo <= NewID("TxBurstFifo", TCID);
    RxBurstFifo <= NewID("RxBurstFifo", TCID);

    wait until nReset = '1';
    ClearAlerts;

    WaitForBarrier(TestDone, TIMEOUT);
    AlertIf(ProcID, now >= TIMEOUT, "Test finished due to timeout");
    AlertIf(ProcID, GetAffirmCount < 1, "Test is not Self-Checking");

    EndOfTestReports(ReportAll => TRUE);
    std.env.stop;
  end process;

  ----------------------------------------------------------------------------
  -- Writer Process - uses Transaction interface to send data
  ----------------------------------------------------------------------------
  WriterProc : process
    constant ProcID   : AlertLogIDType := NewID("WriterProc", TCID);
    variable WriteCount : integer := 0;
  begin
    wait until nReset = '1';
    WaitForClock(TxRec, 2);

    -- Assign BurstFifo to transaction record
    TxRec.BurstFifo <= TxBurstFifo;

    -- Verify initial state: FIFO should not be full
    AffirmIf(ProcID, full = '0', "Initial: FIFO should not be full");
    AffirmIf(ProcID, estate_wr = "1111", "Initial: estate_wr should be max (1111), got: " & to_string(estate_wr));
    AffirmIf(ProcID, fstate_rd = "0000", "Initial: fstate_rd should be min (0000), got: " & to_string(fstate_rd));
    Log(ProcID, "Initial: full = '" & std_logic'image(full) & "', estate_wr=" & to_string(estate_wr), INFO);

    ---------------------------------------------------------------------------
    -- Phase 1: Fill FIFO to full using single Send() operations
    ---------------------------------------------------------------------------
    Log(ProcID, "Phase 1: Fill to FULL using single Send()", INFO);
    
    -- Fill with sequential data using individual Send transactions
    loop
      Send(TxRec, std_logic_vector(to_unsigned(WriteCount, D_BITS)));
      WriteCount := WriteCount + 1;
      
      -- Wait for full signal to update
      WaitForClock(TxRec, 1);
      
      -- Check if FIFO is now full
      exit when full = '1';
    end loop;
    
    -- Verify FIFO reached full state
    AffirmIf(ProcID, full = '1', "Phase 1: FIFO should be FULL after single writes");
    -- Verify estate_wr indicates full state (should be at maximum)
    AffirmIf(ProcID, estate_wr = "0000", "Phase 3: estate_wr should be max (0000) when full, got: " & to_string(estate_wr));
    AffirmIf(ProcID, fstate_rd = "1111", "Phase 3: fstate_rd should be max (1111) when full, got: " & to_string(fstate_rd));
    Log(ProcID, "Phase 1: Reached FULL after " & integer'image(WriteCount) & " single writes, estate_wr=" & to_string(estate_wr), INFO);
    
    WaitForBarrier(Phase1Done);

    ---------------------------------------------------------------------------
    -- Phase 2: Wait for reader to drain to empty (no writes)
    ---------------------------------------------------------------------------
    Log(ProcID, "Phase 2: Waiting for reader to drain to empty", INFO);
    WaitForBarrier(Phase2Done);

    ---------------------------------------------------------------------------
    -- Phase 3: Fill FIFO to full using single Send() operations
    ---------------------------------------------------------------------------
    Log(ProcID, "Phase 3: Fill to FULL using single Send()", INFO);
    
    -- Calculate how many words to send to fill (assuming empty after Phase 2)
    WriteCount := 0;
    
    -- Fill with sequential data using individual Send transactions
    loop
      Send(TxRec, std_logic_vector(to_unsigned(WriteCount, D_BITS)));
      WriteCount := WriteCount + 1;
      
      -- Wait for full signal to update
      WaitForClock(TxRec, 1);
      
      -- Check if FIFO is now full
      exit when full = '1';
    end loop;
    
    -- Verify FIFO reached full state
    AffirmIf(ProcID, full = '1', "Phase 3: FIFO should be FULL after single writes");
    -- Verify estate_wr indicates full state (should be at maximum)
    AffirmIf(ProcID, estate_wr = "0000", "Phase 3: estate_wr should be max (0000) when full, got: " & to_string(estate_wr));
    AffirmIf(ProcID, fstate_rd = "1111", "Phase 3: fstate_rd should be max (1111) when full, got: " & to_string(fstate_rd));

    Log(ProcID, "Phase 3: Reached FULL after " & integer'image(WriteCount) & " single writes, estate_wr=" & to_string(estate_wr), INFO);
    
    WaitForBarrier(Phase3Done);

    ---------------------------------------------------------------------------
    -- Phase 4: Wait for reader to drain to empty (no writes)
    ---------------------------------------------------------------------------
    Log(ProcID, "Phase 4: Waiting for reader to drain to empty", INFO);
    WaitForBarrier(Phase4Done);

    Log(ProcID, "Writer complete", INFO);
    WaitForBarrier(TestDone);
    wait;
  end process;

  ----------------------------------------------------------------------------
  -- Reader Process - uses Transaction interface to verify data
  ----------------------------------------------------------------------------
  ReaderProc : process
    constant ProcID   : AlertLogIDType := NewID("ReaderProc", TCID);
    variable ReadCount  : integer := 0;
  begin
    wait until nReset = '1';
    WaitForClock(RxRec, 2);

    -- Assign BurstFifo to transaction record
    RxRec.BurstFifo <= RxBurstFifo;

    -- Verify initial state: FIFO should be empty (valid = '0')
    AffirmIf(ProcID, valid = '0', "Initial: FIFO should be EMPTY (valid = '0')");
    AffirmIf(ProcID, fstate_rd = "0000", "Initial: fstate_rd should be min (0000), got: " & to_string(fstate_rd));
    Log(ProcID, "Initial: valid = '" & std_logic'image(valid) & "', fstate_rd=" & to_string(fstate_rd), INFO);

    ---------------------------------------------------------------------------
    -- Phase 1: Wait for writer to fill, verify not empty
    ---------------------------------------------------------------------------
    Log(ProcID, "Phase 1: Wait for writer to fill FIFO to full", INFO);
    WaitForBarrier(Phase1Done);
    
    -- Verify FIFO is not empty now
    AffirmIf(ProcID, valid = '1', "Phase 1: FIFO should not be EMPTY after fill");
    Log(ProcID, "Phase 1: FIFO is not empty, valid = '" & std_logic'image(valid) & "'", INFO);

    ---------------------------------------------------------------------------
    -- Phase 2: Drain FIFO to empty using single Check() operations
    ---------------------------------------------------------------------------
    Log(ProcID, "Phase 2: Drain to EMPTY using single Check()", INFO);
    
    -- Drain using individual Check transactions until FIFO is empty
    ReadCount := 0;
    while valid = '1' loop
      Check(RxRec, std_logic_vector(to_unsigned(ReadCount, D_BITS)));
      ReadCount := ReadCount + 1;
      WaitForClock(RxRec, 1);
    end loop;
    
    -- Verify FIFO reached empty state
    AffirmIf(ProcID, valid = '0', "Phase 2: FIFO should be EMPTY (valid = '0') after single reads");
    -- Verify fstate_rd indicates empty state (should be at minimum)
    AffirmIf(ProcID, fstate_rd = "0000", "Phase 2: fstate_rd should be min (0000) when empty, got: " & to_string(fstate_rd));
    Log(ProcID, "Phase 2: Reached EMPTY after " & integer'image(ReadCount) & " single reads, fstate_rd=" & to_string(fstate_rd), INFO);
    
    WaitForBarrier(Phase2Done);

    ---------------------------------------------------------------------------
    -- Phase 3: Wait for writer to fill with bursts
    ---------------------------------------------------------------------------
    Log(ProcID, "Phase 3: Wait for writer to fill FIFO with bursts", INFO);
    WaitForBarrier(Phase3Done);
    
    -- Verify FIFO is not empty now
    AffirmIf(ProcID, valid = '1', "Phase 3: FIFO should not be EMPTY after burst fill");
    Log(ProcID, "Phase 3: FIFO is not empty, valid = '" & std_logic'image(valid) & "'", INFO);

    ---------------------------------------------------------------------------
    -- Phase 4: Drain FIFO to empty using single Check() operations
    ---------------------------------------------------------------------------
    Log(ProcID, "Phase 4: Drain to EMPTY using single Check()", INFO);
    
    ReadCount := 0;
    while valid = '1' loop
      Check(RxRec, std_logic_vector(to_unsigned(ReadCount, D_BITS)));
      ReadCount := ReadCount + 1;
      WaitForClock(RxRec, 1);
    end loop;
    
    -- Verify FIFO reached empty state
    AffirmIf(ProcID, valid = '0', "Phase 4: FIFO should be EMPTY (valid = '0') after single reads");
    -- Verify fstate_rd indicates empty state (should be at minimum)
    AffirmIf(ProcID, fstate_rd = "0000", "Phase 4: fstate_rd should be min (0000) when empty, got: " & to_string(fstate_rd));
    Log(ProcID, "Phase 4: Reached EMPTY after " & integer'image(ReadCount) & " single reads, fstate_rd=" & to_string(fstate_rd), INFO);
    
    WaitForBarrier(Phase4Done);

    Log(ProcID, "Reader complete", INFO);
    WaitForBarrier(TestDone);
    wait;
  end process;

end architecture;

-- Configuration for Full/Empty Flags test
configuration fifo_cc_got_FullEmpty_Flags of fifo_cc_got_TestHarness is
  for TestHarness
    for TestCtrl : fifo_cc_got_TestController
      use entity work.fifo_cc_got_TestController(FullEmpty_Flags);
    end for;
  end for;
end configuration;
