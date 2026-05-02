library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library PoC;
use PoC.utils.all;
use PoC.axi4lite.all;

entity AXI4Lite_Ocram_Wrapper is
		generic (
			ADDR_WIDTH : positive := 10;
			DATA_WIDTH : positive := 64
		);
		port (

				clk      : in  std_logic;
				rst_n    : in  std_logic;
				
				axi_m2s  : in  T_AXI4Lite_Bus_M2S(AWAddr(12 downto 0), ARAddr(12 downto 0), WData(63 downto 0), WStrb(7 downto 0));
				axi_s2m  : out T_AXI4Lite_Bus_S2M(RData(63 downto 0));
				Read_En  : out std_logic;
				Write_En : out std_logic;
				Write_Strobe : out std_logic_vector((DATA_WIDTH/8)-1 downto 0); 
				Address  : out unsigned(ADDR_WIDTH-1 downto 0);
				Data_In  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
				Data_Out : out std_logic_vector(DATA_WIDTH-1 downto 0)
		);
end entity;

architecture rtl of AXI4Lite_Ocram_Wrapper is


begin


    Inst_Adapter: entity PoC.AXI4Lite_Ocram_Adapter
        generic map (
            OCRAM_ADDRESS_BITS    => ADDR_WIDTH,
            OCRAM_DATA_BITS       => DATA_WIDTH,
            PREFFERED_READ_ACCESS => TRUE
        )
        port map (
            ACLK          => clk,
            ARESETN       => rst_n,
						
            AXI4Lite_M2S  => axi_m2s,
            AXI4Lite_S2M  => axi_s2m,
						Read_En       => Read_En,
						Write_Strobe  => Write_Strobe,
            Write_En      => Write_En,
            Address       => Address,
            Data_In       => Data_In, 
            Data_Out      => Data_Out  
        );

end architecture;