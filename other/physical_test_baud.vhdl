-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
--
-- Module:					Sub-module for test of physical type `BAUD` and conversion
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

entity physical_test_baud is

	generic (
		CONST_1_BD			 : baud			 := 1 Bd;
		CONST_1_KBD			 : baud			 := 1 kBd;
		CONST_1p125_KBD	 : baud			 := 1.125 kBd;
		CONST_1_MBD			 : baud			 := 1 MBd;
		CONST_1p125_MBD	 : baud			 := 1.125 MBd;
		CONST_1_GBD			 : baud			 := 1 GBd;
		CONST_1p125_GBD	 : baud			 := 1.125 GBd;
		CVT_1_BD_INT		 : integer	 := to_int(1 Bd, 1 Bd);
		CVT_1_KBD_INT		 : integer	 := to_int(1 kBd, 1 kBd);
		CVT_1_MBD_INT		 : integer	 := to_int(1 MBd, 1 MBd);
		CVT_1_GBD_INT		 : integer	 := to_int(1 GBd, 1 GBd);
		CVT_1p5_KBD_REAL : real			 := to_real(1.5 kBd, 1 kBd);
		CVT_1p5_MBD_REAL : real			 := to_real(1.5 MBd, 1 MBd);
		CVT_1p5_GBD_REAL : real			 := to_real(1.5 GBd, 1 GBd);
		SOME_BAUDS			 : T_BAUDVEC := (1 GBd, 234 MBd, 567 kBd, 890 Bd)
	);

  port (
		x : in  std_logic;
    y	: out std_logic);

end entity physical_test_baud;

architecture rtl of physical_test_baud is
	function f return boolean is
	begin
		report "CONST_1_BD        = " & BAUD'image(CONST_1_BD      ) severity note;
		report "CONST_1_KBD       = " & BAUD'image(CONST_1_KBD     ) severity note;
		report "CONST_1p125_KBD   = " & BAUD'image(CONST_1p125_KBD ) severity note;
		report "CONST_1_MBD       = " & BAUD'image(CONST_1_MBD     ) severity note;
		report "CONST_1p125_MBD   = " & BAUD'image(CONST_1p125_MBD ) severity note;
		report "CONST_1_GBD       = " & BAUD'image(CONST_1_GBD     ) severity note;
		report "CONST_1p125_GBD   = " & BAUD'image(CONST_1p125_GBD ) severity note;
		report "CVT_1_BD_INT      = " & INTEGER'image(CVT_1_BD_INT ) severity note;
		report "CVT_1_KBD_INT     = " & INTEGER'image(CVT_1_KBD_INT) severity note;
		report "CVT_1_MBD_INT     = " & INTEGER'image(CVT_1_MBD_INT) severity note;
		report "CVT_1_GBD_INT     = " & INTEGER'image(CVT_1_GBD_INT) severity note;
		report "CVT_1p5_KBD_REAL  = " & REAL'image(CVT_1p5_KBD_REAL) severity note;
		report "CVT_1p5_MBD_REAL  = " & REAL'image(CVT_1p5_MBD_REAL) severity note;
		report "CVT_1p5_GBD_REAL  = " & REAL'image(CVT_1p5_GBD_REAL) severity note;
		report "bmax(SOME_BAUDS)  = " & BAUD'image(bmax(SOME_BAUDS)) severity note;
		report "bmin(SOME_BAUDS)  = " & BAUD'image(bmin(SOME_BAUDS)) severity note;
		report "bsum(SOME_BAUDS)  = " & BAUD'image(bsum(SOME_BAUDS)) severity note;
	return true;
	end f;

	constant C : boolean := f;

begin  -- architecture rtl

	-- This should be the only one assignment of output y.
	y <= x; -- just assigning '0' leads only to a critical warning instead of an
					-- error in Vivado.

	-----------------------------------------------------------------------------
	-- The check for values below zero capture overflows.
	checkConst1Bd: if CONST_1_BD <= 0 Bd generate
		y <= '1';
	end generate;

	checkConst1kBd: if CONST_1_KBD <= 0 Bd or CONST_1_KBD /= 1000 Bd generate
		y <= '1';
	end generate;

	checkConst1p125kBd: if CONST_1p125_KBD <= 0 Bd or CONST_1p125_KBD /= 1125 Bd generate
		y <= '1';
	end generate;

	checkConst1MBd: if CONST_1_MBD <= 0 Bd or CONST_1_MBD /= 1000 kBd generate
		y <= '1';
	end generate;

	checkConst1p125MBd: if CONST_1p125_MBD <= 0 Bd or CONST_1p125_MBD /= 1125 kBd generate
		y <= '1';
	end generate;

	checkConst1GBd: if CONST_1_GBD <= 0 Bd or CONST_1_GBD /= 1000 MBd generate
		y <= '1';
	end generate;

	checkConst1p125GBd: if CONST_1p125_GBD <= 0 Bd or CONST_1p125_GBD /= 1125 MBd generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvt1BdInt: if CVT_1_BD_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1kBdInt: if CVT_1_KBD_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1MBdInt: if CVT_1_MBD_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1GBdInt: if CVT_1_GBD_INT /= 1 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvt1p5kBdReal: if CVT_1p5_KBD_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5MBdReal: if CVT_1p5_MBD_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5GBdReal: if CVT_1p5_GBD_REAL /= 1.5 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkMax: if bmax(SOME_BAUDS) /= 1 GBd generate
		y <= '1';
	end generate;

	checkMin: if bmin(SOME_BAUDS) /= 890 Bd generate
		y <= '1';
	end generate;

	checkSum: if bsum(SOME_BAUDS) /= 1234567890 Bd generate
		y <= '1';
	end generate;
end architecture rtl;
