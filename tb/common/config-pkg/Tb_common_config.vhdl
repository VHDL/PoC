-- =============================================================================
-- Authors:          Patrick Lehmann
--
-- Testbench:        Tests global constants, functions and settings
--
-- Description:
-- ------------------------------------
--    Converted to OSVVM style.
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

library PoC;
use     PoC.config.all;
use     PoC.utils.all;

library osvvm;
context osvvm.OsvvmContext;


entity Tb_common_config is
end entity;


architecture tb of Tb_common_config is
	constant TestName : string := "Tb_common_config";
begin

	ControlProc : process
	begin
		SetTestName(TestName);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		Log("NOTE: This is a mechanically converted old-style testbench and needs a proper OSVVM port.", INFO);

		Log("is simulation?:    " & boolean'image(SIMULATION));
		Log("Vendor:            " & T_VENDOR'image(VENDOR));
		Log("Device:            " & T_DEVICE'image(DEVICE));
		Log("Device Family:     " & T_DEVICE_FAMILY'image(DEVICE_FAMILY));
		Log("Device Subtype:    " & T_DEVICE_SUBTYPE'image(DEVICE_SUBTYPE));
		Log("Device Series:     " & T_DEVICE_SERIES'image(DEVICE_SERIES));
		Log("Device Generation: " & integer'image(DEVICE_GENERATION));
		Log("Device Number:     " & integer'image(DEVICE_NUMBER));
		Log("LUT fan-in:        " & integer'image(LUT_FANIN));
		Log("Transceiver:       " & T_TRANSCEIVER'image(TRANSCEIVER_TYPE));

		AffirmIf(SIMULATION = TRUE,                        "SIMULATION="         & boolean'image(SIMULATION)              & "    Expected=TRUE");
		AffirmIf(VENDOR = VENDOR_GENERIC,                  "VENDOR= "            & T_VENDOR'image(VENDOR)                 & "    Expected=VENDOR_GENERIC");
		AffirmIf(DEVICE = DEVICE_GENERIC,                  "DEVICE="             & T_DEVICE'image(DEVICE)                 & "    Expected=DEVICE_GENERIC");
		AffirmIf(DEVICE_FAMILY = DEVICE_FAMILY_GENERIC,    "DEVICE_FAMILY="      & T_DEVICE_FAMILY'image(DEVICE_FAMILY)   & "    Expected=DEVICE_FAMILY_GENERIC");
		AffirmIf(DEVICE_NUMBER = 0,                        "DEVICE_NUMBER="      & integer'image(DEVICE_NUMBER)           & "    Expected=0");
		AffirmIf(DEVICE_SUBTYPE = DEVICE_SUBTYPE_GENERIC,  "DEVICE_SUBTYPE="     & T_DEVICE_SUBTYPE'image(DEVICE_SUBTYPE) & "    Expected=DEVICE_SUBTYPE_GENERIC");
		AffirmIf(DEVICE_GENERATION = 0,                    "DEVICE_GENERATION="  & integer'image(DEVICE_GENERATION)       & "    Expected=0");
		AffirmIf(DEVICE_SERIES = DEVICE_SERIES_GENERIC,    "DEVICE_SERIES="      & T_DEVICE_SERIES'image(DEVICE_SERIES)   & "    Expected=DEVICE_SERIES_GENERIC");
		AffirmIf(LUT_FANIN = 6,                            "LUT_FANIN="          & integer'image(LUT_FANIN)               & "    Expected=6");
		AffirmIf(TRANSCEIVER_TYPE = TRANSCEIVER_GENERIC,   "TRANSCEIVER_TYPE="   & T_TRANSCEIVER'image(TRANSCEIVER_TYPE)  & "    Expected=TRANSCEIVER_GENERIC");

		EndOfTestReports;
		std.env.stop;
		wait;
	end process;
end architecture;
