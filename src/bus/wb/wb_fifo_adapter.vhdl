-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Martin Zabel
--									Patrick Lehmann
--
-- Entity:				 	WishBone Adapter to FIFO interface
--
-- Description:
-- -------------------------------------
-- Small FIFOs are included in this module, if larger or asynchronous
-- transmit / receive FIFOs are required, then they must be connected
-- externally.
--
-- old comments:
-- 	 UART BAUD rate generator
-- 	 bclk_r    = bit clock is rising
-- 	 bclk_x8_r = bit clock times 8 is rising
--
-- License:
-- =============================================================================
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
-- =============================================================================

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library PoC;
use			PoC.utils.all;



-- FIFO access with Wishbone interface.
--
-- Small FIFOs are included in this unit, to implemented the byte/short/word
-- functionality. If larger or asynchronous transmit / rececive FIFOs are
-- required, then they must be connected externally.
--
-- Signals:
-- -------
-- wb_* : Wishbone interface
-- RX_* : receive  (from outside) FIFO, byte interface
-- TX_* : transmit (to outside)   FIFO, byte interface
--
-- Addresses:
-- ---------
--
-- 0x00 : read/write byte
-- 0x01 : read       short (big endian)
-- 0x03 : read       word  (big endian)
--
-- Big endian means, that the first byte put into the receive fifo is placed
-- in the MSB of the short or word read.
--
-- Receive FIFO:
-- -------------
-- Just put all incoming data into the receive FIFO (RX_put, RX_din) while the
-- FIFO is not full (RX_full).
--
-- Transmit FIFO:
-- --------------
-- New data for transmission is available at TX_dout if TX_valid = '1'. If the
-- data has been captured by the outside then assert TX_got.

entity wb_fifo_adapter is
	port (
		-- Global Reset / Clock
		clk				: in std_logic;
		rst				: in std_logic;
		-- Wishbone interface
		wb_adr_i	: in	std_logic_vector(1 downto 0);
		wb_cyc_i	: in	std_logic;
		wb_dat_i	: in	std_logic_vector(7 downto 0);
		wb_stb_i	: in	std_logic;
		wb_we_i		: in	std_logic;
		wb_ack_o	: out	std_logic;
		wb_dat_o	: out	std_logic_vector(31 downto 0);
		wb_err_o	: out	std_logic;
		wb_rty_o	: out	std_logic;
		-- RX FIFO interface
		RX_put		: in	std_logic;
		RX_din		: in	std_logic_vector(7 downto 0);
		RX_full		: out	std_logic;
		-- TX FIFO interface
		TX_got		: in	std_logic;
		TX_valid	: out	std_logic;
		TX_dout		: out	std_logic_vector(7 downto 0)
	);
end entity;


architecture rtl of wb_fifo_adapter is
  -- configuration
  -- change this, to adjust the buffer size
  constant RX_FSTATE_BITS : positive := 2;  -- 2 = minimum value

  -- this depends on RX_STATE_BITS due to available calculation below.
  constant RX_MIN_DEPTH : positive := 2 * (2**RX_FSTATE_BITS);

  -- FSM
  type FSM_TYPE is (IDLE, CHECK, FILL_DOUT, TERMINATE);
  signal fsm_cs : FSM_TYPE;
  signal fsm_ns : FSM_TYPE;

  -- FIFO control
  signal TX_put    : std_logic;
  signal TX_din    : std_logic_vector(7 downto 0);
  signal TX_full   : std_logic;
  signal RX_got    : std_logic;
  signal RX_valid  : std_logic;
  signal RX_dout   : std_logic_vector(7 downto 0);
  signal RX_fstate : unsigned(RX_FSTATE_BITS-1 downto 0);

  signal RX_byte_avl  : std_logic;
  signal RX_short_avl : std_logic;
  signal RX_word_avl  : std_logic;
  signal avl          : std_logic;

  -- io input registers and control signals
  signal get_user    : std_logic;
  signal din_r       : std_logic_vector(7 downto 0);
  signal din_nxt     : std_logic_vector(7 downto 0);
  signal addr_r      : std_logic_vector(1 downto 0);
  signal addr_nxt    : std_logic_vector(1 downto 0);
  signal writing_r   : std_logic;
  signal writing_nxt : std_logic;

  -- data out register and control signals
  signal dout_r          : std_logic_vector(31 downto 0);
  signal read_cnt_r      : unsigned(1 downto 0);
  signal read_cnt_init   : unsigned(1 downto 0);
  signal init_dout       : std_logic;
  signal shift_into_dout : std_logic;

  -- wishbone signaling
  signal wb_acko_r   : std_logic;
  signal wb_acko_nxt : std_logic;
  signal wb_erro_r   : std_logic;
  signal wb_erro_nxt : std_logic;
  signal wb_rtyo_r   : std_logic;
  signal wb_rtyo_nxt : std_logic;

begin
  -----------------------------------------------------------------------------
  -- Datapath not depending on FSM output
  -----------------------------------------------------------------------------

  -- Check if data is available:
  -- Assume that scale = 2**RX_FSTATE_BITS = RX_MIN_DEPTH/2.
  -- A byte  is available if RX_valid = '1'.
  -- A short is available if RX_fstate >= 1/scale which equals 2 bytes.
  -- A word  is available if RX_fstate >= 2/scale which equals 4 bytes.
  RX_byte_avl  <= RX_valid;
  RX_short_avl <= '1' when RX_fstate >= 1 else '0';
  RX_word_avl  <= '1' when RX_fstate >= 2 else '0';

  -- select available depending on word-width
  with addr_r(1 downto 0) select avl <=
    RX_byte_avl  when "00",
    RX_short_avl when "01",
    RX_word_avl  when "11",
    '0'          when others;

  din_nxt     <= wb_dat_i;
  addr_nxt    <= wb_adr_i;
  writing_nxt <= wb_we_i;

  read_cnt_init <= unsigned(addr_r(1 downto 0));

  TX_din  <= din_r;

  -----------------------------------------------------------------------------
  -- FSM
  -----------------------------------------------------------------------------

  process (fsm_cs, TX_full, RX_valid, read_cnt_r, avl,
           wb_cyc_i, wb_stb_i, writing_r, addr_r)
  begin  -- process
    fsm_ns          <= fsm_cs;
    get_user        <= '0';
    TX_put          <= '0';
    init_dout       <= '0';
    shift_into_dout <= '0';

    wb_acko_nxt <= '0';
    wb_erro_nxt <= '0';
    wb_rtyo_nxt <= '0';

    case fsm_cs is
      when IDLE =>
        if (wb_cyc_i and wb_stb_i) = '1' then
          get_user <= '1';
          fsm_ns   <= CHECK;
        end if;

      when CHECK =>
        if writing_r = '1' then
          if addr_r = "00" then
            -- write byte
            if TX_full = '1' then
              wb_rtyo_nxt <= '1';
            else
              TX_put <= '1';
              wb_acko_nxt <= '1';
            end if;
          else
            -- writing of shorts/words is not supported
            wb_erro_nxt <= '1';
          end if;

          fsm_ns <= TERMINATE;
        else
          -- reading: check if enough bytes are available
          if avl = '1' then
            init_dout <= '1';
            fsm_ns    <= FILL_DOUT;
          else
            wb_rtyo_nxt <= '1';
            fsm_ns      <= TERMINATE;
          end if;
        end if;

      when FILL_DOUT =>
        if RX_valid = '1' then
          shift_into_dout <= '1';

          if read_cnt_r = "00" then          -- check old counter state
            wb_acko_nxt <= '1';
            fsm_ns      <= TERMINATE;
          end if;
        end if;

      when TERMINATE =>
        -- bus-cycle is terminated during this clock-cycle by ack/err/rty
        -- wb_stb_i/wb_cyc_i are cleared during clock-transition
        fsm_ns <= IDLE;
    end case;
  end process;

  -----------------------------------------------------------------------------
  -- Data path depending on FSM output
  -----------------------------------------------------------------------------
  RX_got <= shift_into_dout;

  -----------------------------------------------------------------------------
  -- Registers
  -----------------------------------------------------------------------------
  REGS : process (clk)
  begin  -- process INPUT_REGS
    if rising_edge(clk) then
      if rst = '1' then
        fsm_cs      <= IDLE;
        wb_acko_r   <= '0';
        wb_erro_r   <= '0';
        wb_rtyo_r   <= '0';
      else
        fsm_cs      <= fsm_ns;
        wb_acko_r   <= wb_acko_nxt;
        wb_erro_r   <= wb_erro_nxt;
        wb_rtyo_r   <= wb_rtyo_nxt;
      end if;

      if get_user = '1' then
        din_r     <= din_nxt;
        addr_r    <= addr_nxt;
        writing_r <= writing_nxt;
      end if;

      if init_dout = '1' then
        read_cnt_r <= read_cnt_init;
      elsif shift_into_dout = '1' then
        read_cnt_r <= read_cnt_r - 1;
      end if;

      if init_dout = '1' then
        dout_r <= (others => '0');
      elsif shift_into_dout = '1' then
        dout_r <= dout_r(23 downto 0) & RX_dout;
      end if;
    end if;
  end process REGS;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------

  wb_dat_o <= dout_r;
  wb_ack_o <= wb_acko_r;
  wb_err_o <= wb_erro_r;
  wb_rty_o <= wb_rtyo_r;

end;
