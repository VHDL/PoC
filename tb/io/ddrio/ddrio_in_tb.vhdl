-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Martin Zabel
-- 
-- Testbench:					for component ddrio_in
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

entity ddrio_in_tb is

end entity ddrio_in_tb;

-------------------------------------------------------------------------------

architecture sim of ddrio_in_tb is

  -- component generics
  constant BITS		   	: POSITIVE := 2;
  constant INIT_VALUE : BIT_VECTOR(1 downto 0) := "10";

  -- component ports
  signal Clock	    	: STD_LOGIC := '1';
  signal ClockEnable 	: STD_LOGIC := '0';
  signal DataIn_high 	: STD_LOGIC_VECTOR(BITS - 1 downto 0);
  signal DataIn_low 	: STD_LOGIC_VECTOR(BITS - 1 downto 0);
  signal Pad	     		: STD_LOGIC_VECTOR(BITS - 1 downto 0);

  signal STOPPED : boolean := false;

	-- period of signal "Clock"
	constant CLOCK_PERIOD : time := 10 ns;

	-- delay from "Clock" input to outputs of DUT
	-- must be less than CLOCK_PERIOD
	constant OUTPUT_DELAY : time :=  6 ns;
	
begin  -- architecture sim

  -- component instantiation
  DUT: entity poc.ddrio_in
    generic map (
      BITS	      => BITS,
      INIT_VALUE 	=> INIT_VALUE)
    port map (
      Clock	  		=> Clock,
      ClockEnable => ClockEnable,
      DataIn_high => DataIn_high,
      DataIn_low  => DataIn_low,
      Pad	  			=> Pad);

  -- clock generation
  Clock <= not Clock after CLOCK_PERIOD/2 when not STOPPED;

  -- waveform generation
  WaveGen_Proc: process
    variable ii : std_logic_vector(3 downto 0);
  begin
    -- simulate waiting for clock enable
    wait until rising_edge(Clock);
    wait until rising_edge(Clock);

    -- clock ready
    ClockEnable 	<= '1';
		for i in 0 to 15 loop
      ii := std_logic_vector(to_unsigned(i, 4));
			-- input LSB first
			Pad <= ii(1 downto 0); -- bit 0 and 1 with falling edge
			wait until falling_edge(Clock);
						 
			Pad <= ii(3 downto 2); -- bit 2 and 3 with rising  edge
			wait until rising_edge(Clock);
		end loop;

		STOPPED <= true;
		wait;
  end process WaveGen_Proc;

	-- checkout output while reading from PAD
	WaveCheck_Proc: process
    variable ii : std_logic_vector(3 downto 0);
	begin
			wait for OUTPUT_DELAY;
			assert DataIn_high = to_stdlogicvector(INIT_VALUE) report "Wrong initial DataIn_high" severity error;
			assert DataIn_low  = to_stdlogicvector(INIT_VALUE)  report "Wrong initial DataIn_low"  severity error;
		
		-- wait until clock is enabled from process above
		wait until rising_edge(Clock) and ClockEnable = '1';
		
		for i in 0 to 15 loop
			-- precondition: simulation is at a rising_edge(Clock)
      ii := std_logic_vector(to_unsigned(i, 4));
			wait for OUTPUT_DELAY;
			assert DataIn_high = ii(3 downto 2) report "Wrong DataIn_high" severity error;
			assert DataIn_low  = ii(1 downto 0) report "Wrong DataIn_low"  severity error;
			wait until rising_edge(Clock);
		end loop;
		wait;
	end process WaveCheck_Proc;
  

end architecture sim;
