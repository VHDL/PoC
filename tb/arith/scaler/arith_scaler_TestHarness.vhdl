-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_scaler_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for arith_scaler
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
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
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;

library PoC;
use PoC.utils.all;
use PoC.physical.all;

entity arith_scaler_TestHarness is
end entity;

architecture TestHarness of arith_scaler_TestHarness is
  constant TPERIOD_CLOCK : time := 10 ns;
  constant CLOCK_FREQ : FREQ := 100 MHz;
  constant MULS : T_POSVEC := (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  constant DIVS : T_POSVEC := (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  constant ARG_WIDTH : positive := 8;

  signal Clock : std_logic := '1';
  signal Reset : std_logic := '1';
  
  signal start : std_logic := '0';
  signal arg   : std_logic_vector(ARG_WIDTH-1 downto 0) := (others => '0');
  signal msel  : std_logic_vector(log2ceil(MULS'length)-1 downto 0) := (others => '0');
  signal dsel  : std_logic_vector(log2ceil(DIVS'length)-1 downto 0) := (others => '0');
  signal done  : std_logic;
  signal res   : std_logic_vector(ARG_WIDTH-1 downto 0);

  component arith_scaler_TestController is
    generic (
      MULS : T_POSVEC := (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
      DIVS : T_POSVEC := (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
      ARG_WIDTH : positive := 8
    );
    port (
      Clock : in std_logic;
      Reset : in std_logic;
      start : out std_logic;
      arg   : out std_logic_vector(ARG_WIDTH-1 downto 0);
      msel  : out std_logic_vector(log2ceil(MULS'length)-1 downto 0);
      dsel  : out std_logic_vector(log2ceil(DIVS'length)-1 downto 0);
      done  : in std_logic;
      res   : in std_logic_vector(ARG_WIDTH-1 downto 0)
    );
  end component;

begin

  Osvvm.ClockResetPkg.CreateClock(
    Clk    => Clock, 
    Period => TPERIOD_CLOCK
  );

  Osvvm.ClockResetPkg.CreateReset(
    Reset       => Reset, 
    ResetActive => '1', 
    Clk         => Clock, 
    Period      => 5 * TPERIOD_CLOCK, 
    tpd         => 0 ns
  );

  UUT: entity PoC.arith_scaler
    generic map (
      MULS => MULS,
      DIVS => DIVS
    )
    port map (
      clk   => Clock,
      rst   => Reset,
      start => start,
      arg   => arg,
      msel  => msel,
      dsel  => dsel,
      done  => done,
      res   => res
    );
    
  TestCtrl: component arith_scaler_TestController
    generic map (
      MULS => MULS,
      DIVS => DIVS,
      ARG_WIDTH => ARG_WIDTH
    )
    port map (
      Clock => Clock,
      Reset => Reset,
      start => start,
      arg   => arg,
      msel  => msel,
      dsel  => dsel,
      done  => done,
      res   => res
    );
end architecture;
