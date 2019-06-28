
library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;
use PoC.vectors.all;
use PoC.axi4.all;



package axi4Lite_Version is
  -------Define AXI Register structure-------------
  constant Version_of_VersionReg : std_logic_vector(7 downto 0) := x"00";
  
  constant Address_Width  : natural := 32;
  constant Data_Width  : natural := 32;
  
  constant Reg_Length_Common : natural := 8;
  constant Reg_Length_Top    : natural := 56;
  constant Reg_Length_Module : natural := 16;
  

  type T_AXI4_Version_Register_Common is record
    BuildDate_Day          : std_logic_vector(7 downto 0);
    BuildDate_Month        : std_logic_vector(7 downto 0);
    BuildDate_Year         : std_logic_vector(15 downto 0);

    NumberModule           : std_logic_vector(23 downto 0);
    VersionOfVersionReg    : std_logic_vector(7 downto 0);
    
    VivadoVersion_Year     : std_logic_vector(15 downto 0);
    VivadoVersion_Release  : std_logic_vector(7 downto 0);
    VivadoVersion_SubRelease   : std_logic_vector(7 downto 0);
    
    ProjektName            : std_logic_vector(159 downto 0);
  end record;
  
  type T_AXI4_Version_Register_Top is record
    Version_Major          : std_logic_vector(7 downto 0);
    Version_Minor          : std_logic_vector(7 downto 0);
    Version_Release        : std_logic_vector(7 downto 0);
    Version_Flags          : std_logic_vector(7 downto 0);
    
    GitHash                : std_logic_vector(159 downto 0);
    
    GitDate_Day            : std_logic_vector(7 downto 0);
    GitDate_Month          : std_logic_vector(7 downto 0);
    GitDate_Year           : std_logic_vector(15 downto 0);
    
    BranchName_Tag         : std_logic_vector(511 downto 0);
    
    GitURL                 : std_logic_vector(1023 downto 0);
  end record;
  
  type T_AXI4_Version_Register_Module is record
    ModuleName             : std_logic_vector(159 downto 0);
    
    Version_Major          : std_logic_vector(7 downto 0);
    Version_Minor          : std_logic_vector(7 downto 0);
    Version_Release        : std_logic_vector(7 downto 0);
    Version_Flags          : std_logic_vector(7 downto 0);
    
    GitHash                : std_logic_vector(159 downto 0);
    
    GitDate_Day            : std_logic_vector(7 downto 0);
    GitDate_Month          : std_logic_vector(7 downto 0);
    GitDate_Year           : std_logic_vector(15 downto 0);
    
    Dummy                  : std_logic_vector(127 downto 0);
  end record;
  
  type T_AXI4_Version_Register_Module_Vector is array (natural range <>) of T_AXI4_Version_Register_Module;
  
  function get_num_Version_register(numModules : natural := 0) return natural;
 
  function to_SLVV_32_Common       (data : T_AXI4_Version_Register_Common)        return T_SLVV_32;
  function to_SLVV_32_Top          (data : T_AXI4_Version_Register_Top)           return T_SLVV_32;
  function to_SLVV_32_Module       (data : T_AXI4_Version_Register_Module)        return T_SLVV_32;
  -- function to_AXI4_Register_Description_Vector_Module_Vector(data : T_AXI4_Version_Register_Module_Vector) return T_AXI4_Register_Description_Vector;
	function get_Dummy_Descriptor(len : natural) return T_AXI4_Register_Description_Vector;
end package;


package body axi4Lite_Version is 

  function get_num_Version_register(numModules : natural := 0) return natural is
  begin
   return Reg_Length_Common + Reg_Length_Top + (Reg_Length_Module * numModules);
  end function;

  function get_Dummy_Descriptor(len : natural) return T_AXI4_Register_Description_Vector is
    variable descriptor : T_AXI4_Register_Description_Vector(0 to len -1);
  begin
    for i in descriptor'range loop
      descriptor(i) := to_AXI4_Register_Description(
        Address => to_unsigned(i,Address_Width), 
        Writeable => false);
    end loop;
    return descriptor;
  end function;
  
  
  function to_SLVV_32_Common(data : T_AXI4_Version_Register_Common) return T_SLVV_32 is
    variable temp : T_SLVV_32(0 to 7) := (others => (others => '0'));
    variable name : T_SLVV_32(4 downto 0) := to_slvv_32(data.ProjektName);
  begin
    temp(0) := data.BuildDate_Day & data.BuildDate_Month & data.BuildDate_Year;
    temp(1) := data.NumberModule & data.VersionOfVersionReg;
    temp(2) := data.VivadoVersion_Year & data.VivadoVersion_Release & data.VivadoVersion_SubRelease;
    for i in name'reverse_range loop
      temp(i +3) := name(i);
    end loop;
    
    return temp;
  end function;


  function to_SLVV_32_Top(data : T_AXI4_Version_Register_Top) return T_SLVV_32 is
    variable temp : T_SLVV_32(0 to 55)     := (others => (others => '0'));
    
    variable hash : T_SLVV_32(4 downto 0)  := to_slvv_32(data.GitHash);
    variable name : T_SLVV_32(15 downto 0) := to_slvv_32(data.BranchName_Tag);
    variable url  : T_SLVV_32(31 downto 0) := to_slvv_32(data.GitURL);
    
    variable idx  : natural := 0;
  begin
    temp(0) := data.Version_Major & data.Version_Minor & data.Version_Release & data.Version_Flags;
    idx := idx +1;
    
    for i in hash'reverse_range loop
      temp(i +1) := hash(i);
      idx := idx +1;
    end loop;
    
    temp(idx) := data.GitDate_Day & data.GitDate_Month & data.GitDate_Year;
    idx := idx +2;
    
    for i in name'reverse_range loop
      temp(idx) := name(i);
      idx := idx +1;
    end loop;
    
    for i in url'reverse_range loop
      temp(idx) := url(i);
      idx := idx +1;
    end loop;
    
    return temp;
  end function;
  

  function to_SLVV_32_Module(data : T_AXI4_Version_Register_Module) return T_SLVV_32 is
    variable temp : T_SLVV_32(0 to 15)     := (others => (others => '0'));
    
    variable hash : T_SLVV_32(4 downto 0)  := to_slvv_32(data.GitHash);
    variable name : T_SLVV_32(4 downto 0) := to_slvv_32(data.ModuleName);
    
    variable idx  : natural := 0;
  begin
    for i in name'reverse_range loop
      temp(idx) := name(i);
      idx := idx +1;
    end loop;
    
    temp(idx) := data.Version_Major & data.Version_Minor & data.Version_Release & data.Version_Flags;
    idx := idx +1;
    
    for i in hash'reverse_range loop
      temp(idx) := hash(i);
      idx := idx +1;
    end loop;

    temp(idx) := data.GitDate_Day & data.GitDate_Month & data.GitDate_Year;

    return temp;
  end function;
  
end package body;
