-- EMACS settings: -*-	tab-width:2	-*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ===========================================================================
-- Description:		Common functions
--
-- Authors:				Thomas B. Preusser
--								Martin Zabel
--								Patrick Lehmann
-- ===========================================================================
-- Copyright 2007-2014 Technische Universität Dresden - Germany
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
-- ===========================================================================

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;


package functions is
	-- ==========================================================================================================================================================
	-- Type declarations
	-- ==========================================================================================================================================================
	-- BOOLEAN_VECTOR
	TYPE		T_BOOLVEC						IS ARRAY(NATURAL RANGE <>) OF BOOLEAN;
	-- INTEGER_VECTORs
	TYPE		T_INTVEC						IS ARRAY(NATURAL RANGE <>) OF INTEGER;
	TYPE		T_NATVEC						IS ARRAY(NATURAL RANGE <>) OF NATURAL;
	TYPE		T_POSVEC						IS ARRAY(NATURAL RANGE <>) OF POSITIVE;
	
	-- INTEGERs
	SUBTYPE T_UINT_8						IS INTEGER RANGE 0 TO 255;
	SUBTYPE T_UINT_16						IS INTEGER RANGE 0 TO 65535;
	
	-- STD_LOGIC_VECTORs
	SUBTYPE T_SLV_2							IS STD_LOGIC_VECTOR(1 DOWNTO 0);
	SUBTYPE T_SLV_3							IS STD_LOGIC_VECTOR(2 DOWNTO 0);
	SUBTYPE T_SLV_4							IS STD_LOGIC_VECTOR(3 DOWNTO 0);
	SUBTYPE T_SLV_8							IS STD_LOGIC_VECTOR(7 DOWNTO 0);
	SUBTYPE T_SLV_12						IS STD_LOGIC_VECTOR(11 DOWNTO 0);
	SUBTYPE T_SLV_16						IS STD_LOGIC_VECTOR(15 DOWNTO 0);
	SUBTYPE T_SLV_24						IS STD_LOGIC_VECTOR(23 DOWNTO 0);
	SUBTYPE T_SLV_32						IS STD_LOGIC_VECTOR(31 DOWNTO 0);
	SUBTYPE T_SLV_48						IS STD_LOGIC_VECTOR(47 DOWNTO 0);
	SUBTYPE T_SLV_64						IS STD_LOGIC_VECTOR(63 DOWNTO 0);
	SUBTYPE T_SLV_96						IS STD_LOGIC_VECTOR(95 DOWNTO 0);
	SUBTYPE T_SLV_128						IS STD_LOGIC_VECTOR(127 DOWNTO 0);
	
	-- STD_LOGIC_VECTOR_VECTORs
--	TYPE		T_SLVV							IS ARRAY(NATURAL RANGE <>) OF STD_LOGIC_VECTOR;					-- VHDL 2008 syntax - not yet supported by Xilinx
	TYPE		T_SLVV_2						IS ARRAY(NATURAL RANGE <>) OF T_SLV_2;
	TYPE		T_SLVV_3						IS ARRAY(NATURAL RANGE <>) OF T_SLV_3;
	TYPE		T_SLVV_4						IS ARRAY(NATURAL RANGE <>) OF T_SLV_4;
	TYPE		T_SLVV_8						IS ARRAY(NATURAL RANGE <>) OF T_SLV_8;
	TYPE		T_SLVV_12						IS ARRAY(NATURAL RANGE <>) OF T_SLV_12;
	TYPE		T_SLVV_16						IS ARRAY(NATURAL RANGE <>) OF T_SLV_16;
	TYPE		T_SLVV_24						IS ARRAY(NATURAL RANGE <>) OF T_SLV_24;
	TYPE		T_SLVV_32						IS ARRAY(NATURAL RANGE <>) OF T_SLV_32;
	TYPE		T_SLVV_48						IS ARRAY(NATURAL RANGE <>) OF T_SLV_48;
	TYPE		T_SLVV_64						IS ARRAY(NATURAL RANGE <>) OF T_SLV_64;
	TYPE		T_SLVV_128					IS ARRAY(NATURAL RANGE <>) OF T_SLV_128;

	-- STD_LOGIC_MATRIXs
	TYPE		T_SLM								IS ARRAY(NATURAL RANGE <>, NATURAL RANGE <>) OF STD_LOGIC;
	-- ATTENTION:
	-- 1.	you MUST initialize your matrix signal with 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	--		Example: SIGNAL myMatrix	: T_SLM(3 DOWNTO 0, 7 DOWNTO 0)			:= (OTHERS => (OTHERS => 'Z'));
	-- 2.	Xilinx iSIM work-around: DON'T use myMatrix'range(n) for n >= 2
	--		because: myMatrix'range(2) returns always myMatrix'range(1);	tested with ISE/iSIM 14.2
	-- USAGE NOTES:
	--	dimmension 1 => rows			- e.g. Words
	--	dimmension 2 => columns		- e.g. Bits/Bytes in a word

	-- Intellectual Property (IP) type
	TYPE T_IPSTYLE			IS (IPSTYLE_HARD, IPSTYLE_SOFT);
	
	-- Bit and byte order types
	TYPE T_BIT_ORDER		IS (LSB_FIRST, MSB_FIRST);
	TYPE T_BYTE_ORDER		IS (LITTLE_ENDIAN, BIG_ENDIAN);


	-- Function declarations
	-- ==========================================================================================================================================================
	
	-- Environment
	function IS_SIMULATION return boolean;													-- Forward declaration; consider this function PRIVATE
	constant SIMULATION		: boolean		:= IS_SIMULATION;							-- Distinguishes Simulation from Synthesis
	
	-- Divisions: div_*
	FUNCTION div_ceil(a : NATURAL; b : POSITIVE) RETURN NATURAL;		-- Calculates: ceil(a / b)
	
	-- Power functions: *_pow2
	FUNCTION is_pow2(int : NATURAL)			RETURN BOOLEAN;							-- is input a power of 2?
	FUNCTION ceil_pow2(int : NATURAL)		RETURN POSITIVE;						-- round to next power of 2
	FUNCTION floor_pow2(int : NATURAL)	RETURN NATURAL;							-- round to previous power of 2

	-- Logarithms: log*ceil*
	function log2ceil(arg			: positive) return natural;						-- Calculates: ceil(ld(arg))
	function log2ceilnz(arg		: positive) return positive;					-- Calculates: max(1, ceil(ld(arg)))
	FUNCTION log10ceil(arg		: POSITIVE)	RETURN NATURAL;						-- calculates: ceil(lg(arg))
	FUNCTION log10ceilnz(arg	: POSITIVE)	RETURN POSITIVE;					-- calculates: max(1, ceil(lg(arg)))
	
 	-- *min / *max / *sum
	function imin(arg1 : integer; arg2 : integer) return integer;		-- Calculates: min(arg1, arg2) for integers
	FUNCTION imin(vec : T_INTVEC) RETURN INTEGER;										-- Calculates: min(vector) for a integer vector
	FUNCTION imin(vec : T_NATVEC) RETURN NATURAL;										-- Calculates: min(vector) for a natural vector
	FUNCTION imin(vec : T_POSVEC) RETURN POSITIVE;									-- Calculates: min(vector) for a positive vector
	function imax(arg1 : integer; arg2 : integer) return integer;		-- Calculates: max(arg1, arg2) for integers
	FUNCTION imax(vec : T_INTVEC) RETURN INTEGER;										-- Calculates: max(vector) for a integer vector
	FUNCTION imax(vec : T_NATVEC) RETURN NATURAL;										-- Calculates: max(vector) for a natural vector
	FUNCTION imax(vec : T_POSVEC) RETURN POSITIVE;									-- Calculates: max(vector) for a positive vector
	FUNCTION isum(vec : T_NATVEC) RETURN NATURAL;										-- Calculates: sum(vector) for a natural vector
	FUNCTION isum(vec : T_POSVEC) RETURN POSITIVE;									-- Calculates: sum(vector) for a positive vector

	function rmin(arg1 : real; arg2 : real) return real;						-- Calculates: min(arg1, arg2) for reals
	function rmax(arg1 : real; arg2 : real) return real;						-- Calculates: max(arg1, arg2) for reals

	-- slicing boundary calulations
	FUNCTION low(LengthVector		: T_POSVEC; pos : NATURAL) RETURN NATURAL;
	FUNCTION high(LengthVector	: T_POSVEC; pos : NATURAL) RETURN NATURAL;

	-- Vector aggregate functions: slv_*
	FUNCTION slv_or(Vector		: STD_LOGIC_VECTOR)	RETURN STD_LOGIC;
	FUNCTION slv_nor(Vector		: STD_LOGIC_VECTOR)	RETURN STD_LOGIC;
	FUNCTION slv_and(Vector		: STD_LOGIC_VECTOR)	RETURN STD_LOGIC;
	FUNCTION slv_nand(Vector	: STD_LOGIC_VECTOR)	RETURN STD_LOGIC;

	-- Assign procedures: assign_*
	PROCEDURE assign_row(SIGNAL slm : OUT T_SLM; SIGNAL slv : STD_LOGIC_VECTOR; CONSTANT RowIndex : NATURAL);																	-- assign vector to complete row
	PROCEDURE assign_row(SIGNAL slm : OUT T_SLM; SIGNAL slv : STD_LOGIC_VECTOR; CONSTANT RowIndex : NATURAL; Position : NATURAL);							-- assign short vector to row starting at position
	PROCEDURE assign_row(SIGNAL slm : OUT T_SLM; SIGNAL slv : STD_LOGIC_VECTOR; CONSTANT RowIndex : NATURAL; High : NATURAL; Low : NATURAL);	-- assign short vector to row in range high:low
	PROCEDURE assign_col(SIGNAL slm : OUT T_SLM; SIGNAL slv : STD_LOGIC_VECTOR; CONSTANT ColIndex : NATURAL);																	-- assign vector to complete column
	-- ATTENTION:	see T_SLM definition for further details and work-arounds

	-- Matrix to matrix conversion: slm_slice*
	FUNCTION slm_slice(slm : T_SLM; RowIndex : NATURAL; ColIndex : NATURAL; Height : NATURAL; Width : NATURAL) RETURN T_SLM;									-- get submatrix in boundingbox RowIndex,ColIndex,Height,Width
--	FUNCTION slm_slice_cols(slm : T_SLM; High : NATURAL; Low : NATURAL) RETURN T_SLM;																													-- get submatrix / all columns in ColIndex range high:low
	-- FIXME: changed arguments low,high to high,low => removed declaration to find all uages of this function

	-- Matrix to vector conversion: get_*
	FUNCTION get_col(slm : T_SLM; ColIndex : NATURAL) RETURN STD_LOGIC_VECTOR;																	-- get a matrix column
	FUNCTION get_row(slm : T_SLM; RowIndex : NATURAL)	RETURN STD_LOGIC_VECTOR;																	-- get a matrix row
	FUNCTION get_row(slm : T_SLM; RowIndex : NATURAL; Length : POSITIVE)	RETURN STD_LOGIC_VECTOR;							-- get a matrix row of defined length [length - 1 downto 0]
	FUNCTION get_row(slm : T_SLM; RowIndex : NATURAL; High : NATURAL; Low : NATURAL) RETURN STD_LOGIC_VECTOR;		-- get a sub vector of a matrix row at high:low
	
	-- Convert to bit: to_sl
	FUNCTION to_sl(Value : BOOLEAN)		RETURN STD_LOGIC;
	FUNCTION to_sl(Value : CHARACTER) RETURN STD_LOGIC;

	-- Convert to vector: to_slv
	FUNCTION to_slv(Value : NATURAL; Size : POSITIVE)		RETURN STD_LOGIC_VECTOR;					-- short for std_logic_vector(to_unsigned(Value, Size))
	FUNCTION to_slv(slvv : T_SLVV_8)										RETURN STD_LOGIC_VECTOR;					-- convert vector-vector to flatten vector
	
	-- Convert flat vector to avector-vector: to_slvv_*
	FUNCTION to_slvv_4(slv : STD_LOGIC_VECTOR)		RETURN T_SLVV_4;												-- 
	FUNCTION to_slvv_8(slv : STD_LOGIC_VECTOR)		RETURN T_SLVV_8;												-- 
	FUNCTION to_slvv_12(slv : STD_LOGIC_VECTOR)		RETURN T_SLVV_12;												-- 
	FUNCTION to_slvv_16(slv : STD_LOGIC_VECTOR)		RETURN T_SLVV_16;												-- 
	FUNCTION to_slvv_32(slv : STD_LOGIC_VECTOR)		RETURN T_SLVV_32;												-- 
	FUNCTION to_slvv_64(slv : STD_LOGIC_VECTOR)		RETURN T_SLVV_64;												-- 
	FUNCTION to_slvv_128(slv : STD_LOGIC_VECTOR)	RETURN T_SLVV_128;											-- 

	-- Convert matrix to avector-vector: to_slvv_*
	FUNCTION to_slvv_4(slm : T_SLM)		RETURN T_SLVV_4;																		-- 
	FUNCTION to_slvv_8(slm : T_SLM)		RETURN T_SLVV_8;																		-- 
	FUNCTION to_slvv_12(slm : T_SLM)	RETURN T_SLVV_12;																		-- 
	FUNCTION to_slvv_16(slm : T_SLM)	RETURN T_SLVV_16;																		-- 
	FUNCTION to_slvv_32(slm : T_SLM)	RETURN T_SLVV_32;																		-- 
	FUNCTION to_slvv_64(slm : T_SLM)	RETURN T_SLVV_64;																		-- 
	FUNCTION to_slvv_128(slm : T_SLM)	RETURN T_SLVV_128;																	-- 
	
	-- Convert vector-vector to matrix: to_slm
	FUNCTION to_slm(slvv : T_SLVV_4) RETURN T_SLM;																				-- create matrix from vector-vector
	FUNCTION to_slm(slvv : T_SLVV_8) RETURN T_SLM;																				-- create matrix from vector-vector
	FUNCTION to_slm(slvv : T_SLVV_12) RETURN T_SLM;																				-- create matrix from vector-vector
	FUNCTION to_slm(slvv : T_SLVV_16) RETURN T_SLM;																				-- create matrix from vector-vector
	FUNCTION to_slm(slvv : T_SLVV_32) RETURN T_SLM;																				-- create matrix from vector-vector
	FUNCTION to_slm(slvv : T_SLVV_48) RETURN T_SLM;																				-- create matrix from vector-vector
	FUNCTION to_slm(slvv : T_SLVV_64) RETURN T_SLM;																				-- create matrix from vector-vector
	FUNCTION to_slm(slvv : T_SLVV_128) RETURN T_SLM;																			-- create matrix from vector-vector
	
	-- to_char
	FUNCTION to_char(value : STD_LOGIC)		RETURN CHARACTER;
	FUNCTION to_char(value : INTEGER)			RETURN CHARACTER;

	-- to_string
	FUNCTION to_string(value : BOOLEAN) RETURN STRING;	
	FUNCTION to_string(value : INTEGER; base : POSITIVE := 10) RETURN STRING;
	FUNCTION to_string(slv : STD_LOGIC_VECTOR; format : CHARACTER; length : NATURAL := 0; fill : CHARACTER := '0') RETURN STRING;
	FUNCTION to_string(slvv : T_SLVV_8; sep : CHARACTER := ':') RETURN STRING;

	-- to_*
	FUNCTION to_digit(chr : CHARACTER; base : CHARACTER := 'd') RETURN INTEGER;
	FUNCTION to_nat(str : STRING; base : CHARACTER := 'd') RETURN INTEGER;
	FUNCTION to_index(slv : STD_LOGIC_VECTOR; max : NATURAL := 0) RETURN INTEGER;
	
	-- is_*
	FUNCTION is_sl(c : CHARACTER) RETURN BOOLEAN;

	-- Change vector direction
	FUNCTION dir(slvv : T_SLVV_8)			RETURN T_SLVV_8;
	
	-- Reverse vector elements
	function reverse(vec : std_logic_vector) return std_logic_vector;			-- be the return Vector cev; then: vec(i) = cev(i) but vec'reverse_range = cev'range
	function reverse(vec : unsigned)				 return unsigned;
	
	FUNCTION rev(slvv : T_SLVV_4)			RETURN T_SLVV_4;
	FUNCTION rev(slvv : T_SLVV_8)			RETURN T_SLVV_8;
	FUNCTION rev(slvv : T_SLVV_12)		RETURN T_SLVV_12;
	FUNCTION rev(slvv : T_SLVV_16)		RETURN T_SLVV_16;
	FUNCTION rev(slvv : T_SLVV_32)		RETURN T_SLVV_32;
	FUNCTION rev(slvv : T_SLVV_64)		RETURN T_SLVV_64;
	FUNCTION rev(slvv : T_SLVV_128)		RETURN T_SLVV_128;
	
	-- Swap sub vectors in vector
	FUNCTION swap(slv : STD_LOGIC_VECTOR; Size : POSITIVE) RETURN STD_LOGIC_VECTOR;

	-- binary encoding conversion functions
	FUNCTION onehot2bin(onehot : STD_LOGIC_VECTOR; ReportError : BOOLEAN := FALSE) RETURN STD_LOGIC_VECTOR;			-- One-Hot-Code to Binary-Code
	FUNCTION onehot2bin_us(onehot : STD_LOGIC_VECTOR; ReportError : BOOLEAN := FALSE) RETURN UNSIGNED;						-- One-Hot-Code to Binary-Code
	function gray2bin(gray_val : std_logic_vector) return std_logic_vector;		-- Gray-Code to Binary-Code
	
	-- bit searching / bit indices
	function lssb(arg : std_logic_vector) return std_logic_vector;	-- Least-Significant Set Bit (lssb): computes a vector of the same length with at most one bit set at the rightmost '1' found in arg.
	function mssb(arg : std_logic_vector) return std_logic_vector;	-- Most-Significant Set Bit (mssb): computes a vector of the same length with at most one bit set at the leftmost '1' found in arg.

	function lssb_idx(arg : std_logic_vector; ReportError : boolean := false) return std_logic_vector;		-- NOTE: to ensure compatibily with old PoC.functions, use lssb_idx(..., true)
	function mssb_idx(arg : std_logic_vector; ReportError : boolean := false) return std_logic_vector;

	-- if-then-else (ite)
	FUNCTION ite(cond : BOOLEAN; value1 : INTEGER; value2 : INTEGER) RETURN INTEGER;
	FUNCTION ite(cond : BOOLEAN; value1 : REAL;	value2 : REAL) RETURN REAL;
	FUNCTION ite(cond : BOOLEAN; value1 : STD_LOGIC; value2 : STD_LOGIC) RETURN STD_LOGIC;
	FUNCTION ite(cond : BOOLEAN; value1 : STD_LOGIC_VECTOR; value2 : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;
	FUNCTION ite(cond : BOOLEAN; value1 : UNSIGNED; value2 : UNSIGNED) RETURN UNSIGNED;
	FUNCTION ite(cond : BOOLEAN; value1 : CHARACTER; value2 : CHARACTER) RETURN CHARACTER;
	FUNCTION ite(cond : BOOLEAN; value1 : STRING; value2 : STRING) RETURN STRING;
	
	-- resize
	function resize(vec : bit_vector; length : natural; fill : bit := '0')	return bit_vector;
	function resize(vec : std_logic_vector; length : natural; fill : std_logic := '0') return std_logic_vector;
	-- NOTE: Use the resize functions of the numeric_std package for value-preserving resizes of the signed and unsigned data types.

	FUNCTION resize(slm : T_SLM; size : POSITIVE) RETURN T_SLM;
	FUNCTION resize(str : STRING; size : POSITIVE; FillChar : CHARACTER := NUL) RETURN STRING;

	-- Move vector boundaries
	FUNCTION move(slv : STD_LOGIC_VECTOR; pos : INTEGER) RETURN STD_LOGIC_VECTOR;

	-- Character functions
	FUNCTION to_lower(char : CHARACTER) RETURN CHARACTER;
	FUNCTION to_upper(char : CHARACTER) RETURN CHARACTER;
	
	-- String functions
	FUNCTION str_length(str : STRING) RETURN NATURAL;
	FUNCTION str_equal(str1 : STRING; str2 : STRING) RETURN BOOLEAN;
	FUNCTION str_pos(str : STRING; char : CHARACTER) RETURN INTEGER;
	FUNCTION str_to_lower(str : STRING) RETURN STRING;
	FUNCTION str_to_upper(str : STRING) RETURN STRING;

	-- Calculates the length of a vector discounting leading Zeros
	-- The minimum length returned is 1 even if the whole vector is zeros.
	function length(arg : bit_vector)			 return positive;
	function length(arg : std_logic_vector) return positive;
	-- FIXME: this is max(1, mssb_idx) not length; vectors have already a fixed length

end package functions;

--library IEEE;
--use IEEE.numeric_std.all;

package body functions is

	-- Environment
	function IS_SIMULATION return boolean is
		variable ret : boolean := false;
	begin
		--synthesis translate_off
		if Is_X('X') then ret := true; end if;
		--synthesis translate_on
		return	ret;
	end function;

	-- Divisions: div_*
	FUNCTION div_ceil(a : NATURAL; b : POSITIVE) RETURN NATURAL IS	-- calculates: ceil(a / b)
	BEGIN
		RETURN (a + (b - 1)) / b;
	END FUNCTION;

	-- Power functions: *_pow2
	-- ==========================================================================================================================================================
	-- is input a power of 2?
	FUNCTION is_pow2(int : NATURAL) RETURN BOOLEAN IS
	BEGIN
		RETURN ((to_unsigned(int, 32) AND to_unsigned(int - 1, 32)) = 0);
	END FUNCTION;
	
	-- round to next power of 2
	FUNCTION ceil_pow2(int : NATURAL) RETURN POSITIVE IS
	BEGIN
		RETURN 2 ** log2ceil(int);
	END FUNCTION;
	
	-- round to previous power of 2
	FUNCTION floor_pow2(int : NATURAL) RETURN NATURAL IS
		VARIABLE temp : UNSIGNED(30 DOWNTO 0)	:= to_unsigned(int, 31);
	BEGIN
		FOR I IN temp'range LOOP
			IF (temp(I) = '1') THEN
				RETURN 2 ** I;
			END IF;
		END LOOP;
		RETURN 0;
	END FUNCTION;

	-- Logarithms: log*ceil*
	function log2ceil(arg : positive) return natural is
		variable tmp : positive		:= 1;
		variable log : natural		:= 0;
	begin
		if arg = 1 then	return 0; end if;
		while arg > tmp loop
			tmp := tmp * 2;
			log := log + 1;
		end loop;
		return log;
	end function;

	function log2ceilnz(arg : positive) return positive is
	begin
		return imax(1, log2ceil(arg));
	end function;

	function log10ceil(arg : positive) return natural is
		variable tmp : positive		:= 1;
		variable log : natural		:= 0;
	begin
		if arg = 1 then	return 0; end if;
		while arg > tmp loop
			tmp := tmp * 10;
			log := log + 1;
		end loop;
		return log;
	end function;

	function log10ceilnz(arg : positive) return positive is
	begin
		return imax(1, log10ceil(arg));
	end function;
	
	-- *min / *max / *sum
	function imin(arg1 : integer; arg2 : integer) return integer is
	begin
		if arg1 < arg2 then return arg1; end if;
		return arg2;
	end function;

	FUNCTION imin(vec : T_INTVEC) RETURN INTEGER IS
		VARIABLE Result		: INTEGER		:= INTEGER'high;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) < Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION imin(vec : T_NATVEC) RETURN NATURAL IS
		VARIABLE Result		: INTEGER		:= NATURAL'high;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) < Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION imin(vec : T_POSVEC) RETURN POSITIVE IS
		VARIABLE Result		: INTEGER		:= POSITIVE'high;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) < Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;

	function imax(arg1 : integer; arg2 : integer) return integer is
	begin
		if arg1 > arg2 then return arg1; end if;
		return arg2;
	end function;

	FUNCTION imax(vec : T_INTVEC) RETURN INTEGER IS
		VARIABLE Result		: INTEGER		:= INTEGER'low;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) > Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION imax(vec : T_NATVEC) RETURN NATURAL IS
		VARIABLE Result		: INTEGER		:= NATURAL'low;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) > Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION imax(vec : T_POSVEC) RETURN POSITIVE IS
		VARIABLE Result		: INTEGER		:= POSITIVE'low;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) > Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;

	FUNCTION isum(vec : T_NATVEC) RETURN NATURAL IS
		VARIABLE Result		: NATURAL		:= 0;
	BEGIN
		FOR I IN vec'range LOOP
			Result	:= Result + vec(I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION isum(vec : T_POSVEC) RETURN POSITIVE IS
		VARIABLE Result		: NATURAL	:= 0;
	BEGIN
		FOR I IN vec'range LOOP
			Result	:= Result + vec(I);
		END LOOP;
		RETURN Result;
	END FUNCTION;

	function rmin(arg1 : real; arg2 : real) return real is
	begin
		if arg1 < arg2 then return arg1; end if;
		return arg2;
	end function;

	function rmax(arg1 : real; arg2 : real) return real is
	begin
		if arg1 > arg2 then return arg1; end if;
		return arg2;
	end function;

	-- slicing boundary calulations
	FUNCTION low(lenvec : T_POSVEC; index : NATURAL) RETURN NATURAL IS
		VARIABLE pos		: NATURAL		:= 0;
	BEGIN
		FOR I IN lenvec'low TO index - 1 LOOP
			pos := pos + lenvec(I);
		END LOOP;
		RETURN pos;
	END FUNCTION;
	
	FUNCTION high(lenvec : T_POSVEC; index : NATURAL) RETURN NATURAL IS
		VARIABLE pos		: NATURAL		:= 0;
	BEGIN
		FOR I IN lenvec'low TO index LOOP
			pos := pos + lenvec(I);
		END LOOP;
		RETURN pos - 1;
	END FUNCTION;

	-- Vector aggregate functions: slv_*
	FUNCTION slv_or(Vector : STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
		VARIABLE Result : STD_LOGIC := '0';
	BEGIN
		FOR i IN Vector'range LOOP
			Result	:= Result OR Vector(i);
		END LOOP;
		RETURN Result;
	END FUNCTION;

	FUNCTION slv_nor(Vector : STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
	BEGIN
		RETURN NOT slv_or(Vector);
	END FUNCTION;

	FUNCTION slv_and(Vector : STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
		VARIABLE Result : STD_LOGIC := '1';
	BEGIN
		FOR i IN Vector'range LOOP
			Result	:= Result AND Vector(i);
		END LOOP;
		RETURN Result;
	END FUNCTION;

	FUNCTION slv_nand(Vector : STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
	BEGIN
		RETURN NOT slv_and(Vector);
	END FUNCTION;

	-- Assign procedures: assign_*
	PROCEDURE assign_row(SIGNAL slm : OUT T_SLM; SIGNAL slv : STD_LOGIC_VECTOR; CONSTANT RowIndex : NATURAL) IS
		VARIABLE temp : STD_LOGIC_VECTOR(slm'high(2) DOWNTO slm'low(2));					-- Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); tested with ISE/iSIM 14.2
	BEGIN
		temp := slv;
		FOR I IN temp'range LOOP
			slm(RowIndex, I)  <= temp(I);
		END LOOP;
	END PROCEDURE;
	
	PROCEDURE assign_row(SIGNAL slm : OUT T_SLM; SIGNAL slv : STD_LOGIC_VECTOR; CONSTANT RowIndex : NATURAL; Position : NATURAL) IS
		VARIABLE temp : STD_LOGIC_VECTOR(Position + slv'length - 1 DOWNTO Position);
	BEGIN
		temp := slv;
		FOR I IN temp'range LOOP
			slm(RowIndex, I)  <= temp(I);
		END LOOP;
	END PROCEDURE;
	
	PROCEDURE assign_row(SIGNAL slm : OUT T_SLM; SIGNAL slv : STD_LOGIC_VECTOR; CONSTANT RowIndex : NATURAL; High : NATURAL; Low : NATURAL) IS
		VARIABLE temp : STD_LOGIC_VECTOR(High DOWNTO Low);
	BEGIN
		temp := slv;
		FOR I IN temp'range LOOP
			slm(RowIndex, I)  <= temp(I);
		END LOOP;
	END PROCEDURE;
	
	PROCEDURE assign_col(SIGNAL slm : OUT T_SLM; SIGNAL slv : STD_LOGIC_VECTOR; CONSTANT ColIndex : NATURAL) IS
		VARIABLE temp : STD_LOGIC_VECTOR(slm'range(1));
	BEGIN
		temp := slv;
		FOR I IN temp'range LOOP
			slm(I, ColIndex)  <= temp(I);
		END LOOP;
	END PROCEDURE;

	-- Matrix to matrix conversion: slm_slice*
	FUNCTION slm_slice(slm : T_SLM; RowIndex : NATURAL; ColIndex : NATURAL; Height : NATURAL; Width : NATURAL) RETURN T_SLM IS
		VARIABLE Result		: T_SLM(Height - 1 DOWNTO 0, Width - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => '0'));
	BEGIN
		FOR I IN 0 TO Height - 1 LOOP
			FOR J IN 0 TO Width - 1 LOOP
				Result(I, J)		:= slm(RowIndex + I, ColIndex + J);
			END LOOP;
		END LOOP;
		RETURN Result;
	END FUNCTION;

	FUNCTION slm_slice_cols(slm : T_SLM; High : NATURAL; Low : NATURAL) RETURN T_SLM IS
		VARIABLE Result		: T_SLM(slm'range, High - Low DOWNTO 0)		:= (OTHERS => (OTHERS => '0'));
	BEGIN
		FOR I IN 0 TO slm'length - 1 LOOP
			FOR J IN 0 TO High - Low LOOP
				Result(I, J)		:= slm(I, low + J);
			END LOOP;
		END LOOP;
		RETURN Result;
	END FUNCTION;

	-- Matrix to vector conversion: get_*
	
	-- get a matrix column
	FUNCTION get_col(slm : T_SLM; ColumnIndex : NATURAL) RETURN STD_LOGIC_VECTOR IS
		VARIABLE slv		: STD_LOGIC_VECTOR(slm'range(1));
	BEGIN
		FOR I IN slm'range(1) LOOP
			slv(I)	:= slm(I, ColumnIndex);
		END LOOP;
		RETURN slv;
	END FUNCTION;
	
	-- get a matrix row
	FUNCTION get_row(slm : T_SLM; RowIndex : NATURAL) RETURN STD_LOGIC_VECTOR IS
		VARIABLE slv		: STD_LOGIC_VECTOR(slm'high(2) DOWNTO slm'low(2));			-- Xilinx iSIM work-around, because 'range(2) = 'range(1); tested with ISE/iSIM 14.2
	BEGIN
		FOR I IN slv'range LOOP
			slv(I)	:= slm(RowIndex, I);
		END LOOP;
		RETURN slv;
	END FUNCTION;
	
	-- get a matrix row of defined length [length - 1 downto 0]
	FUNCTION get_row(slm : T_SLM; RowIndex : NATURAL; Length : POSITIVE) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN get_row(slm, RowIndex, (Length - 1), 0);
	END FUNCTION;

	-- get a sub vector of a matrix row at high:low
	FUNCTION get_row(slm : T_SLM; RowIndex : NATURAL; High : NATURAL; Low : NATURAL) RETURN STD_LOGIC_VECTOR IS
		VARIABLE slv		: STD_LOGIC_VECTOR(High DOWNTO Low);			-- Xilinx iSIM work-around, because 'range(2) = 'range(1); tested with ISE/iSIM 14.2
	BEGIN
		FOR I IN slv'range LOOP
			slv(I)	:= slm(RowIndex, I);
		END LOOP;
		RETURN slv;
	END FUNCTION;
	
	-- Convert to bit: to_sl
	FUNCTION to_sl(Value : BOOLEAN) RETURN STD_LOGIC IS
	BEGIN
		RETURN ite(Value, '1', '0');
	END FUNCTION;

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
	END FUNCTION;

	-- Convert to vector: to_slv
	
	-- short for std_logic_vector(to_unsigned(Value, Size))
	FUNCTION to_slv(Value : NATURAL; Size : POSITIVE) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN std_logic_vector(to_unsigned(Value, Size));
	END FUNCTION;
	
	-- convert vector-vector to flatten vector
	FUNCTION to_slv(slvv : T_SLVV_8) RETURN STD_LOGIC_VECTOR IS
		VARIABLE slv			: STD_LOGIC_VECTOR((slvv'length * 8) - 1 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			slv((I * 8) + 7 DOWNTO (I * 8))		:= slvv(I);
		END LOOP;
		RETURN slv;
	END FUNCTION;
	
	-- Convert flat vector to avector-vector: to_slvv_*
	
	-- create vector-vector from vector (4 bit)
	FUNCTION to_slvv_4(slv : STD_LOGIC_VECTOR) RETURN T_SLVV_4 IS
		VARIABLE Result		: T_SLVV_4((slv'length / 4) - 1 DOWNTO 0);
	BEGIN
		IF ((slv'length MOD 4) /= 0) THEN	REPORT "to_slvv_4: width mismatch - slv'length is no multiple of 4 (slv'length=" & INTEGER'image(slv'length) & ")" SEVERITY FAILURE;	END IF;
		
		FOR I IN 0 TO (slv'length / 4) - 1 LOOP
			Result(I)	:= slv((I * 4) + 3 DOWNTO (I * 4));
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from vector (8 bit)
	FUNCTION to_slvv_8(slv : STD_LOGIC_VECTOR) RETURN T_SLVV_8 IS
		VARIABLE Result		: T_SLVV_8((slv'length / 8) - 1 DOWNTO 0);
	BEGIN
		IF ((slv'length MOD 8) /= 0) THEN	REPORT "to_slvv_8: width mismatch - slv'length is no multiple of 8 (slv'length=" & INTEGER'image(slv'length) & ")" SEVERITY FAILURE;	END IF;
		
		FOR I IN 0 TO (slv'length / 8) - 1 LOOP
			Result(I)	:= slv((I * 8) + 7 DOWNTO (I * 8));
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from vector (12 bit)
	FUNCTION to_slvv_12(slv : STD_LOGIC_VECTOR) RETURN T_SLVV_12 IS
		VARIABLE Result		: T_SLVV_12((slv'length / 12) - 1 DOWNTO 0);
	BEGIN
		IF ((slv'length MOD 12) /= 0) THEN	REPORT "to_slvv_12: width mismatch - slv'length is no multiple of 12 (slv'length=" & INTEGER'image(slv'length) & ")" SEVERITY FAILURE;	END IF;
		
		FOR I IN 0 TO (slv'length / 12) - 1 LOOP
			Result(I)	:= slv((I * 12) + 11 DOWNTO (I * 12));
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from vector (16 bit)
	FUNCTION to_slvv_16(slv : STD_LOGIC_VECTOR) RETURN T_SLVV_16 IS
		VARIABLE Result		: T_SLVV_16((slv'length / 16) - 1 DOWNTO 0);
	BEGIN
		IF ((slv'length MOD 16) /= 0) THEN	REPORT "to_slvv_16: width mismatch - slv'length is no multiple of 16 (slv'length=" & INTEGER'image(slv'length) & ")" SEVERITY FAILURE;	END IF;
		
		FOR I IN 0 TO (slv'length / 16) - 1 LOOP
			Result(I)	:= slv((I * 16) + 15 DOWNTO (I * 16));
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from vector (32 bit)
	FUNCTION to_slvv_32(slv : STD_LOGIC_VECTOR) RETURN T_SLVV_32 IS
		VARIABLE Result		: T_SLVV_32((slv'length / 32) - 1 DOWNTO 0);
	BEGIN
		IF ((slv'length MOD 32) /= 0) THEN	REPORT "to_slvv_32: width mismatch - slv'length is no multiple of 32 (slv'length=" & INTEGER'image(slv'length) & ")" SEVERITY FAILURE;	END IF;
		
		FOR I IN 0 TO (slv'length / 32) - 1 LOOP
			Result(I)	:= slv((I * 32) + 31 DOWNTO (I * 32));
		END LOOP;
		RETURN Result;
	END FUNCTION;

	-- create vector-vector from vector (64 bit)
	FUNCTION to_slvv_64(slv : STD_LOGIC_VECTOR) RETURN T_SLVV_64 IS
		VARIABLE Result		: T_SLVV_64((slv'length / 64) - 1 DOWNTO 0);
	BEGIN
		IF ((slv'length MOD 64) /= 0) THEN	REPORT "to_slvv_64: width mismatch - slv'length is no multiple of 64 (slv'length=" & INTEGER'image(slv'length) & ")" SEVERITY FAILURE;	END IF;
		
		FOR I IN 0 TO (slv'length / 64) - 1 LOOP
			Result(I)	:= slv((I * 64) + 63 DOWNTO (I * 64));
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from vector (128 bit)
	FUNCTION to_slvv_128(slv : STD_LOGIC_VECTOR) RETURN T_SLVV_128 IS
		VARIABLE Result		: T_SLVV_128((slv'length / 128) - 1 DOWNTO 0);
	BEGIN
		IF ((slv'length MOD 128) /= 0) THEN	REPORT "to_slvv_128: width mismatch - slv'length is no multiple of 128 (slv'length=" & INTEGER'image(slv'length) & ")" SEVERITY FAILURE;	END IF;
		
		FOR I IN 0 TO (slv'length / 128) - 1 LOOP
			Result(I)	:= slv((I * 128) + 127 DOWNTO (I * 128));
		END LOOP;
		RETURN Result;
	END FUNCTION;

	-- Convert matrix to avector-vector: to_slvv_*
	
	-- create vector-vector from matrix (4 bit)
	FUNCTION to_slvv_4(slm : T_SLM) RETURN T_SLVV_4 IS
		VARIABLE Result		: T_SLVV_4(slm'range);
	BEGIN
		IF (slm'length(2) /= 4) THEN	REPORT "to_slvv_4: type mismatch - slm'length(2)=" & INTEGER'image(slm'length(2)) SEVERITY FAILURE;	END IF;
		
		FOR I IN slm'range LOOP
			Result(I)	:= get_row(slm, I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from matrix (8 bit)
	FUNCTION to_slvv_8(slm : T_SLM) RETURN T_SLVV_8 IS
		VARIABLE Result		: T_SLVV_8(slm'range);
	BEGIN
		IF (slm'length(2) /= 8) THEN	REPORT "to_slvv_8: type mismatch - slm'length(2)=" & INTEGER'image(slm'length(2)) SEVERITY FAILURE;	END IF;
		
		FOR I IN slm'range LOOP
			Result(I)	:= get_row(slm, I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from matrix (12 bit)
	FUNCTION to_slvv_12(slm : T_SLM) RETURN T_SLVV_12 IS
		VARIABLE Result		: T_SLVV_12(slm'range);
	BEGIN
		IF (slm'length(2) /= 12) THEN	REPORT "to_slvv_12: type mismatch - slm'length(2)=" & INTEGER'image(slm'length(2)) SEVERITY FAILURE;	END IF;
		
		FOR I IN slm'range LOOP
			Result(I)	:= get_row(slm, I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from matrix (16 bit)
	FUNCTION to_slvv_16(slm : T_SLM) RETURN T_SLVV_16 IS
		VARIABLE Result		: T_SLVV_16(slm'range);
	BEGIN
		IF (slm'length(2) /= 16) THEN	REPORT "to_slvv_16: type mismatch - slm'length(2)=" & INTEGER'image(slm'length(2)) SEVERITY FAILURE;	END IF;
		
		FOR I IN slm'range LOOP
			Result(I)	:= get_row(slm, I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from matrix (32 bit)
	FUNCTION to_slvv_32(slm : T_SLM) RETURN T_SLVV_32 IS
		VARIABLE Result		: T_SLVV_32(slm'range);
	BEGIN
		IF (slm'length(2) /= 32) THEN	REPORT "to_slvv_32: type mismatch - slm'length(2)=" & INTEGER'image(slm'length(2)) SEVERITY FAILURE;	END IF;
		
		FOR I IN slm'range LOOP
			Result(I)	:= get_row(slm, I);
		END LOOP;
		RETURN Result;
	END FUNCTION;

	-- create vector-vector from matrix (64 bit)
	FUNCTION to_slvv_64(slm : T_SLM) RETURN T_SLVV_64 IS
		VARIABLE Result		: T_SLVV_64(slm'range);
	BEGIN
		IF (slm'length(2) /= 64) THEN	REPORT "to_slvv_64: type mismatch - slm'length(2)=" & INTEGER'image(slm'length(2)) SEVERITY FAILURE;	END IF;
		
		FOR I IN slm'range LOOP
			Result(I)	:= get_row(slm, I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- create vector-vector from matrix (128 bit)
	FUNCTION to_slvv_128(slm : T_SLM) RETURN T_SLVV_128 IS
		VARIABLE Result		: T_SLVV_128(slm'range);
	BEGIN
		IF (slm'length(2) /= 128) THEN	REPORT "to_slvv_128: type mismatch - slm'length(2)=" & INTEGER'image(slm'length(2)) SEVERITY FAILURE;	END IF;
		
		FOR I IN slm'range LOOP
			Result(I)	:= get_row(slm, I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- Convert vector-vector to matrix: to_slm

	-- create matrix from vector-vector
	FUNCTION to_slm(slvv : T_SLVV_4) RETURN T_SLM IS
		VARIABLE slm		: T_SLM(slvv'range, 3 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			FOR J IN T_SLV_4'range LOOP
				slm(I, J)		:= slvv(I)(J);
			END LOOP;
		END LOOP;
		RETURN slm;
	END FUNCTION;
	
	FUNCTION to_slm(slvv : T_SLVV_8) RETURN T_SLM IS
--		VARIABLE test		: STD_LOGIC_VECTOR(T_SLV_8'range);
--		VARIABLE slm		: T_SLM(slvv'range, test'range);				-- BUG: iSIM 14.5 cascaded 'range accesses let iSIM break down 
--		VARIABLE slm		: T_SLM(slvv'range, T_SLV_8'range);			-- BUG: iSIM 14.5 allocates 9 bits in dimmension 2
		VARIABLE slm		: T_SLM(slvv'range, 7 DOWNTO 0);
	BEGIN
--		REPORT "slvv:    slvv.length=" & INTEGER'image(slvv'length) &			"  slm.dim0.length=" & INTEGER'image(slm'length(1)) & "  slm.dim1.length=" & INTEGER'image(slm'length(2)) SEVERITY NOTE;
--		REPORT "T_SLV_8:     .length=" & INTEGER'image(T_SLV_8'length) &	"  .high=" & INTEGER'image(T_SLV_8'high) &	"  .low=" & INTEGER'image(T_SLV_8'low)	SEVERITY NOTE;
--		REPORT "test:    test.length=" & INTEGER'image(test'length) &			"  .high=" & INTEGER'image(test'high) &			"  .low=" & INTEGER'image(test'low)			SEVERITY NOTE;
		FOR I IN slvv'range LOOP
			FOR J IN T_SLV_8'range LOOP
				slm(I, J)		:= slvv(I)(J);
			END LOOP;
		END LOOP;
		RETURN slm;
	END FUNCTION;
	
	FUNCTION to_slm(slvv : T_SLVV_12) RETURN T_SLM IS
		VARIABLE slm		: T_SLM(slvv'range, 11 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			FOR J IN T_SLV_12'range LOOP
				slm(I, J)		:= slvv(I)(J);
			END LOOP;
		END LOOP;
		RETURN slm;
	END FUNCTION;
	
	FUNCTION to_slm(slvv : T_SLVV_16) RETURN T_SLM IS
		VARIABLE slm		: T_SLM(slvv'range, 15 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			FOR J IN T_SLV_16'range LOOP
				slm(I, J)		:= slvv(I)(J);
			END LOOP;
		END LOOP;
		RETURN slm;
	END FUNCTION;
	
	FUNCTION to_slm(slvv : T_SLVV_32) RETURN T_SLM IS
		VARIABLE slm		: T_SLM(slvv'range, 31 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			FOR J IN T_SLV_32'range LOOP
				slm(I, J)		:= slvv(I)(J);
			END LOOP;
		END LOOP;
		RETURN slm;
	END FUNCTION;
	
	FUNCTION to_slm(slvv : T_SLVV_48) RETURN T_SLM IS
		VARIABLE slm		: T_SLM(slvv'range, 47 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			FOR J IN T_SLV_48'range LOOP
				slm(I, J)		:= slvv(I)(J);
			END LOOP;
		END LOOP;
		RETURN slm;
	END FUNCTION;
	
	FUNCTION to_slm(slvv : T_SLVV_64) RETURN T_SLM IS
		VARIABLE slm		: T_SLM(slvv'range, 63 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			FOR J IN T_SLV_64'range LOOP
				slm(I, J)		:= slvv(I)(J);
			END LOOP;
		END LOOP;
		RETURN slm;
	END FUNCTION;
	
	FUNCTION to_slm(slvv : T_SLVV_128) RETURN T_SLM IS
		VARIABLE slm		: T_SLM(slvv'range, 127 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			FOR J IN T_SLV_128'range LOOP
				slm(I, J)		:= slvv(I)(J);
			END LOOP;
		END LOOP;
		RETURN slm;
	END FUNCTION;
	
	-- to_char
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

	-- to_string
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
		CONSTANT int					: INTEGER				:= ite((slv'length <= 32), to_integer(unsigned(slv)), 0);
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

	FUNCTION to_string(slvv : T_SLVV_8; sep : CHARACTER := ':') RETURN STRING IS
		CONSTANT hex_len			: POSITIVE								:= ite((sep = NUL), (slvv'length * 2), (slvv'length * 3) - 1);
		VARIABLE Result				: STRING(1 TO hex_len)		:= (OTHERS => sep);
		VARIABLE pos					: POSITIVE								:= 1;
	BEGIN
		FOR I IN slvv'range LOOP
			Result(pos TO pos + 1)	:= to_string(slvv(I), 'h');
			pos											:= pos + ite((sep = NUL), 2, 3);
		END LOOP;
		RETURN Result;
	END FUNCTION;

	-- to_*
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

	FUNCTION to_index(slv : STD_LOGIC_VECTOR; max : NATURAL := 0) RETURN INTEGER IS
		VARIABLE m	: NATURAL		:= ite((max = 0), 2**slv'length - 1, max);
	BEGIN
		IF (SIMULATION = TRUE) THEN
			RETURN imin(to_integer(unsigned(slv)), m);
		ELSE
			RETURN to_integer(unsigned(slv));
		END IF;
	END FUNCTION;
	
	-- is_*
	FUNCTION is_sl(c : CHARACTER) RETURN BOOLEAN IS
	BEGIN
		CASE C IS
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
	END FUNCTION;

	-- Change vector direction
	FUNCTION dir(slvv : T_SLVV_8) RETURN T_SLVV_8 IS
		VARIABLE Result : T_SLVV_8(slvv'reverse_range);
	BEGIN
		Result := slvv;
		RETURN Result;
	END FUNCTION;
	
	-- Reverse vector elements

	-- be the return Vector cev; then: vec(i) = cev(i) but vec'reverse_range = cev'range
--	function reverse(vec : std_logic_vector) return std_logic_vector is
--		variable res : std_logic_vector(vec'reverse_range);
--	begin
--		for i in res'range loop
--			res(i) := vec(i);
--		end loop;
--		return	res;
--	end reverse;
	function reverse(vec : std_logic_vector) return std_logic_vector is
		variable res : std_logic_vector(vec'range);
	begin
		for i in vec'low to vec'high loop
			res(vec'high - i) := vec(i);
		end loop;
		return	res;
	end function;
	
	function reverse(vec : unsigned) return unsigned is
	begin
		return unsigned(reverse(std_logic_vector(vec)));
	end function;

	
	FUNCTION rev(slvv : T_SLVV_4) RETURN T_SLVV_4 IS
		VARIABLE Result : T_SLVV_4(slvv'range);
	BEGIN
		FOR I IN slvv'low TO slvv'high LOOP
			Result(slvv'high - I) := slvv(I);
		END LOOP;
		RETURN Result;
	END FUNCTION;

	FUNCTION rev(slvv : T_SLVV_8) RETURN T_SLVV_8 IS
		VARIABLE Result : T_SLVV_8(slvv'range);
	BEGIN
		FOR I IN slvv'low TO slvv'high LOOP
			Result(slvv'high - I) := slvv(I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION rev(slvv : T_SLVV_12) RETURN T_SLVV_12 IS
		VARIABLE Result : T_SLVV_12(slvv'range);
	BEGIN
		FOR I IN slvv'low TO slvv'high LOOP
			Result(slvv'high - I) := slvv(I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION rev(slvv : T_SLVV_16) RETURN T_SLVV_16 IS
		VARIABLE Result : T_SLVV_16(slvv'range);
	BEGIN
		FOR I IN slvv'low TO slvv'high LOOP
			Result(slvv'high - I) := slvv(I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION rev(slvv : T_SLVV_32) RETURN T_SLVV_32 IS
		VARIABLE Result : T_SLVV_32(slvv'range);
	BEGIN
		FOR I IN slvv'low TO slvv'high LOOP
			Result(slvv'high - I) := slvv(I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION rev(slvv : T_SLVV_64) RETURN T_SLVV_64 IS
		VARIABLE Result : T_SLVV_64(slvv'range);
	BEGIN
		FOR I IN slvv'low TO slvv'high LOOP
			Result(slvv'high - I) := slvv(I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION rev(slvv : T_SLVV_128) RETURN T_SLVV_128 IS
		VARIABLE Result : T_SLVV_128(slvv'range);
	BEGIN
		FOR I IN slvv'low TO slvv'high LOOP
			Result(slvv'high - I) := slvv(I);
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	-- Swap sub vectors in vector
	FUNCTION swap(slv : STD_LOGIC_VECTOR; Size : POSITIVE) RETURN STD_LOGIC_VECTOR IS
		CONSTANT SegmentCount	: NATURAL													:= slv'length / Size;
		VARIABLE FromH				: NATURAL;
		VARIABLE FromL				: NATURAL;
		VARIABLE ToH					: NATURAL;
		VARIABLE ToL					: NATURAL;
		VARIABLE Result : STD_LOGIC_VECTOR(slv'length - 1 DOWNTO 0);
	BEGIN
		FOR I IN 0 TO SegmentCount - 1 LOOP
			FromH		:= ((I + 1) * Size) - 1;
			FromL		:= I * Size;
			ToH			:= ((SegmentCount - I) * Size) - 1;
			ToL			:= (SegmentCount - I - 1) * Size;
			Result(ToH DOWNTO ToL)	:= slv(FromH DOWNTO FromL);
		END LOOP;
		RETURN Result;
	END FUNCTION;

	-- binary encoding conversion functions
	
	-- One-Hot-Code to Binary-Code
	FUNCTION onehot2bin(onehot : STD_LOGIC_VECTOR; ReportError : BOOLEAN := FALSE) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN std_logic_vector(onehot2bin_us(onehot, ReportError));
	END FUNCTION;
	
	FUNCTION onehot2bin_us(onehot : STD_LOGIC_VECTOR; ReportError : BOOLEAN := FALSE) RETURN UNSIGNED IS
		CONSTANT BITS					: POSITIVE											:= log2ceilnz(onehot'length);
		VARIABLE Result_Synth	: UNSIGNED(BITS - 1 DOWNTO 0)		:= (OTHERS => '0');
		VARIABLE Result_Sim		: INTEGER												:= -1;
	BEGIN
		IF (SIMULATION = FALSE) THEN
			FOR I IN 0 TO onehot'length - 1 LOOP
				IF (onehot(I) = '1') THEN
					Result_Synth	:= Result_Synth OR to_unsigned(I, BITS);
				END IF;
			END LOOP;
			IF ReportError THEN
				RETURN to_sl(onehot = (onehot'range => '0')) & Result_Synth;
			ELSE
				RETURN Result_Synth;
			END IF;
			
--		function lssb_idx(arg : std_logic_vector) return std_logic_vector is
--			variable hot : std_logic_vector(arg'length						 downto 0)	:= lssb('1' & arg);
--			variable res : std_logic_vector(log2ceil(arg'length)-1 downto 0)	:= (others => '0');
--		begin
--			for i in 0 to arg'length - 1 loop
--				if hot(i) = '1' then
--					res := res or std_logic_vector(to_unsigned(i, res'length));
--				end if;
--			end loop;
--			return	hot(arg'length) & res;
--		end function
			
		ELSE
			-- find first 'one'
			FOR I IN 0 TO onehot'length - 1 LOOP
				IF (onehot(I) = '1') THEN
					IF (Result_Sim = -1) THEN
						Result_Sim		:= I;
					ELSE
						IF ReportError THEN
							RETURN (0 TO BITS => 'X');				-- error if more the one 'one' in vector
						ELSE
							RETURN (0 TO BITS - 1 => 'X');		-- error if more the one 'one' in vector
						END IF;
					END IF;
				END IF;
			END LOOP;
		
			IF (Result_Sim /= -1 ) THEN
				RETURN to_unsigned(Result_Sim, BITS);
			ELSE
				IF ReportError THEN
					RETURN (0 TO BITS => 'X');						-- error if no 'one' in vector
				ELSE
					RETURN (0 TO BITS - 1 => 'X');				-- error if no 'one' in vector
				END IF;
			END IF;
		END IF;
	END FUNCTION;
	
	-- Gray-Code to Binary-Code
	function gray2bin(gray_val : std_logic_vector) return std_logic_vector is
		variable res : std_logic_vector(gray_val'range);
	begin	-- gray2bin
		res(res'left) := gray_val(gray_val'left);
		for i in res'left-1 downto res'right loop
			res(i) := res(i+1) xor gray_val(i);
		end loop;
		return res;
	end gray2bin;

	-- bit searching / bit indices

	-- Least-Significant Set Bit (lssb): computes a vector of the same length with at most one bit set at the rightmost '1' found in arg.
	function lssb(arg : std_logic_vector) return std_logic_vector is
	begin
		return	arg and std_logic_vector(unsigned(not arg)+1);
	end function;

	-- Most-Significant Set Bit (mssb): computes a vector of the same length with at most one bit set at the leftmost '1' found in arg.
	function mssb(arg : std_logic_vector) return std_logic_vector is
	begin
		return	reverse(lssb(reverse(arg)));
	end function;

	-- Index of lssb
	function lssb_idx(arg : std_logic_vector; ReportError : boolean := false) return std_logic_vector is
	begin
		return onehot2bin(lssb(arg), ReportError);
	end function;
	-- NOTE: to ensure compatibily with old PoC.functions, use lssb_idx(..., true)

	-- Index of mssb
	function mssb_idx(arg : std_logic_vector; ReportError : boolean := false) return std_logic_vector is
	begin
		return onehot2bin(mssb(arg), ReportError);
	end function;

--	Returns the position of the least-significant set bit assigning
--	the rightmost position an index of zero (0).
--	The returned vector is of length 1+log2ceil(arg'length) coding
--	the result position in a two's complement binary. If its additional
--	leftmost bit is set, all elements of the argument vector were
--	zero (0).
--	function lssb_idx(arg : std_logic_vector) return std_logic_vector is
--		variable hot : std_logic_vector(arg'length						 downto 0)	:= lssb('1' & arg);
--		variable res : std_logic_vector(log2ceil(arg'length)-1 downto 0)	:= (others => '0');
--	begin
--		for i in 0 to arg'length - 1 loop
--			if hot(i) = '1' then
--				res := res or std_logic_vector(to_unsigned(i, res'length));
--			end if;
--		end loop;
--		return	hot(arg'length) & res;
--	end function;


	-- if-then-else (ite)
	FUNCTION ite(cond : BOOLEAN; value1 : INTEGER; value2 : INTEGER) RETURN INTEGER IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : REAL; value2 : REAL) RETURN REAL IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : STD_LOGIC; value2 : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : STD_LOGIC_VECTOR; value2 : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : UNSIGNED; value2 : UNSIGNED) RETURN UNSIGNED IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : CHARACTER; value2 : CHARACTER) RETURN CHARACTER IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;
	
	FUNCTION ite(cond : BOOLEAN; value1 : STRING; value2 : STRING) RETURN STRING IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;
	
	-- Resize functions
	-- Resizes the vector to the specified length. Input vectors larger than the specified size are truncated from the left side. Smaller input
	-- vectors are extended on the left by the provided fill value (default: '0'). Use the resize functions of the numeric_std package for
	-- value-preserving resizes of the signed and unsigned data types.
	function resize(vec : bit_vector; length : natural; fill : bit := '0') return bit_vector is
	begin
		return	to_bitvector(resize(to_stdlogicvector(vec), length, to_stdulogic(fill)));
	end function;

	function resize(vec : std_logic_vector; length : natural; fill : std_logic := '0') return std_logic_vector is
	begin
		if vec'length >= length then
			return	vec(length - 1 downto 0);
		else
			return (length - 1 downto vec'length => fill) & vec;
		end if;
	end function;

	FUNCTION resize(slm : T_SLM; size : POSITIVE) RETURN T_SLM IS
		VARIABLE Result		: T_SLM(size - 1 DOWNTO 0, slm'high(2) DOWNTO slm'low(2))		:= (OTHERS => (OTHERS => '0'));
	BEGIN
		FOR I IN slm'range(1) LOOP
			FOR J IN slm'high(2) DOWNTO slm'low(2) LOOP
				Result(I, J)	:= slm(I, J);
			END LOOP;
		END LOOP;
		RETURN Result;
	END FUNCTION;

	FUNCTION resize(str : STRING; size : POSITIVE; FillChar : CHARACTER := NUL) RETURN STRING IS
		CONSTANT MaxLength	: POSITIVE							:= imin(size, str'length);
		VARIABLE Result			: STRING(1 TO size)			:= (OTHERS => FillChar);
	BEGIN
		Result(1 TO MaxLength) := str(1 TO MaxLength);
		RETURN Result;
	END FUNCTION;

	-- Move vector boundaries
	FUNCTION move(slv : STD_LOGIC_VECTOR; pos : INTEGER) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result : STD_LOGIC_VECTOR(slv'left + pos DOWNTO slv'right + pos) := slv;
	BEGIN
		RETURN Result;
	END FUNCTION;

	-- Character functions
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

	-- Calculates the length of a vector discounting leading Zeros
	-- The minimum length returned is 1 even if the whole vector is zeros.
	function length(arg : bit_vector) return positive is
	begin
		return	length(to_stdLogicVector(arg));
	end function;

	-- FIXME: isn't this max(1, mssb_idx), but not length; vectors have already a fixed length
	function length(arg : std_logic_vector) return positive is
		variable result : natural := arg'length;
	begin
		for i in arg'range loop
			if arg(i) = '1' then
				return result;
			end if;
			result := result - 1;
		end loop;
		return	1;		-- FIXME: why have empty vector a length of 1?
	end function;
	
end functions;
