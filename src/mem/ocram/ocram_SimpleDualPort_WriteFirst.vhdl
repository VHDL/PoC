-- =============================================================================
-- Authors:          Martin Zabel
--
-- Entity:           Simple dual-port memory with write-first behavior.
--
-- Description:
-- -------------------------------------
-- Inferring / instantiating simple dual-port memory, with:
--
-- * single clock, clock enable,
-- * 1 read port plus 1 write port.
--
-- Command truth table:
--
-- == == ===============================
-- ce we Command
-- == == ===============================
-- 0   X   No operation
-- 1   0   Read only from memory
-- 1   1   Read from and Write to memory
-- == == ===============================
--
-- Both reading and writing are synchronous to the rising-edge of the clock.
-- Thus, when reading, the memory data will be outputted after the
-- clock edge, i.e, in the following clock cycle.
--
-- Mixed-Port Read-During-Write
--   When reading at the write address, the read value will be the new data,
--   aka. "write-first behavior". Of course, the read is still synchronous,
--   i.e, the latency is still one clock cyle.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2008-2015 Technische Universitaet Dresden - Germany
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

use     work.ocram.all;

-- XXX: why is this not a mode to ocram_SimpleDualPort?
entity ocram_SimpleDualPort_WriteFirst is
	generic (
		ADDRESS_BITS : positive;                           -- number of address bits
		DATA_BITS    : positive;                           -- number of data bits
		FILENAME     : string    := ""                     -- file-name for RAM initialization
	);
	port (
		Clock         : in  std_logic;                               -- clock
		ClockEnable   : in  std_logic;                               -- clock-enable

		Write_Enable  : in  std_logic;                               -- write enable
		Write_Address : in  unsigned(ADDRESS_BITS-1 downto 0);       -- write address
		Write_DataIn  : in  std_logic_vector(DATA_BITS-1 downto 0);  -- data in

		Read_Address  : in  unsigned(ADDRESS_BITS-1 downto 0);       -- read address
		Read_DataOut  : out std_logic_vector(DATA_BITS-1 downto 0)   -- data out
	);
end entity;


architecture rtl of ocram_SimpleDualPort_WriteFirst is
	-- Implementation Notes:
	-- ---------------------
	--
	-- I have also checked a modified version of the unit `ocram_SinglePort` with just a
	-- single clock and an asynchronous read like::
	--
	--   process(clk)
	--   begin
	--     if rising_edge(clk) then
	--       if ce = '1' then
	--         ra_r <= ra;
	--       end if;
	--     end if;
	--   end process;
	--
	--   q <= ram(to_integer(ra_r));
	--
	-- But the result from various FPGA synthesis tools was as follows:
	--
	-- * Altera Quartus 13.0: adds proper bypass-logic as expected.
	--
	-- * Lattice Synthesis Engine: adds proper bypass-logic, but there was an
	--   unnecessary multiplexer for the read address to mimic the read enable.
	--
	-- * XST 14.7: RAM is mapped to Block-RAM which has not the desired
	--   read-during-write behavior and also no bypass logic is added. XST adds
	--   also an unnecessary multiplexer for the read address to mimic the read
	--   enable.
	--
	--   Enforcing distributed RAM gives the desired behavior when synthesizing
	--   just this unit. But synthesis has failed in complex projects when
	--   KEEP_HIERARCHY was set to NO.
	--
	-- * Vivado 2016.2: RAM is mapped to Block-RAM which has not the desired
	--   read-during-write behavior and also no bypass logic is added. Vivado
	--   adds also an unnecessary multiplexer for the read address to mimic the
	--   read enable.
	--
	--   Enforcing distributed RAM gives the desired behavior when synthesizing
	--   just this unit. Synthesis results have not yet been checked for larger
	--   designs.
	--
	-- Thus, the solution below is to explicitly implement the bypass logic.

	signal WriteData_d : Write_DataIn'subtype; -- write data
	signal Forward_d   : std_logic;            -- forward write data
	signal RAM_DataOut : Read_DataOut'subtype; -- RAM output

begin
	process(Clock)
	begin
		if rising_edge(Clock) then
			case to_x01(ClockEnable) is
				when '1' =>
					WriteData_d <= to_x01(Write_DataIn);
					Forward_d   <= addressIsEqual(Write_Address, Read_Address) and Write_Enable;

				when '0' =>    -- keep previous state
					null;

				when others => -- X propagation in simulation
					WriteData_d  <= (others => 'X');
					Forward_d <= 'X';
			end case;
		end if;
	end process;

	ram_sdp: entity work.ocram_SimpleDualPort
		generic map (
			ADDRESS_BITS => ADDRESS_BITS,
			DATA_BITS    => DATA_BITS,
			FILENAME     => FILENAME
		)
		port map (
			Write_Clock       => Clock,
			Write_ClockEnable => ClockEnable,
			Write_WriteEnable => Write_Enable,
			Write_Address     => Write_Address,
			Write_DataIn      => Write_DataIn,

			Read_Clock        => Clock,
			Read_ClockEnable  => ClockEnable,
			Read_Address      => Read_Address,
			Read_DataOut      => RAM_DataOut
		);

	with Forward_d select Read_DataOut <=
		WriteData_d     when '1',
		RAM_DataOut     when '0',
		(others => 'X') when others; -- X propagation in simulation
end architecture;
