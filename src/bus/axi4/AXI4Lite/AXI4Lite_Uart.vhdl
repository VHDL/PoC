-- =============================================================================
-- Authors:
--   Nimitha Mallikarjuna
--   Srikanth Boppudi
--
-- Entity:
--
-- Description:
-- -------------------------------------
-- Implement AXI4-Lite UART with hardware and software flowcontrol.
--
-- This component has the same register set as AMD's AXI UARTLite.
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

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use work.axi4lite.all;
use work.vectors.all;
use work.physical.all;
use work.components.all;
use work.utils.all;
use work.uart.all;

entity AXI4Lite_Uart is
	generic (

			--uart communication parameters
			CLOCK_FREQ              : FREQ;
			BAUDRATE                : BAUD                          := 115.200 kBd;
			PARITY                  : T_UART_PARITY_MODE            := PARITY_NONE; --PARITY_EVEN, PARITY_ODD,PARITY_NONE
			PARITY_ERROR_HANDLING   : T_UART_PARITY_ERROR_HANDLING  := PASSTHROUGH_ERROR_BYTE; --PASSTHROUGH_ERROR_BYTE,REPLACE_ERROR_BYTE,DROP_ERROR_BYTE
			PARITY_ERROR_IDENTIFIER : std_logic_vector(7 downto 0)  := x"15"; --^ NAK
			ADD_INPUT_SYNCHRONIZERS : boolean                       := TRUE;

			--Buffer dimensions
			TX_FIFO_DEPTH           : positive                      := 16;
			RX_FIFO_DEPTH           : positive                      := 16;

			--Flow Control
			FLOWCONTROL             : T_IO_UART_FLOWCONTROL_KIND    := UART_FLOWCONTROL_NONE;
			SWFC_XON_CHAR           : std_logic_vector(7 downto 0)  := x"11";  -- ^Q
			SWFC_XOFF_CHAR          : std_logic_vector(7 downto 0)  := x"13"  -- ^S
	);
	port (
			Clock                   : in  std_logic;
			Reset                   : in  std_logic;

			AXI4Lite_m2s            : in  T_AXI4LITE_BUS_M2S;
			AXI4Lite_s2m            : out T_AXI4LITE_BUS_S2M;
			AXI4Lite_irq            : out std_logic;

			--External Pins
			UART_TX                 : out std_logic;
			UART_RX                 : in  std_logic;
			UART_RTS                : out std_logic;
			UART_CTS                : in  std_logic
	);
end entity;


architecture rtl of AXI4Lite_Uart is
	constant TX_EMPTY_STATE_BITS : natural := 4;
	constant RX_FULL_STATE_BITS  : natural := 4;

	constant Reg_config : T_AXI4_Register_Vector := (
		to_AXI4_Register(Name => "Rx",      Address => 32x"00", RegisterMode => ReadOnly_NotRegistered,      Init_Value => x"00000000"),
		to_AXI4_Register(Name => "Tx",      Address => 32x"04", RegisterMode => ReadWrite_NotRegistered, Init_Value => x"00000000"),
		to_AXI4_Register(Name => "Status",  Address => 32x"08", RegisterMode => ReadOnly,  Init_Value => x"00000000"),
		to_AXI4_Register(Name => "Control", Address => 32x"0C", RegisterMode => ReadWrite, Init_Value => x"00000000")
	);

	subtype RegPortType      is T_SLVV(0 to (Reg_Config'length - 1))(31 downto 0);
	signal Reg_ReadPort      : RegPortType;
	signal Reg_WritePort     : RegPortType := (others => (others => '0'));
	signal Reg_ReadPort_hit  : std_logic_vector(RegPortType'range);
	signal Reg_WritePort_hit : std_logic_vector(RegPortType'range);

	--user required axi registers
	signal RX_Data           : std_logic_vector(7 downto 0);
	signal TX_Data           : std_logic_vector(7 downto 0);
	signal Status            : std_logic_vector(31 downto 0);
	signal Control           : std_logic_vector(31 downto 0);

	--Bit positions of the above registers
	signal Status_RX_Valid         : std_logic;
	signal Status_RX_Valid_d       : std_logic;
	signal RX_Got                  : std_logic;
	signal Control_RX_Reset        : std_logic;
	signal Status_InterruptEnable  : std_logic;
	signal Status_RX_Overrun       : std_logic;
	signal RX_OverFlow             : std_logic;
	signal Status_RX_Full          : std_logic;
	signal RX_StatusReg_hit        : std_logic;
	--signal status_Frame_Error      : std_logic;
	signal status_Parity_error     : std_logic;
	signal parity_error            : std_logic;

	signal TX_Put                  : std_logic;
	signal TXFIFO_Empty            : std_logic;
	signal TXFIFO_Empty_d          : std_logic;
	signal Status_TX_Full          : std_logic;
	signal Control_TX_Reset        : std_logic;
	signal Control_InterruptEnable : std_logic;

	signal Status_TX_EmptyState    : std_logic_vector(imax(0, TX_EMPTY_STATE_BITS - 1) downto 0);
	signal Status_RX_FullState     : std_logic_vector(imax(0, RX_FULL_STATE_BITS - 1) downto 0);


begin
	Reg : entity work.AXI4Lite_Register
		generic map(
			INIT_ON_RESET              => true,
			CONFIG                     => Reg_config
		)
		port map(
			Clock                      => Clock,
			Reset                      => Reset,

			AXI4Lite_m2s               => AXI4Lite_m2s,
			AXI4Lite_s2m               => AXI4Lite_s2m,

			RegisterFile_ReadPort      => Reg_ReadPort,
			RegisterFile_ReadPort_hit  => Reg_ReadPort_hit,
			RegisterFile_WritePort     => Reg_WritePort,
			RegisterFile_WritePort_hit => Reg_WritePort_hit
		);


	registerAssignments: block
		constant RX_IDX      : natural := get_index("RX",      Reg_config);
		constant TX_IDX      : natural := get_index("TX",      Reg_config);
		constant STATUS_IDX  : natural := get_index("Status",  Reg_config);
		constant CONTROL_IDX : natural := get_index("Control", Reg_config);
	begin
		Reg_WritePort(RX_IDX)(RX_Data'range) <= RX_Data;
		RX_Got                               <= Reg_WritePort_hit(RX_IDX) ;
		RX_StatusReg_hit                     <= Reg_WritePort_hit(STATUS_IDX); -- to check overflow flag read or not

		Reg_WritePort(STATUS_IDX)(0)         <= Status_RX_Valid;                         -- ULITE_STATUS_RXVALID
		Reg_WritePort(STATUS_IDX)(1)         <= Status_RX_Full;                          -- ULITE_STATUS_RXFULL
		Reg_WritePort(STATUS_IDX)(2)         <= TXFIFO_Empty;                            -- ULITE_STATUS_TXEMPTY
		Reg_WritePort(STATUS_IDX)(3)         <= Status_TX_Full;                          -- ULITE_STATUS_TXFULL
		Reg_WritePort(STATUS_IDX)(4)         <= Status_InterruptEnable;                  -- ULITE_STATUS_IE
		Reg_WritePort(STATUS_IDX)(5)         <= Status_RX_Overrun;                       -- ULITE_STATUS_OVERRUN
		--Reg_WritePort(STATUS_IDX)(6)         <= status_Frame_Error;                    -- Need to configure later
		Reg_WritePort(STATUS_IDX)(7)         <= status_Parity_error;                   -- Need to configure later

		Control_RX_Reset                     <= Reg_ReadPort(CONTROL_IDX)(0);
		Control_TX_Reset                     <= Reg_ReadPort(CONTROL_IDX)(1);
		Control_InterruptEnable              <= Reg_ReadPort(CONTROL_IDX)(4);

		TX_Put                               <= Reg_ReadPort_hit(TX_IDX);
		TX_Data                              <= Reg_ReadPort(TX_IDX)(TX_Data'range);
	end block;



	Status_InterruptEnable  <= Control_InterruptEnable;
	Status_RX_Overrun   <= ffrs(q =>Status_RX_Overrun , rst => (Reset or RX_StatusReg_hit) ,   set => RX_OverFlow) when rising_edge(Clock);
	status_Parity_error <= ffrs(q =>status_Parity_error , rst => (Reset or RX_StatusReg_hit) , set => parity_error) when rising_edge(Clock);

	Status_RX_Valid_d <= Status_RX_Valid when rising_edge(Clock); -- Delay flag by one CC
	TXFIFO_Empty_d    <= TXFIFO_Empty    when rising_edge(Clock); -- Delay flag by one CC
	AXI4Lite_irq        <= Status_InterruptEnable when ((Status_RX_Valid and not Status_RX_Valid_d) or (TXFIFO_Empty and not TXFIFO_Empty_d)) = '1' else '0'; -- Create IRQ for rising-edge of both flags



	UART : entity work.uart_fifo
		generic map (
			-- Communication Parameters
			CLOCK_FREQ              => CLOCK_FREQ,
			BAUDRATE                => BAUDRATE,
			PARITY                  => PARITY,
			PARITY_ERROR_HANDLING   => PARITY_ERROR_HANDLING,
			PARITY_ERROR_IDENTIFIER => PARITY_ERROR_IDENTIFIER,
			ADD_INPUT_SYNCHRONIZERS => ADD_INPUT_SYNCHRONIZERS,

			-- Buffer Dimensioning
			TX_MIN_DEPTH            => TX_FIFO_DEPTH,
			TX_ESTATE_BITS          => TX_EMPTY_STATE_BITS,
			RX_MIN_DEPTH            => RX_FIFO_DEPTH,
			RX_FSTATE_BITS          => RX_FULL_STATE_BITS,

			-- Flow Control
			FLOWCONTROL             => FLOWCONTROL,
			SWFC_XON_CHAR           => SWFC_XON_CHAR,
			-- SWFC_XON_TRIGGER  =>  ,
			SWFC_XOFF_CHAR          => SWFC_XOFF_CHAR
			-- SWFC_XOFF_TRIGGER  =>
		)
		port map (
			Clock          => Clock,
			Reset          => Reset,

			-- FIFO interface
			TX_put         => TX_Put,
			TX_Data        => TX_Data,
			TX_Full        => Status_TX_Full,
			TX_EmptyState  => Status_TX_EmptyState,
			TXFIFO_Reset   => Control_TX_Reset,
			TXFIFO_Empty   => TXFIFO_Empty,


			RX_Valid       => Status_RX_Valid,
			RX_Data        => RX_Data,
			RX_got         => RX_Got,
			RX_FullState   => Status_RX_FullState,
			RX_Overflow    => RX_OverFlow,
			RXFIFO_Full    => Status_RX_Full,
			RXFIFO_Reset   => Control_RX_Reset,

			-- External pins
			UART_TX         => UART_TX,
			UART_RX         => UART_RX,
			UART_RTS        => UART_RTS,
			UART_CTS        => UART_CTS,
			UART_parity_error => parity_error
		);

end architecture;
