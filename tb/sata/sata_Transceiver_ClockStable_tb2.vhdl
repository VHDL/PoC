-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Testbench:				sata_Transceiver_ClockStable_tb2
-- 
-- Authors:					Martin Zabel
-- 
-- Description:
-- ------------------------------------
-- Automated testbench for 'PoC.sata_Transceiver_ClockStable'.
--
-- Tests also asynchronous input.
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

library ieee;
use ieee.std_logic_1164.all;

library PoC;
use PoC.simulation.all;

-------------------------------------------------------------------------------

entity sata_Transceiver_ClockStable_tb2 is

end entity sata_Transceiver_ClockStable_tb2;

-------------------------------------------------------------------------------

architecture behavioral of sata_Transceiver_ClockStable_tb2 is

	-- component ports
	signal Async_Reset 			 : STD_LOGIC := '0';
	signal PLL_Locked				 : STD_LOGIC;
	signal SATA_Clock				 : STD_LOGIC := '1';
	signal Kill_Stable			 : STD_LOGIC;
	signal ResetDone				 : STD_LOGIC;
	signal SATA_Clock_Stable : STD_LOGIC;

	signal sim_finished : boolean := false;
begin  -- architecture behavioral

  -- component instantiation
  DUT: entity work.sata_Transceiver_ClockStable
    port map (
      Async_Reset => Async_Reset,
      PLL_Locked	=> PLL_Locked,
      SATA_Clock	=> SATA_Clock,
      Kill_Stable	=> Kill_Stable,
      ResetDone		=> ResetDone,
      SATA_Clock_Stable => SATA_Clock_Stable);

  -- clock generation, actual frequency doesn't matter
  SATA_Clock <= not SATA_Clock after 10 ns when not sim_finished;

  -- waveform generation
  process
  begin
		PLL_Locked  <= '0';
		Kill_Stable <= '0';
		wait for 200 ns;
		PLL_Locked  <= '1';
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '0'), "Init state is wrong #1.");
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '0'), "Init state is wrong #2.");
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '0'), "Init state is wrong #3.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '0'), "SATA_Clock_Stable should be asserted now with ResetDone low #1.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "ResetDone should now be asserted #1.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "Steady state expected #1.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "Steady state expected #2.");
		Kill_Stable <= '1';
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "Steady state expected #3.");
		Kill_Stable <= '0';

		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '1'), "SATA_Clock_Stable should be deasserted now.");

		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '1'), "SATA_Clock_Stable should be kept low #1");
		PLL_Locked <= '0'; -- PLL is resetted

		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '1'), "SATA_Clock_Stable should be low #1");

		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '1'), "SATA_Clock_Stable should be low #2");

		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '1'), "SATA_Clock_Stable should be low #3");
		PLL_Locked <= '1'; -- PLL is locked again

		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '1'), "SATA_Clock_Stable should be low #3");

		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '1'), "SATA_Clock_Stable should be low #4");

		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '1'), "SATA_Clock_Stable should be low #5");
		
		wait until rising_edge(SATA_Clock);
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "SATA_Clock_Stable should be re-asserted now.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "Steady state expected #4.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "Steady state expected #5.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "Steady state expected #6.");

		wait for 1 ns;
		Async_Reset <= '1';
		PLL_Locked  <= '0';
		
		wait for 1 ns; -- output delay
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '0'), "SATA_Clock_Stable and ResetDone should be deasserted.");
		Async_Reset <= '0'; -- deassert within same cycle to mimic stopped clock

		wait for 100 ns;
		PLL_Locked <= '1';
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '0'), "Init state is wrong #4.");
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '0'), "Init state is wrong #5.");
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '0') and (ResetDone = '0'), "Init state is wrong #6.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '0'), "SATA_Clock_Stable should be asserted now with ResetDone low #2.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "ResetDone should now be asserted #2.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "Steady state expected #7.");
		
		wait until rising_edge(SATA_Clock);
		tbAssert((SATA_Clock_Stable = '1') and (ResetDone = '1'), "Steady state expected #8.");
    sim_finished <= true;
		tbPrintResult;
		wait;
  end process WaveGen_Proc;

end architecture behavioral;
