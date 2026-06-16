-- =============================================================================
-- Authors:           Martin Zabel
--                  Thomas B. Preusser
--
-- Entity:           BCD counter.
--
-- Description:
-- -------------------------------------
-- Counter with output in binary coded decimal (BCD). The number of BCD digits
-- is configurable by ``DIGITS``.
--
-- All control signals (``Reset``, ``Increment``) are high-active and
-- synchronous to ``Clock``. The output ``Value`` is the current counter
-- state. Groups of 4 bit represent one BCD digit. The lowest significant digit
-- is specified by ``Value(3 downto 0)``.
--
-- .. TODO::
--
--    * implement a ``Decrement`` input for decrementing
--    * implement a ``Load`` input to load a value
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


entity arith_Counter_BCD is
	generic (
		DIGITS    : positive                            -- Number of BCD digits
	);
	port (
		Clock     : in  std_logic;
		Reset     : in  std_logic;                        -- Reset to 0
		Increment : in  std_logic;                        -- Increment
		Value     : out T_BCD_VECTOR(DIGITS-1 downto 0)   -- Value output
	);
end entity;


architecture rtl of arith_Counter_BCD is
	-- c(i) = carry-in of stage 'i'
	signal p : unsigned(DIGITS-1 downto 0);  -- Stage Overflows=Propagates
	signal c : unsigned(DIGITS   downto 0);  -- Inter-Stage Carries
begin
	-- Compute Carries using standard addition
	c <= ('0'&p) xor (('0'&p) + 1);

	-- Generate for each BCD stage
	gDigit : for i in 0 to DIGITS-1 generate
		signal cnt_r : T_BCD := x"0";   -- Counter Digit of this Stage
	begin
		p(i) <= cnt_r(3) and cnt_r(0); -- Local Overflow at digit 9
		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					cnt_r <= (others => '0');
				elsif (Increment and c(i)) = '1' then  -- short critical path for 'inc'
					if p(i) = '1' then -- our counter reached last digit
						cnt_r <= x"0";
					else
						cnt_r <= T_BCD(unsigned(cnt_r) + 1);
					end if;
				end if;
			end if;
		end process;

		-- Digit Output
		Value(i) <= cnt_r;
	end generate gDigit;
end architecture;
