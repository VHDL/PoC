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
-- Entity: trace_eth
-- Author(s): Stefan Alex
-- 
------------------------------------------------------
-- Ethernet-Module with Transmitter and Receiver    --
--
-- ETH_GAP:
--   Increase gap between ethernet packets to slowdown transmission
--   and to reduce pressure on host. The minimal gap is already enforced
--   by the v5temac IP core.
--
------------------------------------------------------
--
-- Revision:    $Revision: 1.9 $
-- Last change: $Date: 2010-04-26 14:34:29 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_internals.all;

entity trace_eth is
  generic (
    BOARD_MAC        : std_logic_vector(47 downto 0);
    HOST_MAC         : std_logic_vector(47 downto 0);
    ETHER_TYPE       : std_logic_vector(15 downto 0);
    SEND_GAP         : positive;
    SEND_PACKET_SIZE : positive
    );
  port (
    -- globals
    clk_eth : in  std_logic;
    rst_eth : in  std_logic;
    tr_finish  : out std_logic;
    
    -- MAC-output
    tr_data  : out std_logic_vector(7 downto 0);
    tr_sof_n : out std_logic;
    tr_eof_n : out std_logic;
    tr_vld_n : out std_logic;
    tr_rdy_n : in  std_logic;

    -- MAC-input
    re_data  : in  std_logic_vector(7 downto 0);
    re_sof_n : in  std_logic;
    re_eof_n : in  std_logic;
    re_vld_n : in  std_logic;
    re_rdy_n : out std_logic;

    -- Fifo-Input
    tr_fifo_got   : out std_logic;
    tr_fifo_valid : in  std_logic;
    tr_fifo_last  : in  std_logic;
    tr_fifo_din   : in  std_logic_vector(7 downto 0);
    tr_header     : in  std_logic;

    -- Fifo-Output
    re_fifo_put  : out std_logic;
    re_fifo_full : in  std_logic;
    re_fifo_dout : out std_logic_vector(7 downto 0)
    );
end trace_eth;

architecture Behavioral of trace_eth is

  constant MAC_ETHERTYPE_SIZE  : positive := (BOARD_MAC'length/8)+(HOST_MAC'length/8)+(ETHER_TYPE'length/8);

begin

  ---------------------------------------------------------------------------
  -- Transmitter
  ---------------------------------------------------------------------------
  transmitter : block

    -- Ethernet Frame Payload exclusive ticket
    constant MINIMAL_PACKET_SIZE : positive := 46-1;
    constant MAXIMAL_PACKET_SIZE : positive := 1500-1;

    type type_state is (
      IDLE, MAC, TICKET, DATA, GAP
    );

    signal state      : type_state := IDLE;
    signal next_state : type_state;

    signal cnt_r        : unsigned(imax(log2ceil(SEND_PACKET_SIZE), log2ceil(SEND_GAP))-1 downto 0) := (others => '0');

    signal cnt_set_mac  : std_logic;
    signal cnt_set_data : std_logic;
    signal cnt_set_gap  : std_logic;
    signal cnt_dec      : std_logic;

    signal cnt_0        : std_logic;

    signal finish_packet : std_logic;
    signal send_byte     : std_logic;

    signal mx_mac  : std_logic_vector(7 downto 0);
    signal mx_data : std_logic_vector(7 downto 0);

    signal ticket_r   : unsigned(6 downto 0) := (others => '0');
    signal ticket_inc : std_logic;

    signal sof_n      : std_logic;
    signal eof_n      : std_logic;
    signal vld_n      : std_logic;

  begin

    assert (MINIMAL_PACKET_SIZE <= SEND_PACKET_SIZE) and (SEND_PACKET_SIZE <= MAXIMAL_PACKET_SIZE)
      report "ERROR: SEND_PACKET_SIZE must be between 45 and 1499."
      severity error;

    with state select
      tr_data<= mx_mac                                 when MAC,
                mx_data                                when DATA,
                tr_header & std_logic_vector(ticket_r) when TICKET,
                (others => '1')                        when others; -- TODO 1

    mx_data <= tr_fifo_din;

    with cnt_r(3 downto 0) select
      mx_mac <= HOST_MAC(47 downto 40)  when "1101",
                HOST_MAC(39 downto 32)  when "1100",
                HOST_MAC(31 downto 24)  when "1011",
                HOST_MAC(23 downto 16)  when "1010",
                HOST_MAC(15 downto  8)  when "1001",
                HOST_MAC( 7 downto  0)  when "1000",
                BOARD_MAC(47 downto 40) when "0111",
                BOARD_MAC(39 downto 32) when "0110",
                BOARD_MAC(31 downto 24) when "0101",
                BOARD_MAC(23 downto 16) when "0100",
                BOARD_MAC(15 downto  8) when "0011",
                BOARD_MAC( 7 downto  0) when "0010",
                ETHER_TYPE(15 downto 8) when "0001",
                ETHER_TYPE( 7 downto 0) when others; -- "0000";

    cnt_0        <= '1' when cnt_r = 0 else '0';

    sof_n <= '0' when state = MAC and cnt_r = to_unsigned(MAC_ETHERTYPE_SIZE-1, cnt_r'length) else '1';
    vld_n <= not send_byte;
    eof_n <= not finish_packet;

    -- processes

    com_proc : process(state, tr_fifo_valid, tr_fifo_last, tr_rdy_n, cnt_0)
    begin

      next_state     <= state;
      cnt_set_mac    <= '0';
      cnt_set_data   <= '0';
      cnt_set_gap    <= '0';
      cnt_dec        <= '0';
      ticket_inc     <= '0';
      tr_fifo_got    <= '0';
      finish_packet  <= '0';
      send_byte      <= '0';

      case state is

        when IDLE =>

          if tr_fifo_valid = '1' then
            next_state  <= MAC;
            cnt_set_mac <= '1';
          end if;

        when MAC =>

          if tr_rdy_n = '0' then
            send_byte <= '1';
            if cnt_0 = '1' then
              next_state <= TICKET;
            else
              cnt_dec <= '1';
            end if;
          end if;

        when TICKET =>

           if tr_rdy_n = '0' then
             send_byte    <= '1';
             cnt_set_data <= '1';
             next_state   <= DATA;
             ticket_inc   <= '1';
           end if;

        when DATA =>

          if tr_rdy_n = '0' then

            if tr_fifo_last = '1' then
              send_byte     <= '1';
              tr_fifo_got   <= '1';
              finish_packet <= '1';
              cnt_set_gap   <= '1';
              next_state    <= GAP;
              
            elsif tr_fifo_valid = '1' then
              -- check if data is available
              tr_fifo_got <= '1';
              send_byte   <= '1';
              
              if cnt_0 = '1' then       -- packet full
                finish_packet <= '1';
                cnt_set_gap   <= '1';
                next_state    <= GAP;
              else
                cnt_dec <= '1';
              end if;
            end if;
          end if;

        when GAP =>
          cnt_dec <= '1';
          if cnt_0 = '1' then
            next_state     <= IDLE;
          end if;

      end case;
    end process com_proc;

    clk_proc : process(clk_eth, rst_eth)
    begin
      if rising_edge(clk_eth) then
        if rst_eth = '1' then
          cnt_r        <= (others => '0');
          ticket_r     <= (others => '0');
          state        <= IDLE;
        else
          state <= next_state;

          if cnt_set_mac = '1' then
            cnt_r <= to_unsigned(MAC_ETHERTYPE_SIZE-1, cnt_r'length);
          elsif cnt_set_gap = '1' then
            cnt_r <= to_unsigned(SEND_GAP-1,cnt_r'length);
          elsif cnt_set_data = '1' then
            cnt_r <= to_unsigned(SEND_PACKET_SIZE-1,cnt_r'length);
          elsif cnt_dec = '1' then
            cnt_r <= cnt_r - 1;
          end if;

          if ticket_inc = '1' then
            ticket_r <= ticket_r + 1;
          end if;

        end if;
      end if;

    end process clk_proc;

    -- output-signals

    tr_sof_n    <= sof_n;
    tr_vld_n    <= vld_n;
    tr_eof_n    <= eof_n;

    tr_finish  <= finish_packet;

  end block transmitter;

  ---------------------------------------------------------------------------
  -- Receiver
  ---------------------------------------------------------------------------
  receiver : block

    type type_state is (
      IDLE, MAC, TICKET, LENGTH, DATA
    );

    signal state      : type_state := IDLE;
    signal next_state : type_state;

    signal mx_mac    : std_logic_vector(7 downto 0);
    signal data_vld  : std_logic;
    signal mac_equal : std_logic;

    signal cnt_r          : unsigned(7 downto 0) := to_unsigned(MAC_ETHERTYPE_SIZE-1, 8);
    signal cnt_set_mac    : std_logic;
    signal cnt_set_length : std_logic;
    signal cnt_dec        : std_logic;
    signal cnt_0          : std_logic;

    signal ticket_r     : unsigned(7 downto 0) := (others => '0');
    signal ticket_inc   : std_logic;
    signal ticket_equal : std_logic;

    signal fifo_put_i : std_logic;
    signal rdy_n      : std_logic;

    signal sof_n      : std_logic;
    signal eof_n      : std_logic;
    signal vld_n      : std_logic;
    signal data_i     : std_logic_vector(7 downto 0);

begin

    sof_n  <= re_sof_n;
    eof_n  <= re_eof_n;
    vld_n  <= re_vld_n;
    data_i <= re_data;

    -- combinatorical datapath

    with cnt_r(3 downto 0) select
      mx_mac <= BOARD_MAC(47 downto 40) when "1101",
                BOARD_MAC(39 downto 32) when "1100",
                BOARD_MAC(31 downto 24) when "1011",
                BOARD_MAC(23 downto 16) when "1010",
                BOARD_MAC(15 downto  8) when "1001",
                BOARD_MAC( 7 downto  0) when "1000",
                HOST_MAC(47 downto 40)  when "0111",
                HOST_MAC(39 downto 32)  when "0110",
                HOST_MAC(31 downto 24)  when "0101",
                HOST_MAC(23 downto 16)  when "0100",
                HOST_MAC(15 downto  8)  when "0011",
                HOST_MAC( 7 downto  0)  when "0010",
                ETHER_TYPE(15 downto 8) when "0001",
                ETHER_TYPE( 7 downto 0) when others; -- "0000";

    mac_equal <= '1' when mx_mac = data_i else '0';

    data_vld <= not vld_n and not re_fifo_full;

    cnt_0        <= '1' when cnt_r = 0 else '0';
    ticket_equal <= '1' when data_i = std_logic_vector(ticket_r) else '0';

    rdy_n <= '0' when state /= DATA or re_fifo_full = '0' else '1';

    -- processes

    com_proc : process(state, sof_n, vld_n, mac_equal, cnt_0, data_vld, eof_n, ticket_equal)
    begin

      next_state     <= state;
      cnt_set_mac    <= '0';
      cnt_set_length <= '0';
      cnt_dec        <= '0';
      ticket_inc     <= '0';
      fifo_put_i     <= '0';

      case(state) is

        when IDLE =>

          if sof_n = '0' and vld_n = '0' and mac_equal = '1' then -- start new frame
            cnt_dec    <= '1';
            next_state <= MAC;
          end if;

        when MAC =>

          if vld_n = '0' then
            if mac_equal = '1' then
              if cnt_0 = '1' then -- correct mac and type
                next_state <= TICKET;
              else
                cnt_dec <= '1';
              end if;
            else -- not correct
              next_state <= IDLE;
            end if;
          end if;

        when TICKET =>

          if vld_n = '0' then
            if ticket_equal = '1' then
              next_state <= LENGTH;
              ticket_inc <= '1';
            else
              next_state <= IDLE;
            end if;
          end if;

        when LENGTH =>

          if vld_n = '0' then
            cnt_set_length <= '1';
            next_state     <= DATA;
          end if;

        when DATA =>

          if data_vld = '1' then
            fifo_put_i <= '1';
            if cnt_0 = '1' then
--              if eof_n = '0' then
                next_state  <= IDLE;
                cnt_set_mac <= '1';
--              end if;
            else

              cnt_dec    <= '1';
            end if;
          end if;

      end case;
    end process com_proc;

    clk_proc : process(clk_eth, rst_eth)
    begin
      if rising_edge(clk_eth) then
        if rst_eth = '1' then
          state    <= IDLE;
          ticket_r <= (others => '0');
          cnt_r    <= to_unsigned(MAC_ETHERTYPE_SIZE-1, cnt_r'length); -- minus one
        else

          state <= next_state;

          if cnt_set_mac = '1' then
            cnt_r <= to_unsigned(MAC_ETHERTYPE_SIZE-1, cnt_r'length); -- minus one
          elsif cnt_set_length = '1' then
            cnt_r <= unsigned(re_data);
          elsif cnt_dec = '1' then
            cnt_r <= cnt_r - 1;
          end if;

          if ticket_inc = '1' then
            ticket_r <= ticket_r + 1;
          end if;

        end if;
      end if;
    end process clk_proc;

    -- outputs

    re_fifo_dout <= re_data;
    re_fifo_put  <= fifo_put_i;
    re_rdy_n     <= rdy_n;

  end block receiver;

end Behavioral;

