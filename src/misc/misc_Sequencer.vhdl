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
--use			PoC.vectors.all;


entity misc_Sequencer is
  generic (
	  INPUT_BITS					: POSITIVE					:= 32;
		OUTPUT_BITS					: POSITIVE					:= 8;
		REGISTERED					: BOOLEAN						:= FALSE
	);
  port (
	  Clock								: in	STD_LOGIC;
		Reset								: in	STD_LOGIC;

		Input								: in	STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0);
		rst									:	IN	STD_LOGIC;
		rev									:	IN	STD_LOGIC;
		nxt									:	IN	STD_LOGIC;
		Output							: out STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0)
	);
end entity;


architecture rtl of misc_Sequencer is
	constant CHUNKS				: POSITIVE := div_ceil(INPUT_BITS, OUTPUT_BITS);
	constant COUNTER_BITS	: POSITIVE := log2ceilnz(CHUNKS);

	subtype T_CHUNK				IS STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);
	TYPE		T_MUX					IS array (NATURAL range <>) OF T_CHUNK;

	signal Mux_Data				: T_MUX(CHUNKS - 1 downto 0);
	signal Mux_Data_d			: T_MUX(CHUNKS - 1 downto 0);
	signal Mux_sel_us			: UNSIGNED(COUNTER_BITS - 1 downto 0)		:= (others => '0');

	signal rev_l					: STD_LOGIC															:= '0';

begin
	genMuxData : for i in 0 to CHUNKS - 1 generate
		Mux_Data(I)		<= Input(((I + 1) * OUTPUT_BITS) - 1 downto I * OUTPUT_BITS);
	end generate;

	genRegistered0 : if (REGISTERED = TRUE) generate
		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Reset = '1') then
					Mux_Data_d		<= (others => (others => '0'));
				else
					Mux_Data_d		<= Mux_Data;
				end if;
			end if;
		end process;
	end generate;
	genRegistered1 : if (REGISTERED = FALSE) generate
		Mux_Data_d		<= Mux_Data;
	end generate;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset OR rst) = '1') then
				rev_l							<= rev;

				if (rev = '0') then
					Mux_sel_us			<= to_unsigned(0,							Mux_sel_us'length);
				else
					Mux_sel_us			<= to_unsigned((CHUNKS - 1),	Mux_sel_us'length);
				end if;
			else
				if (nxt = '1') then
					if (rev_l = '0') then
						Mux_sel_us		<= Mux_sel_us + 1;
					else
						Mux_sel_us		<= Mux_sel_us - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	Output		<= Mux_Data_d(ite((SIMULATION = TRUE), imin(to_integer(Mux_sel_us), CHUNKS - 1), to_integer(Mux_sel_us)));
end;
