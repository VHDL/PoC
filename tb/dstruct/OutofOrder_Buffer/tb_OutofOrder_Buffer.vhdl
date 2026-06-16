-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Iqbal Asif
--
--
-- Entity:          Testbench for a Dstruct_OutofOrder_Buffer
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.utils.all;

library OSVVM;
context OSVVM.OsvvmContext;


entity tb_OutofOrder_Buffer is
end entity;

architecture TestHarness of tb_OutofOrder_Buffer is
	constant NUM_INDEX : positive := 13;
	constant DATA_BITS : integer  := 32;

	constant tpd         : time := 2 ns;
	constant tperiod_Clk : time := 10 ns;

	signal Clk    : std_logic :='0';
	signal nReset : std_logic :='0';

	signal Put      : std_logic;
	signal Full    : std_logic;
	signal DataIn   : std_logic_vector(DATA_BITS-1 downto 0);
	signal IndexOut : unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);

	signal Got      : std_logic;
	signal Valid    : std_logic;
	signal IndexIn  : unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);
	signal DataOut  : std_logic_vector(DATA_BITS-1 downto 0);

	component dstruct_OutofOrder_Buffer_tc
		generic(
			NUM_INDEX : positive;
			DATA_BITS : positive
		);
		port (
				-- Global Signal Interface
			Clock  : in  std_logic;
			nReset : in  std_logic ;

			-- Put Port
			Put      : out std_logic;
			Full    : in  std_logic;
			DataIn   : out std_logic_vector(DATA_BITS-1 downto 0);
			IndexOut : in  unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);

			-- Get Port
			Got      : out std_logic;
			Valid    : in  std_logic;
			IndexIn  : out unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);
			DataOut  : in  std_logic_vector(DATA_BITS-1 downto 0)
		);
	end component;

begin

	-- create Clock for TB and 100 Mhz
	Osvvm.ClockResetPkg.CreateClock (
		Clk    => Clk,
		Period => Tperiod_Clk
	);

	-- create nReset
	Osvvm.ClockResetPkg.CreateReset (
		Reset       => nReset,
		ResetActive => '0',
		Clk         => Clk,
		Period      => 7 * tperiod_Clk,
		tpd         => tpd
	);

	TestCtrl : component dstruct_OutofOrder_Buffer_tc
		generic map (
			NUM_INDEX => NUM_INDEX,
			DATA_BITS => DATA_BITS
		)
		port map(
				-- Global Signal Interface
			Clock   => Clk,
			nReset  => nReset,

			-- Put Port
			Put      => Put,
			Full     => Full,
			DataIn   => DataIn,
			IndexOut => IndexOut,

			-- Get Port
			Got      => Got,
			Valid    => Valid,
			IndexIn  => IndexIn,
			DataOut  => DataOut
		);

	DUT : entity PoC.dstruct_OutOfOrderBuffer
		generic map (
			DATA_BITS => DATA_BITS,
			NUM_INDEX => NUM_INDEX
		)
		port map (
			-- Global signals
			Clock => Clk,
			Reset => not nReset,

			-- Put Port
			Put       => Put,
			Full      => Full,
			DataIn    => DataIn,
			IndexOut  => IndexOut,

			-- Get Port
			Got      => Got,
			Valid    => Valid,
			IndexIn  => IndexIn,
			DataOut  => DataOut
		);

end architecture;
