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
--		TODO
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
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;


ENTITY Stream_DeMux IS
	GENERIC (
		PORTS											: POSITIVE									:= 2;
		DATA_BITS									: POSITIVE									:= 8;
		META_BITS									: NATURAL										:= 8;
		META_REV_BITS							: NATURAL										:= 2
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		-- Control interface
		DeMuxControl							: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		-- IN Port
		In_Valid									: IN	STD_LOGIC;
		In_Data										: IN	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		In_Meta										: IN	STD_LOGIC_VECTOR(META_BITS - 1 DOWNTO 0);
		In_Meta_rev								: OUT	STD_LOGIC_VECTOR(META_REV_BITS - 1 DOWNTO 0);
		In_SOF										: IN	STD_LOGIC;
		In_EOF										: IN	STD_LOGIC;
		In_Ready									: OUT	STD_LOGIC;
		-- OUT Ports
		Out_Valid									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Out_Data									: OUT	T_SLM(PORTS - 1 DOWNTO 0, DATA_BITS - 1 DOWNTO 0);
		Out_Meta									: OUT	T_SLM(PORTS - 1 DOWNTO 0, META_BITS - 1 DOWNTO 0);
		Out_Meta_rev							: IN	T_SLM(PORTS - 1 DOWNTO 0, META_REV_BITS - 1 DOWNTO 0);
		Out_SOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Out_EOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Out_Ready									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF Stream_DeMux IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	SUBTYPE T_CHANNEL_INDEX IS NATURAL RANGE 0 TO PORTS - 1;
	
	TYPE T_STATE		IS (ST_IDLE, ST_DATAFLOW, ST_DISCARD_FRAME);
	
	SIGNAL State								: T_STATE					:= ST_IDLE;
	SIGNAL NextState						: T_STATE;
	
	SIGNAL Is_SOF								: STD_LOGIC;
	SIGNAL Is_EOF								: STD_LOGIC;
	
	SIGNAL In_Ready_i						: STD_LOGIC;
	SIGNAL Out_Valid_i					: STD_LOGIC;
	SIGNAL DiscardFrame					: STD_LOGIC;
	
	SIGNAL ChannelPointer_rst		: STD_LOGIC;
	SIGNAL ChannelPointer_en		: STD_LOGIC;
	SIGNAL ChannelPointer				: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL ChannelPointer_d			: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)								:= (OTHERS => '0');
	
	SIGNAL ChannelPointer_bin		: UNSIGNED(log2ceilnz(PORTS) - 1 DOWNTO 0);
	SIGNAL idx									: T_CHANNEL_INDEX;
	
	SIGNAL Out_Data_i						: T_SLM(PORTS - 1 DOWNTO 0, DATA_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL Out_Meta_i						: T_SLM(PORTS - 1 DOWNTO 0, META_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
BEGIN
	
	In_Ready_i		<= slv_or(Out_Ready AND ChannelPointer);
	DiscardFrame	<= slv_nor(DeMuxControl);
	
	Is_SOF			<= In_Valid AND In_SOF;
	Is_EOF			<= In_Valid AND In_EOF;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State				<= ST_IDLE;
			ELSE
				State				<= NextState;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(State, In_Ready_i, In_Valid, Is_SOF, Is_EOF, DiscardFrame, DeMuxControl, ChannelPointer_d)
	BEGIN
		NextState									<= State;
		
		ChannelPointer_rst				<= Is_EOF;
		ChannelPointer_en					<= '0';
		ChannelPointer						<= ChannelPointer_d;
		
		In_Ready									<= '0';
		Out_Valid_i								<= '0';
		
		CASE State IS
			WHEN ST_IDLE =>
				ChannelPointer					<= DeMuxControl;

				IF (Is_SOF = '1') THEN
					IF (DiscardFrame = '0') THEN
						ChannelPointer_en		<= '1';
						In_Ready						<= In_Ready_i;
						Out_Valid_i					<= '1';
					
						NextState						<= ST_DATAFLOW;
					ELSE
						In_Ready						<= '1';
						
						NextState						<= ST_DISCARD_FRAME;
					END IF;
				END IF;
			
			WHEN ST_DATAFLOW =>
				In_Ready								<= In_Ready_i;
				Out_Valid_i							<= In_Valid;
				ChannelPointer					<= ChannelPointer_d;
			
				IF (Is_EOF = '1') THEN
					NextState							<= ST_IDLE;
				END IF;
				
			WHEN ST_DISCARD_FRAME =>
				In_Ready								<= '1';
			
				IF (Is_EOF = '1') THEN
					NextState							<= ST_IDLE;
				END IF;
		END CASE;
	END PROCESS;
	
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR ChannelPointer_rst) = '1') THEN
				ChannelPointer_d			<= (OTHERS => '0');
			ELSE
				IF (ChannelPointer_en = '1') THEN
					ChannelPointer_d		<= DeMuxControl;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	ChannelPointer_bin	<= onehot2bin(ChannelPointer_d);
	idx									<= to_integer(ChannelPointer_bin);

	In_Meta_rev				<= get_row(Out_Meta_rev, idx);

	genOutput : FOR I IN 0 TO PORTS - 1 GENERATE
		Out_Valid(I)			<= Out_Valid_i AND ChannelPointer(I);
		assign_row(Out_Data_i, In_Data, I);
		assign_row(Out_Meta_i, In_Meta, I);
		Out_SOF(I)				<= In_SOF;
		Out_EOF(I)				<= In_EOF;
	END GENERATE;
	
	Out_Data		<= Out_Data_i;
	Out_Meta		<= Out_Meta_i;
END ARCHITECTURE;
