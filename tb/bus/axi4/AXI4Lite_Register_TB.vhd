
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library PoC;
use PoC.utils.all;
use PoC.axi4.all;
use PoC.vectors.all;

entity AXI4Lite_Register_TB is
--  Port ( );
end AXI4Lite_Register_TB;

architecture tb of AXI4Lite_Register_TB is
  constant ADDRESS_BITS  : natural         := 32;
  constant DATA_BITS     : natural         := 32;
  
	signal System_Clock_100 : std_logic                       := '0';
  signal System_Reset_100 : std_logic                       := '1';
  
  signal AXI4Lite_S2M     : T_AXI4Lite_Bus_S2M(RData(DATA_BITS -1 downto 0))  := Initialize_AXI4Lite_Bus_S2M(ADDRESS_BITS, DATA_BITS);
  signal AXI4Lite_M2S     : T_AXI4Lite_Bus_M2S(
      AWAddr(Address_Bits -1 downto 0), WData(DATA_BITS -1 downto 0), 
      WStrb((Data_Bits /8) -1 downto 0), ARAddr(Address_Bits -1 downto 0))  := Initialize_AXI4Lite_Bus_M2S(ADDRESS_BITS, DATA_BITS, 'Z');    
    
	signal Reconfig : std_logic := '0';
	
	signal RegisterFile_ReadPort   : T_SLVV(0 to 3)(DATA_BITS -1 downto 0) := (others => (others => '0'));
	signal RegisterFile_WritePort  : T_SLVV(0 to 3)(DATA_BITS -1 downto 0) := (others => (others => '0'));
	
begin
	System_Clock_100  <= not System_Clock_100 after 2.5 ns;
	System_Reset_100  <= '0' after 100 ns;
	
	process
  begin
    wait for 120 ns;
    wait until rising_edge(System_Clock_100);
    Reconfig  <= '1';
    wait until rising_edge(System_Clock_100);
    Reconfig  <= '0';
    wait;
  end process;

	control : entity PoC.AXI4Lite_Configurator
	Generic map(
		MAX_CONFIG  => 4,
		ADDRESS_BITS  => ADDRESS_BITS,
		DATA_BITS     => DATA_BITS,
	--      CONFIG        : T_AXI4_Register_Set_VECTOR  := (0 => to_AXI4_Register_Set((0 => Initialize_AXI4_register(32, 32, '0'))))
		CONFIG        => (
			0 => to_AXI4_Register_Set((
					0 => to_AXI4_Register(Address => to_unsigned(2,ADDRESS_BITS), Data => x"ABCDEF01", Mask => x"FFFF0000"),
					1 => to_AXI4_Register(Address => to_unsigned(1,ADDRESS_BITS), Data => x"BCDEF012", Mask => x"FFFFFFFF"),
					2 => to_AXI4_Register(Address => to_unsigned(0,ADDRESS_BITS), Data => x"CDEF0123", Mask => x"F0000000"),
					3 => to_AXI4_Register(Address => to_unsigned(5,ADDRESS_BITS), Data => x"F0123456", Mask => x"00FFFF00")
				), 4),
			1 => to_AXI4_Register_Set((
					0 => to_AXI4_Register(Address => to_unsigned(2,ADDRESS_BITS), Data => x"12345678", Mask => x"00FFFF00"),
					1 => to_AXI4_Register(Address => to_unsigned(1,ADDRESS_BITS), Data => x"3456789A", Mask => x"FFF000F0"),
					2 => to_AXI4_Register(Address => to_unsigned(0,ADDRESS_BITS), Data => x"56789ABC", Mask => x"F000000F")
				), 4)
		)
	)
	Port map( 
		Clock         => System_Clock_100,
		Reset         => System_Reset_100,
		
		Reconfig      => Reconfig,
		ReconfigDone  => open,
		Error         => open,
		ConfigSelect  => (others => '0'),
		
		AXI4Lite_M2S  => AXI4Lite_M2S,
		AXI4Lite_S2M  => AXI4Lite_S2M
	);
	
	Reg : entity PoC.AXI4Lite_Register 
	Generic map(
		ADDRESS_BITS  => ADDRESS_BITS,
		DATA_BITS     => DATA_BITS,
	 	CONFIG        => (
				0 => to_AXI4_Register_Description(Address => to_unsigned(0,ADDRESS_BITS)),--, Writeable => true, Init_Value => x"ABCDEF01", Auto_Clear_Mask => x"FFFF0000"),
				1 => to_AXI4_Register_Description(Address => to_unsigned(1,ADDRESS_BITS)),--, Writeable => true, Init_Value => x"ABCDEF01", Auto_Clear_Mask => x"FFFF0000"),
				2 => to_AXI4_Register_Description(Address => to_unsigned(2,ADDRESS_BITS)),--, Writeable => true, Init_Value => x"ABCDEF01", Auto_Clear_Mask => x"FFFF0000"),
				3 => to_AXI4_Register_Description(Address => to_unsigned(3,ADDRESS_BITS)) --, Writeable => true, Init_Value => x"ABCDEF01", Auto_Clear_Mask => x"FFFF0000")
			)
	)
	Port map (
		S_AXI_ACLK              => System_Clock_100      ,
		S_AXI_ARESETN           => not System_Reset_100  ,
		S_AXI_m2s               => AXI4Lite_M2S          ,
		S_AXI_s2m               => AXI4Lite_S2M          ,
		RegisterFile_ReadPort   => RegisterFile_ReadPort ,
		RegisterFile_WritePort  => RegisterFile_WritePort
	);


end tb;
