-- =============================================================================
-- Authors:					Thomas B. Preusser
--
-- Entity:					Universal Asynchronous Receiver Transmitter (UART) - Transmitter
--
-- Description:
-- -------------------------------------
-- :abbr:`UART (Universal Asynchronous Receiver Transmitter)` Transmitter:
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
--
-- License:
-- =============================================================================
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

library	IEEE;
use IEEE.std_logic_1164.all;

use     work.uart.all;

entity uart_tx is
	generic(
		PARITY : T_UART_PARITY_MODE  := PARITY_NONE  --PARITY_EVEN, PARITY_ODD,PARITY_NONE
	);
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
end entity;


library IEEE;
use IEEE.numeric_std.all;

architecture rtl of uart_tx is

	--                Buf            Cnt
	--   Idle     "----------1"    "0----"
	--   Start    "1hgfedcba01"     -10
	--   Send     "11111hgfedc"   -10 -> -1
	--   Done     "11111111111"       0
	
	signal Buf : std_logic_vector(10 downto 0) := (0 => '1', others => '-');
	signal Cnt : signed(4 downto 0)           := "0----";
	signal parity_bit : std_logic;

begin
	paritycal:process(di)
		begin
			case PARITY is
			when PARITY_EVEN =>
			-- Even parity: parity_bit is '1' if the number of '1's in di is odd (to make total even)
					parity_bit <= xor(di);
			when PARITY_ODD =>
			-- Odd parity: parity_bit is '1' if the number of '1's in di is even (to make total odd)
					parity_bit <=  not (xor(di));
			when others =>
			-- No parity (PARITY = "NONE"): parity_bit not used
					parity_bit <= '0';
		end case;
	end process;
	
	process(clk)
		begin
			if rising_edge(clk) then
				if rst = '1' then
					Buf <= (0 => '1', others => '-');
					Cnt <= "0----";
				else
					if Cnt(Cnt'left) = '0' then -- Idle
						if put = '1' then -- Start Transmission
							if PARITY = PARITY_NONE then 
								Buf <= "1" & di & "01";
								Cnt <= to_signed(-10, Cnt'length);
							else
								Buf <= parity_bit & di & "01"; 
								Cnt <= to_signed(-11, Cnt'length);
							end if;
						else
							Buf <= (0 => '1', others => '-');
							Cnt <= "0----";
						end if;
					else -- Transmitting
						if bclk = '1' then
							Buf <= '1' & Buf(Buf'left downto 1);
							Cnt <= Cnt + 1;
						end if;
					end if;
				end if;
			end if;
	end process;
	tx  <= Buf(0);
	ful <= Cnt(Cnt'left);
end;
