-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
-- 
-- Module:					Sub-module for test of physical type `TIME` and conversion
-- 									routines defined in `physical.pkg.vhdl`.
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

entity physical_test_time is
  
	generic (
		STRICT 				 : boolean := false;
		CONST_1_FS		 : time := 1 fs;
		CONST_1_PS		 : time := 1 ps;
		CONST_1p001_PS : time := 1.001 ps;
		CONST_1_NS		 : time := 1 ns;
		CONST_1p001_NS : time := 1.001 ns;
		CONST_1_US		 : time := 1 us;
		CONST_1p001_US : time := 1.001 us;
		CONST_1_MS		 : time := 1 ms;
		CONST_1p001_MS : time := 1.001 ms;
		CONST_1_SEC		 : time := 1 sec;
		CONST_1p001_SEC: time := 1.001 sec;
		CONST_1_MIN		 : time := 60 sec;		-- Quartus does not support "1 min"
		CONST_1_HR		 : time := 1 hr;
		CVT_NAT_1_FS	 : time := fs2Time(1);
		CVT_NAT_1_PS	 : time := ps2Time(1);
		CVT_NAT_1_NS	 : time := ns2Time(1);
		CVT_NAT_1_US	 : time := us2Time(1);
		CVT_NAT_1_MS	 : time := ms2Time(1);
		CVT_NAT_1_SEC	 : time := sec2Time(1);
		CVT_REAL_1p5_PS	 : time := ps2Time(1.5);
		CVT_REAL_1p5_NS	 : time := ns2Time(1.5);
		CVT_REAL_1p5_US	 : time := us2Time(1.5);
		CVT_REAL_1p5_MS	 : time := ms2Time(1.5);
		CVT_REAL_1p5_SEC : time := sec2Time(1.5);
		SOME_TIMES : T_TIMEVEC := (1 fs, 1 ps, 1 ns, 1 us)
	);

  port (
		x : in  std_logic;
    y	: out std_logic);

end entity physical_test_time;

architecture rtl of physical_test_time is
	function f return boolean is
	begin
		report "CONST_1_FS        = " & TIME'image(CONST_1_FS      ) severity note;
		report "CONST_1_PS        = " & TIME'image(CONST_1_PS      ) severity note;
		report "CONST_1p001_PS    = " & TIME'image(CONST_1p001_PS  ) severity note;
		report "CONST_1_NS        = " & TIME'image(CONST_1_NS      ) severity note;
		report "CONST_1p001_NS    = " & TIME'image(CONST_1p001_NS  ) severity note;
		report "CONST_1_US        = " & TIME'image(CONST_1_US      ) severity note;
		report "CONST_1p001_US    = " & TIME'image(CONST_1p001_US  ) severity note;
		report "CONST_1_MS        = " & TIME'image(CONST_1_MS      ) severity note;
		report "CONST_1p001_MS    = " & TIME'image(CONST_1p001_MS  ) severity note;
		report "CONST_1_SEC       = " & TIME'image(CONST_1_SEC     ) severity note;
		report "CONST_1p001_SEC   = " & TIME'image(CONST_1p001_SEC ) severity note;
		report "CONST_1_MIN       = " & TIME'image(CONST_1_MIN     ) severity note;
		report "CONST_1_HR        = " & TIME'image(CONST_1_HR      ) severity note;
		report "CVT_NAT_1_FS      = " & TIME'image(CVT_NAT_1_FS    ) severity note;
		report "CVT_NAT_1_PS      = " & TIME'image(CVT_NAT_1_PS    ) severity note;
		report "CVT_NAT_1_NS      = " & TIME'image(CVT_NAT_1_NS    ) severity note;
		report "CVT_NAT_1_US      = " & TIME'image(CVT_NAT_1_US    ) severity note;
		report "CVT_NAT_1_MS      = " & TIME'image(CVT_NAT_1_MS    ) severity note;
		report "CVT_NAT_1_SEC     = " & TIME'image(CVT_NAT_1_SEC   ) severity note;
		report "CVT_REAL_1p5_PS   = " & TIME'image(CVT_REAL_1p5_PS ) severity note;
		report "CVT_REAL_1p5_NS   = " & TIME'image(CVT_REAL_1p5_NS ) severity note;
		report "CVT_REAL_1p5_US   = " & TIME'image(CVT_REAL_1p5_US ) severity note;
		report "CVT_REAL_1p5_MS   = " & TIME'image(CVT_REAL_1p5_MS ) severity note;
		report "CVT_REAL_1p5_SEC  = " & TIME'image(CVT_REAL_1p5_SEC) severity note;
		report "MAX(SOME_TIMES)   = " & TIME'image(MAX(SOME_TIMES) ) severity note;
		report "MIN(SOME_TIMES)   = " & TIME'image(MIN(SOME_TIMES) ) severity note;
		report "SUM(SOME_TIMES)   = " & TIME'image(SUM(SOME_TIMES) ) severity note;

		report "TIME'val(integer(real(TIME'pos(1 ps)) * 1.001)) = " & TIME'image(TIME'val(integer(real(TIME'pos(1 ps)) * 1.001))) severity note;
	return true;
	end f;
	
	constant C : boolean := f;

begin  -- architecture rtl

	-- This should be the only one assignment of output y.
	y <= x; -- just assigning '0' leads only to a critical warning instead of an
					-- error in Vivado.

	-- The check for values below zero capture overflows.
	checkConst1fs: if CONST_1_FS <= 0 sec generate
		y <= '1';
	end generate;
	
	checkConst1ps: if CONST_1_PS <= 0 sec or CONST_1_PS /= 1000 fs generate
		y <= '1';
	end generate;
	
	checkConst1p001ps: if CONST_1p001_PS <= 0 sec or (STRICT and CONST_1p001_PS /= 1001 fs) or CONST_1p001_PS < 1000 fs or CONST_1p001_PS > 1002 fs generate
		y <= '1';
	end generate;
	
	checkConst1ns: if CONST_1_NS <= 0 sec or CONST_1_NS /= 1000 ps generate
		y <= '1';
	end generate;
	
	checkConst1p001ns: if CONST_1p001_NS <= 0 sec or (STRICT and CONST_1p001_NS /= 1001 ps) or CONST_1p001_NS < 1000 ps or CONST_1p001_NS > 1002 ps generate
		y <= '1';
	end generate;
	
	checkConst1us: if CONST_1_US <= 0 sec or CONST_1_US /= 1000 ns generate
		y <= '1';
	end generate;
	
	checkConst1p001us: if CONST_1p001_US <= 0 sec or (STRICT and CONST_1p001_US /= 1001 ns) or CONST_1p001_US < 1000 ns or CONST_1p001_US > 1002 ns generate
		y <= '1';
	end generate;
	
	checkConst1ms: if CONST_1_MS <= 0 sec or CONST_1_MS /= 1000 us generate
		y <= '1';
	end generate;
	
	checkConst1p001ms: if CONST_1p001_MS <= 0 sec or (STRICT and CONST_1p001_MS /= 1001 us) or CONST_1p001_MS < 1000 us or CONST_1p001_MS > 1002 us generate
		y <= '1';
	end generate;
	
	checkConst1sec: if CONST_1_SEC <= 0 sec or CONST_1_SEC /= 1000 ms generate
		y <= '1';
	end generate;
	
	checkConst1p001sec: if CONST_1p001_SEC <= 0 sec or (STRICT and CONST_1p001_SEC /= 1001 ms) or CONST_1p001_SEC < 1000 ms or CONST_1p001_SEC > 1002 ms generate
		y <= '1';
	end generate;
	
	checkConst1min: if CONST_1_MIN <= 0 sec or CONST_1_MIN /= 60 sec generate
		y <= '1';
	end generate;
	
	checkConst1hr: if CONST_1_HR <= 0 sec or CONST_1_HR /= 3600 sec generate
		y <= '1';
	end generate;

	checkCvtNat1fs: if CVT_NAT_1_FS /= 1 fs generate
		y <= '1';
	end generate;

	checkCvtNat1ps: if CVT_NAT_1_PS /= 1 ps generate
		y <= '1';
	end generate;

	checkCvtNat1ns: if CVT_NAT_1_NS /= 1 ns generate
		y <= '1';
	end generate;

	checkCvtNat1us: if CVT_NAT_1_US /= 1 us generate
		y <= '1';
	end generate;

	checkCvtNat1ms: if CVT_NAT_1_MS /= 1 ms generate
		y <= '1';
	end generate;

	checkCvtNat1sec: if CVT_NAT_1_SEC /= 1 sec generate
		y <= '1';
	end generate;

	checkCvtReal1p5ps: if CVT_REAL_1p5_PS /= 1.5 ps generate
		y <= '1';
	end generate;

	checkCvtReal1p5ns: if CVT_REAL_1p5_NS /= 1.5 ns generate
		y <= '1';
	end generate;

	checkCvtReal1p5us: if CVT_REAL_1p5_US /= 1.5 us generate
		y <= '1';
	end generate;

	checkCvtReal1p5ms: if CVT_REAL_1p5_MS /= 1.5 ms generate
		y <= '1';
	end generate;

	checkCvtReal1p5sec: if CVT_REAL_1p5_SEC /= 1.5 sec generate
		y <= '1';
	end generate;

	checkMax: if max(SOME_TIMES) /= 1 us generate
		y <= '1';
	end generate;

	checkMin: if min(SOME_TIMES) /= 1 fs generate
		y <= '1';
	end generate;

	checkSum: if sum(SOME_TIMES) /= 1001001001 fs generate
		y <= '1';
	end generate;
end architecture rtl;
