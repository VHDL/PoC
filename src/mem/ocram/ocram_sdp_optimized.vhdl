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
-- For simulation, always our dedicated simulation model :ref:`IP:ocram_tdp_sim`
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

library  IEEE;
use      IEEE.std_logic_1164.all;
use      IEEE.numeric_std.all;

use      work.config.all;
use      work.utils.all;
use      work.strings.all;
use      work.vectors.all;
use      work.mem.all;


entity ocram_sdp_optimized is
  generic (
    A_BITS    : positive;                              -- number of address bits
    D_BITS    : positive;                              -- number of data bits
    RAM_TYPE  : T_RAM_TYPE := RAM_TYPE_AUTO;
    FILENAME  : string    := ""                        -- file-name for RAM initialization
  );
  port (
    rclk  : in  std_logic;                            -- read clock
    rce    : in  std_logic;                            -- read clock-enable
    wclk  : in  std_logic;                            -- write clock
    wce    : in  std_logic;                            -- write clock-enable
    we    : in  std_logic;                            -- write enable
    ra    : in  unsigned(A_BITS-1 downto 0);          -- read address
    wa    : in  unsigned(A_BITS-1 downto 0);          -- write address
    d      : in  std_logic_vector(D_BITS-1 downto 0);  -- data in
    q      : out std_logic_vector(D_BITS-1 downto 0)    -- data out
  );
end entity;


architecture rtl of ocram_sdp_optimized is
    constant RAM_Type_Depth : T_INTVEC := get_ram_type(A_BITS, D_BITS);

    constant BRAM_width : integer := get_BRAM_half_width(A_BITS);

    constant U_Low_Bit  : integer := 0;
    constant U_High_Bit : integer := ite((RAM_Type_Depth(0) * 72) > D_BITS, D_BITS, (RAM_Type_Depth(0) * 72)) -1;
    constant B_Low_Bit  : integer := U_High_Bit +1;
    constant B_High_Bit : integer := ite((RAM_Type_Depth(1) * BRAM_width + U_High_Bit +1) > D_BITS, D_BITS -1, (RAM_Type_Depth(1) * BRAM_width + U_High_Bit));
    constant L_Low_Bit  : integer := B_High_Bit +1;
    constant L_High_Bit : integer := D_BITS -1;

    constant debug_ranges : boolean := false;
begin
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: D_BITS      : " & integer'image(D_BITS)     severity warning;
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: U-Ram-Depth : " & integer'image(RAM_Type_Depth(0))     severity warning;
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: B-Ram-Depth : " & integer'image(RAM_Type_Depth(1))     severity warning;
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: BRAM_width  : " & integer'image(BRAM_width)     severity warning;
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: U_Low_Bit   : " & integer'image(U_Low_Bit)  severity warning;
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: U_High_Bit  : " & integer'image(U_High_Bit) severity warning;
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: B_Low_Bit   : " & integer'image(B_Low_Bit)  severity warning;
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: B_High_Bit  : " & integer'image(B_High_Bit) severity warning;
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: L_Low_Bit   : " & integer'image(L_Low_Bit)  severity warning;
  assert not debug_ranges report "PoC.ocram_sdp_optimized:: L_High_Bit  : " & integer'image(L_High_Bit) severity warning;

  optimized_gen : if RAM_TYPE = RAM_TYPE_OPTIMIZED and RAM_Type_Depth(0) /= -1 generate
    genURAM : if RAM_Type_Depth(0) > 0 generate
    begin
      -- Backing Memory
      ram : entity work.ocram_sdp
      generic map (
        A_BITS => A_BITS,
        D_BITS => U_High_Bit - U_Low_Bit +1,
        RAM_TYPE => RAM_TYPE_ULTRA_RAM
      )
      port map (
        wclk   => wclk,
        rclk   => rclk,
        wce    => wce,

        wa     => wa,
        we     => we,
        d      => d(U_High_Bit downto U_Low_Bit),

        ra     => ra,
        rce    => rce,
        q      => q(U_High_Bit downto U_Low_Bit)
      );
    end generate;
    genBRAM : if RAM_Type_Depth(1) > 0 generate
    begin
      -- Backing Memory
      ram : entity work.ocram_sdp
      generic map (
        A_BITS => A_BITS,
        D_BITS => B_High_Bit - B_Low_Bit +1,
        RAM_TYPE => RAM_TYPE_BLOCK_RAM
      )
      port map (
        wclk   => wclk,
        rclk   => rclk,
        wce    => wce,

        wa     => wa,
        we     => we,
        d      => d(B_High_Bit downto B_Low_Bit),

        ra     => ra,
        rce    => rce,
        q      => q(B_High_Bit downto B_Low_Bit)
      );
    end generate;
    genLRAM : if L_High_Bit >= L_Low_Bit generate
    begin
      -- Backing Memory
      ram : entity work.ocram_sdp
      generic map (
        A_BITS => A_BITS,
        D_BITS => L_High_Bit - L_Low_Bit +1,
        RAM_TYPE => RAM_TYPE_LUT_RAM
      )
      port map (
        wclk   => wclk,
        rclk   => rclk,
        wce    => wce,

        wa     => wa,
        we     => we,
        d      => d(L_High_Bit downto L_Low_Bit),

        ra     => ra,
        rce    => rce,
        q      => q(L_High_Bit downto L_Low_Bit)
      );
    end generate;
  else generate
    ram : entity work.ocram_sdp
    generic map(
      A_BITS    => A_BITS,
      D_BITS    => D_BITS,
      RAM_TYPE  => RAM_TYPE,
      FILENAME  => FILENAME
    )
    port map(
      rclk  => rclk,
      rce    => rce,
      wclk  => wclk,
      wce    => wce,
      we    => we,
      ra    => ra,
      wa    => wa,
      d      => d,
      q      => q
    );

  end generate;
end architecture;
