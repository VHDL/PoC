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


-- cache

ENTITY cache_par IS
	GENERIC (
		REPLACEMENT_POLICY				: STRING													:= "LRU";
		CACHE_LINES								: POSITIVE												:= 32;
		ASSOCIATIVITY							: POSITIVE												:= 32;
		TAG_BITS									: POSITIVE												:= 8;
		DATA_BITS									: POSITIVE												:= 32;
		USE_INITIAL_TAGS 					: BOOLEAN 												:= false;
		INITIAL_TAGS							: T_SLM 													:= (0 downto 0 => (0 downto 0 => '0'));
		INITIAL_DATALINES					: T_SLM 													:= (0 downto 0 => (0 downto 0 => '0'))
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;

		Insert										: IN	STD_LOGIC;
		NewTag										: IN	STD_LOGIC_VECTOR(TAG_BITS - 1 DOWNTO 0);
		NewCacheLine							: IN	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		
		Request										: IN	STD_LOGIC;
		ReadWrite									: IN	STD_LOGIC;
		Invalidate								: IN	STD_LOGIC;
		Tag												: IN	STD_LOGIC_VECTOR(TAG_BITS - 1 DOWNTO 0);
		
		CacheLineIn								: IN	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		CacheLineOut							: OUT	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		CacheHit									: OUT	STD_LOGIC;
		CacheMiss									: OUT	STD_LOGIC;
		
		Replaced									: OUT	STD_LOGIC;
		OldTag										: OUT	STD_LOGIC_VECTOR(TAG_BITS - 1 DOWNTO 0);
		OldCacheLine							: OUT	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0)
	);
END;

-- Cache access commands
-- ==========================
--
--	| Request	| ReadWrite	| Invalidate		| Command
--	+---------+-----------+---------------+------------------------------------
--	|		0			|		0				|		0						|	None
--	|		1			|		0				|		0						|	Read cache line
--	|		1			|		1				|		0						|	Update cache line
--	|		1			|		0				|		1						|	Read cache line and discard it
--	|		1			|		1				|		1						|	write cache line and discard it
--	+---------+-----------+---------------+------------------------------------
--
-- Cache update signals
-- ==========================
--	Insert		insert new cache line (New*)
--	Updated		cache line was replaced, the victim can be read from Old*

ARCHITECTURE rtl OF cache_par IS
	ATTRIBUTE KEEP										: BOOLEAN;

	CONSTANT CACHEMEMORY_INDEX_BITS		: POSITIVE														:= log2ceilnz(CACHE_LINES);
	
	SUBTYPE	T_CACHE_LINE							IS STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
	TYPE		T_CACHE_LINE_VECTOR				IS ARRAY (NATURAL RANGE <>)		OF T_CACHE_LINE;

	FUNCTION to_datamemory(slm : T_SLM) RETURN T_CACHE_LINE_VECTOR IS
		VARIABLE result		: T_CACHE_LINE_VECTOR(CACHE_LINES - 1 DOWNTO 0);
	BEGIN
		result := (others => (others => '0'));
		if not USE_INITIAL_TAGS then return result; end if;
		
		FOR I IN slm'range LOOP
			result(I)	:= get_row(slm, I);
		END LOOP;
		RETURN result;
	END FUNCTION;

	SIGNAL TU_OldIndex								: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_Replace									: STD_LOGIC;

	SIGNAL TU_Index										: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_NewIndex								: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_TagHit									: STD_LOGIC;
	SIGNAL TU_TagMiss									: STD_LOGIC;
	
	SIGNAL Memory_ReadWrite						: STD_LOGIC;
	SIGNAL MemoryIndex_us							: UNSIGNED(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL ReplaceIndex_us						: UNSIGNED(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL ReplacedIndex_us						: UNSIGNED(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL CacheMemory								: T_CACHE_LINE_VECTOR(CACHE_LINES - 1 DOWNTO 0)						:= to_datamemory(INITIAL_DATALINES);
	
BEGIN

	-- Cache TagUnit
	TU : ENTITY PoC.cache_TagUnit_par
		GENERIC MAP (
			REPLACEMENT_POLICY				=> REPLACEMENT_POLICY,
			CACHE_LINES								=> CACHE_LINES,
			ASSOCIATIVITY							=> ASSOCIATIVITY,
			TAG_BITS									=> TAG_BITS,
			USE_INITIAL_TAGS 					=> USE_INITIAL_TAGS,
			INITIAL_TAGS							=> INITIAL_TAGS
		)
		PORT MAP (
			Clock											=> Clock,
			Reset											=> Reset,
			
			Replace										=> Insert,
			NewTag										=> Tag,
			NewIndex									=> TU_NewIndex,
			OldTag										=> OldTag,
			OldIndex									=> TU_OldIndex,
			Replaced									=> TU_Replace,
			
			Request										=> Request,
			ReadWrite									=> ReadWrite,
			Invalidate								=> Invalidate,
			Tag												=> Tag,
			Index											=> TU_Index,
			TagHit										=> TU_TagHit,
			TagMiss										=> TU_TagMiss
		);

	-- Cache Memory - port 1
	Memory_ReadWrite	<= ReadWrite;
	MemoryIndex_us		<= unsigned(TU_Index);
	
	-- Cache Memory - port 2
	ReplaceIndex_us		<= unsigned(TU_NewIndex);
	ReplacedIndex_us	<= unsigned(TU_OldIndex);
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Memory_ReadWrite AND TU_TagHit) = '1') THEN
				CacheMemory(to_integer(MemoryIndex_us))	<= CacheLineIn;
			END IF;
			
			IF (TU_Replace = '1') THEN
				CacheMemory(to_integer(ReplaceIndex_us))	<= NewCacheLine;
			END IF;
		END IF;
	END PROCESS;

	CacheHit					<= TU_TagHit;
	CacheMiss					<= TU_TagMiss;
	CacheLineOut			<= CacheMemory(to_integer(MemoryIndex_us));

	Replaced					<= TU_Replace;
	OldCacheLine			<= CacheMemory(to_integer(ReplacedIndex_us));

END ARCHITECTURE;
