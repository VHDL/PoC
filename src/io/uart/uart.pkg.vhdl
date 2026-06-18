-- =============================================================================
-- Authors:        Martin Zabel
--                 Thomas B. Preusser
--                 Patrick Lehmann
--
-- Package:        UART (RS232) Components for PoC.io.uart
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
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
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;

use     work.utils.all;
use     work.physical.all;


package uart is
	type T_UART_FLOWCONTROL_KIND is (
		UART_FLOWCONTROL_NONE,
		UART_FLOWCONTROL_XON_XOFF,
		UART_FLOWCONTROL_RTS_CTS,
		UART_FLOWCONTROL_RTR_CTS
	);

	type T_UART_PARITY_MODE is (
		PARITY_NONE,
		PARITY_EVEN,
		PARITY_ODD
	);

	type T_UART_PARITY_ERROR_HANDLING is (
		REPLACE_ERROR_BYTE,
		PASSTHROUGH_ERROR_BYTE,
		DROP_ERROR_BYTE
	);

	constant C_IO_UART_TYPICAL_BAUDRATES : T_BAUDVEC := (
		 0 =>    300 Bd,   1 =>    600 Bd,   2 =>   1200 Bd,   3 =>   1800 Bd,   4 =>   2400 Bd,
		 5 =>   4000 Bd,   6 =>   4800 Bd,   7 =>   7200 Bd,   8 =>   9600 Bd,   9 =>  14400 Bd,
		10 =>  16000 Bd,  11 =>  19200 Bd,  12 =>  28800 Bd,  13 =>  38400 Bd,  14 =>  51200 Bd,
		15 =>  56000 Bd,  16 =>  57600 Bd,  17 =>  64000 Bd,  18 =>  76800 Bd,  19 => 115200 Bd,
		20 => 128000 Bd,  21 => 153600 Bd,  22 => 230400 Bd,  23 => 250000 Bd,  24 => 256000 Bd,
		25 => 460800 Bd,  26 => 500000 Bd,  27 => 576000 Bd,  28 => 921600 Bd
	);

	function io_UART_IsTypicalBaudRate(br : BAUD) return boolean;

	-- Bit Clock Generator: 8 Ticks per Bit
	component uart_BitClock
		generic(
			CLOCK_FREQ        : FREQ     := 100 MHz;
			BAUDRATE          : BAUD     := 115200 Bd;
			OVERSAMPLING_RATE : positive := 8
		);
		port(
			Clock       : in  std_logic;
			Reset       : in  std_logic;
			BitClock    : out std_logic;
			SampleClock : out std_logic
		);
	end component uart_BitClock;

	-- Receiver
	component uart_RX
		generic(
			SYNC_DEPTH              : natural                      := 2;             -- Use 0 for already clock-synchronous RX signal
			PARITY                  : T_UART_PARITY_MODE           := PARITY_NONE;
			PARITY_ERROR_HANDLING   : T_UART_PARITY_ERROR_HANDLING := PASSTHROUGH_ERROR_BYTE;
			PARITY_ERROR_IDENTIFIER : std_logic_vector(7 downto 0) := x"15"
		);
		port(
			Clock       : in  std_logic;
			Reset       : in  std_logic;

			SampleClock : in  std_logic;
			RX          : in  std_logic;

			DataOut     : out std_logic_vector(7 downto 0);
			Strobe      : out std_logic;
			ParityError : out std_logic
		);
	end component uart_RX;

	-- Transmitter
	component uart_TX
		generic(
			PARITY   : T_UART_PARITY_MODE := PARITY_NONE
		);
		port(
			Clock    : in  std_logic;
			Reset    : in  std_logic;

			BitClock : in  std_logic;
			TX       : out std_logic;

			Put      : in  std_logic;
			DataIn   : in  std_logic_vector(7 downto 0);
			Full     : out std_logic
		);
	end component uart_TX;

	-- Wrappers
	-- ===========================================================================
	-- UART with FIFOs and optional flow control
	component uart_FIFO
		generic(
			CLOCK_FREQ              : FREQ;
			BAUDRATE                : BAUD;
			PARITY                  : T_UART_PARITY_MODE           := PARITY_NONE;
			PARITY_ERROR_HANDLING   : T_UART_PARITY_ERROR_HANDLING := PASSTHROUGH_ERROR_BYTE;
			PARITY_ERROR_IDENTIFIER : std_logic_vector(7 downto 0) := 8x"0";
			ADD_INPUT_SYNCHRONIZERS : boolean                      := TRUE;
			TX_MIN_DEPTH            : positive                     := 16;
			TX_ESTATE_BITS          : natural                      := 0;
			RX_MIN_DEPTH            : positive                     := 16;
			RX_FSTATE_BITS          : natural                      := 0;
			FLOWCTRL_XON_THRESHOLD  : real                         := 0.0625;
			FLOWCTRL_XOFF_THRESHOLD : real                         := 0.75;
			FLOWCONTROL             : T_UART_FLOWCONTROL_KIND   := UART_FLOWCONTROL_NONE;
			SWFC_XON_CHAR           : std_logic_vector(7 downto 0) := x"11";
			SWFC_XOFF_CHAR          : std_logic_vector(7 downto 0) := x"13"
		);
		port(
			Clock            : in  std_logic;
			Reset            : in  std_logic;

			TX_Put           : in  std_logic;
			TX_Data          : in  std_logic_vector(7 downto 0);
			TX_Full          : out std_logic;
			TX_EmptyState    : out std_logic_vector(imax(0, TX_ESTATE_BITS-1) downto 0);
			TXFIFO_Reset     : in  std_logic;
			TXFIFO_Empty     : out std_logic;

			RX_Valid         : out std_logic;
			RX_Data          : out std_logic_vector(7 downto 0);
			RX_Got           : in  std_logic;
			RX_FullState     : out std_logic_vector(imax(0, RX_FSTATE_BITS-1) downto 0);
			RX_Overflow      : out std_logic;
			RXFIFO_Full      : out std_logic;
			RXFIFO_Reset     : in  std_logic;

			UART_TX          : out std_logic;
			UART_RX          : in  std_logic;
			UART_RTS         : out std_logic;
			UART_CTS         : in  std_logic;
			UART_ParityError : out std_logic
		);
	end component uart_FIFO;

	-- USB-UART
	component ft245_uart is
		generic (
			CLK_FREQ : positive
		);
		port (
			-- common signals
			Clock       : in  std_logic;
			Reset       : in  std_logic;

			-- Send data
			TX_Put     : in  std_logic;
			TX_Data    : in  std_logic_vector(7 downto 0);
			TX_Full    : out std_logic;

			-- Receive data
			RX_Valid   : out std_logic;
			RX_Data    : out std_logic_vector(7 downto 0);

			-- Connection to FT245
			FT245_PowerEnable_n : in    std_logic;
			FT245_Read_n        : out   std_logic;
			FT245_Write_n       : out   std_logic;
			FT245_Data          : inout std_logic_vector(7 downto 0);
			FT245_RXF_n         : in    std_logic;
			FT245_TXE_n         : in    std_logic
		);
	end component;

end package;


package body uart is
	function io_UART_IsTypicalBaudRate(br : BAUD) return boolean is
	begin
		for i in C_IO_UART_TYPICAL_BAUDRATES'range loop
			next when (br /= C_IO_UART_TYPICAL_BAUDRATES(i));
			return TRUE;
		end loop;
		return FALSE;
	end function;
end package body;
