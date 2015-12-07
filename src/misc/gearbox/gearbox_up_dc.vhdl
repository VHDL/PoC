-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:				 	Patrick Lehmann
-- 
-- Module:				 	An upscaling gearbox module with a dependent clock (dc) interface.
--
-- Description:
-- ------------------------------------
--	This module provides a upscaling gearbox with a dependent clock (dc)
--	interface. It perfoems a 'byte' to 'word' collection. Input "I" is of clock
--	domain "Clock1"; output "O" is of clock domain "Clock2". Optional output
--	registers can be added by enabling (ADD_OUTPUT_REGISTERS = TRUE). In case of
--	up scaling, input "Align" is required to mark byte 0 in the word.
--
-- Assertions:
-- ===========
--	- Clock periods of Clock1 and Clock2 MUST be multiples of each other.
--	- Clock1 and Clock2 MUST be phase aligned (related) to each other.
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
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.components.all;


entity gearbox_up_dc is
  generic (
		INPUT_BITS						: POSITIVE				:= 8;														-- input bit width
		OUTPUT_BITS						: POSITIVE				:= 32;													-- output bit width
		ADD_INPUT_REGISTER		: BOOLEAN					:= FALSE;												-- add input register @Clock1
	  ADD_OUTPUT_REGISTERS	: BOOLEAN					:= FALSE												-- add output register @Clock2
	);
  port (
	  Clock1								: in	STD_LOGIC;																	-- input clock domain
		Clock2								: in	STD_LOGIC;																	-- output clock domain
		Align									: in	STD_LOGIC;																	-- align word (one cycle high impulse)
		In_Data								: in	STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0);	-- input word
		Out_Data							: out STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);	-- output word
		Out_Valid							: out	STD_LOGIC																		-- output is valid
	);
end entity;


architecture rtl OF gearbox_up_dc is
	constant BITS_RATIO		: REAL			:= real(INPUT_BITS) / real(OUTPUT_BITS);
	constant COUNTER_BITS : POSITIVE	:= log2ceil(integer(BITS_RATIO));

	signal Counter_us			: UNSIGNED(COUNTER_BITS - 1 downto 0)						:= (others => '0');
	signal Select_us			: UNSIGNED(COUNTER_BITS - 1 downto 0);
	signal In_Data_d			:	STD_LOGIC_VECTOR(OUTPUT_BITS - INPUT_BITS - 1 downto 0);
	signal Collected			: STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);
	signal Collected_d		: STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);
begin
	-- byte alignment counter @Clock1
	Counter_us	<= upcounter_next(cnt => Counter_us, rst => Align, INIT => 1) when rising_edge(Clock1);
	Select_us		<= mux(Align, Counter_us, (Counter_us'range => '0'));

	-- delay registers @Clock1
	process(Clock1)
	begin
		if rising_edge(Clock1) then
			for j in 2**COUNTER_BITS - 2 downto 0 loop
				if j = to_integer(Select_us) then					-- d-FF enable
					for k in INPUT_BITS - 1 downto 0 loop
						In_Data_d((j * INPUT_BITS) + k) <= In_Data(k);
					end loop;
				end if;
			end loop;
		end if;
	end process;
	
	-- collect signals
	Collected <= In_Data & In_Data_d;
	
	-- register collected signals again @Clock1
	process(Clock1)
	begin
		if rising_edge(Clock1) then
			if (to_integer(Select_us) = (2**COUNTER_BITS - 1)) then
				Collected_d <= Collected;
			end if;
		end if;
	end process;
	
	-- add output register @Clock2
	genReg : if (ADD_OUTPUT_REGISTERS = TRUE) generate
		Out_Data <= Collected_d when rising_edge(Clock2);
	end generate;
	genNoReg : if (ADD_OUTPUT_REGISTERS = FALSE) generate
		Out_Data <= Collected_d;
	end generate;
end architecture;
