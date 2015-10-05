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
-- Test bench for arith_same module.
--
-- Author: Thomas B. Preußer <thomas.preusser@tu-dresden.de>
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-07-20 13:10:08 $
--

entity arith_same_tb is
end arith_same_tb;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture tb of arith_same_tb is

  component arith_same is
    generic (
      N : positive                             -- Input width
    );
    port (
      g : in  std_logic := '1';                -- Guard Input (!g => !y)
      x : in  std_logic_vector(N-1 downto 0);  -- Input Vector
      y : out std_logic                        -- All-same Output
    );
  end component;

  type tTest is record
                  arg : std_logic_vector(19 downto 0);  -- input
                  res : std_logic_vector( 2 downto 0);  -- expected output
                end record;
  type tTests is array(natural range<>) of tTest;
  constant TESTS : tTests := (
    (x"00000", "111"),
    (x"FFFFF", "111"),
    (x"11111", "000"),
    (x"00080", "100"),
    (x"1FFFF", "000"),
    (x"FFFF8", "110")
  );
  
  signal arg : std_logic_vector(19 downto 0);
  signal res : std_logic_vector( 2 downto 0);

begin  -- tb

  -- Stimuli Generation
  process
    variable test : tTest;
  begin
    for i in TESTS'range loop
      test := TESTS(i);
      arg <= test.arg;
      wait for 10 ns;
      assert  res = test.res
        report "Output mismatch."
        severity error;
    end loop;
    wait;
  end process;

  arith_same_2: arith_same
    generic map (
      N => 11
    )
    port map (
      g => '1',
      x => arg(19 downto 9),
      y => res(2)
    );
  arith_same_1: arith_same
    generic map (
      N =>  7
    )
    port map (
      g => res(2),
      x => arg(9 downto 3),
      y => res(1)
    );
  arith_same_0: arith_same
    generic map (
      N =>  4
    )
    port map (
      g => res(1),
      x => arg(3 downto 0),
      y => res(0)
    );
end tb;
