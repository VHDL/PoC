-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
-- 
-- Module:					Check synthesis of physical types.
--
-- 
-- Description:
-- ------------------------------------
--		TODO
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

library poc;
use poc.physical.all;
use poc.utils.all;

entity physical_test is
  
	generic (
		ENABLE_TIME_TEST			: boolean := true;
		ENABLE_FREQ_TEST			: boolean := true;
		ENABLE_BAUD_TEST			: boolean := true;
		ENABLE_MEMORY_TEST		: boolean := true;
		ENABLE_FREQ2TIME_TEST : boolean := true;
		ENABLE_SUB_TEST				: boolean := true);

	port (
		clk		: in	std_logic;
		d			: in	std_logic;
		q			: out std_logic_vector(2 downto 0);
		x			: in	std_logic;
		y     : out std_logic_vector(4 downto 0));

end entity;

architecture rtl of physical_test is
begin  -- architecture rtl

	gEnableTime: if ENABLE_TIME_TEST generate
		test_time: entity work.physical_test_time
			port map (
				x => x,
				y => y(0));
	end generate;
	
	gEnableFreq: if ENABLE_FREQ_TEST generate
		test_freq: entity work.physical_test_freq
			port map (
				x => x,
				y => y(1));
	end generate;
	
	gEnableBaud: if ENABLE_BAUD_TEST generate
		test_baud: entity work.physical_test_baud
			port map (
				x => x,
				y => y(2));
	end generate;
	
	gEnableMemory: if ENABLE_MEMORY_TEST generate
		test_memory: entity work.physical_test_memory
			port map (
				x => x,
				y => y(3));
	end generate;
	
	gEnableFreq2time: if ENABLE_FREQ2TIME_TEST generate
		test_freq2time: entity work.physical_test_freq2time
			port map (
				x => x,
				y => y(4));
	end generate;
	
	gEnableSub: if ENABLE_SUB_TEST generate
		sub0: entity work.physical_test_sub
			generic map (
				CLOCK_FREQ   => 100 MHz,
				DELAY_TIME   => 865.0e-9,
				CLOCK_PERIOD => to_time(100 MHz),
				STEPS 	  	 => TimingToCycles(865.0e-9, 100 MHz),
				EXPECT_STEPS => 87)
			port map (
				clk => clk,
				d	  => d,
				q	  => q(0));
		sub1: entity work.physical_test_sub
			generic map (
				CLOCK_FREQ   => 100 MHz,
				DELAY_TIME   => 865.0e-9,
				CLOCK_PERIOD => to_time(100 MHz),
				STEPS 	  	 => TimingToCycles(865.0e-9, 100 MHz, ROUND_DOWN),
				EXPECT_STEPS => 86)
			port map (
				clk => clk,
				d	  => d,
				q	  => q(1));
		sub2: entity work.physical_test_sub
			generic map (
				CLOCK_FREQ   => 100 MHz,
				DELAY_TIME   => 865.0e-9,
				CLOCK_PERIOD => to_time(100 MHz),
				STEPS 	  	 => TimingToCycles(865.0e-9, 100 MHz, ROUND_TO_NEAREST),
				EXPECT_STEPS => 87)
			port map (
				clk => clk,
				d	  => d,
				q	  => q(2));
	end generate;
end architecture rtl;
