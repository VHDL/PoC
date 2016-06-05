-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.components.all;
use			PoC.xil.all;


entity xil_DRP_BusSync is
	port (
		In_Clock			: in	STD_LOGIC;
		In_Reset			: in	STD_LOGIC;
		In_Enable			: in	STD_LOGIC;																				--
		In_Address		: in	T_XIL_DRP_ADDRESS;																--
		In_ReadWrite	: in	STD_LOGIC;																				--
		In_DataIn			: in	T_XIL_DRP_DATA;																		--
		In_DataOut		: out	T_XIL_DRP_DATA;																		--
		In_Ack				: out	STD_LOGIC;																				--

		Out_Clock			: in	STD_LOGIC;
		Out_Reset			: in	STD_LOGIC;
		Out_Enable		: out	STD_LOGIC;																				--
		Out_Address		: out	T_XIL_DRP_ADDRESS;																--
		Out_ReadWrite	: out	STD_LOGIC;																				--
		Out_DataIn		: in	T_XIL_DRP_DATA;																		--
		Out_DataOut		: out	T_XIL_DRP_DATA;																		--
		Out_Ack				: in	STD_LOGIC																					--
	);
end entity;


architecture rtl of xil_DRP_BusSync is
	signal Reset_1						: STD_LOGIC;
	signal Reset_2						: STD_LOGIC;
	signal Enable_2						: STD_LOGIC;
	signal Ready_1						: STD_LOGIC;

	signal Reg_ReadWrite_1		: STD_LOGIC						:= '0';
	signal Reg_ReadWrite_2		: STD_LOGIC						:= '0';
	signal Reg_Address_1			: T_XIL_DRP_ADDRESS		:= (others => '0');
	signal Reg_Address_2			: T_XIL_DRP_ADDRESS		:= (others => '0');
	signal Reg_DataIn_1				: T_XIL_DRP_DATA			:= (others => '0');
	signal Reg_DataIn_2				: T_XIL_DRP_DATA			:= (others => '0');
	signal Reg_DataOut_1			: T_XIL_DRP_DATA			:= (others => '0');
	signal Reg_DataOut_2			: T_XIL_DRP_DATA			:= (others => '0');

begin
	syncOutClock : entity PoC.sync_Strobe
		generic map (
			BITS				=> 2
		)
		port map (
			Clock1			=> In_Clock,
			Clock2			=> Out_Clock,
			Input(0)		=> In_Reset,
			Input(1)		=> In_Enable,
			Output(0)		=> Reset_2,
			Output(1)		=> Enable_2
		);

	syncInClock : entity PoC.sync_Strobe
		generic map (
			BITS				=> 2
		)
		port map (
			Clock1			=> Out_Clock,
			Clock2			=> In_Clock,
			Input(0)		=> Out_Reset,
			Input(1)		=> Out_Ack,
			Output(0)		=> Reset_1,
			Output(1)		=> Ready_1
		);

	process(In_Clock)
	begin
		if rising_edge(In_Clock) then
			if ((Reset_1 or In_Reset) = '1') then
				Reg_ReadWrite_1		<= '0';
				Reg_Address_1			<= (others => '0');
				Reg_DataOut_1			<= (others => '0');
			elsif (In_Enable = '1') then
				Reg_ReadWrite_1	<= In_ReadWrite;
				Reg_Address_1		<= In_Address;
				Reg_DataOut_1		<= In_DataIn;
			end if;
		end if;
	end process;

	process(Out_Clock)
	begin
		if rising_edge(Out_Clock) then
			if ((Reset_2 or Out_Reset) = '1') then
				Reg_ReadWrite_2		<= '0';
				Reg_Address_2			<= (others => '0');
				Reg_DataOut_2			<= (others => '0');
			elsif (Enable_2 = '1') then
				Reg_ReadWrite_2	<= Reg_ReadWrite_1;
				Reg_Address_2		<= Reg_Address_1;
				Reg_DataOut_2		<= Reg_DataOut_1;
			end if;
		end if;
	end process;

	In_DataOut		<= Reg_DataIn_1;
	In_Ack				<= Ready_1	when rising_edge(In_Clock);

	Out_Enable		<= Enable_2 when rising_edge(Out_Clock);
	Out_ReadWrite	<= Reg_ReadWrite_2;
	Out_Address		<= Reg_Address_2;
	Out_DataOut		<= Reg_DataOut_2;

	process(Out_Clock)
	begin
		if rising_edge(Out_Clock) then
			if ((Reset_2 or Out_Reset) = '1') then
				Reg_DataIn_2			<= (others => '0');
			elsif (Out_Ack = '1') then
				Reg_DataIn_2		<= Out_DataIn;
			end if;
		end if;
	end process;

	process(In_Clock)
	begin
		if rising_edge(In_Clock) then
			if ((Reset_1 or In_Reset) = '1') then
				Reg_DataIn_1			<= (others => '0');
			elsif (Ready_1 = '1') then
				Reg_DataIn_1		<= Reg_DataIn_2;
			end if;
		end if;
	end process;
end;
