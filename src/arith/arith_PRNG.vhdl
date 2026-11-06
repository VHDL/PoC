-- =============================================================================
-- Authors:                    Martin Zabel
--                             Patrick Lehmann
--                             Jonas Schreiner
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
--        http://www.apache.org/licenses/LICENSE-2.0
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
use     work.arith.all;


-- Pseudo-random number generator (PRNG) based on a linear-feedback shift register (LFSR).
--
-- The ``BITS``-wide LFSR uses an internal list of FPGA-optimized polynomials from 3 to 168 bits (see
-- ``arith_prbs_lfsr`` in package ``arith``); other widths fail an assertion. The polynomials have at most 5 tap
-- positions, so that long shift registers can be inferred instead of single flip-flops. The feedback uses XNOR gates:
-- the generated number sequence includes the value all-zeros, but not all-ones.
--
-- ``Value`` is the registered LFSR state. Each ``Clock`` cycle with ``Got`` high advances it to the next number.
-- ``Reset`` is synchronous and loads ``InitialValue``, resized to ``BITS`` bits. The power-up value is ``SEED``,
-- resized likewise.
entity arith_PRNG is
	generic (
		BITS : positive;                -- Width of ``Value`` in bits (3 to 168).
		SEED : std_logic_vector := "0"  -- Power-up value; default of ``InitialValue``.
	);
	port (
		Clock        : in  std_logic;                           -- Clock; all inputs are sampled on its rising edge.
		Reset        : in  std_logic;                           -- Synchronous reset; loads ``InitialValue``.

		InitialValue : in  std_logic_vector := SEED;            -- Value loaded by ``Reset``; must not be all-ones.
		Got          : in  std_logic;                           -- ``Value`` was consumed; advance to the next one.
		Value        : out std_logic_vector(BITS - 1 downto 0)  -- Current pseudo-random number.
	);
end entity;


architecture rtl of arith_PRNG is
		-- The current value
		signal val_r : std_logic_vector(BITS - 1 downto 0) := resize(SEED, BITS);
begin
		assert ((3 <= BITS) and (BITS <= 168)) report "Width not yet supported." severity failure;

		-----------------------------------------------------------------------------
		-- Register
		-----------------------------------------------------------------------------
		process (Clock)
		begin
				if rising_edge(Clock) then
						if Reset = '1' then
								val_r <= resize(InitialValue, BITS);
						elsif Got = '1' then
								val_r <= arith_prbs_lfsr(val_r);
						end if;
				end if;
		end process;

		Value <= val_r;
end architecture;
