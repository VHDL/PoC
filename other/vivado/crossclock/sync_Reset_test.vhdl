-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Martin Zabel
--
-- Module:					For testing of timing constraints.
--
-- Description:
-- ------------------------------------
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

library	ieee;
use			ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library	PoC;
use			PoC.sync.all;

entity sync_Reset_test is
	generic (
		EXTERNAL_RESET : boolean := true);
	port (
		Clock1	: in	STD_LOGIC;
		Clock2	: in	STD_LOGIC;
		Input		: in	STD_LOGIC;
		Output	: out STD_LOGIC_VECTOR(63 downto 0);
		Busy		: out STD_LOGIC;
		Changed : out STD_LOGIC);

end entity sync_Reset_test;

architecture rtl of sync_Reset_test is
	signal Input_r3  : STD_LOGIC;

	signal Reset2  : std_logic;
	signal Counter : unsigned(Output'range);
	
begin  -- architecture rtl

	gExtern: if EXTERNAL_RESET generate
		Input_r3 <= Input;
	end generate gExtern;
	
	gIntern: if not EXTERNAL_RESET generate
		signal Input_r1  : STD_LOGIC;
		signal Input_r2  : STD_LOGIC;
	begin
		-- Trigger the reset input by another clock domain instead of an external
		-- button. 
		Input_r1 <= Input    when rising_edge(Clock1);
		Input_r2 <= Input_r1 when rising_edge(Clock1);
		Input_r3 <= Input_r2 when rising_edge(Clock1);
	end generate gIntern;

	-- Reset Synchronizer
	reset_sync: entity poc.sync_Reset
		port map (
			Clock	 => Clock2,
			Input	 => Input_r3,
			Output => Reset2);

	-- example logic with an asynchronous reset
	process(Clock2, Reset2)
	begin
		if Reset2 = '1' then
			Counter <= (others => '0');
		elsif rising_edge(Clock2) then
			Counter <= Counter + 1;
		end if;
	end process;

	Output <= std_logic_vector(Counter);
	
end architecture rtl;
