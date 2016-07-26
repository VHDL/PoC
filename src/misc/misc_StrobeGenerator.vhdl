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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.components.all;


entity misc_StrobeGenerator is
	generic (
		STROBE_PERIOD_CYCLES	: positive		:= 16;
		INITIAL_STROBE				: boolean			:= TRUE
	);
	port (
		Clock		: in	std_logic;
		O				: out	std_logic
	);
end entity;


architecture rtl of misc_StrobeGenerator is
	constant COUNTER_INIT_VALUE	: positive		:= STROBE_PERIOD_CYCLES - 2;
	constant COUNTER_BITS				: natural			:= log2ceilnz(COUNTER_INIT_VALUE + 1);

	signal Counter_s						: signed(COUNTER_BITS downto 0)		:= to_signed(ite(INITIAL_STROBE, -1, COUNTER_INIT_VALUE), COUNTER_BITS + 1);
	signal Counter_neg					: std_logic;

begin
	Counter_s		<= downcounter_next(cnt => Counter_s, rst => Counter_neg, en => '1', INIT => COUNTER_INIT_VALUE) when rising_edge(Clock);
	Counter_neg	<= downcounter_neg(cnt => Counter_s);
	O						<= Counter_neg;
end;
