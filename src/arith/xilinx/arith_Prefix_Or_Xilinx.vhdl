-- =============================================================================
-- Authors:          Thomas B. Preusser
--                  Patrick Lehmann
--
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

library UniSim;
use     UniSim.VComponents.all;


-- Xilinx-specific prefix OR computation on the carry chain.
--
-- Combinational: ``y(i)`` is the OR of ``x(i downto 0)``, i.e.
-- ``y(i) <= '0' when x(i downto 0) = (i downto 0 => '0') else '1';``.
--
-- ``y(0)`` and ``y(1)`` are computed in logic. For ``BITS > 2``, the remaining bits are built from one ``MUXCY``
-- primitive per bit.
entity arith_Prefix_Or_Xilinx is
	generic (
		BITS : positive  -- Width of ``x`` and ``y`` in bits.
	);
	port (
		x : in  std_logic_vector(BITS-1 downto 0);  -- Input vector.
		y : out std_logic_vector(BITS-1 downto 0)   -- Prefix OR: ``y(i)`` is the OR of ``x(i downto 0)``.
	);
end entity;


architecture rtl of arith_Prefix_Or_Xilinx is
	constant d : std_logic_vector(BITS-2 downto 0) := (BITS-2 downto 1 => '1') & '0';
	signal   c : std_logic_vector(BITS-1 downto 0);
begin
	y(0) <= x(0);
	gen1: if BITS > 1 generate
		signal  p : unsigned(BITS-1 downto 1);
	begin
		p(1) <= x(0) or x(1);
		gen2: if BITS > 2 generate
			p(BITS-1 downto 2) <= not unsigned(x(BITS-1 downto 2));
			c(0) <= '1';
			genChain: for i in 1 to BITS-1 generate
				mux : MUXCY
					port map (
						S  => p(i),
						DI => d(i-1),
						CI => c(i-1),
						O  => c(i)
					);
			end generate genChain;
			y(BITS-1 downto 2) <= c(BITS-1 downto 2);
		end generate gen2;
		y(1) <= p(1);
	end generate gen1;
end architecture;
