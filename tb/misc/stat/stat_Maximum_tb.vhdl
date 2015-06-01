-- EMACS settings: -*-  tab-width:2  -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-------------------------------------------------------------------------------
-- Authors:      Patrick Lehmann
--
-- Description:  Testbench for stat_Minimum.
--
-------------------------------------------------------------------------------
-- Copyright 2007-2015 Technische Universität Dresden - Germany
--                     Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--    http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-------------------------------------------------------------------------------

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;
use			poC.utils.all;


entity stat_Minimum_tb is
end entity;


architecture tb of stat_Minimum_tb is

  -- component generics
  constant VALUES : T_NATVEC := (211, 63, 225, 211, 63, 5, 84, 63, 35, 12, 26, 84, 63, 57, 5, 68, 12, 99, 10, 5);

  -- component ports
  signal Clock		: std_logic		:= '1';
  signal Reset		: std_logic		:= '0';
	
  signal Enable		: std_logic		:= '0';
  signal DataIn		: std_logic_vector(7 downto 0);

begin
  
  -- component instantiation
  DUT1: entity PoC.stat_Minimum
    generic map (
      DEPTH					=> 8,
			DATA_BITS			=> 8,
			COUNTER_BITS	=> 4
    )
    port map (
      Clock			=> Clock,
      Reset			=> Reset,
			
			Enable		=> Enable,
			DataIn		=> DataIn,
			
			Valids		=> open,
			Minimums	=> open
    );

  DUT2: entity PoC.stat_Maximum
    generic map (
      DEPTH					=> 8,
			DATA_BITS			=> 8,
			COUNTER_BITS	=> 4
    )
    port map (
      Clock			=> Clock,
      Reset			=> Reset,
			
			Enable		=> Enable,
			DataIn		=> DataIn,
			
			Valids		=> open,
			Maximums	=> open
    );

	process
		procedure cycle is
		begin
			Clock	<= '1';
			wait for 5 ns;
			Clock <= '0';
			wait for 5 ns;
		end cycle;
	begin
		cycle;
		Reset		<= '1';
		cycle;
		Reset		<= '0';
		cycle;
		cycle;
		Enable	<= '1';

		for i in VALUES'range loop
			Enable	<= to_sl(VALUES(i) /= 35);
			DataIn	<= to_slv(VALUES(i), DataIn'length);
			cycle;
		end loop;

		cycle;

		report "Test complete.";
		wait;
	end process;

end;
