-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Entity:				 	TODO
--
-- Authors:				 	Patrick Lehmann
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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
-- =============================================================================



-- Summary:
-- ============
--  This function package parses *.VCD files and drives simulation stimulies.
--
-- Description:
-- ============
--	"VCD_ReadHeader" reads the file header.
--	"VCD_ReadLine" reads a line from *.vcd file.
--	"VCD_Read_StdLogic" parses a vcd one bit value to std_logic.
--	"VCD_Read_StdLogicVector" parses a vcd N bit value to std_logic_vector with N bits.
--
--	See ../tb/Test_vcd_example_tb.vhd for example code.
--
-- Dependancies:
-- =============
--	- IEEE.STD_LOGIC_1164.ALL
--	- IEEE.STD_LOGIC_TEXTIO.ALL
--	- IEEE.NUMERIC_STD.ALL
--	- STD.TEXTIO.ALL
--	- PoC.functions.ALL
--
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2012-06-08 16:51:07 $
--


LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.STD_LOGIC_TEXTIO.ALL;
USE			IEEE.NUMERIC_STD.ALL;
USE			STD.TEXTIO.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;

PACKAGE sim_value_change_dump IS
	SUBTYPE T_VCDLINE		IS		STRING(1 TO 80);

	FUNCTION to_nat(str : STRING) RETURN INTEGER;
	FUNCTION resize(str : STRING; size : POSITIVE) RETURN STRING;

	PROCEDURE VCD_ReadHeader(FILE VCDFile : TEXT; VCDLine : INOUT T_VCDLINE);
	PROCEDURE VCD_ReadLine(FILE VCDFile : TEXT; VCDLine : OUT STRING);

	PROCEDURE VCD_Read_StdLogic(VCDLine : STRING; SIGNAL sl : OUT STD_LOGIC; WaveName : STRING);
	PROCEDURE VCD_Read_StdLogicVector(VCDLine : STRING; SIGNAL slv : OUT STD_LOGIC_VECTOR; WaveName : STRING; def : STD_LOGIC := '0');

END sim_value_change_dump;

PACKAGE BODY sim_value_change_dump IS
	FUNCTION to_digit(chr : CHARACTER) RETURN INTEGER IS
	BEGIN
		CASE (chr) IS
			WHEN '0' =>			RETURN 0;
			WHEN '1' =>			RETURN 1;
			WHEN '2' =>			RETURN 2;
			WHEN '3' =>			RETURN 3;
			WHEN '4' =>			RETURN 4;
			WHEN '5' =>			RETURN 5;
			WHEN '6' =>			RETURN 6;
			WHEN '7' =>			RETURN 7;
			WHEN '8' =>			RETURN 8;
			WHEN '9' =>			RETURN 9;
			WHEN OTHERS =>	RETURN -1;
		END CASE;
	END;

	FUNCTION to_nat(str : STRING) RETURN INTEGER IS
		VARIABLE Result			: NATURAL		:= 0;
		VARIABLE Digit			: INTEGER;
	BEGIN
		IF (to_digit(str(str'low)) /= -1) THEN
			FOR I IN str'range LOOP
				Digit	:= to_digit(str(I));
				IF (Digit /= -1) THEN
					Result	:= Result * 10 + Digit;
				ELSE
					EXIT;
				END IF;
			END LOOP;

			RETURN Result;
		ELSE
			RETURN -1;
		END IF;
	END;

	FUNCTION to_sl(Value : BOOLEAN) RETURN STD_LOGIC IS
	BEGIN
		IF (Value = TRUE) THEN
			RETURN '1';
		ELSE
			RETURN '0';
		END IF;
	END;

	FUNCTION to_sl(Value : CHARACTER) RETURN STD_LOGIC IS
	BEGIN
		CASE Value IS
			WHEN 'U' =>			RETURN 'U';
			WHEN 'X' =>			RETURN 'X';
			WHEN '0' =>			RETURN '0';
			WHEN '1' =>			RETURN '1';
			WHEN 'Z' =>			RETURN 'Z';
			WHEN 'W' =>			RETURN 'W';
			WHEN 'L' =>			RETURN 'L';
			WHEN 'H' =>			RETURN 'H';
			WHEN '-' =>			RETURN '-';
			WHEN OTHERS =>	RETURN 'X';
		END CASE;
	END;

	FUNCTION is_sl(char : CHARACTER) RETURN BOOLEAN IS
	BEGIN
		CASE char IS
			WHEN 'U' =>			RETURN TRUE;
			WHEN 'X' =>			RETURN TRUE;
			WHEN '0' =>			RETURN TRUE;
			WHEN '1' =>			RETURN TRUE;
			WHEN 'Z' =>			RETURN TRUE;
			WHEN 'W' =>			RETURN TRUE;
			WHEN 'L' =>			RETURN TRUE;
			WHEN 'H' =>			RETURN TRUE;
			WHEN '-' =>			RETURN TRUE;
			WHEN OTHERS =>	RETURN FALSE;
		END CASE;
	END;

	FUNCTION str_length(str : STRING) RETURN NATURAL IS
		VARIABLE l	: NATURAL		:= 0;
	BEGIN
		FOR I IN str'range LOOP
			IF (str(I) = NUL) THEN
				RETURN l;
			ELSE
				l := l + 1;
			END IF;
		END LOOP;

		RETURN str'length;
	END;

	FUNCTION str_equal(str1 : STRING; str2 : STRING) RETURN BOOLEAN IS
		VARIABLE L				: POSITIVE	:= imin(str_length(str1), str_length(str2));
	BEGIN
		FOR I IN 0 TO L - 1 LOOP
			IF (str1(str1'low + I) /= str2(str2'low + I)) THEN
				RETURN FALSE;
			END IF;
		END LOOP;

		RETURN TRUE;
	END;

	FUNCTION resize(str : STRING; size : POSITIVE) RETURN STRING IS
		CONSTANT MaxLength	: POSITIVE							:= imin(size, str'length);
		VARIABLE Result			: STRING(1 TO size)			:= (OTHERS => nul);
	BEGIN
		Result(1 TO MaxLength) := str(1 TO MaxLength);
		RETURN Result;
	END;

	PROCEDURE VCD_ReadHeader(FILE VCDFile : TEXT; VCDLine : INOUT T_VCDLINE) IS
	BEGIN
		WHILE (NOT endfile(VCDFile)) LOOP
			VCD_ReadLine(VCDFile, VCDLine);

			IF (VCDLine(1) = '#') THEN
				ASSERT (FALSE) REPORT "Header passed" SEVERITY NOTE;
				EXIT;
			END IF;
		END LOOP;
	END;

	PROCEDURE VCD_ReadLine(FILE VCDFile : TEXT; VCDLine : OUT STRING) IS
		VARIABLE l					: LINE;
		VARIABLE c					: CHARACTER;
		VARIABLE is_string	: BOOLEAN;
	BEGIN
		readline(VCDFile, l);

		-- clear VCDLine
		FOR I in VCDLine'range LOOP
			VCDLine(I)		:= NUL;
		END LOOP;

		-- TODO: use imin of ranges, not 'range
		FOR I IN VCDLine'range LOOP
			read(l, c, is_string);
			IF NOT is_string THEN
				EXIT;
			END IF;

			VCDLine(I)	:= c;
		END LOOP;
	END;

	PROCEDURE VCD_Read_StdLogic(VCDLine : STRING; SIGNAL sl : OUT STD_LOGIC; WaveName : STRING) IS
	BEGIN
		IF (str_equal(VCDLine(2 TO VCDLine'high), WaveName)) THEN
			sl	<= to_sl(VCDLine(1));
		END IF;
	END;

	PROCEDURE VCD_Read_StdLogicVector(VCDLine : STRING; SIGNAL slv : OUT STD_LOGIC_VECTOR; WaveName : STRING; def : STD_LOGIC := '0') IS
		VARIABLE Result	: STD_LOGIC_VECTOR(slv'range)			:= (OTHERS => def);
		VARIABLE k			: NATURAL													:= 0;
	BEGIN
		FOR I IN VCDLine'range LOOP
			IF (is_sl(VCDLine(I)) = FALSE) THEN
				k				:= I;
				EXIT;
			ELSE
				Result := Result(Result'high - 1 DOWNTO Result'low) & to_sl(VCDLine(I));
			END IF;
		END LOOP;

		IF (str_equal(VCDLine(k + 1 TO VCDLine'high), WaveName)) THEN
			slv				<= Result;
		END IF;
	END;
END PACKAGE BODY;
