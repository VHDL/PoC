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

architecture SimpleReadWrite of AXI4_Demux_TestController is
	signal TestDone : integer_barrier := 1;

begin

	------------------------------------------------------------
	-- ControlProc
	-- Set up AlertLog and wait for end of test
	------------------------------------------------------------
	ControlProc : process
		constant TestName : string := "TC_SimpleReadWrite";
	begin
		-- Initialization of test
		SetTestName(TestName);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		SetLogEnable(PASSED, FALSE); -- Enable PASSED logs
		SetLogEnable(INFO, FALSE);    -- Enable INFO logs

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
		variable ReadData : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
		variable StartTime : time;
	begin
		-------------------------------------
		-- Normal Rread and Wirte
		-------------------------------------
		wait until Reset = '0';
		SetModelOptions(ManagerRec, WRITE_RESPONSE_VALID_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, READ_DATA_VALID_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, WRITE_ADDRESS_READY_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, WRITE_DATA_READY_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, WRITE_RESPONSE_READY_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, READ_ADDRESS_READY_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, READ_DATA_READY_TIME_OUT, 5000) ;
		WaitForClock(ManagerRec, 2);

		StartTime := NOW;
		for i in 1 to CHANNELS loop
			Address := resize(32x"10000" * i, 32);
			for j in 1 to 64 loop
				WriteAsync(ManagerRec, to_slv(Address + 16 * j), to_slv(X"0000_0000" + j));
			end loop;
		end loop;
		WaitForTransaction(ManagerRec);
		Log("Write transaction took " & to_string(NOW - StartTime, 1 ns) & " for number=" & integer'image(CHANNELS * 64));

		wait for 1 us;
		StartTime := NOW;
		for i in 1 to CHANNELS loop
			Address := resize(32x"10000" * i, 32);

			for j in 1 to 64 loop
				ReadAddressAsync(ManagerRec, to_slv(Address + 16 * j));
			end loop;
			for j in 1 to 64 loop
				ReadCheckData(ManagerRec, to_slv(X"0000_0000" + j));
			end loop;

			WaitForClock(ManagerRec);
		end loop;
		Log("Read transaction took " & to_string(NOW - StartTime, 1 ns) & " for number=" & integer'image(CHANNELS * 64));

		wait for 1 us;
		StartTime := NOW;
		-- Transfer write and read at the same time
		for i in 1 to CHANNELS loop
			Address := resize(32x"10000" * i, 32);
			for j in 1 to 64 loop
				WriteAsync(ManagerRec, to_slv(Address + 16 * j), to_slv(X"0000_0000" + j));
			end loop;

			WaitForTransaction(ManagerRec);

			for j in 1 to 64 loop
				ReadAddressAsync(ManagerRec, to_slv(Address + 16 * j));
			end loop;
			for j in 1 to 64 loop
				ReadCheckData(ManagerRec, to_slv(X"0000_0000" + j));
			end loop;

			WaitForTransaction(ManagerRec);
			WaitForClock(ManagerRec, 2);
		end loop;
		WaitForTransaction(ManagerRec);
		Log("Write and Read transaction took " & to_string(NOW - StartTime, 1 ns) & " for number=" & integer'image(2* CHANNELS * 64));

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
		begin
			-------------------------------------
			-- Normal Rread and Wirte
			-------------------------------------
			wait until Reset = '0';
			SetModelOptions(SubordinateRec(i), WRITE_RESPONSE_VALID_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), READ_DATA_VALID_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), WRITE_ADDRESS_READY_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), WRITE_DATA_READY_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), WRITE_RESPONSE_READY_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), READ_ADDRESS_READY_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), READ_DATA_READY_TIME_OUT, 500) ;
			WaitForClock(SubordinateRec(i), 2);

			-- Check Single transactions
			for j in 1 to 64 loop
				GetWrite(SubordinateRec(i), Address, Data);
				AffirmIfEqual(Address, to_slv(BaseAddress + 16 * j), "Subordinate Write Addr: ");
				AffirmIfEqual(Data, to_slv(X"0000_0000" + j), "Subordinate Write Data: ");
			end loop;

			for j in 1 to 64 loop
				SendRead(SubordinateRec(i), Address, to_slv(X"0000_0000" + j));
				AffirmIfEqual(Address, to_slv(BaseAddress + 16 * j), "Subordinate Read Addr: ");
			end loop;

			for j in 1 to 64 loop
				GetWrite(SubordinateRec(i), Address, Data);
				AffirmIfEqual(Address, to_slv(BaseAddress + 16 * j), "Subordinate Write Addr: ");
				AffirmIfEqual(Data, to_slv(X"0000_0000" + j), "Subordinate Write Data: ");
			end loop;

			for j in 1 to 64 loop
				SendRead(SubordinateRec(i), Address, to_slv(X"0000_0000" + j));
				AffirmIfEqual(Address, to_slv(BaseAddress + 16 * j), "Subordinate Read Addr: ");
			end loop;

			wait;
		end process;
	end generate;

end architecture;

configuration TC_SimpleReadWrite of AXI4_Demux_TestHarness is
	for Harness
		for TestCtrl : AXI4_Demux_TestController
			use entity work.AXI4_Demux_TestController(SimpleReadWrite);
		end for;
	end for;
end configuration;
