-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- ============================================================================
-- Entity:				 	TODO
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


ENTITY misc_StrobeLimiter IS
	GENERIC (
		MIN_STROBE_PERIOD_CYCLES		: POSITIVE		:= 16;
		INITIAL_LOCKED							: BOOLEAN			:= FALSE;
		INITIAL_STROBE							: BOOLEAN			:= TRUE--;
--		REGISTERED_OUTPUT						: BOOLEAN			:= FALSE			-- TODO:
	);
	PORT (
		Clock				: IN	STD_LOGIC;
		I						:	IN	STD_LOGIC;
		O						: OUT	STD_LOGIC
	);
end entity;


ARCHITECTURE rtl OF misc_StrobeLimiter IS
	CONSTANT COUNTER_INIT_VALUE		: POSITIVE		:= MIN_STROBE_PERIOD_CYCLES - 2;
	CONSTANT COUNTER_BITS					: NATURAL			:= log2ceilnz(COUNTER_INIT_VALUE);

	TYPE T_STATE IS (ST_IDLE, ST_LOCKED, ST_LOCKED2);

	FUNCTION InitialState(InitialLocked : BOOLEAN; InitialStrobe : BOOLEAN) RETURN T_STATE IS
	BEGIN
		IF (InitialLocked = TRUE) THEN
			IF (InitialStrobe = TRUE) THEN
				RETURN ST_LOCKED2;
			ELSE
				RETURN ST_LOCKED;
			END IF;
		ELSE
			RETURN ST_IDLE;
		END IF;
	END;

	SIGNAL State						: T_STATE					:= InitialState(INITIAL_LOCKED, INITIAL_STROBE);
	SIGNAL NextState				: T_STATE;

	SIGNAL Counter_en				: STD_LOGIC;
	SIGNAL Counter_s				: SIGNED(COUNTER_BITS DOWNTO 0)		:= to_signed(COUNTER_INIT_VALUE, COUNTER_BITS + 1);
	SIGNAL Counter_ov				: STD_LOGIC;

BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			State <= NextState;
		END IF;
	END PROCESS;

	PROCESS(State, I, Counter_ov)
	BEGIN
		NextState							<= State;

		Counter_en						<= '0';
		O											<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				IF (I = '1') THEN
					O								<= '1';

					NextState				<= ST_LOCKED;
				END IF;

			WHEN ST_LOCKED =>
				Counter_en				<= '1';

				IF (I = '1') THEN
					IF (Counter_ov = '1') THEN
						Counter_en		<= '0';
						O							<= '1';
					ELSE
						NextState			<= ST_LOCKED2;
					END IF;
				ELSE
					IF (Counter_ov = '1') THEN
						NextState			<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_LOCKED2 =>
				Counter_en				<= '1';

				IF (I = '1') THEN
					IF (Counter_ov = '1') THEN
						Counter_en		<= '0';
						O							<= '1';
					END IF;
				ELSE
					IF (Counter_ov = '1') THEN
						O							<= '1';
						NextState			<= ST_IDLE;
					END IF;
				END IF;

		END CASE;
	END PROCESS;

	-- counter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Counter_en = '0') THEN
				Counter_s		<= to_signed(COUNTER_INIT_VALUE, Counter_s'length);
			ELSE
				Counter_s	<= Counter_s - 1;
			END IF;
		END IF;
	END PROCESS;

	Counter_ov <= Counter_s(Counter_s'high);

END;
