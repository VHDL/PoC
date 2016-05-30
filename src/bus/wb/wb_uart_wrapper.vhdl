









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


library IEEE;
use			IEEE.std_logic_1164.all;

library PoC;
use			PoC.physical.all;


entity uart_wb is
	generic (
		CLOCK_FREQ		: FREQ;
		BAUDRATE			: BAUD;
		RX_OUT_REGS		: boolean
	);
	port (
		clk				: in	std_logic;
		rst				: in	std_logic;

		-- FIFO interface

		wb_adr_i	: in	std_logic_vector(1 downto 0);
		wb_cyc_i	: in	std_logic;
		wb_dat_i	: in	std_logic_vector(7 downto 0);
		wb_stb_i	: in	std_logic;
		wb_we_i		: in	std_logic;
		wb_ack_o	: out	std_logic;
		wb_dat_o	: out	std_logic_vector(31 downto 0);
		wb_err_o	: out	std_logic;
		wb_rty_o	: out	std_logic;

		-- debugging
		overflow	: out	std_logic;

		-- External Pins
		rxd				: in	std_logic;
		txd				: out	std_logic
	);
end entity;


architecture rtl of uart_wb is
  signal rf_put   : std_logic;
  signal rf_din   : std_logic_vector(7 downto 0);
  signal rf_full  : std_logic;
  signal tf_got   : std_logic;
  signal tf_valid : std_logic;
  signal tf_dout  : std_logic_vector(7 downto 0);

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

  rx: uart_rx
    generic map (
      OUT_REGS => RX_OUT_REGS)
    port map (
      clk       => clk,
      rst       => rst,
      bclk_x8_r => bclk_x8_r,
      rxd       => rxd,
      dos       => rf_put,
      dout      => rf_din);

  tx: uart_tx
    port map (
      clk    => clk,
      rst    => rst,
      bclk_r => bclk_r,
      stb    => tf_valid,
      din    => tf_dout,
      rdy    => tf_got,                 -- tf_got is checked inside fifo
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
end;
