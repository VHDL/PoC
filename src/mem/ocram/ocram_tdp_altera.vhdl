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
-- Entity: ocram_tdp_altera
-- Author(s): Martin Zabel
-- 
-- Inferring / instantiating simple dual-port memory.
--
-- - dual clock, clock enable
-- - 2 read/write ports
-- 
-- Reading from the opposite port at the write address returns unknown data.
-- Putting the different RAM
-- behaviours (Altera, Xilinx, some ASICs) together, then the Altera M512/M4K
-- TriMatrix memory defines the minimum time after which the written data can
-- be read out again. As stated in the Stratix Handbook, Volum2, page 2-13, the
-- data is actually written with the falling (instead of the rising) edge of
-- the clock. So that data can be read out after half of the write-clock period
-- plus the write-cycle time.
--
-- To generalize this behaviour, it can be assumed, that written data is 
-- available at the read-port with the next rising write!-clock edge. Both,
-- read- and write-clock edge might be at the same time, to satisfy this rule.
-- An example would be, that write- and read-clock are the same.
--
-- Written data is passed through the memory and output again as read-data on
-- the same port only! This is the normal behaviour for the same port and also
-- known as write-first mode or read-through-write behaviour.
--
-- If latency is an issue, then memory blocks should be directly instantiated.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-12-11 17:51:31 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.all;

entity ocram_tdp_altera is
  
  generic (
    A_BITS : positive;-- := 10;
    D_BITS : positive--  := 32
  );

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
    q2   : out std_logic_vector(D_BITS-1 downto 0)
  );

end ocram_tdp_altera;

architecture rtl of ocram_tdp_altera is

  component altsyncram
    generic (
      address_aclr_a            : STRING;
      address_aclr_b            : STRING;
      address_reg_b             : STRING;
      indata_aclr_a             : STRING;
      indata_aclr_b             : STRING;
      indata_reg_b              : STRING;
      intended_device_family    : STRING;
      lpm_type                  : STRING;
      numwords_a                : NATURAL;
      numwords_b                : NATURAL;
      operation_mode            : STRING;
      outdata_aclr_a            : STRING;
      outdata_aclr_b            : STRING;
      outdata_reg_a             : STRING;
      outdata_reg_b             : STRING;
      power_up_uninitialized    : STRING;
      widthad_a                 : NATURAL;
      widthad_b                 : NATURAL;
      width_a                   : NATURAL;
      width_b                   : NATURAL;
      width_byteena_a           : NATURAL;
      width_byteena_b           : NATURAL;
      wrcontrol_aclr_a          : STRING;
      wrcontrol_aclr_b          : STRING;
      wrcontrol_wraddress_reg_b : STRING);
    port (
      clocken0  : IN  STD_LOGIC;
      clocken1  : IN  STD_LOGIC;
      wren_a    : IN  STD_LOGIC;
      clock0    : IN  STD_LOGIC;
      wren_b    : IN  STD_LOGIC;
      clock1    : IN  STD_LOGIC;
      address_a : IN  STD_LOGIC_VECTOR (widthad_a-1 DOWNTO 0);
      address_b : IN  STD_LOGIC_VECTOR (widthad_b-1 DOWNTO 0);
      q_a       : OUT STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);
      q_b       : OUT STD_LOGIC_VECTOR (width_b-1 DOWNTO 0);
      data_a    : IN  STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);
      data_b    : IN  STD_LOGIC_VECTOR (width_b-1 DOWNTO 0));
  end component;

  constant DEPTH : positive := 2**A_BITS;

  signal a1_sl : std_logic_vector(A_BITS-1 downto 0);
  signal a2_sl : std_logic_vector(A_BITS-1 downto 0);
  
begin  -- rtl

  a1_sl <= std_logic_vector(a1);
  a2_sl <= std_logic_vector(a2);
    
  altsyncram_component : altsyncram
    GENERIC MAP (
      address_aclr_a => "NONE",
      address_aclr_b => "NONE",
      address_reg_b => "CLOCK1",
      indata_aclr_a => "NONE",
      indata_aclr_b => "NONE",
      indata_reg_b => "CLOCK1",
      intended_device_family => "Stratix",
      lpm_type => "altsyncram",
      numwords_a => DEPTH,
      numwords_b => DEPTH,
      operation_mode => "BIDIR_DUAL_PORT",
      outdata_aclr_a => "NONE",
      outdata_aclr_b => "NONE",
      outdata_reg_a => "UNREGISTERED",
      outdata_reg_b => "UNREGISTERED",
      power_up_uninitialized => "FALSE",
      widthad_a => A_BITS,
      widthad_b => A_BITS,
      width_a => D_BITS,
      width_b => D_BITS,
      width_byteena_a => 1,
      width_byteena_b => 1,
      wrcontrol_aclr_a => "NONE",
      wrcontrol_aclr_b => "NONE",
      wrcontrol_wraddress_reg_b => "CLOCK1"
      )
    PORT MAP (
      clock0 => clk1,
      clock1 => clk2,
      clocken0 => ce1,
      clocken1 => ce2,
      wren_a => we1,
      wren_b => we2,
      address_a => a1_sl,
      address_b => a2_sl,
      data_a => d1,
      data_b => d2,
      q_a => q1,
      q_b => q2
      );
    
end rtl;
