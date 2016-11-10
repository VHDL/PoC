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
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
use			PoC.xil.all;


entity xil_DRP_BusSync is
	port (
		In_Clock			: in	std_logic;
		In_Enable			: in	std_logic;						--
		In_Address		: in	T_XIL_DRP_ADDRESS;		--
		In_ReadWrite	: in	std_logic;						--
		In_DataIn			: in	T_XIL_DRP_DATA;				--
		In_DataOut		: out	T_XIL_DRP_DATA;				--
		In_Ack				: out	std_logic;						--

		Out_Clock			: in	std_logic;
		Out_Enable		: out	std_logic;						--
		Out_Address		: out	T_XIL_DRP_ADDRESS;		--
		Out_ReadWrite	: out	std_logic;						--
		Out_DataIn		: in	T_XIL_DRP_DATA;				--
		Out_DataOut		: out	T_XIL_DRP_DATA;				--
		Out_Ack				: in	std_logic							--
	);
end entity;


architecture rtl of xil_DRP_BusSync is
	signal syncInToOut_DataIn		: std_logic_vector(T_XIL_DRP_DATA'length + T_XIL_DRP_ADDRESS'length + 1 downto 0);
	signal syncInToOut_DataOut	: std_logic_vector(T_XIL_DRP_DATA'length + T_XIL_DRP_ADDRESS'length + 1 downto 0);

	signal syncOutToIn_DataIn		: std_logic_vector(T_XIL_DRP_DATA'length downto 0);
	signal syncOutToIn_DataOut	: std_logic_vector(T_XIL_DRP_DATA'length downto 0);

	procedure map_sl(vec : inout std_logic_vector; input : in std_logic; lastIndex : inout natural) is
	begin
		vec(lastIndex)	:= input;
		lastIndex				:= lastIndex + 1;
	end procedure;

	procedure map_slv(vec : inout std_logic_vector; input : in std_logic_vector; lastIndex : inout natural) is
	begin
		vec(input'length + lastIndex - 1 downto lastIndex) := input;
		lastIndex := lastIndex + input'length;
	end procedure;

	procedure unmap_sl(vec : inout std_logic_vector; output : out std_logic; lastIndex : inout natural) is
	begin
		output		:= vec(lastIndex);
		lastIndex	:= lastIndex + 1;
	end procedure;

	procedure unmap_slv(vec : inout std_logic_vector; output : out std_logic_vector; lastIndex : inout natural) is
	begin
		output		:= vec(input'length + lastIndex - 1 downto lastIndex);
		lastIndex := lastIndex + input'length;
	end procedure;

	procedure mapInputToVector(vec : inout std_logic_vector; Enable : in std_logic; ReadWrite : in std_logic; Address : in std_logic_vector; Data : in std_logic_vector) is
		variable lastIndex	: natural	:= 0;
	begin
		map_slv(vec, Enable,		lastIndex);
		map_slv(vec, ReadWrite,	lastIndex);
		map_slv(vec, Address,		lastIndex);
		map_slv(vec, Data,			lastIndex);
	end procedure;

	procedure unmapInputToVector(vec : inout std_logic_vector; Enable : out std_logic; ReadWrite : out std_logic; Address : out std_logic_vector; Data : out std_logic_vector) is
		variable lastIndex	: natural	:= 0;
	begin
		unmap_slv(vec, Enable,		lastIndex);
		unmap_slv(vec, ReadWrite,	lastIndex);
		unmap_slv(vec, Address,		lastIndex);
		unmap_slv(vec, Data,			lastIndex);
	end procedure;

	procedure mapOutputToVector(vec : inout std_logic_vector; Ack : in std_logic; Data : in std_logic_vector) is
		variable lastIndex	: natural	:= 0;
	begin
		map_slv(vec, Ack,		lastIndex);
		map_slv(vec, Data,			lastIndex);
	end procedure;

	procedure unmapVectorToOutput(vec : inout std_logic_vector; Ack : out std_logic; Data : out std_logic_vector) is
		variable lastIndex	: natural	:= 0;
	begin
		unmap_slv(vec, Ack,		lastIndex);
		unmap_slv(vec, Data,			lastIndex);
	end procedure;

begin
	mapInputToVector(syncInToOut_DataIn, In_Enable, In_ReadWrite, In_Address, In_DataIn);

	syncInToOut : sync_Vector
		generic map (
			MASTER_BITS					=> 1,
			SLAVE_BITS					=> syncInToOut_DataIn'length - 1,
			INIT								=> x"00000000"
		)
		port map (
			Clock1							=> In_Clock,							-- <Clock>	input clock
			Clock2							=> Out_Clock,							-- <Clock>	output clock
			Input								=> syncInToOut_DataIn,		-- @Clock1:	input vector
			Output							=> syncInToOut_DataOut,		-- @Clock2:	output vector
			Busy								=> open,									-- @Clock1:	busy bit
			Changed							=> Out_Enable							-- @Clock2:	changed bit
		);

	unmapVectorToOutput(syncInToOut_DataOut, open, Out_ReadWrite, Out_Address, Out_DataOut);

	mapOutputToVector(syncOutToIn_DataIn, Out_Ack, Out_DataIn);

	syncOutToIn : sync_Vector
		generic map (
			MASTER_BITS					=> 1,
			SLAVE_BITS					=> syncOutToIn_DataIn'length - 1,
			INIT								=> x"00000000"
		)
		port map (
			Clock1							=> Out_Clock,							-- <Clock>	input clock
			Clock2							=> In_Clock,							-- <Clock>	output clock
			Input								=> syncOutToIn_DataIn,		-- @Clock1:	input vector
			Output							=> syncOutToIn_DataOut,		-- @Clock2:	output vector
			Busy								=> open,									-- @Clock1:	busy bit
			Changed							=> In_Ack									-- @Clock2:	changed bit
		);

	unmapVectorToOutput(syncOutToIn_DataOut, open, In_DataOut);
end architecture;
