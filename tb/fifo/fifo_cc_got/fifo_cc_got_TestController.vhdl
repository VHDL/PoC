-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Gustavo Martin
--
-- Entity:          fifo_cc_got_TestController
--
-- Description:
-- -------------------------------------
-- Test controller entity for fifo_cc_got OSVVM testbench
-- Uses Transaction interfaces to communicate with VCs
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
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

library osvvm;
context osvvm.OsvvmContext;
use     osvvm.ScoreboardPkg_slv.all;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

use     work.fifo_cc_got_TestController_pkg.all;

entity fifo_cc_got_TestController is
  generic (
    CONFIG_INDEX : tConfigIndex := 0
  );
  port (
    -- Clock and Reset
    Clock   : in    std_logic;
    nReset  : in    std_logic;
    
    -- FIFO Status Signals (for direct monitoring)
    full      : in    std_logic;  -- Write side status
    valid     : in    std_logic;  -- Read side status
    estate_wr : in    std_logic_vector(3 downto 0);  -- Write side fill state
    fstate_rd : in    std_logic_vector(3 downto 0);  -- Read side fill state
    
    -- Transaction interfaces to VCs (OSVVM Standard)
    TxRec   : inOut StreamRecType;  -- To Transmitter VC
    RxRec   : inOut StreamRecType   -- To Receiver VC
  );

  -- Simplifying access to Burst FIFOs using aliases (OSVVM pattern)
  alias TxBurstFifo : ScoreboardIdType is TxRec.BurstFifo;
  alias RxBurstFifo : ScoreboardIdType is RxRec.BurstFifo;

end entity;
