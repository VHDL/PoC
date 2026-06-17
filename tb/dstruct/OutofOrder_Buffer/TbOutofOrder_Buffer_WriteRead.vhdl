-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Iqbal Asif
--
-- Entity:          Testcases for AXI4 stream delay.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

architecture WriteRead of dstruct_OutofOrder_Buffer_TestController is

	constant NUM_TRANSACTIONS : positive := 100000;
	constant TestName : string := "TbOutofOrder_Buffer_WriteRead";
	signal TestDone         : integer_barrier := 1 ;
	signal TransmissionDone : integer_barrier := 1 ;
	signal SB : osvvm.ScoreboardPkg_slv.ScoreboardIdArrayType(0 to NUM_INDEX - 1);

begin

	------------------------------------------------------------
	-- ControlProc
	--   Set up AlertLog and wait for end of test
	------------------------------------------------------------
	ControlProc : process
		constant TIMEOUT : time := 3 ms;
	begin
		-- Initialization of test
		SetTestName(TestName);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		SetLogEnable(PASSED, FALSE);  -- Enable PASSED logs
		SetLogEnable(INFO, FALSE);    -- Enable INFO logs
		SetLogEnable(DEBUG, FALSE);    -- Enable INFO logs
		SB <= NewID("Read_WRITE", NUM_INDEX) ;
		-- Wait for testbench initialization
		wait for 0 ns ;  wait for 0 ns;

		-- wait for design reset
		wait until nReset = '1';
		ClearAlerts;

		WaitForBarrier(TestDone, TIMEOUT);
		EndOfTestReports(ReportAll => TRUE, Timeout => now >= TIMEOUT);
		std.env.finish;
		wait;
	end process ControlProc;

	TransmitterProc : process
		variable RV          : RandomPType;
		variable DataSlv     : std_logic_vector(DATA_BITS - 1 downto 0) := (others => '0');
		variable wasFull     : std_logic;
	begin
		RV.InitSeed(RV'instance_name);
		wait until nReset = '1' ;
		put <= '0';

		WaitForClock(Clock, 10);

		for i in 0 to NUM_TRANSACTIONS-1 loop
			wait for 0.1 ns;

			if i = 1000 then -- Let the OOO buffer run empty
				wait for 1 us;
				WaitForClock(Clock);
			end if;

			put <= '1';
			DataSlv := RV.RandSlv(DATA_BITS);
			DataIn <= DataSlv;

			wasFull := full;

			WaitForClock(Clock);

			if wasFull = '0' then
				Push(SB(to_integer(IndexOut)), DataSlv);
				log("SB: Push, Index: " & to_hstring(IndexOut) & ", Data: " & to_hstring(DataSlv), DEBUG);
			end if;

			put <= '0';
			if RV.RandInt(0, 100) > 70 then  --Create gap with 70% chance
				WaitForClock(Clock, RV.RandInt(1, 10));
			end if;
		end loop;
		WaitForBarrier(TransmissionDone);
		WaitForBarrier(TestDone);
		wait ;
	end process TransmitterProc ;

	ReceiverProc : process
		variable RV          : RandomPType;
		variable Data   : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
		variable TestIndex : natural;
	begin
		IndexIn <= (others => '0');
		RV.InitSeed(RV'instance_name);
		Got <= '0';
		wait until nReset = '1' ;

		WaitForClock(Clock, 15);

		for i in 0 to NUM_TRANSACTIONS-1 loop
			TestIndex := RV.RandInt(0, NUM_INDEX -1);

			IndexIn <= to_unsigned(TestIndex, IndexIn'length);

			wait for 0.1 ns;

			if Empty(SB(TestIndex)) then
				AffirmIf(Valid = '0', "Expected Valid = 0 for empty SB " & to_string(TestIndex));

				if RV.RandInt(0, 100) > 50 then -- Try to remove empty slot with 50% chance
					Got <= '1';
				end if;
			else
				Got <= '1';
				AffirmIf(Valid = '1', "Expected Valid = 1 for SB " & to_string(TestIndex));

				if RV.RandInt(0, 100) > 20 then  -- Peek with 20% chance
					Got <= '0';
					Peek(SB(TestIndex), Data);
					log("SB: Peek, Index: " & to_string(TestIndex) & ", Data: " & to_hstring(Data), DEBUG);
					AffirmIf(Data = DataOut, "Got Data=0x" & to_hstring(DataOut) & ", expected Data=0x" & to_hstring(Data) &  " for SB " & to_string(TestIndex));
				else
					Check(SB(TestIndex), DataOut);
					log("SB: Check, Index: " & to_string(TestIndex) & ", Data: " & to_hstring(DataOut), DEBUG);
				end if;
			end if;

			WaitForClock(Clock);

			Got <= '0';
			if RV.RandInt(0, 100) > 70 then --Create gap with 70% chance
				WaitForClock(Clock, RV.RandInt(1, 10));
			end if;
		end loop;

		WaitForClock(Clock);
		WaitForBarrier(TransmissionDone);

		WaitForClock(Clock, 3);
		-- clear SB
		for j in 0 to NUM_INDEX - 1 loop
			TestIndex := j;
			IndexIn <= to_unsigned(TestIndex, IndexIn'length);

			wait for 0.1 ns;

			if Empty(SB(TestIndex)) then
				AffirmIf(Valid = '0', "Expected Valid = 0 for empty SB " & to_string(TestIndex));
			else
				Got <= '1';
				AffirmIf(Valid = '1', "Expected Valid = 1 for SB " & to_string(TestIndex));
				Check(SB(TestIndex), DataOut);
				log("SB: Check, Index: " & to_string(TestIndex) & ", Data: " & to_hstring(DataOut), DEBUG);
			end if;

			WaitForClock(Clock);

			Got <= '0';
		end loop;

		WaitForBarrier(TestDone);
		wait ;
	end process;

end architecture;

configuration TbOutofOrder_Buffer_WriteRead of tb_OutofOrder_Buffer is
	for TestHarness
		for TestCtrl : dstruct_OutofOrder_Buffer_TestController
			use entity work.dstruct_OutofOrder_Buffer_TestController(WriteRead);
		end for;
	end for;
end configuration;
