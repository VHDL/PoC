-- EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
--            ____        ____    _     _ _
--           |  _ \ ___  / ___|  | |   (_) |__  _ __ __ _ _ __ _   _
--           | |_) / _ \| |      | |   | | '_ \| '__/ _` | '__| | | |
--           |  __/ (_) | |___   | |___| | |_) | | | (_| | |  | |_| |
--           |_|   \___/ \____|  |_____|_|_.__/|_|  \__,_|_|   \__, |
--                                                             |___/
-- =============================================================================
-- Module:					sata_Transceiver_ClockStable
--
-- Authors:					Martin Zabel
--
-- Package:					PoC.sata
--
-- Description:
-- ------------------------------------
-- Generic reset handling for Altera FPGAs to be embedded into the SATA
-- transceiver layer. In contrast to the Xilinx version, Async_Reset is not
-- supported. 
--
-- Generates proper ResetDone and SATA_Clock_Stable signals in dependence on:
-- - asynchronous state of the PLL/DLL generating the SATA_Clock (PLL_Locked)
-- - the asynchronous control signal Async_Reset
-- - the synchronous control signal Kill_Stable which synchronously deasserts
--   SATA_Clock_Stable before reconfiguration
--
-- Assert Kill_Stable only if the PLL is reseted afterwards and PLL_Locked goes
-- low because SATA_Clock_Stable is only asserted again when PLL_Locked rises.
-- Apply Kill_Stable for one clock cycle. Reset PLL in the next cycle.
--
-- As Async_Reset is not available:
-- - SATA_Clock_Stable is only synchronously asserted (after PLL_Locked is
--   rising) and synchronously deasserted (by Kill_Stable).
-- - ResetDone is asserted one cycle after the first time SATA_Clock_Stable ist
--   asserted.
-- This is the normal operation of the SATA controller.
--
-- License:
-- -----------------------------------------------------------------------------
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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;

entity sata_Transceiver_ClockStable is
	port (
		-- @async
		PLL_Locked            : in  STD_LOGIC;

		-- the clock of the SATA controller
		SATA_Clock						: in	STD_LOGIC;
		
		-- @sync SATA_Clock, see exception in documentation
		Kill_Stable						: in 	STD_LOGIC;
		ResetDone							: out	STD_LOGIC;
		SATA_Clock_Stable			: out	STD_LOGIC
	);
end;


architecture rtl of sata_Transceiver_ClockStable is
	signal Locked_meta 			: std_logic := '0';
	signal Locked_sync1 		: std_logic := '0';
	signal Locked_sync2 		: std_logic := '0';
	signal Locked_rising 		: std_logic;
	signal Clock_Stable			: std_logic := '0';
	signal ResetDone_i			: std_logic := '0';
	
begin
	-- Only Locked_meta has a metastability problem. At all other FFs input D and
	-- output Q are the same (zero) when the FPGA is powered-up.
	-- According to the intial value, there will be always a rising edge on
	-- Locked_meta even if PLL_Locked is always high.

	Locked_rising <= Locked_sync1 and not Locked_sync2;
	
	process(SATA_Clock)
	begin
		if rising_edge(SATA_Clock) then
			Locked_meta  <= PLL_Locked;
			Locked_sync1 <= Locked_meta;
			Locked_sync2 <= Locked_sync1;
			
			-- R/S-Flipflop:
			-- reset when Kill_Stable (high priority)
			-- set   when Locked rises (low priority)
			Clock_Stable <= (Locked_rising or Clock_Stable) and not Kill_Stable;

			-- Assert ResetDone one cycle after SATA_Clock_Stable to synchronously
			-- reset the whole SATA stack with clock enabled.
			ResetDone_i <= ResetDone_i or Clock_Stable;
		end if;
	end process;
	
	SATA_Clock_Stable <= Clock_Stable;
	ResetDone <= ResetDone_i;

end;
