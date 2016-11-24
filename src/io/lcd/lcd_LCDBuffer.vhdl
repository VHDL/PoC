-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

library	PoC;
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.io.all;
use			PoC.lcd.all;


entity lcd_LCDBuffer is
	generic (
		CLOCK_FREQ						: FREQ				:= 100 MHz;
		MIN_REFRESH_PERIOD		: time				:= 100 ms
	);
	port (
		Clock				: in	std_logic;
		Reset				: in	std_logic;

		Load				: in	std_logic;
		LCDBuffer		:	in	T_LCD;

		CharColumn	:	in	T_LCD_COLUMN_INDEX;
		CharRow			: in	T_LCD_ROW_INDEX;
		Char				: out	T_LCD_CHAR
	);
end entity;


architecture rtl of lcd_LCDBuffer is
	signal LCDBuffer_Load		: std_logic;
	signal LCDBuffer_d			: T_LCD			:= (others => (others => to_RawChar(' ')));

begin
	SL : entity PoC.misc_StrobeLimiter
		generic map (
			MIN_STROBE_PERIOD_CYCLES	=> TimingToCycles(MIN_REFRESH_PERIOD,	CLOCK_FREQ),
			INITIAL_LOCKED						=> FALSE,
			INITIAL_STROBE						=> TRUE
		)
		port map (
			Clock											=> Clock,
			I													=> Load,
			O													=> LCDBuffer_Load
		);

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				LCDBuffer_d			<= (others => (others => to_RawChar(' ')));
			else
				if (LCDBuffer_Load = '1') then
					LCDBuffer_d		<= LCDBuffer;
				end if;
			end if;
		end if;
	end process;

	Char <= to_LCD_CHAR2(LCDBuffer_d(CharRow)(CharColumn));
end;
