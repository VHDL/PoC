-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:				 	Martin Zabel
-- 
-- Module:				 	UART bit clock / baud rate generator
--
-- Description:
-- ------------------------------------
--	TODO
-- 
--	old comments:
--		UART BAUD rate generator
--		bclk_r    = bit clock is rising
--		bclk_x8_r = bit clock times 8 is rising
--
--
-- License:
-- ============================================================================
-- Copyright 2008-2015 Technische Universitaet Dresden - Germany
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
-- ============================================================================

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library PoC;
use			PoC.utils.all;


entity uart_bclk is
  generic (
    CLK_FREQ : positive;-- := 50000000;
    BAUD     : positive-- := 115200
	);
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    bclk_r    : out std_logic;
    bclk_x8_r : out std_logic
	);
end entity;


architecture rtl of uart_bclk is
  constant DIVIDER : positive := CLK_FREQ/(8*BAUD);

  -- register
  signal x8_cnt : unsigned(log2ceil(DIVIDER)-1 downto 0);
  signal x1_cnt : unsigned(2 downto 0);

  -- control signals
  signal x8_cnt_done : std_logic;
  signal x1_cnt_done : std_logic;

begin

  x8_cnt_done <= '1' when (x8_cnt and to_unsigned(DIVIDER-1, x8_cnt'length)) = DIVIDER-1 else '0';
  x1_cnt_done <= '1' when x1_cnt = (x1_cnt'range => '0') else '0';
  
  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if (rst or x8_cnt_done) = '1' then
        x8_cnt <= (others => '0');
      else
        x8_cnt <= x8_cnt + 1;
      end if;

      if rst = '1' then
        x1_cnt <= (others => '0');      -- only for simulation
      elsif x8_cnt_done = '1' then
        x1_cnt <= x1_cnt - 1;
      end if;
    end if;
  end process;

  -- outputs
  process (clk)
  begin  -- process
    if rising_edge(clk) then
      -- only x8_cnt_done is pulsed for one clock cycle!
      bclk_r    <= x1_cnt_done and x8_cnt_done;  -- important
      bclk_x8_r <= x8_cnt_done;
    end if;
  end process;
  
end;
