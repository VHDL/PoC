-- =============================================================================
-- Authors:
--  Iqbal Asif (PLC2 Design GmbH)
--  Patrick Lehmann (PLC2 Design GmbH)
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

architecture SimpleReadWrite of TestControl is
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

		SetLogEnable(PASSED, TRUE); -- Enable PASSED logs
		SetLogEnable(INFO, TRUE);    -- Enable INFO logs

		-- Wait for testbench initialization

		-- Wait for Design Reset
		wait until Reset = '0';
		ClearAlerts;

		-- Wait for test to finish
		WaitForBarrier(TestDone);
		AlertIf(now >= 10 ms, "Test finished due to timeout");
		--    AlertIf(GetAffirmCount < 100, "Test is not Self-Checking");

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
			WaitForClock(AXI4_Manager_Transaction(i), 2);

			for j in 0 to 10 loop
				Write(AXI4_Manager_Transaction(i), 32x"1000", to_slv(to_unsigned(j, 16) & 16x"1234"));
				Write(AXI4_Manager_Transaction(i), 32x"2000", to_slv(to_unsigned(j, 16) & 16x"5678"));

				Read(AXI4_Manager_Transaction(i), 32x"3000", Data);
				Read(AXI4_Manager_Transaction(i), 32x"4000", Data);
			end loop;
			WaitForClock(AXI4_Manager_Transaction(i), 2);

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
	begin
		-------------------------------------
		-- Normal Rread and Wirte
		-------------------------------------
		wait until Reset = '0';
		WaitForClock(AXI4_Subordinate_Transaction, 2);

		loop
			TryGetWriteAddress(AXI4_Subordinate_Transaction, Address, Available);
			if Available then
				GetWriteData(AXI4_Subordinate_Transaction, Data);
			end if;


			TryGetReadAddress(AXI4_Subordinate_Transaction, Address, Available);
			if Available then
				SendReadData(AXI4_Subordinate_Transaction, X"1111_1111");
			end if;
			WaitForClock(AXI4_Subordinate_Transaction);
		end loop;
		wait;
	end process;

end architecture;

configuration TC_SimpleReadWrite of AXI4_Mux_TestHarness is
	for Harness
		for TestControl_inst : TestControl
			use entity work.TestControl(SimpleReadWrite);
		end for;
	end for;
end configuration;
