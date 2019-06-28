library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;
use PoC.axi4.all;

entity AXI4Stream_Termination_Slave is
  Generic (
    VALUE         : std_logic := '0'
  );
  Port ( 
    -- IN Port
		In_M2S           : in T_AXI4Stream_M2S;
		In_S2M           : out T_AXI4Stream_S2M
  );
end entity;

architecture rtl of AXI4Stream_Termination_Slave is
begin
  In_S2M <= Initialize_AXI4Stream_S2M(DataBits, UserBits, VALUE);
end architecture;
