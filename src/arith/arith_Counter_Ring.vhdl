-- =============================================================================
-- Authors:           Patrick Lehmann
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

use     work.utils.all;


-- Up/down ring counter or Johnson counter with a loadable start pattern.
--
-- The counter rotates its ``BITS``-wide state by one position per ``Clock`` cycle: ``Increment`` shifts towards the
-- MSB and feeds the old MSB into the LSB, ``Decrement`` shifts towards the LSB and feeds the old LSB into the MSB.
-- ``Increment`` has priority over ``Decrement``. With ``INVERT_FEEDBACK`` enabled, the fed-back bit is inverted, which
-- turns the ring counter into a Johnson counter.
--
-- ``Reset`` is synchronous and loads ``Seed``. ``Value`` is the registered counter state.
entity arith_Counter_Ring is
	generic (
		BITS            : positive;            -- Width of the counter in bits.
		INVERT_FEEDBACK : boolean    := FALSE  -- ``FALSE``: ring counter; ``TRUE``: Johnson counter.
	);
	port (
		Clock     : in  std_logic;                                               -- Clock; inputs sampled on rising edge.
		Reset     : in  std_logic;                                               -- Synchronous reset; loads ``Seed``.
		Seed      : in  std_logic_vector(BITS - 1 downto 0) := (others => '0');  -- Counter pattern loaded by ``Reset``.
		Increment : in  std_logic                           := '0';              -- Rotate towards the MSB.
		Decrement : in  std_logic                           := '0';              -- Rotate towards the LSB.
		Value     : out std_logic_vector(BITS - 1 downto 0)                      -- Counter state.
	);
end entity;


architecture rtl of arith_Counter_Ring is
	constant invert    : std_logic      := to_sl(INVERT_FEEDBACK);

	signal Counter    : std_logic_vector(BITS - 1 downto 0)  := (others => '0');

begin
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Counter      <= Seed;
			elsif (Increment = '1') then
				Counter    <= Counter(Counter'high - 1 downto 0) & (Counter(Counter'high) xor invert);
			elsif (Decrement = '1') then
				Counter    <= (Counter(0) xor invert) & Counter(Counter'high downto 1);
			end if;
		end if;
	end process;

	Value    <= Counter;
end architecture;
