library ieee;
use ieee.std_logic_1164.all;

library poc;
use poc.ddrio.all;

entity ddrio_inout_test is

  generic (
    BITS : positive := 2);

  port (
    ClockOut	   : in	   std_logic;
    ClockOutEnable : in	   std_logic;
    OutputEnable   : in	   std_logic;
    DataOut_high   : in	   std_logic_vector(BITS - 1 downto 0);
    DataOut_low	   : in	   std_logic_vector(BITS - 1 downto 0);
    ClockIn	   : in	   std_logic;
    ClockInEnable  : in	   std_logic;
    DataIn_high	   : out   std_logic_vector(BITS - 1 downto 0);
    DataIn_low	   : out   std_logic_vector(BITS - 1 downto 0);
    Pad		   : inout std_logic_vector(BITS - 1 downto 0));

end entity ddrio_inout_test;

architecture rtl of ddrio_inout_test is

begin  -- architecture rtl

  i: ddrio_inout
    generic map (
      BITS => BITS)
    port map (
      ClockOut	     => ClockOut,
      ClockOutEnable => ClockOutEnable,
      OutputEnable   => OutputEnable,
      DataOut_high   => DataOut_high,
      DataOut_low    => DataOut_low,
      ClockIn	     => ClockIn,
      ClockInEnable  => ClockInEnable,
      DataIn_high    => DataIn_high,
      DataIn_low     => DataIn_low,
      Pad	     => Pad);

end architecture rtl;
