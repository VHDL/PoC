-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Martin Zabel
--
-- Entity:					Synthesis test for sram_is61lv_ctrl.
--
-- Description:
-- -------------------------------------
-- Synthesis test for sram_is61lv_ctrl.
--
-- Synthesis results (with and with out wrapper):
--
-- * Xilinx ISE (KEEP_HIERARCHY = SOFT): generates logic as expected. If device
--   has 6-input LUTs, then the CE of the ctrl/wdata_r is not used. Instead the
--   designated output (sram_wdata) is fed back to a LUT (which is not possible
--   in hardware) to keep the old state. Some intended duplicate control
--   registers are removed if Virtex-5 is selected, attribute KEEP is ignored.
--
-- * Xilinx Vivado: generates logic as expected.
--
-- * Altera Quartus 13.0: issues warnings about connectivity warnings (12241
--   and 13034). RTL netlist view looks ugly. Post-Mapping netlist looks good.
--
-- * Lattice Diamond 3.7.0: No warnings. Netlist view looks ugly. Some
--   unnecessary LUTs are synthesized for sram_data_tristate.o. Signal naming
--   in physical view is confusing. Duplicate registers for ctrl/own_oe_r
--   (driving t of IOB) are removed.
--
-- License:
-- =============================================================================
-- Copyright 2016-2016 Technische Universitaet Dresden - Germany,
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

-------------------------------------------------------------------------------
-- Naming Conventions:
-- (Based on: Keating and Bricaud: "Reuse Methodology Manual")
--
-- active low signals: "*_n"
-- clock signals: "clk", "clk_div#", "clk_#x"
-- reset signals: "rst", "rst_n"
-- generics: all UPPERCASE
-- user defined types: "*_TYPE"
-- state machine next state: "*_ns"
-- state machine current state: "*_cs"
-- output of a register: "*_r"
-- asynchronous signal: "*_a"
-- pipelined or register delay signals: "*_p#"
-- data before being registered into register with the same name: "*_nxt"
-- clock enable signals: "*_ce"
-- internal version of output port: "*_i"
-- tristate internal signal "*_z"
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.io.all;

entity sram_is61lv_ctrl_wrapper is

  generic (
    A_BITS   : positive;
    D_BITS   : positive;
    SDIN_REG : boolean := true);

  port (
    clk       : in    std_logic;
    rst       : in    std_logic;
    req       : in    std_logic;
    write     : in    std_logic;
    addr      : in    unsigned(A_BITS-1 downto 0);
    wdata     : in    std_logic_vector(D_BITS-1 downto 0);
    wmask     : in    std_logic_vector(D_BITS/8 -1 downto 0);
    rdy       : out   std_logic;
    rstb      : out   std_logic;
    rdata     : out   std_logic_vector(D_BITS-1 downto 0);
    sram_be_n : out   std_logic_vector(D_BITS/8 -1 downto 0);
    sram_oe_n : out   std_logic;
    sram_we_n : out   std_logic;
    sram_addr : out   unsigned(A_BITS-1 downto 0);
    sram_data : inout T_IO_TRISTATE_VECTOR(D_BITS-1 downto 0));

end entity sram_is61lv_ctrl_wrapper;

architecture rtl of sram_is61lv_ctrl_wrapper is
begin
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
      addr      => addr,
      wdata     => wdata,
      wmask     => wmask,
      rdy       => rdy,
      rstb      => rstb,
      rdata     => rdata,
      sram_be_n => sram_be_n,
      sram_oe_n => sram_oe_n,
      sram_we_n => sram_we_n,
      sram_addr => sram_addr,
      sram_data => sram_data);
end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.io.all;

entity sram_is61lv_ctrl_test is

	generic (
		A_BITS   : positive := 19;
		D_BITS   : positive := 16);

	port (
		-- PoC.Mem interface
		clk   : in  std_logic;
		rst   : in  std_logic;
		req   : in  std_logic;
		write : in  std_logic;
		addr  : in  unsigned(A_BITS-1 downto 0);
		wdata : in  std_logic_vector(D_BITS-1 downto 0);
		wmask : in  std_logic_vector(D_BITS/8 -1 downto 0);
		rdy   : out std_logic;
		rstb  : out std_logic;
		rdata : out std_logic_vector(D_BITS-1 downto 0);

		-- SRAM connection
		sram_be_n : out   std_logic_vector(D_BITS/8 -1 downto 0);
		sram_oe_n : out   std_logic;
		sram_we_n : out   std_logic;
		sram_addr : out   unsigned(A_BITS-1 downto 0);
		sram_data : inout std_logic_vector(D_BITS-1 downto 0));
end sram_is61lv_ctrl_test;

architecture rtl of sram_is61lv_ctrl_test is
	signal sram_data_tristate : T_IO_TRISTATE_VECTOR(D_BITS-1 downto 0);

	signal rst_r     : std_logic;
	signal req_r     : std_logic;
	signal write_r   : std_logic;
	signal addr_r    : unsigned(A_BITS-1 downto 0);
	signal wdata_r   : std_logic_vector(D_BITS-1 downto 0);
	signal wmask_r   : std_logic_vector(D_BITS/8 -1 downto 0);
	signal rdy_i     : std_logic;
	signal rstb_i    : std_logic;
	signal rdata_i   : std_logic_vector(D_BITS-1 downto 0);
begin

	-- Just some input and output flip-flops instead of a real design.
	-- NOTE: this is not a real pipeline stage!
	rst_r   <= rst     when rising_edge(clk);
	req_r   <= req     when rising_edge(clk);
	write_r <= write   when rising_edge(clk);
	addr_r  <= addr    when rising_edge(clk);
	wdata_r <= wdata   when rising_edge(clk);
	wmask_r <= wmask   when rising_edge(clk);
	rdy     <= rdy_i   when rising_edge(clk);
	rstb    <= rstb_i  when rising_edge(clk);
	rdata   <= rdata_i when rising_edge(clk);

	wrapper: entity work.sram_is61lv_ctrl_wrapper
		generic map (
			A_BITS   => A_BITS,
			D_BITS   => D_BITS,
			SDIN_REG => true)
		port map (
			clk       => clk,
			rst       => rst_r,
			req       => req_r,
			write     => write_r,
			addr      => addr_r,
			wdata     => wdata_r,
			wmask     => wmask_r,
			rdy       => rdy_i,
			rstb      => rstb_i,
			rdata     => rdata_i,
			sram_be_n => sram_be_n,
			sram_oe_n => sram_oe_n,
			sram_we_n => sram_we_n,
			sram_addr => sram_addr,
			sram_data => sram_data_tristate);

	-- Instantiate tri-state driver on top-level
	io_tristate_driver(
		tristate => sram_data_tristate,
		pad      => sram_data);
end rtl;
