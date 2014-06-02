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

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.strings.ALL;
--USE			PoC.sata.ALL;


ENTITY sata_TX_CRC32 IS
	PORT (
		Clock				: IN	STD_LOGIC;
		Reset				: IN	STD_LOGIC;

		Valid				: IN	STD_LOGIC;		
		DataIn			: IN	T_SLV_32;
		DataOut			: OUT	T_SLV_32
	);
END;


ARCHITECTURE rtl OF sata_TX_CRC32 IS
	CONSTANT CRC32_POLYNOMIAL		: BIT_VECTOR(35 DOWNTO 0) := x"104C11DB7";
	CONSTANT CRC32_INIT					: T_SLV_32								:= x"52325032";

BEGIN
	CRC : ENTITY PoC.comm_crc
		GENERIC MAP (
			GEN							=> CRC32_POLYNOMIAL(32 DOWNTO 0),		-- Generator Polynom
			BITS						=> 32																-- Number of Bits to be processed in parallel
		)
		PORT MAP (
			clk							=> Clock,														-- Clock
			
			set							=> Reset,														-- Parallel Preload of Remainder
			init						=> CRC32_INIT,											
			step						=> Valid,														-- Process Input Data (MSB first)
			din							=> DataIn,

			rmd							=> DataOut,													-- Remainder
			zero						=> OPEN															-- Remainder is Zero
		);
END;
