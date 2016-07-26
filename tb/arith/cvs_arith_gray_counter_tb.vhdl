--
-- Copyright (c) 2012
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
-- Entity: arith_gray_counter_tb
-- Author(s): Thomas Preusser <thomas.preusser@tu-dresden.de>
--
-- Testbench for arith_gray_counter
--
-- Revision:    $Revision: 1.4 $
-- Last change: $Date: 2012-09-26 12:51:59 $
--
entity arith_gray_counter_tb is
end arith_gray_counter_tb;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture tb of arith_gray_counter_tb is

  component arith_gray_counter is
    generic (
      BITS      : positive;      -- Bit Width of Counter
      INIT      : natural := 0   -- Binary Position of Counter Value after Reset
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

  -- component generics
  constant N : positive := 8;

  -- component ports
  signal clk : std_logic;
  signal rst : std_logic;
  signal inc : std_logic;
  signal dec : std_logic;
  signal val : std_logic_vector(N-1 downto 0);
  signal cry : std_logic;

begin

  -- component instantiation
  DUT: arith_gray_counter
    generic map (
      BITS      => N
    )
    port map (
      clk => clk,
      rst => rst,
      inc => inc,
      dec => dec,
      val => val,
      cry => cry
    );

  process
    procedure cycle is
    begin
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    end cycle;

    variable  v  : unsigned(N-1 downto 0);
    variable  ok : boolean := true;
  begin
    rst <= '1';
    cycle;
    rst <= '0';

    if val /= (val'range => '0') then
      report "Unexpected Value @RST" severity error;
      ok := false;
    end if;

    inc <= '1';
    dec <= '0';
    for i in 1 to 2**N loop
      cycle;
      v := to_unsigned(i mod 2**N, N);
      if unsigned(val) /= (v xor ('0' & v(N-1 downto 1))) then
        report "Unexpected Value @INC "&integer'image(i) severity error;
        ok := false;
      end if;
    end loop;

    inc <= '0';
    dec <= '1';
    for i in 2**N-1 downto 0 loop
      cycle;
      v := to_unsigned(i, N);
      if unsigned(val) /= (v xor ('0' & v(N-1 downto 1))) then
        report "Unexpected Value @DEC "&integer'image(i) severity error;
        ok := false;
      end if;
    end loop;

    if ok then
      report "Test completed successfully." severity note;
    else
      report "Test failed." severity note;
    end if;
    wait;
  end process;

end tb;
