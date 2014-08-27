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

ENTITY sata_PrimitiveDetector IS
	PORT (
		Clock									: IN	STD_LOGIC;
		
		RX_DataIn							: IN	T_SLV_32;
		RX_CharIsK						: IN	T_SLV_4;
		
		Primitive							: OUT	T_SATA_PRIMITIVE
	);
END;

ARCHITECTURE rtl OF sata_PrimitiveDetector IS
	SIGNAL Primitive_i							: T_SATA_PRIMITIVE;
	
	SIGNAL PrimitiveReg_ctrl_rst		: STD_LOGIC;
	SIGNAL PrimitiveReg_ctrl_set		: STD_LOGIC;
	SIGNAL PrimitiveReg_ctrl				: STD_LOGIC						:= '1';
	SIGNAL PrimitiveReg_en					: STD_LOGIC;
	SIGNAL PrimitiveReg_d						: T_SATA_PRIMITIVE		:= SATA_PRIMITIVE_NONE;

BEGIN
	PROCESS(RX_DataIn, RX_CharIsK)
	BEGIN
		Primitive_i		<= SATA_PRIMITIVE_NONE;
	
		IF (RX_CharIsK = "0000") THEN																																	-- no primitive					=> data word
			Primitive_i <= SATA_PRIMITIVE_NONE;
																																																	--																							K symbol
		ELSIF (RX_CharIsK = "0001") THEN																															-- primitive name				Byte 3	Byte 2	Byte 1	Byte 0
--			Primitive_i	<= to_primitive(RX_DataIn);
--			CASE RX_DataIn IS																																						-- =======================================================
--				WHEN to_slv(SATA_PRIMITIVE_ALIGN) =>			Primitive_i			<= SATA_PRIMITIVE_ALIGN;				-- ALIGN								D27.3,	D10.2,	D10.2,	K28.5
--				WHEN to_slv(SATA_PRIMITIVE_SYNC) =>				Primitive_i			<= SATA_PRIMITIVE_SYNC;					-- SYNC									D21.5,	D21.5,	D21.4,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_SOF) =>				Primitive_i			<= SATA_PRIMITIVE_SOF;					-- SOF									D23.1,	D23.1,	D21.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_EOF) =>				Primitive_i			<= SATA_PRIMITIVE_EOF;					-- EOF									D21.6,	D21.6,	D21.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_HOLD) =>				Primitive_i			<= SATA_PRIMITIVE_HOLD;					-- HOLD									D21.6,	D21.6,	D10.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_HOLD_ACK) =>		Primitive_i			<= SATA_PRIMITIVE_HOLD_ACK;			-- HOLDA								D21.4,	D21.4,	D10.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_CONT) =>				Primitive_i			<= SATA_PRIMITIVE_CONT;					-- CONT									D25.4,	D25.4,	D10.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_R_OK) =>				Primitive_i			<= SATA_PRIMITIVE_R_OK;					-- R_OK									D21.1,	D21.1,	D21.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_R_ERROR) =>		Primitive_i			<= SATA_PRIMITIVE_R_ERROR;			-- R_ERR								D22.2,	D22.2,	D21.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_R_IP) =>				Primitive_i			<= SATA_PRIMITIVE_R_IP;					-- R_IP									D21.2,	D21.2,	D21.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_RX_RDY) =>			Primitive_i			<= SATA_PRIMITIVE_RX_RDY;				-- R_RDY								D10.2,	D10.2,	D21.4,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_TX_RDY) =>			Primitive_i			<= SATA_PRIMITIVE_TX_RDY;				-- X_RDY								D23.2,	D23.2,	D21.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_DMA_TERM) =>		Primitive_i			<= SATA_PRIMITIVE_DMA_TERM;			-- DMAT									D22.1,	D22.1,	D21.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_WAIT_TERM) =>	Primitive_i			<= SATA_PRIMITIVE_WAIT_TERM;		-- WTRM									D24.2,	D24.2,	D21.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_PM_ACK) =>			Primitive_i			<= SATA_PRIMITIVE_PM_ACK;				-- PMACK								D21.4,	D21.4,	D21.4,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_PM_NACK) =>		Primitive_i			<= SATA_PRIMITIVE_PM_NACK;			-- PMNAK								D21.7,	D21.7,	D21.4,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_PM_REQ_P) =>		Primitive_i			<= SATA_PRIMITIVE_PM_REQ_P;			-- PMREQ_P							D23.0,	D23.0,	D21.5,	K28.3
--				WHEN to_slv(SATA_PRIMITIVE_PM_REQ_S) =>		Primitive_i			<= SATA_PRIMITIVE_PM_REQ_S;			-- PMREQ_S							D21.3,	D21.3,	D21.4,	K28.3
--				WHEN OTHERS =>														Primitive_i			<= SATA_PRIMITIVE_ILLEGAL;			-- 
--			END CASE;
			FOR I IN T_SATA_PRIMITIVE LOOP
				IF (RX_DataIn = to_sata_word(I)) THEN
					Primitive_i <= I;
				END IF;
			END LOOP;
		ELSE
			Primitive_i					<= SATA_PRIMITIVE_ILLEGAL;
		END IF;
	END PROCESS;


-- ------------------------------------------------------------------
-- SATA_PRIMITIVE_CONT feature
-- ------------------------------------------------------------------

-- Example waveform
-- """"""""""""""""""""""
-- Primitive_i							< TX_RDY ><  CONT  ><  XXXX  ><  XXXX  >< RX_RDY ><  CONT  ><  XXXX  ><  XXXX  >
-- PrimitiveReg_ctrl_rst		__________""""""""""______________________________""""""""""____________________
-- PrimitiveReg_ctrl_set		""""""""""______________________________""""""""""______________________________
-- PrimitiveReg_ctrl				""""""""""""""""""""______________________________""""""""""____________________
-- PrimitiveReg_en					""""""""""______________________________""""""""""______________________________
-- PrimitiveReg_d						<  ????  >< TX_RDY >< TX_RDY >< TX_RDY >< TX_RDY >< RX_RDY >< RX_RDY >< RX_RDY >
-- Primitive								< TX_RDY >< TX_RDY >< TX_RDY >< TX_RDY >< RX_RDY >< RX_RDY >< RX_RDY >< RX_RDY >


	PrimitiveReg_ctrl_rst		<= to_sl(Primitive_i = SATA_PRIMITIVE_CONT);
	PrimitiveReg_ctrl_set		<= NOT to_sl((Primitive_i = SATA_PRIMITIVE_CONT) OR
																			 (Primitive_i = SATA_PRIMITIVE_ALIGN) OR
																			 (Primitive_i = SATA_PRIMITIVE_NONE) OR
																			 (Primitive_i = SATA_PRIMITIVE_ILLEGAL));
	
	-- PrimitiveReg_ctrl - if CONT ocours disable PrimitiveReg
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (PrimitiveReg_ctrl_rst = '1') THEN
				PrimitiveReg_ctrl		<= '0';
			END IF;
			
			IF (PrimitiveReg_ctrl_set = '1') THEN
				PrimitiveReg_ctrl		<= '1';
			END IF;
		END IF;
	END PROCESS;

	PrimitiveReg_en <= to_sl(((PrimitiveReg_ctrl = '1') OR (PrimitiveReg_ctrl_set = '1')) AND (PrimitiveReg_ctrl_rst = '0'));

	-- PrimitiveReg - save last received primitive
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (PrimitiveReg_en = '1') AND NOT (Primitive_i = SATA_PRIMITIVE_ALIGN) THEN
				PrimitiveReg_d	<= Primitive_i;
			END IF;
		END IF;
	END PROCESS;

	Primitive	<= Primitive_i WHEN (PrimitiveReg_en = '1') ELSE PrimitiveReg_d;
END;
