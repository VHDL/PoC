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
--USE			PoC.strings.ALL;
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
	ATTRIBUTE KEEP					: BOOLEAN;
	ATTRIBUTE ASYNC_REG			: STRING;
	ATTRIBUTE SHREG_EXTRACT	: STRING;

	SIGNAL ElectricalIDLE_async				: STD_LOGIC									:= '0';	
	SIGNAL ElectricalIDLE_sync				: STD_LOGIC									:= '0';	
	
	-- Mark register "Serial***_async" as asynchronous
	ATTRIBUTE ASYNC_REG OF ElectricalIDLE_async			: SIGNAL IS "TRUE";
	
	-- Prevent XST from translating two FFs into SRL plus FF
	ATTRIBUTE SHREG_EXTRACT OF ElectricalIDLE_async	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF ElectricalIDLE_sync	: SIGNAL IS "NO";

	SIGNAL NoDevice_i									: STD_LOGIC;
	SIGNAL NoDevice_d									: STD_LOGIC		:= '0';
	SIGNAL NoDevice_re								: STD_LOGIC;

BEGIN
	-- synchronize ElectricalIDLE to working clock domain
	ElectricalIDLE_async	<= ElectricalIDLE				WHEN rising_edge(Clock);
	ElectricalIDLE_sync		<= ElectricalIDLE_async	WHEN rising_edge(Clock);
	
	GF : ENTITY PoC.io_GlitchFilter
		GENERIC MAP (
			CLOCK_FREQ_MHZ										=> CLOCK_FREQ_MHZ,
			HIGH_SPIKE_SUPPRESSION_TIME_NS		=> NEW_DEVICE_TIMEOUT_MS * 1000.0 * 1000.0,
			LOW_SPIKE_SUPPRESSION_TIME_NS			=> NO_DEVICE_TIMEOUT_MS * 1000.0 * 1000.0
		)
		PORT MAP (
			Clock		=> Clock,
			I				=> ElectricalIDLE_sync,
			O				=> NoDevice_i
		);
	
	NoDevice_d	<= NoDevice_i WHEN rising_edge(Clock);
	NoDevice_re	<= NOT NoDevice_d AND NoDevice_i;
	
	NewDevice		<= NoDevice_re;
END;