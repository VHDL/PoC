-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Gustavo Martin
--
-- Entity:          fifo_cc_got_TestHarness
--
-- Description:
-- -------------------------------------
-- Test harness for fifo_cc_got OSVVM testbench
-- Instantiates DUT and Verification Components (Transmitter/Receiver)
-- Connects VCs to TestController via Transaction interfaces
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

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

library PoC;

use     work.fifo_cc_got_TestController_pkg.all;
use     work.FifoCcGotComponentPkg.all;

entity fifo_cc_got_TestHarness is
  generic (
    CONFIG_INDEX : tConfigIndex := 0
  );
end entity;

architecture TestHarness of fifo_cc_got_TestHarness is
  constant TPERIOD_CLOCK : time := 10 ns;

  signal Clock  : std_logic := '1';
  signal nReset : std_logic := '0';  -- Active low for VCs

  -- Write interface signals (between VC and DUT)
  signal put       : std_logic;
  signal din       : tDataWord;
  signal full      : std_logic;
  signal estate_wr : std_logic_vector(ESTATE_WR_BITS-1 downto 0);

  -- Read interface signals (between VC and DUT)
  signal got       : std_logic;
  signal dout      : tDataWord;
  signal valid     : std_logic;
  signal fstate_rd : std_logic_vector(FSTATE_RD_BITS-1 downto 0);

  -- Transaction interfaces (between VCs and TestController)
  signal TxRec : StreamRecType(DataToModel(D_BITS-1 downto 0), DataFromModel(D_BITS-1 downto 0), ParamToModel(0 downto 0), ParamFromModel(0 downto 0));
  signal RxRec : StreamRecType(DataToModel(D_BITS-1 downto 0), DataFromModel(D_BITS-1 downto 0), ParamToModel(0 downto 0), ParamFromModel(0 downto 0));

  -- Test Controller component declaration
  component fifo_cc_got_TestController is
    generic (
      CONFIG_INDEX : tConfigIndex := 0
    );
    port (
      Clock     : in    std_logic;
      nReset    : in    std_logic;
      full      : in    std_logic;
      valid     : in    std_logic;
      estate_wr : in    std_logic_vector(3 downto 0);
      fstate_rd : in    std_logic_vector(3 downto 0);
      TxRec     : inOut StreamRecType;
      RxRec     : inOut StreamRecType
    );
  end component;

begin
  -- Clock generation
  Osvvm.ClockResetPkg.CreateClock(
    Clk    => Clock,
    Period => TPERIOD_CLOCK
  );

  -- Reset generation (active low for VCs)
  Osvvm.ClockResetPkg.CreateReset(
    Reset       => nReset,
    ResetActive => '0',
    Clk         => Clock,
    Period      => 5 * TPERIOD_CLOCK,
    tpd         => 0 ns
  );

  -- DUT instantiation
  DUT : entity PoC.fifo_cc_got
    generic map (
      D_BITS         => D_BITS,
      MIN_DEPTH      => MIN_DEPTH,
      DATA_REG       => GetDataReg(CONFIG_INDEX),
      STATE_REG      => GetStateReg(CONFIG_INDEX),
      OUTPUT_REG     => GetOutputReg(CONFIG_INDEX),
      ESTATE_WR_BITS => ESTATE_WR_BITS,
      FSTATE_RD_BITS => FSTATE_RD_BITS
    )
    port map (
      rst       => not nReset,  -- DUT uses active-high reset
      clk       => Clock,
      put       => put,
      din       => din,
      full      => full,
      estate_wr => estate_wr,
      got       => got,
      dout      => dout,
      valid     => valid,
      fstate_rd => fstate_rd
    );

  -- Transmitter VC instantiation (Write side)
  Transmitter_VC : FifoCcGotTransmitter
    generic map (
      MODEL_ID_NAME => "FifoTx",
      DATA_WIDTH    => D_BITS,
      ESTATE_WIDTH  => ESTATE_WR_BITS
    )
    port map (
      Clk       => Clock,
      nReset    => nReset,
      put       => put,
      din       => din,
      full      => full,
      estate_wr => estate_wr,
      TransRec  => TxRec
    );

  -- Receiver VC instantiation (Read side)
  Receiver_VC : FifoCcGotReceiver
    generic map (
      MODEL_ID_NAME => "FifoRx",
      DATA_WIDTH    => D_BITS,
      FSTATE_WIDTH  => FSTATE_RD_BITS
    )
    port map (
      Clk       => Clock,
      nReset    => nReset,
      got       => got,
      dout      => dout,
      valid     => valid,
      fstate_rd => fstate_rd,
      TransRec  => RxRec
    );

  -- Test Controller instantiation
  TestCtrl : component fifo_cc_got_TestController
    generic map (
      CONFIG_INDEX => CONFIG_INDEX
    )
    port map (
      Clock     => Clock,
      nReset    => nReset,
      full      => full,
      valid     => valid,
      estate_wr => estate_wr,
      fstate_rd => fstate_rd,
      TxRec     => TxRec,
      RxRec     => RxRec
    );

end architecture;
