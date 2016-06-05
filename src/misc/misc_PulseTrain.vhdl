-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Entity:					TODO
--
-- Description:
-- -------------------------------------
--		This module generates pulse trains. This module was written as a answer for
--		a StackOverflow question: http://stackoverflow.com/questions/25783320
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.components.ALL;


entity misc_PulseTrain is
	generic (
		PULSE_TRAIN				: STD_LOGIC_VECTOR
	);
	port (
		Clock							: in	STD_LOGIC;
		StartSequence			: in	STD_LOGIC;
		SequenceCompleted	: out	STD_LOGIC;
		Output						: out	STD_LOGIC
	);
end entity;


architecture rtl of misc_PulseTrain is
	signal IsIdle_r							: STD_LOGIC																							:= '0';
	signal Counter_us						: UNSIGNED(log2ceilnz(PULSE_TRAIN'length) - 1 downto 0)	:= (others => '0');
	signal Counter_ov						: STD_LOGIC;

begin
	-- state control is done by a basic RS-FF
	IsIdle_r		<= ffrs(q => IsIdle_r, rst => Counter_ov, set => StartSequence)	when rising_edge(Clock);

	-- counter
	Counter_us	<= upcounter_next(cnt => Counter_us, rst => not IsIdle_r)				when rising_edge(Clock);
	Counter_ov	<= upcounter_equal(cnt => Counter_us, value => (PULSE_TRAIN'length - 1));

	Output						<= PULSE_TRAIN(to_index(Counter_us));
	SequenceCompleted	<= Counter_ov;
end architecture;
