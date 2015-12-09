-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
-- 
-- Module:					Check Vivado synthesis of physical types.
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
use poc.config.all;

entity test is
  
  generic (
    CLOCK_FREQ  : freq := 100 MHz;
    DELAY_TIME  : time := 870 ns;
    TIME_1_FS   : time := 1 fs;
    TIME_1_PS   : time := 1 ps;
    TIME_1_NS   : time := 1 ns;
    TIME_1_US   : time := 1 us;
    TIME_1_MS   : time := 1 ms;
    TIME_1_S    : time := 1 sec;
    TIME_1_MIN  : time := 1 min;
    TIME_1_HR   : time := 1 hr);

  port (
    clk : in  std_logic;
    d	: in  std_logic;
    q	: out std_logic);

end entity;

architecture rtl of test is
  function MinimalTimeResolutionInSimulation return TIME is
  begin
    if		(1 fs > 0 sec) then	return 1 fs;
    elsif	(1 ps > 0 sec) then	return 1 ps;
    elsif	(1 ns > 0 sec) then	return 1 ns;
    elsif	(1 us > 0 sec) then	return 1 us;
    elsif	(1 ms > 0 sec) then	return 1 ms;
    else				return 1 sec;
    end if;
  end function;


  function div(a : TIME; b : TIME) return REAL is
    constant MTRIS	: TIME		:= MinimalTimeResolutionInSimulation;
  begin
    if	(a < 1 us) then
      return real(a / MTRIS) / real(b / MTRIS);
    elsif (a < 1 ms) then
      return real(a / (1000 * MTRIS)) / real(b / MTRIS) * 1000.0;
    elsif (a < 1 sec) then
      return real(a / (1000000 * MTRIS)) / real(b / MTRIS) * 1000000.0;
    else
      return real(a / (1000000000 * MTRIS)) / real(b / MTRIS) * 1000000000.0;
    end if;
  end function;
	
	function div(a : FREQ; b : FREQ) return REAL is
	begin
		return real(a / 1 Hz) / real(b / 1 Hz);
	end function;
	
	function to_time(f : FREQ) return TIME is
		variable res : TIME;
	begin
		if SYNTHESIS_TOOL = SYNTHESIS_TOOL_XILINX_VIVADO then
			if f = 100 MHz then
				res := 10 ns;
			elsif f = 150 MHz then
				res := 6666667 fs;
			elsif f = 200 MHz then
				res := 5 ns;
			else
				report "Input frequency not supported." severity failure;
				res := 0 fs;
			end if;
		else
			if		(f < 1 kHz) then res := div(1  Hz, f) * 1 sec;
			elsif (f < 1 MHz) then res := div(1 kHz, f) * 1 ms;
			elsif (f < 1 GHz) then res := div(1 MHz, f) * 1 us;
--	elsif (f < 1 THz) then res := div(1 GHz, f) * 1 ns;
			else										 res := div(1 GHz, f) * 1 ns;
--	else										 res := div(1 THz, f) * 1 ps;
			end if;
		end if;
	
		--if (POC_VERBOSE = TRUE) then
		--	report "to_time: f= " & to_string(f, 3) & "  return " & to_string(res, 3) severity note;
		--end if;
		return res;
	end function;

  
	constant STAGES				: natural := TimingToCycles(DELAY_TIME, CLOCK_FREQ);
	constant CLOCK_PERIOD : time		:= to_time(CLOCK_FREQ);
	constant RES_REAL			: REAL		:= div(DELAY_TIME, CLOCK_PERIOD);
	constant RES_NAT			: NATURAL := natural(ceil(res_real));

begin  -- architecture rtl

--  assert false report "CLOCK_PERIOD=" & time'image(CLOCK_PERIOD) severity note;
--  assert false report "STAGES=" & integer'image(STAGES) severity note;

  shift_reg_1: entity work.shift_reg
    generic map (
      STAGES	  	 => STAGES,
      CLOCK_FREQ   => CLOCK_FREQ,
      DELAY_TIME   => DELAY_TIME,
      CLOCK_PERIOD => CLOCK_PERIOD,
      RES_REAL     => RES_REAL,
      RES_NAT      => RES_NAT,
      TIME_1_FS	   => TIME_1_FS,
      TIME_1_PS	   => TIME_1_PS,
      TIME_1_NS	   => TIME_1_NS,
      TIME_1_US	   => TIME_1_US,
      TIME_1_MS	   => TIME_1_MS,
      TIME_1_S	   => TIME_1_S,
      TIME_1_MIN   => TIME_1_MIN,
      TIME_1_HR	   => TIME_1_HR)
    port map (
      clk => clk,
      d	  => d,
      q	  => q);
  
end architecture rtl;
