-- =============================================================================
-- Authors:
--
--
-- Entity:
--
-- Description:
-- -------------------------------------
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.physical.all;
use     work.utils.all;
use     work.clock.all;


entity clock_HighResolution is
	generic (
		SECOND_RESOLUTION   : T_SECOND_RESOLUTION := MILLISECONDS;
		CLOCK_FREQUENCY     : FREQ
	);
	port (
		Clock               : in std_logic;
		Reset               : in std_logic;

		Load_nanoseconds    : in std_logic;
		Load_datetime       : in std_logic;
		Nanoseconds_to_load : in unsigned(63 downto 0);
		Datetime_to_load    : in T_CLOCK_Datetime;
		Ns_inc              : in std_logic;
		Ns_dec              : in std_logic;

		Nanoseconds         : out unsigned(63 downto 0);
		Datetime            : out T_CLOCK_Datetime
	);
end entity;


architecture rtl of clock_HighResolution is

	signal counter_ns : Nanoseconds'subtype := (others => '0');
	signal secTick    : std_logic;
	signal minTick    : std_logic;
	signal hourTick   : std_logic;
	signal dayTick    : std_logic;
	signal monthTick  : std_logic;
	signal yearTick   : std_logic;

begin
	nanoSecTimer: entity work.clock_Timer
		generic map (
			CLOCK_FREQ => CLOCK_FREQUENCY,
			TIME_BASE  => 1.0e-9,
			WRAP_TIME  => 0.0,
			CLOCK_BITS => Nanoseconds_to_load'length
		)
		port map (
			Clock        => Clock,
			Reset        => Reset,
			Increment    => Ns_inc,
			Decrement    => Ns_dec,
			Load         => Load_nanoseconds,
			Time_to_load => Nanoseconds_to_load,
			Current_time => counter_ns,
			Overflow     => open
		);

	Nanoseconds <= counter_ns;

	secTimer: entity work.clock_Timer
		generic map (
			CLOCK_FREQ => CLOCK_FREQUENCY,
			TIME_BASE  => to_timebase(SECOND_RESOLUTION),
			WRAP_TIME  => 1.0,
			CLOCK_BITS => 32
		)
		port map (
			Clock        => Clock,
			Reset        => Reset,
			Increment    => '0',  -- not connected
			Decrement    => '0',  -- not connected
			Load         => Load_datetime,
			Time_to_load => (31 downto 0 => '0'),
			Current_time => Datetime.secondsResolution,
			Overflow     => secTick
		);

	secTime: entity work.clock_Counter
		generic map (
			MODULO        => 60,
			BITS          => Datetime.seconds'length
		)
		port map (
			Clock         => Clock,
			Reset         => Reset,
			Enable        => secTick,
			Load          => Load_datetime,

			LoadValue     => Datetime_to_load.seconds,
			Value         => Datetime.seconds,
			WrapAround    => minTick
		);

	minTime: entity work.clock_Counter
		generic map (
			MODULO        => 60,
			BITS          => Datetime.minutes'length
		)
		port map (
			Clock         => Clock,
			Reset         => Reset,
			Enable        => minTick,
			Load          => Load_datetime,

			LoadValue     => Datetime_to_load.minutes,
			Value         => Datetime.minutes,
			WrapAround    => hourTick
		);

	hourTime: entity work.clock_Counter
		generic map (
			MODULO        => 24,
			BITS          => Datetime.hours'length
		)
		port map (
			Clock         => Clock,
			Reset         => Reset,
			Enable        => hourTick,
			Load          => Load_datetime,

			LoadValue     => Datetime_to_load.hours,
			Value         => Datetime.hours,
			WrapAround    => dayTick
		);

	dayTime: entity work.clock_Counter
		generic map (
			MODULO        => 31,
			BITS          => Datetime.day'length
		)
		port map (
			Clock         => Clock,
			Reset         => Reset,
			Enable        => dayTick,
			Load          => Load_datetime,

			LoadValue     => Datetime_to_load.day,
			Value         => Datetime.day,
			WrapAround    => monthTick
		);

	monthTime: entity work.clock_Counter
		generic map (
			MODULO        => 12,
			BITS          => Datetime.month'length
		)
		port map (
			Clock         => Clock,
			Reset         => Reset,
			Enable        => monthTick,
			Load          => Load_datetime,

			LoadValue     => Datetime_to_load.month,
			Value         => Datetime.month,
			WrapAround    => yearTick
		);

	yearTime: entity work.clock_Counter
		generic map (
			MODULO        => 8192,
			BITS          => Datetime.year'length
		)
		port map (
			Clock         => Clock,
			Reset         => Reset,
			Enable        => yearTick,
			Load          => Load_datetime,

			LoadValue     => Datetime_to_load.year,
			Value         => Datetime.year,
			WrapAround    => open
		);
end architecture;
