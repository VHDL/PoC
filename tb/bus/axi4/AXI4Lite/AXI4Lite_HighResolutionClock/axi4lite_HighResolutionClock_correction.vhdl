-- =============================================================================
-- Authors:
--   Adrian Weiland
--
-- Testcase: Test functionality of the correction counter.
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

architecture correction of axi4lite_HighResolutionClock_tc is

	signal TestDone : integer_barrier := 1;

begin
	-- Testbench control process
	ControlProc : process
		constant TIMEOUT : time := 1 ms;
	begin
		-- Initialization of test
		SetTestName("axi4lite_HighResolutionClock_correction");
		SetLogEnable(PASSED, TRUE);  --Enable PASSED Logs
		SetLogEnable(INFO, TRUE);    --Enable INFO  Logs

		-- Wait for testbench Initialization
		wait for 0 ns;
		wait for 0 ns;
		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		-- wait for design reset
		wait until Reset = '0';
		ClearAlerts;

		WaitForBarrier(TestDone, TIMEOUT);
		EndOfTestReports(ReportAll => TRUE, Timeout => now >= TIMEOUT);
		std.env.finish;
		wait;
	end process ControlProc;

	-- Generate transaction for AXI manager
	ManagerProc : process
		procedure LoadNanoseconds (
			signal   manager             : inout AddressBusRecType;
			constant Nanoseconds_to_load : natural
		) is 
			variable ns_value_slv : std_logic_vector(63 downto 0) := to_slv(Nanoseconds_to_load, 64);
		begin
			log("");
			log("Writing Nanoseconds to register");
			Write(AXI_Manager, Reg_Nanoseconds_to_load_lower, ns_value_slv(31 downto 0));
			Write(AXI_Manager, Reg_Nanoseconds_to_load_upper, ns_value_slv(63 downto 32));
		end procedure;

		procedure CheckCorrection (
			signal   manager              : inout AddressBusRecType;
			constant config               : in std_logic_vector(1 downto 0);
			constant correction_threshold : natural;
			constant correction_time      : time
		) is
			variable ReadData : AXIDataType;
			variable time_now_a           : time;
			variable time_now_b           : time;
			variable time_now_delta       : time;
			variable time_now_delta_val   : natural;
			variable time_ns_a_l          : natural;
			variable time_ns_b_l          : natural;
			variable time_ns_delta        : natural;
			variable delta_expected       : natural;
		begin
			log("");
			log("Setting defined config");
			Write(AXI_Manager, Reg_Config_reg, config & to_slv(correction_threshold, 30));
			WaitForClock(AXI_Manager, 8);
			ReadCheck(AXI_Manager, Reg_Config_reg, config & to_slv(correction_threshold, 30));

			Read(AXI_Manager, Reg_Nanoseconds_lower, ReadData);
			time_now_a  := now;
			time_ns_a_l := to_integer(unsigned(ReadData));
			
			wait for correction_time;
			
			Read(AXI_Manager, Reg_Nanoseconds_lower, ReadData);
			time_now_b         := now;
			time_now_delta     := time_now_b - time_now_a;
			time_now_delta_val := time_now_delta / 1000 ps;
			
			case config is
				when "11" =>    -- increment
					if correction_threshold = 0 then
						delta_expected := time_now_delta_val;
					else
						delta_expected := time_now_delta_val + time_now_delta_val / (INCREMENT_FULL * correction_threshold);
					end if;
				when "10" =>    -- decrement
					if correction_threshold = 0 then
						delta_expected := time_now_delta_val;
					else
						delta_expected := time_now_delta_val - time_now_delta_val / (INCREMENT_FULL * correction_threshold);
					end if;
				when others =>  -- no correction
					delta_expected := time_now_delta_val;
			end case;

			time_ns_b_l        := to_integer(unsigned(ReadData));
			time_ns_delta      := time_ns_b_l - time_ns_a_l;
			AffirmIf (  -- check if delta is in range
				time_ns_delta = delta_expected or (time_ns_delta = delta_expected + 1) or (time_ns_delta = delta_expected - 1),
				"Delta: " & to_string(time_ns_delta) & " (" & to_string(delta_expected - 1) & " to " & to_string(delta_expected + 1) & ")",
				"Delta: /= " & to_string(delta_expected - 1) & " to " & to_string(delta_expected + 1) & " (expected)"
			);
		end procedure;
			
	begin
		wait until Reset = '0';
		WaitForClock(AXI_Manager, 2);

		LoadNanoseconds(AXI_Manager, 1000);
		CheckCorrection(AXI_Manager, "11", 10, 600 ns);
		CheckCorrection(AXI_Manager, "10", 10, 600 ns);
		CheckCorrection(AXI_Manager, "01", 10, 600 ns);  -- enable not set
		CheckCorrection(AXI_Manager, "11", 53, 600 ns);
		LoadNanoseconds(AXI_Manager, 1764);
		CheckCorrection(AXI_Manager, "11", 1000, 600 ns);
		CheckCorrection(AXI_Manager, "11", 2, 477 ns);
		CheckCorrection(AXI_Manager, "10", 2, 352 ns);
		CheckCorrection(AXI_Manager, "10", 1, 352 ns);
		CheckCorrection(AXI_Manager, "11", 0, 444 ns);

		WaitForClock(AXI_Manager);
		WaitForBarrier(TestDone);
		wait;
	end process ManagerProc;

end architecture;

configuration axi4lite_HighResolutionClock_correction of axi4lite_HighResolutionClock_th is
	for TestHarness
		for TestCtrl : axi4lite_HighResolutionClock_tc
			use entity work.axi4lite_HighResolutionClock_tc(correction);
		end for;
	end for;
end configuration;
