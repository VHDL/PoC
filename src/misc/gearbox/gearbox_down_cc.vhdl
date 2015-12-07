-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:				 	Patrick Lehmann
-- 
-- Module:				 	A gearbox module with a common clock (cc) interface.
--
-- Description:
-- ------------------------------------
--		This module provides a gearbox with a common clock (cc) interface.
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
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.components.all;


entity gearbox_down_cc is
	generic (
		INPUT_BITS						: POSITIVE	:= 32;
		OUTPUT_BITS						: POSITIVE	:= 24;
		ADD_INPUT_REGISTER		: BOOLEAN		:= FALSE;
		ADD_OUTPUT_REGISTER		: BOOLEAN		:= FALSE
	);
	port (
		Clock				: in	STD_LOGIC;
		Reset				: in	STD_LOGIC;
		
		In_Busy			: in	STD_LOGIC;
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
	
	function registered(signal Clock : STD_LOGIC; constant IsRegistered : BOOLEAN) return BOOLEAN is
	begin
		return ite(IsRegistered, rising_edge(Clock), TRUE);
	end function;
	
	subtype T_CHUNK			is STD_LOGIC_VECTOR(BITS_PER_CHUNK - 1 downto 0);
	type T_CHUNK_VECTOR	is array(NATURAL range <>) of T_CHUNK;
	
	signal MuxSelect_en				: STD_LOGIC;
	signal MuxSelect_us				: UNSIGNED(log2ceilnz(INPUT_CHUNKS) - 1 downto 0)		:= (others => '0');
	
	signal GearBoxInput				: T_CHUNK_VECTOR(INPUT_CHUNKS - 2 downto 0);
	signal GearBoxBuffer			: T_CHUNK_VECTOR(INPUT_CHUNKS - 1 downto 1);
begin
	-- genInputReg : if (ADD_INPUT_REGISTER = TRUE) generate
	DataIn	<= In_Data	when registered(Clock, ADD_INPUT_REGISTER);
	ValidIn	<= In_Valid	when registered(Clock, ADD_INPUT_REGISTER);
	-- end generate;
	-- genInputReg : if (ADD_INPUT_REGISTER = FALSE) generate
		-- DataIn		<= In_Data;
		-- ValidIn	<= In_Valid;
	-- end generate;
	
	process(DataIn)
	begin
		for i in 0 to INPUT_CHUNKS - 2 loop
			GearBoxInput(i)		<= DataIn((i + 1) * BITS_PER_CHUNK - 1 downto i * BITS_PER_CHUNK);
		end loop;
	end process;
	
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				GearBoxBuffer		<= (others => '0');
			elsif (ValidIn = '1') then
				for i in 1 to INPUT_CHUNKS - 1 loop
					GearBoxBuffer(i)		<= DataIn((i + 1) * BITS_PER_CHUNK - 1 downto i * BITS_PER_CHUNK);
				end loop;
			end if;
		end if;
	end process;
	
	MuxSelect_us		<= upcounter_next(cnt => MuxSelect_us, rst => (Reset or MuxSelect_ov), en => MuxSelect_en) when rising_edge(Clock);
	MuxSelect_ov		<= upcounter_equal(cnt => MuxSelect_us, val => (INPUT_CHUNKS - 1));
	
	In_Busy					<= MuxSelect_ov;
	
	genMux : for i in 0 to OUTPUT_CHUNKS - 1 generate
		signal MuxInput		: T_CHUNK_VECTOR(INPUT_CHUNKS - 1 downto 0);
	begin
		genMuxInputs : for j in 0 to INPUT_CHUNKS - 1 generate
			constant k		: INTEGER		:= i - j;
		begin
			MuxInput(j)	<= GearBoxInput(ite((K >= 0), k, INPUT_CHUNKS + k));
		end generate;
		
		GearBoxOutput(i)	<= MuxInput(to_index(MuxSelect_us, INPUT_CHUNKS));
	end generate;

	process(GearBoxOutput)
	begin
		for i in 0 to OUTPUT_CHUNKS - 1 loop
			DataOut((i + 1) * BITS_PER_CHUNK - 1 downto i * BITS_PER_CHUNK) <= GearBoxOutput(i);
		end loop;
	end process;

	-- genOutputReg : if (ADD_OUTPUT_REGISTER = TRUE) generate
	Out_Data	<= DataOut when registered(Clock, ADD_OUTPUT_REGISTER);
	-- end generate;
	-- genOutputReg : if (ADD_OUTPUT_REGISTER = FALSE) generate
		-- Out_Data	<= DataOut;
	-- end generate;
end architecture;
