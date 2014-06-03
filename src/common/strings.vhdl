-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Package:					String related functions and types
--
-- Authors:					Thomas B. Preusser
--									Martin Zabel
--									Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		For detailed documentation see below.
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany,
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

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;
use			PoC.utils.all;


package strings is
	-- Type declarations
	-- ===========================================================================
	SUBTYPE T_RAWCHAR				IS STD_LOGIC_VECTOR(7 DOWNTO 0);
	TYPE		T_RAWSTRING			IS ARRAY (NATURAL RANGE <>) OF T_RAWCHAR;
	
	-- testing area:
	-- ===========================================================================
	FUNCTION to_IPStyle(str : STRING)			RETURN T_IPSTYLE;
	
	-- to_char
	FUNCTION to_char(value : STD_LOGIC)		RETURN CHARACTER;
	FUNCTION to_char(value : INTEGER)			RETURN CHARACTER;
	FUNCTION to_char(rawchar : T_RAWCHAR) RETURN CHARACTER;	

	-- to_string
	FUNCTION to_string(value : BOOLEAN) RETURN STRING;	
	FUNCTION to_string(value : INTEGER; base : POSITIVE := 10) RETURN STRING;
	FUNCTION to_string(slv : STD_LOGIC_VECTOR; format : CHARACTER; length : NATURAL := 0; fill : CHARACTER := '0') RETURN STRING;
	FUNCTION to_string(rawstring : T_RAWSTRING) RETURN STRING;

	-- to_*
	FUNCTION to_digit(chr : CHARACTER; base : CHARACTER := 'd') RETURN INTEGER;
	FUNCTION to_nat(str : STRING; base : CHARACTER := 'd') RETURN INTEGER;
	
	-- to_raw*
	FUNCTION to_rawchar(char : CHARACTER) RETURN T_RAWCHAR;
	FUNCTION to_rawstring(stri : STRING)	RETURN T_RAWSTRING;
	
	-- resize
	FUNCTION resize(str : STRING; size : POSITIVE; FillChar : CHARACTER := NUL) RETURN STRING;
	FUNCTION resize(rawstr : T_RAWSTRING; size : POSITIVE; FillChar : T_RAWCHAR := x"00") RETURN T_RAWSTRING;

	-- Character functions
	FUNCTION to_lower(char : CHARACTER) RETURN CHARACTER;
	FUNCTION to_upper(char : CHARACTER) RETURN CHARACTER;
	
	-- String functions
	FUNCTION str_length(str : STRING) RETURN NATURAL;
	FUNCTION str_equal(str1 : STRING; str2 : STRING) RETURN BOOLEAN;
	FUNCTION str_match(str1 : STRING; str2 : STRING) RETURN BOOLEAN;
	FUNCTION str_pos(str : STRING; char : CHARACTER) RETURN INTEGER;
	FUNCTION str_to_lower(str : STRING) RETURN STRING;
	FUNCTION str_to_upper(str : STRING) RETURN STRING;

end package strings;


package body strings is

	-- 
	FUNCTION to_IPStyle(str : STRING) RETURN T_IPSTYLE IS
	BEGIN
		FOR I IN T_IPSTYLE'pos(T_IPSTYLE'low) TO T_IPSTYLE'pos(T_IPSTYLE'high) LOOP
			IF str_match(str_to_upper(str), str_to_upper(T_IPSTYLE'image(T_IPSTYLE'val(I)))) THEN
				RETURN T_IPSTYLE'val(I);
			END IF;
		END LOOP;
		
		REPORT "Unknown IPStyle: " & str SEVERITY FAILURE;
	END FUNCTION;

	-- to_char
	-- ===========================================================================
	FUNCTION to_char(value : STD_LOGIC) RETURN CHARACTER IS
	BEGIN
		CASE value IS
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
	END FUNCTION;

	FUNCTION to_char(value : INTEGER) RETURN CHARACTER IS
	BEGIN
		CASE value IS
			WHEN	0 =>			RETURN '0';
			WHEN	1 =>			RETURN '1';
			WHEN	2 =>			RETURN '2';
			WHEN	3 =>			RETURN '3';
			WHEN	4 =>			RETURN '4';
			WHEN	5 =>			RETURN '5';
			WHEN	6 =>			RETURN '6';
			WHEN	7 =>			RETURN '7';
			WHEN	8 =>			RETURN '8';
			WHEN	9 =>			RETURN '9';
			WHEN 10 =>			RETURN 'A';
			WHEN 11 =>			RETURN 'B';
			WHEN 12 =>			RETURN 'C';
			WHEN 13 =>			RETURN 'D';
			WHEN 14 =>			RETURN 'E';
			WHEN 15 =>			RETURN 'F';
			WHEN OTHERS =>	RETURN 'X';
		END CASE;
	END FUNCTION;

	FUNCTION to_char(rawchar : T_RAWCHAR) RETURN CHARACTER IS
	BEGIN
		RETURN CHARACTER'val(to_integer(unsigned(rawchar)));
	END;

	-- to_string
	-- ===========================================================================
	FUNCTION to_string(value : BOOLEAN) RETURN STRING IS
	BEGIN
		RETURN ite(value, "TRUE", "FALSE");
	END FUNCTION;

	FUNCTION to_string(value : INTEGER; base : POSITIVE := 10) RETURN STRING IS
		CONSTANT absValue		: NATURAL								:= abs(value);
		CONSTANT len		 		: POSITIVE							:= log10ceilnz(absValue);
		VARIABLE power			: POSITIVE							:= 1;
		VARIABLE Result			: STRING(1 TO len);

	BEGIN
		IF (base = 10) THEN
			RETURN INTEGER'image(value);
		ELSE
			FOR i IN len DOWNTO 1 LOOP
				Result(i)		:= to_char(absValue / power MOD base);
				power				:= power * base;
			END LOOP;

			IF (value < 0) THEN
				RETURN '-' & Result;
			ELSE
				RETURN Result;
			END IF;
		END IF;
	END FUNCTION;

	FUNCTION to_string(slv : STD_LOGIC_VECTOR; format : CHARACTER; length : NATURAL := 0; fill : CHARACTER := '0') RETURN STRING IS
		CONSTANT int					: INTEGER				:= ite((slv'length <= 31), to_integer(unsigned(resize(slv, 31))), 0);
		CONSTANT str					: STRING				:= INTEGER'image(int);
		CONSTANT bin_len			: POSITIVE			:= slv'length;
		CONSTANT dec_len			: POSITIVE			:= str'length;--log10ceilnz(int);
		CONSTANT hex_len			: POSITIVE			:= ite(((bin_len MOD 4) = 0), (bin_len / 4), (bin_len / 4) + 1);
		CONSTANT len					: NATURAL				:= ite((format = 'b'), bin_len,
																						 ite((format = 'd'), dec_len,
																						 ite((format = 'h'), hex_len, 0)));
		
		VARIABLE j						: NATURAL				:= 0;
		VARIABLE Result				: STRING(1 TO ite((length = 0), len, imax(len, length)))	:= (OTHERS => fill);
		
	BEGIN
		IF (format = 'b') THEN
			FOR i IN Result'reverse_range LOOP
				Result(i)		:= to_char(slv(j));
				j						:= j + 1;
			END LOOP;
		ELSIF (format = 'd') THEN
			Result(Result'length - str'length + 1 TO Result'high)	:= str;
		ELSIF (format = 'h') THEN
			FOR i IN Result'reverse_range LOOP
				Result(i)		:= to_char(to_integer(unsigned(slv((j * 4) + 3 DOWNTO (j * 4)))));
				j						:= j + 1;
			END LOOP;
		ELSE
			REPORT "unknown format" SEVERITY FAILURE;
		END IF;
		
		RETURN Result;
	END FUNCTION;

	FUNCTION to_string(rawstring : T_RAWSTRING) RETURN STRING IS
		VARIABLE str		: STRING(1 TO rawstring'length);
	BEGIN
		FOR I IN rawstring'low TO rawstring'high LOOP
			str(I - rawstring'low + 1)	:= to_char(rawstring(I));
		END LOOP;
	
		RETURN str;
	END;

	-- to_*
	-- ===========================================================================
	FUNCTION to_digit(chr : CHARACTER; base : CHARACTER := 'd') RETURN INTEGER IS
	BEGIN
		CASE base IS
			WHEN 'd' =>
				CASE chr IS
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
			
			WHEN 'h' =>
				CASE chr IS
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
					WHEN 'a' =>			RETURN 10;
					WHEN 'b' =>			RETURN 11;
					WHEN 'c' =>			RETURN 12;
					WHEN 'd' =>			RETURN 13;
					WHEN 'e' =>			RETURN 14;
					WHEN 'f' =>			RETURN 15;
					WHEN 'A' =>			RETURN 10;
					WHEN 'B' =>			RETURN 11;
					WHEN 'C' =>			RETURN 12;
					WHEN 'D' =>			RETURN 13;
					WHEN 'E' =>			RETURN 14;
					WHEN 'F' =>			RETURN 15;
					WHEN OTHERS =>	RETURN -1;
				END CASE;
			
			WHEN OTHERS =>
				REPORT "unknown base" SEVERITY ERROR;
				RETURN -1;
				
		END CASE;
	END FUNCTION;

	FUNCTION to_nat(str : STRING; base : CHARACTER := 'd') RETURN INTEGER IS
		VARIABLE Result			: NATURAL		:= 0;
		VARIABLE Digit			: INTEGER;
		VARIABLE b					: INTEGER;
	BEGIN
		CASE base IS
			WHEN 'd' =>			b := 10;
			WHEN 'h' =>			b := 16;
			WHEN OTHERS =>	REPORT "unknown base" SEVERITY ERROR;
		END CASE;
	
		IF (to_digit(str(str'low), base) /= -1) THEN
			FOR I IN str'range LOOP
				Digit	:= to_digit(str(I), base);
				IF (Digit /= -1) THEN
					Result	:= Result * b + Digit;
				ELSE
					RETURN -1;
				END IF;
			END LOOP;
				
			RETURN Result;
		ELSE
			RETURN -1;
		END IF;
	END FUNCTION;

	-- to_raw*
	-- ===========================================================================
	FUNCTION to_rawchar(char : CHARACTER) RETURN T_RAWCHAR IS
	BEGIN
		RETURN std_logic_vector(to_unsigned(CHARACTER'pos(char), T_RAWCHAR'length));
	END;

	FUNCTION to_rawstring(stri : STRING) RETURN T_RAWSTRING IS
		VARIABLE rawstr			: T_RAWSTRING(0 TO stri'length - 1);
	BEGIN
		FOR I IN stri'low TO stri'high LOOP
			rawstr(I - stri'low)	:= to_rawchar(stri(I));
		END LOOP;
	
		RETURN rawstr;
	END;

	-- resize
	-- ===========================================================================
	FUNCTION resize(str : STRING; size : POSITIVE; FillChar : CHARACTER := NUL) RETURN STRING IS
		CONSTANT MaxLength	: POSITIVE							:= imin(size, str'length);
		VARIABLE Result			: STRING(1 TO size)			:= (OTHERS => FillChar);
	BEGIN
		Result(1 TO MaxLength) := str(1 TO MaxLength);
		RETURN Result;
	END FUNCTION;

	FUNCTION resize(rawstr : T_RAWSTRING; size : POSITIVE; FillChar : T_RAWCHAR := x"00") RETURN T_RAWSTRING IS
		CONSTANT MaxLength	: POSITIVE																					:= imin(size, rawstr'length);
		VARIABLE Result			: T_RAWSTRING(rawstr'low TO rawstr'low + size - 1)	:= (OTHERS => FillChar);
	BEGIN
		Result(rawstr'low TO rawstr'low + MaxLength - 1) := rawstr(rawstr'low TO rawstr'low + MaxLength - 1);
		RETURN Result;
	END;

	-- Character functions
	-- ===========================================================================
	FUNCTION to_lower(char : CHARACTER) RETURN CHARACTER IS
	BEGIN
		IF ((CHARACTER'pos('A') <= CHARACTER'pos(char)) AND (CHARACTER'pos(char) <= CHARACTER'pos('Z'))) THEN
			RETURN CHARACTER'val(CHARACTER'pos(char) + (CHARACTER'pos('a') - CHARACTER'pos('A')));
		ELSE
			RETURN char;
		END IF;
	END FUNCTION;
	
	FUNCTION to_upper(char : CHARACTER) RETURN CHARACTER IS
	BEGIN
		IF ((CHARACTER'pos('a') <= CHARACTER'pos(char)) AND (CHARACTER'pos(char) <= CHARACTER'pos('z'))) THEN
			RETURN CHARACTER'val(CHARACTER'pos(char) - (CHARACTER'pos('a') - CHARACTER'pos('A')));
		ELSE
			RETURN char;
		END IF;	
	END FUNCTION;
	
	-- String functions
	-- ===========================================================================
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
	END FUNCTION;
	
	FUNCTION str_equal(str1 : STRING; str2 : STRING) RETURN BOOLEAN IS
	BEGIN
		IF str1'length /= str2'length THEN
			RETURN FALSE;
		ELSE
			RETURN (str1 = str2);
		END IF;
	END FUNCTION;

	FUNCTION str_match(str1 : STRING; str2 : STRING) RETURN BOOLEAN IS
	BEGIN
		IF str_length(str1) /= str_length(str2) THEN
			RETURN FALSE;
		ELSE
			RETURN (resize(str1, str_length(str1)) = resize(str2, str_length(str1)));
		END IF;
	END FUNCTION;

	FUNCTION str_pos(str : STRING; char : CHARACTER) RETURN INTEGER IS
	BEGIN
		FOR I IN str'range LOOP
			EXIT WHEN (str(I) = NUL);
			IF (str(I) = char) THEN
				RETURN I;
			END IF;
		END LOOP;
		RETURN -1;
	END FUNCTION;
	
	FUNCTION str_to_lower(str : STRING) RETURN STRING IS
		VARIABLE temp		: STRING(str'range);
	BEGIN
		FOR I IN str'range LOOP
			temp(I)	:= to_lower(str(I));
		END LOOP;
		RETURN temp;
	END FUNCTION;
	
	FUNCTION str_to_upper(str : STRING) RETURN STRING IS
		VARIABLE temp		: STRING(str'range);
	BEGIN
		FOR I IN str'range LOOP
			temp(I)	:= to_upper(str(I));
		END LOOP;
		RETURN temp;
	END FUNCTION;
	
end strings;
