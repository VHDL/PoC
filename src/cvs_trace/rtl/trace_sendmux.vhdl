--
-- Copyright (c) 2010
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
-- Entity: trace_sendmux
-- Author(s): Martin Zabel
--
-- Multiplex between data-packets and control-packets (command answer) during
-- sending the trace to the host PC.
--
-- MIN_DATA_PACKET_SIZE:
-- Ensure a minimum size for data-packets, e.g., to fill to the ethernet frame
-- with at least 46 bytes of valid data-data.
-- Examples:
-- - MIN_DATA_PACKET_SIZE = 46 for Ethernet
-- - MIN_DATA_PACKET_SIZE = 2  is current minimum (might be extended to 1)
--
-- 'eth_last' signals last byte of current packet. This terminates the current
-- packet, to allow switching between data-packets and control-packets.
--
-- 'data_fifo_clear' writes out any pending data even if minimum size of last
-- packet is not reached. Handle carefully.
--
-- This module's logic was formerly included in trace_ctrl (fifo_blk). But now,
-- it has
-- been separated to allow separate simulation. It has been also been
-- reimplemented and should be usable also for other communication channels
-- than ethernet. It might be integrated into the communication module itself
-- instead of trace_ctrl in the future.
--
-- TODO: Currently, some port-names are adapted from old implementation to avoid
--       confusion due to several port-name changes. But the port-names should
--       reflect the generalized usage in the future.
--
-- Revision:    $Revision: 1.4 $
-- Last change: $Date: 2013-05-16 12:14:00 $
--

library IEEE;
use IEEE.std_logic_1164.all;

entity trace_sendmux is

  generic (
    MIN_DATA_PACKET_SIZE : integer range 2 to 128);

  port (
    clk : in std_logic;
    rst : in std_logic;

    -- data-fifo access
    data_fifo_clear : in  std_logic;
    data_fifo_put   : in  std_logic;
    data_fifo_din   : in  std_logic_vector(7 downto 0);
    data_fifo_full  : out std_logic;
    data_fifo_empty : out std_logic;

    -- control-packet signaling
    ctrl_valid : in  std_logic;
    ctrl_data  : in  std_logic_vector(7 downto 0);
    ctrl_last  : in  std_logic;
    ctrl_got   : out std_logic;

    -- outgoing messages
    eth_valid   : out std_logic;
    eth_last    : out std_logic;
    eth_dout    : out std_logic_vector(7 downto 0);
    eth_got     : in  std_logic;
    eth_finish  : in  std_logic;
    header      : out std_logic);
end trace_sendmux;

library IEEE;
use IEEE.numeric_std.all;

library poc;
use poc.functions.all;
use poc.fifo.fifo_cc_got;

architecture rtl of trace_sendmux is
  type FSM_TYPE is (IDLE, SEND_CTRL, SEND_DATA);
  signal fsm_cs : FSM_TYPE;
  signal fsm_ns : FSM_TYPE;

  -- Data-Fifo control signals
  signal data_fifo_fstate : std_logic_vector(log2ceil(MIN_DATA_PACKET_SIZE+1)-1 downto 0);
  signal data_fifo_minavl : std_logic;
  signal data_fifo_1entry : std_logic;
  signal data_fifo_valid  : std_logic;
  signal data_fifo_got    : std_logic;
  signal data_fifo_dout   : std_logic_vector(7 downto 0);

  -- last byte of data-packet
  signal data_last : std_logic;

  -- real valid data byte
  signal data_valid : std_logic;

begin  -- rtl

  -----------------------------------------------------------------------------
  -- Data-Packet FIFO:
  --
  -- Required to collect enough trace-data bytes to fill the (ethernet) packet
  -- with the minimum count of bytes (MIN_DATA_PACKET_SIZE).
  -- Cannot be included in trace_eth because there is a packet multiplexer
  -- after that FIFO.
  --
  -- DEPTH must be one more, so that fill-state denotes the number of bytes
  -- available
  -----------------------------------------------------------------------------
  data_fifo: fifo_cc_got
    generic map (
      D_BITS         => 8,
      MIN_DEPTH      => MIN_DATA_PACKET_SIZE+1,
      DATA_REG       => true,
      FSTATE_RD_BITS => data_fifo_fstate'length
    )
    port map (
      rst => rst,
      clk => clk,

      put       => data_fifo_put,
      din       => data_fifo_din,
      full      => data_fifo_full,
      estate_wr => open,

      got       => data_fifo_got,
      valid     => data_fifo_valid,
      dout      => data_fifo_dout,
      fstate_rd => data_fifo_fstate
    );
  data_fifo_empty  <= '1' when unsigned(data_fifo_fstate) = 0 else '0';
  data_fifo_1entry <= '1' when unsigned(data_fifo_fstate) = 1 else '0';
  data_fifo_minavl <= '1' when unsigned(data_fifo_fstate) >= MIN_DATA_PACKET_SIZE else '0';

  -----------------------------------------------------------------------------
  -- FSM
  -----------------------------------------------------------------------------
  fsm_proc: process (fsm_cs, ctrl_valid, ctrl_last, data_fifo_clear,
                     data_fifo_minavl, data_fifo_valid, data_fifo_1entry,
                     eth_got, eth_finish)
  begin  -- process fsm_proc
    fsm_ns        <= fsm_cs;
    ctrl_got      <= '0';
    data_fifo_got <= '0';
    data_last     <= '0';
    data_valid    <= '0';

    case fsm_cs is
      when IDLE =>
        -- no packet in transmission
        if ctrl_valid = '1' then
          -- priority!
          fsm_ns <= SEND_CTRL;
        elsif data_fifo_minavl = '1'
          or (data_fifo_valid  and data_fifo_clear) = '1'
        then
          fsm_ns <= SEND_DATA;
        end if;

      when SEND_CTRL =>
        -- ctrl-packet in transmission
        ctrl_got <= eth_got;

        if (ctrl_last and eth_got) = '1' then
          fsm_ns <= IDLE;
        end if;

      when SEND_DATA =>
        -- data-packet in transmission
        -- enough data was available at the time this state was entered
        -- send all bytes but one, the last byte is required to terminate the packet
        data_fifo_got <= eth_got;

        if data_fifo_1entry = '0' then
          -- more than one byte left
          data_valid <= '1';

          if eth_finish = '1' then      -- implies eth_got
            -- maximum packet size reached
            -- just switch to new state to shorten critical path!
            fsm_ns <= IDLE;
          end if;

        else
          -- only one byte left
          if (ctrl_valid or data_fifo_clear) = '1' then
            -- finish data-packet, so that, we can switch to control-packet
            -- just switch to new state to shorten critical path!
            data_valid <= '1';
            data_last  <= '1';
            fsm_ns     <= IDLE;
          end if;
        end if;
    end case;
  end process fsm_proc;


  clk_proc: process (clk)
  begin  -- process clk_proc
    if rising_edge(clk) then
      if rst = '1' then
        fsm_cs <= IDLE;
      else
        fsm_cs <= fsm_ns;
      end if;
    end if;
  end process clk_proc;

  -----------------------------------------------------------------------------
  -- Output Multiplexer
  -----------------------------------------------------------------------------
  header <= '1' when fsm_cs = SEND_CTRL else '0';

  with fsm_cs select eth_dout <=
    ctrl_data      when SEND_CTRL,
    data_fifo_dout when others;         -- '0'

  with fsm_cs select eth_last <=
    ctrl_last when SEND_CTRL,
    data_last when SEND_DATA,
    '0'       when others;

  with fsm_cs select eth_valid <=
    ctrl_valid when SEND_CTRL,
    data_valid when SEND_DATA,
    '0'        when others;

end rtl;
