-- =============================================================================
-- Authors:        Thomas B. Preusser
--
-- Entity:				 Universal Asynchronous Receiver Transmitter (UART) - Receiver
--
-- Description:
-- -------------------------------------
-- 1 Start + 8 Data + [1 parity] + 1 Stop
-- if data is "01000110" and with even parity the frame will be 0 + 01100010 + 1 + 1
--                           with odd  parity the frame will be 0 + 01100010 + 0 + 1
--                           with no   parity the frame will be 0 + 01100010 + 1
--     8 bits of data |(count of 1-bits)|  8 bits including parity
--                    |                 |   even	      odd
--     00000000       |	     0	        |  000000000   000000001
--     10100010       |	     3	        |  101000101   101000100
--     11010010       |	     4	        |  110100100   110100101
--     11111110       |	     7	        |  111111101   111111100
-- When parity error occured, 
-- if PARITY_ERROR_HANDLING = PASSTHROUGH_ERROR_BYTE then error byte passed to FIFO 
--                          = REPLACE_ERROR_BYTE then error byte will replaced with PARITY_ERROR_IDENTIFIER which is generic 
--                          = DROP_ERROR_BYTE then error byte will be dropped 
-- and all three scenarios, error flag will be raised.
-- License:
-- =============================================================================
-- Copyright 2008-2016 Technische Universitaet Dresden - Germany
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

library	IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.uart.all;

entity uart_rx is
	generic (
		SYNC_DEPTH              : natural                      := 2;  -- use zero for already clock-synchronous rx
		PARITY                  : T_UART_PARITY_MODE           := PARITY_NONE;  --PARITY_EVEN, PARITY_ODD, PARITY_NONE
		PARITY_ERROR_HANDLING   : T_UART_PARITY_ERROR_HANDLING := PASSTHROUGH_ERROR_BYTE; --PASSTHROUGH_ERROR_BYTE,REPLACE_ERROR_BYTE
		PARITY_ERROR_IDENTIFIER : std_logic_vector(7 downto 0) := x"15" -- ^NAK
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
		stb : out std_logic;
		parity_error : out std_logic
	);
end entity;


architecture rtl of uart_rx is
	-- RX Synchronization
	signal rxs : std_logic;

	--                Buf         Cnt  Vld
	--   Idle     "----------0"    X    0
	--   Start    "01111111111"  5->16  0   -- 1.5 bit length after start of start bit
	--   Recv     "dcba0111111"  9->16  0   -- shifting left to right (LSB first)
	--   Done     "11hgfedcba0"    X    1   -- Output strobe, without parity

	-- Data buffer
	signal Buf : std_logic_vector(10 downto 0) := (0      => '0', others => '-');
	-- Bit clock counter: 8 ticks per bit
	signal Cnt : unsigned(4 downto 0)         := (others => '-');
	-- Output strobe
	signal Vld                 : std_logic := '0';
	signal parity_bit_cal      : std_logic := '0';
	signal parity_bit          : std_logic := '0';
	signal parity_error_flag   : std_logic := '0';
	

begin
  -- Input synchronization
	sync :  entity work.sync_Bits
		generic map (
			INIT					=> (SYNC_DEPTH - 1 downto 0 => '1'),	-- initialitation bits
			SYNC_DEPTH		=> SYNC_DEPTH													-- generate SYNC_DEPTH many stages, at least 2
		)
		port map (
			Clock					=> clk,		-- <Clock>	output clock domain
			Input(0)			=> rx,		-- @async:	input bits
			Output(0)			=> rxs		-- @Clock:	output bits
		);
	paritycal: process(Buf)
		begin
			case PARITY is
			when PARITY_EVEN =>
			-- Even parity: parity_bit_cal is '1' if the number of '1's in data is odd (to make total even)
					parity_bit_cal <= xor(Buf(9 downto 2));
			when PARITY_ODD =>
			-- Odd parity: parity_bit_cal is '1' if the number of '1's in data is even (to make total odd)
					parity_bit_cal <=  not (xor(Buf(9 downto 2)));
			when others =>
			-- No parity (PARITY = "NONE"): parity_bit_cal not used
					parity_bit_cal <= '0';
		end case;
	end process;
	-- Reception state
	process(clk)
	begin
		if rising_edge(clk) then
			Vld <= '0';
			parity_error_flag <= '0';
			if rst = '1' then
				Buf <= (0      => '0', others => '-');
				Cnt <= (others => '-');
			else
				if Buf(0) = '0' or Vld ='1' then
					-- Idle
					if rxs = '0' then
						-- Start bit -> receive byte
						Buf <= (Buf'left => '0', others => '1');
						Cnt <= to_unsigned(5, Cnt'length);
					else
						Buf <= (0 => '0', others => '-');
						Cnt <= (others => '-');
					end if;
				elsif bclk_x8 = '1' then
					parity_bit <= Buf(10);
					if Cnt(Cnt'left) = '1' then					  
						Buf <= rxs & Buf(Buf'left downto 1);							
						if PARITY = PARITY_NONE then 
							Vld <= rxs and not Buf(2);	
						elsif Buf(1) = '0' then 
							if parity_bit /= parity_bit_cal then							
								parity_error_flag <= '1';
							end if;
							Vld <= rxs;
						end if;
					end if;
					Cnt <= Cnt + (Cnt(4) & Cnt(4) & "001");
				end if;
			end if;
		end if;
	end process;

	-- Outputs
	ouput:process(all)
		begin
			if PARITY = PARITY_NONE then 
				do  <= Buf(9 downto 2);
				stb <= Vld;
			elsif parity_error_flag = '1' then
				if PARITY_ERROR_HANDLING = DROP_ERROR_BYTE then 
					do  <= Buf(8 downto 1);
					stb <= '0';
				elsif PARITY_ERROR_HANDLING = PASSTHROUGH_ERROR_BYTE then 
					do  <= Buf(8 downto 1);
					stb <= Vld;
				elsif PARITY_ERROR_HANDLING = REPLACE_ERROR_BYTE then  
					do  <= PARITY_ERROR_IDENTIFIER;
					stb <= Vld;
				end if;
			else 
				do  <= Buf(8 downto 1); 
				stb <= Vld and not parity_error_flag;
			end if;
		end process;	
	parity_error <= parity_error_flag;

end architecture;
