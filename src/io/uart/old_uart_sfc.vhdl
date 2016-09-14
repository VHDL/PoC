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
-- Entity: uart_sfc
-- Author(s): Martin Zabel
--
-- UART with software flow control
--
-- Includes receiver, transmitter, bit clock generator and FIFOs for input and
-- output.
--
-- Serial configuration is defined by instantiated uart_tx and uart_rx
-- modules.
--
-- Received XON/XOFF is not handled and passed to the user. Thus, software flow
-- control is only avaliable for this host. This enables the remote host to
-- send full 8-bit binary data.
--
-- Any XON/XOFF put into the transmit FIFO by the user are discarded. Flow
-- control characters are only send on the behalf of this unit.
--
-- If your timing constraints did not met, then you can enable output registers
-- inside the receiver with setting RX_OUT_REGS to true.
--
-- RF_MIN_DEPTH = minimum depth for receive FIFO
-- RF_FSTATE_BITS = number of bits to use for rf_fstate
-- RF_CHECK     = check 'got' for receive FIFO
-- TF_MIN_DEPTH = minimum depth for transmit FIFO
-- TF_CHECK     = check 'put' for transmit FIFO
--
-- XOFF_TRIGGER = trigger level for sending XOFF. Real value with range:
--                0.5 <= XOFF_TRIGGER < 1
--
-- On Linux as remote host, flow control is set using
-- "stty -F /dev/ttyS0 ixon -ixoff".
-- Parameter "-ixoff" means, that Linux must not send XON/XOFF when its own
-- receive buffer is full.
--
-- On Windows consult the documentation of the terminal program, if software
-- flow control can only be activated for one direction. If not, then ensure
-- that the terminal program is always ready for receiving.
--
-- Revision:    $Revision: 1.3 $
-- Last change: $Date: 2008-11-03 21:16:03 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.fifo.all;

entity uart_sfc is

  generic (
    CLK_FREQ     : positive;-- := 50000000;
    BAUD         : positive;-- := 115200;
    RF_MIN_DEPTH : positive;-- := 16;
    RF_FSTATE_BITS : positive;-- := 2;
    RF_CHECK     : boolean;--  := true;
    TF_MIN_DEPTH : positive;-- := 4;
    TF_CHECK     : boolean;--  := true;
    XOFF_TRIGGER : real;--     := 0.75;
    XON_TRIGGER  : real;--     := 0.0625;
    RX_OUT_REGS  : boolean--  := false
  );

  port (
    clk : in std_logic;
    rst : in std_logic;

    -- transmit FIFO
    tf_put  : in  std_logic;
    tf_din  : in  std_logic_vector(7 downto 0);
    tf_full : out std_logic;

    -- receive FIFO
    rf_got    : in  std_logic;
    rf_valid  : out std_logic;
    rf_dout   : out std_logic_vector(7 downto 0);
    rf_fstate : out unsigned(RF_FSTATE_BITS-1 downto 0);

    -- state
    overflow : out std_logic;

    -- line
    rxd : in  std_logic;
    txd : out std_logic);

end uart_sfc;

architecture uart_sfc_impl of uart_sfc is

  -----------------------------------------------------------------------------
  -- constants
  -----------------------------------------------------------------------------

  constant XON  : std_logic_vector(7 downto 0) := x"11";  -- ^Q
  constant XOFF : std_logic_vector(7 downto 0) := x"13";  -- ^S

  constant XOFF_TRIG : integer := integer(XOFF_TRIGGER *
                                          real(2**RF_FSTATE_BITS));

  constant XON_TRIG : integer := integer(XON_TRIGGER *
                                         real(2**RF_FSTATE_BITS));

  -----------------------------------------------------------------------------
  -- signals declaration
  -----------------------------------------------------------------------------

  signal bclk_r    : std_logic;
  signal bclk_x8_r : std_logic;

  signal rx_dos  : std_logic;
  signal rx_dout : std_logic_vector(7 downto 0);

  signal tx_stb : std_logic;
  signal tx_din : std_logic_vector(7 downto 0);
  signal tx_rdy : std_logic;

  signal tf_got   : std_logic;
  signal tf_valid : std_logic;
  signal tf_dout  : std_logic_vector(7 downto 0);

  signal rf_put   : std_logic;
  signal rf_din   : std_logic_vector(7 downto 0);
  signal rf_full  : std_logic;
  signal rf_fs    : unsigned(RF_FSTATE_BITS-1 downto 0);

  signal send_xoff : std_logic;
  signal send_xon  : std_logic;

  signal set_xoff_transmitted : std_logic;
  signal clr_xoff_transmitted : std_logic;
  signal discard_user         : std_logic;

  signal set_overflow : std_logic;

  -- registers
  signal xoff_transmitted : std_logic;

begin  -- uart_sfc_impl

  -----------------------------------------------------------------------------
  -- components instantiation
  -----------------------------------------------------------------------------

  rx: uart_rx
    generic map (
      OUT_REGS => RX_OUT_REGS)
    port map (
        clk       => clk,
        rst       => rst,
        bclk_x8_r => bclk_x8_r,
        rxd       => rxd,
        dos       => rx_dos,
        dout      => rx_dout);

  tx: uart_tx
    port map (
        clk    => clk,
        rst    => rst,
        bclk_r => bclk_r,
        stb    => tx_stb,
        din    => tx_din,
        rdy    => tx_rdy,
        txd    => txd);

  bclk: uart_bclk
    generic map (
        CLK_FREQ => CLK_FREQ,
        BAUD     => BAUD)
    port map (
        clk       => clk,
        rst       => rst,
        bclk_r    => bclk_r,
        bclk_x8_r => bclk_x8_r);

  rf: fifo_cc_got_smfs
    generic map (
        D_BITS    => 8,
        MIN_DEPTH => RF_MIN_DEPTH,
        FSTATE_BITS => RF_FSTATE_BITS,
        CHECK     => RF_CHECK)
    port map (
        rst    => rst,
        clk    => clk,
        put    => rf_put,
        din    => rf_din,
        full   => rf_full,
        fstate => rf_fs,
        got    => rf_got,
        valid  => rf_valid,
        dout   => rf_dout);

  rf_fstate <= rf_fs;

  tf: fifo_cc_got_sm
    generic map (
        D_BITS    => 8,
        MIN_DEPTH => TF_MIN_DEPTH,
        CHECK     => TF_CHECK)
    port map (
        rst    => rst,
        clk    => clk,
        put    => tf_put,
        din    => tf_din,
        full   => tf_full,
        got    => tf_got,
        valid  => tf_valid,
        dout   => tf_dout);

  -----------------------------------------------------------------------------
  -- logic
  -----------------------------------------------------------------------------

  -- send XOFF only once when fill state goes above trigger level
  send_xoff <= (not xoff_transmitted) when (rf_fs >= XOFF_TRIG) else '0';
  set_xoff_transmitted <= tx_rdy      when (rf_fs >= XOFF_TRIG) else '0';

  -- send XON only once when receive FIFO is almost empty
  send_xon <= xoff_transmitted   when rf_fs = XON_TRIG else '0';
  clr_xoff_transmitted <= tx_rdy when rf_fs = XON_TRIG else '0';

  -- discard any user supplied XON/XOFF
  discard_user <= '1' when (tf_dout = XON) or (tf_dout = XOFF) else '0';

  -- tx / tf control
  tx_din <= XOFF  when (send_xoff = '1') else
            XON   when (send_xon  = '1') else
            tf_dout;

  tx_stb <= send_xoff or send_xon or (tf_valid and (not discard_user));
  tf_got <= (send_xoff nor send_xon) and
            tf_valid and tx_rdy;        -- always check tf_valid

  -- rx / rf control
  rf_put <= (not rf_full) and rx_dos;   -- always check rf_full
  rf_din <= rx_dout;

  set_overflow <= rf_full and rx_dos;

  -- registers
  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if (rst or set_xoff_transmitted) = '1' then
        -- send a XON after reset
        xoff_transmitted <= '1';
      elsif clr_xoff_transmitted = '1' then
        xoff_transmitted <= '0';
      end if;

      if rst = '1' then
        overflow <= '0';
      elsif set_overflow = '1' then
        overflow <= '1';
      end if;
    end if;
  end process;

end uart_sfc_impl;
