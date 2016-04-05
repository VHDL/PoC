-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
-- 
-- Module:				 	Cache with parallel tag-unit and data memory.
--
-- Description:
-- ------------------------------------
-- All inputs are synchronous to the rising-edge of the clock `clock`.
--
-- Command truth table:
-- 
--	Request	| ReadWrite	| Invalidate	| Replace | Command
--	--------+-----------+-------------+---------+--------------------------------
--		0			|		0				|		0					|   0 		|	None
--		1			|		0				|		0					|	  0 		| Read cache line
--		1			|		1				|		0					|	  0 		| Update cache line
--		1			|		0				|		1					|	  0 		| Read cache line and discard it
--		1			|		1				|		1					|	  0 		| Write cache line and discard it
--    0     |   - 			|   0 				|   1 		| Replace cache line.
--	--------+-----------+-------------+------------------------------------------
--
-- All commands use `Tag` to lookup (request) or replace a cache line.
-- Each command is completed within one clock cycle, but outputs are delayed as
-- described below.
--
-- Upon requests, the outputs `CacheMiss` and `CacheHit` indicate (high-active)
-- whether the `Tag` is stored within the cache, or not. Both outputs have a
-- latency of one clock cycle.
--
-- Upon writing a cache line, the new content is given by `CacheLineIn`.
-- Upon reading a cache line, the current content is outputed on `CacheLineOut`
-- with a latency of one clock cycle.
--
-- Upon replacing a cache line, the new content is given by `CacheLineIn`. The
-- old content is outputed on `CacheLineOut` and the old tag on `OldTag`,
-- both with a latency of one clock cycle.
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

		Replace										: IN	STD_LOGIC;
		
		Request										: IN	STD_LOGIC;
		ReadWrite									: IN	STD_LOGIC;
		Invalidate								: IN	STD_LOGIC;
		Tag												: IN	STD_LOGIC_VECTOR(TAG_BITS - 1 DOWNTO 0);
		
		CacheLineIn								: IN	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		CacheLineOut							: OUT	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		CacheHit									: OUT	STD_LOGIC := '0';
		CacheMiss									: OUT	STD_LOGIC := '0';
		
		OldTag										: OUT	STD_LOGIC_VECTOR(TAG_BITS - 1 DOWNTO 0);
		OldCacheLine							: OUT	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0)
	);
END;


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

	-- look-up (request)
	SIGNAL TU_Index										: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_TagHit									: STD_LOGIC;
	SIGNAL TU_TagMiss									: STD_LOGIC;

	-- replace
	SIGNAL TU_ReplaceIndex						: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	signal TU_OldTag									:	STD_LOGIC_VECTOR(TAG_BITS - 1 DOWNTO 0);

	SIGNAL MemoryIndex_us							: UNSIGNED(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL CacheMemory								: T_CACHE_LINE_VECTOR(CACHE_LINES - 1 DOWNTO 0)						:= to_datamemory(INITIAL_DATALINES);
	
BEGIN

	-- Cache TagUnit
	TU : ENTITY PoC.cache_tagunit_par
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
			
			Replace										=> Replace,
			ReplaceIndex 							=> TU_ReplaceIndex,
			NewTag										=> Tag,
			OldTag										=> TU_OldTag,
			
			Request										=> Request,
			ReadWrite									=> ReadWrite,
			Invalidate								=> Invalidate,
			Tag												=> Tag,
			Index											=> TU_Index,
			TagHit										=> TU_TagHit,
			TagMiss										=> TU_TagMiss
		);

	-- Address selector
	MemoryIndex_us		<= unsigned(TU_Index) when Request = '1' else
											 unsigned(TU_ReplaceIndex);
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Request and TU_TagHit and ReadWrite) or Replace) = '1' THEN
				CacheMemory(to_integer(MemoryIndex_us))	<= CacheLineIn;
			END IF;

			-- Single-port memory with read before write is required here.
			-- Cannot be mapped to `PoC.ocram_sdp`.
			CacheLineOut			<= CacheMemory(to_integer(MemoryIndex_us));
			
			-- Control outputs have same latency as cache line data.
			if Reset = '1' then
				CacheMiss <= '0';
				CacheHit  <= '0';
			else
				CacheMiss <= TU_TagMiss;
				CacheHit  <= TU_TagHit;
			end if;
			
			OldTag <= TU_OldTag;
		END IF;
	END PROCESS;
END ARCHITECTURE;
