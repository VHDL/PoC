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

LIBRARY	PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
USE			PoC.io.ALL;
USE			PoC.lcd.ALL;


ENTITY LCDBusController IS
	GENERIC (
		CLOCK_FREQ_MHZ						: REAL													:= 125.0;					-- 125 MHz
--		LCD_BUS_FREQ_KHZ					: REAL													:= 2000.0;				-- 2 MHz
		LCD_BUS_WIDTH							: POSITIVE											:= 4
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		Strobe										: IN	STD_LOGIC;
		ReadWrite									: IN	STD_LOGIC;
		RegisterSelect						: IN	STD_LOGIC;
		
		DataIn										: IN	T_SLV_8;
		DataOut										: OUT	T_SLV_8;
		
		LCD_Enable								: OUT	STD_LOGIC;
		LCD_ReadWrite							: OUT	STD_LOGIC;
		LCD_RegisterSelect				: OUT	STD_LOGIC;
		LCD_Data_i								: IN	STD_LOGIC_VECTOR(LCD_BUS_WIDTH - 1 DOWNTO 0);
		LCD_Data_o								: OUT	STD_LOGIC_VECTOR(LCD_BUS_WIDTH - 1 DOWNTO 0);
		LCD_Data_t								: OUT	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF LCDBusController IS
	ATTRIBUTE KEEP														: BOOLEAN;
	ATTRIBUTE FSM_ENCODING										: STRING;
	
	CONSTANT CLOCK_DUTY_CYCLE									: REAL			:= 0.50;		-- 50% high time
	CONSTANT TIME_CLOCK_HIGH_NS								: REAL			:= 250.0;		--Freq_kHz2Real_ns(LCD_BUS_FREQ_KHZ * 			CLOCK_DUTY_CYCLE);
	CONSTANT TIME_CLOCK_LOW_NS								: REAL			:= 250.0;		--Freq_kHz2Real_ns(LCD_BUS_FREQ_KHZ * (1 - CLOCK_DUTY_CYCLE));

	CONSTANT TIME_SETUP_REGSEL_NS							: REAL			:= 40.0;
	CONSTANT TIME_SETUP_DATA_NS								: REAL			:= 80.0;
	CONSTANT TIME_HOLD_REGSEL_NS							: REAL			:= 10.0;
	CONSTANT TIME_HOLD_DATA_NS								: REAL			:= 10.0;
	CONSTANT TIME_VALID_DATA_NS								: REAL			:= 5.0;
	CONSTANT TIME_DELAY_DATA_NS								: REAL			:= 120.0;

	-- Timing table ID
	CONSTANT TTID_CLOCK_LOW										: NATURAL		:= 0;
	CONSTANT TTID_CLOCK_HIGH									: NATURAL		:= 1;
	CONSTANT TTID_SETUP_REGSEL								: NATURAL		:= 2;
	CONSTANT TTID_SETUP_DATA									: NATURAL		:= 3;
	CONSTANT TTID_HOLD_REGSEL									: NATURAL		:= 4;
	CONSTANT TTID_HOLD_DATA										: NATURAL		:= 5;
	CONSTANT TTID_VALID_DATA									: NATURAL		:= 6;
	CONSTANT TTID_DELAY_DATA									: NATURAL		:= 7;
	
	-- Timing table
	CONSTANT TIMING_TABLE											: T_NATVEC	:= (
		TTID_CLOCK_LOW			=> TimingToCycles_ns(TIME_CLOCK_LOW_NS,			Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_CLOCK_HIGH			=> TimingToCycles_ns(TIME_CLOCK_HIGH_NS,		Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_SETUP_REGSEL		=> TimingToCycles_ns(TIME_SETUP_REGSEL_NS,	Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_SETUP_DATA			=> TimingToCycles_ns(TIME_SETUP_DATA_NS,		Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_HOLD_REGSEL		=> TimingToCycles_ns(TIME_HOLD_REGSEL_NS,		Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_HOLD_DATA			=> TimingToCycles_ns(TIME_HOLD_DATA_NS,			Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_VALID_DATA			=> TimingToCycles_ns(TIME_VALID_DATA_NS,		Freq_MHz2Real_ns(CLOCK_FREQ_MHZ))
		TTID_DELAY_DATA			=> TimingToCycles_ns(TIME_DELAY_DATA_NS,		Freq_MHz2Real_ns(CLOCK_FREQ_MHZ))
	);
	
	-- Bus TimingCounter (BusTC)
	SUBTYPE T_BUSTC_SLOT_INDEX								IS INTEGER RANGE 0 TO TIMING_TABLE'length - 1;

	SIGNAL BusTC_en														: STD_LOGIC;
	SIGNAL BusTC_Load													: STD_LOGIC;
	SIGNAL BusTC_Slot													: T_BUSTC_SLOT_INDEX;
	SIGNAL BusTC_Timeout											: STD_LOGIC;

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
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				Status_d			<= IO_IICBUS_STATUS_ERROR;
			ELSE
				IF (Status_en = '1') THEN
					Status_d		<= Status_nxt;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	BusTC : ENTITY PoC.io_TimingCounter
		GENERIC MAP (
			TIMING_TABLE				=> TIMING_TABLE												-- timing table
		)
		PORT MAP (
			Clock								=> Clock,															-- clock
			Enable							=> BusTC_en,													-- enable counter
			Load								=> BusTC_Load,												-- load Timing Value from TIMING_TABLE selected by slot
			Slot								=> BusTC_Slot,												-- 
			Timeout							=> BusTC_Timeout											-- timing reached
		);	
END;
