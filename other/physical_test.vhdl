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
		ENABLE_SUB_TEST  : boolean := true;
		ENABLE_TIME_TEST : boolean := true);

	port (
		clk		: in	std_logic;
		d			: in	std_logic;
		q			: out std_logic_vector(2 downto 0);
		x			: in	std_logic;
		yTime : out std_logic);

end entity;

architecture rtl of physical_test is
	function f return boolean is
	begin
	  report "to_freq( 500 ps ) = " & FREQ'image(to_freq( 500 ps )) severity note;
	  report "to_freq(   1 ns ) = " & FREQ'image(to_freq(   1 ns )) severity note;
	  report "to_freq(   5 ns ) = " & FREQ'image(to_freq(   5 ns )) severity note;
	  report "to_freq(  10 ns ) = " & FREQ'image(to_freq(  10 ns )) severity note;
	  report "to_freq(  50 ns ) = " & FREQ'image(to_freq(  50 ns )) severity note;
	  report "to_freq( 100 ns ) = " & FREQ'image(to_freq( 100 ns )) severity note;
	  report "to_freq( 500 ns ) = " & FREQ'image(to_freq( 500 ns )) severity note;
	  report "to_freq(   1 us ) = " & FREQ'image(to_freq(   1 us )) severity note;
	  report "to_freq(   5 us ) = " & FREQ'image(to_freq(   5 us )) severity note;
	  report "to_freq(  10 us ) = " & FREQ'image(to_freq(  10 us )) severity note;
	  report "to_freq(  50 us ) = " & FREQ'image(to_freq(  50 us )) severity note;
	  report "to_freq( 100 us ) = " & FREQ'image(to_freq( 100 us )) severity note;
	  report "to_freq( 500 us ) = " & FREQ'image(to_freq( 500 us )) severity note;
	  report "to_freq(   1 ms ) = " & FREQ'image(to_freq(   1 ms )) severity note;
	  report "to_freq(   5 ms ) = " & FREQ'image(to_freq(   5 ms )) severity note;
	  report "to_freq(  10 ms ) = " & FREQ'image(to_freq(  10 ms )) severity note;
	  report "to_freq(  50 ms ) = " & FREQ'image(to_freq(  50 ms )) severity note;
	  report "to_freq( 100 ms ) = " & FREQ'image(to_freq( 100 ms )) severity note;
	  report "to_freq( 500 ms ) = " & FREQ'image(to_freq( 500 ms )) severity note;
	  report "to_freq(   1 sec) = " & FREQ'image(to_freq(   1 sec)) severity note;
	  report "to_freq(   1  Bd) = " & FREQ'image(to_freq(   1 Bd )) severity note;
	  report "to_freq(   2  Bd) = " & FREQ'image(to_freq(   2 Bd )) severity note;
	  report "to_freq(   1 kBd) = " & FREQ'image(to_freq(   1 kBd)) severity note;
	  report "to_freq(   2 kBd) = " & FREQ'image(to_freq(   2 kBd)) severity note;
	  report "to_freq(   1 MBd) = " & FREQ'image(to_freq(   1 MBd)) severity note;
	  report "to_freq(   2 MBd) = " & FREQ'image(to_freq(   2 MBd)) severity note;
	  report "to_freq(1000 MBd) = " & FREQ'image(to_freq(1000 MBd)) severity note;
	  report "to_freq(2000 MBd) = " & FREQ'image(to_freq(2000 MBd)) severity note;
	  report "to_time(   1  Hz) = " & TIME'image(to_time(   1 Hz )) severity note;
	  report "to_time(   2  Hz) = " & TIME'image(to_time(   2 Hz )) severity note;
	  report "to_time(   1 kHz) = " & TIME'image(to_time(   1 kHz)) severity note;
	  report "to_time(   2 kHz) = " & TIME'image(to_time(   2 kHz)) severity note;
	  report "to_time(   1 MHz) = " & TIME'image(to_time(   1 MHz)) severity note;
	  report "to_time(   2 MHz) = " & TIME'image(to_time(   2 MHz)) severity note;
	  report "to_time(1000 MHz) = " & TIME'image(to_time(1000 MHz)) severity note;
	  report "to_time(2000 MHz) = " & TIME'image(to_time(2000 MHz)) severity note;
		report "2.5 * 2   us = " & TIME'image(2.5 * 2   us) severity note;
	  report "2   * 2.5 us = " & TIME'image(2   * 2.5 us) severity note;
	return true;
	end f;
	
	constant C : boolean := f;
  
--	constant STEPS 				: natural := TimingToCycles(DELAY_TIME, CLOCK_FREQ);
--	constant CLOCK_PERIOD : time		:= to_time(CLOCK_FREQ);

begin  -- architecture rtl

	gEnableSub: if ENABLE_SUB_TEST generate
		sub0: entity work.physical_test_sub
			generic map (
				CLOCK_FREQ   => 100 MHz,
				DELAY_TIME   => 865 ns,
				CLOCK_PERIOD => to_time(100 MHz),
				STEPS 	  	 => TimingToCycles(865 ns, 100 MHz),
				EXPECT_STEPS => 87)
			port map (
				clk => clk,
				d	  => d,
				q	  => q(0));
		sub1: entity work.physical_test_sub
			generic map (
				CLOCK_FREQ   => 100 MHz,
				DELAY_TIME   => 865 ns,
				CLOCK_PERIOD => to_time(100 MHz),
				STEPS 	  	 => TimingToCycles(865 ns, 100 MHz, ROUND_DOWN),
				EXPECT_STEPS => 86)
			port map (
				clk => clk,
				d	  => d,
				q	  => q(1));
		sub2: entity work.physical_test_sub
			generic map (
				CLOCK_FREQ   => 100 MHz,
				DELAY_TIME   => 865 ns,
				CLOCK_PERIOD => to_time(100 MHz),
				STEPS 	  	 => TimingToCycles(865 ns, 100 MHz, ROUND_TO_NEAREST),
				EXPECT_STEPS => 87)
			port map (
				clk => clk,
				d	  => d,
				q	  => q(2));
	end generate;
	
	gEnableTime: if ENABLE_TIME_TEST generate
		test_time: entity work.physical_test_time
			port map (
				x => x,
				y => yTime);
	end generate;
end architecture rtl;
