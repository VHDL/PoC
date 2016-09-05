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
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;


entity misc_StrobeLimiter is
	generic (
		MIN_STROBE_PERIOD_CYCLES		: positive		:= 16;
		INITIAL_LOCKED							: boolean			:= FALSE;
		INITIAL_STROBE							: boolean			:= TRUE--;
--		REGISTERED_OUTPUT						: BOOLEAN			:= FALSE			-- TODO:
	);
	port (
		Clock				: in	std_logic;
		I						:	in	std_logic;
		O						: out	std_logic
	);
end entity;


architecture rtl of misc_StrobeLimiter is
	constant COUNTER_INIT_VALUE		: positive		:= MIN_STROBE_PERIOD_CYCLES - 2;
	constant COUNTER_BITS					: natural			:= log2ceilnz(COUNTER_INIT_VALUE);

	type T_STATE is (ST_IDLE, ST_LOCKED, ST_LOCKED2);

	function InitialState(InitialLocked : boolean; InitialStrobe : boolean) return T_STATE is
	begin
		if InitialLocked then
			if InitialStrobe then
				return ST_LOCKED2;
			else
				return ST_LOCKED;
			end if;
		else
			return ST_IDLE;
		end if;
	end;

	signal State						: T_STATE					:= InitialState(INITIAL_LOCKED, INITIAL_STROBE);
	signal NextState				: T_STATE;

	signal Counter_en				: std_logic;
	signal Counter_s				: signed(COUNTER_BITS downto 0)		:= to_signed(COUNTER_INIT_VALUE, COUNTER_BITS + 1);
	signal Counter_ov				: std_logic;

begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			State <= NextState;
		end if;
	end process;

	process(State, I, Counter_ov)
	begin
		NextState							<= State;

		Counter_en						<= '0';
		O											<= '0';

		case State is
			when ST_IDLE =>
				if (I = '1') then
					O								<= '1';

					NextState				<= ST_LOCKED;
				end if;

			when ST_LOCKED =>
				Counter_en				<= '1';

				if (I = '1') then
					if (Counter_ov = '1') then
						Counter_en		<= '0';
						O							<= '1';
					else
						NextState			<= ST_LOCKED2;
					end if;
				else
					if (Counter_ov = '1') then
						NextState			<= ST_IDLE;
					end if;
				end if;

			when ST_LOCKED2 =>
				Counter_en				<= '1';

				if (I = '1') then
					if (Counter_ov = '1') then
						Counter_en		<= '0';
						O							<= '1';
					end if;
				else
					if (Counter_ov = '1') then
						O							<= '1';
						NextState			<= ST_IDLE;
					end if;
				end if;

		end case;
	end process;

	-- counter
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Counter_en = '0') then
				Counter_s		<= to_signed(COUNTER_INIT_VALUE, Counter_s'length);
			else
				Counter_s	<= Counter_s - 1;
			end if;
		end if;
	end process;

	Counter_ov <= Counter_s(Counter_s'high);

end;
