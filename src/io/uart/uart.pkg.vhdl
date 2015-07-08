-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ===========================================================================
-- Package:        UART (RS232) Components
--
-- Authors:        Martin Zabel
--                 Thomas B. Preusser
--
-- License:
-- ===========================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--                     Chair for VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--              http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ===========================================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;               -- uart_sfc

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

  component uart_rx is
    generic (
      SYNC_DEPTH : natural := 2  -- use zero for already clock-synchronous rx
    );
    port (
      -- Global Control
      clk : in std_logic;
      rst : in std_logic;

      -- Bit Clock and RX Line
      bclk_x8 : in std_logic;  	-- bit clock, eight strobes per bit length
      rx      : in std_logic;

      -- Byte Stream Output
      do  : out std_logic_vector(7 downto 0);
      put : out std_logic
    );
  end component;

	component uart_tx is
		port (
			-- Global Control
			clk : in std_logic;
			rst : in std_logic;

			-- Bit Clock and TX Line
			bclk : in  std_logic;  -- bit clock, one strobe each bit length
			tx   : out std_logic;

			-- Byte Stream Input
			di  : in  std_logic_vector(7 downto 0);
			put : in  std_logic;
			ful : out std_logic
		);
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
