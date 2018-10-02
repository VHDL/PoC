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
--USE			PoC.vectors.ALL;


ENTITY misc_Sequencer IS
  GENERIC (
	  INPUT_BITS					: POSITIVE					:= 32;
		OUTPUT_BITS					: POSITIVE					:= 8;
		REGISTERED					: BOOLEAN						:= FALSE
	);
  PORT (
	  Clock								: IN	STD_LOGIC;
		Reset								: IN	STD_LOGIC;
		
		Input								: IN	STD_LOGIC_VECTOR(INPUT_BITS - 1 DOWNTO 0);
		rst									:	IN	STD_LOGIC;
		rev									:	IN	STD_LOGIC;
		nxt									:	IN	STD_LOGIC;
		Output							: OUT STD_LOGIC_VECTOR(OUTPUT_BITS - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF misc_Sequencer IS
	CONSTANT CHUNKS				: POSITIVE := div_ceil(INPUT_BITS, OUTPUT_BITS);
	CONSTANT COUNTER_BITS	: POSITIVE := log2ceilnz(CHUNKS);

	SUBTYPE T_CHUNK				IS STD_LOGIC_VECTOR(OUTPUT_BITS - 1 DOWNTO 0);
	TYPE		T_MUX					IS ARRAY (NATURAL RANGE <>) OF T_CHUNK;
	
	SIGNAL Mux_Data				: T_MUX(CHUNKS - 1 DOWNTO 0);
	SIGNAL Mux_Data_d			: T_MUX(CHUNKS - 1 DOWNTO 0);
	SIGNAL Mux_sel_us			: UNSIGNED(COUNTER_BITS - 1 DOWNTO 0)		:= (OTHERS => '0');
	
	SIGNAL rev_l					: STD_LOGIC															:= '0';
	
BEGIN
	genMuxData : FOR I IN 0 TO CHUNKS - 1 GENERATE
		Mux_Data(I)		<= Input(((I + 1) * OUTPUT_BITS) - 1 DOWNTO I * OUTPUT_BITS);
	END GENERATE;

	genRegistered0 : IF (REGISTERED = TRUE) GENERATE
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Reset = '1') THEN
					Mux_Data_d		<= (OTHERS => (OTHERS => '0'));
				ELSE
					Mux_Data_d		<= Mux_Data;
				END IF;
			END IF;
		END PROCESS;
	END GENERATE;
	genRegistered1 : IF (REGISTERED = FALSE) GENERATE
		Mux_Data_d		<= Mux_Data;
	END GENERATE;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR rst) = '1') THEN
				rev_l							<= rev;
			
				IF (rev = '0') THEN
					Mux_sel_us			<= to_unsigned(0,							Mux_sel_us'length);
				ELSE
					Mux_sel_us			<= to_unsigned((CHUNKS - 1),	Mux_sel_us'length);
				END IF;
			ELSE
				IF (nxt = '1') THEN
					IF (rev_l = '0') THEN
						Mux_sel_us		<= Mux_sel_us + 1;
					ELSE
						Mux_sel_us		<= Mux_sel_us - 1;
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	Output		<= Mux_Data_d(ite((SIMULATION = TRUE), imin(to_integer(Mux_sel_us), CHUNKS - 1), to_integer(Mux_sel_us)));
END;