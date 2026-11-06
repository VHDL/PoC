-- =============================================================================
-- Authors:           Thomas B. Preusser
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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

-- Free-running counter that generates a strobe every ``DIVIDER``-th cycle in which ``Increment`` is asserted.
--
-- There is deliberately no output or specification of the counter value so as to allow an implementation to optimize
-- as much as possible.
--
-- ``Strobe`` is driven directly from a register. It is asserted for exactly one ``Clock`` cycle after ``DIVIDER``
-- cycles with an asserted ``Increment`` have been observed; an ``Increment`` in the strobe cycle already counts towards
-- the next period. ``Reset`` is synchronous. After ``Reset``, the first strobe follows ``DIVIDER - 1`` increments. For
-- ``DIVIDER = 1``, ``Strobe`` is ``Increment`` delayed by one cycle and ``Reset`` has no effect.
entity arith_Counter_Free is
	generic (
		DIVIDER   : positive  -- Number of ``Increment`` cycles per ``Strobe``.
	);
	port (
		-- Global Control
		Clock     : in  std_logic;  -- Clock; all inputs are sampled on its rising edge.
		Reset     : in  std_logic;  -- Synchronous reset; restarts the period.

		Increment : in  std_logic;  -- Count this cycle.
		Strobe    : out std_logic   -- End-of-period strobe; high for one cycle.
	);

	-- XXX: discuss generic
end entity;



architecture rtl of arith_Counter_Free is
begin

	genNoDiv: if DIVIDER = 1 generate
		process(Clock)
		begin
			if rising_edge(Clock) then
				Strobe <= Increment;
			end if;
		end process;
	end generate genNoDiv;
	genDoDiv: if DIVIDER > 1 generate
		-- Note: For DIVIDER=2**K+1, this could be marginally reduced to log2ceil(DIVIDER-1)
		--       if it was known that the increment input inc would never be deasserted.
		constant BITS : natural := log2ceil(DIVIDER);
		signal Cnt : unsigned(BITS downto 0) := (others => '0');

		signal cin : unsigned(0 downto 0);
	begin
		cin(0) <= not Increment;
		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					Cnt <= to_unsigned(DIVIDER-2, BITS+1);
				else
					Cnt <= Cnt + ite(Cnt(BITS) = '0', (Cnt'range => '1'), to_unsigned(DIVIDER-1, BITS+1)) + cin;
				end if;
			end if;
		end process;
		Strobe <= Cnt(BITS);
	end generate genDoDiv;

end architecture;
