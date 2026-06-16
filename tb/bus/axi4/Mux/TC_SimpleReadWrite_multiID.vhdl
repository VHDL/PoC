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

library OSVVM;
context OSVVM.OsvvmContext;

library OSVVM_AXI4;
context OSVVM_AXI4.Axi4Context;

library PoC;
use     PoC.utils.all;

architecture SimpleReadWrite_multiID of TestControl is
	signal TestDone : integer_barrier := 1;

begin

	------------------------------------------------------------
	-- ControlProc
	-- Set up AlertLog and wait for end of test
	------------------------------------------------------------
	ControlProc : process
		constant TestName : string := "TC_SimpleReadWrite_multiID";
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
		WaitForBarrier(TestDone);
		AlertIf(now >= 10 ms, "Test finished due to timeout");
		AlertIf(GetAffirmCount < 64 * 8, "Test is not Self-Checking");

		wait for 1 us;

		EndOfTestReports(ReportAll => TRUE);
		TranscriptClose;
		std.env.stop;
		wait;
	end process ControlProc;

	Manager_gen : for i in AXI4_Manager_Transaction'range generate
	begin
		ManagerProc : process
			variable Address  : std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
			variable Data     : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
			variable ReadData : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
		begin
			wait until Reset = '0';
			SetModelOptions(AXI4_Manager_Transaction(i), WRITE_RESPONSE_VALID_TIME_OUT, 5000) ;
			SetModelOptions(AXI4_Manager_Transaction(i), READ_DATA_VALID_TIME_OUT, 5000) ;
			SetModelOptions(AXI4_Manager_Transaction(i), WRITE_ADDRESS_READY_TIME_OUT, 5000) ;
			SetModelOptions(AXI4_Manager_Transaction(i), WRITE_DATA_READY_TIME_OUT, 5000) ;
			SetModelOptions(AXI4_Manager_Transaction(i), WRITE_RESPONSE_READY_TIME_OUT, 5000) ;
			SetModelOptions(AXI4_Manager_Transaction(i), READ_ADDRESS_READY_TIME_OUT, 5000) ;
			SetModelOptions(AXI4_Manager_Transaction(i), READ_DATA_READY_TIME_OUT, 5000) ;
			WaitForClock(AXI4_Manager_Transaction(i), 2);

			for j in 1 to 64 loop
				WriteAsync(AXI4_Manager_Transaction(i), to_slv(to_unsigned(1024 * i + 64 * j +0, 32)), to_slv(to_unsigned(1024 * i + 64 * j +0, 32)));
				WriteAsync(AXI4_Manager_Transaction(i), to_slv(to_unsigned(1024 * i + 64 * j +16, 32)), to_slv(to_unsigned(1024 * i + 64 * j +16, 32)));
			end loop;

			for j in 1 to 64 loop
				ReadAddressAsync(AXI4_Manager_Transaction(i), to_slv(to_unsigned(1024 * i + 64 * j +0, 32)));
				ReadAddressAsync(AXI4_Manager_Transaction(i), to_slv(to_unsigned(1024 * i + 64 * j +16, 32)));
			end loop;

			for j in 1 to 64 loop
				ReadCheckData(AXI4_Manager_Transaction(i), to_slv(to_unsigned(1024 * i + 64 * j +0, 32)));
				ReadCheckData(AXI4_Manager_Transaction(i), to_slv(to_unsigned(1024 * i + 64 * j +16, 32)));
			end loop;

			wait for 100 ns;
			WaitForBarrier(TestDone);
			wait;
		end process;
	end generate;

	ResponderProc : process
		variable Address  : std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
		variable Data     : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
		variable ReadData : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
		variable Available : boolean;
		variable ID        : natural;
	begin
		-------------------------------------
		-- Normal Rread and Wirte
		-------------------------------------
		wait until Reset = '0';
		SetModelOptions(AXI4_Subordinate_Transaction, WRITE_RESPONSE_VALID_TIME_OUT, 500) ;
		SetModelOptions(AXI4_Subordinate_Transaction, READ_DATA_VALID_TIME_OUT, 500) ;
		SetModelOptions(AXI4_Subordinate_Transaction, WRITE_ADDRESS_READY_TIME_OUT, 500) ;
		SetModelOptions(AXI4_Subordinate_Transaction, WRITE_DATA_READY_TIME_OUT, 500) ;
		SetModelOptions(AXI4_Subordinate_Transaction, WRITE_RESPONSE_READY_TIME_OUT, 500) ;
		SetModelOptions(AXI4_Subordinate_Transaction, READ_ADDRESS_READY_TIME_OUT, 500) ;
		SetModelOptions(AXI4_Subordinate_Transaction, READ_DATA_READY_TIME_OUT, 500) ;
		WaitForClock(AXI4_Subordinate_Transaction, 2);

		loop
			TryGetWriteAddress(AXI4_Subordinate_Transaction, Address, Available);
			if Available then
				GetAxi4Options(AXI4_Subordinate_Transaction, AWID, ID);
				SetAxi4Options(AXI4_Subordinate_Transaction, BID, ID);
				GetWriteData(AXI4_Subordinate_Transaction, Data);
				AffirmIfEqual(Address, Data, "Write Address Data check");
			end if;


			TryGetReadAddress(AXI4_Subordinate_Transaction, Address, Available);
			if Available then
				GetAxi4Options(AXI4_Subordinate_Transaction, ARID, ID);
				SetAxi4Options(AXI4_Subordinate_Transaction, RID, ID);
				SendReadData(AXI4_Subordinate_Transaction, Address);
			end if;
			WaitForClock(AXI4_Subordinate_Transaction);
		end loop;
		wait;
	end process;

end architecture;

configuration TC_SimpleReadWrite_multiID of AXI4_Mux_TestHarness is
	for Harness
		for TestControl_inst : TestControl
			use entity work.TestControl(SimpleReadWrite_multiID);
		end for;
	end for;
end configuration;
