-- =============================================================================
-- Authors:
--	Stefan Unrein (PLC2 Design GmbH)
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

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;

architecture SimpleReadWrite_multiID_randDelay of AXI4_Demux_TestController is
	signal TestDone : integer_barrier := 1;

begin

	------------------------------------------------------------
	-- ControlProc
	-- Set up AlertLog and wait for end of test
	------------------------------------------------------------
	ControlProc : process
		constant TestName : string := "TC_SimpleReadWrite_multiID_randDelay";
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
		SetUseRandomDelays(ManagerRec);
		SetModelOptions(ManagerRec, WRITE_RESPONSE_VALID_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, READ_DATA_VALID_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, WRITE_ADDRESS_READY_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, WRITE_DATA_READY_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, WRITE_RESPONSE_READY_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, READ_ADDRESS_READY_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, READ_DATA_READY_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, WRITE_RESPONSE_VALID_TIME_OUT, 5000) ;
		SetModelOptions(ManagerRec, READ_DATA_VALID_TIME_OUT, 5000) ;
		WaitForClock(ManagerRec, 2);

		for i in 0 to CHANNELS - 1 loop
			for j in 1 to 64 loop
				WriteAsync(ManagerRec, to_slv(to_unsigned(1024 * i + 64 * j +0, 32)), to_slv(to_unsigned(1024 * i + 64 * j +0, 32)));
				WriteAsync(ManagerRec, to_slv(to_unsigned(1024 * i + 64 * j +16, 32)), to_slv(to_unsigned(1024 * i + 64 * j +16, 32)));
			end loop;

			for j in 1 to 64 loop
				ReadAddressAsync(ManagerRec, to_slv(to_unsigned(1024 * i + 64 * j +0, 32)));
				ReadAddressAsync(ManagerRec, to_slv(to_unsigned(1024 * i + 64 * j +16, 32)));
			end loop;
		end loop;

		for i in 0 to CHANNELS - 1 loop
			for j in 1 to 64 loop
				ReadCheckData(ManagerRec, to_slv(to_unsigned(1024 * i + 64 * j +0, 32)));
				ReadCheckData(ManagerRec, to_slv(to_unsigned(1024 * i + 64 * j +16, 32)));
			end loop;
		end loop;

		-- Wait for outputs to propagate and signal TestDone
		WaitForTransaction(ManagerRec);
		WaitForClock(ManagerRec, 10);
		WaitForBarrier(TestDone);
		wait;
	end process;

	Responder_gen : for i in 0 to CHANNELS - 1 generate
	begin
		ResponderProc : process
			variable WriteAddress : std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
			variable ReadAddress  : std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
			variable WriteData    : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
			variable WriteAddressV : natural := 0;
			variable WriteDataV    : natural := 0;
			variable Available : boolean;
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
			SetModelOptions(SubordinateRec(i), WRITE_RESPONSE_VALID_TIME_OUT, 500) ;
			SetModelOptions(SubordinateRec(i), READ_DATA_VALID_TIME_OUT, 500) ;
			WaitForClock(SubordinateRec(i), 2);

			loop
				TryGetWriteAddress(SubordinateRec(i), WriteAddress, Available);
				if Available then
					WriteAddressV := WriteAddressV +1;
					Log("Received Write Address: " & to_hxstring(WriteAddress));
				end if;

				if WriteAddressV > 0 then
					TryGetWriteData(SubordinateRec(i), WriteData, Available);
					if Available then
						WriteDataV := WriteDataV +1;
						Log("Received Write Data: " & to_hxstring(WriteData));
					end if;
				end if;
				if WriteDataV > 0 and WriteAddressV > 0 then
					WriteAddressV := WriteAddressV -1;
					WriteDataV    := WriteDataV -1;
					AffirmIfEqual(WriteAddress, WriteData, "Write Address Data check");
				end if;


				TryGetReadAddress(SubordinateRec(i), ReadAddress, Available);
				if Available then
					-- GetAxi4Options(SubordinateRec(i), ARID, ID);
					Log("Received Read Address: " & to_hxstring(ReadAddress));
					-- SetAxi4Options(SubordinateRec(i), RID, ID);
					SendReadDataAsync(SubordinateRec(i), ReadAddress);
				end if;
				WaitForClock(SubordinateRec(i));
			end loop;
			wait;
		end process;
	end generate;

end architecture;

configuration TC_SimpleReadWrite_multiID_randDelay of AXI4_Demux_TestHarness is
	for Harness
		for TestCtrl : AXI4_Demux_TestController
			use entity work.AXI4_Demux_TestController(SimpleReadWrite_multiID_randDelay);
		end for;
	end for;
end configuration;
