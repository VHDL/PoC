-- =============================================================================
-- Authors:
--   Adrian Weiland
--
-- Testcase: Load times into register.
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

architecture load_times of axi4lite_HighResolutionClock_tc is

	signal TestDone : integer_barrier := 1;

begin
	-- Testbench control process
	ControlProc : process
		constant TIMEOUT : time := 1 ms;
	begin
		-- Initialization of test
		SetTestName("axi4lite_HighResolutionClock_load_times");
		-- SetLogEnable(PASSED, TRUE);  --Enable PASSED Logs
		-- SetLogEnable(INFO, TRUE);    --Enable INFO  Logs

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
	end process;

	-- Generate transaction for AXI manager
	ManagerProc : process
		variable ReadData : AXIDataType;

		variable comp_time     : time    := 200 ns;
		variable comp_time_val : natural := 200;

		variable Nanoseconds_to_load     : std_logic_vector(63 downto 0) := to_slv(1000, 64);
		variable Nanosecond_value        : natural;
		variable Nanoseconds_updated_min : natural := to_integer(unsigned(Nanoseconds_to_load)) + comp_time_val;
		variable Nanoseconds_updated_max : natural := to_integer(unsigned(Nanoseconds_to_load)) + comp_time_val + 100;
		-- each Write need 8 CC until the value is available in the register. Therefore the updated value will be:
		-- Nanoseconds_updated_min + 4 * 8 but it can differ depending on other operations in the network (in a real scenario with more op.)
		variable Datetime_to_load : T_CLOCK_DATETIME := (
														secondsResolution => to_unsigned(0, 32), 
														seconds           => to_unsigned(42, 6), 
														minutes           => to_unsigned(7, 6),  
														hours             => to_unsigned(16, 5), 
														day               => to_unsigned(13, 5), 
														month             => to_unsigned(1, 4),  
														year              => to_unsigned(2025, 13)
													);
		variable Datetime_to_load_slv : std_logic_vector(63 downto 0) := datetime_to_slv(Datetime_to_load);
		
		procedure LoadNanoseconds (
			signal   manager             : inout AddressBusRecType;
			constant Nanoseconds_to_load : natural;
			constant waitTime            : time
		) is 
			variable ReadData : AXIDataType;
			variable ns_value_slv : std_logic_vector(63 downto 0) := to_slv(Nanoseconds_to_load, 64);
			variable time_now_a     : time;
			variable time_now_b     : time;
			variable time_now_delta : time;
			variable time_total     : natural;
			variable time_ns_a_l    : natural;
			variable time_ns_b_l    : natural;
			variable time_ns_delta  : natural;
			variable delta_expected : natural;
		begin
			log("");
			log("Writing Nanoseconds to register");
			Write(AXI_Manager, Reg_Nanoseconds_to_load_lower, ns_value_slv(31 downto 0));
			time_now_a  := now;
			time_ns_a_l := to_integer(unsigned(ReadData));
			Write(AXI_Manager, Reg_Nanoseconds_to_load_upper, ns_value_slv(63 downto 32));

			wait for waitTime;

			Read(AXI_Manager, Reg_Nanoseconds_lower, ReadData);
			time_now_b  := now;
			time_ns_b_l := to_integer(unsigned(ReadData));
			time_now_delta := time_now_b - time_now_a;
			time_total     := Nanoseconds_to_load + time_now_delta / 1000 ps;

			time_ns_b_l    := to_integer(unsigned(ReadData));
			time_ns_delta  := time_ns_b_l - time_ns_a_l;
			AffirmIfEqual(time_ns_delta, time_ns_b_l);
			ReadCheck(AXI_Manager, Reg_Nanoseconds_upper, std_logic_vector(ns_value_slv(63 downto 32)));   -- value should not have changed
		end procedure;
		
		procedure LoadDatetime (
			signal manager    : inout AddressBusRecType;
			constant s        : natural;  -- second
			constant m        : natural;  -- minute
			constant h        : natural;  -- hour
			constant d        : natural;  -- day
			constant mo       : natural;  -- month
			constant y        : natural;  -- year
			constant waitTime : time
		) is
			variable ReadData : AXIDataType;
			variable Datetime_to_load : T_CLOCK_DATETIME := (
														secondsResolution => to_unsigned(0, 32),  -- gets written to different register
														seconds           => to_unsigned(s, 6), 
														minutes           => to_unsigned(m, 6),  
														hours             => to_unsigned(h, 5), 
														day               => to_unsigned(d, 5), 
														month             => to_unsigned(mo, 4),  
														year              => to_unsigned(y, 13)
													);
			variable Datetime_to_load_slv : std_logic_vector(63 downto 0) := datetime_to_slv(Datetime_to_load);
			variable time_now_a : time;
		begin
			log("");
			log("Writing Datetime to register");
			Write(AXI_Manager, Reg_Datetime_to_load_HMS, Datetime_to_load_slv(31 downto 0));
			Write(AXI_Manager, Reg_Datetime_to_load_Ymd, Datetime_to_load_slv(63 downto 32));

			wait for waitTime;

			ReadCheck(AXI_Manager, Reg_Time_HMS, std_logic_vector(Datetime_to_load_slv(31 downto 0)));   -- value should not have changed
			ReadCheck(AXI_Manager, Reg_Date_Ymd, std_logic_vector(Datetime_to_load_slv(63 downto 32)));  -- value should not have changed

		end procedure;
	begin
		wait until Reset = '0';
		WaitForClock(AXI_Manager, 2);

		log("Writing load values to register");
		LoadNanoseconds(AXI_Manager, 1000, 400 ns);
		LoadDatetime(AXI_Manager, 42, 7, 16, 13, 1, 2025, 500 ns);

		WaitForClock(AXI_Manager);
		WaitForBarrier(TestDone);
		wait;
	end process ManagerProc;

end architecture;

configuration axi4lite_HighResolutionClock_load_times of axi4lite_HighResolutionClock_th is
	for TestHarness
		for TestCtrl : axi4lite_HighResolutionClock_tc
			use entity work.axi4lite_HighResolutionClock_tc(load_times);
		end for;
	end for;
end configuration;
