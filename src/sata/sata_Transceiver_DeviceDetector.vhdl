-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--									Steffen Koehler
--
-- Description:
-- ------------------------------------
--		TODO
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
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.io.ALL;


ENTITY sata_DeviceDetector IS
	GENERIC (
		DEBUG									: BOOLEAN				:= FALSE;
		CLOCK_FREQ_MHZ				: REAL					:= 150.0;						-- 150 MHz
		NO_DEVICE_TIMEOUT_MS	: REAL					:= 0.5;							-- 0,5 ms
		NEW_DEVICE_TIMEOUT_MS	: REAL					:= 0.01							-- 10 us				-- TODO: unused?
	);
	PORT (
		Clock						: IN STD_LOGIC;
		ElectricalIDLE	: IN STD_LOGIC;
		NoDevice				: OUT STD_LOGIC;
		NewDevice				: OUT STD_LOGIC
	);
END;


ARCHITECTURE rtl OF sata_DeviceDetector IS
	CONSTANT NO_DEVICE_TIMEOUT							: TIME		:= ite(SIMULATION, 2.0 us, ms2Time(NO_DEVICE_TIMEOUT_MS));
	CONSTANT NEW_DEVICE_TIMEOUT							: TIME		:= ite(SIMULATION, 0.1 us, ms2Time(NEW_DEVICE_TIMEOUT_MS));
			
	CONSTANT HIGH_SPIKE_SUPPRESSION_CYCLES	: NATURAL	:= TimingToCycles(NO_DEVICE_TIMEOUT,	MHz2Time(CLOCK_FREQ_MHZ));
	CONSTANT LOW_SPIKE_SUPPRESSION_CYCLES		: NATURAL	:= TimingToCycles(NEW_DEVICE_TIMEOUT,	MHz2Time(CLOCK_FREQ_MHZ));
	
	SIGNAL ElectricalIDLE_sync	: STD_LOGIC;
	
	SIGNAL NoDevice_i						: STD_LOGIC;
	SIGNAL NoDevice_d						: STD_LOGIC		:= '0';
	SIGNAL NoDevice_re					: STD_LOGIC;

BEGIN
	-- synchronize ElectricalIDLE to working clock domain
	sync2_DDClock : ENTITY PoC.sync_Flag
		PORT MAP (
			Clock					=> Clock,								-- Clock to be synchronized to
			Input(0)			=> ElectricalIDLE,			-- Data to be synchronized
			Output(0)			=> ElectricalIDLE_sync	-- synchronised data
		);
	
	GF : ENTITY PoC.io_GlitchFilter
		GENERIC MAP (
			HIGH_SPIKE_SUPPRESSION_CYCLES		=> HIGH_SPIKE_SUPPRESSION_CYCLES,
			LOW_SPIKE_SUPPRESSION_CYCLES		=> LOW_SPIKE_SUPPRESSION_CYCLES
		)
		PORT MAP (
			Clock		=> Clock,
			Input		=> ElectricalIDLE_sync,
			Output	=> NoDevice_i
		);
	
	NoDevice_d	<= NoDevice_i WHEN rising_edge(Clock);
	NoDevice_re	<= NOT NoDevice_d AND NoDevice_i;
	
	NoDevice		<= NoDevice_i;
	NewDevice		<= NoDevice_re;
END;