-- =============================================================================
-- Authors:
--   Adrian Weiland (PLC2 Design GmbH)
--
-- Testcase: Initial
--
-- Description:
-- -------------------------------------
-- Test-Case Initial
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

architecture Initial of AXI4Lite_Register_TestController is

	signal TestDone   : integer_barrier := 1;
	signal ConfigDone : integer_barrier := 1;

	constant TCID     : AlertLogIDType :=  NewID("TestCtrl");

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
		SetAlertLogName("AXI4Lite_Register_Initial");
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
	end process ControlProc;

	ManagerProc : process

		constant OFFSET_BITS : positive := 4;

		procedure ReadInit (
			RegName  : string;
			addr     : AXIAddressType;
			init_val : AXIDataType := 32x"00"
		) is
			variable idx : integer;
		begin
			idx := get_index(RegName, CONFIG);
			ReadInit(AxiMasterTransRec, ReadPort, idx, addr, init_val);
		end procedure;

	begin
		Reset <= '0';

		WaitForClock(AxiMasterTransRec, 2);

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
		Reset <= '1';
		WaitForClock(AxiMasterTransRec);
		Reset <= '0';

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

configuration AXI4Lite_Register_Initial of AXI4Lite_Register_TestHarness is
	for sim
		for TestCtrl : AXI4Lite_Register_TestController
			use entity work.AXI4Lite_Register_TestController(Initial);
		end for;
	end for;
end configuration;
