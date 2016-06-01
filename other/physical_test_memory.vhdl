-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
--
-- Module:					Sub-module for test of physical type `MEMORY` and conversion
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

entity physical_test_memory is

	generic (
		CONST_1_BYTE		 : memory		:= 1 Byte;
		CONST_1_KIB			 : memory		:= 1 KiB;
		CONST_1p125_KIB	 : memory		:= 1152 Byte;
		CONST_1_MIB			 : memory		:= 1 MiB;
		CONST_1p125_MIB	 : memory		:= 1152 kiB;
		CONST_1_GIB			 : memory		:= 1024 MiB;
		CONST_1p125_GIB	 : memory		:= 1152 MiB;
		CVT_1_BYTE_INT	 : integer	:= to_int(1 Byte, 1 Byte);
		CVT_1_KIB_INT		 : integer	:= to_int(1 KiB, 1 KiB);
		CVT_1_MIB_INT		 : integer	:= to_int(1 MiB, 1 MiB);
		CVT_1_GIB_INT		 : integer	:= to_int(1024 MiB, 1024 MiB);
		CVT_1p5_KIB_REAL : real			:= to_real(1536 Byte, 1 KiB);
		CVT_1p5_MIB_REAL : real			:= to_real(1536 kiB, 1 MiB);
		CVT_1p5_GIB_REAL : real			:= to_real(1536 MiB, 1024 MiB);
		SOME_MEMORYS		 : T_MEMVEC := (1024 MiB, 234 MiB, 567 KiB, 890 Byte)
	);

  port (
		x : in  std_logic;
    y	: out std_logic);

end entity physical_test_memory;

architecture rtl of physical_test_memory is
	function f return boolean is
	begin
		report "CONST_1_BYTE      = " & MEMORY'image(CONST_1_BYTE   ) severity note;
		report "CONST_1_KIB       = " & MEMORY'image(CONST_1_KIB    ) severity note;
		report "CONST_1p125_KIB   = " & MEMORY'image(CONST_1p125_KIB) severity note;
		report "CONST_1_MIB       = " & MEMORY'image(CONST_1_MIB    ) severity note;
		report "CONST_1p125_MIB   = " & MEMORY'image(CONST_1p125_MIB) severity note;
		report "CONST_1_GIB       = " & MEMORY'image(CONST_1_GIB    ) severity note;
		report "CONST_1p125_GIB   = " & MEMORY'image(CONST_1p125_GIB) severity note;
		report "CVT_1_BYTE_INT    = " & INTEGER'image(CVT_1_BYTE_INT) severity note;
		report "CVT_1_KIB_INT     = " & INTEGER'image(CVT_1_KIB_INT ) severity note;
		report "CVT_1_MIB_INT     = " & INTEGER'image(CVT_1_MIB_INT ) severity note;
		report "CVT_1_GIB_INT     = " & INTEGER'image(CVT_1_GIB_INT ) severity note;
		report "CVT_1p5_KIB_REAL  = " & REAL'image(CVT_1p5_KIB_REAL ) severity note;
		report "CVT_1p5_MIB_REAL  = " & REAL'image(CVT_1p5_MIB_REAL ) severity note;
		report "CVT_1p5_GIB_REAL  = " & REAL'image(CVT_1p5_GIB_REAL ) severity note;
		report "mmax(SOME_MEMORYS)= " & MEMORY'image(mmax(SOME_MEMORYS)) severity note;
		report "mmin(SOME_MEMORYS)= " & MEMORY'image(mmin(SOME_MEMORYS)) severity note;
		report "msum(SOME_MEMORYS)= " & MEMORY'image(msum(SOME_MEMORYS)) severity note;
	return true;
	end f;

	constant C : boolean := f;

begin  -- architecture rtl

	-- This should be the only one assignment of output y.
	y <= x; -- just assigning '0' leads only to a critical warning instead of an
					-- error in Vivado.

	-----------------------------------------------------------------------------
	-- The check for values below zero capture overflows.
	checkConst1Byte: if CONST_1_BYTE <= 0 Byte generate
		y <= '1';
	end generate;

	checkConst1KiB: if CONST_1_KIB <= 0 Byte or CONST_1_KIB /= 1024 Byte generate
		y <= '1';
	end generate;

	checkConst1p125KiB: if CONST_1p125_KIB <= 0 Byte or CONST_1p125_KIB /= 1152 Byte generate
		y <= '1';
	end generate;

	checkConst1MiB: if CONST_1_MIB <= 0 Byte or CONST_1_MIB /= 1024 KiB generate
		y <= '1';
	end generate;

	checkConst1p125MiB: if CONST_1p125_MIB <= 0 Byte or CONST_1p125_MIB /= 1152 KiB generate
		y <= '1';
	end generate;

	checkConst1GiB: if CONST_1_GIB <= 0 Byte or CONST_1_GIB /= 1024 MiB generate
		y <= '1';
	end generate;

	checkConst1p125GiB: if CONST_1p125_GIB <= 0 Byte or CONST_1p125_GIB /= 1152 MiB generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvt1ByteInt: if CVT_1_BYTE_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1KiBInt: if CVT_1_KIB_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1MiBInt: if CVT_1_MIB_INT /= 1 generate
		y <= '1';
	end generate;

	checkCvt1GiBInt: if CVT_1_GIB_INT /= 1 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkCvt1p5KiBReal: if CVT_1p5_KIB_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5MiBReal: if CVT_1p5_MIB_REAL /= 1.5 generate
		y <= '1';
	end generate;

	checkCvt1p5GiBReal: if CVT_1p5_GIB_REAL /= 1.5 generate
		y <= '1';
	end generate;


	-----------------------------------------------------------------------------
	checkMax: if mmax(SOME_MEMORYS) /= 1024 MiB generate
		y <= '1';
	end generate;

	checkMin: if mmin(SOME_MEMORYS) /= 890 Byte generate
		y <= '1';
	end generate;

	checkSum: if msum(SOME_MEMORYS) /= 1319690106 Byte generate
		y <= '1';
	end generate;
end architecture rtl;
