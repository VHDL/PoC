-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Gustavo Martin
--
-- Package:         FifoCcGotComponentPkg
--
-- Description:
-- -------------------------------------
-- Component declarations for FIFO CC Got Verification Components
-- Uses OSVVM's standard StreamRecType for transaction interfaces
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

library osvvm;
context osvvm.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

package FifoCcGotComponentPkg is

  ------------------------------------------------------------
  -- FifoCcGotTransmitter - Write side VC
  ------------------------------------------------------------
  component FifoCcGotTransmitter is
    generic (
      MODEL_ID_NAME   : string := "";
      DATA_WIDTH      : integer := 8;
      ESTATE_WIDTH    : integer := 2;
      tpd_Clk_put     : time := 2 ns;
      tpd_Clk_din     : time := 2 ns
    );
    port (
      -- Global Signals
      Clk           : in  std_logic;
      nReset        : in  std_logic;

      -- FIFO Write Interface
      put           : out std_logic;
      din           : out std_logic_vector(DATA_WIDTH-1 downto 0);
      full          : in  std_logic;
      estate_wr     : in  std_logic_vector(ESTATE_WIDTH-1 downto 0);

      -- Transaction Interface (OSVVM Standard)
      TransRec      : inOut StreamRecType
    );
  end component FifoCcGotTransmitter;

  ------------------------------------------------------------
  -- FifoCcGotReceiver - Read side VC
  ------------------------------------------------------------
  component FifoCcGotReceiver is
    generic (
      MODEL_ID_NAME  : string := "";
      DATA_WIDTH     : integer := 8;
      FSTATE_WIDTH   : integer := 2;
      tpd_Clk_got    : time := 2 ns
    );
    port (
      -- Global Signals
      Clk           : in  std_logic;
      nReset        : in  std_logic;

      -- FIFO Read Interface
      got           : out std_logic;
      dout          : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      valid         : in  std_logic;
      fstate_rd     : in  std_logic_vector(FSTATE_WIDTH-1 downto 0);

      -- Transaction Interface (OSVVM Standard)
      TransRec      : inOut StreamRecType
    );
  end component FifoCcGotReceiver;

end package FifoCcGotComponentPkg;
