-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		This module generates pulse trains. This module was written as a answer for
--		a stackoverflow question: http://stackoverflow.com/questions/25783320
-- 
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;


entity PulseTrain is
	generic (
		PULSE_TRAIN				: STD_LOGIC_VECTOR
	);
	port (
		Clock							: in	STD_LOGIC;
		StartSequence			: in	STD_LOGIC;
		SequenceCompleted	: out	STD_LOGIC;
		Output						: out	STD_LOGIC
	); 
end entity; 


architecture rtl of PulseTrain is 
	signal State								: STD_LOGIC																							:= '0';
	signal Counter_us						: UNSIGNED(log2ceilnz(PULSE_TRAIN'length) - 1 downto 0)	:= (others => '0');
	signal SequenceCompleted_i	: STD_LOGIC;
begin
	-- state control is done by a basic RS-FF
  process(Clock) is
	begin 
		if rising_edge(Clock) then
			if (StartSequence = '1') then
				State		<= '1';
			elsif (SequenceCompleted_i = '1') then
				State		<= '0';
			end if;
		end if;
	end process;
	
	SequenceCompleted_i		<= to_sl(Counter_us = (PULSE_TRAIN'length - 1));
	SequenceCompleted			<= SequenceCompleted_i;
	
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (State = '0') then
				Counter_us	<= (others => '0');
			else
				Counter_us	<= Counter_us + 1;
			end if;
		end if;
	end process;
	
	Output	<= PULSE_TRAIN(to_index(Counter_us));
end;
