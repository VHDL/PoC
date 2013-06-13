--
-- Copyright (c) 2011
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
-- Entity: crc
-- Author(s): Thomas B. Preusser <thomas.preusser@tu-dresden.de>
-- 	      Patrick Lehmann    <paebbels@gmail.com>
--
-- Computes the CRC (FCS) for a data packet as remainder of the
-- polynomial division of teh message by the given generator polynomial.
--
-- The computation is unrolled so as to process an arbitrary number of
-- message bits per step. The generated FCS is independent from the
-- chosen processing width.
--
-- Bug fixes:
-- ==========
--	Patrick Lehmann
--	- calculation fixed; tested with Serial-ATA and CRC32 polynomial
--
-- Revision:    $Revision: 1.4 $
-- Last change: $Date: 2012-11-29 14:50:50 $
--

library IEEE;
use IEEE.std_logic_1164.all;

entity comm_crc is
  -----------------------------------------------------------------------------
  -- Calculates the Remainder of the Division by the Generator Polynomial GEN.
  --

  generic (
    GEN  : bit_vector;     -- Generator Polynom
    BITS : positive        -- Number of Bits to be processed in parallel
  );
  port (
    clk  : in  std_logic;               -- Clock
    
    set  : in  std_logic;               -- Parallel Preload of Remainder
    init : in  std_logic_vector(GEN'length-2 downto 0);
    step : in  std_logic;               -- Process Input Data (MSB first)
    din  : in  std_logic_vector(BITS-1 downto 0);

    rmd  : out std_logic_vector(GEN'length-2 downto 0);  -- Remainder
    zero : out std_logic                                 -- Remainder is Zero
  );
end comm_crc;

architecture rtl of comm_crc is

  -----------------------------------------------------------------------------
  -- Normalizes the generator representation:
  --   - into a 'downto 0' index range and
  --   - truncating it just below the most significant and so hidden '1'.
  function normalize(G : bit_vector) return bit_vector is
    variable GN : bit_vector(G'length-1 downto 0);
  begin
    GN := G;
    for i in GN'left downto 1 loop
      if GN(i) = '1' then
        return  GN(i-1 downto 0);
      end if;
    end loop;
    report "Cannot use absolute constant as generator."
      severity failure;
    return  GN;
  end normalize;
  
  -- Normalized Generator
  constant GN : bit_vector := normalize(GEN);

  -- LFSR Value
  signal lfsr : std_logic_vector(GN'range);

begin
  process(clk)
    variable v : std_logic_vector(lfsr'range);
  begin
    if rising_edge(clk) then
      if set = '1' then
        lfsr <= init(lfsr'range);
      elsif step = '1' then
        v := lfsr;
        for i in BITS-1 downto 0 loop
          v := (v(v'left-1 downto 0) & '0') xor
               (to_stdlogicvector(GN) and (GN'range => (din(i) xor v(v'left))));
        end loop;
        lfsr <= v;
      end if;
    end if;
  end process;

  -- Provide Outputs
  rmd  <= lfsr;
  zero <= '1' when lfsr = (lfsr'range => '0') else '0';

end rtl;
