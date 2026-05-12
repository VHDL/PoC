-- ============================================================================
-- Author(s)
--   Adrian Weiland
--
-- Test Case: Test functionality of the correction counter.
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

architecture load of clock_HighResolution_tc is

	signal TestDone : integer_barrier := 1;

begin
	-- Testbench control process
	ControlProc : process
		constant TIMEOUT : time := 1100 ms;
	begin
		-- Initialization of test
		SetTestName("clock_HighResolution_load");
		SetLogEnable(PASSED, FALSE);  --Enable PASSED Logs
		SetLogEnable(INFO, FALSE);    --Enable INFO  Logs

		-- Wait for testbench Initialization
		wait for 0 ns;
		wait for 0 ns;
		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		-- wait for design reset
		wait until Reset = '0';
		ClearAlerts;

		-- wait for test to finish
		WaitForBarrier(TestDone, TIMEOUT);
		AlertIf(now >= TIMEOUT, "Test finished due to timeout");
		--AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

		print("");
		EndOfTestReports;
		TranscriptClose;
		std.env.stop;
		wait;
	end process ControlProc;

	-- Generate transaction for AXI manager
	ManagerProc : process
		
		procedure LoadNanoseconds (
			signal   manager       : inout AddressBusRecType;
			constant ns_load_value : natural;
			constant waitTime      : time
		) is 
			variable ns_value_slv     : std_logic_vector(63 downto 0) := to_slv(ns_load_value, 64);
			variable time_now_a       : time;
			variable time_now_b       : time;
			variable time_elapsed     : time;
			variable time_elapsed_nat : natural;
			variable ns_elapsed       : natural;
		begin
			Nanoseconds_to_load <= unsigned(ns_value_slv);
			Load_nanoseconds <= '1';
			WaitForClock(AXI_Manager, 1);
			Load_nanoseconds <= '0';
			time_now_a := now;

			wait for waitTime;

			ns_elapsed   := to_integer(Nanoseconds - unsigned(ns_value_slv) + 1);  -- + 1 because of WaitForClock
			time_now_b   := now;
			time_elapsed := time_now_b - time_now_a;
			time_elapsed_nat := time_elapsed / 1 ns;
			AffirmIfEqual(ns_elapsed, time_elapsed_nat);
		end procedure;
		
		procedure LoadDatetime (
			signal   manager  : inout AddressBusRecType;
			constant s        : natural;  -- second
			constant m        : natural;  -- minute
			constant h        : natural;  -- hour
			constant d        : natural;  -- day
			constant mo       : natural;  -- month
			constant y        : natural;  -- year
			constant waitTime : time
		) is
			variable Datetime_to_load_i : T_CLOCK_DATETIME := (
				secondsResolution => to_unsigned(0, 32),
				seconds           => to_unsigned(s, 6), 
				minutes           => to_unsigned(m, 6),  
				hours             => to_unsigned(h, 5), 
				day               => to_unsigned(d, 5), 
				month             => to_unsigned(mo, 4),  
				year              => to_unsigned(y, 13)
			);
			variable Datetime_read : T_CLOCK_DATETIME := (others => (others => '0'));
			variable Datetime_to_load_slv : std_logic_vector(63 downto 0) := datetime_to_slv(Datetime_to_load_i);
			variable time_now_a : time;
			variable time_now_b : time;
		begin
			Datetime_to_load <= Datetime_to_load_i;
			Load_datetime <= '1';
			WaitForClock(AXI_Manager, 1);
			Load_datetime <= '0';
			time_now_a := now;

			wait for waitTime;

			time_now_b    := now;
			Datetime_read := Datetime;

			AffirmIfEqual(Datetime_read.secondsResolution, Datetime_to_load.secondsResolution);
			AffirmIfEqual(Datetime_read.seconds, Datetime_to_load.seconds);
			AffirmIfEqual(Datetime_read.minutes, Datetime_to_load.minutes);
			AffirmIfEqual(Datetime_read.hours, Datetime_to_load.hours);
			AffirmIfEqual(Datetime_read.day, Datetime_to_load.day);
			AffirmIfEqual(Datetime_read.month, Datetime_to_load.month);
			AffirmIfEqual(Datetime_read.year, Datetime_to_load.year);
		end procedure;

		variable RV : RandomPType;
		variable randTime : time := 0 ns;
		type T_RandTimes is record
			randNs    : positive;
			randT     : positive;
			randSec   : positive;
			randMin   : positive;
			randHour  : positive;
			randDay   : positive;
			randMonth : positive;
			randYear  : positive;
		end record;
		variable RandTimes : T_RandTimes := (others => 1);

	begin
		RV.InitSeed(RV'instance_name);

		Load_nanoseconds <= '0';
		Load_datetime    <= '0';
		wait until Reset = '0';
		WaitForClock(AXI_Manager, 2);
		
		log("Checking nanosecond load");
		for i in 0 to 5 loop
			randTime         := RV.RandTime(1 ns, 500 ns);  -- in ns
			RandTimes.randNs := RV.RandInt(1, 999);
			LoadNanoseconds(AXI_Manager, RandTimes.randNs, randTime);

			RandTimes.randT     := RV.RandInt(1, 1000);
			RandTimes.randSec   := RV.RandInt(1, 59);
			RandTimes.randMin   := RV.RandInt(1, 59); 
			RandTimes.randHour  := RV.RandInt(1, 24);
			RandTimes.randDay   := RV.RandInt(1, 12);
			RandTimes.randMonth := RV.RandInt(1, 12);
			RandTimes.randYear  := RV.RandInt(2000, 4000);
			LoadDatetime(AXI_Manager, RandTimes.randT, RandTimes.randSec, RandTimes.randMin, RandTimes.randHour, RandTimes.randDay, RandTimes.randYear, randTime);
		end loop;
		-- todo: check for changes in datetime
		
		wait for 1 ms;
		WaitForClock(AXI_Manager);
		WaitForBarrier(TestDone);
		wait;
	end process;

end architecture;

configuration clock_HighResolution_load of clock_HighResolution_th is
	for TestHarness
		for TestCtrl : clock_HighResolution_tc
			use entity work.clock_HighResolution_tc(load);
		end for;
	end for;
end configuration;
