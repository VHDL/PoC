library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;
use PoC.axi4.all;

entity AXI4Stream_Termination_Master is
  Generic (
    VALUE         : std_logic := '0'
  );
  Port ( 
    -- OUT Port
		Out_M2S           : out T_AXI4Stream_M2S;
		Out_S2M           : in T_AXI4Stream_S2M
  );
end entity;

architecture rtl of AXI4Stream_Termination_Master is
  constant UserBits : natural := Out_M2S.User'length;
  constant DataBits : natural := Out_M2S.Data'length;
begin

  Out_M2S <= Initialize_AXI4Stream_M2S(DataBits, UserBits, VALUE);

end architecture;
