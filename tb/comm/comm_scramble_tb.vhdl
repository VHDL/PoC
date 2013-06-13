--
-- Copyright (c) 2011
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
-- Entity: scramble_tb
-- Author(s): Thomas B. Preusser <thomas.preusser@tu-dresden.de>
--
-- Test bench for scramble using the SATA polynomial.
--

entity comm_scramble_tb is
end comm_scramble_tb;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture tb of comm_scramble_tb is

  -- Hex Translation
  type tHex is array(0 to 15) of character;
  constant HEX : tHex := (
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
  );

  -- Reference
  type tRef is array(natural range<>) of std_logic_vector(15 downto 0);
  constant REF : tREF := (
    x"768D", x"C2D2", x"B368", x"1F26", x"436C", x"A508", x"D354", x"3452",
    x"9502", x"8A55", x"BE1B", x"BB1A", x"B73D", x"FA56", x"0B1B", x"53F6",
    x"9C41", x"F080", x"C34A", x"747F", x"5291", x"BE86", x"A7B6", x"7A6F",
    x"E6D6", x"3163", x"FE0C", x"F036", x"EA29", x"1EF3", x"2694", x"EB34"
  );

  -- DUT
  component comm_scramble
    generic (
      GEN  : bit_vector;
      BITS : positive
    ); 
    port (
      clk  : in  std_logic;
      set  : in  std_logic;
      din  : in  std_logic_vector(GEN'length-2 downto 0);
      step : in  std_logic;
      mask : out std_logic_vector(BITS-1 downto 0)
    ); 
  end component;

  -- Connectivity
  signal clk       : std_logic;
  signal rst, step : std_logic;
  signal mask      : std_logic_vector(15 downto 0);
  
begin

  -- DUT
  scramble_2 : comm_scramble
    generic map (
      GEN  => "11010000000010001",
      BITS => 16
    )
    port map (
      clk  => clk,
      set  => rst,
      din  => x"FFFF",
      step => step,
      mask => mask
    );

  -- Stimuli
  process

    -- Perform a Clock Cycle
    procedure cycle is
    begin
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
      clk <= '0';
    end cycle;

    variable errors : natural;
    
  begin
    clk <= '0';

    -- Reset Cycle
    rst  <= '1';
    step <= '0';
    cycle;

    rst  <= '0';
    step <= '1';

    -- Generate Output Sequence
    errors := 0;
    for i in REF'range loop
      cycle;
      if mask /= REF(i) then
        report "MISMATCH @"&integer'image(i)&": "&
            HEX(to_integer(unsigned(mask(15 downto 12))))&
            HEX(to_integer(unsigned(mask(11 downto  8))))&
            HEX(to_integer(unsigned(mask( 7 downto  4))))&
            HEX(to_integer(unsigned(mask( 3 downto  0))))&" for "&
            HEX(to_integer(unsigned(REF(i)(15 downto 12))))&
            HEX(to_integer(unsigned(REF(i)(11 downto  8))))&
            HEX(to_integer(unsigned(REF(i)( 7 downto  4))))&
            HEX(to_integer(unsigned(REF(i)( 3 downto  0))))
         severity error;
        errors := errors + 1;
      else
        report "OUTPUT @"&integer'image(i)&": "&
            HEX(to_integer(unsigned(mask(15 downto 12))))&
            HEX(to_integer(unsigned(mask(11 downto  8))))&
            HEX(to_integer(unsigned(mask( 7 downto  4))))&
            HEX(to_integer(unsigned(mask( 3 downto  0))))
          severity note;
      end if;
    end loop;

    report "Test completed: "&integer'image(errors)&" error(s).";
    wait;
  end process;
end tb;
