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

architecture Initial of AXI4Lite_Register_TestController is

	signal TestDone   : integer_barrier := 1 ;
	signal ConfigDone : integer_barrier := 1 ;

	constant number : positive := 7;
	constant TCID      : AlertLogIDType :=  NewID("TestCtrl");

	shared variable IndexValue : integer := 0;
	shared variable SB         : osvvm.ScoreboardPkg_slv.ScoreboardPType ;

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
		SetAlertLogName("AXI4Lite_Register_initial") ;
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

		constant OFFSET_BITS : positive := 4;

		variable reg_index : integer;
		
		procedure ReadInit (
			RegName  : string;
			addr     : AXIAddressType;
			init_val : AXIDataType := 32x"00"
		) is
			variable idx : integer;
		begin
			idx := get_index(RegName, CONF);
			ReadInit(AxiMasterTransRec, ReadPort, idx, addr, init_val);
		end procedure;

	begin
		nReset <= '1';

		WaitForClock(AxiMasterTransRec, 2) ;

		-- CHECK INIT VALUES
		log("Verify all the registers");
		ReadInit("Reg1",        32x"00", 32x"12");
		ReadInit("Reg3",        32x"08", 32x"FF");
		ReadInit("Reg4_L",      32x"10", 32x"2");
		ReadInit("Reg4_H",      32x"14", 32x"A");
		ReadInit("IRQ_L_lhcor", 32x"20");
		ReadInit("IRQ_H_lhcor", 32x"24");
		ReadInit("IRQ_L_llcor", 32x"28");
		ReadInit("IRQ_H_llcor", 32x"2C");
		ReadInit("IRQ_L_lhcow", 32x"30");
		ReadInit("IRQ_H_lhcow", 32x"34");
		ReadInit("IRQ_L_llcow", 32x"38");
		ReadInit("IRQ_H_llcow", 32x"3C");
		ReadInit("IRQ_L_lvcor", 32x"40");
		ReadInit("IRQ_H_lvcor", 32x"44");
		ReadInit("IRQ_L_lvcow", 32x"48");
		ReadInit("IRQ_H_lvcow", 32x"4C");

		-- try to access reserved registers
		log("Trying to access reserved registers");
		ReadReserved(AxiMasterTransRec, 32x"0C");
		ReadReserved(AxiMasterTransRec, 32x"18");
		ReadReserved(AxiMasterTransRec, 32x"1C");
		ReadReserved(AxiMasterTransRec, 32x"50");

		-- reset and recheck values
		nReset <= '0';
		WaitForClock(AxiMasterTransRec);
		nReset <= '1';

		-- CHECK INIT VALUES
		log("Verify all the registers after reset");
		ReadInit("Reg1",        32x"00", 32x"12");
		ReadInit("Reg3",        32x"08", 32x"FF");
		ReadInit("Reg4_L",      32x"10", 32x"2");
		ReadInit("Reg4_H",      32x"14", 32x"A");
		ReadInit("IRQ_L_lhcor", 32x"20");
		ReadInit("IRQ_H_lhcor", 32x"24");
		ReadInit("IRQ_L_llcor", 32x"28");
		ReadInit("IRQ_H_llcor", 32x"2C");
		ReadInit("IRQ_L_lhcow", 32x"30");
		ReadInit("IRQ_H_lhcow", 32x"34");
		ReadInit("IRQ_L_llcow", 32x"38");
		ReadInit("IRQ_H_llcow", 32x"3C");
		ReadInit("IRQ_L_lvcor", 32x"40");
		ReadInit("IRQ_H_lvcor", 32x"44");
		ReadInit("IRQ_L_lvcow", 32x"48");
		ReadInit("IRQ_H_lvcow", 32x"4C");

		-- try to access reserved registers
		log("Trying to access reserved registers after reset");
		ReadReserved(AxiMasterTransRec, 32x"0C");
		ReadReserved(AxiMasterTransRec, 32x"18");
		ReadReserved(AxiMasterTransRec, 32x"1C");
		ReadReserved(AxiMasterTransRec, 32x"50");

		WaitForClock(AxiMasterTransRec);
	    WaitForBarrier(TestDone);
		wait;

	end process;

end architecture;

configuration AXI4Lite_Register_initial of AXI4Lite_Register_TestHarness is
	for sim
		for TestCtrl : AXI4Lite_Register_TestController
			use entity work.AXI4Lite_Register_TestController(Initial) ;
		end for ;
	end for;
end configuration ;
