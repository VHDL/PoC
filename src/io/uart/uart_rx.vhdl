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
-- Entity: uart_rx
-- Author(s): Martin Zabel
-- 
-- UART receiver
--
-- Serial configuration: 8 data bits, 1 stop bit, no parity
--
-- bclk_x8_r = bit clock (defined by BAUD rate) times 8
-- dos       = data out strobe, signals that dout is valid, active high for one
--             cycle 
-- dout      = data out = received byte
--
-- OUT_REGS:
-- If disabled, then dos is a combinatorial output. Further merging of logic is
-- possible but timing constraints might fail. If enabled, 9 more registers are
-- required. But now, dout toggles only after receiving of full byte.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-11-03 17:24:59 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is

  generic (
    OUT_REGS : boolean);-- := false);
  
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    bclk_x8_r : in  std_logic;
    rxd       : in  std_logic;
    dos       : out std_logic;
    dout      : out std_logic_vector(7 downto 0));

end uart_rx;

architecture uart_rx_impl of uart_rx is

  -------------------------------------------
  -- signals

  type states is (IDLE, RDATA);
  signal state : states;
  signal next_state : states;

  -- registers
  signal rxd_reg1     : std_logic;
  signal rxd_reg2     : std_logic;
  signal sr           : std_logic_vector(7 downto 0);  -- data only
  signal bclk_cnt     : unsigned(2 downto 0);
  signal shift_cnt    : unsigned(3 downto 0);

  -- control signals
  signal rxd_falling    : std_logic;
  signal bclk_rising    : std_logic;
  signal start_bclk     : std_logic;
  signal shift_sr       : std_logic;
  signal shift_done     : std_logic;
  signal put_data       : std_logic;

begin  -- uart_rx_impl

  rxd_falling    <= (not rxd_reg1) and rxd_reg2;
  bclk_rising    <= bclk_x8_r when bclk_cnt = (bclk_cnt'range => '1')
                 else '0';

  -- shift_cnt count from 0 to 9 (1 start bit + 8 data bits)
  shift_done <= '1' when (shift_cnt and to_unsigned(9, 4)) = 9 else '0';

  process (state, rxd_falling, bclk_x8_r, bclk_rising, shift_done)
  begin  -- process
    next_state <= state;
    start_bclk <= '0';
    shift_sr   <= '0';
    put_data   <= '0';
    
    case state is
      when IDLE =>
        -- wait for start bit
        if (rxd_falling and bclk_x8_r) = '1' then
          next_state <= RDATA;
          start_bclk <= '1';            -- = rst_shift_cnt
        end if;

      when RDATA =>
        if bclk_rising = '1' then
          -- bit clock keeps running
          if shift_done = '1' then
            -- stop bit reached
            put_data   <= '1';
            next_state <= IDLE;
            
          else
            -- TODO: check start bit?
            shift_sr <= '1';
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

      rxd_reg1 <= rxd;

      if bclk_x8_r = '1' then
        -- align to bclk_x8, so when we can easily check for
        -- the falling edge of the start bit
        rxd_reg2 <= rxd_reg1;
      end if;

      if shift_sr = '1' then
        -- shift into MSB
        sr <= rxd_reg2 & sr(sr'left downto 1);
      end if;

      if start_bclk = '1' then
        bclk_cnt <= to_unsigned(4, bclk_cnt'length);
      elsif bclk_x8_r = '1' then
        -- automatically wraps
        bclk_cnt <= bclk_cnt + 1;
      end if;

      if start_bclk = '1' then
        shift_cnt <= (others => '0');
      elsif shift_sr = '1' then
        shift_cnt <= shift_cnt + 1;
      end if;
    end if;
  end process;

  -- output
  gOutRegs: if OUT_REGS = true generate
    process (clk)
    begin  -- process
      if rising_edge(clk) then
        dos  <= put_data and rxd_reg2;  -- check stop bit
        dout <= sr;
      end if;
    end process;
  end generate gOutRegs;

  gNoOutRegs: if OUT_REGS = false generate
    dos  <= put_data and rxd_reg2;      -- check stop bit
    dout <= sr;
  end generate gNoOutRegs;
  
end uart_rx_impl;
