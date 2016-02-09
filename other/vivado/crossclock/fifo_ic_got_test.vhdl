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
use PoC.utils.all;

entity fifo_ic_got_test is

	generic (
		D_BITS				 : positive := 8;
		MIN_DEPTH			 : positive := 16;
		DATA_REG			 : boolean := false;
		OUTPUT_REG		 : boolean := true);

	port (
		Clock1		: in	std_logic;
		rst_wr		: in	std_logic;
		put				: in	std_logic;
		din				: in	std_logic_vector(D_BITS-1 downto 0);
		full			: out std_logic;
		Clock2		: in	std_logic;
		rst_rd		: in	std_logic;
		got				: in	std_logic;
		valid			: out std_logic;
		dout			: out std_logic_vector(D_BITS-1 downto 0));

end entity fifo_ic_got_test;


architecture rtl of fifo_ic_got_test is
begin  -- architecture rtl

	test_1: entity poc.fifo_ic_got
		generic map (
			D_BITS				 => D_BITS,
			MIN_DEPTH			 => MIN_DEPTH,
			DATA_REG			 => DATA_REG,
			OUTPUT_REG		 => OUTPUT_REG,
			ESTATE_WR_BITS => 0,
			FSTATE_RD_BITS => 0)
		port map (
			clk_wr		=> Clock1,
			rst_wr		=> rst_wr,
			put				=> put,
			din				=> din,
			full			=> full,
			estate_wr => open,
			clk_rd		=> Clock2,
			rst_rd		=> rst_rd,
			got				=> got,
			valid			=> valid,
			dout			=> dout,
			fstate_rd => open);

end architecture rtl;
