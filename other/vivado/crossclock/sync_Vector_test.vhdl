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

library	IEEE;
use			IEEE.STD_LOGIC_1164.all;

library	PoC;
use			PoC.sync.all;

entity sync_Vector_test is

	generic (
		MASTER_BITS : positive				 := 8;
		SLAVE_BITS	: natural					 := 0;
		INIT				: std_logic_vector := "00000000");

	port (
		Clock1	: in	std_logic;
		Clock2	: in	std_logic;
		Input		: in	std_logic_vector((MASTER_BITS + SLAVE_BITS) - 1 downto 0);
		Output	: out std_logic_vector((MASTER_BITS + SLAVE_BITS) - 1 downto 0);
		Busy		: out std_logic;
		Changed : out std_logic);

end entity sync_Vector_test;

architecture rtl of sync_Vector_test is
	signal Input_r1  : std_logic_vector(MASTER_BITS + SLAVE_BITS - 1 downto 0);
	signal Input_r2  : std_logic_vector(MASTER_BITS + SLAVE_BITS - 1 downto 0);
	signal Input_r3  : std_logic_vector(MASTER_BITS + SLAVE_BITS - 1 downto 0);
	signal Output_r1 : std_logic_vector(MASTER_BITS + SLAVE_BITS - 1 downto 0);
	signal Output_r2 : std_logic_vector(MASTER_BITS + SLAVE_BITS - 1 downto 0);
	signal Output_r3 : std_logic_vector(MASTER_BITS + SLAVE_BITS - 1 downto 0);
begin  -- architecture rtl

	Input_r1 <= Input    when rising_edge(Clock1);
	Input_r2 <= Input_r1 when rising_edge(Clock1);
	Input_r3 <= Input_r2 when rising_edge(Clock1);

	test_1: entity poc.sync_Vector
		generic map (
			MASTER_BITS => MASTER_BITS,
			SLAVE_BITS	=> SLAVE_BITS,
			INIT				=> INIT)
		port map (
			Clock1	=> Clock1,
			Clock2	=> Clock2,
			Input		=> Input_r3,
			Output	=> Output_r1,
			Busy		=> open,
			Changed => open);

	Output_r2 <= Output_r1 when rising_edge(Clock2);
	Output_r3 <= Output_r2 when rising_edge(Clock2);
	Output    <= Output_r3 when rising_edge(Clock2);

end architecture rtl;
