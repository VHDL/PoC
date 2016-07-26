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
		CONST_1_FS		 : t_time := 1.0e-15;
		CONST_1_PS		 : t_time := 1.0e-12;
		CONST_1p125_PS : t_time := 1.125e-12;
		CONST_1_NS		 : t_time := 1.0e-9;
		CONST_1p125_NS : t_time := 1.125e-9;
		CONST_1_US		 : t_time := 1.0e-6;
		CONST_1p125_US : t_time := 1.125e-6;
		CONST_1_MS		 : t_time := 1.0e-3;
		CONST_1p125_MS : t_time := 1.125e-3;
		CONST_1_SEC		 : t_time := 1.0;
		CONST_1p125_SEC: t_time := 1.125;
		CONST_1_MIN		 : t_time := 60.0;
		CONST_1_HR		 : t_time := 3600.0;
		CVT_INT_1_FS	 : t_time := fs2Time(1);
		CVT_INT_1_PS	 : t_time := ps2Time(1);
		CVT_INT_1_NS	 : t_time := ns2Time(1);
		CVT_INT_1_US	 : t_time := us2Time(1);
		CVT_INT_1_MS	 : t_time := ms2Time(1);
		CVT_INT_1_SEC	 : t_time := sec2Time(1);
  	CVT_1_FS_INT   : integer := to_int(1.0e-15, 1.0e-15);
  	CVT_1_PS_INT   : integer := to_int(1.0e-12, 1.0e-12);
  	CVT_1_NS_INT   : integer := to_int(1.0e-9, 1.0e-9);
  	CVT_1_US_INT   : integer := to_int(1.0e-6, 1.0e-6);
  	CVT_1_MS_INT   : integer := to_int(1.0e-3, 1.0e-3);
  	CVT_1_SEC_INT  : integer := to_int(1.0, 1.0);
		CVT_REAL_1p5_PS	 : t_time := ps2Time(1.5);
		CVT_REAL_1p5_NS	 : t_time := ns2Time(1.5);
		CVT_REAL_1p5_US	 : t_time := us2Time(1.5);
		CVT_REAL_1p5_MS	 : t_time := ms2Time(1.5);
		CVT_REAL_1p5_SEC : t_time := sec2Time(1.5);
		CVT_1p5_PS_REAL  : real := to_real(1.5e-12, 1.0e-12);
		CVT_1p5_NS_REAL  : real := to_real(1.5e-9, 1.0e-9);
		CVT_1p5_US_REAL  : real := to_real(1.5e-6, 1.0e-6);
		CVT_1p5_MS_REAL  : real := to_real(1.5e-3, 1.0e-3);
		CVT_1p5_SEC_REAL : real := to_real(1.5, 1.0);
		SOME_TIMES : T_TIMEVEC := (1.0e-6, 234.0e-9, 567.0e-12, 890.0e-15)
	);

  port (
		x : in  std_logic;
    y	: out std_logic);

end entity physical_test_time;

architecture rtl of physical_test_time is
	function f return boolean is
	begin
		report "CONST_1_FS        = " & T_TIME'image(CONST_1_FS      ) severity note;
		report "CONST_1_PS        = " & T_TIME'image(CONST_1_PS      ) severity note;
		report "CONST_1p125_PS    = " & T_TIME'image(CONST_1p125_PS  ) severity note;
		report "CONST_1_NS        = " & T_TIME'image(CONST_1_NS      ) severity note;
		report "CONST_1p125_NS    = " & T_TIME'image(CONST_1p125_NS  ) severity note;
		report "CONST_1_US        = " & T_TIME'image(CONST_1_US      ) severity note;
		report "CONST_1p125_US    = " & T_TIME'image(CONST_1p125_US  ) severity note;
		report "CONST_1_MS        = " & T_TIME'image(CONST_1_MS      ) severity note;
		report "CONST_1p125_MS    = " & T_TIME'image(CONST_1p125_MS  ) severity note;
		report "CONST_1_SEC       = " & T_TIME'image(CONST_1_SEC     ) severity note;
		report "CONST_1p125_SEC   = " & T_TIME'image(CONST_1p125_SEC ) severity note;
		report "CONST_1_MIN       = " & T_TIME'image(CONST_1_MIN     ) severity note;
		report "CONST_1_HR        = " & T_TIME'image(CONST_1_HR      ) severity note;
		report "CVT_INT_1_FS      = " & T_TIME'image(CVT_INT_1_FS    ) severity note;
		report "CVT_INT_1_PS      = " & T_TIME'image(CVT_INT_1_PS    ) severity note;
		report "CVT_INT_1_NS      = " & T_TIME'image(CVT_INT_1_NS    ) severity note;
		report "CVT_INT_1_US      = " & T_TIME'image(CVT_INT_1_US    ) severity note;
		report "CVT_INT_1_MS      = " & T_TIME'image(CVT_INT_1_MS    ) severity note;
		report "CVT_INT_1_SEC     = " & T_TIME'image(CVT_INT_1_SEC   ) severity note;
		report "CVT_1_FS_INT      = " & integer'image(CVT_1_FS_INT ) severity note;
		report "CVT_1_PS_INT      = " & integer'image(CVT_1_PS_INT ) severity note;
		report "CVT_1_NS_INT      = " & integer'image(CVT_1_NS_INT ) severity note;
		report "CVT_1_US_INT      = " & integer'image(CVT_1_US_INT ) severity note;
		report "CVT_1_MS_INT      = " & integer'image(CVT_1_MS_INT ) severity note;
		report "CVT_1_SEC_INT     = " & integer'image(CVT_1_SEC_INT) severity note;
		report "CVT_REAL_1p5_PS   = " & T_TIME'image(CVT_REAL_1p5_PS ) severity note;
		report "CVT_REAL_1p5_NS   = " & T_TIME'image(CVT_REAL_1p5_NS ) severity note;
		report "CVT_REAL_1p5_US   = " & T_TIME'image(CVT_REAL_1p5_US ) severity note;
		report "CVT_REAL_1p5_MS   = " & T_TIME'image(CVT_REAL_1p5_MS ) severity note;
		report "CVT_REAL_1p5_SEC  = " & T_TIME'image(CVT_REAL_1p5_SEC) severity note;
		report "CVT_1p5_PS_REAL   = " & REAL'image(CVT_1p5_PS_REAL ) severity note;
		report "CVT_1p5_NS_REAL   = " & REAL'image(CVT_1p5_NS_REAL ) severity note;
		report "CVT_1p5_US_REAL   = " & REAL'image(CVT_1p5_US_REAL ) severity note;
		report "CVT_1p5_MS_REAL   = " & REAL'image(CVT_1p5_MS_REAL ) severity note;
		report "CVT_1p5_SEC_REAL  = " & REAL'image(CVT_1p5_SEC_REAL) severity note;
		report "tmax(SOME_TIMES)  = " & T_TIME'image(tmax(SOME_TIMES)) severity note;
		report "tmin(SOME_TIMES)  = " & T_TIME'image(tmin(SOME_TIMES)) severity note;
		report "tsum(SOME_TIMES)  = " & T_TIME'image(tsum(SOME_TIMES)) severity note;
	return true;
	end f;

	constant C : boolean := f;

begin  -- architecture rtl

	-- This should be the only one assignment of output y.
	y <= x; -- just assigning '0' leads only to a critical warning instead of an
					-- error in Vivado.

	-----------------------------------------------------------------------------
	-- The check for values below zero capture overflows.
	checkConst1fs: if CONST_1_FS <= 0.0 generate
		y <= '1';
	end generate;

	checkConst1ps: if CONST_1_PS <= 0.0 or CONST_1_PS /= 1000.0e-15 generate
		y <= '1';
	end generate;

	checkConst1p125ps: if CONST_1p125_PS <= 0.0 or CONST_1p125_PS /= 1125.0e-15 generate
		y <= '1';
	end generate;

	checkConst1ns: if CONST_1_NS <= 0.0 or CONST_1_NS /= 1000.0e-12 generate
		y <= '1';
	end generate;

	checkConst1p125ns: if CONST_1p125_NS <= 0.0 or CONST_1p125_NS /= 1125.0e-12 generate
		y <= '1';
	end generate;

	checkConst1us: if CONST_1_US <= 0.0 or CONST_1_US /= 1000.0e-9 generate
		y <= '1';
	end generate;

	checkConst1p125us: if CONST_1p125_US <= 0.0 or CONST_1p125_US /= 1125.0e-9 generate
		y <= '1';
	end generate;

	checkConst1ms: if CONST_1_MS <= 0.0 or CONST_1_MS /= 1000.0e-6 generate
		y <= '1';
	end generate;

	checkConst1p125ms: if CONST_1p125_MS <= 0.0 or CONST_1p125_MS /= 1125.0e-6 generate
		y <= '1';
	end generate;

	checkConst1sec: if CONST_1_SEC <= 0.0 or CONST_1_SEC /= 1000.0e-3 generate
		y <= '1';
	end generate;

	checkConst1p125sec: if CONST_1p125_SEC <= 0.0 or CONST_1p125_SEC /= 1125.0e-3 generate
		y <= '1';
	end generate;

	checkConst1min: if CONST_1_MIN <= 0.0 or CONST_1_MIN /= 60.0 generate
		y <= '1';
	end generate;

	checkConst1hr: if CONST_1_HR <= 0.0 or CONST_1_HR /= 3600.0 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvtInt1fs: if CVT_INT_1_FS /= 1.0e-15 generate
		y <= '1';
	end generate;

	checkCvtInt1ps: if CVT_INT_1_PS /= 1.0e-12 generate
		y <= '1';
	end generate;

	checkCvtInt1ns: if CVT_INT_1_NS /= 1.0e-9 generate
		y <= '1';
	end generate;

	checkCvtInt1us: if CVT_INT_1_US /= 1.0e-6 generate
		y <= '1';
	end generate;

	checkCvtInt1ms: if CVT_INT_1_MS /= 1.0e-3 generate
		y <= '1';
	end generate;

	checkCvtInt1sec: if CVT_INT_1_SEC /= 1.0 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvt1fsInt: if CVT_1_FS_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1psInt: if CVT_1_PS_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1nsInt: if CVT_1_NS_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1usInt: if CVT_1_US_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1msInt: if CVT_1_MS_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1secInt: if CVT_1_SEC_INT /= 1 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvtReal1p5ps: if CVT_REAL_1p5_PS /= 1.5e-12 generate
		y <= '1';
	end generate;

	checkCvtReal1p5ns: if CVT_REAL_1p5_NS < 1.499999e-9 and CVT_REAL_1p5_NS > 1.500001e-9 generate
		y <= '1';
	end generate;

	checkCvtReal1p5us: if CVT_REAL_1p5_US /= 1.5e-6 generate
		y <= '1';
	end generate;

	checkCvtReal1p5ms: if CVT_REAL_1p5_MS /= 1.5e-3 generate
		y <= '1';
	end generate;

	checkCvtReal1p5sec: if CVT_REAL_1p5_SEC /= 1.5 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvt1p5psReal: if CVT_1p5_PS_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5nsReal: if CVT_1p5_NS_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5usReal: if CVT_1p5_US_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5msReal: if CVT_1p5_MS_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5secReal: if CVT_1p5_SEC_REAL /= 1.5 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkMax: if tmax(SOME_TIMES) /= 1.0e-6 generate
		y <= '1';
	end generate;

	checkMin: if tmin(SOME_TIMES) /= 890.0e-15 generate
		y <= '1';
	end generate;

	checkSum: if tsum(SOME_TIMES) /= 1234567890.0e-15 generate
		y <= '1';
	end generate;
end architecture rtl;
