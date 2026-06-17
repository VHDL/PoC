-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:          Simple dual-port memory.
--
-- Description:
-- -------------------------------------
-- Inferring / instantiating simple dual-port memory, with:
--
-- * dual clock, clock enable,
-- * 1 read port plus 1 write port.
--
-- Both reading and writing are synchronous to the rising-edge of the clock.
-- Thus, when reading, the memory data will be outputted after the
-- clock edge, i.e, in the following clock cycle.
--
-- The generalized behavior across Altera and Xilinx FPGAs since
-- Stratix/Cyclone and Spartan-3/Virtex-5, respectively, is as follows:
--
-- Mixed-Port Read-During-Write
--   When reading at the write address, the read value will be unknown which is
--   aka. "don't care behavior". This applies to all reads (at the same
--   address) which are issued during the write-cycle time, which starts at the
--   rising-edge of the write clock and (in the worst case) extends until the
--   next rising-edge of the write clock.
--
-- For simulation, always our dedicated simulation model :ref:`IP:ocram_TrueDualPort_sim`
-- is used.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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

use     work.config.all;
use     work.utils.all;
use     work.strings.all;
use     work.vectors.all;
use     work.mem.all;


entity ocram_SimpleDualPort_Optimized is
	generic (
		RAM_TYPE     : T_RAM_TYPE := RAM_TYPE_AUTO;
		ADDRESS_BITS : positive;                              -- number of address bits
		DATA_BITS    : positive;                              -- number of data bits
		FILENAME     : string    := ""                        -- file-name for RAM initialization
	);
	port (
		Write_Clock       : in  std_logic;                            -- write clock
		Write_ClockEnable : in  std_logic;                            -- write clock-enable
		Write_WriteEnable : in  std_logic;                            -- write enable
		Write_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);          -- write address
		Write_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);  -- data in

		Read_Clock        : in  std_logic;                            -- read clock
		Read_ClockEnable  : in  std_logic;                            -- read clock-enable
		Read_Address      : in  unsigned(ADDRESS_BITS-1 downto 0);          -- read address
		Read_DataOut      : out std_logic_vector(DATA_BITS-1 downto 0)    -- data out
	);
end entity;


architecture rtl of ocram_SimpleDualPort_Optimized is
	constant RAM_Type_Depth : integer_vector := get_ram_type(ADDRESS_BITS, DATA_BITS);

	constant BRAM_width : integer := get_BRAM_half_width(ADDRESS_BITS);

	constant U_Low_Bit  : integer := 0;
	constant U_High_Bit : integer := ite((RAM_Type_Depth(0) * 72) > DATA_BITS, DATA_BITS, (RAM_Type_Depth(0) * 72)) -1;
	constant B_Low_Bit  : integer := U_High_Bit +1;
	constant B_High_Bit : integer := ite((RAM_Type_Depth(1) * BRAM_width + U_High_Bit +1) > DATA_BITS, DATA_BITS -1, (RAM_Type_Depth(1) * BRAM_width + U_High_Bit));
	constant L_Low_Bit  : integer := B_High_Bit +1;
	constant L_High_Bit : integer := DATA_BITS -1;

	constant debug_ranges : boolean := false;
begin
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: D_BITS      : " & integer'image(DATA_BITS)     severity warning;
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: U-Ram-Depth : " & integer'image(RAM_Type_Depth(0))     severity warning;
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: B-Ram-Depth : " & integer'image(RAM_Type_Depth(1))     severity warning;
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: BRAM_width  : " & integer'image(BRAM_width)     severity warning;
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: U_Low_Bit   : " & integer'image(U_Low_Bit)  severity warning;
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: U_High_Bit  : " & integer'image(U_High_Bit) severity warning;
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: B_Low_Bit   : " & integer'image(B_Low_Bit)  severity warning;
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: B_High_Bit  : " & integer'image(B_High_Bit) severity warning;
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: L_Low_Bit   : " & integer'image(L_Low_Bit)  severity warning;
	assert not debug_ranges report "PoC.ocram_SimpleDualPort_optimized:: L_High_Bit  : " & integer'image(L_High_Bit) severity warning;

	optimized_gen : if RAM_TYPE = RAM_TYPE_OPTIMIZED and RAM_Type_Depth(0) /= -1 generate
		genURAM : if RAM_Type_Depth(0) > 0 generate
		begin
			-- Backing Memory
			ram : entity work.ocram_SimpleDualPort
			generic map (
				ADDRESS_BITS => ADDRESS_BITS,
				DATA_BITS => U_High_Bit - U_Low_Bit +1,
				RAM_TYPE => RAM_TYPE_ULTRA_RAM
			)
			port map (
				Write_Clock   => Write_Clock,
				Read_Clock   => Read_Clock,
				Write_ClockEnable    => Write_ClockEnable,

				Write_Address     => Write_Address,
				Write_WriteEnable     => Write_WriteEnable,
				Write_DataIn      => Write_DataIn(U_High_Bit downto U_Low_Bit),

				Read_Address     => Read_Address,
				Read_ClockEnable    => Read_ClockEnable,
				Read_DataOut      => Read_DataOut(U_High_Bit downto U_Low_Bit)
			);
		end generate;
		genBRAM : if RAM_Type_Depth(1) > 0 generate
		begin
			-- Backing Memory
			ram : entity work.ocram_SimpleDualPort
			generic map (
				ADDRESS_BITS => ADDRESS_BITS,
				DATA_BITS => B_High_Bit - B_Low_Bit +1,
				RAM_TYPE => RAM_TYPE_BLOCK_RAM
			)
			port map (
				Write_Clock   => Write_Clock,
				Read_Clock   => Read_Clock,
				Write_ClockEnable    => Write_ClockEnable,

				Write_Address     => Write_Address,
				Write_WriteEnable     => Write_WriteEnable,
				Write_DataIn      => Write_DataIn(B_High_Bit downto B_Low_Bit),

				Read_Address     => Read_Address,
				Read_ClockEnable    => Read_ClockEnable,
				Read_DataOut      => Read_DataOut(B_High_Bit downto B_Low_Bit)
			);
		end generate;
		genLRAM : if L_High_Bit >= L_Low_Bit generate
		begin
			-- Backing Memory
			ram : entity work.ocram_SimpleDualPort
			generic map (
				ADDRESS_BITS => ADDRESS_BITS,
				DATA_BITS => L_High_Bit - L_Low_Bit +1,
				RAM_TYPE => RAM_TYPE_LUT_RAM
			)
			port map (
				Write_Clock   => Write_Clock,
				Read_Clock   => Read_Clock,
				Write_ClockEnable    => Write_ClockEnable,

				Write_Address     => Write_Address,
				Write_WriteEnable     => Write_WriteEnable,
				Write_DataIn      => Write_DataIn(L_High_Bit downto L_Low_Bit),

				Read_Address     => Read_Address,
				Read_ClockEnable    => Read_ClockEnable,
				Read_DataOut      => Read_DataOut(L_High_Bit downto L_Low_Bit)
			);
		end generate;
	else generate
		ram : entity work.ocram_SimpleDualPort
		generic map(
			ADDRESS_BITS    => ADDRESS_BITS,
			DATA_BITS    => DATA_BITS,
			RAM_TYPE  => RAM_TYPE,
			FILENAME  => FILENAME
		)
		port map(
			Read_Clock  => Read_Clock,
			Read_ClockEnable    => Read_ClockEnable,
			Write_Clock  => Write_Clock,
			Write_ClockEnable    => Write_ClockEnable,
			Write_WriteEnable    => Write_WriteEnable,
			Read_Address    => Read_Address,
			Write_Address    => Write_Address,
			Write_DataIn      => Write_DataIn,
			Read_DataOut      => Read_DataOut
		);

	end generate;
end architecture;
