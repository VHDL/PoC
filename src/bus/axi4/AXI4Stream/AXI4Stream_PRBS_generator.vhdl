-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:  Max Kraft-Kugler
--
-- Entity:   A simple PRBS generator utilizing the PRNG from arith and providing an axistream interface for it.
--
-- Description:
-- -------------------------------------
-- This module wraps the arith_prng pseudo-random-number-generator (PRNG) to send out a 
-- pseudo-random-bit-sequence (PRBS).
-- 
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.STD_LOGIC_1164.all;
use     IEEE.NUMERIC_STD.all;

library PoC;
use     PoC.axi4stream.all;


entity AXI4Stream_PRBS_generator is
	port (
		Clock    : in  std_logic;
		Reset    : in  std_logic;
		PRBS_M2S : out T_AXI4STREAM_M2S;
		PRBS_S2M : in  T_AXI4STREAM_S2M
	);
end entity;

architecture RTL of AXI4Stream_PRBS_generator is
	constant DATA_BITS : natural := PRBS_M2S.Data'length; 

	signal Data  : std_logic_vector(DATA_BITS - 1 downto 0);
	signal Valid : std_logic := '0';

begin
	

	prng_inst : entity PoC.arith_prng
	generic map(
		BITS => DATA_BITS,
		SEED => (DATA_BITS - 1 downto 0 => '0')
	)
	port map(
		clk  => Clock,
		rst  => Reset,
		got  => PRBS_S2M.Ready,
		val  => Data
	);

	Valid <= not Reset when rising_edge(Clock);

	PRBS_M2S.Valid <= Valid;
	PRBS_M2S.Data  <= Data;
	-- Last, User, Keep etc are unsupported, thus undriven if existing

end architecture;
