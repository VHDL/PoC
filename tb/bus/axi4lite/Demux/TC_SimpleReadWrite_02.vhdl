-- =============================================================================
-- Authors:
--  Iqbal Asif (PLC2 Design GmbH)
--  Patrick Lehmann (PLC2 Design GmbH)
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
use     PoC.config.all;
use     PoC.vectors.all;
use     PoC.strings.all;
use     PoC.utils.all;


architecture SimpleReadWrite_02 of AXI4Lite_Demux_TestController is
	signal TestDone : integer_barrier := 1;

begin

	------------------------------------------------------------
	-- ControlProc
	-- Set up AlertLog and wait for end of test
	------------------------------------------------------------
	ControlProc : process
		constant TestName : string := "TC_SimpleReadWrite_02";
	begin
		-- Initialization of test
		SetTestName(TestName);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		SetLogEnable(PASSED, FALSE);  -- Enable PASSED logs
		SetLogEnable(INFO, TRUE);    -- Enable INFO logs

	-- Wait for testbench initialization

	-- Wait for Design Reset
	wait until nReset = '1' ;
	ClearAlerts ;

		-- Wait for test to finish
		WaitForBarrier(TestDone) ;
		AlertIf(now >= 10 ms, "Test finished due to timeout") ;
--    AlertIf(GetAffirmCount < 100, "Test is not Self-Checking");

		wait for 1 us;

		EndOfTestReports(ReportAll => TRUE);
		TranscriptClose;
		std.env.stop;
		wait;
	end process ControlProc ;

	------------------------------------------------------------
	-- ManagerProc
	-- Generate transactions for AxiMaster
	------------------------------------------------------------
	ManagerProc : process
		variable Address  : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
		variable Data     : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
		variable ReadData : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

	begin
		-------------------------------------
		-- Normal Rread and Wirte
		-------------------------------------
		wait until nReset = '1' ;
		WaitForClock(ManagerRec, 2);

		Write(ManagerRec, 32x"0000", 64x"F" );
		WaitForClock(ManagerRec, 2);

		for i in 0 to 63 loop
			Address(31 downto 0) := to_slv(to_unsigned(i + 64, 24)) & 8X"10";
			Data := to_slv(to_unsigned(2048,AXI_DATA_WIDTH));
			Write(ManagerRec, Address, Data);
		end loop;

		wait for 100 ns;
		WaitForBarrier(TestDone) ;
		wait;
	end process ManagerProc ;

	------------------------------------------------------------
	-- ResponderProc_01
	-- Generate transactions for AxiMaster
	------------------------------------------------------------
	ResponderProc_01 : process
		variable Address  : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
		variable Data     : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
		variable ReadData : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

	begin
		-------------------------------------
		-- Normal Rread and Wirte
		-------------------------------------
		wait until nReset = '1' ;
		WaitForClock(SubordinateRec(0), 2);
		GetWrite(SubordinateRec(0), Address, Data) ;

		wait for 100 ns;
		WaitForBarrier(TestDone) ;
		wait;
	end process ResponderProc_01 ;

	------------------------------------------------------------
	-- ResponderProc_02
	-- Generate transactions for AxiMaster
	------------------------------------------------------------
	ResponderProc_02 : process
		variable Address  : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
		variable Data     : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
		variable ReadData : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

	begin
		-------------------------------------
		-- Normal Rread and Wirte
		-------------------------------------
		wait until nReset = '1' ;

		for i in 0 to 63 loop
			WaitForClock(SubordinateRec(1), 2);
			-- Write and Read with ByteAddr = 0, 4 Bytes
			GetWrite(SubordinateRec(1), Address, Data) ;
		end loop;

		wait for 100 ns;
		WaitForBarrier(TestDone) ;
		wait;
	end process ResponderProc_02 ;

end architecture ;

configuration TC_SimpleReadWrite_02 of AXI4Lite_Demux_TestHarness is
	for sim
		for TestCtrl : AXI4Lite_Demux_TestController
			use entity work.AXI4Lite_Demux_TestController(SimpleReadWrite_02) ;
		end for ;
	end for ;
end configuration ;
