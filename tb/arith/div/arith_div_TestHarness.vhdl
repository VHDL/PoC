-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Gustavo Martin
--
-- Entity:					arith_div_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for arith_div
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

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.strings.all;
use     PoC.physical.all;

library osvvm;
context osvvm.OsvvmContext;

library tb_arith;
use     tb_arith.arith_div_TestController_pkg.all;

entity arith_div_TestHarness is
end entity;

architecture tb of arith_div_TestHarness is
  constant CLOCK_FREQ : FREQ := 100 MHz;

  signal Clock : std_logic;
  signal Reset : std_logic;

  signal Start : std_logic;
  signal Ready : std_logic_vector(1 to 2*MAX_POW);
  signal A     : tA;
  signal D     : tD;
  signal Q     : tA_vector(1 to 2*MAX_POW);
  signal R     : tD_vector(1 to 2*MAX_POW);
  signal Z     : std_logic_vector(1 to 2*MAX_POW);

  component arith_div_TestController is
    port (
      Clock : in std_logic;
      Reset : in std_logic;
      Start : out std_logic;
      Ready : in  std_logic_vector(1 to 2*MAX_POW);
      A     : out tA;
      D     : out tD;
      Q     : in  tA_vector(1 to 2*MAX_POW);
      R     : in  tD_vector(1 to 2*MAX_POW);
      Z     : in  std_logic_vector(1 to 2*MAX_POW)
    );
  end component;

begin

  -- Clock Generation
  Osvvm.ClockResetPkg.CreateClock(
    Clk        => Clock,
    Period     => 10 ns
  );

  -- Reset Generation
  Osvvm.ClockResetPkg.CreateReset(
    Reset       => Reset,
    ResetActive => '1',
    Clk         => Clock,
    Period      => 10 ns,
    tpd         => 0 ns
  );

  -- Test Controller
  TestCtrl : arith_div_TestController
    port map (
      Clock => Clock,
      Reset => Reset,
      Start => Start,
      Ready => Ready,
      A     => A,
      D     => D,
      Q     => Q,
      R     => R,
      Z     => Z
    );

  -- DUTs
  genDUTs : for i in 1 to MAX_POW generate
    DUT_SEQU : entity PoC.arith_div
      generic map (
        A_BITS             => A_BITS,
        D_BITS             => D_BITS,
        RAPOW              => i
      )
      port map (
        clk => Clock,
        rst => Reset,

        start => Start,
        ready => Ready(i),

        A => A,
        D => D,
        Q => Q(i),
        R => R(i),
        Z => Z(i)
      );

    DUT_PIPE : entity PoC.arith_div
      generic map (
        A_BITS             => A_BITS,
        D_BITS             => D_BITS,
        RAPOW              => i,
        PIPELINED          => true
      )
      port map (
        clk => Clock,
        rst => Reset,

        start => Start,
        ready => Ready(MAX_POW+i),

        A => A,
        D => D,
        Q => Q(MAX_POW+i),
        R => R(MAX_POW+i),
        Z => Z(MAX_POW+i)
      );
  end generate;

end architecture;
