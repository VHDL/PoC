-- =============================================================================
-- Authors:         Martin Zabel
--                  Patrick Lehmann
--
-- Entity:           UART Wrapper with Embedded FIFOs and Optional Flow Control
--
-- Description:
-- -------------------------------------
-- Small :abbr:`FIFO (first-in, first-out)` s are included in this module, if
-- larger or asynchronous transmit / receive FIFOs are required, then they must
-- be connected externally.
-- Flow control: In this module flow control(SW flowcontrol and HW flow control)
-- are implemented for UART. Threshold limits can be set for flow control by using the generic
-- parameters FLOWCTRL_XON_THRESHOLD,FLOWCTRL_XOFF_THRESHOLD.
-- := For exmaple:
-- FLOWCTRL_XOFF_THRESHOLD is set to 0.75,  if fifo filled upto = FIFO_DEPTH*0.75
-- gives the backpressure based the flow control that being used. To know more about
-- TX_ESTATE_BITS,RX_FSTATE_BITS please refer 'fifo_cc_got' module. User can change the
-- SWFC_XON/XOFF_CHAR if needed.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
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

use     work.vectors.all;
use     work.physical.all;
use     work.components.all;
use     work.utils.all;
use     work.uart.all;


entity uart_fifo is
	generic (
		-- Communication Parameters
		CLOCK_FREQ                      : FREQ;
		BAUDRATE                        : BAUD;
		PARITY                          : T_UART_PARITY_MODE           := PARITY_NONE;
		PARITY_ERROR_HANDLING           : T_UART_PARITY_ERROR_HANDLING := PASSTHROUGH_ERROR_BYTE;
		PARITY_ERROR_IDENTIFIER         : std_logic_vector(7 downto 0) := 8x"0";
		ADD_INPUT_SYNCHRONIZERS         : boolean := TRUE;

		-- Buffer Dimensioning
		TX_MIN_DEPTH                    : positive          := 16;
		TX_ESTATE_BITS                  : natural           := 0;
		RX_MIN_DEPTH                    : positive          := 16;
		RX_FSTATE_BITS                  : natural           := 0;

		FLOWCTRL_XON_THRESHOLD          : real := 0.0625;
		FLOWCTRL_XOFF_THRESHOLD         : real := 0.75;

		-- Flow Control
		FLOWCONTROL                     : T_IO_UART_FLOWCONTROL_KIND   := UART_FLOWCONTROL_NONE;
		SWFC_XON_CHAR                   : std_logic_vector(7 downto 0) := x"11";  -- ^Q

		SWFC_XOFF_CHAR                  : std_logic_vector(7 downto 0) := x"13"   -- ^S

	);
	port (
		Clock               : in  std_logic;
		Reset               : in  std_logic;

		-- FIFO interface
		TX_put              : in    std_logic;
		TX_Data             : in    std_logic_vector(7 downto 0);
		TX_Full             : out   std_logic;
		TX_EmptyState       : out   std_logic_vector(imax(0, TX_ESTATE_BITS-1) downto 0);
		TXFIFO_Reset        : in    std_logic;
		TXFIFO_Empty        : out   std_logic;

		RX_Valid            : out   std_logic;
		RX_Data             : out   std_logic_vector(7 downto 0);
		RX_got              : in    std_logic;
		RX_FullState        : out   std_logic_vector(imax(0, RX_FSTATE_BITS-1) downto 0);
		RX_Overflow         : out   std_logic;
		RXFIFO_Full         : out   std_logic;
		RXFIFO_Reset        : in    std_logic;

		-- External pins
		UART_TX             : out   std_logic;
		UART_RX             : in    std_logic;
		UART_RTS            : out   std_logic;
		UART_CTS            : in    std_logic;
		UART_parity_error   : out   std_logic
	);
end entity;


architecture rtl of uart_fifo is

	signal FC_TX_Strobe         : std_logic;
	signal FC_TX_Data           : T_SLV_8;
	signal FC_TX_got            : std_logic;
	signal FC_RX_put            : std_logic;
	signal FC_RX_Data           : T_SLV_8;

	signal TXFIFO_Valid         : std_logic;

	signal TXFIFO_Data          : T_SLV_8;

	signal RXFIFO_Full_int      : std_logic;
	signal RX_FullState_int     : std_logic_vector(imax(0, RX_FSTATE_BITS-1) downto 0);

	signal TXUART_Full          : std_logic;
	signal RXUART_Strobe        : std_logic;
	signal RXUART_Data          : T_SLV_8;



	signal BitClock             : std_logic;
	signal BitClock_x8          : std_logic;

	signal UART_RX_sync         : std_logic;

begin
	assert FALSE report "uart_fifo: BAUDRATE=: " & to_string(BAUDRATE, 3)  severity NOTE;


	-- ===========================================================================
	-- Transmit and Receive FIFOs
	-- ===========================================================================
	TXFIFO : entity work.fifo_cc_got
		generic map (
			D_BITS           => 8,                  -- Data Width
			MIN_DEPTH        => TX_MIN_DEPTH,       -- Minimum FIFO Depth
			DATA_REG         => TRUE,               -- Store Data Content in Registers
			STATE_REG        => FALSE,              -- Registered Full/Empty Indicators
			OUTPUT_REG       => FALSE,              -- Registered FIFO Output
			ESTATE_WR_BITS   => TX_ESTATE_BITS,     -- Empty State Bits
			FSTATE_RD_BITS   => 0                   -- Full State Bits
		)
		port map (
			rst             => Reset or TXFIFO_Reset,
			clk             => Clock,
			put             => TX_put,
			din             => TX_Data,
			full            => TX_Full,
			estate_wr       => TX_EmptyState,

			valid           => TXFIFO_Valid,
			dout            => TXFIFO_Data,
			got             => FC_TX_got,
			fstate_rd       => open
		);

	RXFIFO : entity work.fifo_cc_got
		generic map (
			D_BITS              => 8,                 -- Data Width
			MIN_DEPTH           => RX_MIN_DEPTH,      -- Minimum FIFO Depth
			DATA_REG            => TRUE,              -- Store Data Content in Registers
			STATE_REG           => FALSE,             -- Registered Full/Empty Indicators
			OUTPUT_REG          => FALSE,             -- Registered FIFO Output
			ESTATE_WR_BITS      => 0,                 -- Empty State Bits
			FSTATE_RD_BITS      => RX_FSTATE_BITS     -- Full State Bits
		)
		port map (
			rst             => Reset or RXFIFO_Reset,
			clk             => Clock,
			put             => FC_RX_put,
			din             => FC_RX_Data,
			full            => RXFIFO_Full_int,
			estate_wr       => open,

			valid           => RX_Valid,
			dout            => RX_Data,
			got             => RX_got,
			fstate_rd       => RX_FullState_int
		);

		RXFIFO_Full  <=  RXFIFO_Full_int;
		RX_FullState <=  RX_FullState_int;
		TXFIFO_Empty <=  NOT TXFIFO_Valid;


	genNOFC : if FLOWCONTROL = UART_FLOWCONTROL_NONE generate

	begin

		FC_TX_Strobe    <= TXFIFO_Valid and not TXUART_Full;
		FC_TX_Data      <= TXFIFO_Data;
		FC_TX_got       <= FC_TX_Strobe;

		FC_RX_put       <= RXUART_Strobe;
		FC_RX_Data      <= RXUART_Data;

		RX_Overflow      <= RXUART_Strobe and RXFIFO_Full_int;
	end generate;
	-- ===========================================================================
	-- Software Flow Control
	-- ===========================================================================
	genSWFC : if FLOWCONTROL = UART_FLOWCONTROL_XON_XOFF generate
		constant XON_TRIG       : integer := integer(FLOWCTRL_XON_THRESHOLD * real(2**RX_FSTATE_BITS));
		constant XOFF_TRIG      : integer := integer(FLOWCTRL_XOFF_THRESHOLD * real(2**RX_FSTATE_BITS));

		signal send_xoff        : std_logic;
		signal send_xon         : std_logic;

		signal set_xoff_transmitted     : std_logic;
		signal clr_xoff_transmitted     : std_logic;
		signal discard_user_tx          : std_logic;
		signal discard_user_rx          : std_logic;
		signal RxFifo_FullState         : integer := 0; -- receive fifo full_state

		-- registers
		signal xoff_transmitted         : std_logic := '0';
		signal transmit_enable          : std_logic := '1';
	begin
		RxFifo_FullState <= to_integer(unsigned(RX_FullState_int));
		--assert false report"FLOWCONTROL=" & T_IO_UART_FLOWCONTROL_KIND'image(FLOWCONTROL) & " is currently not supported!" severity failure;
		-- send XOFF only once when fill state goes above trigger level
		send_xoff <= not xoff_transmitted   when (RxFifo_FullState >= XOFF_TRIG) else '0';
		set_xoff_transmitted <= (not TXUART_Full)    when (RxFifo_FullState >= XOFF_TRIG) else '0';

		-- send XON only once when receive FIFO is almost empty
		send_xon <=  xoff_transmitted     when (RxFifo_FullState <= XON_TRIG) else '0';
		clr_xoff_transmitted <= (not TXUART_Full) when (RxFifo_FullState <= XON_TRIG) else '0';

		-- discard any user supplied XON/XOFF
		discard_user_tx <= '1' when (TXFIFO_Data = SWFC_XON_CHAR) or (TXFIFO_Data = SWFC_XOFF_CHAR) else '0';
		discard_user_rx <= '1' when (RXUART_Data = SWFC_XON_CHAR) or (RXUART_Data = SWFC_XOFF_CHAR) else '0';
		-- tx / tf control
		FC_TX_Data <= SWFC_XOFF_CHAR  when (send_xoff = '1') else
		              SWFC_XON_CHAR   when (send_xon  = '1') else
		              TXFIFO_Data;

		FC_TX_Strobe <= send_xoff or send_xon or (TXFIFO_Valid and transmit_enable and (not discard_user_tx)) ;
		FC_TX_got    <= (send_xoff nor send_xon) and TXFIFO_Valid and (not TXUART_Full);        -- always check TXFIFO_Valid
		-- rx / rf control
		FC_RX_put  <= (RXUART_Strobe and (not discard_user_rx)); -- always check RXFIFO_Full_int
		FC_RX_Data <= RXUART_Data;


		RX_Overflow      <= RXUART_Strobe and RXFIFO_Full_int;
		-- registers
		process (Clock)
		begin  -- process
			if rising_edge(Clock) then
				if  (reset or set_xoff_transmitted) = '1' then
						xoff_transmitted <= '1';
				elsif clr_xoff_transmitted = '1' then
						xoff_transmitted <= '0';
				end if;
				if reset = '1' then
					transmit_enable <= '1';
				elsif RXUART_Strobe = '1' then
					if RXUART_Data = SWFC_XOFF_CHAR  then
						transmit_enable <= '0';
					elsif RXUART_Data = SWFC_XON_CHAR then
						transmit_enable <= '1';
					end if;
				end if;
			end if;
		end process;
	end generate;
	-- ===========================================================================
	-- Hardware Flow Control
	-- ===========================================================================
	genHWFC1 : if FLOWCONTROL = UART_FLOWCONTROL_RTS_CTS generate
		constant RX_FSTATE_UPPER_LIMIT     : integer  := integer(FLOWCTRL_XOFF_THRESHOLD * real(2**RX_FSTATE_BITS));
		constant RX_FSTATE_LOWER_LIMIT     : integer  := integer(FLOWCTRL_XON_THRESHOLD * real(2**RX_FSTATE_BITS));
	begin
		--assert false report"FLOWCONTROL=" & T_IO_UART_FLOWCONTROL_KIND'image(FLOWCONTROL) & " is currently not supported!" severity failure;

		FC_TX_Strobe    <= TXFIFO_Valid and not TXUART_Full and UART_CTS;
		FC_TX_Data      <= TXFIFO_Data;
		FC_TX_got       <= FC_TX_Strobe;

		FC_RX_put       <= RXUART_Strobe;
		FC_RX_Data      <= RXUART_Data;
		RX_Overflow      <= RXUART_Strobe and RXFIFO_Full_int;

		RTS_process: process(Clock)
		begin
		if rising_edge(Clock) then
			if  TXUART_Full = '0' then
				if Reset = '1' then
					UART_RTS<='1';
				elsif (to_integer(unsigned(RX_FullState_int)) >= RX_FSTATE_UPPER_LIMIT)   then
					UART_RTS<='0';
				elsif (to_integer(unsigned(RX_FullState_int)) <= RX_FSTATE_LOWER_LIMIT)  then
					UART_RTS<='1';
				end if;
			end if;
		end if;
		end process;
	end generate;
	-- ===========================================================================
	-- Hardware Flow Control
	-- ===========================================================================
	genHWFC2 : if FLOWCONTROL = UART_FLOWCONTROL_RTR_CTS generate

	begin
		assert false report"FLOWCONTROL=" & T_IO_UART_FLOWCONTROL_KIND'image(FLOWCONTROL) & " is currently not supported!" severity failure;
	end generate;

	-- ===========================================================================
	-- BitClock, Transmitter, Receiver
	-- ===========================================================================
	genNoSync : if not ADD_INPUT_SYNCHRONIZERS generate
		UART_RX_sync <= UART_RX;
	end generate;
	genSync : if ADD_INPUT_SYNCHRONIZERS generate
		sync_i : entity work.sync_Bits
			port map (
				Clock         => Clock,               -- Clock to be synchronized to
				Input(0)      => UART_RX,             -- Data to be synchronized
				Output(0)     => UART_RX_sync         -- synchronised data
			);
	end generate;
	-- ===========================================================================
	-- BitClock, Transmitter, Receiver
	-- ===========================================================================
	bclk : entity work.uart_bclk
		generic map (
			CLOCK_FREQ  => CLOCK_FREQ,
			BAUDRATE    => BAUDRATE
		)
		port map (
			clk         => Clock,
			rst         => Reset,
			bclk        => BitClock,
			bclk_x8     => BitClock_x8
		);

	TX : entity work.uart_tx
		generic map (
			PARITY  => PARITY
		)
		port map (
			clk     => Clock,
			rst     => Reset,
			bclk    => BitClock,
			tx      => UART_TX,
			di      => FC_TX_Data,
			put     => FC_TX_Strobe,
			ful     => TXUART_Full
		);

	RX : entity work.uart_rx
		generic map (
			PARITY  => PARITY,
			PARITY_ERROR_HANDLING   => PARITY_ERROR_HANDLING,
			PARITY_ERROR_IDENTIFIER => PARITY_ERROR_IDENTIFIER
		)
		port map (
			clk     => Clock,
			rst     => Reset,
			bclk_x8 => BitClock_x8,
			rx      => UART_RX_sync,
			do      => RXUART_Data,
			stb     => RXUART_Strobe,
			parity_error => UART_parity_error
		);

end architecture;
