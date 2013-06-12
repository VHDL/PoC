--
-- Copyright (c) 2008-2013
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
-- Package: alu
-- Author(s): Martin Zabel    <martin.zabel@tu-dresden.de>
--            Thomas Preusser <thomas.preusser@tu-dresden.de>
-- 
-- Commonly used modules for ALUs or like.
--
-- Revision:    $Revision: 1.9 $
-- Last change: $Date: 2013-05-27 14:02:36 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package arith_pkg is

  component arith_gray_counter is
    generic (
      BITS : positive;     -- Bit Width of Counter
      INIT : natural := 0  -- Binary Position of Counter Value after Reset
    );
    port (
      clk : in  std_logic;
      rst : in  std_logic;                          -- Reset to INIT Value
      inc : in  std_logic;                          -- Increment
      dec : in  std_logic := '0';                   -- Decrement
      val : out std_logic_vector(BITS-1 downto 0);  -- Value Output
      cry : out std_logic                           -- Carry Output
    );
  end component;

  component arith_prng
    generic (
      BITS : positive;
      SEED : natural := 0
    );
    port (
      clk : in  std_logic;
      rst : in  std_logic;
      got : in  std_logic;
      val : out std_logic_vector(BITS-1 downto 0));
  end component;

  component arith_muls_wide
    generic (
      NA    : integer range 2 to 18;
      NB    : integer range 19 to 36;
      SPLIT : positive);
    port (
      a : in  signed(NA-1 downto 0);
      b : in  signed(NB-1 downto 0);
      p : out signed(NA+NB-1 downto 0));
  end component;

  component arith_sqrt
    generic (
      N : positive);
    port (
      rst   : in  std_logic;
      clk   : in  std_logic;
      arg   : in  std_logic_vector(N-1 downto 0);
      start : in  std_logic;
      sqrt  : out std_logic_vector((N-1)/2 downto 0);
      rdy   : out std_logic);
  end component;
  
  component arith_div
    generic (
      N          : positive;
      RAPOW      : positive;
      REGISTERED : boolean);
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      start      : in  std_logic;
      rdy        : out std_logic;
      arg1, arg2 : in  std_logic_vector(N-1 downto 0);
      res        : out std_logic_vector(N-1 downto 0));
  end component;
end arith_pkg;

package body arith_pkg is
end arith_pkg;
