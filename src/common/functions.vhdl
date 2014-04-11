-- EMACS settings: -*-  tab-width:2  -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ===========================================================================
-- Description:     Common functions
--
-- Authors:         Thomas B. Preusser
--                  Martin Zabel
--                  Patrick Lehmann
-- ===========================================================================
-- Copyright 2007-2014 Technische Universität Dresden - Germany
--                     Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--    http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ===========================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;

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
  constant SIMULATION		: boolean		:= IS_SIMULATION;						  -- Distinguishes Simulation from Synthesis
  
	-- Divisions: div_*
	FUNCTION div_ceil(a : NATURAL; b : POSITIVE) RETURN NATURAL;		-- Calculates: ceil(a / b)
	
	-- Power functions: *_pow2
	FUNCTION is_pow2(int : NATURAL)			RETURN BOOLEAN;
	FUNCTION ceil_pow2(int : NATURAL)		RETURN POSITIVE;
	FUNCTION floor_pow2(int : NATURAL)	RETURN NATURAL;
	
  -- Logarithms: log*ceil*
  function log2ceil(arg			: positive) return natural;						-- Calculates: ceil(ld(arg))
  function log2ceilnz(arg		: positive) return positive;					-- Calculates: max(1, ceil(ld(arg)))
  FUNCTION log10ceil(arg		: POSITIVE)	RETURN NATURAL;						-- calculates: ceil(lg(arg))
  FUNCTION log10ceilnz(arg	: POSITIVE)	RETURN POSITIVE;				  -- calculates: max(1, ceil(lg(arg)))
	
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








	-- binary encoding conversion functions
	FUNCTION onehot2bin(onehot : STD_LOGIC_VECTOR) RETURN UNSIGNED;







  --+ Vectors ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  -- Reverses the elements of the passed Vector.
  -- Be the return Vector cev; then:
  --   - vec(i)            = cev(i)     but
  --   - vec'reverse_range = cev'range
  --
  -- @synthesis supported
  --
  function reverse(vec : std_logic_vector) return std_logic_vector;
	function reverse(vec : unsigned)         return unsigned;

  -- Least-Significant Set Bit (lssb):
  -- Computes a vector of the same length as the argument with
  -- at most one bit set at the rightmost '1' found in arg.
  --
  -- @synthesis supported
  --
  function lssb(arg : std_logic_vector) return std_logic_vector;

  -- Returns the position of the least-significant set bit assigning
  -- the rightmost position an index of zero (0).
  -- The returned vector is of length 1+log2ceil(arg'length) coding
  -- the result position in a two's complement binary. If its additional
  -- leftmost bit is set, all elements of the argument vector were
  -- zero (0).
  --
  -- @synthesis supported
  --
  function lssb_idx(arg : std_logic_vector) return std_logic_vector;
  
  -- Calculates the length of a vector discounting leading Zeros
  -- The minimum length returned is 1 even if the whole vector is zeros.
  function length(arg : bit_vector)       return positive;
  function length(arg : std_logic_vector) return positive;

  -- Resizes the vector to the specified length. Input vectors larger than
  -- the specified size are truncated from the left side. Smaller input
  -- vectors are extended on the left by the provided fill value
  -- (default: '0'). Use the resize functions of the numeric_std package
  -- for value-preserving resizes of the signed and unsigned data types.
  --
  -- @synthesis supported
  --
  function resize(vec : bit_vector; length : natural; fill : bit := '0')
    return bit_vector;
  function resize(vec : std_logic_vector; length : natural; fill : std_logic := '0')
    return std_logic_vector;

  --+ Gray-Code / Binary-Code ++++++++++++++++++++++++++++++++++++++++++++++++
  -- Converts Gray-Code into Binary-Code.
  --
  -- @synthesis supported
  --
  function gray2bin (gray_val : std_logic_vector) return std_logic_vector;

end package functions;

library IEEE;
use IEEE.numeric_std.all;

package body functions is

  --+ Status +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  function IS_SIMULATION return boolean is
    variable  ret : boolean;
  begin
    ret := false;
    --synthesis translate_off
    if Is_X('X') then ret := true; end if;
    --synthesis translate_on
    return  ret;
  end;

  --+ Logarithm ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  function log2ceil(arg : positive) return natural is
    variable tmp : positive;
    variable log : natural;
  begin
    if arg = 1 then  return  0; end if;
    
    tmp := 1;
    log := 0;

    while arg > tmp loop
      tmp := tmp * 2;
      log := log + 1;
    end loop;
    return log;
    
  end;

  function log2ceilnz(arg : positive) return positive is
  begin
    return imax(1, log2ceil(arg));
  end;

  --+ Min / Max ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  function imax(arg1 : integer; arg2 : integer) return integer is
  begin
    if arg1>arg2 then return arg1; end if;
    return arg2;
  end;

  function rmax(arg1 : real; arg2 : real) return real is
  begin
    if arg1>arg2 then return arg1; end if;
    return arg2;
  end;

  function imin(arg1 : integer; arg2 : integer) return integer is
  begin
    if arg1<arg2 then return arg1; end if;
    return arg2;
  end;

  function rmin(arg1 : real; arg2 : real) return real is
  begin
    if arg1<arg2 then return arg1; end if;
    return arg2;
  end;

  --+ Vectors ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  function reverse(vec : std_logic_vector) return std_logic_vector is
    variable res : std_logic_vector(vec'reverse_range);
  begin
    for i in res'range loop
      res(i) := vec(i);
    end loop;
    return  res;
  end reverse;
	
	function reverse(vec : unsigned) return unsigned is
  begin
    return unsigned(reverse(std_logic_vector(vec)));
  end reverse;

  function lssb(arg : std_logic_vector) return std_logic_vector is
  begin
    return  arg and std_logic_vector(unsigned(not arg)+1);
  end;

  function lssb_idx(arg : std_logic_vector) return std_logic_vector is
    variable hot : std_logic_vector(arg'length             downto 0);
    variable res : std_logic_vector(log2ceil(arg'length)-1 downto 0);
  begin
    hot := lssb('1' & arg);
    res := (others => '0');
    for i in 0 to arg'length-1 loop
      if hot(i) = '1' then
        res := res or std_logic_vector(to_unsigned(i, res'length));
      end if;
    end loop;
    return  hot(arg'length) & res;
  end;

  function length(arg : bit_vector) return positive is
  begin
    return  length(to_stdLogicVector(arg));
  end;
  function length(arg : std_logic_vector) return positive is
    variable res : natural;
  begin
    res := arg'length;
    for i in arg'range loop
      if arg(i) = '1' then
        return  res;
      end if;
      res := res - 1;
    end loop;
    return  1;
  end;
  
  function resize(vec : bit_vector; length : natural; fill : bit := '0')
    return bit_vector is
  begin
    return  to_bitVector(resize(to_stdLogicVector(vec), length, to_stdULogic(fill)));
  end;

  function resize(vec : std_logic_vector; length : natural; fill : std_logic := '0')
    return std_logic_vector is

    alias arg : std_logic_vector(vec'length-1 downto 0) is vec;
  begin
    if arg'length >= length then
      return  arg(length-1 downto 0);
    end if;
    return (length-1 downto arg'length => fill) & arg;
  end;

  --+ Gray-Code / Binary-Code ++++++++++++++++++++++++++++++++++++++++++++++++
  function gray2bin(gray_val : std_logic_vector) return std_logic_vector is
  variable res : std_logic_vector(gray_val'range);
  begin  -- gray2bin
    res(res'left) := gray_val(gray_val'left);
    for i in res'left-1 downto res'right loop
      res(i) := res(i+1) xor gray_val(i);
    end loop;
    return res;
  end gray2bin;
  
end functions;
