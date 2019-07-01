
library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.utils.all;
use     PoC.axi4.all;

entity AXI4Lite_AddressMask is
  Generic (
    ADDRESS_MASK  : std_logic_vector
  );
	Port (
    M_AXI_m2s               : out T_AXI4Lite_BUS_M2S := Initialize_AXI4Lite_Bus_M2S(32, 32);
    M_AXI_s2m               : in  T_AXI4Lite_BUS_S2M := Initialize_AXI4Lite_Bus_S2M(32, 32);
		S_AXI_m2s               : in  T_AXI4Lite_BUS_M2S := Initialize_AXI4Lite_Bus_M2S(32, 32);
		S_AXI_s2m               : out T_AXI4Lite_BUS_S2M := Initialize_AXI4Lite_Bus_S2M(32, 32)
	);
end entity;

architecture rtl of AXI4Lite_AddressMask is

begin
  --SLAVE
  S_AXI_s2m.WReady     <= M_AXI_s2m.WReady ;
	S_AXI_s2m.BValid     <= M_AXI_s2m.BValid ;
	S_AXI_s2m.BResp      <= M_AXI_s2m.BResp  ;
	S_AXI_s2m.ARReady    <= M_AXI_s2m.ARReady;
	S_AXI_s2m.AWReady    <= M_AXI_s2m.AWReady;
	S_AXI_s2m.RValid     <= M_AXI_s2m.RValid ;
	S_AXI_s2m.RData      <= M_AXI_s2m.RData  ;
	S_AXI_s2m.RResp      <= M_AXI_s2m.RResp  ;

  
	--MASTER
	M_AXI_m2s.AWValid    <= S_AXI_m2s.AWValid ;
	M_AXI_m2s.AWAddr     <= S_AXI_m2s.AWAddr  and ADDRESS_MASK;
  M_AXI_m2s.AWCache    <= S_AXI_m2s.AWCache ;
	M_AXI_m2s.AWProt     <= S_AXI_m2s.AWProt  ;
	M_AXI_m2s.WValid     <= S_AXI_m2s.WValid  ;
	M_AXI_m2s.WData      <= S_AXI_m2s.WData   ;
	M_AXI_m2s.WStrb      <= S_AXI_m2s.WStrb   ;
	M_AXI_m2s.BReady     <= S_AXI_m2s.BReady  ;
	M_AXI_m2s.ARValid    <= S_AXI_m2s.ARValid ;
	M_AXI_m2s.ARAddr     <= S_AXI_m2s.ARAddr  and ADDRESS_MASK;
  M_AXI_m2s.ARCache    <= S_AXI_m2s.ARCache ;
	M_AXI_m2s.ARProt     <= S_AXI_m2s.ARProt  ;
	M_AXI_m2s.RReady     <= S_AXI_m2s.RReady  ;

    
end architecture;
