-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		This is a clock domain crossing for reset signals optimized for Xilinx
--		FPGAs. It utilizes two 'FDP' instances from UNISIM.VCOMPONENTS. If you
--		need a platform independent version of this Synchronizer, please use
--		'PoC.misc.sync.sync_Reset', which internally instantiates this module if
--		a Xilinx FPGA is detected.
--		
--		ATTENTION:
--			Only use this synchronizer for reset signals.
--
--		CONSTRAINTS:
--			This relative placement of the internal sites is constrained by RLOCs
--		
--			Xilinx ISE UCF or XCF file:
--				NET "*_async"		TIG;
--				INST "*_meta"		TNM = "METASTABILITY_FFS";
--				TIMESPEC "TS_MetaStability" = FROM FFS TO "METASTABILITY_FFS" TIG;
--			
--			Xilinx Vivado xdc file:
--				TODO
--				TODO
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

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;


ENTITY xil_SyncReset IS
	PORT (
		Clock				: IN	STD_LOGIC;					-- clock to be sync'ed to
		Input				: IN	STD_LOGIC;					-- Active high asynchronous reset
		Output			: OUT	STD_LOGIC						-- "Synchronised" reset signal ()
	);
END;


ARCHITECTURE rtl OF xil_SyncReset IS
	ATTRIBUTE ASYNC_REG											: STRING;
	ATTRIBUTE SHREG_EXTRACT									: STRING;

	SIGNAL Reset_async											: STD_LOGIC;
	SIGNAL Reset_meta												: STD_LOGIC;
	SIGNAL Reset_sync												: STD_LOGIC;

	-- Mark register "Reset_meta" and "Output" as asynchronous
	ATTRIBUTE ASYNC_REG OF Reset_meta				: SIGNAL IS "TRUE";
	ATTRIBUTE ASYNC_REG OF Reset_sync				: SIGNAL IS "TRUE";

	-- Prevent XST from translating two FFs into SRL plus FF
	ATTRIBUTE SHREG_EXTRACT OF Reset_meta		: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF Reset_sync		: SIGNAL IS "NO";

BEGIN

	Reset_async		<= Input;

	FF1 : FDP
		GENERIC MAP (
			INIT		=> '1'
		)
		PORT MAP (
			C				=> Clock,
			PRE			=> Reset_async,
			D				=> '0',
			Q				=> Reset_meta
	);

	FF2 : FDP
		GENERIC MAP (
			INIT		=> '1'
		)
		PORT MAP (
			C				=> Clock,
			PRE			=> Reset_async,
			D				=> Reset_meta,
			Q				=> Reset_sync
	);

	Output	<= Reset_sync;
END;
