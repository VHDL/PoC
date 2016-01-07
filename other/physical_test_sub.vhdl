-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
-- 
-- Module:					Sub-module for physical_test.
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

library poc;
use poc.physical.all;
use poc.utils.all;

entity physical_test_sub is
  
  generic (
    CLOCK_FREQ   : freq;
    DELAY_TIME   : time;
    DELAY_TIME2  : time;
    CLOCK_PERIOD : time;
    STEPS				 : integer;
    TIME_1_FS    : time;
    TIME_1_PS    : time;
    TIME_1_NS    : time;
    TIME_1_US    : time;
    TIME_1_MS    : time;
    TIME_1_S     : time;
    TIME_1_MIN   : time;
    TIME_1_HR    : time);

  port (
    clk : in  std_logic;
    d	: in  std_logic;
    q	: out std_logic);

end entity physical_test_sub;

architecture rtl of physical_test_sub is
	function f return boolean is
	begin
		report "DELAY_TIME    = " & TIME'image(DELAY_TIME  ) severity note;
		report "DELAY_TIME2   = " & TIME'image(DELAY_TIME2 ) severity note;
		report "CLOCK_PERIOD  = " & TIME'image(CLOCK_PERIOD) severity note;
	return true;
	end f;
	
	constant C : boolean := f;

begin  -- architecture rtl

	g0: if STEPS = 0 generate
		q <= d;
	end generate g0;

  g1: if STEPS = 1 generate
    q <= d when rising_edge(clk);
  end generate g1;

  g2: if STEPS > 1 generate
    signal reg : std_logic_vector(imax(STEPS,2)-1 downto 0);
  begin
    reg <= reg(reg'left-1 downto 0) & d when rising_edge(clk);
    q	<= reg(reg'left);
  end generate g2;

	gError: if TIME_1_HR < 0 sec generate
		-- The expression is true on Vivado, thus provoke an error.
		q <= '1';
	end generate gError;
end architecture rtl;
