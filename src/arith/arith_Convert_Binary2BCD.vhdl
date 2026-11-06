-- =============================================================================
-- Authors:          Patrick Lehmann
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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
use     work.components.all;


-- Sequential converter from binary numbers to binary-coded decimal (BCD) numbers.
--
-- A cycle with ``Start`` high samples ``Binary`` and ``IsSigned``. If ``IsSigned`` is high and ``Binary`` is negative
-- (two's complement), its magnitude is converted and ``Sign`` is set; otherwise, ``Binary`` is converted as an unsigned
-- number and ``Sign`` is cleared.
--
-- The conversion shifts ``log2ceil(RADIX)`` bits per ``Clock`` cycle into a chain of ``DIGITS`` BCD digit stages. It
-- takes ``ceil(BITS / log2ceil(RADIX))`` cycles, during which ``Busy`` is high. ``DIGITS`` must be large enough for the
-- largest magnitude of ``Binary``; higher digits are lost.
--
-- If ``REGISTER_OUTPUT`` is ``FALSE``, ``BCDDigits`` shows the digit stages and changes during a conversion; the
-- result is valid while ``Busy`` is low. If ``REGISTER_OUTPUT`` is ``TRUE``, ``BCDDigits`` is registered: it holds the
-- previous result during a conversion and shows the new result one cycle after ``Busy`` went low.
--
-- ``Reset`` is synchronous and clears the digits; it does not clear ``Busy`` or ``Sign``.
entity arith_Convert_Binary2BCD is
	generic (
		BITS                : positive := 8;     -- Width of ``Binary`` in bits.
		DIGITS              : positive := 3;     -- Number of BCD digits.
		RADIX               : positive := 2;     -- Conversion radix; ``log2ceil(RADIX)`` bits per cycle.
		REGISTER_OUTPUT     : boolean  := FALSE  -- Register ``BCDDigits``; update it only while idle.
	);
	port (
		Clock               : in  std_logic;                            -- Clock; all inputs are sampled on its rising edge.
		Reset               : in  std_logic;                            -- Synchronous reset; clears the digits.

		Start               : in  std_logic;                            -- Start a conversion of ``Binary``.
		Busy                : out std_logic;                            -- Conversion in progress.

		Binary              : in  std_logic_vector(BITS - 1 downto 0);  -- Binary number; sampled with ``Start``.
		IsSigned            : in  std_logic  := '0';                    -- ``Binary`` is a two's complement number.
		BCDDigits           : out T_BCD_VECTOR(DIGITS - 1 downto 0);    -- Magnitude in BCD; lowest digit at index 0.
		Sign                : out std_logic                             -- Converted number is negative.
	);
end entity;


architecture rtl of arith_Convert_Binary2BCD is
	constant RADIX_BITS     : positive := log2ceil(RADIX);
	constant BINARY_SHIFTS  : positive := div_ceil(BITS, RADIX_BITS);
	constant BINARY_BITS    : positive := BINARY_SHIFTS * RADIX_BITS;

	subtype T_CARRY        is unsigned(RADIX_BITS - 1 downto 0);
	type T_CARRY_VECTOR    is array(natural range <>) of T_CARRY;   -- FIXME: T_USV ?

	signal Digit_Shift_rst : std_logic;
	signal Digit_Shift_en  : std_logic;
	signal Digit_Shift_in  : T_CARRY_VECTOR(DIGITS downto 0);

	signal Binary_en       : std_logic;
	signal Binary_rl       : std_logic;
	signal Binary_d         : std_logic_vector(BINARY_BITS - 1 downto 0) := (others => '0');

	signal Sign_d          : std_logic                                  := '0';
	signal DelayShifter    : std_logic_vector(BINARY_SHIFTS downto 0)   := '1' & (BINARY_SHIFTS - 1 downto 0 => '0');



	function nextBCD(Value : unsigned(4 downto 0)) return unsigned is
		constant Temp : unsigned(4 downto 0) := Value - 10;
	begin
		if Value > 9 then
			return '1' & Temp(3 downto 0);
		else
			return Value;
		end if;
	end function;

begin
	Busy                <= not DelayShifter(DelayShifter'high);

	Binary_en           <= Start;
	Binary_rl           <= Start nor DelayShifter(DelayShifter'high);
	Digit_Shift_rst     <= Start;
	Digit_Shift_en      <= Start nor DelayShifter(DelayShifter'high);

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Binary_d <= (others => '0');
			elsif (Binary_en = '1') then
				Binary_d(Binary_d'high downto Binary'high) <= (others => '0');
				if ((IsSigned and Binary(Binary'high)) = '1') then
					Binary_d(Binary'high downto 0) <= std_logic_vector(-signed(Binary));
					Sign_d                         <= '1';
				else
					Binary_d(Binary'high downto 0) <= Binary;
					Sign_d                         <= '0';
				end if;
				DelayShifter                       <= (BINARY_SHIFTS downto 1 => '0') & '1';
			elsif (Binary_rl = '1') then
				DelayShifter <= DelayShifter(DelayShifter'high - 1 downto 0) & DelayShifter(DelayShifter'high);
				Binary_d     <= Binary_d(Binary_d'high - RADIX_BITS downto 0) & Binary_d(Binary_d'high downto Binary_d'high - RADIX_BITS + 1);
			end if;
		end if;
	end process;

	Sign              <= Sign_d;
	Digit_Shift_in(0) <= unsigned(Binary_d(Binary_d'high downto Binary_d'high - RADIX_BITS + 1));

	-- generate DIGITS many systolic elements
	genDigits : for i in 0 to DIGITS - 1 generate
		signal Digit_nxt : unsigned(3 + RADIX_BITS downto 0);
		signal Digit_d   : unsigned(3 downto 0) := (others => '0');
	begin
		process(Digit_d, Digit_Shift_in)
			variable Temp : unsigned(4 downto 0);
		begin
			Temp := '0' & Digit_d;
			for j in RADIX_BITS - 1 downto 0 loop
				Temp := nextBCD(Temp(3 downto 0) & Digit_Shift_in(i)(j));
				Digit_nxt(j + 4 downto j) <= Temp;
			end loop;
		end process;

		Digit_Shift_in(i + 1) <= Digit_nxt(Digit_nxt'high downto Digit_nxt'high - RADIX_BITS + 1);

		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' or Digit_Shift_rst = '1' then
					Digit_d  <= "0000";
				elsif (Digit_Shift_en = '1') then
					Digit_d  <= Digit_nxt(Digit_d'range);
				end if;
			end if;
		end process;

		unstableOutput: if not REGISTER_OUTPUT generate
			BCDDigits(i)   <= T_BCD(std_logic_vector(Digit_d));
		else generate
			signal BCDDigits_d     : BCDDigits'element := (others => '0');
		begin
			BCDDigits_d  <= T_BCD(std_logic_vector(Digit_d)) when rising_edge(Clock) and Busy = '0';
			BCDDigits(i) <= BCDDigits_d;
		end generate;
	end generate;
end architecture;
