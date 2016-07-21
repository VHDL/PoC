-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Entity:					Primtive Detector for SATA Link Layer
--
-- Description:
-- -------------------------------------
-- Detects primitives in the incoming data stream from the physical link. If
-- a primitive X is continued via the CONT primitive and scrambled dummy data,
-- this unit outputs X continously until a new primitve (except ALIGN) arrives.
--
-- License:
-- =============================================================================
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
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.components.all;
use			PoC.sata.all;


entity sata_PrimitiveDetector is
	port (
		Clock									: in	std_logic;

		RX_DataIn							: in	T_SLV_32;
		RX_CharIsK						: in	T_SLV_4;

		Primitive							: out	T_SATA_PRIMITIVE
	);
end entity;

-- Example waveform
-- """"""""""""""""""""""
-- Primitive_i							< TX_RDY ><  CONT  ><  XXXX  ><  XXXX  >< RX_RDY ><  CONT  ><  XXXX  ><  XXXX  >
-- PrimitiveReg_ctrl_rst		__________""""""""""______________________________""""""""""____________________
-- PrimitiveReg_ctrl_set		""""""""""______________________________""""""""""______________________________
-- PrimitiveReg_ctrl				""""""""""""""""""""______________________________""""""""""____________________
-- PrimitiveReg_en					""""""""""______________________________""""""""""______________________________
-- PrimitiveReg_d						<  ????  >< TX_RDY >< TX_RDY >< TX_RDY >< TX_RDY >< RX_RDY >< RX_RDY >< RX_RDY >
-- Primitive								< TX_RDY >< TX_RDY >< TX_RDY >< TX_RDY >< RX_RDY >< RX_RDY >< RX_RDY >< RX_RDY >

architecture rtl of sata_PrimitiveDetector is
	signal Primitive_i							: T_SATA_PRIMITIVE;

	signal PrimitiveReg_ctrl_rst		: std_logic;
	signal PrimitiveReg_ctrl_set		: std_logic;
	signal PrimitiveReg_ctrl				: std_logic						:= '1';
	signal PrimitiveReg_en					: std_logic;
	signal PrimitiveReg_d						: T_SATA_PRIMITIVE		:= SATA_PRIMITIVE_NONE;

begin
	Primitive_i		<= to_sata_primitive(RX_DataIn, RX_CharIsK);

	-- ===========================================================================
	-- SATA_PRIMITIVE_CONT feature
	-- ===========================================================================
	-- PrimitiveReg_ctrl - if CONT ocours -> disable PrimitiveReg
	PrimitiveReg_ctrl_rst		<= to_sl(Primitive_i = SATA_PRIMITIVE_CONT);
	PrimitiveReg_ctrl_set		<= not to_sl((Primitive_i = SATA_PRIMITIVE_CONT) or
																			 (Primitive_i = SATA_PRIMITIVE_ALIGN) or
																			 (Primitive_i = SATA_PRIMITIVE_NONE) or
																			 (Primitive_i = SATA_PRIMITIVE_ILLEGAL));

	PrimitiveReg_ctrl	<= ffsr(q => PrimitiveReg_ctrl, rst => PrimitiveReg_ctrl_rst, set => PrimitiveReg_ctrl_set) when rising_edge(Clock);
	PrimitiveReg_en		<= (PrimitiveReg_ctrl or PrimitiveReg_ctrl_set) and not PrimitiveReg_ctrl_rst;

	-- PrimitiveReg - save last received primitive
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (PrimitiveReg_en = '1') and not (Primitive_i = SATA_PRIMITIVE_ALIGN) then
				PrimitiveReg_d	<= Primitive_i;
			end if;
		end if;
	end process;

	Primitive	<= Primitive_i when (PrimitiveReg_en = '1') else PrimitiveReg_d;
end architecture;
