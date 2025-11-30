-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Gustavo Martin
--
-- Entity:					arith_firstone_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for arith_firstone
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

entity arith_firstone_TestHarness is
end entity;

architecture TestHarness of arith_firstone_TestHarness is
  constant TPERIOD_CLOCK : time := 10 ns;
  constant N             : positive := 8;

  signal Clock : std_logic := '1';
  signal Reset : std_logic := '1';
  
  signal tin  : std_logic := '1';
  signal rqst : std_logic_vector(N-1 downto 0) := (others => '0');
  signal grnt : std_logic_vector(N-1 downto 0);
  signal tout : std_logic;
  signal bin  : std_logic_vector(log2ceil(N)-1 downto 0);

  component arith_firstone_TestController is
    generic (
      N : positive := 8
    );
    port (
      Clock : in std_logic;
      Reset : in std_logic;
      tin   : out std_logic;
      rqst  : out std_logic_vector(N-1 downto 0);
      grnt  : in std_logic_vector(N-1 downto 0);
      tout  : in std_logic;
      bin   : in std_logic_vector(log2ceil(N)-1 downto 0)
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
    Period      => 10 * TPERIOD_CLOCK, 
    tpd         => 0 ns
  );

  UUT: entity PoC.arith_firstone
    generic map (
      N => N
    )
    port map (
      tin  => tin,
      rqst => rqst,
      grnt => grnt,
      tout => tout,
      bin  => bin
    );
    
  TestCtrl: component arith_firstone_TestController
    generic map (
      N => N
    )
    port map (
      Clock => Clock,
      Reset => Reset,
      tin   => tin,
      rqst  => rqst,
      grnt  => grnt,
      tout  => tout,
      bin   => bin
    );
end architecture;
