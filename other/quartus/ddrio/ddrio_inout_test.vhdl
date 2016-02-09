library ieee;
use ieee.std_logic_1164.all;

library poc;
use poc.ddrio.all;

entity ddrio_inout_test is

  generic (
    BITS : POSITIVE := 2);

  port (
    ClockOut	   : in	   STD_LOGIC;
    ClockOutEnable : in	   STD_LOGIC;
    OutputEnable   : in	   STD_LOGIC;
    DataOut_high   : in	   STD_LOGIC_VECTOR(BITS - 1 downto 0);
    DataOut_low	   : in	   STD_LOGIC_VECTOR(BITS - 1 downto 0);
    ClockIn	   : in	   STD_LOGIC;
    ClockInEnable  : in	   STD_LOGIC;
    DataIn_high	   : out   STD_LOGIC_VECTOR(BITS - 1 downto 0);
    DataIn_low	   : out   STD_LOGIC_VECTOR(BITS - 1 downto 0);
    Pad		   : inout STD_LOGIC_VECTOR(BITS - 1 downto 0));

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
