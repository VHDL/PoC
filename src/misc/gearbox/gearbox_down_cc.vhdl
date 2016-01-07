-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:				 	Patrick Lehmann
-- 
-- Module:				 	A downscaling gearbox module with a common clock (cc) interface.
--
-- Description:
-- ------------------------------------
--	This module provides a downscaling gearbox with a common clock (cc)
--	interface. It perfoems a 'word' to 'byte' splitting. The default order is
--	LITTLE_ENDIAN (starting at byte(0)). Input "In_Data" and output "Out_Data"
--	are of the same clock domain "Clock". Optional input and output registers
--	can be added by enabling (ADD_***PUT_REGISTERS = TRUE).
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

library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library PoC;
use			PoC.math.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.components.all;


entity gearbox_down_cc is
	generic (
		INPUT_BITS						: POSITIVE	:= 32;
		OUTPUT_BITS						: POSITIVE	:= 24;
		ADD_INPUT_REGISTERS		: BOOLEAN		:= FALSE;
		ADD_OUTPUT_REGISTERS	: BOOLEAN		:= FALSE
	);
	port (
		Clock				: in	STD_LOGIC;
		
		In_Sync			: in	STD_LOGIC;
		In_Next			: out	STD_LOGIC;
		In_Data			: in	STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0);
		In_Valid		: in	STD_LOGIC;
		Out_Data		: out	STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);
		Out_Valid		: out	STD_LOGIC
	);
end entity;


architecture rtl of gearbox_down_cc is
	constant BITS_PER_CHUNK		: POSITIVE		:= greatestCommonDivisor(INPUT_BITS, OUTPUT_BITS);
	constant INPUT_CHUNKS			: POSITIVE		:= INPUT_BITS / BITS_PER_CHUNK;
	constant OUTPUT_CHUNKS		: POSITIVE		:= OUTPUT_BITS / BITS_PER_CHUNK;
	
	subtype T_CHUNK					is STD_LOGIC_VECTOR(BITS_PER_CHUNK - 1 downto 0);
	type T_CHUNK_VECTOR			is array(NATURAL range <>) of T_CHUNK;
	
	subtype T_MUX_INDEX			is INTEGER range 0 to INPUT_CHUNKS - 1;
	type T_MUX_INPUT_LIST		is array(NATURAL range <>) of T_MUX_INDEX;
	type T_MUX_INPUT_STRUCT is record
		List		: T_MUX_INPUT_LIST(0 to OUTPUT_CHUNKS - 1);
		Nxt			: STD_LOGIC;
		Reg_en	: STD_LOGIC;
	end record;
	type T_MUX_DESCRIPTIONS		is array(NATURAL range <>) of T_MUX_INPUT_STRUCT;
	
	function geMuxDescription return T_MUX_DESCRIPTIONS is
		variable C		: T_MUX_DESCRIPTIONS(T_MUX_INDEX);
		variable k		: T_MUX_INDEX;
	begin
		k := INPUT_CHUNKS - 1;
		for i in C'range loop
			C(i).Reg_en			:= '0';
			for j in 0 to OUTPUT_CHUNKS - 1 loop
				k							:= (k + 1) mod INPUT_CHUNKS;
				C(i).List(j)	:= k;
				C(i).Reg_en		:= C(i).Reg_en	or	to_sl(k = 0);
			end loop;
			C(i).Nxt				:= to_sl(k + OUTPUT_CHUNKS >= INPUT_CHUNKS);
		end loop;
		return C;
	end function;
	
	function isZeroLine(C : T_MUX_DESCRIPTIONS; i : T_MUX_INDEX; j : T_MUX_INDEX) return BOOLEAN is
	begin
		for k in (j + 1) to OUTPUT_CHUNKS - 1 loop
			if (C(i).List(k) = 0) then
				return TRUE;
			end if;
		end loop;
		return FALSE;
	end function;
	
	constant MUX_INPUT_TRANSLATION		: T_MUX_DESCRIPTIONS		:= geMuxDescription;
	
	-- create vector-vector from vector (4 bit)
	function to_chunkv(slv : STD_LOGIC_VECTOR) return T_CHUNK_VECTOR is
		constant CHUNKS		: POSITIVE		:= slv'length / BITS_PER_CHUNK;
		variable Result		: T_CHUNK_VECTOR(CHUNKS - 1 downto 0);
	begin
		if ((slv'length mod BITS_PER_CHUNK) /= 0) then	report "to_chunkv: width mismatch - slv'length is no multiple of BITS_PER_CHUNK (slv'length=" & INTEGER'image(slv'length) & "; BITS_PER_CHUNK=" & INTEGER'image(BITS_PER_CHUNK) & ")" severity FAILURE;	end if;
		
		for i in 0 to CHUNKS - 1 loop
			Result(i)	:= slv(slv'low + ((i + 1) * BITS_PER_CHUNK) - 1 downto slv'low + (i * BITS_PER_CHUNK));
		end loop;
		return Result;
	end function;
	
	-- convert vector-vector to flatten vector
	function to_slv(slvv : T_CHUNK_VECTOR) return STD_LOGIC_VECTOR is
		variable slv			: STD_LOGIC_VECTOR((slvv'length * BITS_PER_CHUNK) - 1 downto 0);
	begin
		for i in slvv'range loop
			slv(((i + 1) * BITS_PER_CHUNK) - 1 downto (i * BITS_PER_CHUNK))		:= slvv(i);
		end loop;
		return slv;
	end function;
	
	signal DataIn							:	STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0)				:= (others => '0');
	signal ValidIn						: STD_LOGIC																				:= '0';
	
	signal MuxSelect_en				: STD_LOGIC;
	signal MuxSelect_us				: UNSIGNED(log2ceilnz(INPUT_CHUNKS) - 1 downto 0)	:= (others => '0');
	signal MuxSelect_ov				: STD_LOGIC;
	signal Nxt								: STD_LOGIC;
	
	signal GearBoxInput				: T_CHUNK_VECTOR(INPUT_CHUNKS - 1 downto 0);
	signal GearBoxBuffer_en		: STD_LOGIC;
	signal GearBoxBuffer			: T_CHUNK_VECTOR(INPUT_CHUNKS - 1 downto INPUT_CHUNKS - OUTPUT_CHUNKS + 1)	:= (others => (others => '0'));
	signal GearBoxOutput			: T_CHUNK_VECTOR(OUTPUT_CHUNKS - 1 downto 0);
	
	signal DataOut						:	STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0)			:= (others => '0');
	signal ValidOut						: STD_LOGIC																				:= '0';

begin
	assert (INPUT_BITS > OUTPUT_BITS) report "OUTPUT_BITS must be less than INPUT_BITS, otherwise it's no down-sizing gearbox." severity FAILURE;

	DataIn	<= In_Data	when registered(Clock, ADD_INPUT_REGISTERS);
	ValidIn	<= In_Valid	when registered(Clock, ADD_INPUT_REGISTERS);
	
	GearBoxInput			<= to_chunkv(DataIn(INPUT_BITS - 1 downto 0));
	GearBoxBuffer_en	<= MUX_INPUT_TRANSLATION(to_index(MuxSelect_us, INPUT_CHUNKS)).Reg_en and ValidIn;
	
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (GearBoxBuffer_en = '1') then
				GearBoxBuffer		<= to_chunkv(DataIn(INPUT_BITS - 1 downto ((INPUT_CHUNKS - OUTPUT_CHUNKS + 1) * BITS_PER_CHUNK)));
			end if;
		end if;
	end process;
	
	MuxSelect_en		<= ValidIn or MuxSelect_ov;
	MuxSelect_us		<= upcounter_next(cnt => MuxSelect_us, rst => (In_Sync or MuxSelect_ov), en => MuxSelect_en) when rising_edge(Clock);
	MuxSelect_ov		<= upcounter_equal(cnt => MuxSelect_us, value => (INPUT_CHUNKS - 1));
	Nxt							<= MUX_INPUT_TRANSLATION(to_index(MuxSelect_us, INPUT_CHUNKS)).Nxt;
	
	In_Next					<= Nxt;
	
	-- generate gearbox multiplexer structure
	genMux : for j in 0 to OUTPUT_CHUNKS - 1 generate
		signal MuxInput		: T_CHUNK_VECTOR(INPUT_CHUNKS - 1 downto 0);
	begin
		genMuxInputs : for i in 0 to INPUT_CHUNKS - 1 generate
			assert FALSE
				report "i= " & INTEGER'image(i) & " " &
							 "j= " & INTEGER'image(j) & " " &
							 "-> idx= " & INTEGER'image(MUX_INPUT_TRANSLATION(i).List(j)) & " " &
							 "-> useReg= " & BOOLEAN'image(isZeroLine(MUX_INPUT_TRANSLATION, i, j)) & " " &
							 "-> Nxt= " & STD_LOGIC'image(MUX_INPUT_TRANSLATION(i).Nxt)
				severity NOTE;
			
			connectToInput : if (isZeroLine(MUX_INPUT_TRANSLATION, i, j) = FALSE) generate
				MuxInput(i)	<= GearBoxInput(MUX_INPUT_TRANSLATION(i).List(j));
			end generate;
			connectToBuffer : if (isZeroLine(MUX_INPUT_TRANSLATION, i, j) = TRUE) generate
				MuxInput(i)	<= GearBoxBuffer(MUX_INPUT_TRANSLATION(i).List(j));
			end generate;
		end generate;
		
		GearBoxOutput(j)	<= MuxInput(to_index(MuxSelect_us, INPUT_CHUNKS));
	end generate;

	DataOut		<= to_slv(GearBoxOutput);
	ValidOut	<= ValidIn;
	
	Out_Data	<= DataOut	when registered(Clock, ADD_OUTPUT_REGISTERS);
	Out_Valid	<= ValidOut	when registered(Clock, ADD_OUTPUT_REGISTERS);
end architecture;
