--
-- Copyright (c) 2013
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
-- Entity: sdram_ctrl_fsm_tb
-- Author(s): Martin Zabel
-- 
-- Testbench for generic SDAM memory controller.
--
-- Revision:    $Revision: 1.3 $
-- Last change: $Date: 2013-06-07 12:40:51 $
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

library poc;
use poc.functions.all;

-------------------------------------------------------------------------------

entity sdram_ctrl_fsm_tb is

end sdram_ctrl_fsm_tb;

-------------------------------------------------------------------------------

architecture tb of sdram_ctrl_fsm_tb is

  -- component generics
  constant SDRAM_TYPE : natural  := 0;   -- SDR-SDRAM
  constant A_BITS     : positive := 22;  -- 4Meg
  constant D_BITS     : positive := 16;  -- x16
  constant R_BITS     : positive := 12;  -- 4096 rows
  constant C_BITS     : positive := 8;   --  256 columns
  constant B_BITS     : positive := 2;   --    2 banks

  -- Timing for 166 MHz maximum
  constant CL        : positive                     := 3;
  constant BL        : positive                     := 1;
  constant T_MRD     : integer                      := 2;
  constant T_RAS     : integer                      := 7;
  constant T_RCD     : integer                      := 3;
  constant T_RFC     : integer                      := 10;
  constant T_RP      : integer                      := 2;
  constant T_WR      : integer                      := 2;
  constant T_WTR     : integer                      := 1;
  constant T_REFI    : integer                      := 2500;
  constant INIT_WAIT : integer                      := 7;

  -- component ports
  signal clk              : std_logic := '1';
  signal rst              : std_logic;
  signal user_cmd_valid   : std_logic;
  signal user_wdata_valid : std_logic;
  signal user_write       : std_logic;
  signal user_addr        : std_logic_vector(A_BITS-1 downto 0);
  signal user_got_cmd     : std_logic;
  signal user_got_wdata   : std_logic;
  signal sd_cke_nxt       : std_logic;
  signal sd_cs_nxt        : std_logic;
  signal sd_ras_nxt       : std_logic;
  signal sd_cas_nxt       : std_logic;
  signal sd_we_nxt        : std_logic;
  signal sd_a_nxt         : std_logic_vector(imax(R_BITS,C_BITS+1)-1 downto 0);
  signal sd_ba_nxt        : std_logic_vector(1 downto 0);
  signal rden_nxt         : std_logic;
  signal wren_nxt         : std_logic;

begin  -- tb

  -- component instantiation
  DUT: entity poc.sdram_ctrl_fsm
    generic map (
      SDRAM_TYPE   => SDRAM_TYPE,
      A_BITS       => A_BITS,
      D_BITS       => D_BITS,
      R_BITS       => R_BITS,
      C_BITS       => C_BITS,
      B_BITS       => B_BITS,
      CL           => CL,
      BL           => BL,
      T_MRD        => T_MRD,
      T_RAS        => T_RAS,
      T_RCD        => T_RCD,
      T_RFC        => T_RFC,
      T_RP         => T_RP,
      T_WR         => T_WR,
      T_WTR        => T_WTR,
      T_REFI       => T_REFI,
      INIT_WAIT    => INIT_WAIT)
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

  -- clock generation
  clk <= not clk after 3 ns;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    rst <= '1';
    wait until rising_edge(clk);
    
    wait until rising_edge(clk);
    rst <= '0';
    user_cmd_valid <= '1';
    user_addr <= "10" & "101010101010" & "01010101";
    user_write <= '1';
    user_wdata_valid <= '1';
    
    wait until rising_edge(clk) and user_got_cmd = '1';
    user_cmd_valid <= '1';
    user_addr <= not user_addr;
    user_write <= '0';
    user_wdata_valid <= '0';
    
    wait until rising_edge(clk) and user_got_cmd = '1';
    user_cmd_valid <= '0';
    user_addr <= (others => '-');
    user_write <= '-';
    user_wdata_valid <= '0';
    
    wait;                               -- forever
  end process WaveGen_Proc;

  

end tb;
