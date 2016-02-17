-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Thomas B. Preusser
-- 
-- Module:					Multi-cycle Non-Performing Restoring Divider
-- 
-- Description:
-- ------------------------------------
--	Implementation of a Non-Performing restoring divider with a configurable radix.
--	The multi-cycle division is controlled by 'start' / 'rdy'. A new division is
--	started by asserting 'start'. The result Q = A/D is available when 'rdy'
--  returns to '1'.
--  The generic DETECT_DIVISION_BY_ZERO enables circuitry to detect a divisor
--  of zero (0) right upon start. It is signalled by the corresponding output
--  'Z' together with an immediate 'rdy' indication. If this generic flag is
--  not enabled, the output 'Z' will never be asserted. The computation, in
--  fact, also terminates but with undefined results.
-- =============================================================================
-- Copyright 2007-2016 Technische Universität Dresden - Germany,
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

entity arith_div is
  generic (
    A_BITS             : positive;  		-- Dividend Width
    D_BITS             : positive;  		-- Divisor Width
    DETECT_DIV_BY_ZERO : boolean;  			-- Detect Division by Zero
    RAPOW              : positive := 1  -- Power of Compute Radix (2**RAPOW)
  );
  port (
    -- Global Reset/Clock
    clk : in std_logic;
    rst : in std_logic;

    -- Ready / Start
    start : in  std_logic;
    rdy   : out std_logic;

    -- Arguments / Result (2's complement)
    A : in  std_logic_vector(A_BITS-1 downto 0);  -- Dividend
    D : in  std_logic_vector(D_BITS-1 downto 0);  -- Divisor
    Q : out std_logic_vector(A_BITS-1 downto 0);  -- Quotient
    R : out std_logic_vector(D_BITS-1 downto 0);  -- Remainder
    Z : out std_logic  -- Division by Zero
  );
end arith_div;


library IEEE;
use IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;

architecture rtl of arith_div is

  -- Constants
  constant STEPS       : positive := (A_BITS+RAPOW-1)/RAPOW;  -- Number of Iteration Steps
  constant TRUNK_BITS  : natural  := (STEPS-1)*RAPOW;
  constant ACTIVE_BITS : positive := D_BITS + RAPOW;

  -- State
  constant EXEC_BITS : positive                     := log2ceil(STEPS)+1;
  constant EXEC_IDLE : signed(EXEC_BITS-1 downto 0) := '0' & (1 to EXEC_BITS-1 => '-');
  signal CntExec     : signed(EXEC_BITS-1 downto 0) := EXEC_IDLE;

  -- Argument/Result Registers
  signal AR : unsigned(ACTIVE_BITS+TRUNK_BITS-1 downto 0) := (others => '-');
  signal DR : unsigned(D_BITS-1 downto 0)                 := (others => '-');
  signal ZR : std_logic                                   := '0';

begin

  -- Registers
  process(clk)
    variable win : unsigned(D_BITS-1 downto 0);
    variable dif : unsigned(D_BITS downto 0);
  begin
    if rising_edge(clk) then
      -- Reset
      if rst = '1' then

        CntExec <= EXEC_IDLE;
        AR      <= (others => '-');
        DR      <= (others => '-');
        ZR      <= '0';

			-- Operation Initialization
			elsif start = '1' then

        if DETECT_DIV_BY_ZERO and D = (D'range => '0') then
          CntExec <= EXEC_IDLE;
          AR      <= (others => '-');
          DR      <= (others => '-');
          ZR      <= '1';
        else
          CntExec <= to_signed(-STEPS, CntExec'length);
          AR      <= (AR'left downto A_BITS => '0') & unsigned(A);
          DR      <= unsigned(D);
          ZR      <= '0';
        end if;

			-- Iteration Step
			elsif CntExec(CntExec'left) = '1' then

        CntExec <= CntExec + 1;

        win := AR(AR'left downto TRUNK_BITS + RAPOW);
        for i in RAPOW-1 downto 0 loop
          dif := (win & AR(TRUNK_BITS+i)) - DR;
          if dif(dif'left) = '0' then
            win := dif(D_BITS-1 downto 0);
          else
            win := win(D_BITS-2 downto 0) & AR(TRUNK_BITS+i);
          end if;
          AR(i) <= not dif(dif'left);
        end loop;
        AR(AR'left downto RAPOW) <= win & AR(TRUNK_BITS-1 downto 0);
      end if;
    end if;
  end process;
  rdy <= not CntExec(CntExec'left);
  Q   <= std_logic_vector(AR(A_BITS-1 downto 0));
  R   <= std_logic_vector(AR(STEPS*RAPOW+D_BITS-1 downto STEPS*RAPOW));
  Z   <= ZR;
end rtl;
