-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Package:					Common functions and types
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
-- ============================================================================

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;


package utils is
	-- Environment
	function IS_SIMULATION return boolean;													-- Forward declaration; consider this function PRIVATE
	constant SIMULATION		: boolean		:= IS_SIMULATION;							-- Distinguishes Simulation from Synthesis
	
	-- Type declarations
	-- ==========================================================================
	
	-- BOOLEAN_VECTOR
	TYPE		T_BOOLVEC						IS ARRAY(NATURAL RANGE <>) OF BOOLEAN;
	-- INTEGER_VECTORs
	TYPE		T_INTVEC						IS ARRAY(NATURAL RANGE <>) OF INTEGER;
	TYPE		T_NATVEC						IS ARRAY(NATURAL RANGE <>) OF NATURAL;
	TYPE		T_POSVEC						IS ARRAY(NATURAL RANGE <>) OF POSITIVE;
	TYPE		T_REALVEC						IS ARRAY(NATURAL RANGE <>) OF REAL;
	
	-- INTEGERs
	SUBTYPE T_UINT_8						IS INTEGER RANGE 0 TO 255;
	SUBTYPE T_UINT_16						IS INTEGER RANGE 0 TO 65535;

	-- Intellectual Property (IP) type
	TYPE T_IPSTYLE			IS (IPSTYLE_HARD, IPSTYLE_SOFT);
	
	-- Bit and byte order types
	TYPE T_BIT_ORDER		IS (LSB_FIRST, MSB_FIRST);
	TYPE T_BYTE_ORDER		IS (LITTLE_ENDIAN, BIG_ENDIAN);

	-- Function declarations
	-- ==========================================================================
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

	-- Vector aggregate functions: slv_*
	FUNCTION slv_or(Vector		: STD_LOGIC_VECTOR)	RETURN STD_LOGIC;
	FUNCTION slv_nor(Vector		: STD_LOGIC_VECTOR)	RETURN STD_LOGIC;
	FUNCTION slv_and(Vector		: STD_LOGIC_VECTOR)	RETURN STD_LOGIC;
	FUNCTION slv_nand(Vector	: STD_LOGIC_VECTOR)	RETURN STD_LOGIC;

	-- Convert to bit: to_sl
	FUNCTION to_sl(Value : BOOLEAN)		RETURN STD_LOGIC;
	FUNCTION to_sl(Value : CHARACTER) RETURN STD_LOGIC;

	-- Convert to vector: to_slv
	FUNCTION to_slv(Value : NATURAL; Size : POSITIVE)		RETURN STD_LOGIC_VECTOR;					-- short for std_logic_vector(to_unsigned(Value, Size))
	
	-- TODO: comment
	FUNCTION to_index(slv : STD_LOGIC_VECTOR; max : NATURAL := 0) RETURN INTEGER;
	
	-- is_*
	FUNCTION is_sl(c : CHARACTER) RETURN BOOLEAN;

	-- Reverse vector elements
	function reverse(vec : std_logic_vector) return std_logic_vector;			-- be the return Vector cev; then: vec(i) = cev(i) but vec'reverse_range = cev'range
	function reverse(vec : unsigned)				 return unsigned;
	
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

	-- Adjust the index range of a vector by the specified offset.
	function move(vec : std_logic_vector; ofs : integer) return std_logic_vector;

end package utils;


package body utils is

	-- Environment
	-- ==========================================================================
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
	-- ==========================================================================
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
	-- ==========================================================================
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
	-- ==========================================================================
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

	-- Vector aggregate functions: slv_*
	-- ==========================================================================
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

	
	-- Convert to bit: to_sl
	-- ==========================================================================
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
	-- ==========================================================================
	-- short for std_logic_vector(to_unsigned(Value, Size))
	FUNCTION to_slv(Value : NATURAL; Size : POSITIVE) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN std_logic_vector(to_unsigned(Value, Size));
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
	-- ==========================================================================
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

	
	-- Reverse vector elements

	-- FIXME: be the return Vector cev; then: vec(i) = cev(i) but vec'reverse_range = cev'range
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

	
	-- Swap sub vectors in vector
	-- ==========================================================================
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
	-- ==========================================================================
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
	-- ==========================================================================
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


	-- if-then-else (ite)
	-- ==========================================================================
	FUNCTION ite(cond : BOOLEAN; value1 : INTEGER; value2 : INTEGER) RETURN INTEGER IS
	BEGIN
		IF cond THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : REAL; value2 : REAL) RETURN REAL IS
	BEGIN
		IF cond THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : STD_LOGIC; value2 : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		IF cond THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : STD_LOGIC_VECTOR; value2 : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		IF cond THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : UNSIGNED; value2 : UNSIGNED) RETURN UNSIGNED IS
	BEGIN
		IF cond THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;

	FUNCTION ite(cond : BOOLEAN; value1 : CHARACTER; value2 : CHARACTER) RETURN CHARACTER IS
	BEGIN
		IF cond THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;
	
	FUNCTION ite(cond : BOOLEAN; value1 : STRING; value2 : STRING) RETURN STRING IS
	BEGIN
		IF cond THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END FUNCTION;
	
	-- Resize functions
	-- ==========================================================================
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

	-- Move vector boundaries
	-- ==========================================================================
  function move(vec : std_logic_vector; ofs : integer) return std_logic_vector is
    variable res_up : std_logic_vector(vec'low +ofs to     vec'high+ofs);
    variable res_dn : std_logic_vector(vec'high+ofs downto vec'low +ofs);
  begin
    if vec'ascending then
      res_up := vec;
      return  res_up;
    else
      res_dn := vec;
      return  res_dn;
    end if;
  end move;
	
end utils;
