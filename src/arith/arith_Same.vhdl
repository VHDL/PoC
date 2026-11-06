-- =============================================================================
-- Authors:          Thomas B. Preusser
--
-- License:
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
use     IEEE.numeric_std.all;

use     work.config.all;
use     work.utils.all;
use     work.arith.all;


-- Detects whether all bit positions of a ``std_logic_vector`` have the same value.
--
-- Combinational: ``y`` is ``'1'`` if ``g`` is ``'1'`` and all bits of ``x`` are equal. This circuit may, for instance,
-- be used to detect the first sign change and, thus, the range of a two's complement number.
--
-- ``x`` is split into overlapping slices that fit into one LUT each; their results are combined on a carry chain. On
-- Xilinx devices, the carry chain is instantiated by ``arith_inc_ovcy_xilinx``; otherwise, it is inferred from an
-- addition.
--
-- These components may be chained by using the output of the predecessor as guard input. This chaining allows to have
-- intermediate results available while still ensuring the use of a fast carry chain on supporting FPGA architectures.
-- When chaining, make sure to overlap both vector slices by one bit position as to avoid an undetected sign change
-- between the slices.
entity arith_Same is
	generic (
		BITS : positive  -- Width of ``x`` in bits.
	);
	port (
		g : in  std_logic := '1';                   -- Guard input; ``'0'`` forces ``y`` to ``'0'``.
		x : in  std_logic_vector(BITS-1 downto 0);  -- Input vector.
		y : out std_logic                           -- ``g`` is high and all bits of ``x`` are equal.
	);
end entity;


architecture rtl of arith_Same is
	constant DEV_INFO  : T_DEVICE_INFO    := DEVICE_INFO;

	constant K : positive := DEV_INFO.LUT_FanIn;      -- LUT Fanin
	constant M : positive := (BITS-2+1/BITS)/(K-1) + 1;      -- Required Stage Count
	signal   p : std_logic_vector(M-1 downto 0);      -- Stage Propagates

begin

	-- Compute Propagates in LUT Stages
	genCC: for i in 0 to M-1 generate
		-- Relevant Vector Slice
		constant LO : natural :=            i   *(K-1);
		constant HI : natural := imin(BITS-1, (i+1)*(K-1));
	begin
		p(i) <= '1' when x(HI downto LO) = (HI downto LO => '0') else
						'1' when x(HI downto LO) = (HI downto LO => '1') else
						'0';
	end generate;

	-- Compute Equivalence in Carry Chain
	genXLXn: if DEV_INFO.Vendor /= VENDOR_XILINX generate
		signal   s : std_logic_vector(M downto 0);
	begin
		-- Infere Carry Chain from Addition
		s <= std_logic_vector(unsigned('0' & p) + (0 to 0 => g));
		y <= s(M);
	end generate genXLXn;

	genXLXy: if DEV_INFO.Vendor = VENDOR_XILINX generate
		i: arith_inc_ovcy_xilinx
			generic map (
				BITS => M
			)
			port map (
				p => p,
				g => g,
				v => y
			);
	end generate genXLXy;
end architecture;
