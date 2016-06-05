-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Steffen Koehler
--
-- Entity: 					Old Device Detector for Transceivers
--
-- Description:
-- -------------------------------------
-- TO BE REMOVED.
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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;
--use			PoC.sata.all;


entity sata_DeviceDetector is
	generic (
		DEBUG								: BOOLEAN	:= FALSE;
		CLOCK_FREQ					: FREQ		:= 150 MHz;
		NO_DEVICE_TIMEOUT		: TIME		:= 50 ms;
		NEW_DEVICE_TIMEOUT	: TIME		:= 1 ms
	);
	port (
		Clock						: in STD_LOGIC;
		ElectricalIDLE	: in STD_LOGIC;
		RxComReset			: in STD_LOGIC;
		NoDevice				: out STD_LOGIC;
		NewDevice				: out STD_LOGIC
	);
end entity;


architecture rtl of sata_DeviceDetector is
	attribute KEEP					: BOOLEAN;
	attribute FSM_ENCODING	: STRING;

	-- Statemachine
	type T_State is (ST_NORMAL_MODE, ST_NO_DEVICE, ST_OOB_RESET, ST_NEW_DEVICE);

	signal State										: T_State	:= ST_NORMAL_MODE;
	signal NextState								: T_State;
	attribute FSM_ENCODING OF State	: signal IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	signal ElectricalIDLE_sync	: STD_LOGIC;
	signal ElectricalIDLE_i			: STD_LOGIC_VECTOR(1 downto 0) := "00";
	signal RxComReset_i					: STD_LOGIC_VECTOR(1 downto 0);

	signal TC_load				: STD_LOGIC;
	signal TC_en					: STD_LOGIC;
	signal TC_timeout			: STD_LOGIC;
	signal TD_load				: STD_LOGIC;
	signal TD_timeout			: STD_LOGIC;

begin

	-- synchronize ElectricalIDLE to working clock domain
	sync1_DDClock : entity PoC.sync_Bits
	port map (
		Clock		=> Clock,		-- Clock to be synchronized to
		Input(0)	=> ElectricalIDLE,	-- Data to be synchronized
		Output(0)	=> ElectricalIDLE_sync	-- synchronised data
	);

	ElectricalIDLE_i <= ElectricalIDLE_i(0) & ElectricalIDLE_sync when rising_edge(Clock);
	RxComReset_i <= RxComReset_i(0) & RxComReset when rising_edge(Clock);

	process(Clock)
	begin
		if rising_edge(Clock) then
			State <= NextState;
		end if;
	end process;

	process(State, ElectricalIDLE_i, TC_timeout, TD_timeout)
	begin
		NextState			<= State;

		NoDevice			<= '0';
		NewDevice			<= '0';
		TD_load				<= '0';

		case State is
			when ST_NORMAL_MODE =>
				if (TC_timeout = '1') then
					NextState	<= ST_NO_DEVICE;
				end if;

			when ST_NO_DEVICE =>
				NoDevice		<= '1';

				IF RxComReset_i = "01" then
					NextState	<= ST_OOB_RESET;
					TD_load		<= '1';
				end if;

			when ST_OOB_RESET =>

				if (TD_timeout = '1') then
					NextState	<= ST_NEW_DEVICE;
				end if;

			when ST_NEW_DEVICE =>
				NewDevice		<= '1';
				NextState		<= ST_NORMAL_MODE;

		end case;
	end process;

	NO_TC : entity PoC.io_TimingCounter
	generic map ( -- timing table
		TIMING_TABLE => T_NATVEC'(0 => TimingToCycles(NO_DEVICE_TIMEOUT, CLOCK_FREQ))
	)
	port map (
		Clock	=> Clock,
		Enable	=> TC_en,
		Load	=> TC_load,
		Slot	=> 0,
		Timeout	=> TC_timeout
	);

	TC_load <= ElectricalIDLE_i(0) and not ElectricalIDLE_i(1);
	TC_en <= ElectricalIDLE_i(0);

	NEW_TC : entity PoC.io_TimingCounter
	generic map ( -- timing table
		TIMING_TABLE => T_NATVEC'(0 => TimingToCycles(NEW_DEVICE_TIMEOUT, CLOCK_FREQ))
	)
	port map (
		Clock	=> Clock,
		Enable	=> '1',
		Load	=> TD_load,
		Slot	=> 0,
		Timeout	=> TD_timeout
	);

end;
