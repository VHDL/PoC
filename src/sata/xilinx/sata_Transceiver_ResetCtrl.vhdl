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
-- Authors:					Martin Zabel
--
-- Package:					TODO
--
-- Description:
-- ------------------------------------
-- Generic reset handling for Xilinx FPGAs to be embedded into the SATA
-- transceiver layer.
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
-- When Async_Reset is unused (i.e. deasserted) then:
-- - SATA_Clock_Stable is only synchronously asserted (after PLL_Locked is
--   rising) and synchronously deasserted (by Kill_Stable).
-- - ResetDone is asserted one cycle after the first time SATA_Clock_Stable ist
--   asserted.
-- This is the normal operation of the SATA controller.
--
-- If Async_Reset is asserted, then SATA_Clock_Stable and ResetDone are
-- both asynchronously deasserted at the same moment. Reset the PLL at the same
-- moment. After Async_Reset is deasserted, SATA_Clock_Stable is
-- asserted again after the PLL locks, followed by the assertion of ResetDone
-- as described above.
--
-- Use cases for Async_Reset:
-- - Assert at power-up if the reference clock of the PLL is not yet stable.
-- - Powerdown of the SATA controller.
-- - Hard reset when reconfiguration does not succeed.
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

library UNISIM;
use			UNISIM.VCOMPONENTS.all;

library PoC;

entity sata_Transceiver_ResetCtrl is
	port (
		-- @async
		Async_Reset						: in	STD_LOGIC := '0';
		PLL_Locked            : in  STD_LOGIC;

		-- the clock of the SATA controller
		SATA_Clock						: in	STD_LOGIC;
		
		-- @sync SATA_Clock, see exception in documentation
		Kill_Stable						: in 	STD_LOGIC;
		ResetDone							: out	STD_LOGIC;
		SATA_Clock_Stable			: out	STD_LOGIC
	);
end;


architecture rtl of sata_Transceiver_ResetCtrl is
	attribute ASYNC_REG				: STRING;
	attribute SHREG_EXTRACT		: STRING;
	attribute RLOC						: STRING;
	
	signal Locked_meta 			: std_logic;
	signal Locked_sync1 		: std_logic;
	signal Locked_sync2 		: std_logic;
	signal Locked_rising 		: std_logic;
	signal Next_Stable 			: std_logic;
	signal Clock_Stable			: std_logic;
	signal Next_ResetDone		: std_logic;
	signal ResetDone_i			: std_logic;
	
	-- Mark register Data_async's input as asynchronous
	attribute ASYNC_REG			of Locked_meta	: signal is "TRUE";

	-- Prevent XST from translating two FFs into SRL plus FF
	attribute SHREG_EXTRACT of Locked_meta	: signal is "NO";
	attribute SHREG_EXTRACT of Locked_sync1	: signal is "NO";
	attribute SHREG_EXTRACT of Locked_sync2	: signal is "NO";
		
	-- Assign synchronization FF pairs to the same slice -> minimal routing delay
	attribute RLOC of Locked_meta						: signal is "X0Y0";
	attribute RLOC of Locked_sync1					: signal is "X0Y0";
	
begin
	-- Only FF1 has a metastability problem. At all other FFs input D and
	-- output Q are the same (zero) when the asynchronous reset is deasserted.
	-- Thus, deassertation can take place nearby a clock edge without problems.

	-- According to the intial value as well as the asynchronous reset, there
	-- will be always a rising edge on Locked_meta even if PLL_Locked is always
	-- high.
	FF1_METASTABILITY_FFS : FDCE
		generic map (
			INIT		=> '0'
		)
		port map (
			CLR			=> Async_Reset,
			C				=> SATA_Clock,
			CE 			=> '1',
			D				=> PLL_Locked,
			Q				=> Locked_meta
		);

	FF2 : FDCE
		generic map (
			INIT		=> '0'
		)
		port map (
			CLR			=> Async_Reset,
			C				=> SATA_Clock,
			CE 			=> '1',
			D				=> Locked_meta,
			Q				=> Locked_sync1
		);
	
	FF3 : FDCE
		generic map (
			INIT		=> '0'
		)
		port map (
			CLR			=> Async_Reset,
			C				=> SATA_Clock,
			CE 			=> '1',
			D				=> Locked_sync1,
			Q				=> Locked_sync2
		);

	Locked_rising <= Locked_sync1 and not Locked_sync2;

	-- FF4 is an R/S-Flipflop:
	-- reset when Kill_Stable (high priority)
	-- set   when Locked rises (low priority)
	Next_Stable <= (Locked_rising or Clock_Stable) and not Kill_Stable;
	
	FF4 : FDCE
		generic map (
			INIT		=> '0'
		)
		port map (
			CLR			=> Async_Reset,
			C				=> SATA_Clock,
			CE 			=> '1',
			D				=> Next_Stable,
			Q				=> Clock_Stable
		);

	SATA_Clock_Stable <= Clock_Stable;
	
	-- Assert ResetDone one cycle after SATA_Clock_Stable to synchronously reset
	-- the whole SATA stack with clock enabled.
	Next_ResetDone <= ResetDone_i or Clock_Stable;
	FF5 : FDCE
		generic map (
			INIT		=> '0'
		)
		port map (
			CLR			=> Async_Reset,
			C				=> SATA_Clock,
			CE 			=> '1',
			D				=> Next_ResetDone,
			Q				=> ResetDone_i
			);

	ResetDone <= ResetDone_i;

end;
