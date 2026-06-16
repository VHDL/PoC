-- =============================================================================
-- Authors:
--  Iqbal Asif (PLC2 Design GmbH)
--  Patrick Lehmann (PLC2 Design GmbH)
--	Stefan Unrein (PLC2 Design GmbH)
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;

library osvvm;
use     osvvm.ScoreBoardPkg_slv.all;

library osvvm_Axi4 ;
context osvvm_Axi4.Axi4LiteContext ;

architecture SimpleReadWrite_delay of AXI4_Demux_TestController is
	signal TestDone : integer_barrier := 1;
	signal WriteAddr_SB : ScoreboardIDArrayType(1 to CHANNELS);
	signal WriteData_SB : ScoreboardIDArrayType(1 to CHANNELS);
	signal ReadAddr_SB  : ScoreboardIDArrayType(1 to CHANNELS);
	signal ReadData_SB  : ScoreboardIDArrayType(1 to CHANNELS);
begin

	------------------------------------------------------------
	-- ControlProc
	-- Set up AlertLog and wait for end of test
	------------------------------------------------------------
	ControlProc : process
		constant TestName : string := "TC_SimpleReadWrite_delay";
	begin
		-- Initialization of test
		SetTestName(TestName);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		WriteAddr_SB <= NewID("WriteAddr_SB", CHANNELS);
		WriteData_SB <= NewID("WriteData_SB", CHANNELS);
		ReadAddr_SB  <= NewID("ReadAddr_SB", CHANNELS);
		ReadData_SB  <= NewID("ReadData_SB", CHANNELS);

		SetLogEnable(PASSED, FALSE); -- Enable PASSED logs
		SetLogEnable(INFO, FALSE);   -- Enable INFO logs

		-- Wait for testbench initialization

		-- Wait for Design Reset
		wait until Reset = '0';
		ClearAlerts;

		-- Wait for test to finish
		WaitForBarrier(TestDone, 10 ms);
		AlertIf(now >= 10 ms, "Test finished due to timeout");
		AlertIf(GetAffirmCount < 100, "Test is not Self-Checking");

		wait for 1 us;

		EndOfTestReports(ReportAll => TRUE);
		TranscriptClose;
		std.env.stop;
		wait;
	end process ControlProc;

	ManagerProc : process
		variable Address  : unsigned(AXI_ADDR_WIDTH - 1 downto 0);
		variable Data     : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
		variable Available : boolean;
	begin
		-------------------------------------
		-- Normal Rread and Wirte
		-------------------------------------
		wait until Reset = '0';

		SetUseRandomDelays(ManagerRec);

		SetModelOptions(ManagerRec, WRITE_RESPONSE_VALID_TIME_OUT, 500) ;
		SetModelOptions(ManagerRec, READ_DATA_VALID_TIME_OUT, 500) ;
		SetModelOptions(ManagerRec, WRITE_ADDRESS_READY_TIME_OUT, 500) ;
		SetModelOptions(ManagerRec, WRITE_DATA_READY_TIME_OUT, 500) ;
		SetModelOptions(ManagerRec, WRITE_RESPONSE_READY_TIME_OUT, 500) ;
		SetModelOptions(ManagerRec, READ_ADDRESS_READY_TIME_OUT, 500) ;
		SetModelOptions(ManagerRec, READ_DATA_READY_TIME_OUT, 500) ;

		WaitForClock(ManagerRec, 2);

		for i in 1 to CHANNELS loop
			Address := resize(32x"10000" * i, 32);
			for j in 1 to 64 loop
				Push(WriteAddr_SB(i), to_slv(Address + 16 * j));
				Push(WriteData_SB(i), to_slv(X"0000_0000" + j));
				WriteAsync(ManagerRec, to_slv(Address + 16 * j), to_slv(X"0000_0000" + j));
				-- SetAxi4Options(ManagerRec, AWID, j);
			end loop;
			WaitForClock(ManagerRec, 1);
			-- WaitForTransaction(ManagerRec);

			for j in 1 to 64 loop
				Push(ReadAddr_SB(i), to_slv(Address + 16 * j));
				ReadAddressAsync(ManagerRec, to_slv(Address + 16 * j));
			end loop;
			WaitForClock(ManagerRec, 1);


			TryReadData(ManagerRec, Data, Available);

			-- WaitForTransaction(ManagerRec);
			-- WaitForClock(ManagerRec, 2);
		end loop;

		for i in 1 to CHANNELS loop
			for j in 1 to 64 loop
				ReadData(ManagerRec, Data);
			end loop;
		end loop;

		-- Wait for outputs to propagate and signal TestDone
		WaitForClock(ManagerRec, 2);
		WaitForBarrier(TestDone);
		wait;
	end process;

	Responder_gen : for i in 0 to CHANNELS - 1 generate
	begin
		ResponderProc : process
			constant BaseAddress : unsigned(AXI_ADDR_WIDTH - 1 downto 0) := resize(32x"10000" * (i + 1), 32);
			variable Address     : std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
			variable Data        : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
			variable ReadData    : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
			variable Available   : boolean;
			variable receivedAW  : natural := 0;
			variable receivedW   : natural := 0;
			variable receivedAR  : natural := 0;
			variable receivedR   : natural := 0;
		begin
			-------------------------------------
			-- Normal Rread and Wirte
			-------------------------------------
			wait until Reset = '0';

			SetUseRandomDelays(SubordinateRec(i));
			SetModelOptions(SubordinateRec(i), WRITE_RESPONSE_VALID_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), READ_DATA_VALID_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), WRITE_ADDRESS_READY_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), WRITE_DATA_READY_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), WRITE_RESPONSE_READY_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), READ_ADDRESS_READY_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), READ_DATA_READY_TIME_OUT, 500) ;
			WaitForClock(SubordinateRec(i), 2);

			-- SetAxi4Options(SubordinateRec(i), BID, ID_value) ;  -- write response BID
			-- SetAxi4Options(SubordinateRec(i), RID, ID_value) ;  -- read data RID

			-- Check Single transactions
			loop
				TryGetWriteAddress(SubordinateRec(i), Address, Available);
				if Available then
					Log("Got Write Address");
					Check(WriteAddr_SB(i +1), Address);
					receivedAW := receivedAW +1;
				end if;

				TryGetWriteData(SubordinateRec(i), Data, Available);
				if Available then
					Log("Got Write Data");
					Check(WriteData_SB(i +1), Data);
					receivedW := receivedW +1;
				end if;

				TryGetReadAddress(SubordinateRec(i), Address, Available);
				if Available then
					Log("Got Read Address");
					Check(ReadAddr_SB(i +1), Address);
					SendReadData(SubordinateRec(i), to_slv(X"0000_0000" + receivedAR));
					receivedAR := receivedAR +1;
				end if;
				WaitForClock(SubordinateRec(i), 1);

				exit when receivedAW >= 64 and receivedW >= 64 and receivedAR >= 64;
			end loop;

			AlertIf(receivedAW > 64, "Received more than the expected 64 transactions");
			AlertIf(receivedW > 64, "Received more than the expected 64 transactions");
			AlertIf(receivedAR > 64, "Received more than the expected 64 transactions");
			WaitForBarrier(TestDone);
			wait;
		end process;
	end generate;

end architecture;

configuration TC_SimpleReadWrite_delay of AXI4_Demux_TestHarness is
	for Harness
		for TestCtrl : AXI4_Demux_TestController
			use entity work.AXI4_Demux_TestController(SimpleReadWrite_delay);
		end for;
	end for;
end configuration;
