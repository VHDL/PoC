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
USE			IEEE.STD_LOGIC_1164.ALL;

LIBRARY	L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY	L_IO;
USE			L_IO.IOTypes.ALL;

LIBRARY	L_LCD;
USE			L_LCD.LCDTypes.ALL;


ENTITY LCDBusController IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ					: REAL													:= 125.0;					-- 125 MHz
		CLOCK_OUT_FREQ_KHZ				: REAL													:= 500.0;					-- 500 kHz
		LCD_BUS_WIDTH							: POSITIVE											:= 4
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		Strobe										: IN	STD_LOGIC;
		ReadWrite									: IN	STD_LOGIC;
		
		DataIn										: IN	T_SLV_8;
		DataOut										: OUT	T_SLV_8;
		
		LCD_Clock									: OUT	STD_LOGIC;
		LCD_RegisterSelect				: OUT	STD_LOGIC;
		LCD_ReadWrite							: OUT	STD_LOGIC;
		LCD_Data_i								: IN	STD_LOGIC_VECTOR(LCD_BUS_WIDTH - 1 DOWNTO 0);
		LCD_Data_o								: OUT	STD_LOGIC_VECTOR(LCD_BUS_WIDTH - 1 DOWNTO 0);
		LCD_Data_t								: OUT	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF LCDBusController IS
	ATTRIBUTE KEEP														: BOOLEAN;
	ATTRIBUTE FSM_ENCODING										: STRING;
	
	CONSTANT CLOCK_DUTY_CYCLE									: REAL			:= 0.50;		-- 50% high time
	CONSTANT TIME_CLOCK_HIGH_NS								: REAL			:= Freq_kHz2Real_ns(CLOCK_OUT_FREQ_KHZ * 			CLOCK_DUTY_CYCLE);
	CONSTANT TIME_CLOCK_LOW_NS								: REAL			:= Freq_kHz2Real_ns(CLOCK_OUT_FREQ_KHZ * (1 - CLOCK_DUTY_CYCLE));

	TYPE T_STATE IS (
		ST_INIT,
		ST_IDLE,
		ST_x,
		ST_ERROR
	);
	
	SIGNAL State				: T_STATE						:= ST_INIT;
	SIGNAL NextState		: T_STATE;
	
BEGIN
	ASSERT ((LCD_BUS_WIDTH = 4) OR (LCD_BUS_WIDTH = 8)) REPORT "LCD_BUS_WIDTH is out of range {4,8}" SEVERITY FAILURE;


	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_INIT;
			ELSE
				State			: NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Strobe, ReadWrite)
	BEGIN
		NextState			<= State;
	
		CASE State IS
			WHEN ST_INIT =>
				NULL;
				
			WHEN ST_IDLE =>
				null;
				
			WHEN ST_x =>
				null;
				
			WHEN ST_ERROR =>
				null;
				
					
		END CASE;
	END PROCESS;
	
	
END;
