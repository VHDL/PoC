-- Synchronized reset is used.
-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:				 	Martin Zabel
--									Patrick Lehmann
-- 
-- Module:				 	UART Wrapper with Embedded FIFOs and Optional Flow Control
--
-- Description:
-- ------------------------------------
--	Small FIFOs are included in this module, if larger or asynchronous
--	transmit / receive FIFOs are required, then they must be connected
--	externally.
-- 
--	old comments:
--		UART BAUD rate generator
--		bclk_r    = bit clock is rising
--		bclk_x8_r = bit clock times 8 is rising
--
--
-- License:
-- ============================================================================
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
-- ============================================================================


library	IEEE;
use			IEEE.std_logic_1164.all;

library PoC;
use			PoC.physical.all;
use			PoC.components.all;


entity uart_fifo is
	generic (
		CLOCK_FREQ			: FREQ;
		BAUDRATE				: BAUD;
		TX_MIN_DEPTH		: POSITIVE;
		RX_MIN_DEPTH		: POSITIVE;
		RX_OUT_REGS			: BOOLEAN;
		
		SWFC_XON_CHAR			: std_logic_vector(7 downto 0)	:= x"11";		-- ^Q
    SWFC_XON_TRIGGER	: real													:= 0.0625;
		SWFC_XOFF_CHAR		: std_logic_vector(7 downto 0)	:= x"13";		-- ^S
		SWFC_XOFF_TRIGGER	: real													:= 0.75

		);
	port (
		clk						: in	std_logic;
		rst						: in	std_logic;

		-- FIFO interface
		TX_Valid			: in	STD_LOGIC;
		TX_Data				: in	STD_LOGIC_VECTOR(7 downto 0);
		TX_got				: out	STD_LOGIC;
		
		RX_Valid			: out	STD_LOGIC;
		RX_Data				: out	STD_LOGIC_VECTOR(7 downto 0);
		RX_got				: in	STD_LOGIC;
		RX_FillState	: out	STD_LOGIC_VECTOR(RX_FSTATE_BITS - 1 downto 0);
		RX_Overflow		: out	std_logic;
		
		-- External Pins
		rxd						: in	std_logic;
		txd						: out	std_logic
	);
end entity;


architecture rtl of uart_fifo is
  signal rf_put			: std_logic;
  signal rf_din			: std_logic_vector(7 downto 0);
  signal rf_full		: std_logic;
  signal tf_got			: std_logic;
  signal tf_valid		: std_logic;
  signal tf_dout		: std_logic_vector(7 downto 0);
  
  signal bclk_r			: std_logic;
  signal bclk_x8_r	: std_logic;

	constant RX_FSTATE_BITS		: POSITIVE;
	
  signal overflow_r					: std_logic					:= '0';
  
begin
	-- ===========================================================================
	-- Transmit and Receive FIFOs
	-- ===========================================================================
	tf : entity PoC.fifo_cc_got
		generic map (
			D_BITS         => 8,							-- Data Width
			MIN_DEPTH      => TX_MIN_DEPTH,		-- Minimum FIFO Depth
			DATA_REG       => TRUE,						-- Store Data Content in Registers
			STATE_REG      => FALSE,					-- Registered Full/Empty Indicators
			OUTPUT_REG     => FALSE,					-- Registered FIFO Output
			ESTATE_WR_BITS => 0,							-- Empty State Bits
			FSTATE_RD_BITS => 0								-- Full State Bits
		)
		port map (
			rst    => rst,
			clk    => clk,
			put    => tf_put,
			din    => tf_din,
			full   => tf_full,
			got    => tf_got,
			valid  => tf_valid,
			dout   => tf_dout
		);

  rf : entity PoC.fifo_cc_got
		generic map (
			D_BITS         => 8,							-- Data Width
			MIN_DEPTH      => RX_MIN_DEPTH,		-- Minimum FIFO Depth
			DATA_REG       => TRUE,						-- Store Data Content in Registers
			STATE_REG      => FALSE,					-- Registered Full/Empty Indicators
			OUTPUT_REG     => FALSE,					-- Registered FIFO Output
			ESTATE_WR_BITS => 0,							-- Empty State Bits
			FSTATE_RD_BITS => RX_FSTATE_BITS	-- Full State Bits
		)
		port map (
			rst    => rst,
			clk    => clk,
			put    => rf_put,
			din    => rf_din,
			full   => rf_full,
			fstate => rf_fs,
			got    => rf_got,
			valid  => rf_valid,
			dout   => rf_dout
		);

	genNOFC : if (FLOWCONTROL = NO) generate
	
	begin
	
	end generate;
	-- ===========================================================================
	-- Software Flow Control
	-- ===========================================================================
	genSWFC : if (FLOWCONTROL = SW) generate
	  constant XON  : std_logic_vector(7 downto 0) := x"11";  -- ^Q
		constant XOFF : std_logic_vector(7 downto 0) := x"13";  -- ^S

		constant XON_TRIG		: integer	:= integer(SWFC_XON_TRIGGER		* real(2**RF_FSTATE_BITS));
		constant XOFF_TRIG	: integer	:= integer(SWFC_XOFF_TRIGGER	* real(2**RF_FSTATE_BITS));

		signal send_xoff		: std_logic;
		signal send_xon			: std_logic;

		signal set_xoff_transmitted	: std_logic;
		signal clr_xoff_transmitted	: std_logic;
		signal discard_user					: std_logic;

		signal set_overflow					: std_logic;
		
		-- registers
		signal xoff_transmitted			: std_logic;
		
	begin
		-- send XOFF only once when fill state goes above trigger level
		send_xoff <= (not xoff_transmitted) when (rf_fs >= XOFF_TRIG) else '0';
		set_xoff_transmitted <= tx_rdy      when (rf_fs >= XOFF_TRIG) else '0';

		-- send XON only once when receive FIFO is almost empty
		send_xon <= xoff_transmitted   when (rf_fs = XON_TRIG) else '0';
		clr_xoff_transmitted <= tx_rdy when (rf_fs = XON_TRIG) else '0';

		-- discard any user supplied XON/XOFF
		discard_user <= '1' when (tf_dout = SWFC_XON_CHAR) or (tf_dout = SWFC_XOFF_CHAR) else '0';

		-- tx / tf control
		tx_din <= SWFC_XOFF_CHAR  when (send_xoff = '1') else
							SWFC_XON_CHAR   when (send_xon  = '1') else
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
	end generate;
	-- ===========================================================================
	-- Hardware Flow Control
	-- ===========================================================================
	genHWFC : if (FLOWCONTROL = HW) generate
	
	begin
	
	end generate;
	
	-- ===========================================================================
	-- BitClock, Transmitter, Receiver
	-- ===========================================================================
	bclk : entity PoC.uart_bclk
		generic map (
			CLOCK_FREQ	=> CLOCK_FREQ,
			BAUDRATE		=> BAUDRATE
		)
		port map (
			clk					=> clk,
			rst					=> rst,
			bclk_r			=> bclk_r,
			bclk_x8_r		=> bclk_x8_r
		);
	
	tx : entity PoC.uart_tx
		port map (
			clk			=> clk,
			rst			=> rst,
			bclk_r	=> bclk_r,
			stb			=> tf_valid,
			din			=> tf_dout,
			rdy			=> tf_got,
			txd			=> txd
		);
		
	rx : entity PoC.uart_rx
		generic map (
			OUT_REGS => RX_OUT_REGS
		)
		port map (
			clk				=> clk,
			rst				=> rst,
			bclk_x8_r	=> bclk_x8_r,
			rxd				=> rxd,
			dos				=> rf_put,
			dout			=> rf_din
		);
	
	overflow_r	<= ffrs(q => overflow_r, rst => rst, set => (rf_put and rf_full) when rising_edge(clk);
	RX_Overflow	<= overflow_r;
end;
