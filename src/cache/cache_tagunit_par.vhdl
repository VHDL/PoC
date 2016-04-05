-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;

-- cache_tagunit_par
--		par = parallel
--		seq = sequential

ENTITY cache_tagunit_par IS
	GENERIC (
		REPLACEMENT_POLICY				: STRING													:= "LRU";
		CACHE_LINES								: POSITIVE												:= 32;
		ASSOCIATIVITY							: POSITIVE												:= 32;
		TAG_BITS									: POSITIVE												:= 8;
		USE_INITIAL_TAGS 					: BOOLEAN 												:= false;
		INITIAL_TAGS							: T_SLM 													:= (0 downto 0 => (0 downto 0 => '0'))
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		Replace										: IN	STD_LOGIC;
		NewTag										: IN	STD_LOGIC_VECTOR(TAG_BITS - 1 DOWNTO 0);
		NewIndex									: OUT	STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);		
		OldTag										: OUT	STD_LOGIC_VECTOR(TAG_BITS - 1 DOWNTO 0);
		OldIndex									: OUT	STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);
		Replaced									: OUT	STD_LOGIC;
		
		Request										: IN	STD_LOGIC;
		ReadWrite									: IN	STD_LOGIC;
		Invalidate								: IN	STD_LOGIC;
		Tag												: IN	STD_LOGIC_VECTOR(TAG_BITS - 1 DOWNTO 0);
		Index											: OUT	STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);
		TagHit										: OUT	STD_LOGIC;
		TagMiss										: OUT	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF cache_tagunit_par IS
	ATTRIBUTE KEEP										: BOOLEAN;

	CONSTANT SETS											: POSITIVE				:= CACHE_LINES / ASSOCIATIVITY;

BEGIN
	-- ==========================================================================================================================================================
	-- Full-Assoziative Cache
	-- ==========================================================================================================================================================
	genFA : IF (CACHE_LINES = ASSOCIATIVITY) GENERATE
		CONSTANT FA_CACHE_LINES					: POSITIVE					:= ASSOCIATIVITY;
		CONSTANT FA_TAG_BITS						: POSITIVE					:= TAG_BITS;
		CONSTANT FA_MEMORY_INDEX_BITS		: POSITIVE					:= log2ceilnz(FA_CACHE_LINES);

		SUBTYPE	T_FA_TAG_LINE						IS STD_LOGIC_VECTOR(FA_TAG_BITS - 1 DOWNTO 0);
		TYPE		T_FA_TAG_LINE_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_FA_TAG_LINE;

		FUNCTION to_validvector(slm : T_SLM) RETURN STD_LOGIC_VECTOR IS
			VARIABLE result		: STD_LOGIC_VECTOR(CACHE_LINES - 1 DOWNTO 0);
		BEGIN
			result := (others => '0');
			if not USE_INITIAL_TAGS then return result; end if;
			
			FOR I IN slm'range LOOP
				result(I)	:= '1';
			END LOOP;
			RETURN result;
		END FUNCTION;

		FUNCTION to_tagmemory(slm : T_SLM) RETURN T_FA_TAG_LINE_VECTOR IS
			VARIABLE result		: T_FA_TAG_LINE_VECTOR(CACHE_LINES - 1 DOWNTO 0);
		BEGIN
			result := (others => (others => '0'));
			if not USE_INITIAL_TAGS then return result; end if;
			
			FOR I IN slm'range LOOP
				result(I)	:= get_row(slm, I);
			END LOOP;
			RETURN result;
		END FUNCTION;
		
		SIGNAL TagHits									: STD_LOGIC_VECTOR(FA_CACHE_LINES - 1 DOWNTO 0);

		SIGNAL FA_TagMemory							: T_FA_TAG_LINE_VECTOR(FA_CACHE_LINES - 1 DOWNTO 0)		:= to_tagmemory(INITIAL_TAGS);
		SIGNAL FA_ValidMemory						: STD_LOGIC_VECTOR(FA_CACHE_LINES - 1 DOWNTO 0)				:= to_validvector(INITIAL_TAGS);

		SIGNAL FA_MemoryIndex_i					: STD_LOGIC_VECTOR(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);
		SIGNAL FA_MemoryIndex_us				: UNSIGNED(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);

		SIGNAL FA_Replace								: STD_LOGIC;
		SIGNAL Policy_ReplaceIndex			: STD_LOGIC_VECTOR(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);
		SIGNAL FA_ReplaceIndex_us				: UNSIGNED(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);

		SIGNAL ValidHit									: STD_LOGIC;
		SIGNAL TagHit_i									: STD_LOGIC;
		SIGNAL TagMiss_i								: STD_LOGIC;
		
		SIGNAL TagAccess								: STD_LOGIC;
	BEGIN
		-- generate comparators
		genVectors : FOR I IN 0 TO FA_CACHE_LINES - 1 GENERATE
			TagHits(I)			<= to_sl(FA_TagMemory(I) = Tag);
		END GENERATE;
		
		-- convert hit-vector to binary index (cache line address)
		FA_MemoryIndex_us		<= onehot2bin(TagHits);
		FA_MemoryIndex_i		<= std_logic_vector(FA_MemoryIndex_us);
		
		-- Memories
		FA_Replace					<= Replace;
		FA_ReplaceIndex_us	<= unsigned(Policy_ReplaceIndex);
		
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (FA_Replace = '1') THEN
					FA_TagMemory(to_integer(FA_ReplaceIndex_us))		<= NewTag;
					FA_ValidMemory(to_integer(FA_ReplaceIndex_us))	<= '1';
				END IF;
			END IF;
		END PROCESS;
		
		-- access valid-vector
		ValidHit			<= FA_ValidMemory(to_integer(FA_MemoryIndex_us));
		
		-- hit/miss calculation
		TagHit_i			<=			slv_or(TagHits) AND ValidHit	AND Request;
		TagMiss_i			<= NOT (slv_or(TagHits) AND ValidHit)	AND Request;

		-- outputs
		Index					<= FA_MemoryIndex_i;
		TagHit				<= TagHit_i;
		TagMiss				<= TagMiss_i;		

		Replaced			<= Replace;
		NewIndex			<= Policy_ReplaceIndex;
		OldIndex			<= Policy_ReplaceIndex;
		OldTag				<= FA_TagMemory(to_integer(FA_ReplaceIndex_us));

		-- replacement policy
		TagAccess			<= ValidHit AND Request;
		
		Policy : ENTITY PoC.cache_replacement_policy
			GENERIC MAP (
				REPLACEMENT_POLICY				=> REPLACEMENT_POLICY,
				CACHE_LINES								=> FA_CACHE_LINES
			)
			PORT MAP (
				Clock											=> Clock,
				Reset											=> Reset,
				
				Replace										=> Replace,
				ReplaceIndex							=> Policy_ReplaceIndex,
				
				TagAccess									=> TagAccess,
				ReadWrite									=> ReadWrite,
				Invalidate								=> Invalidate,
				Index											=> FA_MemoryIndex_i
			);
	END GENERATE;
	-- ==========================================================================================================================================================
	-- Direct-Mapped Cache
	-- ==========================================================================================================================================================
	genDM : IF (ASSOCIATIVITY = 1) GENERATE
		CONSTANT FA_CACHE_LINES					: POSITIVE					:= CACHE_LINES;
		CONSTANT FA_TAG_BITS						: POSITIVE					:= TAG_BITS;
		CONSTANT FA_MEMORY_INDEX_BITS		: POSITIVE					:= log2ceilnz(FA_CACHE_LINES);
		
		SIGNAL FA_Tag										: STD_LOGIC_VECTOR(FA_TAG_BITS - 1 DOWNTO 0);
		SIGNAL TagHits								: STD_LOGIC_VECTOR(FA_CACHE_LINES - 1 DOWNTO 0);

		SIGNAL FA_MemoryIndex_i					: STD_LOGIC_VECTOR(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);
		SIGNAL FA_MemoryIndex_us				: UNSIGNED(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);
		SIGNAL FA_ReplaceIndex_us				: UNSIGNED(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);

		SIGNAL ValidHit									: STD_LOGIC;
		SIGNAL TagHit_i									: STD_LOGIC;
		SIGNAL TagMiss_i								: STD_LOGIC;
	BEGIN
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
--					ValidMemory(to_integer(FA_ReplaceIndex_us))	<= '1';
--				END IF;
--			END IF;
--		END PROCESS;
--		
--		-- access valid-vector
--		ValidHit					<= ValidMemory(to_integer(FA_MemoryIndex_us));
--		
--		-- hit/miss calculation
--		TagHit_i					<=			slv_or(TagHits) AND ValidHit	AND Request;
--		TagMiss_i				<= NOT (slv_or(TagHits) AND ValidHit)	AND Request;
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
	END GENERATE;
	-- ==========================================================================================================================================================
	-- Set-Assoziative Cache
	-- ==========================================================================================================================================================
	genSA : IF ((ASSOCIATIVITY > 1) AND (SETS > 1)) GENERATE
		CONSTANT FA_CACHE_LINES					: POSITIVE					:= CACHE_LINES;
		CONSTANT SETINDEX_BITS					: NATURAL						:= log2ceil(SETS);
		CONSTANT FA_TAG_BITS						: POSITIVE					:= TAG_BITS;
		CONSTANT FA_MEMORY_INDEX_BITS		: POSITIVE					:= log2ceilnz(FA_CACHE_LINES);
		
		SIGNAL FA_Tag										: STD_LOGIC_VECTOR(FA_TAG_BITS - 1 DOWNTO 0);
		SIGNAL TagHits									: STD_LOGIC_VECTOR(FA_CACHE_LINES - 1 DOWNTO 0);

		SIGNAL FA_MemoryIndex_i					: STD_LOGIC_VECTOR(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);
		SIGNAL FA_MemoryIndex_us				: UNSIGNED(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);
		SIGNAL FA_ReplaceIndex_us				: UNSIGNED(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);

		SIGNAL ValidHit									: STD_LOGIC;
		SIGNAL TagHit_i									: STD_LOGIC;
		SIGNAL TagMiss_i								: STD_LOGIC;
	BEGIN
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
--					ValidMemory(to_integer(FA_ReplaceIndex_us))	<= '1';
--				END IF;
--			END IF;
--		END PROCESS;
--		
--		-- access valid-vector
--		ValidHit					<= ValidMemory(to_integer(FA_MemoryIndex_us));
--		
--		-- hit/miss calculation
--		TagHit_i					<=			slv_or(TagHits) AND ValidHit	AND Request;
--		TagMiss_i				<= NOT (slv_or(TagHits) AND ValidHit)	AND Request;
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
	END GENERATE;
END ARCHITECTURE;
