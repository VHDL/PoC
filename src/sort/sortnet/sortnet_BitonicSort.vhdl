-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Module:					Sorting Network: Bitonic-Sort
--
-- Description:
-- ------------------------------------
--	TODO
--
-- License:
-- =============================================================================
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
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;


entity sortnet_BitonicSort is
	generic (
		INPUTS								: POSITIVE	:= 8;
		KEY_BITS							: POSITIVE	:= 16;
		DATA_BITS							: POSITIVE	:= 16;
		ADD_OUTPUT_REGISTERS	: BOOLEAN		:= TRUE
	);
	port (
		Clock									: in	STD_LOGIC;
		Reset									: in	STD_LOGIC;
		
		DataInputs						: in	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
		DataOutputs						: out	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0)
	);
end entity;


architecture rtl of sortnet_BitonicSort is
	signal DataInputMatrix1		: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputMatrix1	: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	
begin
	DataInputMatrix1		<= DataInputs;
	
	sort : entity PoC.sortnet_BitonicSort_Sort
		generic map (
			INPUTS			=> INPUTS,
			KEY_BITS		=> KEY_BITS,
			DATA_BITS		=> DATA_BITS,
			INVERSE			=> FALSE
		)
		port map (
			Clock				=> Clock,
			Reset				=> Reset,
			
			DataInputs	=> DataInputMatrix1,
			DataOutputs	=> DataOutputMatrix1
		);
	
	genOutReg : if (ADD_OUTPUT_REGISTERS = TRUE) generate
		DataOutputs	<= DataOutputMatrix1 when rising_edge(Clock);
	end generate;
	genNoOutReg : if (ADD_OUTPUT_REGISTERS = FALSE) generate
		DataOutputs	<= DataOutputMatrix1;
	end generate;
end architecture;
