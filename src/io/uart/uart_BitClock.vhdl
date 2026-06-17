-- =============================================================================
-- Authors:           Martin Zabel
--                  Patrick Lehmann
--
-- Entity:           UART bit clock / baud rate generator
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- old comments:
--   :abbr:`UART (Universal Asynchronous Receiver Transmitter)` BAUD rate generator
--   bclk_r    = bit clock is rising
--   bclk_x8_r = bit clock times 8 is rising
--
--
-- License:
-- =============================================================================
-- Copyright 2008-2015 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.strings.all;
use     work.physical.all;
use     work.components.all;
use     work.uart.all;


entity uart_BitClock is
	generic (
		CLOCK_FREQ        : FREQ := 100 MHz;    -- XXX: FREQ and BAUD ?
		BAUDRATE          : BAUD := 115200 Bd;  -- FIXME: add oversampling factor
		OVERSAMPLING_RATE : positive  := 8
	);
	port (
		Clock       : in  std_logic;
		Reset       : in  std_logic;

		BitClock    : out std_logic;
		SampleClock : out std_logic
	);
end entity;


architecture rtl of uart_BitClock is
	constant TIME_UNIT_INTERVAL               : T_TIME            := 1.0 / (to_real(BAUDRATE, 1 Bd) * real(OVERSAMPLING_RATE));
	constant BAUDRATE_COUNTER_MAX             : positive          := TimingToCycles(TIME_UNIT_INTERVAL, CLOCK_FREQ);
	constant BAUDRATE_COUNTER_BITS            : positive          := log2ceilnz(BAUDRATE_COUNTER_MAX + 1);

	-- registers
	signal x8_cnt : unsigned(BAUDRATE_COUNTER_BITS - 1 downto 0)  := (others => '0');
	signal x1_cnt : unsigned(2 downto 0)                          := (others => '0');

	-- control signals
	signal x8_cnt_done : std_logic;
	signal x1_cnt_done : std_logic;

	signal bclk_r       : std_logic    := '0';
	signal bclk_x8_r    : std_logic    := '0';
begin
	assert FALSE    -- LF works in QuartusII
		report "uart_bclk:" & LF &
					 "  CLOCK_FREQ="    & to_string(CLOCK_FREQ, 3) & LF &
					 "  BAUDRATE="      & to_string(BAUDRATE, 3) & LF &
					 "  COUNTER_MAX="    & integer'image(BAUDRATE_COUNTER_MAX) & LF &
					 "  COUNTER_BITS="  & integer'image(BAUDRATE_COUNTER_BITS)
		severity NOTE;

	assert io_UART_IsTypicalBaudRate(BAUDRATE)
		report "The baudrate " & to_string(BAUDRATE, 3) & " is not known to be a typical baudrate!"
		severity WARNING;

	x8_cnt      <= upcounter_next(cnt => x8_cnt, rst => (Reset or x8_cnt_done)) when rising_edge(Clock);
	x8_cnt_done     <= upcounter_equal(cnt => x8_cnt, value => BAUDRATE_COUNTER_MAX - 1);

	x1_cnt          <= upcounter_next(cnt => x1_cnt, rst => Reset, en => x8_cnt_done) when rising_edge(Clock);
	x1_cnt_done     <= comp_allzero(x1_cnt);

	-- outputs
	-- ---------------------------------------------------------------------------
	-- only x8_cnt_done is pulsed for one clock cycle!
	bclk_r      <= (x1_cnt_done and x8_cnt_done)  when rising_edge(Clock);
	bclk_x8_r    <= x8_cnt_done                      when rising_edge(Clock);

	BitClock            <= bclk_r;
	SampleClock      <= bclk_x8_r;
end architecture;
