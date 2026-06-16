-- =============================================================================
-- Authors:         Thomas B. Preusser
--
-- Entity:          A flexible scaler for fixed-point values.
--
-- Description:
-- -------------------------------------
-- A flexible scaler for fixed-point values. The scaler is implemented for a set
-- of multiplier and divider values. Each individual scaling operation can
-- arbitrarily select one value from each these sets.
--
-- The computation calculates: ``unsigned(arg) * MULS(msel) / DIVS(dsel)``
-- rounded to the nearest (tie upwards) fixed-point result of the same precision
-- as ``arg``.
--
-- The computation is started by asserting ``start`` to high for one cycle. If a
-- computation is running, it will be restarted. The completion of a calculation
-- is signaled via ``done``. ``done`` is high when no computation is in progress.
-- The result of the last scaling operation is stable and can be read from
-- ``res``. The weight of the LSB of ``res`` is the same as the LSB of ``arg``.
-- Make sure to tap a sufficient number of result bits in accordance to the
-- highest scaling ratio to be used in order to avoid a truncation overflow.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
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
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;

entity arith_Scaler is
	generic (
		MULTIPLIERS : positive_vector := (0 => 1);  -- The set of multipliers to choose from in scaling operations.
		DIVISORS    : positive_vector := (0 => 1)   -- The set of divisors to choose from in scaling operations.
	);
	port (
		Clock            : in  std_logic;
		Reset            : in  std_logic;

		Start            : in  std_logic;          -- Start of Computation
		arg              : in  std_logic_vector;   -- Fixed-point value to be scaled
		MultiplierSelect : in  std_logic_vector(log2ceil(MULTIPLIERS'length)-1 downto 0) := (others => '0');
		DivisorSelect    : in  std_logic_vector(log2ceil(DIVISORS'length)-1 downto 0)    := (others => '0');

		Result           : out std_logic_vector;    -- Result
		Done             : out std_logic          -- Completion
	);
end entity;

architecture rtl of arith_Scaler is

	-- Derived Constants
	constant BITS : positive := arg'length;
	constant X    : positive := log2ceil(imax(imax(MULTIPLIERS), imax(DIVISORS)/2+1));
	constant R    : positive := log2ceil(imax(DIVISORS)+1);

	-- Division Properties
	type tDivProps is record  -- Properties of the operation for a divisor
		steps : positive_vector(DIVISORS'range);  -- Steps to perform
		align : positive_vector(DIVISORS'range);  -- Left-aligned divisor
	end record;

	function computeProps return tDivProps is
		variable res       : tDivProps;
		variable min_steps : positive;
	begin
		for i in DIVISORS'range loop
			res.steps(i) := BITS+X - log2ceil(DIVISORS(i)+1) + 1;
		end loop;
		min_steps := imin(res.steps);
		for i in DIVISORS'range loop
			res.align(i) := DIVISORS(i) * 2**(res.steps(i) - min_steps);
		end loop;
		return  res;
	end computeProps;

	constant DIV_PROPS : tDivProps := computeProps;

	constant MAX_MUL_STEPS : positive := BITS;
	constant MAX_DIV_STEPS : positive := imax(DIV_PROPS.steps);
	constant MAX_ANY_STEPS : positive := imax(MAX_MUL_STEPS, MAX_DIV_STEPS);

	subtype tResMask  is std_logic_vector(MAX_DIV_STEPS-1 downto 0);
	type    tResMasks is array(natural range<>) of tResMask;

	function computeMasks return tResMasks is
		variable res : tResMasks(DIVISORS'range);
	begin
		for i in DIVISORS'range loop
			res(i)                                := (others => '0');
			res(i)(DIV_PROPS.steps(i)-1 downto 0) := (others => '1');
		end loop;
		return res;
	end computeMasks;

	constant RES_MASKS : tResMasks(DIVISORS'range) := computeMasks;

	-- Values computed for the selected multiplier/divisor pair.
	signal muloffset  : unsigned(X-1 downto 0);  -- Offset for correct rounding.
	signal multiplier : unsigned(X   downto 0);  -- The actual multiplier value.
	signal divisor    : unsigned(R-1 downto 0);  -- The actual divisor value.
	signal divcini    : unsigned(log2ceil(MAX_ANY_STEPS)-1 downto 0);  -- Count for division steps.
	signal divmask    : tResMask;                -- Result Mask

begin

	-----------------------------------------------------------------------------
	-- Compute Parameters according to selected Multiplier/Divisor Pair.

	-- Selection of Multiplier
	genMultiMul: if MULTIPLIERS'length > 1 generate
		signal MS : unsigned(MultiplierSelect'range) := (others => '0');
	begin
		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					MS <= (others => '0');
				elsif Start = '1' then
					MS <= unsigned(MultiplierSelect);
				end if;
			end if;
		end process;

		multiplier <= (others => 'X') when Is_X(std_logic_vector(MS)) else to_unsigned(MULTIPLIERS(to_integer(MS)), multiplier'length);
	end generate genMultiMul;

	genSingleMul: if MULTIPLIERS'length = 1 generate
		multiplier <= to_unsigned(MULTIPLIERS(0), multiplier'length);
	end generate genSingleMul;

	-- Selection of Divisor
	genMultiDiv: if DIVISORS'length > 1 generate
		signal DS : unsigned(DivisorSelect'range) := (others => '0');
	begin
		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					DS <= (others => '0');
				elsif Start = '1' then
					DS <= unsigned(DivisorSelect);
				end if;
			end if;
		end process;

		muloffset <= (others => 'X') when Is_X(DivisorSelect)                 else to_unsigned(DIVISORS(to_integer(unsigned(DivisorSelect)))/2, muloffset'length);
		divisor   <= (others => 'X') when Is_X(std_logic_vector(DS)) else to_unsigned(DIV_PROPS.align(to_integer(DS)), divisor'length);
		divcini   <= (others => 'X') when Is_X(std_logic_vector(DS)) else to_unsigned(DIV_PROPS.steps(to_integer(DS))-1, divcini'length);
		divmask   <= (others => 'X') when Is_X(std_logic_vector(DS)) else RES_MASKS(to_integer(DS));
	end generate genMultiDiv;

	genSingleDiv: if DIVISORS'length = 1 generate
		muloffset <= to_unsigned(DIVISORS(0)/2, muloffset'length);
		divisor   <= to_unsigned(DIV_PROPS.align(0), divisor'length);
		divcini   <= to_unsigned(DIV_PROPS.steps(0)-1, divcini'length);
		divmask   <= RES_MASKS(0);
	end generate genSingleDiv;

	-----------------------------------------------------------------------------
	-- Implementation of Scaling Operation
	blkMain : block
		signal C : unsigned(1+log2ceil(MAX_ANY_STEPS) downto 0) := (others => '0');
		signal Q : unsigned(                     X+BITS  downto 0) := (others => '0');
	begin
		process(Clock)
			variable cnxt : unsigned(C'range);
			variable d    : unsigned(R downto 0);
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					C <= (others => '0');
					Q <= (others => '0');
				else
					if Start = '1' then
						C <= "11" & to_unsigned(MAX_MUL_STEPS-1, C'length-2);
						Q <= '0' & muloffset & unsigned(arg);
					elsif C(C'left) = '1' then

						cnxt := C - 1;
						if C(C'left-1) = '1' then
							-- MUL Phase
							Q <= "00" & Q(X+BITS-1 downto 1);
							if Q(0) = '1' then
								Q(X+BITS-1 downto BITS-1) <= ('0' & Q(X+BITS-1 downto BITS)) + multiplier;
							end if;

							-- Transition to DIV
							if cnxt(cnxt'left-1) = '0' then
								cnxt(cnxt'left-2 downto 0) := divcini;
							end if;
						else
							-- DIV Phase
							d := Q(Q'left downto Q'left-R) - divisor;
							Q <= Q(Q'left-1 downto 0) & not d(d'left);

							if d(d'left) = '0' then
								Q(Q'left downto Q'left-R+1) <= d(d'left-1 downto 0);
							end if;
						end if;
						C <= cnxt;

					end if;
				end if;
			end if;
		end process;

		Done <= not C(C'left);

		process(Q, divmask)
			variable r : std_logic_vector(Result'length-1 downto 0);
		begin
			r := (others => '0');
			r(imin(r'left, tResMask'left) downto 0) := std_logic_vector(Q(imin(r'left, tResMask'left) downto 0)) and divmask(imin(r'left, tResMask'left) downto 0);
			Result <= r;
		end process;

	end block blkMain;

end architecture;
