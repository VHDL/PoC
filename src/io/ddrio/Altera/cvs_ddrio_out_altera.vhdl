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
-- Entity: ddrio_out_altera
-- Author(s): Martin Zabel
-- 
-- Instantiates Chip-specific DDR output registers on Virtex-5.
--
-- See ../rtl/ddrio_out.vhdl for interface description.
-- 
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2009-02-17 17:47:07 $
--

library ieee;
use ieee.std_logic_1164.ALL;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity ddrio_out_altera is
  
  generic (
    WIDTH : positive);

  port (
    clk : in  std_logic;
    ce  : in  std_logic;
    dh  : in  std_logic_vector(WIDTH-1 downto 0);
    dl  : in  std_logic_vector(WIDTH-1 downto 0);
    oe  : in  std_logic;
    q   : out std_logic_vector(WIDTH-1 downto 0));

end ddrio_out_altera;

architecture rtl of ddrio_out_altera is
begin  -- rtl

  ff : altddio_out
    generic map (
      width                  => WIDTH,
      INTENDED_DEVICE_FAMILY => "STRATIXII")  -- TODO
    port map (
        datain_h => dh,
        datain_l => dl,
        oe       => oe,
        oe_out   => open,
        outclock => clk,
        dataout  => q);

end rtl;
