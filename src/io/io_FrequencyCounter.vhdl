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
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.physical.ALL;


ENTITY io_FrequencyCounter IS
	GENERIC (
		CLOCK_FREQ								: FREQ									:= 100.0 MHz;
		TIMEBASE									: TIME									:= 1.0 sec;
		RESOLUTION								: POSITIVE							:= 8
	);
	PORT (
		Clock				: IN	STD_LOGIC;
		Reset				: IN	STD_LOGIC;
    FreqIn			: IN	STD_LOGIC;
		FreqOut			: OUT	STD_LOGIC_VECTOR(RESOLUTION - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF io_FrequencyCounter IS
	CONSTANT TIMEBASECOUNTER_MAX				: POSITIVE																		:= TimingToCycles(TIMEBASE, CLOCK_FREQ);
	CONSTANT TIMEBASECOUNTER_BITS				: POSITIVE																		:= log2ceilnz(TIMEBASECOUNTER_MAX);
	CONSTANT REQUENCYCOUNTER_MAX				: POSITIVE																		:= 2**RESOLUTION;
	CONSTANT FREQUENCYCOUNTER_BITS			: POSITIVE																		:= RESOLUTION;
	
	SIGNAL TimeBaseCounter_us						: UNSIGNED(TIMEBASECOUNTER_BITS - 1 DOWNTO 0)	:= (OTHERS => '0');
	SIGNAL TimeBaseCounter_ov						: STD_LOGIC;
	SIGNAL FrequencyCounter_us					: UNSIGNED(FREQUENCYCOUNTER_BITS DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL FrequencyCounter_ov					: STD_LOGIC;
	
	SIGNAL FreqIn_d											: STD_LOGIC																		:= '0';
	SIGNAL FreqIn_re										: STD_LOGIC;
	
	SIGNAL FreqOut_d										: STD_LOGIC_VECTOR(RESOLUTION - 1 DOWNTO 0)		:= (OTHERS => '0');
BEGIN

	FreqIn_d	<= FreqIn WHEN rising_edge(Clock);
	FreqIn_re	<= NOT FreqIn_d AND FreqIn;

	-- timebase counter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') OR (TimeBaseCounter_ov = '1') THEN
				TimeBaseCounter_us		<= (OTHERS => '0');
			ELSE
				TimeBaseCounter_us		<= TimeBaseCounter_us + 1;
			END IF;
		END IF;
	END PROCESS;
	
	TimeBaseCounter_ov	<= to_sl(TimeBaseCounter_us = TIMEBASECOUNTER_MAX);
	
	-- frequency counter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') OR (TimeBaseCounter_ov = '1') THEN
				FrequencyCounter_us		<= (OTHERS => '0');
			ELSE
				IF (FrequencyCounter_ov = '0') AND (FreqIn_re = '1') THEN
					FrequencyCounter_us		<= FrequencyCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	FrequencyCounter_ov	<= FrequencyCounter_us(FrequencyCounter_us'high);
	
	-- hold counter value until next TimeBaseCounter event
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				FreqOut_d			<= (OTHERS => '0');
			ELSE
				IF (TimeBaseCounter_ov = '1') THEN
					IF (FrequencyCounter_ov = '1') THEN
						FreqOut_d	<= (OTHERS => '1');
					ELSE
						FreqOut_d	<= std_logic_vector(FrequencyCounter_us(FreqOut_d'range));
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	FreqOut		<= FreqOut_d;
END;
