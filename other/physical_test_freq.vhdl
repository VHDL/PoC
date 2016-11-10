-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
--
-- Module:					Sub-module for test of physical type `FREQ` and conversion
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
--										 Chair of VLSI-Design, Diagnostics and Architecture
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

entity physical_test_freq is

	generic (
		CONST_1_HZ			 : freq			 := 1 Hz;
		CONST_1_KHZ			 : freq			 := 1 kHz;
		CONST_1p125_KHZ	 : freq			 := 1.125 kHz;
		CONST_1_MHZ			 : freq			 := 1 MHz;
		CONST_1p125_MHZ	 : freq			 := 1.125 MHz;
		CONST_1_GHZ			 : freq			 := 1 GHz;
		CONST_1p125_GHZ	 : freq			 := 1.125 GHz;
		CVT_INT_1_HZ		 : freq			 := Hz2Freq(1);
		CVT_INT_1_KHZ		 : freq			 := kHz2Freq(1);
		CVT_INT_1_MHZ		 : freq			 := MHz2Freq(1);
		CVT_INT_1_GHZ		 : freq			 := GHz2Freq(1);
		CVT_1_HZ_INT		 : integer	 := to_int(1 Hz, 1 Hz);
		CVT_1_KHZ_INT		 : integer	 := to_int(1 kHz, 1 kHz);
		CVT_1_MHZ_INT		 : integer	 := to_int(1 MHz, 1 MHz);
		CVT_1_GHZ_INT		 : integer	 := to_int(1 GHz, 1 GHz);
		CVT_REAL_1p5_KHZ : freq			 := kHz2Freq(1.5);
		CVT_REAL_1p5_MHZ : freq			 := MHz2Freq(1.5);
		CVT_REAL_1p5_GHZ : freq			 := GHz2Freq(1.5);
		CVT_1p5_KHZ_REAL : real			 := to_real(1.5 kHz, 1 kHz);
		CVT_1p5_MHZ_REAL : real			 := to_real(1.5 MHz, 1 MHz);
		CVT_1p5_GHZ_REAL : real			 := to_real(1.5 GHz, 1 GHz);
		SOME_FREQS			 : T_FREQVEC := (1 GHz, 234 MHz, 567 kHz, 890 Hz)
	);

  port (
		x : in  std_logic;
    y	: out std_logic);

end entity physical_test_freq;

architecture rtl of physical_test_freq is
	function f return boolean is
	begin
		report "CONST_1_HZ        = " & FREQ'image(CONST_1_HZ      ) severity note;
		report "CONST_1_KHZ       = " & FREQ'image(CONST_1_KHZ     ) severity note;
		report "CONST_1p125_KHZ   = " & FREQ'image(CONST_1p125_KHZ ) severity note;
		report "CONST_1_MHZ       = " & FREQ'image(CONST_1_MHZ     ) severity note;
		report "CONST_1p125_MHZ   = " & FREQ'image(CONST_1p125_MHZ ) severity note;
		report "CONST_1_GHZ       = " & FREQ'image(CONST_1_GHZ     ) severity note;
		report "CONST_1p125_GHZ   = " & FREQ'image(CONST_1p125_GHZ ) severity note;
		report "CVT_INT_1_HZ      = " & FREQ'image(CVT_INT_1_HZ    ) severity note;
		report "CVT_INT_1_KHZ     = " & FREQ'image(CVT_INT_1_KHZ   ) severity note;
		report "CVT_INT_1_MHZ     = " & FREQ'image(CVT_INT_1_MHZ   ) severity note;
		report "CVT_INT_1_GHZ     = " & FREQ'image(CVT_INT_1_GHZ   ) severity note;
		report "CVT_1_HZ_INT      = " & integer'image(CVT_1_HZ_INT ) severity note;
		report "CVT_1_KHZ_INT     = " & integer'image(CVT_1_KHZ_INT) severity note;
		report "CVT_1_MHZ_INT     = " & integer'image(CVT_1_MHZ_INT) severity note;
		report "CVT_1_GHZ_INT     = " & integer'image(CVT_1_GHZ_INT) severity note;
		report "CVT_REAL_1p5_KHZ  = " & FREQ'image(CVT_REAL_1p5_KHZ) severity note;
		report "CVT_REAL_1p5_MHZ  = " & FREQ'image(CVT_REAL_1p5_MHZ) severity note;
		report "CVT_REAL_1p5_GHZ  = " & FREQ'image(CVT_REAL_1p5_GHZ) severity note;
		report "CVT_1p5_KHZ_REAL  = " & REAL'image(CVT_1p5_KHZ_REAL) severity note;
		report "CVT_1p5_MHZ_REAL  = " & REAL'image(CVT_1p5_MHZ_REAL) severity note;
		report "CVT_1p5_GHZ_REAL  = " & REAL'image(CVT_1p5_GHZ_REAL) severity note;
		report "tmax(SOME_FREQS)  = " & FREQ'image(fmax(SOME_FREQS)) severity note;
		report "tmin(SOME_FREQS)  = " & FREQ'image(fmin(SOME_FREQS)) severity note;
		report "tsum(SOME_FREQS)  = " & FREQ'image(fsum(SOME_FREQS)) severity note;
	return true;
	end f;

	constant C : boolean := f;

begin  -- architecture rtl

	-- This should be the only one assignment of output y.
	y <= x; -- just assigning '0' leads only to a critical warning instead of an
					-- error in Vivado.

	-----------------------------------------------------------------------------
	-- The check for values below zero capture overflows.
	checkConst1Hz: if CONST_1_HZ <= 0 Hz generate
		y <= '1';
	end generate;

	checkConst1kHz: if CONST_1_KHZ <= 0 Hz or CONST_1_KHZ /= 1000 Hz generate
		y <= '1';
	end generate;

	checkConst1p125kHz: if CONST_1p125_KHZ <= 0 Hz or CONST_1p125_KHZ /= 1125 Hz generate
		y <= '1';
	end generate;

	checkConst1MHz: if CONST_1_MHZ <= 0 Hz or CONST_1_MHZ /= 1000 kHz generate
		y <= '1';
	end generate;

	checkConst1p125MHz: if CONST_1p125_MHZ <= 0 Hz or CONST_1p125_MHZ /= 1125 kHz generate
		y <= '1';
	end generate;

	checkConst1GHz: if CONST_1_GHZ <= 0 Hz or CONST_1_GHZ /= 1000 MHz generate
		y <= '1';
	end generate;

	checkConst1p125GHz: if CONST_1p125_GHZ <= 0 Hz or CONST_1p125_GHZ /= 1125 MHz generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvtInt1Hz: if CVT_INT_1_HZ /= 1 Hz generate
		y <= '1';
	end generate;

	checkCvtInt1kHz: if CVT_INT_1_KHZ /= 1 kHz generate
		y <= '1';
	end generate;

	checkCvtInt1MHz: if CVT_INT_1_MHZ /= 1 MHz generate
		y <= '1';
	end generate;

	checkCvtInt1GHz: if CVT_INT_1_GHZ /= 1 GHz generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvt1HzInt: if CVT_1_HZ_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1kHzInt: if CVT_1_KHZ_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1MHzInt: if CVT_1_MHZ_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1GHzInt: if CVT_1_GHZ_INT /= 1 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvtReal1p5kHz: if CVT_REAL_1p5_KHZ /= 1.5 kHz generate
		y <= '1';
	end generate;

	checkCvtReal1p5MHz: if CVT_REAL_1p5_MHZ /= 1.5 MHz generate
		y <= '1';
	end generate;

	checkCvtReal1p5GHz: if CVT_REAL_1p5_GHZ /= 1.5 GHz generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvt1p5kHzReal: if CVT_1p5_KHZ_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5MHzReal: if CVT_1p5_MHZ_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5GHzReal: if CVT_1p5_GHZ_REAL /= 1.5 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkMax: if fmax(SOME_FREQS) /= 1 GHz generate
		y <= '1';
	end generate;

	checkMin: if fmin(SOME_FREQS) /= 890 Hz generate
		y <= '1';
	end generate;

	checkSum: if fsum(SOME_FREQS) /= 1234567890 Hz generate
		y <= '1';
	end generate;
end architecture rtl;
