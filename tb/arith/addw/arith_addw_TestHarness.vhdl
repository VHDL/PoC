-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_addw_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for arith_addw
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
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;

library PoC;
use     PoC.strings.all;
use     PoC.physical.all;
use     PoC.arith.all;

use     work.arith_addw_TestController_pkg.all;

entity arith_addw_TestHarness is
end entity;

architecture TestHarness of arith_addw_TestHarness is
  constant TPERIOD_CLOCK : time := 10 ns;

  signal Clock : std_logic := '1';
  signal Reset : std_logic := '1';
  signal a, b  : word := (others => '0');
  signal cin   : std_logic := '0';
  signal s     : word_vector;
  signal cout  : carry_vector;

  component arith_addw_TestController is
    port (
      Clock : in std_logic;
      Reset : in std_logic;
      a     : out word;
      b     : out word;
      cin   : out std_logic;
      s     : in word_vector;
      cout  : in carry_vector
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
    Period      => 5*TPERIOD_CLOCK, 
    tpd         => 0 ns
  );

  genArchs: for i in tArch_test generate
    genSkips: for j in tSkip_test generate
      genIncl_false: if true generate
        DUT_false : entity PoC.arith_addw
          generic map (
            N => N,
            K => K,
            ARCH => i,
            SKIPPING => j,
            P_INCLUSIVE => false
          )
          port map (
            a    => a,
            b    => b,
            cin  => cin,
            s    => s(i, j, false),
            cout => cout(i, j, false)
          );
      end generate;
      
      genIncl_true: if true generate
        DUT_true : entity PoC.arith_addw
          generic map (
            N => N,
            K => K,
            ARCH => i,
            SKIPPING => j,
            P_INCLUSIVE => true
          )
          port map (
            a    => a,
            b    => b,
            cin  => cin,
            s    => s(i, j, true),
            cout => cout(i, j, true)
          );
      end generate;
    end generate;
  end generate;

  TestCtrl: component arith_addw_TestController
    port map (
      Clock => Clock,
      Reset => Reset,
      a     => a,
      b     => b,
      cin   => cin,
      s     => s,
      cout  => cout
    );

end architecture;
