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
USE			PoC.sata.ALL;


ENTITY sata_PrimitiveMux IS
	GENERIC (
		DEBUG									: BOOLEAN					:= FALSE
	);
	PORT (
		Primitive							: IN	T_SATA_PRIMITIVE;
		
		TX_DataIn							: IN	T_SLV_32;
		TX_DataOut						: OUT	T_SLV_32;
		TX_CharIsK						: OUT T_SATA_CIK
	);
END;


ARCHITECTURE rtl OF sata_PrimitiveMux IS
	ATTRIBUTE KEEP						: BOOLEAN;
	ATTRIBUTE FSM_ENCODING		: STRING;
	
BEGIN
	-- PrimitiveROM
	PROCESS(Primitive, TX_DataIn)
	BEGIN
		TX_DataOut		<= TX_DataIn;
		TX_CharIsK		<= "0000";

		CASE Primitive IS
			WHEN SATA_PRIMITIVE_NONE =>							-- no primitive					passthrough data word
				TX_DataOut		<= TX_DataIn;
				TX_CharIsK		<= "0000";

			WHEN SATA_PRIMITIVE_ILLEGAL =>
				REPORT "illegal PRIMTIVE" SEVERITY FAILURE;

			WHEN OTHERS =>													-- Send Primitive
				TX_DataOut		<= to_slv(Primitive);		-- access ROM
				TX_CharIsK		<= "0001";							-- mark primitive with K-symbols
		
		END CASE;
	END PROCESS;


	-- ================================================================
	-- ChipScope
	-- ================================================================
	genCSP : IF (DEBUG = TRUE) GENERATE
		SIGNAL CSP_Primitive_NONE			: STD_LOGIC;
		
		ATTRIBUTE KEEP OF CSP_Primitive_NONE				: SIGNAL IS TRUE;
	BEGIN
		CSP_Primitive_NONE		<= to_sl(Primitive = SATA_PRIMITIVE_NONE);
	END GENERATE;
END;
