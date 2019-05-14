-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Patrick Lehmann
--
-- Entity:          Synchronizes a reset signal across clock-domain boundaries
--
-- Description:
-- -------------------------------------
-- This module synchronizes an asynchronous reset signal to the clock
-- ``Clock``. The ``Input`` can be asserted and de-asserted at any time.
-- The ``Output`` is asserted asynchronously and de-asserted synchronously
-- to the clock.
--
-- .. ATTENTION::
--    Use this synchronizer only to asynchronously reset your design.
--    The 'Output' should be feed by global buffer to the destination FFs, so
--    that, it reaches their reset inputs within one clock cycle.
--
-- Constraints:
--   General:
--     Please add constraints for meta stability to all '_meta' signals and
--     timing ignore constraints to all '_async' signals.
--
--   Xilinx:
--     In case of a Xilinx device, this module will instantiate the optimized
--     module xil_SyncReset. Please attend to the notes of xil_SyncReset.
--
--   Altera sdc file:
--     TODO
--
-- License:
-- =============================================================================
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
use     IEEE.STD_LOGIC_1164.all;

library PoC;
use     PoC.config.all;
use     PoC.utils.all;
use     PoC.sync.all;


entity sync_Resets is
	generic (
		SYNC_DEPTH    : T_MISC_SYNC_DEPTH   := T_MISC_SYNC_DEPTH'low;    -- generate SYNC_DEPTH many stages, at least 2
    NUM_CLOCKS    : natural             := 2
  );
	port (
		Slow_Clock    : in  std_logic;                                  -- <Clock>  slowest clock domain
		Clocks        : in  std_logic_vector(NUM_CLOCKS -1 downto 0);   -- <Clocks>  output clock domain
		Input_Reset   : in  std_logic;                                  -- @async:  reset input
		Output_Resets : out std_logic_vector(NUM_CLOCKS -1 downto 0);   
		Output_Resets_fast : out std_logic_vector(NUM_CLOCKS -1 downto 0) 
	);
end entity;


architecture rtl of sync_Resets is
  signal Slow_Reset_sync  : std_logic;
begin

  slow_reset : entity poc.sync_Reset
  port map(
    Clock         => Slow_Clock,
    Input         => Input_Reset,
    Output        => Slow_Reset_sync
  );
    
  sync : for i in 0 to NUM_CLOCKS -1 generate
  begin
    clock_sync : entity poc.sync_Bits_Xilinx
    generic map(
      INIT          => "1"
    )
    port map(
      Clock         => Clocks(i),
      Input(0)         => Slow_Reset_sync,
      Output(0)        => Output_Resets(i)
    );


    fast_reset : entity poc.sync_Reset
    port map(
      Clock         => Clocks(i),
      Input         => Input_Reset,
      Output        => Output_Resets_fast(i)
    );
  
  end generate;
	
  
  
end architecture;
