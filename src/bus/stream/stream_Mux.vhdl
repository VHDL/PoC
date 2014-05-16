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


ENTITY Stream_Mux IS
	GENERIC (
		PORTS											: POSITIVE									:= 2;
		DATA_BITS									: POSITIVE									:= 8;
		META_BITS									: NATURAL										:= 8;
		META_REV_BITS							: NATURAL										:= 2--;
--		WEIGHTS										: T_INTVEC									:= (1, 1)
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		-- IN Ports
		In_Valid									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		In_Data										: IN	T_SLM(PORTS - 1 DOWNTO 0, DATA_BITS - 1 DOWNTO 0);
		In_Meta										: IN	T_SLM(PORTS - 1 DOWNTO 0, META_BITS - 1 DOWNTO 0);
		In_Meta_rev								: OUT	T_SLM(PORTS - 1 DOWNTO 0, META_REV_BITS - 1 DOWNTO 0);
		In_SOF										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		In_EOF										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		In_Ready									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		-- OUT Port
		Out_Valid									: OUT	STD_LOGIC;
		Out_Data									: OUT	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		Out_Meta									: OUT	STD_LOGIC_VECTOR(META_BITS - 1 DOWNTO 0);
		Out_Meta_rev							: IN	STD_LOGIC_VECTOR(META_REV_BITS - 1 DOWNTO 0);
		Out_SOF										: OUT	STD_LOGIC;
		Out_EOF										: OUT	STD_LOGIC;
		Out_Ready									: IN	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF Stream_Mux IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	SUBTYPE T_CHANNEL_INDEX IS NATURAL RANGE 0 TO PORTS - 1;
	
	TYPE T_STATE IS (ST_IDLE, ST_DATAFLOW);
	
	SIGNAL State											: T_STATE					:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	
	SIGNAL RequestVector							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL RequestWithSelf						: STD_LOGIC;
	SIGNAL RequestWithoutSelf					: STD_LOGIC;
	
	SIGNAL RequestLeft								: UNSIGNED(PORTS - 1 DOWNTO 0);
	SIGNAL SelectLeft									: UNSIGNED(PORTS - 1 DOWNTO 0);
	SIGNAL SelectRight								: UNSIGNED(PORTS - 1 DOWNTO 0);
	
	SIGNAL ChannelPointer_en					: STD_LOGIC;
	SIGNAL ChannelPointer							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL ChannelPointer_d						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)						:= to_slv(2 ** (PORTS - 1), PORTS);
	SIGNAL ChannelPointer_nxt					: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL ChannelPointer_bin					: UNSIGNED(log2ceilnz(PORTS) - 1 DOWNTO 0);
	
	SIGNAL idx												: T_CHANNEL_INDEX;
	
	SIGNAL Out_EOF_i									: STD_LOGIC;
	
BEGIN
	
	RequestVector				<= In_Valid AND In_SOF;
	RequestWithSelf			<= slv_or(RequestVector);
	RequestWithoutSelf	<= slv_or(RequestVector AND NOT ChannelPointer_d);

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
	
	PROCESS(State, RequestWithSelf, RequestWithoutSelf, Out_Ready, Out_EOF_i, ChannelPointer_d, ChannelPointer_nxt)
	BEGIN
		NextState									<= State;
		
		ChannelPointer_en					<= '0';
		ChannelPointer						<= ChannelPointer_d;
		
		CASE State IS
			WHEN ST_IDLE =>
				IF (RequestWithSelf = '1') THEN
					ChannelPointer_en		<= '1';
					
					NextState						<= ST_DATAFLOW;
				END IF;
			
			WHEN ST_DATAFLOW =>
				IF ((Out_Ready AND Out_EOF_i) = '1') THEN
					IF (RequestWithoutSelf = '0') THEN
						NextState					<= ST_IDLE;
					ELSE
						ChannelPointer_en	<= '1';
					END IF;
				END IF;
		END CASE;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				ChannelPointer_d			<= to_slv(2 ** (PORTS - 1), PORTS);
			ELSE
				IF (ChannelPointer_en = '1') THEN
					ChannelPointer_d		<= ChannelPointer_nxt;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	RequestLeft					<= (NOT ((unsigned(ChannelPointer_d) - 1) OR unsigned(ChannelPointer_d))) AND unsigned(RequestVector);
	SelectLeft					<= (unsigned(NOT RequestLeft) + 1)		AND RequestLeft;
	SelectRight					<= (unsigned(NOT RequestVector) + 1)	AND unsigned(RequestVector);
	ChannelPointer_nxt	<= std_logic_vector(ite((RequestLeft = (RequestLeft'range => '0')), SelectRight, SelectLeft));
	
	ChannelPointer_bin	<= onehot2bin(ChannelPointer);
	idx									<= to_integer(ChannelPointer_bin);
--	ASSERT idx < PORTS REPORT INTEGER'image(idx) SEVERITY ERROR;
	
	Out_Data						<= get_row(In_Data, idx);
	Out_Meta						<= get_row(In_Meta, idx);
	
	Out_SOF							<= In_SOF(to_integer(ChannelPointer_bin));
	Out_EOF_i						<= In_EOF(to_integer(ChannelPointer_bin));
	Out_Valid						<= In_Valid(to_integer(ChannelPointer_bin));
	Out_EOF							<= Out_EOF_i;
	
	In_Ready						<= (In_Ready'range => Out_Ready) AND ChannelPointer;

	genMetaReverse_0 : IF (META_REV_BITS = 0) GENERATE
		In_Meta_rev		<= (OTHERS => (OTHERS => '0'));
	END GENERATE;
	genMetaReverse_1 : IF (META_REV_BITS > 0) GENERATE
		SIGNAL Temp_Meta_rev : T_SLM(PORTS - 1 DOWNTO 0, META_REV_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));
	BEGIN
		genAssign : FOR I IN 0 TO PORTS - 1 GENERATE
			SIGNAL row	: STD_LOGIC_VECTOR(META_REV_BITS - 1 DOWNTO 0);
		BEGIN
			row		<= Out_Meta_rev AND (row'range => ChannelPointer(I));
			assign_row(Temp_Meta_rev, row, I);
		END GENERATE;
		In_Meta_rev		<= Temp_Meta_rev;
	END GENERATE;
	
END ARCHITECTURE;
