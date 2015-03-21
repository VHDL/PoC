--
-- Copyright (c) 2008
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
-- Entity: mt46v_ctrl_s3esk
-- Author(s): Martin Zabel
-- 
-- Controller for Micron DDR-SDRAM "MT46V*" for Spartan-3E Starter Kit Board.
--
-- For configuration, see mt46v_ctrl_fsm.
--
-- Command, address and write data is sampled with clk.
--
-- Read data is aligned with clk_fb90_n. Either process data in this clock
-- domain, or connect a FIFO to transfer data into another clock domain of your
-- choice.  This FIFO should capable of storing at least one burst (size BL/2)
-- + start of next burst (size 1).
--
-- Synchronous resets are used.
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2009-02-19 16:02:29 $
--
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

entity mt46v_ctrl_s3esk is

  generic (
    CLK_FREQ_MHZ : positive                     := 100;
    CL           : positive                     := 2;
    BL           : positive                     := 2;
    MR_CL        : std_logic_vector(2 downto 0) := "010";
    MR_BL        : std_logic_vector(2 downto 0) := "001";
    T_MRD        : integer                      := 2;
    T_RAS        : integer                      := 5;
    T_RCD        : integer                      := 2;
    T_RFC        : integer                      := 8;
    T_RP         : integer                      := 2;
    T_WR         : integer                      := 2;
    T_WTR        : integer                      := 1);

  port (
    clk        : in    std_logic;
    clk_n      : in    std_logic;
    clk90      : in    std_logic;
    clk90_n    : in    std_logic;
    rst        : in    std_logic;
    rst90      : in    std_logic;
    rst180     : in    std_logic;
    rst270     : in    std_logic;
    clk_fb90   : in    std_logic;
    clk_fb90_n : in    std_logic;
    rst_fb90   : in    std_logic;
    rst_fb270  : in    std_logic;

    user_cmd_valid   : in  std_logic;
    user_wdata_valid : in  std_logic;
    user_write       : in  std_logic;
    user_addr        : in  unsigned(24 downto 0);
    user_wdata       : in  std_logic_vector(31 downto 0);
    user_got_cmd     : out std_logic;
    user_got_wdata   : out std_logic;
    user_rdata       : out std_logic_vector(31 downto 0);
    user_rstb        : out std_logic;
    
    sd_ck_p    : out   std_logic;
    sd_ck_n    : out   std_logic;
    sd_cke     : out   std_logic;
    sd_cs      : out   std_logic;
    sd_ras     : out   std_logic;
    sd_cas     : out   std_logic;
    sd_we      : out   std_logic;
    sd_ba      : out   std_logic_vector(1 downto 0);
    sd_a       : out   std_logic_vector(12 downto 0);
    sd_ldqs    : out   std_logic;
    sd_udqs    : out   std_logic;
    sd_dq      : inout std_logic_vector(15 downto 0));

end mt46v_ctrl_s3esk;

architecture rtl of mt46v_ctrl_s3esk is
  component mt46v_ctrl_fsm
    generic (
      A_BITS       : positive;
      D_BITS       : positive;
      CLK_FREQ_MHZ : positive;
      CL           : positive;
      BL           : positive;
      MR_CL        : std_logic_vector(2 downto 0);
      MR_BL        : std_logic_vector(2 downto 0);
      T_MRD        : integer;
      T_RAS        : integer;
      T_RCD        : integer;
      T_RFC        : integer;
      T_RP         : integer;
      T_WR         : integer;
      T_WTR        : integer);
    port (
      clk              : in  std_logic;
      rst              : in  std_logic;
      user_cmd_valid   : in  std_logic;
      user_wdata_valid : in  std_logic;
      user_write       : in  std_logic;
      user_addr        : in  unsigned(A_BITS-1 downto 0);
      user_got_cmd     : out std_logic;
      user_got_wdata   : out std_logic;
      sd_cke_nxt       : out std_logic;
      sd_cs_nxt        : out std_logic;
      sd_ras_nxt       : out std_logic;
      sd_cas_nxt       : out std_logic;
      sd_we_nxt        : out std_logic;
      sd_a_nxt         : out std_logic_vector(12 downto 0);
      sd_ba_nxt        : out std_logic_vector(1 downto 0);
      rden_nxt         : out std_logic;
      wren_nxt         : out std_logic);
  end component;

  component mt46v_ctrl_phy_s3esk
    port (
      clk        : in    std_logic;
      clk_n      : in    std_logic;
      clk90      : in    std_logic;
      clk90_n    : in    std_logic;
      rst        : in    std_logic;
      rst90      : in    std_logic;
      rst180     : in    std_logic;
      rst270     : in    std_logic;
      clk_fb90   : in    std_logic;
      clk_fb90_n : in    std_logic;
      rst_fb90   : in    std_logic;
      rst_fb270  : in    std_logic;
      sd_cke_nxt : in    std_logic;
      sd_cs_nxt  : in    std_logic;
      sd_ras_nxt : in    std_logic;
      sd_cas_nxt : in    std_logic;
      sd_we_nxt  : in    std_logic;
      sd_ba_nxt  : in    std_logic_vector(1 downto 0);
      sd_a_nxt   : in    std_logic_vector(12 downto 0);
      wren_nxt   : in    std_logic;
      wdata_nxt  : in    std_logic_vector(31 downto 0);
      rden_nxt   : in    std_logic;
      rdata      : out   std_logic_vector(31 downto 0);
      rstb       : out   std_logic;
      sd_ck_p    : out   std_logic;
      sd_ck_n    : out   std_logic;
      sd_cke     : out   std_logic;
      sd_cs      : out   std_logic;
      sd_ras     : out   std_logic;
      sd_cas     : out   std_logic;
      sd_we      : out   std_logic;
      sd_ba      : out   std_logic_vector(1 downto 0);
      sd_a       : out   std_logic_vector(12 downto 0);
      sd_ldqs    : out   std_logic;
      sd_udqs    : out   std_logic;
      sd_dq      : inout std_logic_vector(15 downto 0));
  end component;

  --
  -- Configuration
  --
  constant A_BITS : positive := 25;     -- 32M
  constant D_BITS : positive := 16;     -- x16

  --
  -- Signals
  --
  signal sd_cke_nxt       : std_logic;
  signal sd_cs_nxt        : std_logic;
  signal sd_ras_nxt       : std_logic;
  signal sd_cas_nxt       : std_logic;
  signal sd_we_nxt        : std_logic;
  signal sd_a_nxt         : std_logic_vector(12 downto 0);
  signal sd_ba_nxt        : std_logic_vector(1 downto 0);
  signal rden_nxt         : std_logic;
  signal wren_nxt         : std_logic;

begin  -- rtl

  fsm: mt46v_ctrl_fsm
    generic map (
      A_BITS       => A_BITS,
      D_BITS       => D_BITS,
      CLK_FREQ_MHZ => CLK_FREQ_MHZ,
      CL           => CL,
      BL           => BL,
      MR_CL        => MR_CL,
      MR_BL        => MR_BL,
      T_MRD        => T_MRD,
      T_RAS        => T_RAS,
      T_RCD        => T_RCD,
      T_RFC        => T_RFC,
      T_RP         => T_RP,
      T_WR         => T_WR,
      T_WTR        => T_WTR)
    port map (
      clk              => clk,
      rst              => rst,
      user_cmd_valid   => user_cmd_valid,
      user_wdata_valid => user_wdata_valid,
      user_write       => user_write,
      user_addr        => user_addr,
      user_got_cmd     => user_got_cmd,
      user_got_wdata   => user_got_wdata,
      sd_cke_nxt       => sd_cke_nxt,
      sd_cs_nxt        => sd_cs_nxt,
      sd_ras_nxt       => sd_ras_nxt,
      sd_cas_nxt       => sd_cas_nxt,
      sd_we_nxt        => sd_we_nxt,
      sd_a_nxt         => sd_a_nxt,
      sd_ba_nxt        => sd_ba_nxt,
      rden_nxt         => rden_nxt,
      wren_nxt         => wren_nxt);

  phy: mt46v_ctrl_phy_s3esk
    port map (
      clk        => clk,
      clk_n      => clk_n,
      clk90      => clk90,
      clk90_n    => clk90_n,
      rst        => rst,
      rst90      => rst90,
      rst180     => rst180,
      rst270     => rst270,
      clk_fb90   => clk_fb90,
      clk_fb90_n => clk_fb90_n,
      rst_fb90   => rst_fb90,
      rst_fb270  => rst_fb270,
      sd_cke_nxt => sd_cke_nxt,
      sd_cs_nxt  => sd_cs_nxt,
      sd_ras_nxt => sd_ras_nxt,
      sd_cas_nxt => sd_cas_nxt,
      sd_we_nxt  => sd_we_nxt,
      sd_ba_nxt  => sd_ba_nxt,
      sd_a_nxt   => sd_a_nxt,
      wren_nxt   => wren_nxt,
      wdata_nxt  => user_wdata,
      rden_nxt   => rden_nxt,
      rdata      => user_rdata,
      rstb       => user_rstb,
      sd_ck_p    => sd_ck_p,
      sd_ck_n    => sd_ck_n,
      sd_cke     => sd_cke,
      sd_cs      => sd_cs,
      sd_ras     => sd_ras,
      sd_cas     => sd_cas,
      sd_we      => sd_we,
      sd_ba      => sd_ba,
      sd_a       => sd_a,
      sd_ldqs    => sd_ldqs,
      sd_udqs    => sd_udqs,
      sd_dq      => sd_dq);

end rtl;
