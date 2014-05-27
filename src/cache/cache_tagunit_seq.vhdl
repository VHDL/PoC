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

-- cache_tagunit_seq
--		par = parallel
--		seq = sequential

ENTITY cache_tagunit_seq IS
	GENERIC (
		REPLACEMENT_POLICY				: STRING													:= "LRU";
		CACHE_LINES								: POSITIVE												:= 32;
		ASSOCIATIVITY							: POSITIVE												:= 32;
		TAG_BITS									: POSITIVE												:= 128;
		CHUNK_BITS								: POSITIVE												:= 8;
		TAG_BYTE_ORDER						: T_BYTE_ORDER										:= LITTLE_ENDIAN;
		INITIAL_TAGS							: T_SLM														:= (31 DOWNTO 0 => (127 DOWNTO 0 => '0'))
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		Replace										: IN	STD_LOGIC;
		Replaced									: OUT	STD_LOGIC;
		Replace_NewTag_rst				: OUT	STD_LOGIC;
		Replace_NewTag_rev				: OUT	STD_LOGIC;
		Replace_NewTag_nxt				: OUT	STD_LOGIC;
		Replace_NewTag_Data				: IN	STD_LOGIC_VECTOR(CHUNK_BITS - 1 DOWNTO 0);
		Replace_NewIndex					: OUT	STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);		
		
		Request										: IN	STD_LOGIC;
		Request_ReadWrite					: IN	STD_LOGIC;
		Request_Invalidate				: IN	STD_LOGIC;
		Request_Tag_rst						: OUT	STD_LOGIC;
		Request_Tag_rev						: OUT	STD_LOGIC;
		Request_Tag_nxt						: OUT	STD_LOGIC;
		Request_Tag_Data					: IN	STD_LOGIC_VECTOR(CHUNK_BITS - 1 DOWNTO 0);
		Request_Index							: OUT	STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);
		Request_TagHit						: OUT	STD_LOGIC;
		Request_TagMiss						: OUT	STD_LOGIC
	);
END;


ARCHITECTURE rtl OF cache_tagunit_seq IS
	ATTRIBUTE KEEP							: BOOLEAN;

	CONSTANT SETS								: POSITIVE				:= CACHE_LINES / ASSOCIATIVITY;

BEGIN
	-- ==========================================================================================================================================================
	-- Full-Assoziative Cache
	-- ==========================================================================================================================================================
	genFA : IF (CACHE_LINES = ASSOCIATIVITY) GENERATE
		CONSTANT FA_CACHE_LINES						: POSITIVE					:= ASSOCIATIVITY;
		CONSTANT FA_TAG_BITS							: POSITIVE					:= TAG_BITS;
		CONSTANT FA_CHUNKS								: POSITIVE					:= div_ceil(FA_TAG_BITS, CHUNK_BITS);
		CONSTANT FA_CHUNK_INDEX_BITS			: POSITIVE					:= log2ceilnz(FA_CHUNKS);
		CONSTANT FA_MEMORY_INDEX_BITS			: POSITIVE					:= log2ceilnz(FA_CACHE_LINES);

		CONSTANT FA_INITIAL_TAGS_RESIZED	: T_SLM							:= resize(INITIAL_TAGS, FA_CACHE_LINES);

		SUBTYPE	T_CHUNK									IS STD_LOGIC_VECTOR(CHUNK_BITS - 1 DOWNTO 0);
		TYPE		T_TAG_LINE							IS ARRAY (NATURAL RANGE <>) OF T_CHUNK;

		TYPE T_REPLACE_STATE	IS (ST_IDLE, ST_REPLACE);
		TYPE T_REQUEST_STATE	IS (ST_IDLE, ST_COMPARE, ST_READ);

		FUNCTION to_validvector(slm : T_SLM) RETURN STD_LOGIC_VECTOR IS
			VARIABLE result		: STD_LOGIC_VECTOR(CACHE_LINES - 1 DOWNTO 0)	:= (OTHERS => '0');
		BEGIN
			FOR I IN slm'range LOOP
				result(I)	:= '1';
			END LOOP;
			RETURN result;
		END FUNCTION;

		FUNCTION to_tagmemory(slm : T_SLM; row : NATURAL) RETURN T_TAG_LINE IS
			CONSTANT tag_line			: STD_LOGIC_VECTOR(slm'high(2) DOWNTO slm'low(2))		:= get_row(slm, row);
			VARIABLE result				: T_TAG_LINE(FA_CHUNKS - 1 DOWNTO 0);
		BEGIN
--			REPORT "tagline @row " & INTEGER'image(row) & " = " & to_string(tag_line, 'h') SEVERITY NOTE;
			FOR I IN result'range LOOP
				result(I)	:= tag_line((I * CHUNK_BITS) + CHUNK_BITS - 1 DOWNTO (I * CHUNK_BITS));
			END LOOP;
			RETURN result;
		END FUNCTION;
		
		SIGNAL Replace_State						: T_Replace_STATE																				:= ST_IDLE;
		SIGNAL Replace_NextState				: T_Replace_STATE;
		SIGNAL Request_State						: T_REQUEST_STATE																				:= ST_IDLE;
		SIGNAL Request_NextState				: T_REQUEST_STATE;
		
		SIGNAL RequestComplete					: STD_LOGIC;
		
		SIGNAL NewTagSeqCounter_rst			: STD_LOGIC;
--		SIGNAL NewTagSeqCounter_en			: STD_LOGIC;
		SIGNAL NewTagSeqCounter_us			: UNSIGNED(FA_CHUNK_INDEX_BITS - 1 DOWNTO 0)						:= (OTHERS => '0');
		SIGNAL TagSeqCounter_rst				: STD_LOGIC;
--		SIGNAL TagSeqCounter_en					: STD_LOGIC;
		SIGNAL TagSeqCounter_us					: UNSIGNED(FA_CHUNK_INDEX_BITS - 1 DOWNTO 0)						:= (OTHERS => '0');
		
		SIGNAL TagMemory_we							: STD_LOGIC;
		
		SIGNAL PartialTagHits						: STD_LOGIC_VECTOR(FA_CACHE_LINES - 1 DOWNTO 0);
		SIGNAL TagHits_en								: STD_LOGIC;
		SIGNAL TagHits_nxt							: STD_LOGIC_VECTOR(FA_CACHE_LINES - 1 DOWNTO 0);
		SIGNAL TagHits_nor							: STD_LOGIC;
		SIGNAL TagHits_r								: STD_LOGIC_VECTOR(FA_CACHE_LINES - 1 DOWNTO 0)					:= (OTHERS => '1');

		SIGNAL MemoryIndex_us						: UNSIGNED(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);
		SIGNAL MemoryIndex_i						: STD_LOGIC_VECTOR(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);

		SIGNAL ValidMemory							: STD_LOGIC_VECTOR(FA_CACHE_LINES - 1 DOWNTO 0)					:= to_validvector(INITIAL_TAGS);
		SIGNAL ValidHit									: STD_LOGIC;

		SIGNAL Policy_ReplaceIndex			: STD_LOGIC_VECTOR(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);
		SIGNAL Policy_ReplaceIndex_d		: STD_LOGIC_VECTOR(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0)		:= (OTHERS => '0');
		SIGNAL ReplaceIndex_us					: UNSIGNED(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0);

		SIGNAL TagHit_i									: STD_LOGIC;
		SIGNAL TagMiss_i								: STD_LOGIC;
		
		SIGNAL TagAccess								: STD_LOGIC																							:= '0';
		SIGNAL TagIndex									: STD_LOGIC_VECTOR(FA_MEMORY_INDEX_BITS - 1 DOWNTO 0)		:= (OTHERS => '0');
		
	BEGIN
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Reset = '1') THEN
					Replace_State		<= ST_IDLE;
					Request_State		<= ST_IDLE;
				ELSE
					Replace_State		<= Replace_NextState;
					Request_State		<= Request_NextState;
				END IF;
			END IF;
		END PROCESS;
		
		PROCESS(Replace_State, Replace, NewTagSeqCounter_us)
		BEGIN
			Replace_NextState						<= Replace_State;
			
			Replace_NewTag_rst					<= '0';
			Replace_NewTag_rev					<= '0';
			Replace_NewTag_nxt					<= '0';
			Replaced										<= '0';
			
			NewTagSeqCounter_rst				<= '0';
--			NewTagSeqCounter_en					<= '0';
			TagMemory_we								<= '0';
			
			CASE Replace_State IS
				WHEN ST_IDLE =>
					Replace_NewTag_rst			<= '1';
					NewTagSeqCounter_rst		<= '1';
					
					IF (Replace = '1') THEN
						Replace_NewTag_rst		<= '0';
						Replace_NewTag_nxt		<= '1';
							
						NewTagSeqCounter_rst	<= '0';
--						NewTagSeqCounter_en		<= '1';
						TagMemory_we					<= '1';
						
						Replace_NextState			<= ST_REPLACE;
					END IF;
				
				WHEN ST_REPLACE =>
					Replace_NewTag_nxt			<= '1';
--					NewTagSeqCounter_en			<= '1';
					TagMemory_we						<= '1';

					IF (NewTagSeqCounter_us = ite((TAG_BYTE_ORDER = LITTLE_ENDIAN), (FA_CHUNKS - 1), 0)) THEN
						Replaced							<= '1';

						Replace_NextState			<= ST_IDLE;
					END IF;
				
			END CASE;
		END PROCESS;
		
		PROCESS(Request_State, Request, TagSeqCounter_us, TagHits_nor)
		BEGIN
			Request_NextState										<= Request_State;
			
			TagSeqCounter_rst						<= '0';
--			TagSeqCounter_en						<= '0';
			TagHits_en									<= '0';
			
			Request_Tag_rst							<= '0';
			Request_Tag_rev							<= ite((TAG_BYTE_ORDER = LITTLE_ENDIAN), '0', '1');
			Request_Tag_nxt							<= '0';
			RequestComplete							<= '0';
			
			CASE Request_State IS
				WHEN ST_IDLE =>
					Request_Tag_rst					<= '1';
					TagSeqCounter_rst				<= '1';
					
					IF (Request = '1') THEN
						IF (TagHits_nor = '1') THEN
							RequestComplete			<= '1';
						ELSE
							Request_Tag_rst			<= '0';
							Request_Tag_nxt			<= '1';
							
							TagSeqCounter_rst		<= '0';
--							TagSeqCounter_en		<= '1';
							TagHits_en					<= '1';
						
							Request_NextState						<= ST_COMPARE;
						END IF;
					END IF;
				
				WHEN ST_COMPARE =>
					Request_Tag_nxt					<= '1';
--					TagSeqCounter_en				<= '1';
					TagHits_en							<= '1';

					IF (TagHits_nor = '1') THEN
						Request_Tag_rst				<= '1';
						TagSeqCounter_rst			<= '1';
						RequestComplete				<= '1';
						
						Request_NextState			<= ST_IDLE;
					ELSE
						IF (TagSeqCounter_us = ite((TAG_BYTE_ORDER = LITTLE_ENDIAN), (FA_CHUNKS - 1), 0)) THEN
							RequestComplete			<= '1';

							Request_NextState		<= ST_READ;
						END IF;
					END IF;
					
				WHEN ST_READ =>
					Request_Tag_rst					<= '1';
					TagSeqCounter_rst				<= '1';
					
					IF (Request = '1') THEN
						IF (TagHits_nor = '1') THEN
							RequestComplete			<= '1';
							Request_NextState		<= ST_IDLE;
						ELSE
							Request_Tag_rst			<= '0';
							Request_Tag_nxt			<= '1';
							
							TagSeqCounter_rst		<= '0';
--							TagSeqCounter_en		<= '1';
							TagHits_en					<= '1';
						
							Request_NextState		<= ST_COMPARE;
						END IF;
					END IF;
				
			END CASE;
		END PROCESS;
		
		-- Counters
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				-- NewTagSeqCounter
				IF ((Reset OR NewTagSeqCounter_rst) = '1') THEN
					IF (TAG_BYTE_ORDER = LITTLE_ENDIAN) THEN
						NewTagSeqCounter_us		<= to_unsigned(0,								NewTagSeqCounter_us'length);
					ELSE
						NewTagSeqCounter_us		<= to_unsigned((FA_CHUNKS - 1), NewTagSeqCounter_us'length);
					END IF;
				ELSE
					IF (TAG_BYTE_ORDER = LITTLE_ENDIAN) THEN
						NewTagSeqCounter_us		<= NewTagSeqCounter_us + 1;
					ELSE
						NewTagSeqCounter_us		<= NewTagSeqCounter_us - 1;
					END IF;
				END IF;
				
				-- TagSeqCounter
				IF ((Reset OR TagSeqCounter_rst) = '1') THEN
					IF (TAG_BYTE_ORDER = LITTLE_ENDIAN) THEN
						TagSeqCounter_us			<= to_unsigned(0,								TagSeqCounter_us'length);
					ELSE
						TagSeqCounter_us			<= to_unsigned((FA_CHUNKS - 1), TagSeqCounter_us'length);
					END IF;
				ELSE
					IF (TAG_BYTE_ORDER = LITTLE_ENDIAN) THEN
						TagSeqCounter_us			<= TagSeqCounter_us + 1;
					ELSE
						TagSeqCounter_us			<= TagSeqCounter_us - 1;
					END IF;
				END IF;
			END IF;
		END PROCESS;
		
		-- generate comparators
		genVectors : FOR I IN 0 TO FA_CACHE_LINES - 1 GENERATE
			CONSTANT C_TAGMEMORY					: T_TAG_LINE(FA_CHUNKS - 1 DOWNTO 0)		:= to_tagmemory(FA_INITIAL_TAGS_RESIZED, I);
			SIGNAL TagMemory							: T_TAG_LINE(FA_CHUNKS - 1 DOWNTO 0)		:= C_TAGMEMORY;
		BEGIN
--			genASS : FOR J IN 0 TO FA_CHUNKS - 1 GENERATE
--				ASSERT FALSE REPORT "line=" & INTEGER'image(I) & "  chunk=" & INTEGER'image(J) & "  tag=" & to_string(C_TAGMEMORY(J), 'h') SEVERITY NOTE;
--			END GENERATE;
			
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF ((ReplaceIndex_us = I ) AND (TagMemory_we = '1')) THEN
						TagMemory(to_integer(NewTagSeqCounter_us))	<= Replace_NewTag_Data;
					END IF;
				END IF;
			END PROCESS;
		
			PartialTagHits(I)	<= to_sl(TagMemory(to_integer(TagSeqCounter_us)) = Request_Tag_Data);
		END GENERATE;

		-- TagHit accumulator
		TagHits_nxt				<= TagHits_r AND PartialTagHits;
		TagHits_nor				<= slv_nor(TagHits_nxt);
		
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF ((TagHit_i OR TagMiss_i) = '1') THEN
					TagHits_r		<= (OTHERS => '1');
				ELSIF (TagHits_en = '1') THEN
					TagHits_r		<= TagHits_nxt;
				END IF;
			END IF;
		END PROCESS;
		
		-- convert hit-vector to binary index (cache line address)
		MemoryIndex_us			<= onehot2bin(TagHits_nxt);
		MemoryIndex_i				<= std_logic_vector(MemoryIndex_us);

		-- latching the ReplaceIndex
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Replace = '1') THEN
					Policy_ReplaceIndex_d		<= Policy_ReplaceIndex;
				END IF;
			END IF;
		END PROCESS;
		
		ReplaceIndex_us			<= unsigned(ite((Replace = '1'), Policy_ReplaceIndex, Policy_ReplaceIndex_d));

		-- Memories
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Replace = '1') THEN
					ValidMemory(to_integer(unsigned(Policy_ReplaceIndex)))	<= '1';
				END IF;
			END IF;
		END PROCESS;

		ValidHit					<= ValidMemory(to_integer(MemoryIndex_us));
		
		-- hit/miss calculation
		TagHit_i					<=			slv_or(TagHits_nxt) AND ValidHit	AND RequestComplete;
		TagMiss_i					<= NOT (slv_or(TagHits_nxt) AND ValidHit)	AND RequestComplete;

		-- outputs
		Request_Index			<= MemoryIndex_i;
		Request_TagHit		<= TagHit_i;
		Request_TagMiss		<= TagMiss_i;		

		Replace_NewIndex	<= Policy_ReplaceIndex;
		
		TagAccess					<= TagHit_i				WHEN rising_edge(Clock);
		TagIndex					<= MemoryIndex_i	WHEN rising_edge(Clock);

		-- replacement policy
--		Policy : ENTITY L_Global.cache_replacement_policy
		Policy : ENTITY PoC.cache_replacement_policy
			GENERIC MAP (
				REPLACEMENT_POLICY				=> REPLACEMENT_POLICY,
				CACHE_LINES								=> FA_CACHE_LINES,
				INITIAL_VALIDS						=> to_validvector(INITIAL_TAGS)
			)
			PORT MAP (
				Clock											=> Clock,
				Reset											=> Reset,
				
				Replace										=> Replace,
				ReplaceIndex							=> Policy_ReplaceIndex,
				
				TagAccess									=> TagAccess,
				ReadWrite									=> Request_ReadWrite,
				Invalidate								=> Request_Invalidate,
				Index											=> TagIndex
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
--					Request_ReadWrite									=> Request_ReadWrite(I),
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
--					Request_ReadWrite									=> Request_ReadWrite(I),
--					Invalidate								=> Invalidate(I),
--					Index											=> Policy_Index(I)
--				);
--		END GENERATE;
	END GENERATE;
END ARCHITECTURE;
