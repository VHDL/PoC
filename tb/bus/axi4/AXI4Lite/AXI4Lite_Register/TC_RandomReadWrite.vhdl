-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:
--                  Iqbal Asif (PLC2 Design GmbH)
--                  Patrick Lehmann (PLC2 Design GmbH)
--                  Stefan Unrein (PLC2 Design GmbH)
--
-- Entity:          TC_RandomReadWrite
--
-- Description:
-- -------------------------------------
-- Test-Case Random-Read-Write
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

architecture RandomReadWrite of AXI4Lite_Register_TestController is
  constant Timeout : time := 100 ms;

	constant number : positive := 7;

	signal TestDone   : integer_barrier := 1;
	signal ConfigDone : integer_barrier := 1;

	shared variable IndexValue : integer := 0;
	shared variable SB         : osvvm.ScoreboardPkg_slv.ScoreboardPType;

begin

	------------------------------------------------------------
	-- ControlProc
	--   Set up AlertLog and wait for end of test
	------------------------------------------------------------
	ControlProc : process
	begin
		-- Initialization of test
		SetAlertLogName("TC_RandomReadWrite");
		SetLogEnable(PASSED, TRUE); -- Enable PASSED logs
		SetLogEnable(INFO, TRUE);   -- Enable INFO logs

		-- Wait for testbench initialization
		wait for 0 ns;
		SetTranscriptMirror(TRUE);

		-- Wait for Design Reset
		wait until nReset = '1';
		ClearAlerts;

		-- Wait for test to finish
		WaitForBarrier(TestDone, Timeout);
		AlertIf(now >= Timeout, "Test finished due to timeout");
		--    AlertIf(GetAffirmCount < 100, "Test is not Self-Checking");

		print("");
		ReportAlerts;
		print("");
		std.env.stop;
		wait;
	end process ControlProc;

	ReadWriteProc : process
		variable RV    : RandomPType;
		variable value : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0) := 32x"001";

	begin
		RV.InitSeed(RV'instance_name);
		wait until nReset = '1';

		for I in 0 to number - 1 loop
			IndexValue := RV.RandInt(0, 0);
			value      := RV.RandSlv(0, 255, 32);
			wait until rising_edge (Clk);
			SB.Push("IRQ(" & integer'image(IndexValue) & ")", value);
			WritePort (get_index("IRQ(" & integer'image(IndexValue) & ")", config)) <= value;
			wait until rising_edge (Clk);
			WritePort (get_index("IRQ(" & integer'image(IndexValue) & ")", config)) <= (others => '0');
		end loop;

		--		WaitForBarrier(ConfigDone) ;

		WaitForBarrier(TestDone);
	end process;
	------------------------------------------------------------
	-- AxiTransmitterProc
	--   Generate transactions for AxiTransmitter
	------------------------------------------------------------
	AxiMasterProc : process
		variable Data : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
		variable Addr : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0) := (others => '0');

	begin
		wait until nReset = '1';

		wait until Irq = '1';

		--			WaitForBarrier(ConfigDone) ;

		wait until rising_edge (Clk);
		Write(AxiMasterTransRec, x"0000_0010", x"FFFF_FFFF");

		Read(AxiMasterTransRec, x"0000_0868", data);
		Addr := std_logic_vector((get_Address("IRQ(" & integer'image(IndexValue) & ")", config)));
		Read(AxiMasterTransRec, Addr, data);
		SB.Check("IRQ(" & integer'image(IndexValue) & ")", data);

		wait for 10 ns;

		WaitForBarrier(TestDone);
		wait;
	end process AxiMasterProc;

end architecture;

configuration TC_RandomReadWrite of AXI4Lite_Register_TestHarness is
	for sim
		for TestCtrl : AXI4Lite_Register_TestController
			use entity work.AXI4Lite_Register_TestController(RandomReadWrite);
		end for;
	end for;
end configuration;
