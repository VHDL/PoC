-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Martin Zabel
--									Patrick Lehmann
-- 
-- Module:					Instantiates Chip-Specific DDR Input Registers for Xilinx FPGAs.
--
-- Description:
-- ------------------------------------
--		See PoC.io.ddrio.in for interface description.
--		
-- License:
-- ============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany,
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
use			IEEE.std_logic_1164.ALL;

library	UniSim;
use			UniSim.vComponents.all;


entity ddrio_in_xilinx is
	generic (
		INIT_VALUES	: BIT_VECTOR			:= '1';
		WIDTH				: positive
	);
	port (
		clk		: in	std_logic;
		ce		: in	std_logic;
		i			: in	std_logic_vector(WIDTH-1 downto 0);
		dh		: out	std_logic_vector(WIDTH-1 downto 0);
		dl		: out	std_logic_vector(WIDTH-1 downto 0)
	);
end entity;


architecture rtl of ddrio_out_xilinx is

begin
	gen : for i in 0 to WIDTH - 1 generate
		dff : IDDR
			generic map(
				DDR_CLK_EDGE	=> "SAME_EDGE",
				INIT_Q1				=> INIT(0),
				INIT_Q2				=> INIT(1),
				SRTYPE				=> "SYNC"
			)
			port map (
				C		=> clk,
				CE	=> ce,
				D		=> i,
				Q1	=> dh(i),
				Q2	=> dl(i),
				R		=> '0',
				S		=> '0'
			);
	end generate;
end architecture;
