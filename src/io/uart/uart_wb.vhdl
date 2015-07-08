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
-- Entity: uart_wb
-- Author(s): Martin Zabel
-- 
-- Wrapper module for "uart_rx" and "uart_tx" to support Wishbone interface.
--
-- See notes on uart_fifo_wb for commands and adresses.
--
-- Author: Martin Zabel
--
-- Synchronized reset is used.
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
-- user defined types: "*_TYPE"
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

entity uart_wb is
  generic (
    CLK_FREQ    : positive;-- := 50000000;  -- clock frequency in Hz
    BAUD        : positive;-- := 115200;    -- baud rate in Hz
    RX_OUT_REGS : boolean);-- := false);    -- see uart_rx
  
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

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
    txd : out std_logic);

end uart_wb;


library PoC;
use PoC.uart.all;

architecture rtl of uart_wb is
  component uart_fifo_wb
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      wb_adr_i : in  std_logic_vector(1 downto 0);
      wb_cyc_i : in  std_logic;
      wb_dat_i : in  std_logic_vector(7 downto 0);
      wb_stb_i : in  std_logic;
      wb_we_i  : in  std_logic;
      wb_ack_o : out std_logic;
      wb_dat_o : out std_logic_vector(31 downto 0);
      wb_err_o : out std_logic;
      wb_rty_o : out std_logic;
      rf_put   : in  std_logic;
      rf_din   : in  std_logic_vector(7 downto 0);
      rf_full  : out std_logic;
      tf_got   : in  std_logic;
      tf_valid : out std_logic;
      tf_dout  : out std_logic_vector(7 downto 0));
  end component;

  signal rf_put   : std_logic;
  signal rf_din   : std_logic_vector(7 downto 0);
  signal rf_full  : std_logic;
  signal tf_got   : std_logic;
  signal tf_valid : std_logic;
  signal tf_dout  : std_logic_vector(7 downto 0);
  signal tx_ful   : std_logic;
  
  signal bclk_r    : std_logic;
  signal bclk_x8_r : std_logic;

  signal overflow_r : std_logic;
  
begin  -- rtl

  fifo2wb: uart_fifo_wb
    port map (
      clk      => clk,
      rst      => rst,
      wb_adr_i => wb_adr_i,
      wb_cyc_i => wb_cyc_i,
      wb_dat_i => wb_dat_i,
      wb_stb_i => wb_stb_i,
      wb_we_i  => wb_we_i,
      wb_ack_o => wb_ack_o,
      wb_dat_o => wb_dat_o,
      wb_err_o => wb_err_o,
      wb_rty_o => wb_rty_o,
      rf_put   => rf_put,
      rf_din   => rf_din,
      rf_full  => rf_full,
      tf_got   => tf_got,
      tf_valid => tf_valid,
      tf_dout  => tf_dout);

  rx : uart_rx
    port map (
      clk     => clk,
      rst     => rst,
      bclk_x8 => bclk_x8_r,
      rx      => rxd,
      do      => rf_din,
      put     => rf_put
    );

  tx : uart_tx
    port map (
      clk  => clk,
      rst  => rst,
      bclk => bclk_r,
      tx   => txd,
      di   => tf_dout,
      put  => tf_valid,
      ful  => tx_ful
    );
  tf_got <= not tx_ful;                 -- tf_got is checked inside fifo

  bclk: uart_bclk
    generic map (
      CLK_FREQ => CLK_FREQ,
      BAUD     => BAUD)
    port map (
      clk       => clk,
      rst       => rst,
      bclk_r    => bclk_r,
      bclk_x8_r => bclk_x8_r);

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        overflow_r <= '0';
      else
        overflow_r <= rf_put and rf_full;
      end if;
    end if;
  end process;

  overflow <= overflow_r;
end rtl;
