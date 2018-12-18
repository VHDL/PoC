-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Package:					Math extension package.
--
-- Description:
-- -------------------------------------
--		This package provides additional math functions.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany,
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
-- =============================================================================

library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;
use     IEEE.math_real.all;

library PoC;
use			PoC.utils.all;


package math is
	-- figurate numbers
	function squareNumber(N : natural) return natural;
	function cubicNumber(N : natural) return natural;
	function triangularNumber(N : natural) return natural;

	-- coefficients
	-- binomial coefficient (N choose K)
	function binomialCoefficient(N : positive; K : positive) return positive;

	-- greatest common divisor (gcd)
	function greatestCommonDivisor(N1 : positive; N2 : positive) return positive;
	-- least common multiple (lcm)
	function leastCommonMultiple(N1 : positive; N2 : positive) return positive;
  
  -- calculate fraction of positive float and give out as vector of integers
  function fract(F : real; maxDenominator : natural := 1000; maxError : real := 1.0E-9) return T_NATVEC;
  -- calculate time increments to met fraction
  function fract2timing(numerator : natural; denominator : natural) return T_NATVEC;
end package;

package body math is
	-- figurate numbers
	function squareNumber(N : natural) return natural is
	begin
		return N*N;
	end function;

	function cubicNumber(N : natural) return natural is
	begin
		return N*N*N;
	end function;

	function triangularNumber(N : natural) return natural is
		variable T	: natural;
	begin
		return (N * (N + 1) / 2);
	end function;

	-- coefficients
	function binomialCoefficient(N : positive; K : positive) return positive is
		variable Result		: positive;
	begin
		Result		:= 1;
		for i in 1 to K loop
			Result := Result * (((N + 1) - i) / i);
		end loop;
		return Result;
	end function;

	-- greatest common divisor (gcd)
	function greatestCommonDivisor(N1 : positive; N2 : positive) return positive is
		variable M1				: positive;
		variable M2				: natural;
		variable Remainer	: natural;
	begin
		M1	:= imax(N1, N2);
		M2	:= imin(N1, N2);
		while M2 /= 0 loop
			Remainer	:= M1 mod M2;
			M1				:= M2;
			M2				:= Remainer;
		end loop;
		return M1;
	end function;

	-- least common multiple (lcm)
	function leastCommonMultiple(N1 : positive; N2 : positive) return positive is
	begin
		return ((N1 * N2) / greatestCommonDivisor(N1, N2));
	end function;
  
  -- calculate fraction of positive float and give out as vector of integers
  function fract(F : real; maxDenominator : natural := 1000; maxError : real := 1.0E-9) return T_NATVEC is
    constant fulls        : natural := integer(trunc(F));
    constant remainder    : real    := F - trunc(F);
    variable numerator    : natural := 0;
    variable denominator  : natural := 1;
    variable newFraction  : real    := 0.0;
    variable Error        : real    := remainder;
    variable result       : T_NATVEC (0 to 2) := (others => 0);
    variable bestError    : real    := remainder;
  begin
    result(0)  := fulls;
    while (Error > maxError) and (denominator < maxDenominator) loop
      if newFraction > remainder then
        denominator := denominator +1;
        numerator   := numerator -1;
      elsif (numerator +1) = denominator then
        denominator := denominator +1;
      else
        numerator   := numerator +1;
      end if;
       
      newFraction := real(numerator) / real(denominator);
      Error := REALMAX(remainder, newFraction) - REALMIN(remainder, newFraction);
      if Error < bestError then
        bestError := Error;
        result(1) := numerator;
        result(2) := denominator;
      end if;
    end loop;
    assert (bestError < maxError) report "Didn't find suitable fraction for F=" & real'image(F) & "! Target Error=" & real'image(maxError) & " Actual Error=" & real'image(bestError) & "!" severity failure;
    return result;
  end function;
  
  -- calculate time increments to met fraction
  function fract2timing(numerator : natural; denominator : natural) return T_NATVEC is
    variable actualNumerator : natural  := 1;
    variable tab             : natural  := 0;
    variable increment       : real  := real(numerator) / real(denominator);
    variable remainder       : real  := real(numerator) / real(denominator);
    variable result          : T_NATVEC(0 to numerator -1) := (others => 0);
  begin
    while actualNumerator <= denominator -1 loop
      if remainder  >= 1.0 then
        result(tab) := actualNumerator;
        remainder   := remainder -1.0 +increment;
        tab         := tab +1;
        actualNumerator := actualNumerator +1;
      else
        remainder   := remainder +increment;
        actualNumerator := actualNumerator +1;
      end if;
    end loop;   
    result(result'high) := denominator;
    return result;
  end function;
end package body;
