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
--
-- Policies														|	supported
-- -----------------------------------#--------------------
--	RR			round robin								|	not yet
--	RAND		random										|	not yet
--	CLOCK		clock algorithm						|	not yet
--	LRU			least recently used				| YES
--	LFU			least frequently used			| not yet
-- -----------------------------------#--------------------
--
-- Priority		Command
-- ----------------------
--	0					invalidate
--	1					replace
--	2					access
--
-- License:
-- ============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;


ENTITY cache_replacement_policy IS
	GENERIC (
		REPLACEMENT_POLICY				: STRING													:= "LRU";
		CACHE_LINES								: POSITIVE												:= 32
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		-- replacement interface
		Replace										: IN	STD_LOGIC;
		ReplaceIndex							: OUT	STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);
		
		-- cacheline usage update interface
		TagAccess									: IN	STD_LOGIC;
		ReadWrite									: IN	STD_LOGIC;
		Invalidate								: IN	STD_LOGIC;
		Index											: IN	STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF cache_replacement_policy IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	CONSTANT KEY_BITS									: POSITIVE									:= log2ceilnz(CACHE_LINES);

BEGIN
	ASSERT (str_equal(REPLACEMENT_POLICY, "RR") OR
					str_equal(REPLACEMENT_POLICY, "LRU"))
		REPORT "Unsupported replacement strategy"
		SEVERITY ERROR;


	-- ===========================================================================
	-- policy: RR - round robin
	-- ===========================================================================
	genRR : IF (str_equal(REPLACEMENT_POLICY, "RR") = TRUE) GENERATE
		CONSTANT VALID_BIT								: NATURAL			:= 0;

		SUBTYPE	T_OPTION_LINE							IS STD_LOGIC_VECTOR(0 DOWNTO 0);
		TYPE		T_OPTION_LINE_VECTOR			IS ARRAY (NATURAL RANGE <>)		OF T_OPTION_LINE;
		
		SIGNAL OptionMemory								: T_OPTION_LINE_VECTOR(CACHE_LINES - 1 DOWNTO 0)	:= (OTHERS => (
			VALID_BIT			=> '0')
			);

		SIGNAL ValidHit										: STD_LOGIC;
		SIGNAL Pointer_us									: UNSIGNED(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0)	:= (OTHERS => '0');
		
	BEGIN
--		ValidHit		<= OptionMemory(to_integer(unsigned(Index)))(VALID_BIT);
--		IsValid			<= ValidHit;
--
--		PROCESS(Clock)
--		BEGIN
--			IF rising_edge(Clock) THEN
--				IF (Reset = '1') THEN
--					FOR I IN 0 TO CACHE_LINES - 1 LOOP
--						OptionMemory(I)(VALID_BIT)	<= '0';
--					END LOOP;
--				ELSE
--					IF (Insert = '1') THEN
--						OptionMemory(to_integer(Pointer_us))(VALID_BIT)	<= '1';
--					END IF;
--					
--					IF (Invalidate = '1') THEN
--						OptionMemory(to_integer(unsigned(Index)))(VALID_BIT)			<= '0';
--					END IF;
--				END IF;
--			END IF;
--		END PROCESS;
--
--		Replace				<= Insert;
--		ReplaceIndex	<= std_logic_vector(Pointer_us);
--		
--		PROCESS(Clock)
--		BEGIN
--			IF rising_edge(Clock) THEN
--				IF (Reset = '1') THEN
--					Pointer_us		<= (OTHERS => '0');
--				ELSE
--					IF (Insert = '1') THEN
--						Pointer_us	<= Pointer_us + 1;
--					END IF;
--				END IF;
--			END IF;
--		END PROCESS;
	END GENERATE;

	-- ===========================================================================
	-- policy: LRU - least recently used
	-- ===========================================================================
	genLRU : IF (str_equal(REPLACEMENT_POLICY, "LRU") = TRUE) GENERATE
		SIGNAL LRU_Insert						: STD_LOGIC;
		SIGNAL LRU_Invalidate				: STD_LOGIC;
		SIGNAL KeyIn								: STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);
		SIGNAL LRU_Key							: STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);
		
	BEGIN
		-- list_lru_systolic supports only one update per cycle
		PROCESS(TagAccess, ReadWrite, Invalidate, Replace, Index, LRU_Key)
		BEGIN
			LRU_Insert			<= '0';
			LRU_Invalidate	<= '0';
			KeyIn						<= Index;
			
			IF (Invalidate = '1') THEN
				LRU_Invalidate		<= '1';
				KeyIn							<= Index;
			ELSIF (Replace = '1') THEN
				LRU_Insert				<= '1';
				KeyIn							<= LRU_Key;
			ELSIF (TagAccess = '1') THEN
				LRU_Insert				<= '1';
				KeyIn							<= Index;
			END IF;
		END PROCESS;

		ReplaceIndex		<= LRU_Key;
			
		LRU : ENTITY PoC.sort_lru_cache
			GENERIC MAP (
				ELEMENTS								=> CACHE_LINES
			)
			PORT MAP (
				Clock										=> Clock,
				Reset										=> Reset,
				
				Insert									=> LRU_Insert,
				Free										=> LRU_Invalidate,
				KeyIn										=> KeyIn,
				
				KeyOut									=> LRU_Key
			);
	END GENERATE;
END ARCHITECTURE;
