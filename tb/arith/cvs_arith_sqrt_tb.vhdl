--
-- Copyright (c) 2009
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
-- Test bench for iterative Square Root Extractor.
--
-- Author: Thomas B. Preußer <thomas.preusser@tu-dresden.de>
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-01-29 15:49:04 $
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity arith_sqrt_tb is

end arith_sqrt_tb;

architecture tb of arith_sqrt_tb is

  component arith_sqrt is
    generic (
      N : positive := 8                   -- Bit Width of Argument
    );
    port (
      -- Global Control
      rst : in std_logic;                 -- Reset (synchronous)
      clk : in std_logic;                 -- Clock

      -- Inputs
      arg   : in std_logic_vector(N-1 downto 0);  -- Radicand
      start : in std_logic;                       -- Start Strobe

      -- Outputs
      sqrt : out std_logic_vector((N-1)/2 downto 0);  -- Result
      rdy  : out std_logic                            -- Ready / Done
    );
  end component;

  constant N : positive := 10;


  signal hlt : std_logic := '0';
  signal clk : std_logic := '0';
  signal rst : std_logic;

  signal arg   : std_logic_vector(N-1 downto 0);
  signal start : std_logic;
  signal res   : std_logic_vector((N-1)/2 downto 0);
  signal rdy   : std_logic;

begin  -- tb

  -- Generate Clock
  clk <= not clk and not hlt after 5 ns;

  -- Stimuli Generation
  process
  begin
    rst <= '1';
    wait until rising_edge(clk);
    rst <= '0';

    for i in 0 to 2**N-1 loop
      arg <= std_logic_vector(to_unsigned(i, N));
      start <= '1';
      wait until rising_edge(clk) and rdy = '1';
      start <= '0';

      wait until rising_edge(clk) and rdy = '1';

      assert  to_integer(unsigned(res))   **2 <= i and
             (to_integer(unsigned(res))+1)**2 >  i
        report "Square root failed for " & integer'image(i)
        severity error;
    end loop;  -- i
    report "Test completed." severity note;
    hlt <= '1';
    wait;
  end process;

  sqrt_1: arith_sqrt
    generic map (
      N => N
    )
    port map (
      rst   => rst,
      clk   => clk,
      arg   => arg,
      start => start,
      sqrt  => res,
      rdy   => rdy
    );

end tb;
