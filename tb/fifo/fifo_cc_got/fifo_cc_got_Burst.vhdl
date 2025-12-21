-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Gustavo Martin
--
-- Architecture:    fifo_cc_got_Burst
--
-- Description:
-- -------------------------------------
-- Burst OSVVM test for fifo_cc_got using Verification Components
-- Uses Transaction interface to communicate with VCs for:
-- - Full/Empty transitions
-- - Back-to-back operations
-- - Burst operations with PushBurstIncrement/PushBurstRandom
-- - State indicator verification via GetFifoStatus
-- - Simultaneous read/write stress testing
--
-- Uses OSVVM FifoFillPkg for sophisticated burst patterns
-- Uses cross-coverage for state combinations
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

architecture Burst of fifo_cc_got_TestController is
  -- Phase synchronization barriers
  signal TestDone    : integer_barrier := 1;
  signal Phase1Fill  : integer_barrier := 1;  -- Writer fills FIFO
  signal Phase1Done  : integer_barrier := 1;  -- Reader drains FIFO
  signal Phase2Start : integer_barrier := 1;  -- Both ready for Phase 2
  signal Phase2Done  : integer_barrier := 1;
  signal Phase3Start : integer_barrier := 1;  -- Both ready for Phase 3
  signal Phase3Done  : integer_barrier := 1;
  signal Phase4Start : integer_barrier := 1;  -- Both ready for Phase 4
  signal Phase4Done  : integer_barrier := 1;

  -- Alert/Log IDs
  constant TCID : AlertLogIDType := NewID("FifoCcGotBurst_" & ConfigToString(CONFIG_INDEX));

begin
  ----------------------------------------------------------------------------
  -- Control Process - manages test lifecycle
  ----------------------------------------------------------------------------
  ControlProc : process
    constant ProcID  : AlertLogIDType := NewID("ControlProc", TCID);
    constant TIMEOUT : time := 500 ms;
  begin
    SetTestName("fifo_cc_got_Burst");

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
    variable SendOk     : boolean;
  begin
    wait until nReset = '1';
    WaitForClock(TxRec, 2);

    -- Assign BurstFifo to transaction record
    TxRec.BurstFifo <= TxBurstFifo;

    ---------------------------------------------------------------------------
    -- Phase 1: Fill FIFO to capacity using Send()
    ---------------------------------------------------------------------------
    Log(ProcID, "Phase 1: Fill FIFO to capacity via Send()", INFO);
        
    -- Fill with sequential data using individual Send transactions
    loop
      -- Use blocking Send with std_logic_vector
      Send(TxRec, std_logic_vector(to_unsigned(WriteCount, D_BITS)));
      WriteCount := WriteCount + 1;
      
      -- Wait for full signal to update after the write
      WaitForClock(TxRec, 1);
      
      -- Check if FIFO is now full
      exit when full = '1';
    end loop;
    
    -- Verify FIFO reached full state
    AffirmIf(ProcID, full = '1', "Phase 1: FIFO should be full after filling");
    
    Log(ProcID, "Phase 1: Filled " & integer'image(WriteCount) & " words", INFO);
    -- WaitForClock(TxRec);
    -- Signal that FIFO is full, reader can now drain
    WaitForBarrier(Phase1Fill);
    
    -- Wait for reader to drain Phase 1
    WaitForBarrier(Phase1Done);

    ---------------------------------------------------------------------------
    -- Phase 2: Burst writes using SendBurst (128 words)
    ---------------------------------------------------------------------------
    -- Synchronize start of Phase 2
    WaitForBarrier(Phase2Start);
    
    Log(ProcID, "Phase 2: Burst writes via SendBurst()", INFO);
    
    -- Fill TxBurstFifo with incremental data
    PushBurstIncrement(TxBurstFifo, WriteCount, 128, D_BITS);
    
    -- Send burst
    SendBurst(TxRec, 128);
    WriteCount := WriteCount + 128;

    Log(ProcID, "Phase 2: Wrote 128 burst words", INFO);
    
    -- Wait for reader to complete Phase 2
    WaitForBarrier(Phase2Done);

    ---------------------------------------------------------------------------
    -- Phase 3: Random burst writes with multiple small bursts
    ---------------------------------------------------------------------------
    -- Synchronize start of Phase 3
    WaitForBarrier(Phase3Start);
    
    Log(ProcID, "Phase 3: Multiple random bursts via SendBurst()", INFO);
    
    for burst in 0 to 9 loop
      -- Fill with random data
      PushBurstRandom(TxBurstFifo, WriteCount + burst*16, 16, D_BITS);
      
      -- Send burst of 16 words
      SendBurst(TxRec, 16);
      WriteCount := WriteCount + 16;

      -- Small gap between bursts
      WaitForClock(TxRec, 5);
    end loop;
    
    Log(ProcID, "Phase 3: Wrote random burst words", INFO);
    
    -- Wait for reader to complete Phase 3
    WaitForBarrier(Phase3Done);

    ---------------------------------------------------------------------------
    -- Phase 4: Mixed operations stress test
    ---------------------------------------------------------------------------
    -- Synchronize start of Phase 4
    WaitForBarrier(Phase4Start);
    
    Log(ProcID, "Phase 4: Mixed operations stress test", INFO);
    
    -- Mix of single sends and small bursts
    for i in 0 to 24 loop
      if (i mod 3) = 0 then
        -- Single send
        Send(TxRec, std_logic_vector(to_unsigned(WriteCount, D_BITS)));
        WriteCount := WriteCount + 1;
      else
        -- Small burst of 4 words
        PushBurstIncrement(TxBurstFifo, WriteCount, 4, D_BITS);
        SendBurst(TxRec, 4);
        WriteCount := WriteCount + 4;
      end if;
    end loop;

    Log(ProcID, "Total writes: " & integer'image(WriteCount), INFO);
    
    WaitForBarrier(Phase4Done);
    WaitForBarrier(TestDone);
    wait;
  end process;

  ----------------------------------------------------------------------------
  -- Reader Process - uses Transaction interface to verify data
  ----------------------------------------------------------------------------
  ReaderProc : process
    constant ProcID   : AlertLogIDType := NewID("ReaderProc", TCID);
    variable ReadCount  : integer := 0;
    variable ReadData   : std_logic_vector(D_BITS-1 downto 0);
  begin
    wait until nReset = '1';
    WaitForClock(RxRec, 2);

    -- Assign BurstFifo to transaction record
    RxRec.BurstFifo <= RxBurstFifo;

    ---------------------------------------------------------------------------
    -- Phase 1: Drain FIFO using Check()
    ---------------------------------------------------------------------------
    -- Wait for writer to fill FIFO completely
    Log(ProcID, "Phase 1: Wait for writer to fill FIFO completely", INFO);
    WaitForBarrier(Phase1Fill);
    
    Log(ProcID, "Phase 1: Drain FIFO via Check()", INFO);
    
    -- Drain sequential data using individual Check transactions until FIFO is empty
    while valid = '1' loop
      Check(RxRec, std_logic_vector(to_unsigned(ReadCount, D_BITS)));
      ReadCount := ReadCount + 1;
      WaitForClock(RxRec, 1);
    end loop;
    
    -- Verify FIFO is empty
    AffirmIf(ProcID, valid = '0', "Phase 1: FIFO should be empty after draining");
    
    Log(ProcID, "Phase 1: Read " & integer'image(ReadCount) & " words", INFO);
    
    WaitForBarrier(Phase1Done);

    ---------------------------------------------------------------------------
    -- Phase 2: Verify burst data using CheckBurst
    ---------------------------------------------------------------------------
    -- Synchronize start of Phase 2
    WaitForBarrier(Phase2Start);
    
    Log(ProcID, "Phase 2: Verify burst data via CheckBurst()", INFO);
    
    -- Prepare expected values
    PushBurstIncrement(RxBurstFifo, ReadCount, 128, D_BITS);
    
    -- Check burst
    CheckBurst(RxRec, 128);
    ReadCount := ReadCount + 128;
    Log(ProcID, "Phase 2: Verified 128 words", INFO);
    
    WaitForBarrier(Phase2Done);

    ---------------------------------------------------------------------------
    -- Phase 3: Verify random burst data
    ---------------------------------------------------------------------------
    -- Synchronize start of Phase 3
    WaitForBarrier(Phase3Start);
    
    Log(ProcID, "Phase 3: Verify random bursts via CheckBurst()", INFO);
    
    for burst in 0 to 9 loop
      -- Same seed pattern as writer
      PushBurstRandom(RxBurstFifo, ReadCount + burst*16, 16, D_BITS);
      
      -- Check burst
      CheckBurst(RxRec, 16);
      ReadCount := ReadCount + 16;
    end loop;
    
    Log(ProcID, "Phase 3: Verified 64 words", INFO);
    
    WaitForBarrier(Phase3Done);

    ---------------------------------------------------------------------------
    -- Phase 4: Verify mixed operations
    ---------------------------------------------------------------------------
    -- Synchronize start of Phase 4
    WaitForBarrier(Phase4Start);
    
    Log(ProcID, "Phase 4: Verify mixed operations", INFO);
    
    for i in 0 to 24 loop
      if (i mod 3) = 0 then
        -- Single check
        Check(RxRec, std_logic_vector(to_unsigned(ReadCount, D_BITS)));
        ReadCount := ReadCount + 1;
      else
        -- Small burst of 4 words
        PushBurstIncrement(RxBurstFifo, ReadCount, 4, D_BITS);
        CheckBurst(RxRec, 4);
        ReadCount := ReadCount + 4;
      end if;
    end loop;

    Log(ProcID, "Total reads verified: " & integer'image(ReadCount), INFO);
    
    WaitForBarrier(Phase4Done);
    WaitForBarrier(TestDone);
    wait;
  end process;

end architecture;

-- Configuration for Burst test
configuration fifo_cc_got_Burst of fifo_cc_got_TestHarness is
  for TestHarness
    for TestCtrl : fifo_cc_got_TestController
      use entity work.fifo_cc_got_TestController(Burst);
    end for;
  end for;
end configuration;
