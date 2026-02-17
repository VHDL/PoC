-- =============================================================================
-- Authors:
--   Patrick Lehmann
--
-- Entity: Pulse Width Modulated (PWM) signal generator
--
-- Description:
-- -------------------------------------
-- This module generates a pulse width modulated signal, that can be configured
-- in frequency (``PWM_FREQ``) and modulation granularity (``PWM_RESOLUTION``).
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
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
use     IEEE.STD_LOGIC_1164.all;
use     IEEE.NUMERIC_STD.all;

use     work.utils.all;
use     work.physical.all;


entity io_PulseWidthModulation is
	generic (
		CLOCK_FREQ     : FREQ     := 100 MHz;
		PWM_FREQ       : FREQ     := 1 kHz;
		PWM_RESOLUTION : positive := 8
	);
	port (
		Clock          : in  std_logic;
		Reset          : in  std_logic;
		PWMIn          : in  unsigned(PWM_RESOLUTION - 1 downto 0);
		PWMOut         : out std_logic
	);
end entity;


architecture rtl of io_PulseWidthModulation is
	constant PWM_STEPS                 : positive                                         := 2**PWM_RESOLUTION;
	constant PWM_STEP_FREQ             : FREQ                                             := PWM_FREQ * (PWM_STEPS - 1);
	constant PWM_FREQUENCYCOUNTER_MAX  : positive                                         := (CLOCK_FREQ + PWM_STEP_FREQ - 1 Hz) / PWM_STEP_FREQ;  -- division with round-up
	constant PWM_FREQUENCYCOUNTER_BITS : positive                                         := log2ceilnz(PWM_FREQUENCYCOUNTER_MAX);

	signal PWM_FrequencyCounter_us     : unsigned(PWM_FREQUENCYCOUNTER_BITS - 1 downto 0) := (others => '0');
	signal PWM_FrequencyCounter_ov     : std_logic;
	signal PWM_PulseCounter_us         : unsigned(PWM_RESOLUTION - 1 downto 0)            := (others => '0');
	signal PWM_PulseCounter_ov         : std_logic;

begin
	-- PWM frequency counter
	process(Clock)
	begin
	if rising_edge(Clock) then
		if (Reset or PWM_FrequencyCounter_ov) = '1' then
			PWM_FrequencyCounter_us <= (others => '0');
		else
			PWM_FrequencyCounter_us <= PWM_FrequencyCounter_us + 1;
		end if;
	end if;
	end process;

	PWM_FrequencyCounter_ov  <= to_sl(PWM_FrequencyCounter_us = PWM_FREQUENCYCOUNTER_MAX - 1);

	process(Clock)
	begin
	if rising_edge(Clock) then
		if (Reset or PWM_PulseCounter_ov) = '1' then
			PWM_PulseCounter_us <= (others => '0');
		elsif PWM_FrequencyCounter_ov = '1' then
			PWM_PulseCounter_us <= PWM_PulseCounter_us + 1;
		end if;
	end if;
	end process;

	PWM_PulseCounter_ov <= to_sl(PWM_PulseCounter_us = ((2**PWM_RESOLUTION) - 1)) and PWM_FrequencyCounter_ov;

	PWMOut <= to_sl(PWM_PulseCounter_us < PWMIn);
end;
