-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:                    Martin Zabel
--                             Patrick Lehmann
--                             Jonas Schreiner
--
-- Entity:                    Pseudo-Random Number Generator (PRNG).
--
-- Description:
-- -------------------------------------
-- This module implementes a Pseudo-Random Number Generator (PRNG) with
-- configurable bit count (``BITS``). This module uses an internal list of FPGA
-- optimized polynomials from 3 to 168 bits. The polynomials have at most 5 tap
-- positions, so that long shift registers can be inferred instead of single
-- flip-flops.
--
-- The generated number sequence includes the value all-zeros, but not all-ones.
--
-- License:
-- =============================================================================
-- Copyright 2024      PLC2 Design GmbH, Endingen - Germany
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
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

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.utils.all;
use     work.arith.all;


entity arith_prng is
    generic (
        BITS : positive;
		SEED : std_logic_vector := "0"
    );
    port (
        Clock : in std_logic;
        Reset : in std_logic; -- reset value to seed

        InitialValue : in std_logic_vector := SEED; -- Is loaded when Reset = '1'
        Got          : in std_logic; -- the current value has been got, and a new value should be calculated
        Value        : out std_logic_vector(BITS - 1 downto 0) -- the pseudo-random number
    );
end entity;


architecture rtl of arith_prng is
    -- The current value
    signal val_r : std_logic_vector(BITS - 1 downto 0) := resize(SEED, BITS);
begin
    assert ((3 <= BITS) and (BITS <= 168)) report "Width not yet supported." severity failure;

    -----------------------------------------------------------------------------
    -- Register
    -----------------------------------------------------------------------------
    process (Clock)
    begin
        if rising_edge(Clock) then
            if Reset = '1' then
                val_r <= resize(InitialValue, BITS);
            elsif Got = '1' then
                val_r <= arith_prbs_lfsr(val_r);
            end if;
        end if;
    end process;

    Value <= val_r;
end architecture;
