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
-- Entity: ocram_sdp_altera
-- Author(s): Martin Zabel
-- 
-- Instantiating simple dual-port memory.
--
-- - dual clock, clock enable
-- - 1 read port plus 1 write port
-- 
-- Read-to-Write Timing:
--
-- When writing to a given memory cell then the read port must not address that
-- memory cell within the write cycle time.
--
-- When M-RAM blocks are used, then writing occurs at the rising edge of the
-- write clock. When M512 or M4K blocks are used, then address and data are
-- sampled at the rising edge, but the real writing into RAM occurs at the
-- falling edge of the write clock.
--
-- Thus, for safe operation, read from a given memory cell after a complete
-- read-clock cycle after the rising (M-RAM) / falling (M512, M4K) write clock
-- edge.
--
-- Revision:    $Revision: 1.4 $
-- Last change: $Date: 2008-12-11 17:49:25 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.all;

entity ocram_sdp_altera is
  
  generic (
    A_BITS : positive;-- := 10;
    D_BITS : positive--  := 32
  );

  port (
    rclk : in  std_logic;
    wclk : in  std_logic;
    rce  : in  std_logic;
    wce  : in  std_logic;
    we   : in  std_logic;
    ra   : in  unsigned(A_BITS-1 downto 0);
    wa   : in  unsigned(A_BITS-1 downto 0);
    d    : in  std_logic_vector(D_BITS-1 downto 0);
    q    : out std_logic_vector(D_BITS-1 downto 0)
  );
end ocram_sdp_altera;

architecture rtl of ocram_sdp_altera is

  COMPONENT altsyncram
    GENERIC (
      address_aclr_a                     : STRING;
      address_aclr_b                     : STRING;
      address_reg_b                      : STRING;
      indata_aclr_a                      : STRING;
      intended_device_family             : STRING;
      lpm_type                           : STRING;
      numwords_a                         : NATURAL;
      numwords_b                         : NATURAL;
      operation_mode                     : STRING;
      outdata_aclr_b                     : STRING;
      outdata_reg_b                      : STRING;
      power_up_uninitialized             : STRING;
      read_during_write_mode_mixed_ports : STRING;
      widthad_a                          : NATURAL;
      widthad_b                          : NATURAL;
      width_a                            : NATURAL;
      width_b                            : NATURAL;
      width_byteena_a                    : NATURAL;
      wrcontrol_aclr_a                   : STRING
      );

    PORT (
      clocken0  : IN  STD_LOGIC;
      clocken1  : IN  STD_LOGIC;
      wren_a    : IN  STD_LOGIC;
      clock0    : IN  STD_LOGIC;
      clock1    : IN  STD_LOGIC;
      address_a : IN  STD_LOGIC_VECTOR (widthad_a-1 DOWNTO 0);
      address_b : IN  STD_LOGIC_VECTOR (widthad_b-1 DOWNTO 0);
      q_b       : OUT STD_LOGIC_VECTOR (width_a-1 DOWNTO 0);
      data_a    : IN  STD_LOGIC_VECTOR (width_b-1 DOWNTO 0)
      );
  END COMPONENT;

  constant DEPTH : positive := 2**A_BITS;

  signal ra_sl : std_logic_vector(A_BITS-1 downto 0);
  signal wa_sl : std_logic_vector(A_BITS-1 downto 0);
  
begin

  ra_sl <= std_logic_vector(ra);
  wa_sl <= std_logic_vector(wa);
  
  ram : altsyncram
    GENERIC MAP (
      address_aclr_a                     => "NONE",
      address_aclr_b                     => "NONE",
      address_reg_b                      => "CLOCK1",
      indata_aclr_a                      => "NONE",
      intended_device_family             => "Stratix",
      lpm_type                           => "altsyncram",
      numwords_a                         => DEPTH,
      numwords_b                         => DEPTH,
      operation_mode                     => "DUAL_PORT",
      outdata_aclr_b                     => "NONE",
      outdata_reg_b                      => "UNREGISTERED",
      power_up_uninitialized             => "FALSE",
      read_during_write_mode_mixed_ports => "DONT_CARE",
      widthad_a                          => A_BITS,
      widthad_b                          => A_BITS,
      width_a                            => D_BITS,
      width_b                            => D_BITS,
      width_byteena_a                    => 1,
      wrcontrol_aclr_a                   => "NONE"
      )
    PORT MAP (
      clocken0  => wce,
      clocken1  => rce,
      wren_a    => we,
      clock0    => wclk,
      clock1    => rclk,
      address_a => wa_sl,
      address_b => ra_sl,
      data_a    => d,
      q_b       => q
      );

end rtl;
