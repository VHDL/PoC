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
-- Package: ddrio
-- Author(s): Martin Zabel
-- 
-- DDR-IO registers.
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2009-02-19 15:56:48 $
--

library ieee;
use ieee.std_logic_1164.ALL;

package ddrio is

  component ddrio_out
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
  end component;

end ddrio;

package body ddrio is
end ddrio;
