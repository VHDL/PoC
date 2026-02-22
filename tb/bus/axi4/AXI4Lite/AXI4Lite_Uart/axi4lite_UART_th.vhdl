-- =============================================================================
-- Authors:
--   Stefan Unrein
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.AXI4Lite_OSVVM.all;
use     PoC.physical.all;
use     PoC.vectors.all;
use     PoC.utils.all;
use     PoC.axi4lite.all;
use     PoC.uart.all;

library OSVVM;
context OSVVM.OsvvmContext;

library OSVVM_Axi4;
context OSVVM_Axi4.Axi4LiteContext;

library OSVVM_uart;
context OSVVM_uart.UartContext;


entity axi4lite_UART_th is
end entity;


architecture TestHarness of axi4lite_UART_th is
	constant CLOCK_FREQ     : FREQ    := 100 MHz;
	constant BAUDRATE       : BAUD    := 115.200 kBd;

	constant AXI_ADDR_WIDTH : integer := 32;
	constant AXI_DATA_WIDTH : integer := 32;
	constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH / 8;

	constant tperiod_Clk : time := to_time(CLOCK_FREQ);
	constant tpd         : time := 0 ns;

	signal Clock         : std_logic := '1';
	signal Reset         : std_logic := '1';

	-- Transaction interfaces
	signal AXI_Manager : AddressBusRecType(
		Address(AXI_ADDR_WIDTH - 1 downto 0),
		DataToModel(AXI_DATA_WIDTH - 1 downto 0),
		DataFromModel(AXI_DATA_WIDTH - 1 downto 0)
	);
	signal UartTxRec  : UartRecType;
	signal UartRxRec  : UartRecType;

	-- AXI Manager physical Interface
	signal AxiBus : Axi4LiteRecType(
		WriteAddress(Addr(AXI_ADDR_WIDTH - 1 downto 0)),
		WriteData(Data(AXI_DATA_WIDTH - 1 downto 0), Strb(AXI_STRB_WIDTH-1 downto 0)),
		ReadAddress (Addr(AXI_ADDR_WIDTH-1 downto 0)),
		ReadData    (Data(AXI_DATA_WIDTH-1 downto 0))
	);

	signal UART_AXI4Lite_m2s : T_AXI4LITE_BUS_M2S(
		AWAddr(AXI_ADDR_WIDTH - 1 downto 0),
		WData(AXI_DATA_WIDTH - 1 downto 0),
		WStrb(AXI_STRB_WIDTH-1 downto 0),
		ARAddr(AXI_ADDR_WIDTH - 1 downto 0)
	);
	signal UART_AXI4Lite_s2m : T_AXI4LITE_BUS_S2M(
		RData(AXI_DATA_WIDTH - 1 downto 0)
	);

	-- Uart Interface
	signal UART_TX : std_logic := 'H';
	signal UART_RX : std_logic := 'H';

	component axi4lite_UART_tc
		port(
			Reset               : in    std_logic;

			AXI_Manager         : inout AddressBusRecType;

			UartTxRec           : inout UartRecType;
			UartRxRec           : inout UartRecType
		);
	end component;

begin
	-- Create system clock
	clk: Osvvm.ClockResetPkg.CreateClock(
		Clk             => Clock,
		Period          => tperiod_Clk
	);

	-- Create system reset
	rst: Osvvm.ClockResetPkg.CreateReset (
		Reset           => Reset,
		ResetActive     => '1',
		Clk             => Clock,
		Period          => 7 * tperiod_Clk,
		tpd             => tpd
     );

	-- AXI4Lite configuration manager
	manager: entity OSVVM_AXI4.Axi4LiteManager
		generic map (
			DEFAULT_DELAY => tpd
		)
		port map (
			Clk         => Clock,
			nReset      => not Reset,

			-- Transaction interface from TestController
			TransRec    => AXI_Manager,

			-- AXI manager physical interface
			AxiBus      => AxiBus
		);

	-- mapping between PoC and OSVVM AXI bus types
	to_PoC_AXI4Lite_Bus_Master(UART_AXI4Lite_m2s, UART_AXI4Lite_s2m, AXIBus);

	dut: entity PoC.AXI4Lite_Uart
		generic map (
			CLOCK_FREQ   => CLOCK_FREQ,
			BAUDRATE     => BAUDRATE,
			FLOWCONTROL  => UART_FLOWCONTROL_NONE
		)
		port map (
			Clock        => Clock,
			Reset	       => Reset,

			AXI4Lite_m2s => UART_AXI4Lite_m2s,
			AXI4Lite_s2m => UART_AXI4Lite_s2m,
			AXI4Lite_irq => open,

			UART_TX	     => UART_TX,
			UART_RX	     => UART_RX,
			UART_RTS     => open,
			UART_CTS     => 'U'
		);

	rx: entity OSVVM_UART.UartRx
		generic map (
			DEFAULT_BAUD        => UART_BAUD_PERIOD_115200,
			DEFAULT_PARITY_MODE => UARTTB_PARITY_NONE --UARTTB_PARITY_EVEN,UARTTB_PARITY_NONE,UARTTB_PARITY_ODD
		)
		port map (
			TransRec            => UartRxRec,
			SerialDataIn        => UART_TX
		);

	tx: entity OSVVM_UART.UartTx
		generic map (
			DEFAULT_BAUD        => UART_BAUD_PERIOD_115200,
			DEFAULT_PARITY_MODE => UARTTB_PARITY_NONE  
		)
		port map (
			TransRec            => UartTxRec,
			SerialDataOut       => UART_RX
		);

	TestCtrl: component axi4lite_UART_tc
		port map (
			Reset               => Reset,
			AXI_Manager         => AXI_Manager,
			UartTxRec           => UartTxRec,
			UartRxRec           => UartRxRec
		);
end architecture;
