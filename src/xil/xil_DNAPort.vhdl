-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:          xil_DNA
--
-- Description: This component provides the Internal "DNA" (Unique Serial Number
--              or ID) Data of Xilinx devices as parallel dataport.
-- -------------------------------------
--
-- License:
-- =============================================================================
-- Copyright 2017-2025 The PoC-Library Authors
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
--
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library UNISIM;
use     UNISIM.VCOMPONENTS.ALL;

use     work.config.all;
use     work.utils.all;
use     work.config.all;
use     work.xil.all;
use     work.components.all;


entity xil_DNAPort is
  generic (
    SIM_DNA_VALUE : bit_vector := resize("0", get_DNABITS)   -- DNA value for simulation
  );
  port (
    Clock   : in  std_logic;
    Reset   : in  std_logic;
    Valid   : out std_logic;
    DataOut : out std_logic_vector(get_DNABITS -1 downto 0)
  );
end entity;


architecture rtl of xil_DNAPort is
  alias DNA_VALUE : bit_vector(SIM_DNA_VALUE'length - 1 downto 0) is SIM_DNA_VALUE;
  constant counter_high : natural := DataOut'length +2;

  signal DataOut_i     : DataOut'subtype := (others => '0');
  signal Shift         : std_logic;
  signal Read          : std_logic;
  signal DataOut_Shift : std_logic;

  signal counter_us    : unsigned(log2ceilnz(counter_high +1) -1 downto 0) := (others => '0');
  signal is_counter_high   : std_logic;
  signal is_counter_high_1 : std_logic;
begin
  counter_us <= upcounter_next(cnt => counter_us, rst => Reset, en => not is_counter_high) when rising_edge(Clock);
  is_counter_high   <= upcounter_equal(counter_us, counter_high);
  is_counter_high_1 <= upcounter_equal(counter_us, counter_high -1);

  Read      <= '1' when counter_us = 1 else '0';
  Shift     <= '1' when counter_us > 1 and is_counter_high_1 = '0' else '0';
  Valid     <= is_counter_high;
  DataOut   <= DataOut_i;

  genSeries: if (THIS_DEVICE.DevSeries = DEVICE_SERIES_7_SERIES) generate
    DataOut_i <= DataOut_i(DataOut_i'high -1 downto 0) & DataOut_Shift when rising_edge(Clock) and (counter_us > 1 and is_counter_high = '0');

    DNA : component DNA_PORT
    generic map (
      SIM_DNA_VALUE => DNA_VALUE
    )
    port map (
      CLK   => Clock,
      READ  => Read,
      SHIFT => Shift,
      DIN   => '0',
      DOUT  => DataOut_Shift
    );
  elsif (THIS_DEVICE.DevSeries = DEVICE_SERIES_ULTRASCALE_PLUS) or (DEVICE_SERIES = DEVICE_SERIES_ULTRASCALE) generate
    DataOut_i <= DataOut_Shift & DataOut_i(DataOut_i'high downto 1) when rising_edge(Clock) and (counter_us > 1 and is_counter_high = '0');

    DNA : component DNA_PORTE2
    generic map (
      SIM_DNA_VALUE => to_slv(DNA_VALUE)
    )
    port map (
      CLK   => Clock,
      READ  => Read,
      SHIFT => Shift,
      DIN   => '0',
      DOUT  => DataOut_Shift
    );
  else generate
    assert false report "xil_DNAPort:: DEVICE_SERIES not supported!" severity failure;
  end generate;
end architecture;
