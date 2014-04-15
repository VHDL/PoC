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
-- ============================================================================

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;


package utils is
  --+ Environment +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  -- Distinguishes Simulation from Synthesis
	function IS_SIMULATION return boolean;	-- Forward declaration; consider it PRIVATE
	constant SIMULATION : boolean := IS_SIMULATION;
	
	-- Type declarations
	-- ==========================================================================
	
  --+ Vectors of primitive standard types +++++++++++++++++++++++++++++++++++++
	TYPE		T_BOOLVEC						IS ARRAY(NATURAL RANGE <>) OF BOOLEAN;
	TYPE		T_INTVEC						IS ARRAY(NATURAL RANGE <>) OF INTEGER;
	TYPE		T_NATVEC						IS ARRAY(NATURAL RANGE <>) OF NATURAL;
	TYPE		T_POSVEC						IS ARRAY(NATURAL RANGE <>) OF POSITIVE;
	TYPE		T_REALVEC						IS ARRAY(NATURAL RANGE <>) OF REAL;
	
	--+ Integer subranges sometimes useful for speeding up simulation ++++++++++
	SUBTYPE T_UINT_8						IS INTEGER RANGE 0 TO 255;
	SUBTYPE T_UINT_16						IS INTEGER RANGE 0 TO 65535;

	--+ Enums ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	-- Intellectual Property (IP) type
	TYPE T_IPSTYLE			IS (IPSTYLE_HARD, IPSTYLE_SOFT);
	
	-- Bit Order
	TYPE T_BIT_ORDER		IS (LSB_FIRST, MSB_FIRST);
  -- Byte Order (Endian)
	TYPE T_BYTE_ORDER		IS (LITTLE_ENDIAN, BIG_ENDIAN);

	-- Function declarations
	-- ==========================================================================

  --+ Division ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  -- Calculates: ceil(a / b)
	FUNCTION div_ceil(a : NATURAL; b : POSITIVE) RETURN NATURAL;
	
  --+ Power +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  -- is input a power of 2?
	FUNCTION is_pow2(int : NATURAL)			RETURN BOOLEAN;
  -- round to next power of 2
	FUNCTION ceil_pow2(int : NATURAL)		RETURN POSITIVE;
  -- round to previous power of 2
	FUNCTION floor_pow2(int : NATURAL)	RETURN NATURAL;

  --+ Logarithm ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  -- Calculates: ceil(ld(arg))
  function log2ceil(arg : positive) return natural;
  -- Calculates: max(1, ceil(ld(arg)))
  function log2ceilnz(arg : positive) return positive;
  -- Calculates: ceil(lg(arg))
	FUNCTION log10ceil(arg		: POSITIVE)	RETURN NATURAL;
  -- Calculates: max(1, ceil(lg(arg)))
	FUNCTION log10ceilnz(arg	: POSITIVE)	RETURN POSITIVE;
	
	--+ if-then-else (ite) +++++++++++++++++++++++++++++++++++++++++++++++++++++
	FUNCTION ite(cond : BOOLEAN; value1 : INTEGER; value2 : INTEGER) RETURN INTEGER;
	FUNCTION ite(cond : BOOLEAN; value1 : REAL;	value2 : REAL) RETURN REAL;
	FUNCTION ite(cond : BOOLEAN; value1 : STD_LOGIC; value2 : STD_LOGIC) RETURN STD_LOGIC;
	FUNCTION ite(cond : BOOLEAN; value1 : STD_LOGIC_VECTOR; value2 : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;
	FUNCTION ite(cond : BOOLEAN; value1 : UNSIGNED; value2 : UNSIGNED) RETURN UNSIGNED;
	FUNCTION ite(cond : BOOLEAN; value1 : CHARACTER; value2 : CHARACTER) RETURN CHARACTER;
	FUNCTION ite(cond : BOOLEAN; value1 : STRING; value2 : STRING) RETURN STRING;

  --+ Max / Min / Sum ++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	function imin(arg1 : integer; arg2 : integer) return integer;		-- Calculates: min(arg1, arg2) for integers
	FUNCTION imin(vec : T_INTVEC) RETURN INTEGER;										-- Calculates: min(vector) for a integer vector
	FUNCTION imin(vec : T_NATVEC) RETURN NATURAL;										-- Calculates: min(vector) for a natural vector
	FUNCTION imin(vec : T_POSVEC) RETURN POSITIVE;									-- Calculates: min(vector) for a positive vector
	function rmin(arg1 : real; arg2 : real) return real;						-- Calculates: min(arg1, arg2) for reals
	function rmin(vec : T_REALVEC) return real;	       							-- Calculates: min(vec) of real vector

	function imax(arg1 : integer; arg2 : integer) return integer;		-- Calculates: max(arg1, arg2) for integers
	FUNCTION imax(vec : T_INTVEC) RETURN INTEGER;										-- Calculates: max(vector) for a integer vector
	FUNCTION imax(vec : T_NATVEC) RETURN NATURAL;										-- Calculates: max(vector) for a natural vector
	FUNCTION imax(vec : T_POSVEC) RETURN POSITIVE;									-- Calculates: max(vector) for a positive vector
	function rmax(arg1 : real; arg2 : real) return real;						-- Calculates: max(arg1, arg2) for reals
	function rmax(vec : T_REALVEC) return real;	       							-- Calculates: max(vec) of real vector

	FUNCTION isum(vec : T_NATVEC) RETURN NATURAL;										-- Calculates: sum(vector) for a natural vector
	FUNCTION isum(vec : T_POSVEC) RETURN POSITIVE;									-- Calculates: sum(vector) for a positive vector
	function isum(vec : T_INTVEC) return integer; 									-- Calculates: sum(vec) of integer vector
	function rsum(vec : T_REALVEC) return real;	       							-- Calculates: sum(vec) of real vector

	--+ Conversions ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  -- To std_logic: to_sl
	FUNCTION to_sl(Value : BOOLEAN)		RETURN STD_LOGIC;
	FUNCTION to_sl(Value : CHARACTER) RETURN STD_LOGIC;

	-- To std_logic_vector: to_slv
	FUNCTION to_slv(Value : NATURAL; Size : POSITIVE)		RETURN STD_LOGIC_VECTOR;					-- short for std_logic_vector(to_unsigned(Value, Size))
	
	-- TODO: comment
	FUNCTION to_index(slv : STD_LOGIC_VECTOR; max : NATURAL := 0) RETURN INTEGER;
	
	-- is_*
	FUNCTION is_sl(c : CHARACTER) RETURN BOOLEAN;

	--+ Basic Vector Utilities +++++++++++++++++++++++++++++++++++++++++++++++++

  -- Aggregate Functions
  FUNCTION slv_or  (vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC;
  FUNCTION slv_nor (vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC;
  FUNCTION slv_and (vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC;
  FUNCTION slv_nand(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC;
  function slv_xor (vec : std_logic_vector) return std_logic;
	-- NO slv_xnor! This operation would not be well-defined as
	-- not xor(vec) /= vec_{n-1} xnor ... xnor vec_1 xnor vec_0 iff n is odd.

  -- Reverses the elements of the passed Vector.
  --
  -- @synthesis supported
  --
	function reverse(vec : std_logic_vector) return std_logic_vector;
	function reverse(vec : unsigned)				 return unsigned;
	
  -- Resizes the vector to the specified length. Input vectors larger than
  -- the specified size are truncated from the left side. Smaller input
  -- vectors are extended on the left by the provided fill value
  -- (default: '0').
	-- Use the resize functions of the numeric_std package for value-preserving
	-- resizes of the signed and unsigned data types.
	--
  -- @synthesis supported
  --
  function resize(vec : bit_vector; length : natural; fill : bit := '0')
    return bit_vector;
  function resize(vec : std_logic_vector; length : natural; fill : std_logic := '0')
    return std_logic_vector;

	-- Adjust the index range of a vector by the specified offset.
	function move(vec : std_logic_vector; ofs : integer) return std_logic_vector;

  -- Least-Significant Set Bit (lssb):
  -- Computes a vector of the same length as the argument with
  -- at most one bit set at the rightmost '1' found in arg.
  --
  -- @synthesis supported
  --
  function lssb(arg : std_logic_vector) return std_logic_vector;

  -- Returns the position of the least-significant set bit assigning
  -- the rightmost position an index of zero (0).
  --
  -- @synthesis supported
  --
  function lssb_idx(arg : std_logic_vector) return integer;

	-- Most-Significant Set Bit (mssb): computes a vector of the same length
	-- with at most one bit set at the leftmost '1' found in arg.
	function mssb(arg : std_logic_vector) return std_logic_vector;
	function mssb_idx(arg : std_logic_vector) return integer;

	-- Swap sub vectors in vector (endian reversal)
	FUNCTION swap(slv : STD_LOGIC_VECTOR; Size : POSITIVE) RETURN STD_LOGIC_VECTOR;

	--+ Encodings ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  -- One-Hot-Code to Binary-Code.
	function onehot2bin(onehot : std_logic_vector) return unsigned;

  -- Converts Gray-Code into Binary-Code.
  --
  -- @synthesis supported
  --
  function gray2bin (gray_val : std_logic_vector) return std_logic_vector;
	
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
		RETURN ceil_pow2(int) = int;
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
		VARIABLE Result		: natural := NATURAL'high;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) < Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION imin(vec : T_POSVEC) RETURN POSITIVE IS
		VARIABLE Result		: positive := POSITIVE'high;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) < Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;

	function rmin(arg1 : real; arg2 : real) return real is
	begin
		if arg1 < arg2 then return arg1; end if;
		return arg2;
	end function;

	function rmin(vec : T_REALVEC) return real is
		variable  res : real := real'high;
	begin
		for i in vec'range loop
			if vec(i) < res then
				res := vec(i);
			end if;
		end loop;
		return  res;
	end rmin;

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
		VARIABLE Result		: natural := NATURAL'low;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) > Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;
	
	FUNCTION imax(vec : T_POSVEC) RETURN POSITIVE IS
		VARIABLE Result		: positive := POSITIVE'low;
	BEGIN
		FOR I IN vec'range LOOP
			IF (vec(I) > Result) THEN
				Result	:= vec(I);
			END IF;
		END LOOP;
		RETURN Result;
	END FUNCTION;

	function rmax(arg1 : real; arg2 : real) return real is
	begin
		if arg1 > arg2 then return arg1; end if;
		return arg2;
	end function;

	function rmax(vec : T_REALVEC) return real is
		variable  res : real := real'low;
	begin
		for i in vec'range loop
			if vec(i) > res then
				res := vec(i);
			end if;
		end loop;
		return  res;
	end rmax;

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

	function isum(vec : T_INTVEC) return integer is
		variable  res : integer := 0;
	begin
		for i in vec'range loop
			res	:= res + vec(i);
		end loop;
		return  res;
	end isum;

	function rsum(vec : T_REALVEC) return real is
		variable  res : real := 0.0;
	begin
		for i in vec'range loop
			res	:= res + vec(i);
		end loop;
		return  res;
	end rsum;

	-- Vector aggregate functions: slv_*
	-- ==========================================================================
	FUNCTION slv_or(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
		VARIABLE Result : STD_LOGIC := '0';
	BEGIN
		FOR i IN vec'range LOOP
			Result	:= Result OR vec(i);
		END LOOP;
		RETURN Result;
	END FUNCTION;

	FUNCTION slv_nor(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
	BEGIN
		RETURN NOT slv_or(vec);
	END FUNCTION;

	FUNCTION slv_and(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
		VARIABLE Result : STD_LOGIC := '1';
	BEGIN
		FOR i IN vec'range LOOP
			Result	:= Result AND vec(i);
		END LOOP;
		RETURN Result;
	END FUNCTION;

	FUNCTION slv_nand(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC IS
	BEGIN
		RETURN NOT slv_and(vec);
	END FUNCTION;

	function slv_xor(vec : std_logic_vector) return std_logic is
		variable  res : std_logic;
	begin
		res := '0';
		for i in vec'range loop
			res := res xor vec(i);
		end loop;
		return  res;
	end slv_xor;
	
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
		variable  res : integer;
	BEGIN
		res := to_integer(unsigned(slv));
		if SIMULATION and max > 0 then
			res := imin(res, max);
		end if;
		return  res;
	END FUNCTION;
	
  -- is_*
  -- ==========================================================================
  FUNCTION is_sl(c : CHARACTER) RETURN BOOLEAN IS
  BEGIN
    CASE C IS
      WHEN 'U'|'X'|'0'|'1'|'Z'|'W'|'L'|'H'|'-' => return  true;
      WHEN OTHERS                              => return  false;
    END CASE;
  END FUNCTION;

	
	-- Reverse vector elements

	-- FIXME: be the return Vector cev; then: vec(i) = cev(i) but vec'reverse_range = cev'range
	function reverse(vec : std_logic_vector) return std_logic_vector is
		variable res : std_logic_vector(vec'range);
	begin
		for i in vec'low to vec'high loop
			res(vec'low + (vec'high-i)) := vec(i);
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
  function onehot2bin(onehot : std_logic_vector) return unsigned is
		variable res : unsigned(log2ceil(onehot'high+1)-1 downto 0);
		variable chk : natural;
	begin
		res := (others => '0');
		chk := 0;
		for i in onehot'range loop
			if onehot(i) = '1' then
				res := res or to_unsigned(i, res'length);
				chk := chk + 1;
			end if;
		end loop;
		if SIMULATION and chk /= 1 then
			report "Broken 1-Hot-Code with "&integer'image(chk)&" bits set."
				severity error;
		end if;
		return	res;
	end onehot2bin;

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
	function lssb_idx(arg : std_logic_vector) return integer is
	begin
		return  to_integer(onehot2bin(lssb(arg)));
	end function;

	-- Index of mssb
	function mssb_idx(arg : std_logic_vector) return integer is
	begin
		return  to_integer(onehot2bin(mssb(arg)));
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
