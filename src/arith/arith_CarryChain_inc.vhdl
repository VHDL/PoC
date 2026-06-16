-- =============================================================================
-- Authors:  Patrick Lehmann
--
-- Entity:   Carry-chain abstraction for increment by one operations
--
-- Description:
-- -------------------------------------
-- This is a generic carry-chain abstraction for increment by one operations.
--
-- Sum <= A + (0...0) & CarryIn
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


entity arith_CarryChain_inc is
	generic (
		BITS      : positive
	);
	port (
		A       : in  std_logic_vector(BITS - 1 downto 0);
		CarryIn : in  std_logic                              := '1';
		Sum     : out std_logic_vector(BITS - 1 downto 0)
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
