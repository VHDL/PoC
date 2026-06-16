-- =============================================================================
-- Authors:           Thomas B. Preusser
--
-- Entity:           VHDL package for component declarations, types and
--                  functions associated to the PoC.comm namespace
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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


package comm is
	-- Calculates the Remainder of the Division by the Generator Polynomial GEN.
	component comm_CRC is
		generic (
			POLYNOMIAL : bit_vector;                                      -- Generator Polynom
			BITS       : positive                                        -- Number of Bits to be processed in parallel
		);
		port (
			Clock     : in  std_logic;                                       -- Clock

			Load      : in  std_logic;                                       -- Parallel Preload of Remainder
			Seed      : in  std_logic_vector(POLYNOMIAL'length-2 downto 0);  --
			Enable    : in  std_logic;                                       -- Process Input Data (MSB first)
			DataIn    : in  std_logic_vector(BITS-1 downto 0);               --

			Remainder : out std_logic_vector(POLYNOMIAL'length-2 downto 0);  -- Remainder
			IsZero    : out std_logic                                        -- Remainder is Zero
		);
	end component;

	-- Computes XOR masks for stream scrambling from an LFSR generator.
	component comm_Scramble is
		generic (
			POLYNOMIAL : bit_vector;                                      -- Generator Polynomial (little endian)
			BITS       : positive                                        -- Width of Mask Bits to be computed in parallel
		);
		port (
			Clock  : in  std_logic;                                       -- Clock

			Load   : in  std_logic;                                       -- Set LFSR to provided Value
			Seed   : in  std_logic_vector(POLYNOMIAL'length-2 downto 0);  --

			Enable : in  std_logic;                                       -- Compute a Mask Output
			Value  : out std_logic_vector(BITS-1 downto 0)                --
		);
	end component;
end package;
