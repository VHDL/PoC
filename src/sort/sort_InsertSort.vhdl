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
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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

-- library UNISIM;
-- use			UNISIM.VcomponentS.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;


entity list_lru_systolic is
	generic (
		ELEMENTS									: positive					:= 32;
		KEY_BITS									: positive					:= 16;
		DATA_BITS									: positive					:= 16;
		INSERT_PIPELINE_AFTER			: natural						:= 16
	);
	port (
		Clock											: in	std_logic;
		Reset											: in	std_logic;

		Insert										: in	std_logic;
		DataIn										: in	std_logic_vector(DATA_BITS - 1 downto 0);

		Valid											: out	std_logic;
		DataOut										: out	std_logic_vector(DATA_BITS - 1 downto 0);

		DBG_Data									: out	T_SLM(ELEMENTS - 1 downto 0, DATA_BITS - 1 downto 0);
		DBG_Valids								: out std_logic_vector(ELEMENTS - 1 downto 0)
	);
end entity;


architecture rtl of list_lru_systolic is
	subtype T_KEY					is std_logic_vector(KEY_BITS - 1 downto 0);
	type T_KEY_VECTOR			is array (natural range <>) of T_KEY;

	signal NewKeysUp			: T_KEY_VECTOR(ELEMENTS downto 0);

	signal KeysUp					: T_KEY_VECTOR(ELEMENTS downto 0);
	signal KeysDown				: T_KEY_VECTOR(ELEMENTS downto 0);
	signal ValidsUp				: std_logic_vector(ELEMENTS downto 0);
	signal ValidsDown			: std_logic_vector(ELEMENTS downto 0);

	signal MovesDown			: std_logic_vector(ELEMENTS downto 0);
	signal MovesUp				: std_logic_vector(ELEMENTS downto 0);

	signal DBG_Keys_i			: T_SLM(ELEMENTS - 1 downto 0, KEY_BITS - 1 downto 0)			:= (others => (others => 'Z'));

begin
	-- next element (top)
	KeysDown(ELEMENTS)		<= NewKeysUp(ELEMENTS);
	ValidsDown(ELEMENTS)	<= '1';

	MovesDown(ELEMENTS)		<= Insert;

	-- current element
	genElements : for i in ELEMENTS - 1 downto 0 generate
		constant INITIAL_KEY			: std_logic_vector(KEY_BITS - 1 downto 0)					:= get_row(INITIAL_KEYS, I);
		constant INITIAL_VALID		: std_logic																				:= INITIAL_VALIDS(I);

		signal Key_nxt						: std_logic_vector(KEY_BITS - 1 downto 0);
		signal Key_d							: std_logic_vector(KEY_BITS - 1 downto 0)					:= INITIAL_KEY;
		signal Valid_nxt					: std_logic;
		signal Valid_d						: std_logic																				:= INITIAL_VALID;

		signal Unequal						: std_logic;
		signal MoveDown						: std_logic;
		signal MoveUp							: std_logic;

	begin
		-- local movements
		Unequal				<= to_sl(Key_d /= NewKeysUp(I));

		genXilinx : if VENDOR = VENDOR_XILINX generate
			component MUXCY
				port (
					O			: out	STD_ULOGIC;
					CI		: in	STD_ULOGIC;
					DI		: in	STD_ULOGIC;
					S			: in	STD_ULOGIC
				);
			end component;
		begin
			a : MUXCY
				port map (
					S		=> Unequal,
					CI	=> MovesDown(I + 1),
					DI	=> '0',
					O		=> MovesDown(I)
				);

			b : MUXCY
				port map (
					S		=> Unequal,
					CI	=> MovesUp(I),
					DI	=> '0',
					O		=> MovesUp(I + 1)
				);
		end generate;

		-- movements for the current element
		MoveDown		<= MovesDown(I + 1);
		MoveUp			<= MovesUp(I);

		-- passthrought all new
		NewKeysUp(I + 1)	<= NewKeysUp(I);

		KeysUp(I + 1)			<= Key_d;
		ValidsUp(I + 1)		<= Valid_d;

		-- multiplexer
		Key_nxt						<= ite((MoveDown = '1'), KeysDown(I + 1),		ite((MoveUp = '1'), KeysUp(I),		Key_d));
		Valid_nxt					<= ite((MoveDown = '1'), ValidsDown(I + 1),	ite((MoveUp = '1'), ValidsUp(I), Valid_d));

		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Reset = '1') then
					Key_d				<= INITIAL_KEY;
					Valid_d			<= INITIAL_VALID;
				else
					Key_d				<= Key_nxt;
					Valid_d			<= Valid_nxt;
				end if;
			end if;
		end process;

		KeysDown(I)				<= Key_d;
		ValidsDown(I)			<= Valid_d;

		assign_row(DBG_Keys_i, Key_d, I);

		DBG_Keys					<= DBG_Keys_i;
		DBG_Valids(I)			<= Valid_d;
	end generate;

	-- previous element (buttom)
	NewKeysUp(0)				<= KeyIn;
	MovesUp(0)					<= Invalidate;
	KeysUp(0)						<= KeyIn;
	ValidsUp(0)					<= '0';

	LRU_Key							<= KeysDown(0);
	Valid								<= ValidsDown(0);
end architecture;
