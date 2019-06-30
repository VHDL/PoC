
library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.axi4.all;
use     PoC.AXI4Lite_Version.all;
use     PoC.strings.all;
use     PoC.BuildVersion.all;

entity AXI4Lite_Version_Register is
	Port (
		S_AXI_ACLK              : in  std_logic;
		S_AXI_ARESETN           : in  std_logic;
		S_AXI_m2s               : in  T_AXI4Lite_BUS_M2S := Initialize_AXI4Lite_Bus_M2S(32, 32);
		S_AXI_s2m               : out T_AXI4Lite_BUS_S2M := Initialize_AXI4Lite_Bus_S2M(32, 32)
	);
end entity;

architecture Behavioral of AXI4Lite_Version_Register is
	constant ADDRESS_BITS  : natural                 := 32;
	constant DATA_BITS     : natural                 := 32;
	
	constant num_Version_register : natural          := get_num_Version_register;
  
  constant CONFIG     :   T_AXI4_Register_Description_Vector(0 to num_Version_register -1) := get_Dummy_Descriptor(num_Version_register);
	
	constant VersionData           : T_SLVV_32(0 to num_Version_register -1) := (
			0                 to Reg_Length_Common -1                  => to_SLVV_32_Common(C_HW_BUILD_VERSION_COMMON),
			Reg_Length_Common to Reg_Length_Common + Reg_Length_Top -1 => to_SLVV_32_Top(C_HW_BUILD_VERSION_TOP)
		);
		
	function to_slvv(data : T_SLVV_32) return T_SLVV is
		variable temp : T_SLVV(VersionData'range)(DATA_BITS -1 downto 0) := (others => (others => '0'));
	begin
		for i in VersionData'range loop
			temp(i) := data(i);
		end loop;
		return temp;
	end function;

  signal   RegisterFile_ReadPort   : T_SLVV(0 to CONFIG'Length -1)(DATA_BITS -1 downto 0) := (others => (others => '0'));
  constant RegisterFile_WritePort  : T_SLVV(0 to CONFIG'Length -1)(DATA_BITS -1 downto 0) := to_slvv(VersionData);
  
begin
	
	
  version_reg : entity poc.AXI4Lite_Register
	Generic map(
	 	CONFIG        => CONFIG
	)
	Port map(
		S_AXI_ACLK              => S_AXI_ACLK             ,
		S_AXI_ARESETN           => S_AXI_ARESETN          ,
		S_AXI_m2s               => S_AXI_m2s              ,
		S_AXI_s2m               => S_AXI_s2m              ,
		RegisterFile_ReadPort   => RegisterFile_ReadPort  ,
		RegisterFile_WritePort  => RegisterFile_WritePort
	);
    
end Behavioral;
