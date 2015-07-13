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
-- Entity: ddrio_out_virtex5
-- Author(s): Martin Zabel
-- 
-- Instantiates Chip-specific DDR output registers on Virtex-5.
--
-- See ../rtl/ddrio_out.vhdl for interface description.
-- 
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2009-02-17 17:32:56 $
--

library ieee;
use ieee.std_logic_1164.ALL;

library unisim;
use unisim.vcomponents.all;

entity ddrio_out_virtex5 is
  
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

end ddrio_out_virtex5;

architecture rtl of ddrio_out_virtex5 is
begin  -- rtl

  l: for i in 0 to WIDTH-1 generate
    signal o : std_logic;
  begin
     dff : ODDR
      generic map(
        DDR_CLK_EDGE => "SAME_EDGE",
        INIT => '1',
        SRTYPE => "SYNC")
      port map (
        Q => o,
        C => clk,
        CE => ce,
        D1 => dh(i),
        D2 => dl(i),
        R => '0',
        S => '0');

     gOE: if not NO_OE generate
       signal oe_n : std_logic;
       signal t    : std_logic;
     begin
       oe_n <= not oe;                  -- separate statement for ModelSim
       
       oeff : ODDR
         generic map(
           DDR_CLK_EDGE => "SAME_EDGE",
           INIT => '1',
           SRTYPE => "SYNC")
         port map (
           Q => t,
           C => clk,
           CE => ce,
           D1 => oe_n,
           D2 => oe_n,
           R => '0',
           S => '0');

       q(i) <= o when t = '0' else 'Z';  -- 't' is low-active!
     end generate gOE;

     gNoOE: if NO_OE generate
       q(i) <= o;
     end generate gNoOE;
     
  end generate l;

end rtl;
