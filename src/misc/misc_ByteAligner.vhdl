-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	Word alignment for dependent clocks
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
use			PoC.utils.all;
use			PoC.components.all;


entity misc_ByteAligner is
  generic (
	  REGISTERED	: boolean			:= FALSE;																				-- add output register @Clock
		WORD_BITS		: positive		:= 32;																					--
		BYTE_BITS		: positive		:= 8																						--
	);
  port (
		Clock				: in	std_logic;																							-- clock
		In_Align		: in	std_logic_vector((WORD_BITS / BYTE_BITS) - 1 downto 0);	-- align word (one-hot coded)
		In_Data			: in	std_logic_vector(WORD_BITS - 1 downto 0);								-- input word
--		Out_Align		: in	std_logic_vector((WORD_BITS / BYTE_BITS) - 1 downto 0);	-- align word (one-hot coded)
		Out_Data		: out std_logic_vector(WORD_BITS - 1 downto 0)								-- output word
	);
end entity;


architecture rtl of misc_ByteAligner is
	type T_DATA is array(integer range <>) of std_logic_vector(BYTE_BITS - 1 downto 0);
	constant SEGMENTS	: positive		:= WORD_BITS / BYTE_BITS;

	signal Align_d		: std_logic_vector(In_Align'range)				:= (0 => '1', others => '0');
	signal Changed		: std_logic;

	signal Data				: T_DATA(SEGMENTS - 1 downto 0);
	signal Data_d			: T_DATA(SEGMENTS - 1 downto 1)						:= (others => (others => '0'));
	signal Align_bin	: unsigned(log2ceilnz(SEGMENTS) - 1 downto 0);

	signal MuxOut			: T_DATA(SEGMENTS - 1 downto 0);
	signal Out_Data_i	: std_logic_vector(In_Data'range);

begin
	assert ((WORD_BITS mod BYTE_BITS) = 0) report "WORD_BITS must be a multiple of BYTE_BITS." severity FAILURE;

	Align_d			<= ffdre(q => Align_d, d => In_Align, en => Changed)	when rising_edge(Clock);
	Changed			<= to_sl(In_Align /= Align_d);
	Align_bin		<= onehot2bin(Align_d);

	genData : for i in 1 to SEGMENTS - 1 generate
		Data_d(i)	<= In_Data((BYTE_BITS * i) + BYTE_BITS - 1 downto (BYTE_BITS * i))	when rising_edge(Clock);
	end generate;
	genBytes : for i in 0 to SEGMENTS - 1 generate
		signal MuxIn				: T_DATA(SEGMENTS - 1 downto 0);
	begin
		Data(i)		<= In_Data((BYTE_BITS * i) + BYTE_BITS - 1 downto (BYTE_BITS * i));

		genMux : for j in 0 to SEGMENTS - 1 generate
			constant k	: integer := i - j;
		begin
			MuxIn(j)	<= ite((k >= 0), Data(bound(k, Data'low, Data'high)), Data_d(bound((SEGMENTS + k), Data_d'low, Data_d'high)));
		end generate;

		MuxOut(i)	<= MuxIn(to_integer(Align_bin));

		Out_Data_i((BYTE_BITS * i) + BYTE_BITS - 1 downto (BYTE_BITS * i))	<= MuxOut(i);
	end generate;

	-- optional output registers
	genOutReg0 : if not REGISTERED generate
--		Out_Align	<= (0 => '1', others => '0');
		Out_Data	<= Out_Data_i;
	end generate;
	genOutReg1 : if REGISTERED generate
		Out_Data	<= Out_Data_i	when rising_edge(Clock);
	end generate;
end architecture;
