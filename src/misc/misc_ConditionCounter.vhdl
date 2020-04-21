-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors: Stefan Unrein
--
-- Entity:  TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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

library IEEE;
use     IEEE.STD_LOGIC_1164.all;
use     IEEE.NUMERIC_STD.all;

library PoC;
use     PoC.utils.all;


entity misc_ConditionCounter is
	generic (
		Conditions       : T_NATVEC                    := (0 => 0, 1 => 1, 2 => 2, 3 => 15);
		Wraparound       : T_BOOLVEC                   := (0 to 2 => false, 3 => true)
	);
	port (
		Clock            : in  std_logic;
		Clear            : in  std_logic;
		
		Condition_Strobe : in  std_logic_vector(Conditions'range);
		Condition_Reset  : in  std_logic_vector(Conditions'range) := (others => '0');
		
		Condition_Met    : out std_logic
	);
end entity;


architecture rtl of misc_ConditionCounter is

	signal Condition_Met_i : std_logic_vector(Conditions'range);

begin
	Condition_Met <= slv_and(Condition_Met_i);
	
	condition_gen : for i in Conditions'range generate
		signal counter : unsigned(log2ceilnz(imax(Conditions)) -1 downto 0) := (others => '0');
	begin
		Condition_Met_i(i) <= Condition_Strobe(i) when counter = Conditions(i) else '0';
	
		process(Clock)
		begin
			if rising_edge(clock) then
				if Clear = '1' or Condition_Reset(i) = '1' then
					counter <= (others => '0');
				elsif Condition_Strobe(i) = '1' then
					if Wraparound(i) then
						if counter = Conditions(i) then
							counter <= (others => '0');
						else
							counter <= counter + 1;
						end if;
					else
						if counter < Conditions(i) then
							counter <= counter + 1;
						end if;
					end if;
				end if;
			end if;
		end process;
		
	end generate;



end;
