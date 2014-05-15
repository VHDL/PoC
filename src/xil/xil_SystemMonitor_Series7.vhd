-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
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
-- ============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.all;
USE			IEEE.NUMERIC_STD.all;

LIBRARY	UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;


ENTITY xil_SystemMonitor_Series7 IS
	PORT (
		Reset								: IN	STD_LOGIC;				-- Reset signal for the System Monitor control logic
		
		Alarm_UserTemp			: OUT	STD_LOGIC;				-- Temperature-sensor alarm output
		Alarm_OverTemp			: OUT	STD_LOGIC;				-- Over-Temperature alarm output
		Alarm								: OUT	STD_LOGIC;				-- OR'ed output of all the Alarms
		VP									: IN	STD_LOGIC;				-- Dedicated Analog Input Pair
		VN									: IN	STD_LOGIC
	);
END;


ARCHITECTURE xilinx OF xil_SystemMonitor_Series7 IS

	SIGNAL FLOAT_VCCAUX_ALARM		: STD_LOGIC;
	SIGNAL FLOAT_VCCINT_ALARM		: STD_LOGIC;
	SIGNAL FLOAT_VBRAM_ALARM		: STD_LOGIC;
	SIGNAL FLOAT_MUXADDR				: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL aux_channel_p				: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL aux_channel_n				: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL XADC_Alarm						: STD_LOGIC_VECTOR(7 DOWNTO 0);
begin

	genAUXChannel : FOR I IN 0 TO 15 GENERATE
		aux_channel_p(I) <= '0';
		aux_channel_n(I) <= '0';
	END GENERATE;

	SysMonitor : XADC
		GENERIC MAP (
			INIT_40							=> x"8000",					-- config reg 0
			INIT_41							=> x"8f0c",					-- config reg 1
			INIT_42							=> x"0400",					-- config reg 2
			INIT_48							=> x"0000",					-- Sequencer channel selection
			INIT_49							=> x"0000",					-- Sequencer channel selection
			INIT_4A							=> x"0000",					-- Sequencer Average selection
			INIT_4B							=> x"0000",					-- Sequencer Average selection
			INIT_4C							=> x"0000",					-- Sequencer Bipolar selection
			INIT_4D							=> x"0000",					-- Sequencer Bipolar selection
			INIT_4E							=> x"0000",					-- Sequencer Acq time selection
			INIT_4F							=> x"0000",					-- Sequencer Acq time selection
			INIT_50							=> x"9c87",					-- Temp alarm trigger
			INIT_51							=> x"57e4",					-- Vccint upper alarm limit
			INIT_52							=> x"a147",					-- Vccaux upper alarm limit
			INIT_53							=> x"b363",					-- Temp alarm OT upper
			INIT_54							=> x"99fd",					-- Temp alarm reset
			INIT_55							=> x"52c6",					-- Vccint lower alarm limit
			INIT_56							=> x"9555",					-- Vccaux lower alarm limit
			INIT_57							=> x"a93a",					-- Temp alarm OT reset
			INIT_58							=> x"5999",					-- Vbram upper alarm limit
			INIT_5C							=> x"5111",					-- Vbram lower alarm limit
			SIM_DEVICE					=> "7SERIES",
			SIM_MONITOR_FILE		=> "design.txt"
		)
		PORT MAP (
			-- Control and Clock
			RESET								=> Reset,
			CONVSTCLK						=> '0',
			CONVST							=> '0',
			-- DRP port
			DCLK								=> '0',
			DEN									=> '0',
			DADDR								=> "0000000",
			DWE									=> '0',
			DI									=> x"0000",
			DO									=> OPEN,
			DRDY								=> OPEN,
			-- External analog inputs
			VAUXN								=> aux_channel_n(15 DOWNTO 0),
			VAUXP								=> aux_channel_p(15 DOWNTO 0),
			VN									=> VN,
			VP									=> VP,
			-- Alarms
			OT									=> Alarm_OverTemp,
			ALM									=> XADC_Alarm,
			-- Status
			MUXADDR							=> FLOAT_MUXADDR,
			CHANNEL							=> OPEN,
			BUSY								=> OPEN,
			EOC									=> OPEN,
			EOS									=> OPEN,

			JTAGBUSY						=> OPEN,
			JTAGLOCKED					=> OPEN,
			JTAGMODIFIED				=> OPEN
	 );
	 
	Alarm						<= XADC_Alarm(7);
	Alarm_UserTemp	<= XADC_Alarm(0);
END;
