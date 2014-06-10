-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Testbench:				Tests global constants, functions and settings
--
-- Authors:					Thomas B. Preusser
--									Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		TODO
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

entity config_tb is
end config_tb;


library	PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.simulation.all;


architecture tb of config_tb is
begin
	process
	begin
		report "is simulation?: " & boolean'image(SIMULATION)								severity note;
		report "Vendor:         " & vendor_t'image(VENDOR)									severity note;
		report "Device:         " & device_t'image(DEVICE)									severity note;
		report "Device Number:  " & integer'image(DEVICE_NUMBER)						severity note;
		report "Device Subtype: " & T_DEVICE_SUBTYPE'image(DEVICE_SUBTYPE)	severity note;
		report "Device Series:  " & integer'image(DEVICE_SERIES)						severity note;
		report "--------------------------------------------------"					severity note;
		report "LUT fan-in:     " & integer'image(LUT_FANIN)								severity note;
		report "Transceiver:    " & T_TRANSCEIVER'image(TRANSCEIVER_TYPE)		severity note;


		-- simulation completed
		report "                                                  "					severity note;
		tbPrintResult;
		
		wait;
	end process;
end;
