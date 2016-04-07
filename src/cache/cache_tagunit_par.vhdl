-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
-- 
-- Module:					Tag-unit with fully-parallel compare of tag.
--
-- Description:
-- ------------------------------------
-- All inputs are synchronous to the rising-edge of the clock `clock`.
--
-- Command truth table:
-- 
--	Request | ReadWrite | Invalidate	| Replace | Command
--	--------+-----------+-------------+---------+--------------------------------
--		0			|		0				|		0					|		0			| None
--		1			|		0				|		0					|		0			| Read cache line
--		1			|		1				|		0					|		0			| Update cache line
--		1			|		0				|		1					|		0			| Read cache line and discard it
--		1			|		1				|		1					|		0			| Write cache line and discard it
--		0			|		-				|		0					|		1			| Replace cache line.
--	--------+-----------+-------------+------------------------------------------
--
-- All commands use `Tag` to lookup (request) or replace a cache line.
-- Each command is completed within one clock cycle.
--
-- Upon requests, the outputs `CacheMiss` and `CacheHit` indicate (high-active)
-- immediately (combinational) whether the `Tag` is stored within the cache, or not.
-- But, the cache-line usage is updated at the rising-edge of the clock.
--
-- The output `ReplaceIndex` indicates which cache line will be replaced as
-- next by a replace command. The output `OldTag` specifies the old tag stored at this
-- index. The replace command will store the `NewTag` and update the cache-line
-- usage at the rising-edge of the clock.
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library PoC;
use PoC.utils.all;
use PoC.vectors.all;

entity cache_tagunit_par is
	generic (
		REPLACEMENT_POLICY : string		:= "LRU";
		CACHE_LINES				 : positive := 32;
		ASSOCIATIVITY			 : positive := 32;
		TAG_BITS					 : positive := 8;
		USE_INITIAL_TAGS	 : boolean	:= false;
		INITIAL_TAGS			 : T_SLM		:= (0 downto 0 => (0 downto 0 => '0'))
	);
	port (
		Clock : in std_logic;
		Reset : in std_logic;

		Replace			 : in	 std_logic;
		ReplaceIndex : out std_logic_vector(log2ceilnz(CACHE_LINES) - 1 downto 0);
		NewTag			 : in	 std_logic_vector(TAG_BITS - 1 downto 0);
		OldTag			 : out std_logic_vector(TAG_BITS - 1 downto 0);

		Request		 : in	 std_logic;
		ReadWrite	 : in	 std_logic;
		Invalidate : in	 std_logic;
		Tag				 : in	 std_logic_vector(TAG_BITS - 1 downto 0);
		Index			 : out std_logic_vector(log2ceilnz(CACHE_LINES) - 1 downto 0);
		TagHit		 : out std_logic;
		TagMiss		 : out std_logic
	);
end;

architecture rtl of cache_tagunit_par is
	attribute KEEP : boolean;

	constant SETS : positive := CACHE_LINES / ASSOCIATIVITY;

begin
	-- ===========================================================================
	-- Full-Assoziative Cache
	-- ===========================================================================
	genFA : if (CACHE_LINES = ASSOCIATIVITY) generate
		constant FA_CACHE_LINES				: positive := ASSOCIATIVITY;
		constant FA_TAG_BITS					: positive := TAG_BITS;
		constant FA_MEMORY_INDEX_BITS : positive := log2ceilnz(FA_CACHE_LINES);

		subtype T_FA_TAG_LINE is std_logic_vector(FA_TAG_BITS - 1 downto 0);
		type T_FA_TAG_LINE_VECTOR is array (natural range <>) of T_FA_TAG_LINE;

		function to_validvector(slm : T_SLM) return std_logic_vector is
			variable result : std_logic_vector(CACHE_LINES - 1 downto 0);
		begin
			result := (others => '0');
			if not USE_INITIAL_TAGS then return result; end if;

			for I in slm'range loop
				result(I) := '1';
			end loop;
			return result;
		end function;

		function to_tagmemory(slm : T_SLM) return T_FA_TAG_LINE_VECTOR is
			variable result : T_FA_TAG_LINE_VECTOR(CACHE_LINES - 1 downto 0);
		begin
			result := (others => (others => '0'));
			if not USE_INITIAL_TAGS then return result; end if;

			for I in slm'range loop
				result(I) := get_row(slm, I);
			end loop;
			return result;
		end function;

		signal TagHits : std_logic_vector(FA_CACHE_LINES - 1 downto 0); -- includes Valid

		signal FA_TagMemory		: T_FA_TAG_LINE_VECTOR(FA_CACHE_LINES - 1 downto 0) := to_tagmemory(INITIAL_TAGS);
		signal FA_ValidMemory : std_logic_vector(FA_CACHE_LINES - 1 downto 0)			:= to_validvector(INITIAL_TAGS);

		signal FA_MemoryIndex_i	 : std_logic_vector(FA_MEMORY_INDEX_BITS - 1 downto 0);
		signal FA_MemoryIndex_us : unsigned(FA_MEMORY_INDEX_BITS - 1 downto 0);

		signal Policy_ReplaceIndex : std_logic_vector(FA_MEMORY_INDEX_BITS - 1 downto 0);
		signal FA_ReplaceIndex_us	 : unsigned(FA_MEMORY_INDEX_BITS - 1 downto 0);
		
		signal TagHit_i	 : std_logic; -- includes Valid and Request
		signal TagMiss_i : std_logic; -- includes Valid and Request
	begin
		
		-- generate comparators and convert hit-vector to binary index (cache line address)
		-- use process, so that "onehot2bin" does not report false errors in
		-- simulation due to delta-cycles updates
		process(Tag, FA_TagMemory, FA_ValidMemory)
			variable hits : std_logic_vector(FA_CACHE_LINES - 1 downto 0); -- includes Valid
		begin
			for i in 0 to FA_CACHE_LINES - 1 loop
				hits(i) := to_sl(FA_TagMemory(i) = Tag and FA_ValidMemory(i) = '1');
			end loop;

			TagHits 					<= hits;
			FA_MemoryIndex_us <= onehot2bin(hits, 0);
		end process;

		FA_MemoryIndex_i		<= std_logic_vector(FA_MemoryIndex_us);
		FA_ReplaceIndex_us	<= unsigned(Policy_ReplaceIndex);

		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Replace = '1') then
					FA_TagMemory(to_integer(FA_ReplaceIndex_us))	 <= NewTag;
				end if;

				for i in FA_ValidMemory'range loop
					if (Replace = '1' and FA_ReplaceIndex_us = i) or
						(Request = '1' and Invalidate = '1' and TagHits(i) = '1')
					then
						FA_ValidMemory(i) <= Replace; -- clear when Invalidate
					end if;
				end loop;
			end if;
		end process;

		-- hit/miss calculation
		TagHit_i	<= slv_or(TagHits) and Request;
		TagMiss_i <= not (slv_or(TagHits)) and Request;

		-- outputs
		Index		<= FA_MemoryIndex_i;
		TagHit	<= TagHit_i;
		TagMiss <= TagMiss_i;

		ReplaceIndex <= Policy_ReplaceIndex;
		OldTag			 <= FA_TagMemory(to_integer(FA_ReplaceIndex_us));

		-- replacement policy
		Policy : entity PoC.cache_replacement_policy
			generic map (
				REPLACEMENT_POLICY => REPLACEMENT_POLICY,
				CACHE_LINES				 => FA_CACHE_LINES
			)
			port map (
				Clock => Clock,
				Reset => Reset,

				Replace			 => Replace,
				ReplaceIndex => Policy_ReplaceIndex,

				TagAccess	 => TagHit_i,
				ReadWrite	 => ReadWrite,
				Invalidate => Invalidate,
				Index			 => FA_MemoryIndex_i
			);
	end generate;
	-- ==========================================================================================================================================================
	-- Direct-Mapped Cache
	-- ==========================================================================================================================================================
	genDM : if (ASSOCIATIVITY = 1) generate
		constant FA_CACHE_LINES				: positive := CACHE_LINES;
		constant FA_TAG_BITS					: positive := TAG_BITS;
		constant FA_MEMORY_INDEX_BITS : positive := log2ceilnz(FA_CACHE_LINES);

		signal FA_Tag	 : std_logic_vector(FA_TAG_BITS - 1 downto 0);
		signal TagHits : std_logic_vector(FA_CACHE_LINES - 1 downto 0);

		signal FA_MemoryIndex_i		: std_logic_vector(FA_MEMORY_INDEX_BITS - 1 downto 0);
		signal FA_MemoryIndex_us	: unsigned(FA_MEMORY_INDEX_BITS - 1 downto 0);
		signal FA_ReplaceIndex_us : unsigned(FA_MEMORY_INDEX_BITS - 1 downto 0);

		signal ValidHit	 : std_logic;
		signal TagHit_i	 : std_logic;
		signal TagMiss_i : std_logic;
	begin
--		-- generate comparators
--		genVectors : FOR I IN 0 TO FA_CACHE_LINES - 1 GENERATE
--			TagHits(I)			<= to_sl(TagMemory(I) = FA_Tag);
--		END GENERATE;
--		
--		-- convert hit-vector to binary index (cache line address)
--		FA_MemoryIndex_us		<= onehot2bin(TagHits);
--		FA_MemoryIndex_i		<= std_logic_vector(FA_MemoryIndex_us);
--		
--		-- Memories
--		FA_ReplaceIndex_us	<= FA_MemoryIndex_us;
--		
--		PROCESS(Clock)
--		BEGIN
--			IF rising_edge(Clock) THEN
--				IF (Replace = '1') THEN
--					TagMemory(to_integer(FA_ReplaceIndex_us))		<= NewTag;
--					ValidMemory(to_integer(FA_ReplaceIndex_us)) <= '1';
--				END IF;
--			END IF;
--		END PROCESS;
--		
--		-- access valid-vector
--		ValidHit					<= ValidMemory(to_integer(FA_MemoryIndex_us));
--		
--		-- hit/miss calculation
--		TagHit_i					<=			slv_or(TagHits) AND ValidHit	AND Request;
--		TagMiss_i				<= NOT (slv_or(TagHits) AND ValidHit) AND Request;
--		
--		-- outputs
--		Index					<= FA_MemoryIndex_i;
--		TagHit				<= TagHit_i;
--		TagMiss				<= TagMiss_i;		
--
--		genPolicy : FOR I IN 0 TO SETS - 1 GENERATE
--			policy : ENTITY PoC.cache_replacement_policy
--				GENERIC MAP (
--					REPLACEMENT_POLICY				=> REPLACEMENT_POLICY,
--					CACHE_LINES								=> ASSOCIATIVITY,
--					INITIAL_VALIDS						=> INITIAL_VALIDS(I * ASSOCIATIVITY + ASSOCIATIVITY - 1 DOWNTO I * ASSOCIATIVITY)
--				)
--				PORT MAP (
--					Clock											=> Clock,
--					Reset											=> Reset,
--					
--					Replace										=> Policy_Replace(I),
--					ReplaceIndex							=> Policy_ReplaceIndex(I),
--					
--					TagAccess									=> TagAccess(I),
--					ReadWrite									=> ReadWrite(I),
--					Invalidate								=> Invalidate(I),
--					Index											=> Policy_Index(I)
--				);
--		END GENERATE;
	end generate;
	-- ==========================================================================================================================================================
	-- Set-Assoziative Cache
	-- ==========================================================================================================================================================
	genSA : if ((ASSOCIATIVITY > 1) and (SETS > 1)) generate
		constant FA_CACHE_LINES				: positive := CACHE_LINES;
		constant SETINDEX_BITS				: natural	 := log2ceil(SETS);
		constant FA_TAG_BITS					: positive := TAG_BITS;
		constant FA_MEMORY_INDEX_BITS : positive := log2ceilnz(FA_CACHE_LINES);

		signal FA_Tag	 : std_logic_vector(FA_TAG_BITS - 1 downto 0);
		signal TagHits : std_logic_vector(FA_CACHE_LINES - 1 downto 0);

		signal FA_MemoryIndex_i		: std_logic_vector(FA_MEMORY_INDEX_BITS - 1 downto 0);
		signal FA_MemoryIndex_us	: unsigned(FA_MEMORY_INDEX_BITS - 1 downto 0);
		signal FA_ReplaceIndex_us : unsigned(FA_MEMORY_INDEX_BITS - 1 downto 0);

		signal ValidHit	 : std_logic;
		signal TagHit_i	 : std_logic;
		signal TagMiss_i : std_logic;
	begin
--		-- generate comparators
--		genVectors : FOR I IN 0 TO FA_CACHE_LINES - 1 GENERATE
--			TagHits(I)			<= to_sl(TagMemory(I) = FA_Tag);
--		END GENERATE;
--		
--		-- convert hit-vector to binary index (cache line address)
--		FA_MemoryIndex_us		<= onehot2bin(TagHits);
--		FA_MemoryIndex_i		<= std_logic_vector(FA_MemoryIndex_us);
--		
--		-- Memories
--		FA_ReplaceIndex_us	<= FA_MemoryIndex_us;
--		
--		PROCESS(Clock)
--		BEGIN
--			IF rising_edge(Clock) THEN
--				IF (Replace = '1') THEN
--					TagMemory(to_integer(FA_ReplaceIndex_us))		<= NewTag;
--					ValidMemory(to_integer(FA_ReplaceIndex_us)) <= '1';
--				END IF;
--			END IF;
--		END PROCESS;
--		
--		-- access valid-vector
--		ValidHit					<= ValidMemory(to_integer(FA_MemoryIndex_us));
--		
--		-- hit/miss calculation
--		TagHit_i					<=			slv_or(TagHits) AND ValidHit	AND Request;
--		TagMiss_i				<= NOT (slv_or(TagHits) AND ValidHit) AND Request;
--		
--		-- outputs
--		Index					<= FA_MemoryIndex_i;
--		TagHit				<= TagHit_i;
--		TagMiss				<= TagMiss_i;		
--
--		genPolicy : FOR I IN 0 TO SETS - 1 GENERATE
--			policy : ENTITY PoC.cache_replacement_policy
--				GENERIC MAP (
--					REPLACEMENT_POLICY				=> REPLACEMENT_POLICY,
--					CACHE_LINES								=> ASSOCIATIVITY,
--					INITIAL_VALIDS						=> INITIAL_VALIDS(I * ASSOCIATIVITY + ASSOCIATIVITY - 1 DOWNTO I * ASSOCIATIVITY)
--				)
--				PORT MAP (
--					Clock											=> Clock,
--					Reset											=> Reset,
--					
--					Replace										=> Policy_Replace(I),
--					ReplaceIndex							=> Policy_ReplaceIndex(I),
--					
--					TagAccess									=> TagAccess(I),
--					ReadWrite									=> ReadWrite(I),
--					Invalidate								=> Invalidate(I),
--					Index											=> Policy_Index(I)
--				);
--		END GENERATE;
	end generate;
end architecture;
