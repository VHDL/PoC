-- =============================================================================
-- Authors:  Patrick Lehmann
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
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

library Unisim;
use     Unisim.VComponents.all;


-- Xilinx-specific carry-chain implementation of an increment-by-one operation.
--
-- Combinational: ``Sum`` is ``A + CarryIn`` modulo ``2**BITS``; the carry out of the MSB is dropped. Each bit is
-- built from one ``MUXCY`` and one ``XORCY`` primitive of the dedicated carry chain.
entity arith_CarryChain_inc_Xilinx is
	generic (
		BITS      : positive  -- Width of ``A`` and ``Sum`` in bits.
	);
	port (
		A       : in  std_logic_vector(BITS - 1 downto 0);            -- Operand.
		CarryIn : in  std_logic                              := '1';  -- Value added to ``A`` (``'1'``: increment).
		Sum     : out std_logic_vector(BITS - 1 downto 0)             -- ``A + CarryIn``, truncated to ``BITS`` bits.
	);
end entity;


architecture rtl of arith_CarryChain_inc_Xilinx is
	signal ci    : std_logic_vector(BITS downto 0);

begin
	ci(0) <= CarryIn;

	genBits : for i in 0 to BITS - 1 generate
		cc_mux : component MUXCY
			port map (
				O  => ci(i + 1),
				CI => ci(i),
				DI => '0',
				S  => A(i)
			);
		cc_xor : component XORCY
			port map (
				O  => Sum(i),
				CI => ci(i),
				LI => A(i)
			);
	end generate;
 end architecture;

