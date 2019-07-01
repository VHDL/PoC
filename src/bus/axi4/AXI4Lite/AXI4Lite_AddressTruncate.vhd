
library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.utils.all;
use     PoC.axi4.all;

entity AXI4Lite_AddressTruncate is
	Port (
    M_AXI_m2s               : out T_AXI4Lite_BUS_M2S;
    M_AXI_s2m               : in  T_AXI4Lite_BUS_S2M;
		S_AXI_m2s               : in  T_AXI4Lite_BUS_M2S;
		S_AXI_s2m               : out T_AXI4Lite_BUS_S2M
	);
end entity;

architecture rtl of AXI4Lite_AddressTruncate is
  constant ADDR_OUT_BITS : positive := M_AXI_m2s.AWAddr'length;
  constant ADDR_IN_BITS  : positive := S_AXI_m2s.AWAddr'length;

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
	M_AXI_m2s.AWAddr     <= ite(    ADDR_OUT_BITS > ADDR_IN_BITS, 
                                  ADDR_IN_BITS -ADDR_OUT_BITS -1 downto 0 => '0' & S_AXI_m2s.AWAddr, 
                                  S_AXI_m2s.AWAddr(ADDR_OUT_BITS -1 downto 0);
  M_AXI_m2s.AWCache    <= S_AXI_m2s.AWCache ;
	M_AXI_m2s.AWProt     <= S_AXI_m2s.AWProt  ;
	M_AXI_m2s.WValid     <= S_AXI_m2s.WValid  ;
	M_AXI_m2s.WData      <= S_AXI_m2s.WData   ;
	M_AXI_m2s.WStrb      <= S_AXI_m2s.WStrb   ;
	M_AXI_m2s.BReady     <= S_AXI_m2s.BReady  ;
	M_AXI_m2s.ARValid    <= S_AXI_m2s.ARValid ;
	M_AXI_m2s.ARAddr     <= ite(    ADDR_OUT_BITS > ADDR_IN_BITS, 
                                  ADDR_IN_BITS -ADDR_OUT_BITS -1 downto 0 => '0' & S_AXI_m2s.AWAddr, 
                                  S_AXI_m2s.AWAddr(ADDR_OUT_BITS -1 downto 0);
  M_AXI_m2s.ARCache    <= S_AXI_m2s.ARCache ;
	M_AXI_m2s.ARProt     <= S_AXI_m2s.ARProt  ;
	M_AXI_m2s.RReady     <= S_AXI_m2s.RReady  ;

end architecture;
