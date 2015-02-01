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
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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


ENTITY Stream_Mirror IS
	GENERIC (
		PORTS											: POSITIVE									:= 2;
		DATA_BITS									: POSITIVE									:= 8;
		META_BITS									: T_POSVEC									:= (0 => 8);
		META_LENGTH								: T_POSVEC									:= (0 => 16)
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		In_Valid									: IN	STD_LOGIC;
		In_Data										: IN	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		In_SOF										: IN	STD_LOGIC;
		In_EOF										: IN	STD_LOGIC;
		In_Ack										: OUT	STD_LOGIC;
		In_Meta_rst								: OUT	STD_LOGIC;
		In_Meta_nxt								: OUT	STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
		In_Meta_Data							: IN	STD_LOGIC_VECTOR(isum(META_BITS) - 1 DOWNTO 0);
		
		Out_Valid									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Out_Data									: OUT	T_SLM(PORTS - 1 DOWNTO 0, DATA_BITS - 1 DOWNTO 0);
		Out_SOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Out_EOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Out_Ack										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Out_Meta_rst							: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Out_Meta_nxt							: IN	T_SLM(PORTS - 1 DOWNTO 0, META_BITS'length - 1 DOWNTO 0);
		Out_Meta_Data							: OUT	T_SLM(PORTS - 1 DOWNTO 0, isum(META_BITS) - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF Stream_Mirror IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	SIGNAL FIFOGlue_put								: STD_LOGIC;
	SIGNAL FIFOGlue_DataIn						: STD_LOGIC_VECTOR(DATA_BITS + 1 DOWNTO 0);
	SIGNAL FIFOGlue_Full							: STD_LOGIC;
	SIGNAL FIFOGlue_Valid							: STD_LOGIC;
	SIGNAL FIFOGlue_DataOut						: STD_LOGIC_VECTOR(DATA_BITS + 1 DOWNTO 0);
	SIGNAL FIFOGlue_got								: STD_LOGIC;
	
	SIGNAL Ack_i											: STD_LOGIC;
	SIGNAL Mask_r											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)												:= (OTHERS => '1');
	
	SIGNAL MetaOut_rst								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL Out_Data_i									: T_SLM(PORTS - 1 DOWNTO 0, DATA_BITS - 1 DOWNTO 0)						:= (OTHERS => (OTHERS => 'Z'));
	SIGNAL Out_Meta_Data_i						: T_SLM(PORTS - 1 DOWNTO 0, isum(META_BITS) - 1 DOWNTO 0)			:= (OTHERS => (OTHERS => 'Z'));
BEGIN
	
	-- Data path
	-- ==========================================================================================================================================================
	FIFOGlue_put															<= In_Valid;
	FIFOGlue_DataIn(DATA_BITS - 1 DOWNTO 0)		<= In_Data;
	FIFOGlue_DataIn(DATA_BITS + 0)						<= In_SOF;
	FIFOGlue_DataIn(DATA_BITS + 1)						<= In_EOF;
	
	In_Ack																		<= NOT FIFOGlue_Full;
	
	FIFOGlue : ENTITY PoC.fifo_glue
		GENERIC MAP (
			D_BITS		=> DATA_BITS + 2					-- Data Width
		)
		PORT MAP (
			-- Control
			clk				=> Clock,									-- Clock
			rst				=> Reset,									-- Synchronous Reset
	
			-- Input
			put				=> FIFOGlue_put,					-- Put Value
			di				=> FIFOGlue_DataIn,				-- Data Input
			ful				=> FIFOGlue_Full,					-- Full
	
			-- Output
			vld				=> FIFOGlue_Valid,				-- Data Available
			do				=> FIFOGlue_DataOut,			-- Data Output
			got				=> FIFOGlue_got						-- Data Consumed
  );

	genPorts : FOR I IN 0 TO PORTS - 1 GENERATE
		assign_row(Out_Data_i, FIFOGlue_DataOut(DATA_BITS - 1 DOWNTO 0), I);
	END GENERATE;
	
	Ack_i					<= slv_and(Out_Ack) OR slv_and(NOT Mask_r OR Out_Ack);
	FIFOGlue_got	<= Ack_i	;

	Out_Valid			<= (PORTS - 1 DOWNTO 0 => FIFOGlue_Valid) AND Mask_r;
	Out_Data			<= Out_Data_i;
	Out_SOF				<= (PORTS - 1 DOWNTO 0 => FIFOGlue_DataOut(DATA_BITS + 0));
	Out_EOF				<= (PORTS - 1 DOWNTO 0 => FIFOGlue_DataOut(DATA_BITS + 1));
		
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Ack_i	) = '1') THEN
				Mask_r		<= (OTHERS => '1');
			ELSE
				Mask_r		<= Mask_r AND NOT Out_Ack;
			END IF;
		END IF;
	END PROCESS;
	
	-- Metadata path
	-- ==========================================================================================================================================================	
	In_Meta_rst		<= slv_and(MetaOut_rst);
	
	genMeta : FOR I IN 0 TO META_BITS'length - 1 GENERATE
		SUBTYPE T_METAMEMORY						IS STD_LOGIC_VECTOR(META_BITS(I) - 1 DOWNTO 0);
		TYPE T_METAMEMORY_VECTOR				IS ARRAY(NATURAL RANGE <>) OF T_METAMEMORY;
		
	BEGIN
		genReg : IF (META_LENGTH(I) = 1) GENERATE
			SIGNAL MetaMemory_en					: STD_LOGIC;
			SIGNAL MetaMemory							: T_METAMEMORY;
		BEGIN
			MetaMemory_en		<= In_Valid AND In_SOF;
		
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF (MetaMemory_en = '1') THEN
						MetaMemory		<= In_Meta_Data(high(META_BITS, I) DOWNTO low(META_BITS, I));
					END IF;
				END IF;
			END PROCESS;
			
			genReader : FOR J IN 0 TO PORTS - 1 GENERATE
				assign_row(Out_Meta_Data_i, MetaMemory, J, high(META_BITS, I), low(META_BITS, I));
			END GENERATE;
		END GENERATE;
		genMem : IF (META_LENGTH(I) > 1) GENERATE
			SIGNAL MetaMemory_en					: STD_LOGIC;
			SIGNAL MetaMemory							: T_METAMEMORY_VECTOR(META_LENGTH(I) - 1 DOWNTO 0);
			
			SIGNAL Writer_CounterControl	: STD_LOGIC																						:= '0';
			
			SIGNAL Writer_en							: STD_LOGIC;
			SIGNAL Writer_rst							: STD_LOGIC;
			SIGNAL Writer_us							: UNSIGNED(log2ceilnz(META_LENGTH(I)) - 1 DOWNTO 0)		:= (OTHERS => '0');
		BEGIN
			-- MetaMemory Write Pointer Control
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF (Reset = '1') THEN
						Writer_CounterControl			<= '0';
					ELSE
						IF ((In_Valid AND In_SOF) = '1') THEN
							Writer_CounterControl		<= '1';
						ELSIF (Writer_us = (META_LENGTH(I) - 1)) THEN
							Writer_CounterControl		<= '0';
						END IF;
					END IF;
				END IF;
			END PROCESS;
		
			Writer_en				<= (In_Valid AND In_SOF) OR Writer_CounterControl;
			
			In_Meta_nxt(I)	<= Writer_en;
			MetaMemory_en		<= Writer_en;
			MetaOut_rst(I)	<= NOT Writer_en;
			
			-- MetaMemory - Write Pointer
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF (Writer_en = '0') THEN
						Writer_us			<= (OTHERS => '0');
					ELSE
						Writer_us			<= Writer_us + 1;
					END IF;
				END IF;
			END PROCESS;

			-- MetaMemory
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF (MetaMemory_en = '1') THEN
						MetaMemory(to_integer(Writer_us))		<= In_Meta_Data(high(META_BITS, I) DOWNTO low(META_BITS, I));
					END IF;
				END IF;
			END PROCESS;
		
			genReader : FOR J IN 0 TO PORTS - 1 GENERATE
				SIGNAL Row							: T_METAMEMORY;
				
				SIGNAL Reader_en				: STD_LOGIC;
				SIGNAL Reader_rst				: STD_LOGIC;
				SIGNAL Reader_us				: UNSIGNED(log2ceilnz(META_LENGTH(I)) - 1 DOWNTO 0)		:= (OTHERS => '0');
			BEGIN
				Reader_rst		<= Out_Meta_rst(J) OR (In_Valid AND In_SOF);
				Reader_en			<= Out_Meta_nxt(J, I);
			
				PROCESS(Clock)
				BEGIN
					IF rising_edge(Clock) THEN
						IF (Reader_rst = '1') THEN
							Reader_us			<= (OTHERS => '0');
						ELSIF (Reader_en = '1') THEN
							Reader_us			<= Reader_us + 1;
						END IF;
					END IF;
				END PROCESS;
			
				Row <= MetaMemory(to_integer(Reader_us));
				assign_row(Out_Meta_Data_i, Row, J, high(META_BITS, I), low(META_BITS, I));
			END GENERATE;		-- for each port
		END GENERATE;		-- if length > 1
	END GENERATE;		-- for each metadata stream
	
	Out_Meta_Data		<= Out_Meta_Data_i;
END ARCHITECTURE;
