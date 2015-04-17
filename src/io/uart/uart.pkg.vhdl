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
-- Package: uart
-- Author(s): Martin Zabel
-- 
-- Component declarations for UART components
--
-- Revision:    $Revision: 1.3 $
-- Last change: $Date: 2013-06-14 08:58:29 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

package uart is

  component uart_bclk
    generic (
      CLK_FREQ : positive;
      BAUD     : positive);
    port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      bclk_r    : out std_logic;
      bclk_x8_r : out std_logic);
  end component;

  component uart_rx
    generic (
      OUT_REGS : boolean);
    port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      bclk_x8_r : in  std_logic;
      rxd       : in  std_logic;
      dos       : out std_logic;
      dout      : out std_logic_vector(7 downto 0));
  end component;

  component uart_tx
    port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      bclk_r : in  std_logic;
      stb    : in  std_logic;
      din    : in  std_logic_vector(7 downto 0);
      rdy    : out std_logic;
      txd    : out std_logic);
  end component;

  component uart_sfc
    generic (
      CLK_FREQ       : positive;
      BAUD           : positive;
      RF_MIN_DEPTH   : positive;
      RF_OUTPUT_REG  : boolean := true;
      TF_MIN_DEPTH   : positive;
      XOFF_TRIG      : natural;
      XON_TRIG       : natural;
      RX_OUT_REGS    : boolean);
    port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      tf_put    : in  std_logic;
      tf_din    : in  std_logic_vector(7 downto 0);
      tf_full   : out std_logic;
      rf_got    : in  std_logic;
      rf_valid  : out std_logic;
      rf_dout   : out std_logic_vector(7 downto 0);
      rf_count  : out unsigned(log2ceil(RF_MIN_DEPTH) downto 0);
      overflow  : out std_logic;
      rxd       : in  std_logic;
      txd       : out std_logic);
  end component;

  component uart_sfc_wb
    generic (
      CLK_FREQ    : positive;
      BAUD        : positive;
      RX_OUT_REGS : boolean);
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
      overflow : out std_logic;
      rxd      : in  std_logic;
      txd      : out std_logic);
  end component;

  component uart_wb
    generic (
      CLK_FREQ    : positive;
      BAUD        : positive;
      RX_OUT_REGS : boolean);
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
      overflow : out std_logic;
      rxd      : in  std_logic;
      txd      : out std_logic);
  end component;
  
end uart;

package body uart is
end uart;
