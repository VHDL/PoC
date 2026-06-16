-- =============================================================================
-- Authors:
--   Adrian Weiland (PLC2 Design GmbH)
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

architecture InitMemory of AXI4Lite_OCRAM_Adapter_TestController is
begin
	ControlProc : process
		constant ProcID  : AlertLogIDType := NewID("ControlProc", TCID);
	begin
		-- Initialization of test
		SetAlertLogName("TC_InitMemory") ;
		SetLogEnable(PASSED, TRUE);
		SetLogEnable(INFO,   TRUE);
		SetLogEnable(DEBUG,  TRUE);

		-- Wait for testbench initialization
		wait for 0 ns ;
		SetTranscriptMirror(TRUE) ;

		-- Wait for Design Reset
		wait until Reset = '0' ;
		ClearAlerts ;

		WaitForBarrier(TestDone, TIMEOUT);
		EndOfTestReports(ReportAll => TRUE, Timeout => now >= TIMEOUT);
		std.env.finish;
		wait;
	end process;

	MasterProc : process
		constant ProcID  : AlertLogIDType := NewID("MasterProc", TCID);

		constant NUM_ITERATIONS : positive := 1000;

		constant MEMORY_SIZE         : positive := 2**OCRAM_ADDRESS_BITS;
		constant NUM_INCREMENT_LINES : positive := 16;
		constant NUM_DEADBEEF_LINES  : positive := 4;

		variable CheckPattern : std_logic_vector(OCRAM_DATA_BITS - 1 downto 0);
		variable ReadData     : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
		variable addr_mem_i   : natural;
		variable addr         : unsigned(31 downto 0);
		variable data         : std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
		variable RV           : RandomPType;
	begin
		wait until Reset = '0' ;
		WaitForClock(MasterRec, 2);

		-- Read from preloaded memory through transaction record and external name
		addr := (others => '0');
		for i in 0 to MEMORY_SIZE - 1 loop
			if i < NUM_INCREMENT_LINES then                          -- Incremental lines
				CheckPattern := std_logic_vector(resize(to_unsigned(i, OCRAM_DATA_BITS) * x"01010101", OCRAM_DATA_BITS));
			elsif i < NUM_INCREMENT_LINES + NUM_DEADBEEF_LINES then  -- DEADBEEF lines
				CheckPattern := 32x"DEADBEEF";
			else
				CheckPattern := 32x"0";                                -- Zero lines
			end if;

			AffirmIfEqual(ProcID, ram(i), CheckPattern);                 -- external name
			ReadCheck(MasterRec, std_logic_vector(addr), CheckPattern);  -- transaction record
			addr := addr + 4;
		end loop;

		-- Write through record, read via ext. name
		for i in 0 to NUM_ITERATIONS - 1 loop
			addr_mem_i := RV.RandInt(0, MEMORY_SIZE - 1);
			addr       := to_unsigned(addr_mem_i * 4, addr'length);
			data       := RV.RandSlv(AXI_DATA_WIDTH);
			Write(MasterRec, std_logic_vector(addr), data);
			AffirmIfEqual(ProcID, ram(addr_mem_i), data);
		end loop;

		-- Write through ext. name, read via record
		for i in 0 to NUM_ITERATIONS - 1 loop
			addr_mem_i := RV.RandInt(0, MEMORY_SIZE - 1);
			addr       := to_unsigned(addr_mem_i * 4, addr'length);
			data       := RV.RandSlv(AXI_DATA_WIDTH);
			ram(addr_mem_i) <= force data;  -- forced to avoid 'X' because of multiple drivers
			ReadCheck(MasterRec, std_logic_vector(addr), data);
		end loop;

		wait for 100 ns;
		WaitForBarrier(TestDone) ;
		wait;
	end process;
end architecture;

configuration TC_InitMemory of AXI4Lite_Ocram_Adapter_TestHarness is
	for sim
		for TestCtrl : AXI4Lite_Ocram_Adapter_TestController
			use entity work.AXI4Lite_Ocram_Adapter_TestController(InitMemory);
		end for;
	end for;
end configuration;
