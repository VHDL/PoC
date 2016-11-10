-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Martin Zabel
--
-- Entity:					Controller for IS61LV Asynchronous SRAM.
--
-- Description:
-- -------------------------------------
-- Controller for IS61LV Asynchronous SRAM.
--
-- Tested with SRAM: IS61LV25616AL
--
-- This component provides the :doc:`PoC.Mem </References/Interfaces/Memory>`
-- interface for the user application.
--
--
-- Configuration
-- *************
--
-- +------------+-------------------------------------------+
-- | Parameter  | Description                               |
-- +============+===========================================+
-- | A_BITS     | Number of address bits (word address).    |
-- +------------+-------------------------------------------+
-- | D_BITS     | Number of data bits (of the word).        |
-- +------------+-------------------------------------------+
-- | SDIN_REG   | Generate register for sram_data on input. |
-- +------------+-------------------------------------------+
--
-- .. NOTE::
--    While the register on input from the SRAM chip is optional, all outputs
--    to the SRAM are registered as normal. These output registers should be
--    placed in an IOB on an FPGA, so that the timing relationship is
--    fulfilled.
--
--
-- Operation
-- *********
--
-- Regarding the user application interface, more details can be found
-- :doc:`here </References/Interfaces/Memory>`.
--
-- The system top-level must connect GND ('0') to the SRAM chip enable ``ce_n``.
--
-- When using an IS61LV25616: the SRAM byte enables ``lb_n`` and ``ub_n`` must be
-- connected to ``sram_be_n(0)`` and ``sram_be_n(1)``, respectively.
--
-- The system top-level must instantiate the appropriate tri-state driver for
-- ``sram_data``.
--
-- Synchronous reset is used.
--
-- License:
-- =============================================================================
-- Copyright 2008-2016 Technische Universitaet Dresden - Germany,
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
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.io.all;
use poc.physical.all;
-- simulation only packages
use PoC.sim_types.all;
use PoC.simulation.all;
use PoC.waveform.all;

entity sram_is61lv_ctrl_tb is
end entity sram_is61lv_ctrl_tb;

architecture sim of sram_is61lv_ctrl_tb is
  constant A_BITS   : positive := 8;
  constant D_BITS   : positive := 16;
  constant SDIN_REG : boolean := true;

  signal clk       : std_logic;
  signal rst       : std_logic;
  signal req       : std_logic;
  signal write     : std_logic;
  signal mask      : std_logic_vector(D_BITS/8 -1 downto 0);
  signal addr      : unsigned(A_BITS-1 downto 0);
  signal wdata     : std_logic_vector(D_BITS-1 downto 0);
  signal rdy       : std_logic;
  signal rstb      : std_logic;
  signal rdata     : std_logic_vector(D_BITS-1 downto 0);
  signal sram_be_n : std_logic_vector(D_BITS/8 -1 downto 0);
  signal sram_oe_n : std_logic;
  signal sram_we_n : std_logic;
  signal sram_addr : unsigned(A_BITS-1 downto 0);
  signal sram_data : T_IO_TRISTATE_VECTOR(D_BITS-1 downto 0);

  -- The real data bus
  signal sram_dbus : std_logic_vector(D_BITS-1 downto 0) := (others => 'Z');

begin  -- architecture sim

  simInitialize;
  simGenerateClock(clk, 100 MHz);

  ctrl: entity poc.sram_is61lv_ctrl
    generic map (
      A_BITS   => A_BITS,
      D_BITS   => D_BITS,
      SDIN_REG => SDIN_REG)
    port map (
      clk       => clk,
      rst       => rst,
      req       => req,
      write     => write,
      mask      => mask,
      addr      => addr,
      wdata     => wdata,
      rdy       => rdy,
      rstb      => rstb,
      rdata     => rdata,
      sram_be_n => sram_be_n,
      sram_oe_n => sram_oe_n,
      sram_we_n => sram_we_n,
      sram_addr => sram_addr,
      sram_data => sram_data);

  -- Tri-state driver on top-level
  io_tristate_driver(
		tristate => sram_data,
		pad      => sram_dbus
	);

  Stimuli : process
    constant simProcessID : T_SIM_PROCESS_ID := simRegisterProcess("Stimuli");
  begin
    rst <= '1';
    simWaitUntilRisingEdge(clk, 1);
    rst <= '0';

    req   <= '0';
    write <= '-';
    mask  <= (others => '-');
    addr  <= (others => '-');
    wdata <= (others => '-');
    simWaitUntilRisingEdge(clk, 1);

    req   <= '1';
    write <= '1';
    mask  <= (others => '0');
    addr  <= x"00";
    wdata <= x"0F0F";
    simWaitUntilRisingEdge(clk, 1);

    req   <= '0';
    write <= '-';
    mask  <= (others => '-');
    addr  <= (others => '-');
    wdata <= (others => '-');
    simWaitUntilRisingEdge(clk, 1);

    req   <= '1';
    write <= '0';
    mask  <= (others => '-');
    addr  <= x"00";
    wdata <= (others => '-');
    simWaitUntilRisingEdge(clk, 1);

    req   <= '1';
    write <= '1';
    mask  <= (others => '0');
    addr  <= x"00";
    wdata <= x"F0F0";
    simWaitUntilRisingEdge(clk, 1);

    req   <= '0';
    write <= '-';
    mask  <= (others => '-');
    addr  <= (others => '-');
    wdata <= (others => '-');
    simWaitUntilRisingEdge(clk, 1);

    req   <= '0';
    write <= '-';
    mask  <= (others => '-');
    addr  <= (others => '-');
    wdata <= (others => '-');
    simWaitUntilRisingEdge(clk, 1);

    -- This process is finished
    simDeactivateProcess(simProcessID);
    wait;  -- forever
  end process;

  IS61LV : block
  begin
    process(sram_oe_n)
    begin
      if sram_oe_n = '0' then
        sram_dbus <= (others => '1'); -- TODO: read data
      else
        sram_dbus <= (others => 'Z');
      end if;
    end process;
  end block IS61LV;
end architecture sim;
