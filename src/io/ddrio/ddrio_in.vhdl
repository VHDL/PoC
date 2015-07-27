-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Martin Zabel
--									Patrick Lehmann
-- 
-- Module:					Chip-Specific DDR Input Registers
--
-- Description:
-- ------------------------------------
--		Instantiates chip-specific DDR input registers.
--		
--		Both data "dh" and "dl" are sampled with the rising_edge(clk) from the
--		on-chip logic. "dh" is brought out with this rising edge. "dl" is brought
--		out with the falling edge.
--		
--		"d" must be connected to a PAD because FPGAs only have these registers in
--		IOBs.
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


library	IEEE;
use			IEEE.std_logic_1164.all;

library	PoC;
use			PoC.config.all;
use			PoC.ddrio.all;


entity ddrio_in is
	generic (
			INIT_VALUES	: BIT_VECTOR		:= ('1', '1');
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


architecture rtl of ddrio_out is
  
begin
	assert (VENDOR = VENDOR_XILINX)-- or (VENDOR = VENDOR_ALTERA)
		report "ddrio_in not implemented for given DEVICE."
		severity failure;
	
	genXilinx : if (VENDOR = VENDOR_XILINX) generate
		i : ddrio_in_xilinx
			generic map (
				INIT_VALUES	=> INIT_VALUES,
				WIDTH				=> WIDTH
			)
			port map (
				clk => clk,
				ce  => ce,
				i   => i,
				dh  => dh,
				dl  => dl
			);
	end generate;

--	genAltera : if (VENDOR = VENDOR_ALTERA) generate
--		i : ddrio_in_altera
--			generic map (
--				WIDTH => WIDTH
--			)
--			port map (
--				clk => clk,
--				ce  => ce,
--				dh  => dh,
--				dl  => dl,
--				oe  => oe,
--				q   => q
--			);
--	end generate;
end architecture;
