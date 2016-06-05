-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Entity:					Data (Un-)Scrambler for SATA Link Layer
--
-- Description:
-- -------------------------------------
-- Scrambles or unscrambles transmitted data over the physical link.
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


entity sata_Scrambler is
	generic (
		POLYNOMIAL	: BIT_VECTOR					:= x"1A011";
		SEED				: BIT_VECTOR					:= x"FFFF";
		WIDTH				: POSITIVE						:= 32
	);
	port (
		Clock				: in	STD_LOGIC;
		Enable			: in	STD_LOGIC;
		Reset				: in	STD_LOGIC;

		DataIn			: in	STD_LOGIC_VECTOR(WIDTH - 1 downto 0);
		DataOut			: out	STD_LOGIC_VECTOR(WIDTH - 1 downto 0)
	);
end entity;


architecture rtl of sata_Scrambler is
	function normalize(G : BIT_VECTOR) return BIT_VECTOR is
		variable GN		: BIT_VECTOR(G'length - 1 downto 0);
	begin
		GN := G;

		FOR i IN GN'left downto 1 loop
			if (GN(i) = '1') then
				return GN(i - 1 downto 0);
			end if;
		end loop;

		report ""	severity failure;
		return G;
	end;

	constant GENERATOR	: BIT_VECTOR		:= normalize(POLYNOMIAL);

	signal LFSR					: STD_LOGIC_VECTOR(GENERATOR'range);
	signal Mask					: STD_LOGIC_VECTOR(DataIn'range);

begin

-- TODO: test SEED length

	process(Clock, Reset, Enable, LFSR)
		variable Vector		: STD_LOGIC_VECTOR(LFSR'range);
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Vector := to_stdlogicvector(SEED);

				FOR i IN Mask'low to Mask'high loop
					Mask(i) <= Vector(Vector'left);

					-- Galois LFSR
					Vector	:= (Vector(Vector'left - 1 downto 0) & '0') XOR (to_stdlogicvector(GENERATOR) AND (GENERATOR'range => Vector(Vector'left)));
				end loop;

				LFSR <= Vector;
			else
				if (Enable = '1') then
					Vector := LFSR;

					FOR i IN Mask'low to Mask'high loop
						Mask(i) <= Vector(Vector'left);

						-- Galois LFSR
						Vector	:= (Vector(Vector'left - 1 downto 0) & '0') XOR (to_stdlogicvector(GENERATOR) AND (GENERATOR'range => Vector(Vector'left)));
					end loop;

					LFSR <= Vector;
				end if;
			end if;
		end if;
	end process;

	DataOut <= DataIn XOR Mask;
end;
