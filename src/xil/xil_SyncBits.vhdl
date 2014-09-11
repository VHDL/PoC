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
--		This is a multiple bit clock domain crossing optimized for Xilinx FPGAs.
--		It utilizes two 'FD' instances from UNISIM.VCOMPONENTS. If you need a
--		platform independent version of this Synchronizer, please use
--		'PoC.misc.sync.snyc_Flag', which internally instantiates this module if
--		a Xilinx FPGA is detected.
--		
--		ATTENTION:
--			Only use this synchronizer for long time stable signals (flags).
--
--		CONSTRAINTS:
--			This relative placement of the internal sites is constrained by RLOCs
--		
--			Xilinx ISE:			Please use the provided UCF/XCF file or snippet.
--			Xilinx Vivado:	Please use the provided XDC file with scoped constraints
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

LIBRARY PoC;
USE			PoC.utils.ALL;


ENTITY xil_SyncBits IS
	GENERIC (
		BITS					: POSITIVE						:= 1;									-- number of bit to be synchronized
		INIT					: STD_LOGIC_VECTOR		:= x"00"							-- number of BITS to synchronize
	);
	PORT (
		Clock					: IN	STD_LOGIC;														-- Clock to be synchronized to
		Input					: IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);	-- Data to be synchronized
		Output				: OUT	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)		-- synchronised data
	);
END;


ARCHITECTURE rtl OF xil_SyncBits IS
	ATTRIBUTE TIG							: STRING;
	ATTRIBUTE ASYNC_REG				: STRING;
	ATTRIBUTE SHREG_EXTRACT		: STRING;

	CONSTANT INIT_I						: STD_LOGIC_VECTOR		:= descend(INIT);
BEGIN

	gen : FOR I IN 0 TO BITS - 1 GENERATE
		SIGNAL Data_async				: STD_LOGIC;
		SIGNAL Data_meta				: STD_LOGIC;
		SIGNAL Data_sync				: STD_LOGIC;
	
		-- Mark register Data_async's input as asynchronous and ignore timings (TIG)
		ATTRIBUTE TIG						OF Data_meta	: SIGNAL IS "TRUE";
		ATTRIBUTE ASYNC_REG			OF Data_meta	: SIGNAL IS "TRUE";

		-- Prevent XST from translating two FFs into SRL plus FF
		ATTRIBUTE SHREG_EXTRACT OF Data_meta	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF Data_sync	: SIGNAL IS "NO";
	BEGIN
		Data_async	<= Input(I);
	
		FF1 : FD
			GENERIC MAP (
				INIT		=> to_bit(INIT_I(I))
			)
			PORT MAP (
				C				=> Clock,
				D				=> Data_async,
				Q				=> Data_meta
			);

		FF2 : FD
			GENERIC MAP (
				INIT		=> to_bit(INIT_I(I))
			)
			PORT MAP (
				C				=> Clock,
				D				=> Data_async,
				Q				=> Data_sync
			);
		
		Output(I)		<= Data_sync;
	END GENERATE;
END ARCHITECTURE;
