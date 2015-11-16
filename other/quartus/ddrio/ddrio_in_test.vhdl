library ieee;
use ieee.std_logic_1164.all;

library poc;
use poc.ddrio.all;

entity ddrio_in_test is

  generic (
    BITS	: POSITIVE := 2;
    INIT_VALUE 	: BIT_VECTOR(1 downto 0) := "10");

  port (
    Clock	: in	STD_LOGIC;
    ClockEnable : in	STD_LOGIC;
    DataIn_high : out	STD_LOGIC_VECTOR(BITS - 1 downto 0);
    DataIn_low	: out	STD_LOGIC_VECTOR(BITS - 1 downto 0);
    Pad		: inout STD_LOGIC_VECTOR(BITS - 1 downto 0));

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
