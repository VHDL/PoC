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
use     IEEE.numeric_std.all;

use     work.config.all;
use     work.utils.all;
use     work.arith.all;


-- Carry-chain abstraction for increment-by-one operations.
--
-- Combinational: ``Sum`` is ``A + CarryIn`` modulo ``2**BITS``; the carry out of the MSB is dropped.
--
-- On Xilinx devices, synthesis (not simulation) with ``BITS > 4`` instantiates ``arith_CarryChain_inc_Xilinx`` to force
-- the use of the dedicated carry chain. Otherwise, the increment is a plain ``numeric_std`` addition.
entity arith_CarryChain_inc is
	generic (
		BITS      : positive  -- Width of ``A`` and ``Sum`` in bits.
	);
	port (
		A       : in  std_logic_vector(BITS - 1 downto 0);            -- Operand.
		CarryIn : in  std_logic                              := '1';  -- Value added to ``A`` (``'1'``: increment).
		Sum     : out std_logic_vector(BITS - 1 downto 0)             -- ``A + CarryIn``, truncated to ``BITS`` bits.
	);
end entity;


architecture rtl of arith_CarryChain_inc is
	-- Force Carry-chain use for pointer increments on Xilinx architectures
	constant XILINX_FORCE_CARRYCHAIN : boolean := (not SIMULATION) and (VENDOR = VENDOR_XILINX) and (BITS > 4);

begin
	genGeneric : if not XILINX_FORCE_CARRYCHAIN generate
		signal Cin_vec : unsigned(0 downto 0);
	begin
		Cin_vec(0) <= CarryIn; -- WORKAROUND: for GHDL
		Sum <= std_logic_vector(unsigned(A) + Cin_vec);
	end generate;

	genXilinx : if XILINX_FORCE_CARRYCHAIN generate
		inc : component arith_CarryChain_inc_Xilinx
			generic map (
				BITS    => BITS
			)
			port map (
				A        => A,
				CarryIn  => CarryIn,
				Sum      => Sum
			);
	end generate;
end architecture;
