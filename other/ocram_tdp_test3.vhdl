-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Martin Zabel
--
-- Entity:          PoC.mem.ocram.tdp with registers on output and disabled
--                  write on port2
--
-- Description:
-- -------------------------------------
-- Synthesis test of PoC.mem.ocram.tdp when outputs ``q1`` and ``q2`` are
-- registered again and write on port2 is disabled.
--
-- License:
-- =============================================================================
-- Copyright 2016-2016 Technische Universitaet Dresden - Germany
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;

entity ocram_tdp_test3 is

	generic (
		A_BITS	 : positive := 12;
		D_BITS	 : positive := 16;
		FILENAME : string := "");

	port (
		clk1 : in	 std_logic;
		clk2 : in	 std_logic;
		ce1	 : in	 std_logic;
		ce2	 : in	 std_logic;
		we1	 : in	 std_logic;
		a1	 : in	 unsigned(A_BITS-1 downto 0);
		a2	 : in	 unsigned(A_BITS-1 downto 0);
		d1	 : in	 std_logic_vector(D_BITS-1 downto 0);
		q1	 : out std_logic_vector(D_BITS-1 downto 0);
		q2	 : out std_logic_vector(D_BITS-1 downto 0));

end entity;

architecture rtl of ocram_tdp_test3 is

	signal q1_d : std_logic_vector(D_BITS-1 downto 0);
	signal q2_d : std_logic_vector(D_BITS-1 downto 0);

begin  -- architecture rtl

	ocram_0: entity poc.ocram_tdp
		generic map (
			A_BITS	 => A_BITS,
			D_BITS	 => D_BITS,
			FILENAME => FILENAME)
		port map (
			clk1 => clk1,
			clk2 => clk2,
			ce1	 => ce1,
			ce2	 => ce2,
			we1	 => we1,
			we2	 => '0',
			a1	 => a1,
			a2	 => a2,
			d1	 => d1,
			d2	 => (others => '-'),
			q1	 => q1_d,
			q2	 => q2_d);

	q1 <= q1_d when rising_edge(clk1);
	q2 <= q2_d when rising_edge(clk2);


end architecture;
