-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.strings.ALL;
--USE			PoC.sata.ALL;


ENTITY sata_AddressCalculation IS
	GENERIC (
		LOGICAL_BLOCK_SIZE_ldB						: NATURAL
	);
	PORT (
		Clock															: IN	STD_LOGIC;
		Reset															: IN	STD_LOGIC;

		Address_AppLB											: IN	T_SLV_48;
		BlockCount_AppLB									: IN	T_SLV_48;

		IDF_DriveInformation							: IN T_DRIVE_INFORMATION;

		Address_DevLB											: OUT	T_SLV_48;
		BlockCount_DevLB									: OUT	T_SLV_48
	);
END;

ARCHITECTURE rtl OF sata_AddressCalculation IS
	CONSTANT SHIFT_WIDTH								: POSITIVE				:= 16;

	SIGNAL Shift_us											: UNSIGNED(log2ceil(SHIFT_WIDTH) DOWNTO 0);
	
	TYPE T_SHIFTED											IS ARRAY(NATURAL RANGE <>) OF T_SLV_48;
	SIGNAL Address_AppLB_Shifted				: T_SHIFTED(SHIFT_WIDTH - 1 DOWNTO 0);
	SIGNAL BlockCount_AppLB_Shifted			: T_SHIFTED(SHIFT_WIDTH - 1 DOWNTO 0);
BEGIN
	Shift_us											<= to_unsigned(LOGICAL_BLOCK_SIZE_ldB - to_integer(to_01(IDF_DriveInformation.LogicalBlockSize_ldB)), Shift_us'length);

	Address_AppLB_Shifted(0)			<= Address_AppLB;
	BlockCount_AppLB_Shifted(0)		<= BlockCount_AppLB;
	
	genShifted : FOR I IN 1 TO SHIFT_WIDTH - 1 GENERATE
		Address_AppLB_Shifted(I)		<= Address_AppLB(Address_AppLB'high - I DOWNTO 0)			& (I - 1 DOWNTO 0 => '0');
		BlockCount_AppLB_Shifted(I)	<= BlockCount_AppLB(Address_AppLB'high - I DOWNTO 0)	& (I - 1 DOWNTO 0 => '0');
	END GENERATE;
	
	Address_DevLB 		<= Address_AppLB_Shifted(to_integer(to_01(Shift_us, '0')));
	BlockCount_DevLB	<= BlockCount_AppLB_Shifted(to_integer(to_01(Shift_us, '0')));
END;
