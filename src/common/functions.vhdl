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
-- Copyright 2007-2013 Technische Universität Dresden - Germany
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

  --+ Status +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  -- Distinguishes Simulation from Synthesis
  function IS_SIMULATION return boolean; -- Consider it PRIVATE
  constant SIMULATION : boolean := IS_SIMULATION;
  
  --+ Logarithm ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  -- Calculates: ceil(ld(arg))
  function log2ceil(arg : positive) return natural;
  -- Calculates: max(1, ceil(ld(arg)))
  function log2ceilnz(arg : positive) return positive;
  
  --+ Min / Max ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  -- Calculates: max(arg1, arg2) for integers
  function imax(arg1 : integer; arg2 : integer) return integer;
  -- Calculates: max(arg1, arg2) for reals
  function rmax(arg1 : real; arg2 : real) return real;

  -- Calculates: min(arg1, arg2) for integers
  function imin(arg1 : integer; arg2 : integer) return integer;
  -- Calculates: min(arg1, arg2) for reals
  function rmin(arg1 : real; arg2 : real) return real;

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
