-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Gustavo Martin
--
-- Architecture:    fifo_cc_got_Random
--
-- Description:
-- -------------------------------------
-- Random stress test for fifo_cc_got using OSVVM Verification Components
-- Uses Transaction interface with randomized operations:
-- - Random single Send/Check vs SendBurst/CheckBurst selection
-- - Random burst sizes (1 to 32 words)
-- - Random delays between operations
-- - TrySend/TryCheck for non-blocking operations when FIFO full/empty
-- - Asynchronous writer/reader processes (no barriers)
--
-- Coverage Requirements:
-- - Each fill level (0-15) covered multiple times (at least 3x)
-- - All operation types covered
-- - Full and Empty states reached multiple times
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

architecture Random of fifo_cc_got_TestController is
	-- Test synchronization
	signal TestDone    : integer_barrier := 1;
	signal WriterDone  : integer := 0;
	signal ReaderDone  : integer := 0;

	-- Alert/Log IDs
	constant TCID : AlertLogIDType := NewID("FifoCcGotRandom_" & ConfigToString(CONFIG_INDEX));

	-- Shared Scoreboard for data checking
	constant Scoreboard : ScoreboardIdType := NewID("DataScoreboard", TCID);

	-- Functional Coverage
	constant FillCov    : CoverageIDType := NewID("FillLevelCoverage", TCID);
	constant OpCov      : CoverageIDType := NewID("OperationCoverage", TCID);
	constant FlagCov    : CoverageIDType := NewID("FlagCoverage", TCID);

	-- Test parameters
	constant MAX_BURST   : integer := 32;    -- Maximum burst size
	constant MAX_OPS     : integer := 1000000; -- Safety limit on operations

	constant COV_SEND_ID           : integer := 1;
	constant COV_CHECK_ID          : integer := 2;
	constant COV_BURSTOFSINGLES_ID : integer := 3;
	constant COV_ACTUALBURST_ID    : integer := 4;

	constant COV_EMPTY_ID             : integer := 0;
	constant COV_NOT_EMPTY_ID         : integer := 1;
	constant COV_FULL_ID              : integer := 2;
	constant COV_NOT_FULL_ID          : integer := 3;

begin
	----------------------------------------------------------------------------
	-- Control Process - manages test lifecycle
	----------------------------------------------------------------------------
	ControlProc : process
		constant ProcID  : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 1 sec;
	begin
		SetTestName("fifo_cc_got_Random");

		SetLogEnable(PASSED, FALSE);
		SetLogEnable(INFO,   TRUE);
		SetLogEnable(DEBUG,  FALSE);
		wait for 0 ns; wait for 0 ns;

		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		-- Initialize Burst FIFOs
		TxBurstFifo <= NewID("TxBurstFifo", TCID);
		RxBurstFifo <= NewID("RxBurstFifo", TCID);

		-- Initialize Fill Level Coverage (4-bit state = 0-15)
		-- Require at least 20 hits per bin
		for i in 0 to 15 loop
			AddBins(FillCov, "Fill_" & integer'image(i), 20, GenBin(i));
		end loop;

		-- Initialize Operation Coverage
		AddBins(OpCov, "Send",           20, GenBin(COV_SEND_ID));
		AddBins(OpCov, "Check",          20, GenBin(COV_CHECK_ID));
		AddBins(OpCov, "BurstOfSingles", 20, GenBin(COV_BURSTOFSINGLES_ID));
		AddBins(OpCov, "ActualBurst",    20, GenBin(COV_ACTUALBURST_ID));

		-- Initialize Flag Coverage (require 20+ hits for Full/Empty states)
		AddBins(FlagCov, "Empty",       20, GenBin(COV_EMPTY_ID));
		AddBins(FlagCov, "Not_Empty",   20, GenBin(COV_NOT_EMPTY_ID));
		AddBins(FlagCov, "Full",        20, GenBin(COV_FULL_ID));
		AddBins(FlagCov, "Not_Full",    20, GenBin(COV_NOT_FULL_ID));

		wait until nReset = '1';
		ClearAlerts;

		-- Wait until all coverage goals are met
		loop
			wait for 1 us;
			exit when (IsCovered(FillCov) and IsCovered(OpCov) and IsCovered(FlagCov)) or now >= TIMEOUT;
			if now >= TIMEOUT then
				Alert(ProcID, "Coverage timeout - not all bins covered", WARNING);
				exit;
			end if;
			exit when WriterDone > 0 and ReaderDone > 0;
		end loop;

		WaitForBarrier(TestDone, 10 ms);
		AlertIf(ProcID, GetAffirmCount < 1, "Test is not Self-Checking");

		-- Check coverage goals before reporting
		AlertIfNot(ProcID, IsCovered(FillCov), "FillCov: Coverage goals not met");
		AlertIfNot(ProcID, IsCovered(OpCov), "OpCov: Coverage goals not met");
		AlertIfNot(ProcID, IsCovered(FlagCov), "FlagCov: Coverage goals not met");

		-- Report Coverage results
		Log(ProcID, "=== Coverage Reports ===", ALWAYS);
		WriteBin(FillCov);
		WriteBin(OpCov);
		WriteBin(FlagCov);

		EndOfTestReports(ReportAll => TRUE);
		std.env.stop;
	end process;

	----------------------------------------------------------------------------
	-- Writer Process - randomized writes using Transaction interface
	----------------------------------------------------------------------------
	WriterProc : process
		constant ProcID     : AlertLogIDType := NewID("WriterProc", TCID);
		variable RV         : RandomPType;
		variable WriteCount : integer := 0;
		variable BurstSize  : integer;
		variable WaitCycles : integer;
		variable UseBurst   : boolean;
		variable CurrFill   : integer;
		variable TargetFill : integer;
	begin
		wait until nReset = '1';
		WaitForClock(TxRec, 2);

		-- Assign local BurstFifo to transaction record
		TxRec.BurstFifo <= TxBurstFifo;

		-- Initialize random generator with unique seed
		RV.InitSeed(RV'instance_name);

		Log(ProcID, "Starting coverage-driven write operations", INFO);

		while WriteCount < MAX_OPS loop
			-- Get current fill level (must match Monitor's coverage tracking)
			CurrFill := to_integer(unsigned(fstate_rd));
			
			-- Intelligent coverage: get a fill level that needs more hits
			TargetFill := GetRandPoint(FillCov);
			
			-- Adjust delay based on coverage needs:
			-- If need lower fill levels, wait longer to let FIFO drain
			-- If need higher fill levels, write quickly
			if TargetFill < CurrFill then
				-- Need to drain - wait longer
				WaitCycles := RV.RandInt(50, 100);
			elsif TargetFill > CurrFill then
				-- Need to fill - write fast
				WaitCycles := RV.RandInt(1, 5);
			else
				-- At target - moderate pace
				WaitCycles := RV.RandInt(10, 30);
			end if;
			
			if WaitCycles > 0 then
				WaitForClock(TxRec, WaitCycles);
			end if;
			
			-- Stop if all coverage met
			exit when IsCovered(FillCov) and IsCovered(OpCov) and IsCovered(FlagCov);

			-- Randomly choose between single, burst of singles, and actual burst
			UseBurst := RV.RandInt(0, 99) < 70;  -- 70% burst, 30% single

			if UseBurst then
				-- Random burst size (2 to MAX_BURST words)
				BurstSize := RV.RandInt(2, MAX_BURST);
				
				-- 50/50 choice between burst of singles vs actual burst
				if RV.RandInt(0, 99) < 50 then
					-- Burst of singles: loop of individual Send() calls
					for i in 0 to BurstSize-1 loop
						Push(Scoreboard, std_logic_vector(to_unsigned(WriteCount + i, D_BITS)));
						Send(TxRec, std_logic_vector(to_unsigned(WriteCount + i, D_BITS)));
					end loop;
					WriteCount := WriteCount + BurstSize;
					ICover(OpCov, COV_BURSTOFSINGLES_ID);
				else
					-- Actual burst: use SendBurst() with TxBurstFifo
					for i in 0 to BurstSize-1 loop
						Push(Scoreboard, std_logic_vector(to_unsigned(WriteCount + i, D_BITS)));
						Push(TxBurstFifo, std_logic_vector(to_unsigned(WriteCount + i, D_BITS)));
					end loop;
					SendBurst(TxRec, BurstSize);
					WriteCount := WriteCount + BurstSize;
					ICover(OpCov, COV_ACTUALBURST_ID);
				end if;
			else
				-- Single word operation: Push before Send
				Push(Scoreboard, std_logic_vector(to_unsigned(WriteCount, D_BITS)));
				Send(TxRec, std_logic_vector(to_unsigned(WriteCount, D_BITS)));
				WriteCount := WriteCount + 1;
				ICover(OpCov, COV_SEND_ID);
			end if;
		end loop;

		Log(ProcID, "Writer complete - " & integer'image(WriteCount) & " words sent, coverage met", INFO);
		WriterDone <= 1;
		WaitForBarrier(TestDone);
		wait;
	end process;

	----------------------------------------------------------------------------
	-- Reader Process - randomized reads using Transaction interface
	----------------------------------------------------------------------------
	ReaderProc : process
		constant ProcID     : AlertLogIDType := NewID("ReaderProc", TCID);
		variable RV         : RandomPType;
		variable ReadCount  : integer := 0;
		variable BurstSize  : integer;
		variable WaitCycles : integer;
		variable UseBurst   : boolean;
		variable ReadData   : std_logic_vector(D_BITS-1 downto 0);
		variable CurrFill   : integer;
		variable TargetFill : integer;
		variable ActualBurstSize : integer := 0;
	begin
		wait until nReset = '1';
		WaitForClock(RxRec, 2);

		-- Assign local BurstFifo to transaction record
		RxRec.BurstFifo <= RxBurstFifo;

		-- Initialize random generator with unique seed
		RV.InitSeed(RV'instance_name);

		Log(ProcID, "Starting coverage-driven read operations", INFO);

		while ReadCount < MAX_OPS loop
			-- Exit only when Writer is done AND Scoreboard is empty
			exit when WriterDone > 0 and IsEmpty(Scoreboard);
			
			-- Skip iteration if Scoreboard is empty (Writer still active, waiting for data)
			if IsEmpty(Scoreboard) then
				WaitForClock(RxRec, 10);
				next;
			end if;
			
			-- Get current fill level (must match Monitor's coverage tracking)
			CurrFill := to_integer(unsigned(fstate_rd));
			
			-- Intelligent coverage: get a fill level that needs more hits
			TargetFill := GetRandPoint(FillCov);
			 
			-- Adjust delay based on coverage needs:
			-- If need lower fill levels, read quickly to drain
			-- If need higher fill levels, wait to let FIFO fill
			if TargetFill < CurrFill then
				-- Need to drain - read fast
				WaitCycles := RV.RandInt(1, 5);
			elsif TargetFill > CurrFill then
				-- Need to fill - wait longer
				WaitCycles := RV.RandInt(40, 80);
			else
				-- At target - moderate pace
				WaitCycles := RV.RandInt(10, 30);
			end if;
			
			if WaitCycles > 0 then
				WaitForClock(RxRec, WaitCycles);
			end if;
			
			-- Randomly choose between single, burst of singles, and actual burst
			-- Only do burst if Scoreboard has enough data
			UseBurst := RV.RandInt(0, 99) < 70 and not IsEmpty(Scoreboard);  -- 70% burst, 30% single

			if UseBurst then
				-- Random burst size limited by available data
				BurstSize := RV.RandInt(2, minimum(MAX_BURST, 10));

				-- 50/50 choice between burst of singles vs actual burst
				if RV.RandInt(0, 99) < 50 then
					-- Burst of singles: loop of individual Get/Check calls
					for i in 0 to BurstSize-1 loop
						exit when IsEmpty(Scoreboard);
						Get(RxRec, ReadData);
						Check(Scoreboard, ReadData);
						ReadCount := ReadCount + 1;
					end loop;
					ICover(OpCov, COV_BURSTOFSINGLES_ID);
				else
					-- Actual burst: use CheckBurst() with RxBurstFifo
					-- Transfer expected data from Scoreboard to RxBurstFifo
					for i in 0 to BurstSize-1 loop
						exit when IsEmpty(Scoreboard);
						Push(RxBurstFifo, Pop(Scoreboard));
						ActualBurstSize := ActualBurstSize + 1;
					end loop;
					-- Now check the burst from FIFO (only if we pushed data)
					if ActualBurstSize > 0 then
						CheckBurst(RxRec, ActualBurstSize);
						ReadCount := ReadCount + ActualBurstSize;
					end if;
					ICover(OpCov, COV_ACTUALBURST_ID);
					ActualBurstSize := 0;
				end if;
			else
				-- Single word operation
				Get(RxRec, ReadData);
				Check(Scoreboard, ReadData);
				ReadCount := ReadCount + 1;
				ICover(OpCov, COV_CHECK_ID);
			end if;
		end loop;

		Log(ProcID, "Reader complete - " & integer'image(ReadCount) & " words verified, Scoreboard empty", INFO);
		ReaderDone <= 1;
		WaitForBarrier(TestDone);
		wait;
	end process;

	----------------------------------------------------------------------------
	-- Monitor Process - samples FIFO state for coverage
	----------------------------------------------------------------------------
	MonitorProc : process
		constant ProcID    : AlertLogIDType := NewID("MonitorProc", TCID);
		variable PrevFull  : std_logic := '0';
		variable PrevValid : std_logic := '0';
		variable PrevState : integer := -1;
		variable CurrState : integer := 0;
	begin
		wait until nReset = '1';
		
		loop
			WaitForClock(Clock);
			
			-- Sample write-side fill state
			CurrState := to_integer(unsigned(fstate_rd));
			
			-- Record coverage on state change
			if CurrState /= PrevState then
				ICover(FillCov, CurrState);
				PrevState := CurrState;
			end if;
			
			-- Sample Full flag
			if full /= PrevFull then
				if full = '1' then
					ICover(FlagCov, COV_FULL_ID);
					Log(ProcID, "FULL detected", DEBUG);
				else
					ICover(FlagCov, COV_NOT_FULL_ID);
				end if;
				PrevFull := full;
			end if;
			
			-- Sample Empty flag (via valid)
			if valid /= PrevValid then
				if valid = '0' then
					ICover(FlagCov, COV_EMPTY_ID);
					Log(ProcID, "EMPTY detected", DEBUG);
				else
					ICover(FlagCov, COV_NOT_EMPTY_ID);
				end if;
				PrevValid := valid;
			end if;
			
			-- Exit when both writer and reader are done
			exit when WriterDone > 0 and ReaderDone > 0;
		end loop;
		
		wait;
	end process;

end architecture;

-- Configuration for Random test
configuration fifo_cc_got_Random of fifo_cc_got_TestHarness is
	for TestHarness
		for TestCtrl : fifo_cc_got_TestController
			use entity work.fifo_cc_got_TestController(Random);
		end for;
	end for;
end configuration;
