-- =============================================================================
-- Authors:
--   Stefan Unrein
--   Adrian Weiland
--
-- Entity:
--
-- Description:
-- -------------------------------------
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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
use     IEEE.std_logic_1164.ALL;
use     IEEE.numeric_std.ALL;
use     IEEE.math_real.all;

use     work.math.all;
use     work.utils.all;
use     work.physical.all;


entity clock_Timer is
	generic (
		DEBUG       : boolean := false;
		CLOCK_FREQ  : Freq    := 186 MHz;
		TIME_BASE   : T_TIME  := 1.0e-9;
		WRAP_TIME   : T_TIME  := 1.0e-6; -- 0.0 to disable wrap
		CLOCK_BITS  : natural := 64
	);
	port (
		Clock        : in  std_logic;
		Reset        : in  std_logic;
		Increment    : in  std_logic;
		Decrement    : in  std_logic;
		Load         : in  std_logic;
		Time_to_load : in  unsigned (CLOCK_BITS - 1 downto 0);
		Current_time : out unsigned (CLOCK_BITS - 1 downto 0);
		Overflow     : out std_logic
	);
end entity;

architecture rtl of clock_Timer is

	function "-" (left : t_natvec; right : integer) return t_natvec is
		variable result : t_natvec(left'range) := (others => 0);
	begin
		for i in left'range loop
			if left(i) > right then
				result(i) := left(i) - right;
			end if;
		end loop;
		return result;
	end function;

	constant PERIOD            : T_TIME       := to_time(CLOCK_FREQ);
	constant PERIOD_FRACT      : t_fractional := fract(PERIOD / TIME_BASE, 1000000, 1.0e-12);
	constant INCREMENT_FULL    : natural      := PERIOD_FRACT.whole;
	constant INCREMENT_VEC     : t_natvec     := fract2timing(PERIOD_FRACT);

	constant WRAP_VALUE : integer := ite(WRAP_TIME /= 0.0, to_int(WRAP_TIME / TIME_BASE, 1.0), 0);

	signal wrap_around        : std_logic;
	signal counter            : unsigned(CLOCK_BITS - 1 downto 0) := (others => '0');

	signal Load_d             : std_logic := '0';
	signal Load_re            : std_logic;
	signal correct            : std_logic;
	signal to_Increment       : unsigned(log2ceilnz(INCREMENT_FULL + 3) - 1 downto 0);

begin
	assert not DEBUG report "periodic_fract for " & real'image(PERIOD) & "is: " & integer'image(INCREMENT_FULL) & ", " & integer'image(PERIOD_FRACT.numerator) & ", " & integer'image(PERIOD_FRACT.denominator) & "." severity note;

	Load_d  <= Load when rising_edge(Clock);
	Load_re <= not Load_d and Load;

	Current_time <= counter;

	correction_counter_gen: if INCREMENT_VEC'length = 1 and INCREMENT_VEC(0) = 0 generate
		correct <= '0';
	else generate
		signal   correction_counter : unsigned(log2ceilnz(PERIOD_FRACT.denominator) - 1 downto 0) := (others => '0');
	begin
		correct <= '1' when indexof(INCREMENT_VEC - 1, to_integer(correction_counter)) >= 0 else '0';

		correction_counter_proc : process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' or Load_re = '1' or (correction_counter >= PERIOD_FRACT.denominator - 1 and PERIOD_FRACT.numerator > 0) then
					correction_counter  <= (others => '0');
				else
					correction_counter  <= correction_counter + 1;
				end if;
			end if;
		end process;
	end generate;

	wrap_gen : if WRAP_VALUE /= 0 and INCREMENT_FULL > 0 generate
		wrap_around <= to_sl(counter >= WRAP_VALUE - 1);
	elsif WRAP_VALUE /= 0 and INCREMENT_FULL = 0 generate
		wrap_around <= to_sl(counter >= WRAP_VALUE - 1) and correct;
	else generate
		wrap_around <= '0';
	end generate;

	Overflow <= wrap_around;

	counter_proc : process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				counter <= (others => '0');
			elsif Load_re = '1' then
				counter <= Time_to_load + INCREMENT_FULL;
			elsif wrap_around = '1' then
				counter <= counter - to_unsigned(WRAP_VALUE, CLOCK_BITS) + to_Increment;
			else
				counter <= counter + to_Increment;
			end if;
		end if;
	end process;

	Increment_proc : process(Increment, Decrement, correct)
		variable temp : unsigned(to_Increment'range);
	begin
		temp := to_unsigned(INCREMENT_FULL, temp'length);
		if Increment = '1' then
			temp := temp + 1;
		end if;
		if correct = '1' then
			temp := temp + 1;
		end if;
		if Decrement = '1' then
			temp := temp - 1;
		end if;
		to_Increment  <= temp;
	end process;

end architecture;
