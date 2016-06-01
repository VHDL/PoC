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
USE			PoC.strings.ALL;
use			PoC.physical.all;
USE			PoC.io.ALL;
USE			PoC.lcd.ALL;


ENTITY lcd_LCDBuffer IS
	GENERIC (
		CLOCK_FREQ						: FREQ				:= 100 MHz;
		MIN_REFRESH_PERIOD		: T_TIME			:= 100.0e-3
	);
	PORT (
		Clock				: IN	STD_LOGIC;
		Reset				: IN	STD_LOGIC;
		
		Load				: IN	STD_LOGIC;
		LCDBuffer		:	IN	T_LCD;
		
		CharColumn	:	IN	T_LCD_COLUMN_INDEX;
		CharRow			: IN	T_LCD_ROW_INDEX;
		Char				: OUT	T_LCD_CHAR
	);
END;

ARCHITECTURE rtl OF lcd_LCDBuffer IS
	SIGNAL LCDBuffer_Load		: STD_LOGIC;
	SIGNAL LCDBuffer_d			: T_LCD			:= (OTHERS => (OTHERS => to_RawChar(' ')));
	
BEGIN
	SL : ENTITY PoC.misc_StrobeLimiter
		GENERIC MAP (
			MIN_STROBE_PERIOD_CYCLES	=> TimingToCycles(MIN_REFRESH_PERIOD,	CLOCK_FREQ),
			INITIAL_LOCKED						=> FALSE,
			INITIAL_STROBE						=> TRUE
		)
		PORT MAP (
			Clock											=> Clock,
			I													=> Load,
			O													=> LCDBuffer_Load
		);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				LCDBuffer_d			<= (OTHERS => (OTHERS => to_RawChar(' ')));
			ELSE
				IF (LCDBuffer_Load = '1') THEN
					LCDBuffer_d		<= LCDBuffer;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Char <= to_LCD_CHAR2(LCDBuffer_d(CharRow)(CharColumn));
END;
