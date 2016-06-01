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
-- Author: Thomas B. Preusser <thomas.preusser@tu-dresden.de>
--
-- This implementation uses low-level Xilinx-specific components!
-- Usable for Virtex-5+ architectures.
--
-- This module implements a ROM module whose content can be configured
-- through a serial scan chain. The memory access is asynchronous. The
-- content reconfiguration is controlled by the configuration clock cclk
-- and the associated enable signal cena. For its integration in a
-- scan chain, use the configuration data input cdin and the output cdout.
--
-- The serial bit order of the memory contents is as follows:
--
--   MSB,   addr 2^ABITS-1               (input first)
--   MSB,   addr 2^ABITS-2
--     ...
--   MSB,   addr 1
--   MSB,   addr 0
--
--   MSB-1, addr 2^ABITS-1
--   MSB-1, addr 2^ABITS-2
--     ...
--   MSB-1, addr 1
--   MSB-1, addr 0
--
--     ...
--   LSB,   addr 2^ABITS-1
--   LSB,   addr 2^ABITS-2
--     ...
--   LSB,   addr 1
--   LSB,   addr 0                       (input last)
--
library IEEE;
use IEEE.std_logic_1164.all;

entity ocrom_chain is
  generic (
    WIDTH : positive;                   -- Data Width
    ABITS : positive                    -- Address Bits
  );
  port (
    -- Configuration
    cclk  : in  std_logic;              -- Clock
    cena  : in  std_logic;              -- Enable: Shift cdin on cclk
    cdin  : in  std_logic;              -- Chain Input
    cdout : out std_logic;              -- Chain Output

    -- Data Output (Async without cclk and cena)
    addr : in  std_logic_vector(ABITS-1 downto 0);
    dout : out std_logic_vector(WIDTH-1 downto 0)
  );
end ocrom_chain;

library IEEE;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

architecture rtl of ocrom_chain is
begin  -- rtl

  assert ABITS >= 4
    report "Must have at least 4 address bits."
    severity failure;

  genEQ4: if ABITS = 4 generate
    constant M : positive := WIDTH/2;      -- Number of SRL16x2s
    constant R : natural  := WIDTH mod 2;  -- Number of SRL16s

    signal cnct : std_logic_vector(M+R downto 0);  -- Inter-LUT Connects
  begin

    -- Initial Scan Chain Input
    cnct(0) <= cdin;

    -- CFGLUT5 (SRL16x2) Chain
    gen16x2: for i in 0 to M-1 generate
     lutm: CFGLUT5
      port map (
        I0  => addr(0),                 -- Logic data input
        I1  => addr(1),                 -- Logic data input
        I2  => addr(2),                 -- Logic data input
        I3  => addr(3),                 -- Logic data input
        I4  => '1',                     -- Logic data input
        O5  => dout(2*i),               -- 4-LUT output
        O6  => dout(2*i+1),             -- 5-LUT output
        CLK => cclk,                    -- Clock input
        CE  => cena,                    -- Reconfiguration enable input
        CDI => cnct(i),                 -- Reconfiguration data input
        CDO => cnct(i+1)                -- Reconfiguration cascade output
      );
    end generate gen16x2;

    -- Final SRL16 if necessary
    genLast: if R > 0 generate
      lutm: SRLC16E
        port map (
          A0  => addr(0),               -- Logic data input
          A1  => addr(1),               -- Logic data input
          A2  => addr(2),               -- Logic data input
          A3  => addr(3),               -- Logic data input
          Q   => dout(WIDTH-1),         -- SRL data output
          CLK => cclk,                  -- Clock input
          CE  => cena,                  -- Clock enable input
          D   => cnct(M),               -- SRL data input
          Q15 => cnct(M+1)              -- SRL cascade output pin
        );
    end generate genLast;

    -- Final Scan Chain Output
    cdout <= cnct(M+R);

  end generate genEQ4;

  genGT4: if ABITS > 4 generate
    -- Required Count of Sub Memories
    constant SUBS : positive := 2**(ABITS-5);

    -- Inter-LUT Shift Connections
    signal cnct : std_logic_vector(WIDTH*SUBS downto 0);

  begin

    -- Initial Scan Chain Input
    cnct(0) <= cdin;

    -- SRL32 Chain
    genWidth: for w in 0 to WIDTH-1 generate
      signal sdout : std_logic_vector(SUBS-1 downto 0);
    begin
      genSubs: for s in 0 to SUBS-1 generate

        SRLC32E_i : SRLC32E
          port map (
            Q   => sdout(s),              -- SRL data output
            Q31 => cnct(w*SUBS + s + 1),  -- SRL cascade output pin
            A   => addr(4 downto 0),      -- 5-bit shift depth select input
            CE  => cena,                  -- Clock enable input
            Clk => cclk,                  -- Clock input
            D   => cnct(w*SUBS + s)       -- SRL data input
            );

        -- MUX Bit Position Output in Presence of Sub Memories
        genSingle: if SUBS = 1 generate
          dout(w) <= sdout(0);
        end generate;
        genMulti: if SUBS > 1 generate
          dout(w) <= sdout(to_integer(unsigned(addr(ABITS-1 downto 5))));
        end generate;

      end generate genSubs;
    end generate genWidth;

    -- Final Scan Chain Output
    cdout <= cnct(WIDTH*SUBS);

  end generate genGT4;

end rtl;
