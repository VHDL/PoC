--
-- Copyright (c) 2013
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
-- Entity: arith_prefix_and_tb
-- Author(s): Thomas Preusser <thomas.preusser@tu-dresden.de>
-- 
-- Testbench for arith_prefix_and.
--
entity arith_prefix_or_tb is
end arith_prefix_or_tb;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture tb of arith_prefix_or_tb is

  component arith_prefix_or is
    generic (
      N : positive
    );
    port (
      x : in  std_logic_vector(N-1 downto 0);
      y : out std_logic_vector(N-1 downto 0)
    );
  end component;

  -- component generics
  constant N : positive := 8;

  -- component ports
  signal x : std_logic_vector(N-1 downto 0);
  signal y : std_logic_vector(N-1 downto 0);

begin  -- tb

  -- component instantiation
  DUT: arith_prefix_or
    generic map (
      N => N
    )
    port map (
      x => x,
      y => y
    );

  -- Stimuli
  process
  begin
    for i in 0 to 2**N-1 loop
      x <= std_logic_vector(to_unsigned(i, N));
      wait for 10 ns;
      for j in 0 to N-1 loop
        assert (y(j) = '1') = (x(j downto 0) /= (j downto 0 => '0'))
          report "Wrong result for "&integer'image(i)&" / "&integer'image(j)
          severity error;
      end loop;
    end loop;
    report "Test completed." severity note;
    wait;
  end process;

end tb;
