--
-- Copyright (c) 2010
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
--
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Package: trace
-- Author(s): Stefan Alex
--
-- Externally Visible Components for Trace-Unit
--
-- Revision:    $Revision: 1.10 $
-- Last change: $Date: 2010-04-30 15:25:01 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_config.all;
use poc.trace_types.tPorts;
use poc.trace_types.NULL_PORT;

package trace is

  ----------------------
  -- Public functions --
  ----------------------

  function getPortValueIndex(PORTS : tPorts; ID : natural) return natural;
  function getPortStbIndex(PORTS : tPorts; ID : natural) return natural;

  ----------------
  -- Components --
  ----------------

  component trace_top
    port(
      clk_trc            : in  std_logic;
      rst_trc            : in  std_logic;
      clk_sys            : in  std_logic;
      rst_sys            : in  std_logic;
      trace_running      : out std_logic;
      inst_values        : in  std_logic_vector(INST_ADR_BITS-1 downto 0);
      inst_stbs          : in  std_logic_vector(INST_STB_BITS-1 downto 0);
      inst_branch_values : in  std_logic_vector(INST_BRANCH_BITS-1 downto 0);
      inst_branch_stbs   : in  std_logic_vector(INST_BRANCH_STB_BITS-1 downto 0);
      mem_adr_values     : in  std_logic_vector(MEM_ADR_BITS-1 downto 0);
      mem_adr_stbs       : in  std_logic_vector(MEM_ADR_STB_BITS-1 downto 0);
      mem_data_values    : in  std_logic_vector(MEM_DAT_BITS-1 downto 0);
      mem_data_stbs      : in  std_logic_vector(MEM_DAT_STB_BITS-1 downto 0);
      mem_source_values  : in  std_logic_vector(MEM_SOURCE_BITS-1 downto 0);
      mem_source_stbs    : in  std_logic_vector(MEM_SOURCE_STB_BITS-1 downto 0);
      mem_rw_values      : in  std_logic_vector(MEM_RW_BITS-1 downto 0);
      mem_rw_stbs        : in  std_logic_vector(MEM_RW_STB_BITS-1 downto 0);
      message_values     : in  std_logic_vector(MESSAGE_BITS-1 downto 0);
      message_stbs       : in  std_logic_vector(MESSAGE_STB_BITS-1 downto 0);
      statistic_incs     : in  std_logic_vector(STAT_BITS-1 downto 0);
      statistic_rsts     : in  std_logic_vector(STAT_BITS-1 downto 0);
      trigger_out        : out std_logic_vector(TRIGGER_BITS-1 downto 0);
      system_stall       : out std_logic;
      regs_in            : in  std_logic_vector(ICE_REG_BITS-1 downto 0);
      regs_out           : out std_logic_vector(ICE_REG_BITS-1 downto 0);
      store              : out std_logic_vector(ICE_REG_CNT_NZ-1 downto 0);
      eth_full           : out std_logic;
      eth_din            : in  std_logic_vector(7 downto 0);
      eth_put            : in  std_logic;
      eth_valid          : out std_logic;
      eth_last           : out std_logic;
      eth_dout           : out std_logic_vector(7 downto 0);
      eth_got            : in  std_logic;
      header             : out std_logic;
      eth_finish         : in  std_logic
    );
  end component;

  component trace_eth
    generic (
      BOARD_MAC        : std_logic_vector(47 downto 0);
      HOST_MAC         : std_logic_vector(47 downto 0);
      ETHER_TYPE       : std_logic_vector(15 downto 0) := X"5180";
      SEND_GAP         : positive := 300;
      SEND_PACKET_SIZE : positive := 1499
      );
    port (
      clk_eth       : in  std_logic;
      rst_eth       : in  std_logic;
      tr_finish     : out std_logic;
      tr_data       : out std_logic_vector(7 downto 0);
      tr_sof_n      : out std_logic;
      tr_eof_n      : out std_logic;
      tr_vld_n      : out std_logic;
      tr_rdy_n      : in  std_logic;
      re_data       : in  std_logic_vector(7 downto 0);
      re_sof_n      : in  std_logic;
      re_eof_n      : in  std_logic;
      re_vld_n      : in  std_logic;
      re_rdy_n      : out std_logic;
      tr_fifo_got   : out std_logic;
      tr_fifo_valid : in  std_logic;
      tr_fifo_last  : in  std_logic;
      tr_fifo_din   : in  std_logic_vector(7 downto 0);
      tr_header     : in  std_logic;
      re_fifo_put   : out std_logic;
      re_fifo_full  : in  std_logic;
      re_fifo_dout  : out std_logic_vector(7 downto 0)
      );
  end component;

  component eth_clockgen_ml505
    port (
      CLK_FPGA_P       : in  std_logic;
      CLK_FPGA_N       : in  std_logic;
      PHY_RXCLK        : in  std_logic;
      FPGA_CPU_RESET_B : in  std_logic;
      clk_eth          : out std_logic;
      clk_gmii_tx      : out std_logic;
      clk_gmii_rx      : out std_logic;
      clk_delayctrl    : out std_logic;
      async_rst        : out std_logic;
      rst_eth          : out std_logic;
      rst_delayctrl    : out std_logic;
      locked           : out std_logic);
  end component;

end trace;

-------------------------------------------------------------------------------

package body trace is
  function getPortValueIndex(PORTS : tPorts; ID : natural) return natural is
    variable index : natural := 0;
  begin
    for i in 0 to PORTS'length-1 loop
      if PORTS(i).ID /= ID then
        if PORTS(i).ID /= NULL_PORT.ID then
          index := index + PORTS(i).INPUTS*PORTS(i).WIDTH;
        end if;
      else
        return index;
      end if;
    end loop;
    assert false severity error;
    return 0;
  end function getPortValueIndex;

  function getPortStbIndex(PORTS : tPorts; ID : natural) return natural is
    variable index : natural := 0;
  begin
    for i in 0 to  PORTS'length-1 loop
      if PORTS(i).ID /= ID then
        if PORTS(i).ID /= NULL_PORT.ID then
          index := index + PORTS(i).INPUTS;
        end if;
      else
        return index;
      end if;
    end loop;
    assert false severity error;
    return 0;
  end function getPortStbIndex;

end trace;
