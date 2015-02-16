-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	Simple dual-port memory.
--
-- Authors:				 	Martin Zabel
--									Thomas B. Preusser
-- 
-- Description:
-- ------------------------------------
-- Inferring / instantiating simple dual-port memory.
--
-- - dual clock, clock enable
-- - 1 read port plus 1 write port
-- 
-- Reading at write address returns unknown data. Putting the different RAM
-- behaviours (Altera, Xilinx, some ASICs) together, then the Altera M512/M4K
-- TriMatrix memory defines the minimum time after which the written data can
-- be read out again. As stated in the Stratix Handbook, Volume 2, page 2-13,
-- data is actually written with the falling (instead of the rising) edge of
-- the clock. So that data can be read out after half of the write-clock period
-- plus the write-cycle time.
--
-- To generalize this behaviour, it can be assumed, that written data is 
-- available at the read-port with the next rising write!-clock edge. Both,
-- read- and write-clock edge might be at the same time, to satisfy this rule.
-- An example would be, that write- and read-clock are the same.
--
-- If latency is an issue, then memory blocks should be directly instantiated.
-- 
-- License:
-- ============================================================================
-- Copyright 2008-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
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
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.config.all;

entity ocram_sdp is
  
  generic (
    A_BITS : positive;-- := 10;
    D_BITS : positive--  := 32
  );

  port (
    rclk : in  std_logic;                             -- read clock
    rce  : in  std_logic;                             -- read clock-enable
    wclk : in  std_logic;                             -- write clock
    wce  : in  std_logic;                             -- write clock-enable
    we   : in  std_logic;                             -- write enable
    ra   : in  unsigned(A_BITS-1 downto 0);           -- read address
    wa   : in  unsigned(A_BITS-1 downto 0);           -- write address
    d    : in  std_logic_vector(D_BITS-1 downto 0);   -- data in
    q    : out std_logic_vector(D_BITS-1 downto 0));  -- data out

end ocram_sdp;

architecture rtl of ocram_sdp is

  constant DEPTH : positive := 2**A_BITS;
  
begin  -- rtl

  gInfer: if VENDOR = VENDOR_XILINX or VENDOR = VENDOR_ALTERA generate
    -- RAM can be infered correctly
    -- Xilinx notes:
    --   WRITE_MODE is set to WRITE_FIRST, but this also means that read data
    --   is unknown on the opposite port. (As expected.)
    -- Altera notes:
    --   Setting attribute "ramstyle" to "no_rw_check" supresses generation of
    --   bypass logic, when 'clk1'='clk2' and 'ra' is feed from a register.
    --   This is the expected behaviour.
    --   With two different clocks, synthesis complains about an undefined
    --   read-write behaviour, that can be ignored.
    type ram_t is array(0 to DEPTH-1) of std_logic_vector(D_BITS-1 downto 0);
    signal ram : ram_t;
    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "no_rw_check";
  begin
    process (wclk)
    begin
      if rising_edge(wclk) then
        if (wce and we) = '1' then
          ram(to_integer(wa)) <= d;
        end if;
      end if;
    end process;

    process (rclk)
    begin
      if rising_edge(rclk) then
        -- read data doesn't care, when reading at write address
        if rce = '1' then
        --synthesis translate_off
          if Is_X(std_logic_vector(ra)) then
            q <= (others => 'X');
          else
        --synthesis translate_on
            q <= ram(to_integer(ra));
        --synthesis translate_off
          end if;
        --synthesis translate_on
        end if;
      end if;
    end process;
  end generate gInfer;
  
  assert VENDOR = VENDOR_XILINX or VENDOR = VENDOR_ALTERA
    report "Device not yet supported."
    severity failure;
end rtl;
