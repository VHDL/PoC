--
-- Copyright (c) 2012
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
-- Package: comm
-- Author(s): Patrick Lehmann <paebbels@gmail.com>
--            Thomas Preusser <thomas.preusser@tu-dresden.de>
-- 
-- Summary:
-- ========
-- Component declarations for various common modules.
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2012-09-26 12:51:59 $
--
library IEEE;
use IEEE.std_logic_1164.all;

package comm is
  -- This module convertes std_logic_vectors with different bit widths.
  component comm_bitwidth_converter is
    generic (
      REGISTERED : boolean := false;    -- add output register @Clock2
      BW1        : positive;            -- input bit width
      BW2        : positive             -- output bit width
    );
    port (
      Clock1 : in  std_logic;           -- input clock domain
      Clock2 : in  std_logic;           -- output clock domain
      Align  : in  std_logic;           -- align word (one cycle high impulse)
      I      : in  std_logic_vector(BW1-1 downto 0);  -- input word
      O      : out std_logic_vector(BW2-1 downto 0)   -- output word
    );
  end component;
  
  -- Calculates the Remainder of the Division by the Generator Polynomial GEN.
  component comm_crc is
    generic (
      GEN  : bit_vector;     -- Generator Polynom
      BITS : positive        -- Number of Bits to be processed in parallel
    );
    port (
      clk  : in  std_logic;               -- Clock
      
      set  : in std_logic;              -- Parallel Preload of Remainder
      init : in std_logic_vector(GEN'length-2 downto 0);
      step : in std_logic;              -- Process Input Data (MSB first)
      din  : in std_logic_vector(BITS-1 downto 0);

      rmd  : out std_logic_vector(GEN'length-2 downto 0);  -- Remainder
      zero : out std_logic                                 -- Remainder is Zero
    );
  end component;
  
  -- Computes XOR masks for stream scrambling from an LFSR generator.
  component comm_scramble is
    generic (
      GEN  : bit_vector;       -- Generator Polynomial (little endian)
      BITS : positive          -- Width of Mask Bits to be computed in parallel
    );
    port (
      clk  : in  std_logic;    -- Clock

      set  : in  std_logic;    -- Set LFSR to provided Value
      din  : in  std_logic_vector(GEN'length-2 downto 0);

      step : in  std_logic;    -- Compute a Mask Output
      mask : out std_logic_vector(BITS-1 downto 0)
    );
  end component;
  
end comm;

package body comm is
end comm;
