-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- ============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	A generic buffer module for the PoC.Stream protocol.
--
-- Description:
-- ------------------------------------
--		This module implements a generic buffer (FifO) for the PoC.Stream protocol.
--		It is generic in DATA_BITS and in META_BITS as well as in FifO depths for
--		data and meta information.
--
-- License:
-- ============================================================================
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
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.stream.all;


entity stream_Sink is
	generic (
		TESTCASES												: T_SIM_STREAM_FRAMEGROUP_VECTOR_8
	);
	port (
		Clock														: in	STD_LOGIC;
		Reset														: in	STD_LOGIC;
		-- Control interface
		Enable													: in	STD_LOGIC;
		Error														: out	STD_LOGIC;
		-- IN Port
		In_Valid												: in	STD_LOGIC;
		In_Data													: in	T_SLV_8;
		In_SOF													: in	STD_LOGIC;
		In_EOF													: in	STD_LOGIC;
		In_Ack													: out	STD_LOGIC
	);
end entity;


architecture rtl of stream_Sink is

begin

	In_Ack			<= '1';-- RX_Valid;

end architecture;
