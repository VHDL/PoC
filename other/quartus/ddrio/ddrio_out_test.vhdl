library ieee;
use ieee.std_logic_1164.all;

library poc;
use poc.ddrio.all;

entity ddrio_out_test is

  generic (
    NO_OUTPUT_ENABLE : boolean	  := false;
    BITS	     : positive   := 2;
    INIT_VALUE	     : bit_vector(1 downto 0) := "10");

  port (
    Clock	 : in  std_logic;
    OutputEnable : in  std_logic;
    DataOut_high : in  std_logic_vector(BITS - 1 downto 0);
    DataOut_low	 : in  std_logic_vector(BITS - 1 downto 0);
    Pad		 : out std_logic_vector(BITS - 1 downto 0));

end entity ddrio_out_test;

architecture rtl of ddrio_out_test is
  signal MyClock       : std_logic;
  signal MyClockEnable : std_logic;
begin
  pll: entity work.pll_c3
    port map (
      inclk0 => Clock,
      c0     => MyClock,
      locked => MyClockEnable);

  i : ddrio_out
    generic map (
      NO_OUTPUT_ENABLE => NO_OUTPUT_ENABLE,
      BITS	       => BITS,
      INIT_VALUE       => INIT_VALUE)
    port map (
      Clock	   => MyClock,
      ClockEnable  => MyClockEnable,
      OutputEnable => OutputEnable,
      DataOut_high => DataOut_high,
      DataOut_low  => DataOut_low,
      Pad	   => Pad);
end rtl;
