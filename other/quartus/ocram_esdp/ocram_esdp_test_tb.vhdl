-------------------------------------------------------------------------------
-- Title      : Testbench for design "ocram_esdp_test"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ocram_esdp_test_tb.vhdl
-- Author     : Martin Zabel  <zabel@ite161.inf.tu-dresden.de>
-- Company    : 
-- Created    : 2015-02-17
-- Last update: 2015-02-18
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2015-02-17  1.0      zabel	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------

entity ocram_esdp_test_tb is

end entity ocram_esdp_test_tb;

-------------------------------------------------------------------------------

architecture sim of ocram_esdp_test_tb is

  -- component generics
  constant A_BITS : positive := 8;
  constant D_BITS : positive := 16;

  -- component ports
  signal clk1 : std_logic := '1';
  signal clk2 : std_logic := '1';
  signal ce1  : std_logic;
  signal ce2  : std_logic;
  signal we1  : std_logic;
  signal a1   : unsigned(A_BITS-1 downto 0);
  signal a2   : unsigned(A_BITS-1 downto 0);
  signal d1   : std_logic_vector(D_BITS-1 downto 0);
  signal q1   : std_logic_vector(D_BITS-1 downto 0);
  signal q2   : std_logic_vector(D_BITS-1 downto 0);

  signal clk2_i : std_logic := '1';
begin  -- architecture sim

  -- component instantiation
  NA: entity work.ocram_esdp_test
    port map (
      clk1 => clk1,
      clk2 => clk2,
      ce1  => ce1,
      ce2  => ce2,
      we1  => we1,
      a1   => a1, --std_logic_vector(a1),
      a2   => a2, --std_logic_vector(a2),
      d1   => d1,
      q1   => q1,
      q2   => q2);

  -- clock generation
  clk1   <= not clk1   after 60 ns;
  clk2_i <= not clk2_i after 10 ns;
  
  clk2   <= transport clk2_i after 100 ps; -- small phase shift
  
  WriteGen_Proc: process
  begin
    wait until rising_edge(clk1);
    ce1 <= '1';
    we1 <= '0';

    for i in 0 to 15 loop
      wait until rising_edge(clk1);
      a1  <= to_unsigned(i, A_BITS);
      d1  <= x"D" & std_logic_vector(to_unsigned(i, D_BITS-4));
      we1 <= '1';
    end loop;  -- i

    wait until rising_edge(clk1);
    we1 <= '0';

    wait;
  end process WriteGen_Proc;

  ReadGen_Proc: process is
  begin
    wait until rising_edge(clk2);
    ce2 <= '1';
    a2  <= to_unsigned(1, A_BITS);

    -- loop
  end process ReadGen_Proc;

end architecture sim;

-------------------------------------------------------------------------------

configuration ocram_esdp_test_tb_sim_cfg of ocram_esdp_test_tb is
  for sim
  end for;
end ocram_esdp_test_tb_sim_cfg;

-------------------------------------------------------------------------------
