-- =============================================================================
-- Authors:          Thomas B. Preusser
--
-- =============================================================================
-- Copyright 2007-2015 Technische Universität Dresden - Germany,
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

library UNISIM;
use     UNISIM.vComponents.all;


-- Xilinx-specific overflow detection of a guarded increment on the carry chain.
--
-- Combinational: ``v`` is ``'1'`` if incrementing ``p`` by ``g`` overflows, i.e. if ``g`` is ``'1'`` and all bits of
-- ``p`` are ``'1'``. The guard ``g`` feeds a chain of one ``MUXCY`` primitive per bit of ``p``.
entity arith_inc_ovcy_xilinx is
	generic (
		BITS : positive  -- Width of ``p`` in bits.
	);
	port (
		p : in  std_logic_vector(BITS-1 downto 0);  -- Argument to increment.
		g : in  std_logic;                          -- Increment guard: ``'1'`` increments ``p``.
		v : out std_logic                           -- Overflow: ``g`` is ``'1'`` and ``p`` is all ones.
	);
end entity;


architecture rtl of arith_inc_ovcy_xilinx is
	signal c : std_logic_vector(BITS downto 0);  -- Carry Chain Links
begin  -- rtl

	-- Feed Chain with Guard
	c(0) <= g;

	-- Instantiate Carry Chain
	genCC: for i in 0 to BITS-1 generate
		m : MUXCY
			port map (
				O  => c(i+1),
				CI => c(i),
				DI => '0',
				S  => p(i)
			);
	end generate genCC;

	-- Output from final Carry
	v <= c(BITS);

end architecture;
