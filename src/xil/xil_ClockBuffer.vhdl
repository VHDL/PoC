-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	
--
-- Entity:				 	
--
-- Description:
-- -------------------------------------
-- This module wraps a Virtex-6 System Monitor primitive to report if preconfigured
-- temperature values are overrun.
--
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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

Library UNISIM;
use     UNISIM.vcomponents.all;


entity xil_ClockBuffer is
	port (
		Clock_In      : in  std_logic;
		Clock_Enable  : in  std_logic := '1';
		Clock_Out     : out std_logic
	);
end entity;


architecture xilinx of xil_ClockBuffer is
begin
	BUFGCE_inst : BUFGCE
		generic map (
			CE_TYPE => "SYNC",     -- ASYNC, HARDSYNC, SYNC
			IS_CE_INVERTED => '0', -- Programmable inversion on CE
			IS_I_INVERTED => '0'   -- Programmable inversion on I
		)
		port map (
			O => Clock_Out,   -- 1-bit output: Buffer
			CE => Clock_Enable, -- 1-bit input: Buffer enable
			I => Clock_In    -- 1-bit input: Buffer
		);
end architecture;
