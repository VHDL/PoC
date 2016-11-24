-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;


entity sort_LeastFrequentlyUsed is
	generic (
		ELEMENTS			: positive		:= 1024;
		KEY_BITS			: positive		:= 16;
		DATA_BITS			: positive		:= 16;
		COUNTER_BITS	: positive		:= 8
	);
	port (
		Clock					: in	std_logic;
		Reset					: in	std_logic;

		Access				: in	std_logic;
		Key						: in	std_logic_vector(KEY_BITS - 1 downto 0);

		LFU_Valid			: out	std_logic;
		LFU_Key				: out	std_logic_vector(KEY_BITS - 1 downto 0)
	);
end entity;


architecture rtl of sort_LeastFrequentlyUsed is
	type T_ELEMENT is record
		Data				: std_logic_vector(DATA_BITS - 1 downto 0);
		Counter_us	: unsigned(COUNTER_BITS - 1 downto 0);
		Valid				: std_logic;
	end record;

	type T_ELEMENT_VECTOR is array(natural range <>) of T_ELEMENT;

	constant C_ELEMENT_EMPTY	: T_ELEMENT		:= (Data => (others => '0'), Counter_us => (others => '0'), Valid => '0');

	signal List_d					: T_ELEMENT_VECTOR(ELEMENTS - 1 downto 0)		:= (others => C_ELEMENT_EMPTY);
	signal List_AddSub		: T_ELEMENT_VECTOR(ELEMENTS - 1 downto 0);
	signal List_OddSort		: T_ELEMENT_VECTOR(ELEMENTS - 1 downto 0);
	signal List_EvenSort	: T_ELEMENT_VECTOR(ELEMENTS - 1 downto 0);
begin

	genAddSub : for i in 0 to ELEMENTS - 1 generate
		process(List_d, Data, Access, new)
		begin
			List_AddSub(i)		<= List_d(i);
			if ((Access = '1') and (List_d(i).Data(KEY_BITS - 1 downto 0) = Data(KEY_BITS - 1 downto 0)) and (List_d(i).Counter_us /= (others => '1')) then
				List_AddSub(i).Counter_us		:= List_d(i).Counter_us + 1;
			elsif (new = '1') then		-- ((New = '1') and (List_d(i).Counter_us /= (others => '0')) then
				if i = 0 then
					List_AddSub(i).Data					:= Data;
					List_AddSub(i).Counter_us		:= (others => '0');
					List_AddSub(i).Valid				:= '1';
				else
					List_AddSub(i).Counter_us		:= List_d(i).Counter_us - List_d(0).Counter_us;
				end loop;
			end if;
		end process;
	end generate;
	genOddSort : for i in 0 to ELEMENTS - 2 generate
		process(List_AddSub)
		begin
			if ((i mod 2 = 0) and (List_AddSub(i).Counter_us <= List_AddSub(i + 1).Counter_us)) then
				List_OddSort(i)				<= List_AddSub(i);
				List_OddSort(i + 1)		<= List_AddSub(i + 1);
			else
				List_OddSort(i)				<= List_AddSub(i + 1);
				List_OddSort(i + 1)		<= List_AddSub(i);
			end if;
		end process;
	end generate;
	genEvenSort : for i in 1 to ELEMENTS - 3 generate
		process(List_OddSort)
		begin
			if ((i mod 2 = 0) and (List_OddSort(i).Counter_us <= List_OddSort(i + 1).Counter_us)) then
				List_EvenSort(i)				<= List_OddSort(i);
				List_EvenSort(i + 1)		<= List_OddSort(i + 1);
			else
				List_EvenSort(i)				<= List_OddSort(i + 1);
				List_EvenSort(i + 1)		<= List_OddSort(i);
			end if;
		end process;
	end generate;
	genReg : for i in 0 to ELEMENTS - 1 generate
		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Reset = '1') then
					List_d	<= (others => C_ELEMENT_EMPTY);
				else
					List_d	<= List_EvenSort;
				end if;
			end if;
		end process;
	end generate;

	LFU_Valid		<= List_d(0).Valid;
	LFU_Key			<= List_d(0).Key;
	LFU_Data		<= List_d(0).Data;

end architecture;
