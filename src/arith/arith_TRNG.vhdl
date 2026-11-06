-- =============================================================================
-- Authors:          Thomas B. Preusser
--
-- License:
-- =============================================================================
-- Copyright 2007-2017 Technische Universitaet Dresden - Germany
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

-- True random number generator (TRNG) based on sampling combinational loops of interleaved X(N)OR gates.
--
-- ``BITS`` oscillators form a ring: each one is the XOR (the first three: XNOR) of itself and its two neighbors. Their
-- outputs are sampled into the ``Clock`` domain by ``sync_Bits``; ``Value`` carries these synchronized samples.
--
-- Always verify the randomness of this TRNG implementation for your concrete target platform, for instance, using the
-- `dieharder <http://www.phy.duke.edu/~rgb/General/dieharder.php>`__ test by Robert G. Brown, which is also directly
-- available for many GNU/Linux distributions, e.g. Debian. Ideally, randomness would be verified for varying operating
-- conditions.
--
-- This design involves fast-switching combinational loops on purpose so as to serve as sources of entropy. This implies
-- a relevant local power consumption. Do not cramp large parts of a chip with these TRNGs without ensuring appropriate
-- heat dissipation. It often requires special constraints or directives to enforce the proper synthesis of these
-- combinational loops by the tools.
entity arith_TRNG is
	generic (
		BITS : positive  -- Number of oscillators; width of ``Value``.
	);
	port (
		Clock : in  std_logic;                         -- Sampling clock.
		Value : out std_logic_vector(BITS-1 downto 0)  -- Synchronized oscillator samples.
	);
end entity;

architecture rtl of arith_TRNG is
	signal osc : std_logic_vector(BITS-1 downto 0) := (others => '-');  -- Oscillators
	attribute KEEP : boolean;
	attribute KEEP of osc : signal is true;
begin

	-- Oscillator Leaves
	genOscillate : for i in 0 to BITS-1 generate
		osc(i) <= ite(i<3, '1', '0') xor osc((i-1)mod BITS) xor osc(i) xor osc((i+1)mod BITS);
	end generate;

	sync : entity work.sync_Bits
		generic map (
			BITS => BITS
		)
		port map (
			Clock  => Clock,
			Input  => osc,
			Output => Value
		);

end architecture;
