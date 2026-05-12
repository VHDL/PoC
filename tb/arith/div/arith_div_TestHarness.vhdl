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
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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

entity arith_div_TestHarness is
end entity;

architecture tb of arith_div_TestHarness is
  constant CLOCK_PERIOD : time := 10 ns;

  constant A_BITS  : positive := 13;
  constant D_BITS  : positive := 4;
  constant MAX_POW : positive := 3;

  signal Clock : std_logic;
  signal Reset : std_logic;

  signal Start : std_logic;
  signal Ready : std_logic_vector(1 to 2*MAX_POW);
  signal A     : std_logic_vector(A_BITS-1 downto 0);
  signal D     : std_logic_vector(D_BITS-1 downto 0);
  signal Q     : T_SLVV(1 to 2*MAX_POW)(A_BITS-1 downto 0);
  signal R     : T_SLVV(1 to 2*MAX_POW)(D_BITS-1 downto 0);
  signal Z     : std_logic_vector(1 to 2*MAX_POW);

  component arith_div_TestController is
    port (
      Clock : in std_logic;
      Reset : in std_logic;
      Start : out std_logic;
      Ready : in  std_logic_vector;
      A     : out std_logic_vector;
      D     : out std_logic_vector;
      Q     : in  T_SLVV;
      R     : in  T_SLVV;
      Z     : in  std_logic_vector
    );
  end component;

begin

  -- Clock Generation
  Osvvm.ClockResetPkg.CreateClock(
    Clk        => Clock,
    Period     => CLOCK_PERIOD
  );

  -- Reset Generation
  Osvvm.ClockResetPkg.CreateReset(
    Reset       => Reset,
    ResetActive => '1',
    Clk         => Clock,
    Period      => 10 * CLOCK_PERIOD,
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
        A_BITS => A_BITS,
        D_BITS => D_BITS,
        RAPOW  => i
      )
      port map (
        clk   => Clock,
        rst   => Reset,
        start => Start,
        ready => Ready(i),
        A     => A,
        D     => D,
        Q     => Q(i),
        R     => R(i),
        Z     => Z(i)
      );

    DUT_PIPE : entity PoC.arith_div
      generic map (
        A_BITS    => A_BITS,
        D_BITS    => D_BITS,
        RAPOW     => i,
        PIPELINED => true
      )
      port map (
        clk   => Clock,
        rst   => Reset,
        start => Start,
        ready => Ready(MAX_POW+i),
        A     => A,
        D     => D,
        Q     => Q(MAX_POW+i),
        R     => R(MAX_POW+i),
        Z     => Z(MAX_POW+i)
      );
  end generate;

end architecture;
