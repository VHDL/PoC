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
-- Entity: ddrio_out
-- Author(s): Martin Zabel
-- 
-- Instantiates Chip-specific DDR output registers.
--
-- Output enable "oe" is high-active. It is automatically inverted if
-- necessary.
--
-- If an output enable ist not required, you may save some logic by setting
-- NO_OE = true. However, oe must be set to '1'.
--
-- Both data "dh" and "dl" as well as "oe" are sampled with the
-- rising_edge(clk) from the on-chip logic. "dh" is brought with this
-- rising edge. "dl" is brought out with the falling edge.
--
-- "q" must be connected to a PAD because FPGAs only have these registers in
-- IOBs.
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2009-02-17 17:47:07 $
--

library ieee;
use ieee.std_logic_1164.ALL;

library poc;
use poc.config.all;

entity ddrio_out is
  
  generic (
    NO_OE : boolean := false;
    WIDTH : positive);

  port (
    clk : in  std_logic;
    ce  : in  std_logic;
    dh  : in  std_logic_vector(WIDTH-1 downto 0);
    dl  : in  std_logic_vector(WIDTH-1 downto 0);
    oe  : in  std_logic;
    q   : out std_logic_vector(WIDTH-1 downto 0));

end ddrio_out;

architecture rtl of ddrio_out is
  component ddrio_out_virtex5
    generic (
      NO_OE : boolean;
      WIDTH : positive);
    port (
      clk : in  std_logic;
      ce  : in  std_logic;
      dh  : in  std_logic_vector(WIDTH-1 downto 0);
      dl  : in  std_logic_vector(WIDTH-1 downto 0);
      oe  : in  std_logic;
      q   : out std_logic_vector(WIDTH-1 downto 0));
  end component;

  component ddrio_out_altera
    generic (
      WIDTH : positive);
    port (
      clk : in  std_logic;
      ce  : in  std_logic;
      dh  : in  std_logic_vector(WIDTH-1 downto 0);
      dl  : in  std_logic_vector(WIDTH-1 downto 0);
      oe  : in  std_logic;
      q   : out std_logic_vector(WIDTH-1 downto 0));
  end component;
  
begin  -- rtl

  assert (DEVICE = DEVICE_VIRTEX5) or (VENDOR = VENDOR_ALTERA)
    report "ddrio_out not implemented for given DEVICE."
    severity failure;
  
  gVirtex5: if DEVICE = DEVICE_VIRTEX5 generate
    i: ddrio_out_virtex5
      generic map (
        NO_OE => NO_OE,
        WIDTH => WIDTH)
      port map (
        clk => clk,
        ce  => ce,
        dh  => dh,
        dl  => dl,
        oe  => oe,
        q   => q);
  end generate gVirtex5;

  gAltera: if VENDOR = VENDOR_ALTERA generate
    i: ddrio_out_altera
      generic map (
        WIDTH => WIDTH)
      port map (
        clk => clk,
        ce  => ce,
        dh  => dh,
        dl  => dl,
        oe  => oe,
        q   => q);
  end generate gAltera;
end rtl;
