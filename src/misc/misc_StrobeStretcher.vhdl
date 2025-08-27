-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:           Patrick Lehmann
--                    Stefan Unrein
--
-- Entity:            Module to stretch an incoming strobe impulse
--
-- Description:
-- -------------------------------------
-- This module stretches an incoming strobe impulse to a long output pulse that
-- is asserted for ``OUTPUT_CYCLES`` to high.
--
-- License:
-- =============================================================================
-- Copyright 2024-2025 The PoC-Library Authors
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
use     IEEE.NUMERIC_STD.all;


use     work.utils.all;
use     work.components.all;


entity misc_StrobeStretcher is
	generic (
		BITS              : positive := 1;
		OUTPUT_CYCLES     : positive
	);
	port (
		Clock  : in  std_logic;
		Input  : in  std_logic_vector(BITS -1 downto 0);
		Output : out std_logic_vector(BITS -1 downto 0) := (others => '0')
	);
end entity;


architecture rtl of misc_StrobeStretcher is
	constant COUNTER_INIT_VALUE : positive  := OUTPUT_CYCLES - 2;
	constant COUNTER_BITS       : natural   := log2ceilnz(COUNTER_INIT_VALUE + 1);

begin
	Bit_gen : for i in Input'range generate

		signal Counter_s            : signed(COUNTER_BITS downto 0) := to_signed(-1, COUNTER_BITS + 1);
		signal Counter_ov           : std_logic;

	begin
		-- counter
		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Input(i) = '1') then
					Counter_s    <= to_signed(COUNTER_INIT_VALUE, Counter_s'length);
				elsif (Counter_ov = '0') then
					Counter_s  <= Counter_s - 1;
				end if;
			end if;
		end process;

		Counter_ov <= Counter_s(Counter_s'high);

		Output(i)     <= ffsr(q => Output(i),	rst => Counter_ov, set => Input(i)) when rising_edge(Clock);
	end generate;
end architecture;
