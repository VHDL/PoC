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


entity io_PulseWidthModulation is
	generic (
		CLOCK_FREQ								: FREQ									:= 100.0 MHz;
		PWM_FREQ									: FREQ									:= 1.0 kHz;
		PWM_RESOLUTION						: POSITIVE							:= 8
	);
	port (
		Clock				: in	STD_LOGIC;
		Reset				: in	STD_LOGIC;
    PWMIn				: in	STD_LOGIC_VECTOR(PWM_RESOLUTION - 1 downto 0);
		PWMOut			: out	STD_LOGIC
	);
end;


architecture rtl of io_PulseWidthModulation is
	constant PWM_STEPS									: POSITIVE																			:= 2**PWM_RESOLUTION;
	constant PWM_STEP_FREQ							: FREQ																					:= PWM_FREQ * real(PWM_STEPS - 1);
	constant PWM_FREQUENCYCOUNTER_MAX		: POSITIVE																			:= TimingToCycles(to_time(PWM_STEP_FREQ), CLOCK_FREQ);
	constant PWM_FREQUENCYCOUNTER_BITS	: POSITIVE																			:= log2ceilnz(PWM_FREQUENCYCOUNTER_MAX);
	
	signal PWM_FrequencyCounter_us			: UNSIGNED(PWM_FREQUENCYCOUNTER_BITS downto 0)	:= (others => '0');
	signal PWM_FrequencyCounter_ov			: STD_LOGIC;
	signal PWM_PulseCounter_us					: UNSIGNED(PWM_RESOLUTION - 1 downto 0)					:= (others => '0');
	signal PWM_PulseCounter_ov					: STD_LOGIC;
	
BEGIN
	-- PWM frequency counter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') OR (PWM_FrequencyCounter_ov = '1') THEN
				PWM_FrequencyCounter_us		<= (OTHERS => '0');
			ELSE
				PWM_FrequencyCounter_us		<= PWM_FrequencyCounter_us + 1;
			END IF;
		END IF;
	END PROCESS;
	
	PWM_FrequencyCounter_ov	<= to_sl(PWM_FrequencyCounter_us = PWM_FREQUENCYCOUNTER_MAX);
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') OR (PWM_PulseCounter_ov = '1') THEN
				PWM_PulseCounter_us					<= (OTHERS => '0');
			ELSE
				IF (PWM_FrequencyCounter_ov = '1') THEN
					PWM_PulseCounter_us				<= PWM_PulseCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	PWM_PulseCounter_ov <= to_sl(PWM_PulseCounter_us = ((2**PWM_RESOLUTION) - 2)) AND PWM_FrequencyCounter_ov;
	
	PWMOut		<= to_sl(PWM_PulseCounter_us < unsigned(PWMIn));
END;
