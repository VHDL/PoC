library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;
use PoC.axi4.all;

entity AXI4_Termination_Master is
  Generic (
    VALUE     : std_logic := '0'
  );
  Port ( 
    AXI4_M2S  : out T_AXI4_Bus_M2S;
    AXI4_S2M  : in  T_AXI4_Bus_S2M
  );
end entity;

architecture rtl of AXI4_Termination_Master is
  constant AddrBits : natural := AXI4_M2S.AWAddr'length;
  constant IDBits   : natural := AXI4_M2S.AWID'length;
  constant UserBits : natural := AXI4_M2S.AWUser'length;
  constant DataBits : natural := AXI4_M2S.WData'length;
begin

  T_AXI4_Bus_M2S <= Initialize_AXI4_Bus_M2S(AddrBits, DataBits, UserBits, IDBits, VALUE);

end architecture;
