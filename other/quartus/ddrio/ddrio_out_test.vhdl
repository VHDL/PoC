library ieee;
use ieee.std_logic_1164.all;

library poc;
use poc.ddrio.all;

entity ddrio_out_test is

  generic (
    NO_OUTPUT_ENABLE : BOOLEAN	  := false;
    BITS	     : POSITIVE   := 2;
    INIT_VALUE	     : BIT_VECTOR(1 downto 0) := "10");

  port (
    Clock	 : in  STD_LOGIC;
    OutputEnable : in  STD_LOGIC;
    DataOut_high : in  STD_LOGIC_VECTOR(BITS - 1 downto 0);
    DataOut_low	 : in  STD_LOGIC_VECTOR(BITS - 1 downto 0);
    Pad		 : out STD_LOGIC_VECTOR(BITS - 1 downto 0));

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
