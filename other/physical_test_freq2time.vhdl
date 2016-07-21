-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
--
-- Module:					Sub-module for test of conversion routines defined in
-- 									`physical.pkg.vhdl` between physical types `TIME` and
-- 									`FREQ`.
--
--
-- Description:
-- ------------------------------------
-- Synthesis reports a multiple driver error / critical-warning when
-- one of the tests below fails.
--
-- The values to check are defined via generics to allow debugging within Vivado
-- because Vivado does not support the `report` statement during synthesis.
-- Instead, it prints the assigned values in the synthesis report.
-- But, ISE does not print them in the synthesis report by default, thus a
-- `report` statement is required.
-- Quartus, reports them both ways.
--
-- License:
-- ============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
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
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;

library poc;
use poc.physical.all;

entity physical_test_freq2time is

	generic (
		CVT_LIT_1_Hz		 : time := to_time(1 Hz);
		CVT_LIT_2_Hz		 : time := to_time(2 Hz);
		CVT_LIT_1_kHz		 : time := to_time(1 kHz);
		CVT_LIT_2_kHz		 : time := to_time(2 kHz);
		CVT_LIT_1_MHz		 : time := to_time(1 MHz);
		CVT_LIT_2_MHz		 : time := to_time(2 MHz);
		CVT_LIT_1_GHz		 : time := to_time(1 GHz);
		CVT_LIT_2_GHz		 : time := to_time(2 GHz);
		CVT_INT_1_Hz		 : time := Hz2Time(1);
		CVT_INT_2_Hz		 : time := Hz2Time(2);
		CVT_INT_1_kHz		 : time := kHz2Time(1);
		CVT_INT_2_kHz		 : time := kHz2Time(2);
		CVT_INT_1_MHz		 : time := MHz2Time(1);
		CVT_INT_2_MHz		 : time := MHz2Time(2);
		CVT_INT_1_GHz		 : time := GHz2Time(1);
		CVT_INT_2_GHz		 : time := GHz2Time(2);
		CVT_REAL_1p25_Hz	 : time := Hz2Time(1.25);
		CVT_REAL_1p25_kHz : time := kHz2Time(1.25);
		CVT_REAL_1p25_MHz : time := MHz2Time(1.25);
		CVT_REAL_1p25_GHz : time := GHz2Time(1.25);
		CVT_LIT_500_PS	 : freq := to_freq(500 ps);
		CVT_LIT_1_NS		 : freq := to_freq(1 ns);
		CVT_LIT_500_NS	 : freq := to_freq(500 ns);
		CVT_LIT_1_US		 : freq := to_freq(1 us);
		CVT_LIT_500_US	 : freq := to_freq(500 us);
		CVT_LIT_1_MS		 : freq := to_freq(1 ms);
		CVT_LIT_500_MS	 : freq := to_freq(500 ms);
		CVT_LIT_1_SEC		 : freq := to_freq(1 sec)
	);

  port (
		x : in  std_logic;
    y	: out std_logic);

end entity physical_test_freq2time;

architecture rtl of physical_test_freq2time is
	function f return boolean is
	begin
		report "CVT_LIT_1_Hz      = " & time'image(CVT_LIT_1_Hz     ) severity note;
		report "CVT_LIT_2_Hz      = " & time'image(CVT_LIT_2_Hz     ) severity note;
		report "CVT_LIT_1_kHz     = " & time'image(CVT_LIT_1_kHz    ) severity note;
		report "CVT_LIT_2_kHz     = " & time'image(CVT_LIT_2_kHz    ) severity note;
		report "CVT_LIT_1_MHz     = " & time'image(CVT_LIT_1_MHz    ) severity note;
		report "CVT_LIT_2_MHz     = " & time'image(CVT_LIT_2_MHz    ) severity note;
		report "CVT_LIT_1_GHz     = " & time'image(CVT_LIT_1_GHz    ) severity note;
		report "CVT_LIT_2_GHz     = " & time'image(CVT_LIT_2_GHz    ) severity note;
		report "CVT_INT_1_Hz      = " & time'image(CVT_INT_1_Hz     ) severity note;
		report "CVT_INT_2_Hz      = " & time'image(CVT_INT_2_Hz     ) severity note;
		report "CVT_INT_1_kHz     = " & time'image(CVT_INT_1_kHz    ) severity note;
		report "CVT_INT_2_kHz     = " & time'image(CVT_INT_2_kHz    ) severity note;
		report "CVT_INT_1_MHz     = " & time'image(CVT_INT_1_MHz    ) severity note;
		report "CVT_INT_2_MHz     = " & time'image(CVT_INT_2_MHz    ) severity note;
		report "CVT_INT_1_GHz     = " & time'image(CVT_INT_1_GHz    ) severity note;
		report "CVT_INT_2_GHz     = " & time'image(CVT_INT_2_GHz    ) severity note;
		report "CVT_REAL_1p25_Hz  = " & time'image(CVT_REAL_1p25_Hz ) severity note;
		report "CVT_REAL_1p25_kHz = " & time'image(CVT_REAL_1p25_kHz) severity note;
		report "CVT_REAL_1p25_MHz = " & time'image(CVT_REAL_1p25_MHz) severity note;
		report "CVT_REAL_1p25_GHz = " & time'image(CVT_REAL_1p25_GHz) severity note;
		report "CVT_LIT_500_PS    = " & freq'image(CVT_LIT_500_PS   ) severity note;
		report "CVT_LIT_1_NS      = " & freq'image(CVT_LIT_1_NS     ) severity note;
		report "CVT_LIT_500_NS    = " & freq'image(CVT_LIT_500_NS   ) severity note;
		report "CVT_LIT_1_US      = " & freq'image(CVT_LIT_1_US     ) severity note;
		report "CVT_LIT_500_US    = " & freq'image(CVT_LIT_500_US   ) severity note;
		report "CVT_LIT_1_MS      = " & freq'image(CVT_LIT_1_MS     ) severity note;
		report "CVT_LIT_500_MS    = " & freq'image(CVT_LIT_500_MS   ) severity note;
		report "CVT_LIT_1_SEC     = " & freq'image(CVT_LIT_1_SEC    ) severity note;
	return true;
	end f;

	constant C : boolean := f;

begin  -- architecture rtl

	-- This should be the only one assignment of output y.
	y <= x; -- just assigning '0' leads only to a critical warning instead of an
					-- error in Vivado.

	-----------------------------------------------------------------------------
	checkCvtLit1Hz: if CVT_LIT_1_HZ /= 1 sec generate
		y <= '1';
	end generate;

	checkCvtLit2Hz: if CVT_LIT_2_HZ /= 500 ms generate
		y <= '1';
	end generate;

	checkCvtLit1kHz: if CVT_LIT_1_KHZ /= 1 ms generate
		y <= '1';
	end generate;

	checkCvtLit2kHz: if CVT_LIT_2_KHZ /= 500 us generate
		y <= '1';
	end generate;

	checkCvtLit1MHz: if CVT_LIT_1_MHZ /= 1 us generate
		y <= '1';
	end generate;

	checkCvtLit2MHz: if CVT_LIT_2_MHZ /= 500 ns generate
		y <= '1';
	end generate;

	checkCvtLit1GHz: if CVT_LIT_1_GHZ /= 1 ns generate
		y <= '1';
	end generate;

	checkCvtLit2GHz: if CVT_LIT_2_GHZ /= 500 ps generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvtInt1Hz: if CVT_INT_1_HZ /= 1 sec generate
		y <= '1';
	end generate;

	checkCvtInt2Hz: if CVT_INT_2_HZ /= 500 ms generate
		y <= '1';
	end generate;

	checkCvtInt1kHz: if CVT_INT_1_KHZ /= 1 ms generate
		y <= '1';
	end generate;

	checkCvtInt2kHz: if CVT_INT_2_KHZ /= 500 us generate
		y <= '1';
	end generate;

	checkCvtInt1MHz: if CVT_INT_1_MHZ /= 1 us generate
		y <= '1';
	end generate;

	checkCvtInt2MHz: if CVT_INT_2_MHZ /= 500 ns generate
		y <= '1';
	end generate;

	checkCvtInt1GHz: if CVT_INT_1_GHZ /= 1 ns generate
		y <= '1';
	end generate;

	checkCvtInt2GHz: if CVT_INT_2_GHZ /= 500 ps generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvtReal1p25Hz: if CVT_REAL_1p25_HZ /= 800 ms generate
		y <= '1';
	end generate;

	checkCvtReal1p25kHz: if CVT_REAL_1p25_KHZ /= 800 us generate
		y <= '1';
	end generate;

	checkCvtReal1p25MHz: if CVT_REAL_1p25_MHZ /= 800 ns generate
		y <= '1';
	end generate;

	checkCvtReal1p25GHz: if CVT_REAL_1p25_GHZ /= 800 ps generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvtLit500ps: if CVT_LIT_500_PS /= 2 GHz generate
		y <= '1';
	end generate;

	checkCvtLit1ns: if CVT_LIT_1_NS /= 1 GHz generate
		y <= '1';
	end generate;

	checkCvtLit500ns: if CVT_LIT_500_NS /= 2 MHz generate
		y <= '1';
	end generate;

	checkCvtLit1us: if CVT_LIT_1_US /= 1 MHz generate
		y <= '1';
	end generate;

	checkCvtLit500us: if CVT_LIT_500_US /= 2 kHz generate
		y <= '1';
	end generate;

	checkCvtLit1ms: if CVT_LIT_1_MS /= 1 kHz generate
		y <= '1';
	end generate;

	checkCvtLit500ms: if CVT_LIT_500_MS /= 2 Hz generate
		y <= '1';
	end generate;

	checkCvtLit1sec: if CVT_LIT_1_SEC /= 1 Hz generate
		y <= '1';
	end generate;

end architecture rtl;
