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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;


entity WordAligner is
  generic (
	  REGISTERED		: BOOLEAN			:= FALSE;																					-- add output register @Clock
		INPUT_BITS		: POSITIVE		:= 32;																						-- input/output bitwidth
		WORD_BITS			: POSITIVE		:= 8																							-- word bitwidth
	);
  port (
		Clock					: in	STD_LOGIC;																								-- clock
		Align					: in	STD_LOGIC_VECTOR((INPUT_BITS / WORD_BITS) - 1 downto 0);	-- align word (one-hot code)
		I							: in	STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0);								-- input word
		O							: out STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0);								-- output word
		Valid					: out	STD_LOGIC
	);
end entity;

architecture rtl of WordAligner is
	constant SEGMENT_COUNT	: POSITIVE																	:= INPUT_BITS / WORD_BITS;

	type T_SEGMENTS IS array(NATURAL range <>) OF STD_LOGIC_VECTOR(WORD_BITS - 1 downto 0);

	signal I_d						: STD_LOGIC_VECTOR(I'high downto WORD_BITS)		:= (others => '0');

	signal O_i						: STD_LOGIC_VECTOR(I'range);
	signal Align_d				: STD_LOGIC_VECTOR(Align'range)								:= (0 => '1', others => '0');
	signal Align_i				: STD_LOGIC_VECTOR(Align'range);
	signal Hold						: STD_LOGIC;
	signal Changed				: STD_LOGIC;
	signal Valid_i				: STD_LOGIC;

	signal MuxCtrl				: STD_LOGIC_VECTOR(Align'range);
	signal bin						: INTEGER;


	function onehot2bin(slv : STD_LOGIC_VECTOR) return NATURAL is
	begin
		for i in 0 to slv'length - 1 loop
			if (slv(I) = '1') then
				return I + 1;
			end if;
		end loop;

		return 1;
	end;

	function onehot2muxctrl(slv : STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR is
		variable Result		: STD_LOGIC_VECTOR(slv'range);
		variable Flag			: STD_LOGIC													:= '0';
	begin
		for i in 0 to slv'length - 2 loop
			Flag						:= Flag OR slv(I);
			Result(I)				:= Flag;
		end loop;

		Result(slv'high)	:= '1';

		return Result;
	end;
begin

		I_d				<= I(I_d'range)	when rising_edge(Clock);
		Align_d		<= Align				when rising_edge(Clock) AND (Hold = '0') AND (Changed = '1');

		Hold			<= slv_nor(Align);
		Changed		<= to_sl(Align /= Align_d);
		Valid_i		<= Hold OR Align(Align'low);
		Align_i		<= Align when (Hold = '0') else Align_d;

		O_i		<= I when (Align_i = "01") else I(WORD_BITS - 1 downto 0) & I_d;

	-- add output register @Clock2
	gen11 : if (REGISTERED = TRUE) generate
		O				<= O_i			when rising_edge(Clock);
		Valid		<= Valid_i	when rising_edge(Clock);
	end generate;
	gen12 : if (REGISTERED = FALSE) generate
		O				<= O_i;
		Valid		<= Valid_i;
	end generate;
end;

--	 0 1	0 0
--	4ABC 7B4A 4ABC 7B4A
--			 7B4A 4ABC
--						7B4A 4ABC


