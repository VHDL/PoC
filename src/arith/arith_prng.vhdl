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
-- Entity: arith_prng
-- Author(s): Martin Zabel
-- 
-- Pseudo-Random Number Generator
--
-- Signal description:
--  'rst'   reset value to initial seed.
--  'got'   the current value has been got, and a new value should be
--          calculated.
--  'val'   the pseudo-random number.
--
-- The number sequence includes the value all-zeros, but not all-ones.
--
-- Synchronized Reset is used.
--
-- Revision:    $Revision: 1.8 $
-- Last change: $Date: 2013-05-27 14:02:36 $
--
-------------------------------------------------------------------------------
-- Naming Conventions:
-- (Based on: Keating and Bricaud: "Reuse Methodology Manual")
--
-- active low signals: "*_n"
-- clock signals: "clk", "clk_div#", "clk_#x"
-- reset signals: "rst", "rst_n"
-- generics: all UPPERCASE
-- user defined types: "*_TYPE"
-- state machine next state: "*_ns"
-- state machine current state: "*_cs"
-- output of a register: "*_r"
-- asynchronous signal: "*_a"
-- pipelined or register delay signals: "*_p#"
-- data before being registered into register with the same name: "*_nxt"
-- clock enable signals: "*_ce"
-- internal version of output port: "*_i"
-- tristate internal signal "*_z"
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity arith_prng is
  generic (
    BITS : positive;
    SEED : natural := 0
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    got   : in  std_logic;
    val   : out std_logic_vector(BITS-1 downto 0));

end arith_prng;

architecture rtl of arith_prng is

  -- The current value
  signal val_r    : std_logic_vector(BITS downto 1);
  signal bit1_nxt : std_logic;
  
begin  -- rtl
 
  assert BITS = 8 or BITS = 9 or BITS = 16 or BITS = 18 or BITS = 23 or
    BITS = 24 or BITS = 32 or BITS = 36 or BITS = 64 or BITS = 128
    report "Width not yet supported." severity failure;
  
  -----------------------------------------------------------------------------
  -- Datapath
  -----------------------------------------------------------------------------

  -- tap positions are taken from XAPP052
  -- XNOR used so that all-zero is valid and all-one is forbidden.
  g8: if BITS = 8 generate
    bit1_nxt <= val_r(8) xnor val_r(6) xnor val_r(5) xnor val_r(4);
  end generate g8;

  g9: if BITS = 9 generate
    bit1_nxt <= val_r(9) xnor val_r(5);
  end generate g9;

  g16: if BITS = 16 generate
    bit1_nxt <= val_r(16) xnor val_r(15) xnor val_r(13) xnor val_r(4);
  end generate g16;

  g18: if BITS = 18 generate
    bit1_nxt <= val_r(18) xnor val_r(11);
  end generate g18;

  g23: if BITS = 23 generate
    bit1_nxt <= val_r(23) xnor val_r(18);
  end generate g23;

  g24: if BITS = 24 generate
    bit1_nxt <= val_r(24) xnor val_r(23) xnor val_r(22) xnor val_r(17);
  end generate g24;

  g32: if BITS = 32 generate
    bit1_nxt <= val_r(32) xnor val_r(22) xnor val_r(2) xnor val_r(1);
  end generate g32;

  g36: if BITS = 36 generate
    bit1_nxt <= val_r(36) xnor val_r(25);
  end generate g36;
  
  g64: if BITS = 64 generate
    bit1_nxt <= val_r(64) xnor val_r(63) xnor val_r(61) xnor val_r(60);
  end generate g64;

  g128: if BITS = 128 generate
    bit1_nxt <= val_r(128) xnor val_r(126) xnor val_r(101) xnor val_r(99);
  end generate g128;

  -----------------------------------------------------------------------------
  -- Register
  -----------------------------------------------------------------------------

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        val_r <= std_logic_vector(to_unsigned(SEED, BITS));
      elsif got = '1' then
        val_r(1) <= bit1_nxt;
        val_r(val_r'left downto 2) <= val_r(val_r'left-1 downto 1);
      end if;
    end if;
  end process;
  
  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  val   <= val_r;

end rtl;
