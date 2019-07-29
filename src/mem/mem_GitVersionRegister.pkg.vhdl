library STD;
use			STD.TextIO.all;

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;
use     IEEE.std_logic_textio.all;

use     work.utils.all;
use     work.vectors.all;
use     work.axi4lite.all;
use     work.strings.all;


package GitVersionRegister is
  -------Define AXI Register structure-------------
  constant Version_of_VersionReg : std_logic_vector(7 downto 0) := x"00";
  
  constant Address_Width  : natural := 32;
  constant Data_Width     : natural := 32;
  
  constant Reg_Length_Common : natural := 8;
  constant Reg_Length_Top    : natural := 56;
  constant Reg_Length_Module : natural := 16;
  

  type T_Version_Register_Common is record
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
  
  type T_Version_Register_Top is record
    Version_Major          : std_logic_vector(7 downto 0);
    Version_Minor          : std_logic_vector(7 downto 0);
    Version_Release        : std_logic_vector(7 downto 0);
    Version_Flags          : std_logic_vector(7 downto 0);
    
    GitHash                : std_logic_vector(159 downto 0);
    
    GitDate_Day            : std_logic_vector(7 downto 0);
    GitDate_Month          : std_logic_vector(7 downto 0);
    GitDate_Year           : std_logic_vector(15 downto 0);
    
    GitTime_Hour           : std_logic_vector(7 downto 0);
    GitTime_Min            : std_logic_vector(7 downto 0);
    GitTime_Sec            : std_logic_vector(7 downto 0);
    GitTime_Zone           : std_logic_vector(7 downto 0);
    
    BranchName_Tag         : std_logic_vector(511 downto 0);
    
    GitURL                 : std_logic_vector(1023 downto 0);
  end record;
  
  type T_Version_Register_Module is record
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
  
  type T_Version_Register_Module_Vector is array (natural range <>) of T_Version_Register_Module;
  
  function get_num_Version_register(numModules : natural := 0) return natural;
 
  function to_SLVV_32_Common       (data : T_Version_Register_Common)        return T_SLVV_32;
  function to_SLVV_32_Top          (data : T_Version_Register_Top)           return T_SLVV_32;
  function to_SLVV_32_Module       (data : T_Version_Register_Module)        return T_SLVV_32;
  -- function to_AXI4_Register_Description_Vector_Module_Vector(data : T_Version_Register_Module_Vector) return T_Register_Description_Vector;
	function get_Dummy_Descriptor(len : natural) return T_AXI4_Register_Description_Vector;
	
	impure function read_Version_from_mem(FileName : string) return T_SLVV_32;
end package;


package body GitVersionRegister is 
  function get_num_Version_register(numModules : natural := 0) return natural is
  begin
   return Reg_Length_Common + Reg_Length_Top + (Reg_Length_Module * numModules);
  end function;

  function get_Dummy_Descriptor(len : natural) return T_AXI4_Register_Description_Vector is
    variable descriptor : T_AXI4_Register_Description_Vector(0 to len -1);
  begin
    for i in descriptor'range loop
      descriptor(i) := to_AXI4_Register_Description(
        Address => to_unsigned(i *4,Address_Width), 
        Writeable => false);
    end loop;
    return descriptor;
  end function;
  
  function to_SLVV_32_Common(data : T_Version_Register_Common) return T_SLVV_32 is
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

  function to_SLVV_32_Top(data : T_Version_Register_Top) return T_SLVV_32 is
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
    idx := idx +1;
    temp(idx) := data.GitTime_Hour & data.GitTime_Min & data.GitTime_Sec & data.GitTime_Zone;
    idx := idx +1;
    
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
  

  function to_SLVV_32_Module(data : T_Version_Register_Module) return T_SLVV_32 is
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
  

  
  impure function read_Version_from_mem(FileName : string) return T_SLVV_32 is
  	constant MemoryLines : positive := Reg_Length_Common + Reg_Length_Top;
  	variable HW_BUILD_VERSION_COMMON : T_Version_Register_Common;
  	variable HW_BUILD_VERSION_TOP : T_Version_Register_Top;
  	
  	file     FileHandle		: TEXT open READ_MODE is FileName;
  	variable CurrentLine	: LINE;
		variable TempWord			: string(1 to 3);
		variable Good					: boolean;
		
		variable temp_signed : signed(7 downto 0);
		variable temp : T_SLVV_32(0 to MemoryLines -1)     := (others => (others => '0'));
		
		impure function get_string return string is
			variable result : string(1 to 128);
			variable CurrentLine	: LINE;
			variable Good					: boolean;
			variable Len          : natural;
		begin
			readline(FileHandle, CurrentLine);
			Len := CurrentLine'length;
			read(CurrentLine, result(1 to Len), Good);
			if not Good then
				report "Error while reading memory file '" & FileName & "'." severity FAILURE;
				return result(1 to Len);
			end if;
			return result(1 to Len);
		end function;
		
		impure function get_slv_h return std_logic_vector is
			variable result : std_logic_vector(159 downto 0);
			variable CurrentLine	: LINE;
			variable Good					: boolean;
			variable Len          : natural;
		begin
			readline(FileHandle, CurrentLine);
			Len := CurrentLine'length;
			hread(CurrentLine, result(Len * 4 -1 downto 0), Good);
			if not Good then
				report "Error while reading memory file '" & FileName & "'." severity FAILURE;
				return result(Len * 4 -1 downto 0);
			end if;
			return result(Len * 4 -1 downto 0);
		end function;
		
		impure function get_slv_d(length : natural) return std_logic_vector is
			variable result       : string(1 to 128);
			variable CurrentLine	: LINE;
			variable Good					: boolean;
			variable Len          : natural;
		begin
			readline(FileHandle, CurrentLine);
			Len := CurrentLine'length;
			read(CurrentLine, result(1 to Len), Good);
			if not Good then
				report "Error while reading memory file '" & FileName & "'." severity FAILURE;
				return std_logic_vector(to_unsigned(to_natural_dec(result(1 to Len)), length));
			end if;
			return std_logic_vector(to_unsigned(to_natural_dec(result(1 to Len)), length));
		end function;

  begin
--		readline(FileHandle, CurrentLine);
--		read(CurrentLine, TempWord, Good);
		HW_BUILD_VERSION_COMMON.BuildDate_Day            := get_slv_d(8);
		HW_BUILD_VERSION_COMMON.BuildDate_Month          := get_slv_d(8);
		HW_BUILD_VERSION_COMMON.BuildDate_Year           := get_slv_d(16);
                                                               
		HW_BUILD_VERSION_COMMON.NumberModule             := get_slv_d(24);
		HW_BUILD_VERSION_COMMON.VersionOfVersionReg      := get_slv_d(8);
                                                               
		HW_BUILD_VERSION_COMMON.VivadoVersion_Year       := get_slv_d(16);
		HW_BUILD_VERSION_COMMON.VivadoVersion_Release    := get_slv_d(8);
		HW_BUILD_VERSION_COMMON.VivadoVersion_SubRelease := get_slv_d(8);
                             
		HW_BUILD_VERSION_COMMON.ProjektName              := to_slv(to_RawString(resize(get_string, 20, NUL)));


		HW_BUILD_VERSION_TOP.Version_Major               := get_slv_d(8);
		HW_BUILD_VERSION_TOP.Version_Minor               := get_slv_d(8);
		HW_BUILD_VERSION_TOP.Version_Release             := get_slv_d(8);
		HW_BUILD_VERSION_TOP.Version_Flags               := get_slv_d(6) & get_slv_d(1) & get_slv_d(1);
                                            
		HW_BUILD_VERSION_TOP.GitHash                     := get_slv_h;
                                              
		HW_BUILD_VERSION_TOP.GitDate_Day                 := get_slv_d(8);
		HW_BUILD_VERSION_TOP.GitDate_Month               := get_slv_d(8);
		HW_BUILD_VERSION_TOP.GitDate_Year                := get_slv_d(16);
                                            
		HW_BUILD_VERSION_TOP.GitTime_Hour                := get_slv_d(8);
		HW_BUILD_VERSION_TOP.GitTime_Min                 := get_slv_d(8);
		HW_BUILD_VERSION_TOP.GitTime_Sec                 := get_slv_d(8);
		
		readline(FileHandle, CurrentLine);
		read(CurrentLine, TempWord, Good);
		if not Good then
			report "Error while reading memory file '" & FileName & "'." severity FAILURE;
			return temp;
		end if;
		if TempWord(1) = '-' then
			temp_signed := to_signed(-1* to_natural_dec(TempWord(2 to TempWord'high)),8);
		else
			temp_signed := to_signed(to_natural_dec(TempWord(2 to TempWord'high)),8);
		end if;
		HW_BUILD_VERSION_TOP.GitTime_Zone                := std_logic_vector(temp_signed);
                                               
		HW_BUILD_VERSION_TOP.BranchName_Tag              := to_slv(to_RawString(resize(get_string, 64, NUL)));
                                               
		HW_BUILD_VERSION_TOP.GitURL                      := to_slv(to_RawString(resize(get_string, 128, NUL)));


		temp :=	(0 to Reg_Length_Common -1 => to_SLVV_32_Common(HW_BUILD_VERSION_COMMON),
			       Reg_Length_Common to Reg_Length_Common + Reg_Length_Top -1 => to_SLVV_32_Top(HW_BUILD_VERSION_TOP));
  	
  	return temp;
  end function;
end package body;
