-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	Generic Fan Controller
--
-- Description:
-- -------------------------------------
-- This module generates a PWM signal for a 3-pin (transistor controlled) or
-- 4-pin fan header. The FPGAs temperature is read from device specific system
-- monitors (normal, user temperature, over temperature).
--
-- **For example the Xilinx System Monitors are configured as follows:**
--
-- .. code-block:: none
--
--                    |                      /-----\
--    Temp_ov   on=80 | - - - - - - /-------/       \
--                    |            /        |        \
--    Temp_ov  off=60 | - - - - - / - - - - | - - - - \----\
--                    |          /          |              |\
--                    |         /           |              | \
--    Temp_us   on=35 | -  /---/            |              |  \
--    Temp_us  off=30 | - / - -|- - - - - - |- - - - - - - |- -\------\
--                    |  /     |            |              |           \
--    ----------------|--------|------------|--------------|-----------|--------
--    pwm =           |   min  |  medium    |   max        |   medium  |  min
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
use			IEEE.STD_LOGIC_1164.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.vectors.all;
use			PoC.physical.all;
use			PoC.components.all;
use			PoC.xil.all;


entity xil_SystemMonitor is
	port (
		-- Global Control
		Clock										: in	std_logic;
		Reset										: in	std_logic;

		-- FPGA Temperature values
		Temperature							: out	std_logic_vector(11 downto 0);
		UserTemperature					: out	std_logic;
		OverTemperature					: out	std_logic
  );
end entity;


architecture rtl of xil_SystemMonitor is
	signal UserTemperature_async		: std_logic;
	signal OverTemperature_async		: std_logic;

begin
	-- System Monitor
	-- ==========================================================================================================================================================
	genVirtex6 : if DEVICE = DEVICE_VIRTEX6 generate
		SystemMonitor : xil_SystemMonitor_Virtex6
			port map (
				Reset								=> Reset,										-- Reset signal for the System Monitor control logic

				Alarm_UserTemp			=> UserTemperature_async,		-- Temperature-sensor alarm output
				Alarm_OverTemp			=> OverTemperature_async,		-- Over-Temperature alarm output
				Alarm								=> open,										-- OR'ed output of all the Alarms
				VP									=> '0',											-- Dedicated Analog Input Pair
				VN									=> '0'
			);
	end generate;
	genSeries7 : if DEVICE_SERIES = DEVICE_SERIES7 generate
		SystemMonitor : xil_SystemMonitor_Series7
			port map (
				Reset								=> Reset,										-- Reset signal for the System Monitor control logic

				Alarm_UserTemp			=> UserTemperature_async,		-- Temperature-sensor alarm output
				Alarm_OverTemp			=> OverTemperature_async,		-- Over-Temperature alarm output
				Alarm								=> open,										-- OR'ed output of all the Alarms
				VP									=> '0',											-- Dedicated Analog Input Pair
				VN									=> '0'
			);
	end generate;

	sync : entity PoC.sync_Bits
		generic map (
			BITS			=> 2
		)
		port map (
			Clock				=> Clock,
			Input(0)		=> OverTemperature_async,
			Input(1)		=> UserTemperature_async,
			Output(0)		=> OverTemperature,
			Output(1)		=> UserTemperature
		);
end architecture;
