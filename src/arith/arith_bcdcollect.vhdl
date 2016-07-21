-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Thomas B. Preusser
--
-- Entity:					Serial-binary to parallel BCD-output converter.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
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

library PoC;
use PoC.utils.all;

entity arith_bcdcollect is
  generic (
    BITS     : natural := 0;     -- Maximum Number of Input Bits
                                 --  Zero (0): unspecified
                                 --   -> practical limit by bcd'length
    FRACTION : boolean := false  -- Binary Fractional Input
  );
  port (
    -- Clock
    clk : in std_logic;

    -- Functional Interface
    rst : in  std_logic;-- Reset Value to Zero (0)
    bin : in  std_logic;-- Sequential Binary Input, last digit at binary point:
                        -- Integer Input: MSB first, Fractional Input: LSB first
    ena : in  std_logic;-- Input Enable
    bcd : out t_bcd_vector -- Parallel BCD Output, most-significant digit left
  );
end arith_bcdcollect;


library IEEE;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

architecture rtl of arith_bcdcollect is

  constant MAP_BASE : natural := ite(FRACTION, bcd'left, bcd'right);
  constant MAP_DIR  : integer := ite(FRACTION xor bcd'ascending, -1, 1);
  function mapIndex(i : natural) return natural is
  begin
    return MAP_BASE + MAP_DIR*i;
  end mapIndex;

  -- Determine actual Implementation Size
  constant DIG10 : real := MATH_LOG_OF_2 * real(BITS) / MATH_LOG_OF_10;  -- required  output digits
  constant NN : positive := bcd'length;                                  -- available output digits
  constant N  : natural  := ite(BITS = 0, NN,                            -- fully implemented output digits
                                imin(NN, integer(ite(FRACTION, ceil(DIG10), floor(DIG10)))));
  constant K  : natural  := ite((BITS = 0) or FRACTION or (N = NN), 0,   -- extra bits for partially implemented leftmost digit
                                integer(floor(log(2.0, floor(10**(DIG10-real(N))))))+1);

  -- Inter-Digit Decimal Carries
  signal c : std_logic_vector(N downto 0);

begin
  assert (BITS > 0) and (DIG10 <= real(NN))
    report "BCD output may be truncated ("&
           integer'image(NN)&'<'&real'image(DIG10)&')'
    severity warning;

  c(0) <= bin;
  genDigits: for i in 0 to N-1 generate
    signal bcd_r : t_bcd := (others => '0');
  begin
    c(i+1) <= bcd_r(0) when FRACTION            else
              '1'      when unsigned(bcd_r) > 4 else
              '0';

    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          bcd_r <= (others => '0');
        elsif ena = '1' then
          if FRACTION then
            if c(i) = '1' then
              bcd_r <= t_bcd(('0'&unsigned(bcd_r(3 downto 1))) + 5);
            else
              bcd_r <= '0'&bcd_r(3 downto 1);
            end if;
          else
            if c(i+1) = '1' then
              bcd_r <= t_bcd((unsigned(bcd_r(2 downto 0)) + 3) & c(i));
            else
              bcd_r <= t_bcd(bcd_r(2 downto 0) & c(i));
            end if;
          end if;
        end if;
      end if;
    end process;
    bcd(mapIndex(i)) <= bcd_r;
  end generate genDigits;

  genLast: if K > 0 generate
    signal cnt_r : unsigned(K-1 downto 0) := (others => '0');
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          cnt_r <= (others => '0');
        elsif ena = '1' then
          if c(N) = '1' then
            cnt_r <= cnt_r + 1;
          end if;
        end if;
      end if;
    end process;
    process(cnt_r)
      variable bcd_t : std_logic_vector(3 downto 0);
    begin
      bcd_t               := (others => '0');
      bcd_t(K-1 downto 0) := std_logic_vector(cnt_r);
      bcd(mapIndex(N))    <= t_bcd(bcd_t);
    end process;
  end generate genLast;

  genFill: for i in natural range N+1-(1/(K+1)) to NN-1 generate
    bcd(mapIndex(i)) <= (others => '0');
  end generate genFill;

end architecture rtl;
