-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Module:				 	TODO
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
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
-- ============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;


entity Stream_Mux is
	generic (
		PORTS											: POSITIVE									:= 2;
		DATA_BITS									: POSITIVE									:= 8;
		META_BITS									: NATURAL										:= 8;
		META_REV_BITS							: NATURAL										:= 2--;
--		WEIGHTS										: T_INTVEC									:= (1, 1)
	);
	port (
		Clock											: in	STD_LOGIC;
		Reset											: in	STD_LOGIC;
		-- IN Ports
		In_Valid									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		In_Data										: in	T_SLM(PORTS - 1 downto 0, DATA_BITS - 1 downto 0);
		In_Meta										: in	T_SLM(PORTS - 1 downto 0, META_BITS - 1 downto 0);
		In_Meta_rev								: out	T_SLM(PORTS - 1 downto 0, META_REV_BITS - 1 downto 0);
		In_SOF										: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		In_EOF										: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		In_Ack										: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		-- OUT Port
		Out_Valid									: out	STD_LOGIC;
		Out_Data									: out	STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
		Out_Meta									: out	STD_LOGIC_VECTOR(META_BITS - 1 downto 0);
		Out_Meta_rev							: in	STD_LOGIC_VECTOR(META_REV_BITS - 1 downto 0);
		Out_SOF										: out	STD_LOGIC;
		Out_EOF										: out	STD_LOGIC;
		Out_Ack										: in	STD_LOGIC
	);
end;


architecture rtl OF Stream_Mux is
	attribute KEEP										: BOOLEAN;
	attribute FSM_ENCODING						: STRING;

	subtype T_CHANNEL_INDEX is NATURAL range 0 to PORTS - 1;
	
	type T_STATE is (ST_IDLE, ST_DATAFLOW);
	
	signal State											: T_STATE					:= ST_IDLE;
	signal NextState									: T_STATE;
	
	signal FSM_Dataflow_en						: STD_LOGIC;
	
	signal RequestVector							: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal RequestWithSelf						: STD_LOGIC;
	signal RequestWithoutSelf					: STD_LOGIC;
	
	signal RequestLeft								: UNSIGNED(PORTS - 1 downto 0);
	signal SelectLeft									: UNSIGNED(PORTS - 1 downto 0);
	signal SelectRight								: UNSIGNED(PORTS - 1 downto 0);
	
	signal ChannelPointer_en					: STD_LOGIC;
	signal ChannelPointer							: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal ChannelPointer_d						: STD_LOGIC_VECTOR(PORTS - 1 downto 0)						:= to_slv(2 ** (PORTS - 1), PORTS);
	signal ChannelPointer_nxt					: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal ChannelPointer_bin					: UNSIGNED(log2ceilnz(PORTS) - 1 downto 0);
	
	signal idx												: T_CHANNEL_INDEX;
	
	signal Out_EOF_i									: STD_LOGIC;
	
begin
	RequestVector				<= In_Valid AND In_SOF;
	RequestWithSelf			<= slv_or(RequestVector);
	RequestWithoutSelf	<= slv_or(RequestVector AND NOT ChannelPointer_d);

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State				<= ST_IDLE;
			else
				State				<= NextState;
			end if;
		end if;
	end process;
	
	process(State, RequestWithSelf, RequestWithoutSelf, Out_Ack, Out_EOF_i, ChannelPointer_d, ChannelPointer_nxt)
	begin
		NextState									<= State;
		
		FSM_Dataflow_en						<= '0';
		
		ChannelPointer_en					<= '0';
		ChannelPointer						<= ChannelPointer_d;
		
		case State is
			when ST_IDLE =>
				if (RequestWithSelf = '1') then
					ChannelPointer_en		<= '1';
					
					NextState						<= ST_DATAFLOW;
				end if;
			
			when ST_DATAFLOW =>
				FSM_Dataflow_en				<= '1';
			
				if ((Out_Ack	 AND Out_EOF_i) = '1') then
					if (RequestWithoutSelf = '0') then
						NextState					<= ST_IDLE;
					else
						ChannelPointer_en	<= '1';
					end if;
				end if;
		end case;
	end process;
	
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				ChannelPointer_d			<= to_slv(2 ** (PORTS - 1), PORTS);
			elsif (ChannelPointer_en = '1') then
				ChannelPointer_d		<= ChannelPointer_nxt;
			end if;
		end if;
	end process;

	RequestLeft					<= (NOT ((unsigned(ChannelPointer_d) - 1) OR unsigned(ChannelPointer_d))) AND unsigned(RequestVector);
	SelectLeft					<= (unsigned(NOT RequestLeft) + 1)		AND RequestLeft;
	SelectRight					<= (unsigned(NOT RequestVector) + 1)	AND unsigned(RequestVector);
	ChannelPointer_nxt	<= std_logic_vector(ite((RequestLeft = (RequestLeft'range => '0')), SelectRight, SelectLeft));
	
	ChannelPointer_bin	<= onehot2bin(ChannelPointer);
	idx									<= to_integer(ChannelPointer_bin);
	
	Out_Data						<= get_row(In_Data, idx);
	Out_Meta						<= get_row(In_Meta, idx);
	
	Out_SOF							<= In_SOF(to_integer(ChannelPointer_bin));
	Out_EOF_i						<= In_EOF(to_integer(ChannelPointer_bin));
	Out_Valid						<= In_Valid(to_integer(ChannelPointer_bin)) and FSM_Dataflow_en;
	Out_EOF							<= Out_EOF_i;
	
	In_Ack							<= (In_Ack	'range => (Out_Ack	 and FSM_Dataflow_en)) AND ChannelPointer;

	genMetaReverse_0 : if (META_REV_BITS = 0) generate
		In_Meta_rev		<= (others => (others => '0'));
	end generate;
	genMetaReverse_1 : if (META_REV_BITS > 0) generate
		signal Temp_Meta_rev : T_SLM(PORTS - 1 downto 0, META_REV_BITS - 1 downto 0)		:= (others => (others => 'Z'));
	begin
		genAssign : for i in 0 to PORTS - 1 generate
			signal row	: STD_LOGIC_VECTOR(META_REV_BITS - 1 downto 0);
		begin
			row		<= Out_Meta_rev AND (row'range => ChannelPointer(I));
			assign_row(Temp_Meta_rev, row, i);
		end generate;
		In_Meta_rev		<= Temp_Meta_rev;
	end generate;
end architecture;
