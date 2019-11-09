-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:           Stefan Unrein
--
-- Entity:            sync_Resets
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2019-2019 PLC2 Design GmbH, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.STD_LOGIC_1164.all;

use     work.sync.all;
use     work.components.all;


entity sync_Resets is
	generic (
		SNYC_MODE     : T_SYNC_MODE         := SYNC_MODE_ORDERED;     -- SYNC_MODE_UNORDERED, SYNC_MODE_ORDERED, SYNC_MODE_STRICTLY_ORDERED
		SYNC_DEPTH    : T_MISC_SYNC_DEPTH   := T_MISC_SYNC_DEPTH'low; -- generate SYNC_DEPTH many stages, at least 2
		NUM_CLOCKS    : natural             := 2
	);
	port (
		Clocks        : in  std_logic_vector(NUM_CLOCKS - 1 downto 0); -- <Clocks> output clock domains
		Input         : in  std_logic;                                 -- @async:  reset input
		Outputs       : out std_logic_vector(NUM_CLOCKS - 1 downto 0)  -- @Clocks(i): synchronized reset to Clocks(i)
	);
end entity;


architecture rtl of sync_Resets is
	signal sync_reset_d      : std_logic_vector(NUM_CLOCKS - 1 downto 1) := (others => '0');
	signal sync_reset_out    : std_logic_vector(NUM_CLOCKS - 1 downto 0) := (others => '0');
	signal sync_bits_out     : std_logic_vector(NUM_CLOCKS - 1 downto 0) := (others => '0');
begin

	reset_sync_inst :  entity work.sync_Reset
		generic map(
			SYNC_DEPTH    => SYNC_DEPTH
		)
		port map(
			Clock         => Clocks(0),
			Input         => Input,
			D             => '0',
			Output        => sync_reset_out(0)
		);
	
	sync_bits_inst : entity work.sync_Bits
		generic map(
			SYNC_DEPTH    => SYNC_DEPTH
		)
		port map(
			Clock         => Clocks(0),
			Input(0)      => sync_reset_out(0),
			Output(0)     => sync_bits_out(0)
		);
		
	sync : for i in 1 to NUM_CLOCKS - 1 generate
		signal reset_rs : std_logic := '0';
	begin
		gen_sync_mode : if SNYC_MODE = SYNC_MODE_UNORDERED generate
			reset_rs <= sync_reset_out(i);
			sync_reset_d(i) <= '0';
			
		elsif SNYC_MODE = SYNC_MODE_ORDERED generate
			sync_reset_d(i) <= sync_reset_out(i - 1);
			reset_rs        <= sync_reset_out(i);
			
		elsif SNYC_MODE = SYNC_MODE_STRICTLY_ORDERED generate
			signal set_re           : std_logic;
			signal rst_fe           : std_logic;
			signal sync_reset_out_d : std_logic := '0';
			signal sync_bits_out_d  : std_logic := '0';
		begin
			sync_reset_out_d <= sync_reset_out(i) when rising_edge(Clocks(i));
			set_re           <= not sync_reset_out_d and sync_reset_out(i);
			sync_bits_out_d  <= sync_bits_out(i - 1) when rising_edge(Clocks(i));
			rst_fe           <= sync_bits_out_d and not sync_bits_out(i - 1);
			reset_rs         <= ffsr(set => set_re, rst => rst_fe, q => reset_rs) when rising_edge(Clocks(i));
			
		else generate
			assert FALSE report "Not Supported Sync-Mode for Sync-Reset!" severity FAILURE;
		end generate;
		
		
		reset_sync_inst :  entity work.sync_Reset
			generic map(
				SYNC_DEPTH    => SYNC_DEPTH
			)
			port map(
				Clock         => Clocks(i),
				Input         => Input,
				D             => sync_reset_d(i),
				Output        => sync_reset_out(i)
			);
		
		sync_bits_inst : entity work.sync_Bits
			generic map(
				SYNC_DEPTH    => SYNC_DEPTH
			)
			port map(
				Clock         => Clocks(i),
				Input(0)      => reset_rs,
				Output(0)     => sync_bits_out(i)
			);
	end generate;
	
	Outputs <= sync_bits_out;
	
end architecture;
