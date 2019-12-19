-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Max Kraft-Kugler
--                  Stefan Unrein
--
-- Entity:          Creates a histogram of all input data
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;


entity stat_Histogram_auto_boundary is
	generic (
		RESOLUTION_BITS     : positive    :=  4;
		COUNTER_BITS        : positive    := 16
	);
	port (
		Clock               : in  std_logic;
		Reset               : in  std_logic;

		Enable              : in  std_logic;
		DataIn              : in  std_logic_vector;
		window_bounds_upper : in  unsigned;
		window_bounds_lower : in  unsigned;

		Histogram           : out T_SLM
	);
end entity;

architecture rtl of stat_Histogram_auto_boundary is
	constant NUM_OF_BUCKETS  : natural := Histogram'length(1);
	constant COUNTER_BITS    : natural := Histogram'length(2);
	constant BUCKET_BITS     : natural := log2ceil(NUM_OF_BUCKETS);
	constant DATA_BITS       : natural := DataIn'length;

	signal buckets           : std_logic_vector(BUCKET_BITS - 1 downto 0);

	signal window_width     : natural(DATA_BITS - 1 downto 0);
	signal window_steps     : natural(DATA_BITS - 1 downto 0);

	signal window_width_reg : natural(DATA_BITS - 1 downto 0) := (others => '0');
	signal window_steps_reg : natural(DATA_BITS - 1 downto 0) := (others => '0');

	signal window_changed  : std_logic;

begin
	-- todo check window_bounds_upper/lower DATA_BITS via assert
	
	window_width <= window_bounds_upper - window_bounds_lower;
	window_steps <= window_width/NUM_OF_BUCKETS; -- TODO check how this will be implemented by the synthesis tool!!!!!!!

	process(Clock) is
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				window_width_reg <= (others => '0');
				window_steps_reg <= (others => '0');
			else
				window_width_reg <= window_width;
				window_steps_reg <= window_steps;
			end if;
		end if;
	end process;
	-- automatically detect window change:
	window_changed <= '0' when (window_width_reg = window_width) and (window_steps_reg = window_steps) else '1';

	-- re-resolve buckets depending on window resolution and boundary:
	process(DataIn, window_steps, window_bounds_lower) is
	begin
		--default to lowest bucket:
		buckets <= (others => '0');
		assign_buckets : for bucket_n in 1 to NUM_OF_BUCKETS - 1 loop
			-- check for highest bucket it differently:
			if (bucket_n = NUM_OF_BUCKETS - 1) then
				--check if datum is above highest bucket's threshhold
				if DataIn >= ((bucket_n*window_steps) + window_bounds_lower) then
					buckets <= std_logic_vector(to_unsigned(bucket_n, buckets'length));
				end if;
			else
				--check if datum is between this and next bucket's threshhold
				if (DataIn >= ((bucket_n*window_steps) + window_bounds_lower)) and (DataIn < (((bucket_n + 1 )*window_steps) + window_bounds_lower)) then
					buckets <= std_logic_vector(to_unsigned(bucket_n, buckets'length));
				end if;
			end if;
		end loop;
	end process;

	histogram_inst : entity PoC.stat_Histogram
		generic map(
			DATA_BITS     => BUCKET_BITS,
			COUNTER_BITS  => COUNTER_BITS
		)
		port map(
			Clock         => Clock,
			Reset         => Reset or window_changed, -- reset on window change
			Enable        => Enable,
			DataIn        => buckets,
			Histogram     => Histogram
		);

end architecture;