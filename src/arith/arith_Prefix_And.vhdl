-- =============================================================================
-- Authors:          Thomas B. Preusser
--                  Patrick Lehmann
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universität Dresden - Germany
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
use     work.arith.all;


-- Prefix AND computation.
--
-- Combinational: ``y(i)`` is the AND of ``x(i downto 0)``, i.e.
-- ``y(i) <= '1' when x(i downto 0) = (i downto 0 => '1') else '0';``.
--
-- The prefix is computed on a carry chain. On Xilinx devices, ``arith_Prefix_And_Xilinx`` instantiates the carry-chain
-- primitives; on other devices, the carry chain is inferred from an addition.
entity arith_Prefix_And is
	generic (
		BITS : positive  -- Width of ``x`` and ``y`` in bits.
	);
	port (
		x : in  std_logic_vector(BITS-1 downto 0);  -- Input vector.
		y : out std_logic_vector(BITS-1 downto 0)   -- Prefix AND: ``y(i)`` is the AND of ``x(i downto 0)``.
	);
end entity;


architecture rtl of arith_Prefix_And is
begin
	-- Generic Carry Chain through Addition
	genGeneric: if VENDOR /= VENDOR_XILINX generate
		y(0) <= x(0);
		gen1: if BITS > 1 generate
			signal  p : unsigned(BITS-1 downto 1);
		begin
			p(1) <= x(0) and x(1);
			gen2: if BITS > 2 generate
				signal  s : std_logic_vector(BITS downto 1);
			begin
				p(BITS-1 downto 2) <= unsigned(x(BITS-1 downto 2));
				s <= std_logic_vector(('0' & p) + 1);
				y(BITS-1 downto 2) <= s(BITS downto 3) xor ('0' & x(BITS-1 downto 3));
			end generate gen2;
			y(1) <= p(1);
		end generate gen1;
	end generate;
	genXilinx : if VENDOR = VENDOR_XILINX generate
		prefix : arith_Prefix_And_Xilinx
			generic map (
				BITS    => BITS
			)
			port map (
				x    => x,
				y    => y
			);
	end generate;
end architecture;
