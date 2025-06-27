-- =============================================================================
-- Authors:
-- Adrian Weiland
--
-- License:
-- =============================================================================
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited.
-- Proprietary and confidential
-- =============================================================================

architecture ReadWrite of AXI4Lite_Register_TestController is

	signal TestDone   : integer_barrier := 1 ;
	signal ConfigDone : integer_barrier := 1 ;

	constant number : positive := 7;
	constant TCID      : AlertLogIDType :=  NewID("TestCtrl");

	shared variable IndexValue : integer := 0;
	shared variable SB  : osvvm.ScoreboardPkg_slv.ScoreboardPType ;

begin

  ------------------------------------------------------------
  -- ControlProc
  --   Set up AlertLog and wait for end of test
  ------------------------------------------------------------
	ControlProc : process
		constant ProcID  : AlertLogIDType := NewID("ControlProc", TCID);
		constant TIMEOUT : time := 10 ms;
	begin
		-- Initialization of test
		SetAlertLogName("AXI4Lite_Register_ReadWrite") ;
		SetLogEnable(PASSED,                   FALSE);
		SetLogEnable(INFO,                     FALSE);
		SetLogEnable(osvvm.AlertLogPkg.DEBUG,  FALSE);
		wait for 0 ns; wait for 0 ns;

		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		ClearAlerts;

		WaitForBarrier(TestDone, TIMEOUT);
		EndOfTestReports(ReportAll => TRUE, Timeout => now >= TIMEOUT);
		std.env.finish;
		wait;
	end process ControlProc ;

	ManagerProc : process

		procedure WriteCheck (
			RegName   : string;
			addr      : AXIAddressType;
			write_val : AXIDataType
		) is
			variable idx : integer;
		begin
			idx := get_index(RegName, CONF);
			WriteCheck(AxiMasterTransRec, ReadPort, WritePort, idx, addr, write_val);
		end procedure;

	begin
		nReset <= '1';

		WaitForClock(AxiMasterTransRec, 2) ;

		-- check writable registers
		log("Verify all the registers");
		WriteCheck("Reg3",   32x"08", 32x"02");
		WriteCheck("Reg4_L", 32x"10", 32x"FF");
		WriteCheck("Reg4_H", 32x"14", 32x"2A");

		-- try to access reserved registers
		log("Trying to write reserved registers");
		WriteReserved(AxiMasterTransRec, 32x"0C");
		WriteReserved(AxiMasterTransRec, 32x"18");
		WriteReserved(AxiMasterTransRec, 32x"1C");
		WriteReserved(AxiMasterTransRec, 32x"50");

		WaitForClock(AxiMasterTransRec);
	    WaitForBarrier(TestDone);
		wait;

	end process;

end architecture;

configuration AXI4Lite_Register_ReadWrite of AXI4Lite_Register_TestHarness is
	for sim
		for TestCtrl : AXI4Lite_Register_TestController
			use entity work.AXI4Lite_Register_TestController(ReadWrite) ;
		end for ;
	end for;
end configuration ;
