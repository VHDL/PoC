library ieee;
use ieee.std_logic_1164.all;

library poc;
use poc.ddrio.all;

entity ddrio_in_test is

  generic (
    BITS	: positive := 2;
    INIT_VALUE 	: bit_vector(1 downto 0) := "10");

  port (
    Clock	: in	std_logic;
    ClockEnable : in	std_logic;
    DataIn_high : out	std_logic_vector(BITS - 1 downto 0);
    DataIn_low	: out	std_logic_vector(BITS - 1 downto 0);
    Pad		: inout std_logic_vector(BITS - 1 downto 0));

end entity ddrio_in_test;

architecture rtl of ddrio_in_test is
begin
  i: ddrio_in
    generic map (
      BITS	  => BITS,
      INIT_VALUE  => INIT_VALUE)
    port map (
      Clock	  => Clock,
      ClockEnable => ClockEnable,
      DataIn_high => DataIn_high,
      DataIn_low  => DataIn_low,
      Pad	  => Pad);
end rtl;
