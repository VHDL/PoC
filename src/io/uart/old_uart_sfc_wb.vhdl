--
-- Copyright (c) 2008
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
-- Entity: uart_sfc_wb
-- Author(s): Martin Zabel
--
-- This unit connects uart_sfc to a Wishbone bus.
--
-- Signals:
-- -------
-- wb_* : Wishbone interface
-- rxd  : receive  serial data
-- txd  : transmit serial data
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
-- Please read also notes on uart_sfc.
--
-- Synchronous reset.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-11-03 17:34:16 $
--
-------------------------------------------------------------------------------
-- Naming Conventions:
-- (Based on: Keating and Bricaud: "Reuse Methodology Manual")
--
-- active low signals: "*_n"
-- clock signals: "clk", "clk_div#", "clk_#x"
-- reset signals: "rst", "rst_n"
-- generics: all UPPERCASE
-- user defined types: "*_TYPE", "*_ARRAY"
-- state machine next state: "*_ns"
-- state machine current state: "*_cs"
-- output of a register: "*_r"
-- asynchronous signal: "*_a"
-- pipelined or register delay signals: "*_p#"
-- data before being registered into register with the same name: "*_nxt"
-- clock enable signals: "*_ce"
-- internal version of output port: "*_i"
-- tristate internal signal "*_z"
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_sfc_wb is
  generic (
    CLK_FREQ    : positive;-- := 50000000;  -- clock frequency in Hz
    BAUD        : positive;-- := 115200;    -- baud rate in Hz
    RX_OUT_REGS : boolean);-- := false);    -- see uart_sfc

  port (
    -- Global Reset / Clock
    clk : in std_logic;
    rst : in std_logic;

    -- Wishbone interface
    wb_adr_i : in  std_logic_vector(1 downto 0);
    wb_cyc_i : in  std_logic;
    wb_dat_i : in  std_logic_vector(7 downto 0);
    wb_stb_i : in  std_logic;
    wb_we_i  : in  std_logic;
    wb_ack_o : out std_logic;
    wb_dat_o : out std_logic_vector(31 downto 0);
    wb_err_o : out std_logic;
    wb_rty_o : out std_logic;

    -- debugging
    overflow : out std_logic;

    -- External Pins
    rxd : in  std_logic;
    txd : out std_logic
  );
end uart_sfc_wb;

architecture rtl of uart_sfc_wb is

  component uart_sfc
    generic (
      CLK_FREQ     : positive;
      BAUD         : positive;
      RF_MIN_DEPTH : positive;
      RF_FSTATE_BITS : positive;
      RF_CHECK     : boolean;
      TF_MIN_DEPTH : positive;
      TF_CHECK     : boolean;
      XOFF_TRIGGER : real;
      XON_TRIGGER  : real;
      RX_OUT_REGS  : boolean);
    port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      tf_put    : in  std_logic;
      tf_din    : in  std_logic_vector(7 downto 0);
      tf_full   : out std_logic;
      rf_got    : in  std_logic;
      rf_valid  : out std_logic;
      rf_dout   : out std_logic_vector(7 downto 0);
      rf_fstate : out unsigned(RF_FSTATE_BITS-1 downto 0);
      overflow  : out std_logic;
      rxd       : in  std_logic;
      txd       : out std_logic);
  end component;

  -- configuration
  -- change this, to adjust the buffer size
  constant RF_FSTATE_BITS : positive := 5;

  -- this depends on RF_STATE_BITS due to available calculation below.
  constant RF_MIN_DEPTH : positive := 2 * (2**RF_FSTATE_BITS);

  -- FSM
  type FSM_TYPE is (IDLE, CHECK, FILL_DOUT, TERMINATE);
  signal fsm_cs : FSM_TYPE;
  signal fsm_ns : FSM_TYPE;

  -- FIFO control
  signal tf_put    : std_logic;
  signal tf_din    : std_logic_vector(7 downto 0);
  signal tf_full   : std_logic;
  signal rf_got    : std_logic;
  signal rf_valid  : std_logic;
  signal rf_dout   : std_logic_vector(7 downto 0);
  signal rf_fstate : unsigned(RF_FSTATE_BITS-1 downto 0);

  signal rf_byte_avl  : std_logic;
  signal rf_short_avl : std_logic;
  signal rf_word_avl  : std_logic;
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

begin  -- rtl

  -----------------------------------------------------------------------------
  -- The UART with software flow control
  -----------------------------------------------------------------------------

  uart_sfc_0: uart_sfc
    generic map (
        CLK_FREQ     => CLK_FREQ,
        BAUD         => BAUD,
        RF_MIN_DEPTH => RF_MIN_DEPTH,
        RF_FSTATE_BITS => RF_FSTATE_BITS,
        RF_CHECK     => false,
        TF_MIN_DEPTH => 4,
        TF_CHECK     => false,
        XOFF_TRIGGER => 0.25,
        XON_TRIGGER  => 0.0625,         -- 4 bytes, see below on "avl"
        RX_OUT_REGS  => RX_OUT_REGS)
    port map (
        clk       => clk,
        rst       => rst,
        tf_put    => tf_put,
        tf_din    => tf_din,
        tf_full   => tf_full,
        rf_got    => rf_got,
        rf_valid  => rf_valid,
        rf_dout   => rf_dout,
        rf_fstate => rf_fstate,
        overflow  => overflow,
        rxd       => rxd,
        txd       => txd);

  -----------------------------------------------------------------------------
  -- Datapath not depending on FSM output
  -----------------------------------------------------------------------------

  -- Check if data is available:
  -- Assume that scale = 2**RF_FSTATE_BITS = RF_MIN_DEPTH/2.
  -- A byte  is available if rf_valid = '1'.
  -- A short is available if rf_fstate >= 1/scale which equals 2 bytes.
  -- A word  is available if rf_fstate >= 2/scale which equals 4 bytes.
  rf_byte_avl  <= rf_valid;
  rf_short_avl <= '1' when rf_fstate >= 1 else '0';
  rf_word_avl  <= '1' when rf_fstate >= 2 else '0';

  -- select available depending on word-width
  with addr_r(1 downto 0) select avl <=
    rf_byte_avl  when "00",
    rf_short_avl when "01",
    rf_word_avl  when "11",
    '0'          when others;

  din_nxt     <= wb_dat_i;
  addr_nxt    <= wb_adr_i;
  writing_nxt <= wb_we_i;

  read_cnt_init <= unsigned(addr_r(1 downto 0));

  tf_din  <= din_r;

  -----------------------------------------------------------------------------
  -- FSM
  -----------------------------------------------------------------------------

  process (fsm_cs, tf_full, rf_valid, read_cnt_r, avl,
           wb_cyc_i, wb_stb_i, writing_r, addr_r)
  begin  -- process
    fsm_ns          <= fsm_cs;
    get_user        <= '0';
    tf_put          <= '0';
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
            if tf_full = '1' then
              wb_rtyo_nxt <= '1';
            else
              tf_put <= '1';
              wb_acko_nxt <= '1';
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
        if rf_valid = '1' then
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
  rf_got <= shift_into_dout;

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
        dout_r <= dout_r(23 downto 0) & rf_dout;
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

end rtl;
