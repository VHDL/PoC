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
-- Entity: ocram_sp_altera
-- Author(s): Martin Zabel
-- 
-- Instantiating single-port RAM using Altera Megafunctions.
--
-- - single clock, clock enable
-- - 1 read/write port
-- 
-- Written data is passed through the memory and output again as read-data 'q'.
-- This is the normal behaviour of a single-port RAM and also known as
-- write-first mode or read-through-write behaviour.
--
-- Inference does not work due to 'ce', so the altsyncram macro is used.
--
-- Revision:    $Revision: 1.4 $
-- Last change: $Date: 2008-12-11 17:29:55 $

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.all;

entity ocram_sp_altera is
  
  generic (
    A_BITS : positive;-- := 10;
    D_BITS : positive--  := 32
  );

  port (
    clk : in  std_logic;
    ce  : in  std_logic;
    we  : in  std_logic;
    a   : in  unsigned(A_BITS-1 downto 0);
    d   : in  std_logic_vector(D_BITS-1 downto 0);
    q   : out std_logic_vector(D_BITS-1 downto 0)
  );

end ocram_sp_altera;

architecture rtl of ocram_sp_altera is

  COMPONENT altsyncram
    GENERIC (
      address_aclr_a         : STRING;
      indata_aclr_a          : STRING;
      intended_device_family : STRING;
      lpm_hint               : STRING;
      lpm_type               : STRING;
      numwords_a             : NATURAL;
      operation_mode         : STRING;
      outdata_aclr_a         : STRING;
      outdata_reg_a          : STRING;
      power_up_uninitialized : STRING;
      widthad_a              : NATURAL;
      width_a                : NATURAL;
      width_byteena_a        : NATURAL;
      wrcontrol_aclr_a       : STRING
      );

    PORT (
      clocken0  : IN  STD_LOGIC;
      wren_a    : IN  STD_LOGIC;
      clock0    : IN  STD_LOGIC;
      address_a : IN  STD_LOGIC_VECTOR (widthad_a-1 DOWNTO 0);
      q_a       : OUT STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);
      data_a    : IN  STD_LOGIC_VECTOR (width_a-1 DOWNTO 0)
      );
  END COMPONENT;

  constant DEPTH : positive := 2**A_BITS;
  signal a_sl : std_logic_vector(A_BITS-1 downto 0);

begin
  a_sl <= std_logic_vector(a);

  altsyncram_component : altsyncram
    GENERIC MAP (
      address_aclr_a         => "NONE",
      indata_aclr_a          => "NONE",
      intended_device_family => "Stratix",
      lpm_hint               => "ENABLE_RUNTIME_MOD = NO",
      lpm_type               => "altsyncram",
      numwords_a             => DEPTH,
      operation_mode         => "SINGLE_PORT",
      outdata_aclr_a         => "NONE",
      outdata_reg_a          => "UNREGISTERED",
      power_up_uninitialized => "FALSE",
      widthad_a              => A_BITS,
      width_a                => D_BITS,
      width_byteena_a        => 1,
      wrcontrol_aclr_a       => "NONE")

    PORT MAP (
      clocken0  => ce,
      wren_a    => we,
      clock0    => clk,
      address_a => a_sl,
      data_a    => d,
      q_a       => q);

end rtl;
