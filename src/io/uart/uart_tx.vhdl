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
-- Entity: uart_tx
-- Author(s): Martin Zabel
--
-- UART transmitter
--
-- Serial configuration: 8 data bits, 1 stop bit, no parity
--
-- bclk = bit clk is rising
-- stb  = strobe, i.e. transmit byte @ din
-- rdy  = ready
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-11-03 17:24:59 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is

  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    bclk_r : in  std_logic;
    stb    : in  std_logic;
    din    : in  std_logic_vector(7 downto 0);
    rdy    : out std_logic;
    txd    : out std_logic);

end uart_tx;

architecture uart_tx_impl of uart_tx is
  --------------------------------------------------------
  -- signals
  
  type states is (IDLE, TDATA);
  signal state      : states;
  signal next_state : states;

  -- register
  signal sr        : std_logic_vector(9 downto 1);
  signal sr0       : std_logic;         -- current bit to transmit
  signal shift_cnt : unsigned(3 downto 0);

  -- control signals
  signal start_tx       : std_logic;
  signal shift_sr      : std_logic;

begin  -- uart_tx_impl

  process (state, stb, bclk_r, shift_cnt)
  begin  -- process
    next_state <= state;
    start_tx   <= '0';
    shift_sr   <= '0';

    case state is
      when IDLE =>
        if stb = '1' then
          -- start_tx triggers register initilization
          start_tx   <= '1';
          next_state <= TDATA;
        end if;

      when TDATA =>
        if bclk_r = '1' then
          -- also shift stop bit into sr0!
          shift_sr <= '1';
          
          if (shift_cnt and to_unsigned(9, 4)) = 9 then
            -- condition is true at beginning of sending the stop-bit
            -- synchronization to the bitclk ensures that stop-bit is
            -- transmitted fully
            next_state    <= IDLE;
          end if;
        end if;
      when others => null;
    end case;
  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        state <= IDLE;
      else
        state <= next_state;
      end if;
      
      if start_tx = '1' then
        -- data, start bit
        sr <= din & '0';
      elsif shift_sr = '1' then
        sr <= '1' & sr(sr'left downto sr'right+1);
      end if;

      if rst = '1' then
        sr0 <= '1';                     -- idle
      elsif shift_sr = '1' then
        sr0 <= sr(1);
      end if;

      if start_tx = '1' then
        shift_cnt <= (others => '0');
      elsif shift_sr = '1' then
        shift_cnt <= shift_cnt + 1;
      end if;
    end if;
  end process;

  -- outputs
  txd <= sr0;
  rdy <= '1' when state = IDLE else '0';
  
end uart_tx_impl;
