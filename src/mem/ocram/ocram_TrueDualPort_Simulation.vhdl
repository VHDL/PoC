-- =============================================================================
-- Authors:           Martin Zabel
--
-- Entity:           Simulation model for true dual-port memory.
--
-- Description:
-- -------------------------------------
-- Simulation model for true dual-port memory, with:
--
-- * dual clock, clock enable,
-- * 2 read/write ports.
--
-- The interface matches that of the IP core PoC.mem.ocram.tdp.
-- But the implementation there is restricted to the description supported by
-- various synthesis compilers. The implementation here also simulates the
-- correct Mixed-Port Read-During-Write Behavior and handles X propagation.
--
-- License:
-- =============================================================================
-- Copyright 2016-2016 Technische Universitaet Dresden - Germany
--                     Chair for VLSI-Design, Diagnostics and Architecture
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

use     work.utils.all;
use     work.strings.all;
use     work.vectors.all;
use     work.mem.all;


entity ocram_TrueDualPort_Simulation is
	generic (
		ADDRESS_BITS : positive;                              -- number of address bits
		DATA_BITS    : positive;                              -- number of data bits
		FILENAME     : string    := ""                        -- file-name for RAM initialization
	);
	port (
		PortA_Clock       : in  std_logic;                               -- clock for 1st port
		PortA_ClockEnable : in  std_logic;                               -- clock-enable for 1st port
		PortA_WriteEnable : in  std_logic;                               -- write-enable for 1st port
		PortA_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);       -- address for 1st port
		PortA_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);  -- write-data for 1st port
		PortA_DataOut     : out std_logic_vector(DATA_BITS-1 downto 0);  -- read-data from 1st port

		PortB_Clock       : in  std_logic;                               -- clock for 2nd port
		PortB_ClockEnable : in  std_logic;                               -- clock-enable for 2nd port
		PortB_WriteEnable : in  std_logic;                               -- write-enable for 2nd port
		PortB_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);       -- address for 2nd port
		PortB_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);  -- write-data for 2nd port
		PortB_DataOut     : out std_logic_vector(DATA_BITS-1 downto 0)   -- read-data from 2nd port
	);
end entity;


architecture sim of ocram_TrueDualPort_Simulation is
	constant WORDS : positive := 2**ADDRESS_BITS;

	signal ram : T_SLVV(0 to WORDS - 1)(DATA_BITS - 1 downto 0) := mem_InitMemory(FILENAME, WORDS, DATA_BITS);

	-- write to memory, 'X' means maybe write
	signal write1 : X01;
	signal write2 : X01;

	-- read only from memory, 'X' means maybe read
	signal read1  : X01;
	signal read2  : X01;
begin
	assert SIMULATION report "This model is only for simulation." severity error;

	-- handle 'U' as 'X'
	write1 <= to_x01(PortA_ClockEnable and PortA_WriteEnable);
	read1  <= to_x01(PortA_ClockEnable and not PortA_WriteEnable);
	write2 <= to_x01(PortB_ClockEnable and PortB_WriteEnable);
	read2  <= to_x01(PortB_ClockEnable and not PortB_WriteEnable);

	process (PortA_Clock, PortB_Clock)
		-- Flag and address indicating whether a write occurs in the current clock
		-- cycle. Set and cleared at the rising_edge of the port's clock.
		-- The write address is set to don't care when the write location is
		-- undefined, to match all addresses in collision checks from other port.
		variable writing1 : boolean;
		variable writing2 : boolean;
		variable waddr1   : unsigned(ADDRESS_BITS-1 downto 0);
		variable waddr2   : unsigned(ADDRESS_BITS-1 downto 0);

		-- Check for write-collision check on port 1. Only set during one execution
		-- of the process.
		variable check_wr1 : boolean;

		-- Flag and address indicating whether a read occurs in the current clock
		-- cycle. Set and cleared at the rising_edge of the port's clock.
		-- In opposition to the writing flag, the reading flag is only set if the
		-- address is well known and the read succeeded at the rising clock edge.
		-- A read fails afterwards if a write happens during the read clock cycle.
		variable reading1 : boolean;
		variable reading2 : boolean;
		variable raddr1   : unsigned(ADDRESS_BITS-1 downto 0);
		variable raddr2   : unsigned(ADDRESS_BITS-1 downto 0);

	begin  -- process
		check_wr1 := false;

		-- Writing to Memory
		-- =========================================================================
		if rising_edge(PortA_Clock) then
			writing1 := false;
			waddr1   := (others => '-');

			if write1 = '1' then
				-- RAM is definitely written ...
				writing1 := true;
				if is_x(std_logic_vector(PortA_Address)) then
					-- ... but address is unknown
					ram <= (others => (others => 'X'));
				else
					--- ... and address is well known
					waddr1 := PortA_Address;
					ram(to_integer(PortA_Address)) <= to_ux01(PortA_DataIn);
					-- writing2 and waddr2 are not yet up-to-date, check for
					-- write-collision below
					check_wr1 := true;
				end if;
				-- same-port read during write: return new data
				PortA_DataOut <= to_ux01(PortA_DataIn);

			elsif write1 = 'X' then
				-- RAM may be written ...
				writing1 := true;
				if is_x(std_logic_vector(PortA_Address)) then
					-- ... but address is unknown
					ram <= (others => (others => 'X'));
				else
					--- ... and address is well known
					waddr1 := PortA_Address;
					ram(to_integer(PortA_Address)) <= (others => 'X');
				end if;
				-- same-port read during write: unknown data
				PortA_DataOut <= (others => 'X');
			end if;
		end if;

		-- Must be executed after write to port 1 due to write-collsion check
		if rising_edge(PortB_Clock) then
			writing2 := false;
			waddr2   := (others => '-');

			if write2 = '1' then
				-- RAM is definitely written ...
				writing2 := true;
				if is_x(std_logic_vector(PortB_Address)) then
					-- ... but address is unknown
					ram <= (others => (others => 'X'));
				else
					--- ... and address is well known
					waddr2 := PortB_Address;
					-- writing1 and waddr1 are up-to-date, check for write-collision
					if writing1 and std_match(waddr1, PortB_Address) then
						ram(to_integer(PortB_Address)) <= (others => 'X');
					else
						ram(to_integer(PortB_Address)) <= to_ux01(PortB_DataIn);
					end if;
				end if;
				-- same-port read during write: return new data
				PortB_DataOut <= to_ux01(PortB_DataIn);

			elsif write2 = 'X' then
				-- RAM may be written ...
				writing2 := true;
				if is_x(std_logic_vector(PortB_Address)) then
					-- ... but address is unknown
					ram <= (others => (others => 'X'));
				else
					--- ... and address is well known
					waddr2 := PortB_Address;
					ram(to_integer(PortB_Address)) <= (others => 'X');
				end if;
				-- same-port read during write: unknown data
				PortA_DataOut <= (others => 'X');
			end if;
		end if;

		-- writing1 and waddr1 are up-to-date, check for write-collision
		if check_wr1 then
			if writing2 and std_match(waddr2, PortA_Address) then
				ram(to_integer(PortA_Address)) <= (others => 'X');
			end if;
		end if;

		-- Reading (only) from Memory
		-- =========================================================================
		if rising_edge(PortA_Clock) then
			reading1 := false;
			raddr1   := (others => '-');

			if read1 = '1' then
				-- Definitely read only from RAM ...
				if is_x(std_logic_vector(PortA_Address)) then
					-- ... but address is unknown
					PortA_DataOut <= (others => 'X');
				else
					-- check for mixed-port read-during-write
					if writing2 and std_match(PortA_Address,waddr2) then
						PortA_DataOut <= (others => 'X');
					else
						-- further checks are only required if address is well known
						reading1 := true;
						raddr1   := PortA_Address;
						PortA_DataOut <= ram(to_integer(PortA_Address));
					end if;
				end if;
			elsif read1 = 'X' then
				-- Maybe read only from RAM
				PortA_DataOut <= (others => 'X');
			end if;
		end if;

		if rising_edge(PortB_Clock) then
			reading2 := false;
			raddr2   := (others => '-');

			if read2 = '1' then
				-- Definitely read only from RAM ...
				if is_x(std_logic_vector(PortB_Address)) then
					-- ... but address is unknown
					PortB_DataOut <= (others => 'X');
				else
					-- check for mixed-port read-during-write
					if writing1 and std_match(PortB_Address,waddr1) then
						PortB_DataOut <= (others => 'X');
					else
						-- further checks are only required if address is well known
						reading2 := true;
						raddr2   := PortB_Address;
						PortB_DataOut <= ram(to_integer(PortB_Address));
					end if;
				end if;
			elsif read2 = 'X' then
				-- Maybe read only from RAM
				PortB_DataOut <= (others => 'X');
			end if;
		end if;

		-- Write-during-read check
		-- =========================================================================
		-- cannot be included in read part above, because check is performed on a
		-- following rising edge of the write clock (not read clock!).
		if rising_edge(PortA_Clock) and writing1 then
			if reading2 and std_match(raddr2, waddr1) then
				-- read is disturbed by a write during the read clock cycle
				PortB_DataOut <= (others => 'X');
			end if;
		end if;

		if rising_edge(PortB_Clock) and writing2 then
			if reading1 and std_match(raddr1, waddr2) then
				-- read is disturbed by a write during the read clock cycle
				PortA_DataOut <= (others => 'X');
			end if;
		end if;
	end process;

end architecture;
