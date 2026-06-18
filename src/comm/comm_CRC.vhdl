-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Patrick Lehmann
--                  Matthias Sund
--                  Stefan Unrein
--
-- Entity:          Computes the Cyclic Redundancy Check (CRC)
--
-- Description:
-- -------------------------------------
-- Computes the Cyclic Redundancy Check (CRC) for a data packet as remainder
-- of the polynomial division of the message by the given generator
-- polynomial (GEN).
--
-- The computation is unrolled so as to process an arbitrary number of
-- message bits per step. The generated CRC is independent from the chosen
-- processing width.
--
-- With Chunk-Enable you can enable chunks for calculation. Usually used as
-- Byte-Enables if streamed packets are not multiple of CRC-Size or interface
-- width. Using Chunk-Enables has a significant performance hit, use only if
-- necessary.
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

use     work.utils.all;


entity comm_CRC is
	generic (
		POLYNOMIAL  : bit_vector;                       -- Generator Polynomial
		BITS        : positive;                         -- Number of Bits to be processed in parallel
		CHUNK_BITS  : positive := BITS;                 -- Bus width for 'en' port

		INIT        : std_logic_vector   := "0";
		OUTPUT_REGS : boolean            := true
	);
	port (
		Clock       : in  std_logic;                                -- Clock

		Load        : in  std_logic;                                -- Parallel Preload of Remainder
		Seed        : in  std_logic_vector(abs(mssb_idx(POLYNOMIAL)-POLYNOMIAL'right)-1 downto 0);  --
		Enable      : in  std_logic;                                -- Process Input Data (MSB first)
		ChunkEnable : in  std_logic_vector(CHUNK_BITS-1 downto 0) := (CHUNK_BITS-1 downto 0 => '1'); -- Chunk Enable
		DataIn      : in  std_logic_vector(BITS-1 downto 0);

		Remainder   : out std_logic_vector(abs(mssb_idx(POLYNOMIAL)-POLYNOMIAL'right)-1 downto 0);
		IsZero      : out std_logic                                                  -- Remainder is Zero
	);
end entity;


architecture rtl of comm_CRC is

	-----------------------------------------------------------------------------
	-- Normalizes the generator representation:
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

		report "Cannot use absolute constant as generator." severity failure;

		return GN;
	end function;

	-- XXX: do assert in function really trigger?
	function dcr_check(data_bits : positive; chunk_bits : positive) return positive is
	begin
		assert data_bits >= chunk_bits
			report "Generic 'BITS' must be greater or equal to generic 'CHUNK_BITS'."
			severity failure;
		assert data_bits mod chunk_bits = 0
			report "Generic 'BITS' must be an integer multiple of generic 'CHUNK_BITS'."
			severity failure;
		return data_bits / chunk_bits;
	end function;

	-- Normalized Generator
	constant NORMALIZED_GENERATOR : std_logic_vector := to_stdlogicvector(normalize(POLYNOMIAL));

	-- data-chunk lengths ratio
	constant DCR : positive := dcr_check(BITS, CHUNK_BITS);

	-- LFSR Value
	signal lfsr : std_logic_vector(NORMALIZED_GENERATOR'range) := resize(descend(INIT), NORMALIZED_GENERATOR'length);
	signal lfsn : std_logic_vector(NORMALIZED_GENERATOR'range);  -- Next Value
	signal lfso : std_logic_vector(NORMALIZED_GENERATOR'range);  -- Output

begin

	-- Compute next combinational Value
	process(all)
		variable v : std_logic_vector(lfsr'range);
	begin
		v := lfsr;
		for i in BITS-1 downto 0 loop
			if ChunkEnable(i/DCR) = '1' then
				v := (v(v'left-1 downto 0) & '0') xor (NORMALIZED_GENERATOR and (NORMALIZED_GENERATOR'range => (DataIn(i) xor v(v'left))));
			end if;
		end loop;
		lfsn <= v;
	end process;

	-- Remainder Register
	process(Clock)
	begin
		if rising_edge(Clock) then
			if Load = '1' then
				lfsr <= Seed(lfsr'range);
			elsif Enable = '1' then
				lfsr <= lfsn;
			end if;
		end if;
	end process;

	-- Provide Outputs
	lfso      <= lfsr when OUTPUT_REGS else lfsn;
	Remainder <= lfso;
	IsZero    <= '1' when lfso = (lfso'range => '0') else '0';

end architecture;
