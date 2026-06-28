-- =============================================================================
-- Authors:         Thomas B. Preusser
--
-- Entity:          Computes XOR masks for stream scrambling from an LFSR generator.
--
-- Description:
-- -------------------------------------
-- The LFSR computation is unrolled to generate an arbitrary number of mask
-- bits in parallel. The mask are output in little endian. The generated bit
-- sequence is independent from the chosen output width.
--
-- License:
-- =============================================================================
-- Copyright 2015-2025 The PoC-Library Authors
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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


entity comm_Scramble is
	generic (
		POLYNOMIAL : bit_vector;       -- Generator Polynomial (little endian)
		BITS       : positive          -- Width of Mask Bits to be computed in parallel in each step
	);
	port (
		Clock  : in  std_logic;    -- Clock

		Load   : in  std_logic;    -- Set LFSR to value provided on din
		Seed   : in  std_logic_vector(POLYNOMIAL'length-2 downto 0) := (others => '0');

		Enable : in  std_logic;    -- Compute a Mask Output
		Value  : out std_logic_vector(BITS-1 downto 0)
	);
end entity;


architecture rtl of comm_Scramble is

	-----------------------------------------------------------------------------
	-- Normalizes a generator representation:
	--   - into a 'downto 0' index range and
	--   - truncating it just below the most significant and so hidden '1'.
	function normalize(G : bit_vector) return bit_vector is
		variable GN : bit_vector(G'length-1 downto 0);
	begin
		GN := G;
		for i in GN'left downto 1 loop
			if GN(i) = '1' then
				return GN(i-1 downto 0);
			end if;
		end loop;
		report "PoC.comm_Scramble:: Cannot use absolute constant as generator." severity failure;
		return "0";
	end function;

	-- Normalized Generator
	constant NORMALIZED_GENERATOR : bit_vector := normalize(POLYNOMIAL);

	-- LFSR Value
	signal lfsr : std_logic_vector(NORMALIZED_GENERATOR'range);

begin
	process(Clock)
		-- Intermediate LFSR Values for single-bit Steps
		variable v : std_logic_vector(lfsr'range);
	begin
		if rising_edge(Clock) then
			if Load = '1' then
				lfsr <= Seed(lfsr'range);
			elsif Enable = '1' then
				v := lfsr;
				for i in 0 to BITS-1 loop
					Value(i) <=  v(v'left);
					v := (v(v'left-1 downto 0) & '0') xor (to_stdlogicvector(NORMALIZED_GENERATOR) and (NORMALIZED_GENERATOR'range => v(v'left)));
				end loop;
				lfsr <= v;
			end if;
		end if;
	end process;

end architecture;
