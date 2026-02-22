-- =============================================================================
-- Authors:
-- Iqbal Asif (PLC2 Design GmbH)
-- Patrick Lehmann (PLC2 Design GmbH)
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

architecture AsyncReadWrite of AXI4Lite_Ocram_Adapter_TestController is
    signal TestDone : integer_barrier := 1;

begin

  ------------------------------------------------------------
  -- ControlProc
  -- Set up AlertLog and wait for end of test
  ------------------------------------------------------------
  ControlProc : process
		constant TestName : string := "TC_AsyncReadWrite";
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
    -- Normal Rread and Write
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

    -------------------------------------
    -- Async. Wirte
    -------------------------------------
    WriteAsync(MasterRec, 32x"0C", 32x"0C" );
    WriteAsync(MasterRec, 32x"10", 32x"CC" );
    WaitForClock(MasterRec, 1) ;

    -------------------------------------
    -- Async. Address and Wirte Data
    -------------------------------------
    WriteAddressAsync(MasterRec, 32x"1C");
    WaitForClock(MasterRec, 3) ;
    WriteDataAsync(MasterRec,x"0",32x"1C");
    WaitForClock(MasterRec, 3) ;

    WriteAddressAsync(MasterRec, 32x"2C");
    WaitForClock(MasterRec, 3) ;
    WriteDataAsync(MasterRec,x"0",32x"2C");
    WaitForClock(MasterRec, 3) ;

    WriteAddressAsync(MasterRec, 32x"3C");
    WaitForClock(MasterRec, 3) ;
    WriteDataAsync(MasterRec,x"0",32x"3C");
    WaitForClock(MasterRec, 3) ;

    WriteAddressAsync(MasterRec, 32x"4C");
    WaitForClock(MasterRec, 3) ;
    WriteDataAsync(MasterRec,x"0",32x"4C");
    WaitForClock(MasterRec, 3) ;

    -------------------------------------
    -- Async. Address and Read Data
    -------------------------------------
    ReadAddressAsync(MasterRec, 32x"04");
    ReadAddressAsync(MasterRec, 32x"08");
    ReadCheckData(MasterRec, 32x"F");
    ReadCheckData(MasterRec, 32x"FF");

    -------------------------------------
    -- Async. Data first and Address later
    -------------------------------------
    WriteDataAsync(MasterRec,x"0",32x"1C");
    WriteDataAsync(MasterRec,x"0",32x"2C");
    WriteDataAsync(MasterRec,x"0",32x"3C");
    WriteDataAsync(MasterRec,x"0",32x"4C");

    WaitForClock(MasterRec, 1) ;

    WriteAddressAsync(MasterRec, 32x"1C");
    WriteAddressAsync(MasterRec, 32x"2C");
    WriteAddressAsync(MasterRec, 32x"3C");
    WriteAddressAsync(MasterRec, 32x"4C");

    WaitForClock(MasterRec, 1) ;

    wait for 200 ns;
    WaitForBarrier(TestDone) ;
    wait;
  end process MasterProc ;

end architecture;

configuration TC_AsyncReadWrite of AXI4Lite_Ocram_Adapter_TestHarness is
  for sim
    for TestCtrl : AXI4Lite_Ocram_Adapter_TestController
      use entity work.AXI4Lite_Ocram_Adapter_TestController(AsyncReadWrite) ;
    end for ;
  end for ;
end configuration ;
