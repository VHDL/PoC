-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--                  Patrick Lehmann
--
-- Entity:				 	Converts an AXI4-Stream to PoC.Stream.
--
-- Description:
-- -------------------------------------
-- Converter module for AXI4-Stream to PoC.Stream.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
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
use			IEEE.std_logic_1164.all;

use			work.components.all;


entity AXI4Stream_To_Stream is
	generic (
		DATA_BITS					: positive																								:= 8
	);
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;
		
		-- IN Port
		In_tValid					: in	std_logic;
		In_tData					: in	std_logic_vector(DATA_BITS - 1 downto 0);
		In_tLast					: in	std_logic;
		In_tReady					: out	std_logic;
		
		-- OUT Port
		Out_Valid					: out	std_logic;
		Out_Data					: out	std_logic_vector(DATA_BITS - 1 downto 0);
		Out_SOF						: out	std_logic;
		Out_EOF						: out	std_logic;
		Out_Ack						: in	std_logic
	);
end entity;


architecture rtl of AXI4Stream_To_Stream is
	signal started : std_logic := '0';

begin
	started     <= ffrs(q => started, rst => ((In_tValid and In_tLast) or Reset), set => (In_tValid)) when rising_edge(Clock);
	
	Out_Valid   <= In_tValid;
	Out_Data    <= In_tData;
	Out_SOF     <= In_tValid and not started;
	Out_EOF     <= In_tLast;
	In_tReady   <= Out_Ack;
	
end architecture;
