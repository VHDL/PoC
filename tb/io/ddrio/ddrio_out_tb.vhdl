-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Martin Zabel
-- 
-- Testbench:					for component ddrio_out
--
-- Description:
-- ------------------------------------
-- TODO
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;

-------------------------------------------------------------------------------

entity ddrio_out_tb is

end entity ddrio_out_tb;

-------------------------------------------------------------------------------

architecture sim of ddrio_out_tb is

  -- component generics
  constant NO_OUTPUT_ENABLE : BOOLEAN	 		:= false;
  constant BITS		    			: POSITIVE   	:= 2;
  constant INIT_VALUE	    	: BIT_VECTOR(1 downto 0) := "10";

  -- component ports
  signal Clock	      : STD_LOGIC := '1';
  signal ClockEnable  : STD_LOGIC := '0';
  signal OutputEnable : STD_LOGIC := '0';
  signal DataOut_high : STD_LOGIC_VECTOR(BITS - 1 downto 0);
  signal DataOut_low  : STD_LOGIC_VECTOR(BITS - 1 downto 0);
  signal Pad	      : STD_LOGIC_VECTOR(BITS - 1 downto 0);

  signal STOPPED : boolean := false;
  
begin  -- architecture sim

  -- component instantiation
  DUT: entity poc.ddrio_out
    generic map (
      NO_OUTPUT_ENABLE => NO_OUTPUT_ENABLE,
      BITS	       => BITS,
      INIT_VALUE       => INIT_VALUE)
    port map (
      Clock	   => Clock,
      ClockEnable  => ClockEnable,
      OutputEnable => OutputEnable,
      DataOut_high => DataOut_high,
      DataOut_low  => DataOut_low,
      Pad	   => Pad);

  -- clock generation
  Clock <= not Clock after 5 ns when not STOPPED;

  -- waveform generation
  WaveGen_Proc: process
    variable ii : std_logic_vector(3 downto 0);
  begin
    -- simulate waiting for clock enable
    wait until rising_edge(Clock);
    wait until rising_edge(Clock);

    -- clock ready, no output yet
    ClockEnable 	<= '1';
		if NO_OUTPUT_ENABLE then
			DataOut_high 	<= to_stdlogicvector(not INIT_VALUE);
			DataOut_low  	<= to_stdlogicvector(not INIT_VALUE);
		end if;
    wait until rising_edge(Clock);
    wait until rising_edge(Clock);

    -- output some data
    OutputEnable <= '1';
    for i in 0 to 15 loop
      ii := std_logic_vector(to_unsigned(i, 4));
      -- output LSB first
      DataOut_high <= ii(1 downto 0); -- bit 0 and 1 with rising  edge
      DataOut_low  <= ii(3 downto 2); -- bit 2 and 3 with falling edge
      wait until rising_edge(Clock);
    end loop;

    -- disable output again
    OutputEnable <= '0';
    wait until rising_edge(Clock);

    STOPPED <= true;
    wait;
  end process WaveGen_Proc;

end architecture sim;
