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
-- Package: ocram
-- Author(s): Martin Zabel
-- 
-- On-Chip RAM for FPGAs and so on.
--
-- Revision:    $Revision: 1.6 $
-- Last change: $Date: 2009-01-22 13:44:25 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ocram is
  
  component ocram_sp
    generic (
      A_BITS : positive;
      D_BITS : positive);
    port (
      clk : in  std_logic;
      ce  : in  std_logic;
      we  : in  std_logic;
      a   : in  unsigned(A_BITS-1 downto 0);
      d   : in  std_logic_vector(D_BITS-1 downto 0);
      q   : out std_logic_vector(D_BITS-1 downto 0));
  end component;
  
  component ocram_sdp
    generic (
      A_BITS : positive;
      D_BITS : positive);
    port (
      rclk : in  std_logic;
      rce  : in  std_logic;
      wclk : in  std_logic;
      wce  : in  std_logic;
      we   : in  std_logic;
      ra   : in  unsigned(A_BITS-1 downto 0);
      wa   : in  unsigned(A_BITS-1 downto 0);
      d    : in  std_logic_vector(D_BITS-1 downto 0);
      q    : out std_logic_vector(D_BITS-1 downto 0));
  end component;

  component ocram_esdp
    generic (
      A_BITS : positive;
      D_BITS : positive);
    port (
      clk1 : in  std_logic;
      clk2 : in  std_logic;
      ce1  : in  std_logic;
      ce2  : in  std_logic;
      we1  : in  std_logic;
      a1   : in  unsigned(A_BITS-1 downto 0);
      a2   : in  unsigned(A_BITS-1 downto 0);
      d1   : in  std_logic_vector(D_BITS-1 downto 0);
      q1   : out std_logic_vector(D_BITS-1 downto 0);
      q2   : out std_logic_vector(D_BITS-1 downto 0));
  end component;

  component ocram_tdp
    generic (
      A_BITS : positive;
      D_BITS : positive);
    port (
      clk1 : in  std_logic;
      clk2 : in  std_logic;
      ce1  : in  std_logic;
      ce2  : in  std_logic;
      we1  : in  std_logic;
      we2  : in  std_logic;
      a1   : in  unsigned(A_BITS-1 downto 0);
      a2   : in  unsigned(A_BITS-1 downto 0);
      d1   : in  std_logic_vector(D_BITS-1 downto 0);
      d2   : in  std_logic_vector(D_BITS-1 downto 0);
      q1   : out std_logic_vector(D_BITS-1 downto 0);
      q2   : out std_logic_vector(D_BITS-1 downto 0));
  end component;

  component ocram_wb
    generic (
      A_BITS      : positive;
      D_BITS      : positive;
      PIPE_STAGES : integer range 1 to 2);
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      wb_cyc_i : in  std_logic;
      wb_stb_i : in  std_logic;
      wb_cti_i : in  std_logic_vector(2 downto 0);
      wb_bte_i : in  std_logic_vector(1 downto 0);
      wb_we_i  : in  std_logic;
      wb_adr_i : in  std_logic_vector(A_BITS-1 downto 0);
      wb_dat_i : in  std_logic_vector(D_BITS-1 downto 0);
      wb_ack_o : out std_logic;
      wb_dat_o : out std_logic_vector(D_BITS-1 downto 0);
      ram_ce   : out std_logic;
      ram_we   : out std_logic;
      ram_a    : out unsigned(A_BITS-1 downto 0);
      ram_d    : out std_logic_vector(D_BITS-1 downto 0);
      ram_q    : in  std_logic_vector(D_BITS-1 downto 0));
  end component;
end ocram;

package body ocram is

  

end ocram;
