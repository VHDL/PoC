--
-- Copyright (c) 2007
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: uart_bclk
-- Author(s): Martin Zabel
-- 
-- UART BAUD rate generator
-- bclk_r    = bit clock is rising
-- bclk_x8_r = bit clock times 8 is rising
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2010-01-05 10:29:16 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

entity uart_bclk is

  generic (
    CLK_FREQ : positive;-- := 50000000;
    BAUD     : positive);-- := 115200);
  
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    bclk_r    : out std_logic;
    bclk_x8_r : out std_logic);

end uart_bclk;

architecture uart_bclk_impl of uart_bclk is
  constant DIVIDER : positive := CLK_FREQ/(8*BAUD);

  -- register
  signal x8_cnt : unsigned(log2ceil(DIVIDER)-1 downto 0);
  signal x1_cnt : unsigned(2 downto 0);

  -- control signals
  signal x8_cnt_done : std_logic;
  signal x1_cnt_done : std_logic;

begin  -- uart_bclk_impl

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
  
end uart_bclk_impl;
