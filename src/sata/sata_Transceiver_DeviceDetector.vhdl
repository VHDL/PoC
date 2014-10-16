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
USE			PoC.physical.ALL;


ENTITY sata_DeviceDetector IS
	GENERIC (
		DEBUG			: BOOLEAN	:= FALSE;
		CLOCK_FREQ		: FREQ		:= 150.0 MHz;
		NO_DEVICE_TIMEOUT	: TIME		:= 50.0 ms;
		NEW_DEVICE_TIMEOUT	: TIME		:= 1000.0 us
	);
	PORT (
		Clock		: IN STD_LOGIC;
		ElectricalIDLE	: IN STD_LOGIC;
		NoDevice	: OUT STD_LOGIC;
		NewDevice	: OUT STD_LOGIC
	);
END;


ARCHITECTURE rtl OF sata_DeviceDetector IS
	ATTRIBUTE KEEP		: BOOLEAN;
	ATTRIBUTE FSM_ENCODING	: STRING;

	-- Statemachine
	TYPE T_State IS (ST_NORMAL_MODE, ST_NO_DEVICE, ST_NEW_DEVICE);

	SIGNAL State				: T_State	:= ST_NORMAL_MODE;
	SIGNAL NextState			: T_State;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL ElectricalIDLE_sync		: STD_LOGIC;
	SIGNAL ElectricalIDLE_i			: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";

	SIGNAL TC_load				: STD_LOGIC;
	SIGNAL TC_en				: STD_LOGIC;
	SIGNAL TC_timeout			: STD_LOGIC;
	SIGNAL TD_timeout			: STD_LOGIC;

BEGIN

	-- synchronize ElectricalIDLE to working clock domain
	sync2_DDClock : ENTITY PoC.sync_Flag
	PORT MAP (
		Clock		=> Clock,								-- Clock to be synchronized to
		Input(0)	=> ElectricalIDLE,	-- Data to be synchronized
		Output(0)	=> ElectricalIDLE_sync	-- synchronised data
	);

	ElectricalIDLE_i <= ElectricalIDLE_i(0) & ElectricalIDLE_sync WHEN rising_edge(Clock);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			State <= NextState;
		END IF;
	END PROCESS;

	PROCESS(State, ElectricalIDLE_i, TC_timeout, TD_timeout)
	BEGIN
		NextState			<= State;

		NoDevice			<= '0';
		NewDevice			<= '0';

		CASE State IS
			WHEN ST_NORMAL_MODE =>
				IF (TC_timeout = '1') THEN
					NextState	<= ST_NO_DEVICE;
				END IF;

			WHEN ST_NO_DEVICE =>
				NoDevice		<= '1';

				IF (TD_timeout = '1') THEN
					NextState	<= ST_NEW_DEVICE;
				END IF;

			WHEN ST_NEW_DEVICE =>
				NewDevice		<= '1';
				NextState		<= ST_NORMAL_MODE;

		END CASE;
	END PROCESS;
	
	TC : ENTITY PoC.io_TimingCounter
	GENERIC MAP ( -- timing table
		TIMING_TABLE => T_NATVEC'(0 => TimingToCycles(NO_DEVICE_TIMEOUT, CLOCK_FREQ))
	)
	PORT MAP (
		Clock	=> Clock,
		Enable	=> TC_en,
		Load	=> TC_load,
		Slot	=> 0,
		Timeout	=> TC_timeout
	);

	TC_load <= ElectricalIDLE_i(0) and not ElectricalIDLE_i(1);
	TC_en <= ElectricalIDLE_i(0);

	TD : ENTITY PoC.io_TimingCounter
	GENERIC MAP ( -- timing table
		TIMING_TABLE => T_NATVEC'(0 => TimingToCycles(NEW_DEVICE_TIMEOUT, CLOCK_FREQ))
	)
	PORT MAP (
		Clock	=> Clock,
		Enable	=> '1',
		Load	=> TC_timeout,
		Slot	=> 0,
		Timeout	=> TD_timeout
	);

END;