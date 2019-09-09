library IEEE;
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;

use     work.utils.all;
use     work.iic.all;


entity iic_RawMultiplexer is
	generic (
		PORTS : positive := 2
	);
	port (
		sel    :	in    unsigned(log2ceilnz(PORTS) - 1 downto 0);
--		input  : 	inout T_IO_IIC_SERIAL_VECTOR(PORTS - 1 downto 0) := (others => (others => (others => 'Z')));
		Input_m2s : in  T_IO_IIC_SERIAL_OUT_VECTOR(PORTS - 1 downto 0);
		Input_s2m : out T_IO_IIC_SERIAL_IN_VECTOR(PORTS - 1 downto 0);
			
--		output :	inout T_IO_IIC_SERIAL := (others => (others => 'Z'))
		Output_m2s : out T_IO_IIC_SERIAL_OUT;
		Output_s2m : in  T_IO_IIC_SERIAL_IN
	);
end entity;

architecture rtl of iic_RawMultiplexer is
begin
	gen: for i in 0 to PORTS - 1 generate
		Input_s2m(i).Clock <= Output_s2m.Clock when sel = i else '0';
		Input_s2m(i).Data  <= Output_s2m.Data when sel = i else '0';
	end generate;
	
	Output_m2s.Clock_O <= Input_m2s(to_index(sel)).Clock_O;
	Output_m2s.Clock_T <= Input_m2s(to_index(sel)).Clock_T;
	Output_m2s.Data_O  <= Input_m2s(to_index(sel)).Data_O;
	Output_m2s.Data_T  <= Input_m2s(to_index(sel)).Data_T;
end architecture;
