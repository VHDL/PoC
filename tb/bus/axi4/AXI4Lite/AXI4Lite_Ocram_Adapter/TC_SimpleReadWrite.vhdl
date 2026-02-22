-- =============================================================================
-- Authors:
--   Iqbal Asif (PLC2 Design GmbH)
--   Patrick Lehmann (PLC2 Design GmbH)
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

architecture SimpleReadWrite of AXI4Lite_Ocram_Adapter_TestController is
    signal TestDone : integer_barrier := 1;

begin

  ------------------------------------------------------------
  -- ControlProc
  -- Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
		constant TestName : string := "TC_SimpleReadWrite";
		constant TIMEOUT  : time   := 30 ms;
  begin
		-- Initialization of test
		SetAlertLogName(TestName) ;
    -- SetLogEnable(PASSED, TRUE) ;    -- Enable PASSED logs
    -- SetLogEnable(INFO, TRUE) ;    -- Enable INFO logs

    -- Wait for testbench initialization
    wait for 0 ns ;
    SetTranscriptMirror(TRUE) ;

    -- Wait for Design Reset
    wait until nReset = '1' ;
    ClearAlerts ;

    WaitForBarrier(TestDone, TIMEOUT);
		EndOfTestReports(ReportAll => TRUE, Timeout => now >= TIMEOUT);
		std.env.finish;
		wait;
  end process ControlProc ;

  ------------------------------------------------------------
  -- MasterProc
  -- Generate transactions for AxiMaster
  ------------------------------------------------------------
    MasterProc : process
    variable Address  : std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
    variable Data     : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
    variable ReadData : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);

  begin
    -------------------------------------
    -- Normal Rread and Wirte
    -------------------------------------
    wait until nReset = '1' ;
    WaitForClock(MasterRec, 2);

    Write(MasterRec, 32x"04", 32x"F" );
    WaitForClock(MasterRec, 2);

    Write(MasterRec, 32x"08", 32x"FF" );
    WaitForClock(MasterRec, 2);

    Write(MasterRec, 32x"14", 32x"AFAF" );
    WaitForClock(MasterRec, 2);

    Read(MasterRec, 32x"14", ReadData );
    WaitForClock(MasterRec, 2) ;

    wait for 100 ns;
    WaitForBarrier(TestDone) ;
    wait;
  end process MasterProc ;
end architecture ;

configuration TC_SimpleReadWrite of AXI4Lite_Ocram_Adapter_TestHarness is
  for sim
    for TestCtrl : AXI4Lite_Ocram_Adapter_TestController
      use entity work.AXI4Lite_Ocram_Adapter_TestController(SimpleReadWrite) ;
    end for ;
  end for ;
end configuration ;
