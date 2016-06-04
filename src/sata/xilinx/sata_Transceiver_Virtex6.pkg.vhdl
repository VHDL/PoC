-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- ============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- ------------------------------------
-- .. TODO:: No documentation available.
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


package SATATransceiverTypes is
	type T_SATA_TRANSCEIVER_COMMON_SIGNALS is record
		RefClockIn_75_MHz			: STD_LOGIC;
		RefClockIn_150_MHz		: STD_LOGIC;
	end record;

	type T_SATA_TRANSCEIVER_PRIVATE_SIGNALS is record
		TX_n									: STD_LOGIC;
		TX_p									: STD_LOGIC;
		RX_n									: STD_LOGIC;
		RX_p									: STD_LOGIC;
	end record;

	type T_SATA_TRANSCEIVER_PRIVATE_SIGNALS_VECTOR is array(NATURAL range <>) of T_SATA_TRANSCEIVER_PRIVATE_SIGNALS;

end package;
