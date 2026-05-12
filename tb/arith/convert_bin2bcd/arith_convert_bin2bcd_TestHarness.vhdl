-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Gustavo Martin
--
-- Entity:					arith_convert_bin2bcd_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for arith_convert_bin2bcd
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
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;

library PoC;
use PoC.utils.all;
use PoC.strings.all;
use PoC.physical.all;

entity arith_convert_bin2bcd_TestHarness is
end entity;

architecture TestHarness of arith_convert_bin2bcd_TestHarness is
  constant TPERIOD_CLOCK : time := 10 ns; -- 100 MHz

  constant CONV1_BITS   : positive := 30;
  constant CONV1_DIGITS : positive := 8;
  constant CONV2_BITS   : positive := 27;
  constant CONV2_DIGITS : positive := 8;

  signal Clock : std_logic := '1';
  signal Reset : std_logic := '1';
  
  signal Start           : std_logic;
  
  signal Conv1_Binary    : std_logic_vector(CONV1_BITS - 1 downto 0);
  signal Conv1_BCDDigits : T_BCD_VECTOR(CONV1_DIGITS - 1 downto 0);
  signal Conv1_Sign      : std_logic;
  
  signal Conv2_Binary    : std_logic_vector(CONV2_BITS - 1 downto 0);
  signal Conv2_BCDDigits : T_BCD_VECTOR(CONV2_DIGITS - 1 downto 0);
  signal Conv2_Sign      : std_logic;

  component arith_convert_bin2bcd_TestController is
    generic (
      CONV1_BITS   : positive;
      CONV1_DIGITS : positive;
      CONV2_BITS   : positive;
      CONV2_DIGITS : positive
    );
    port (
      Clock     : in  std_logic;
      Reset     : in  std_logic;
      
      Start           : out std_logic;
      
      Conv1_Binary    : out std_logic_vector(CONV1_BITS - 1 downto 0);
      Conv1_BCDDigits : in  T_BCD_VECTOR(CONV1_DIGITS - 1 downto 0);
      Conv1_Sign      : in  std_logic;
      
      Conv2_Binary    : out std_logic_vector(CONV2_BITS - 1 downto 0);
      Conv2_BCDDigits : in  T_BCD_VECTOR(CONV2_DIGITS - 1 downto 0);
      Conv2_Sign      : in  std_logic
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

  conv1 : entity PoC.arith_convert_bin2bcd
    generic map (
      BITS   => CONV1_BITS,
      DIGITS => CONV1_DIGITS,
      RADIX  => 8
    )
    port map (
      Clock     => Clock,
      Reset     => Reset,
      Start     => Start,
      Busy      => open,
      Binary    => Conv1_Binary,
      IsSigned  => '0',
      BCDDigits => Conv1_BCDDigits,
      Sign      => Conv1_Sign
    );

  conv2 : entity PoC.arith_convert_bin2bcd
    generic map (
      BITS   => CONV2_BITS,
      DIGITS => CONV2_DIGITS,
      RADIX  => 2
    )
    port map (
      Clock     => Clock,
      Reset     => Reset,
      Start     => Start,
      Busy      => open,
      Binary    => Conv2_Binary,
      IsSigned  => '1',
      BCDDigits => Conv2_BCDDigits,
      Sign      => Conv2_Sign
    );
    
  TestCtrl: component arith_convert_bin2bcd_TestController
    generic map (
      CONV1_BITS   => CONV1_BITS,
      CONV1_DIGITS => CONV1_DIGITS,
      CONV2_BITS   => CONV2_BITS,
      CONV2_DIGITS => CONV2_DIGITS
    )
    port map (
      Clock           => Clock,
      Reset           => Reset,
      Start           => Start,
      Conv1_Binary    => Conv1_Binary,
      Conv1_BCDDigits => Conv1_BCDDigits,
      Conv1_Sign      => Conv1_Sign,
      Conv2_Binary    => Conv2_Binary,
      Conv2_BCDDigits => Conv2_BCDDigits,
      Conv2_Sign      => Conv2_Sign
    );

end architecture;
