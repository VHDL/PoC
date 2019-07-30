library IEEE;
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;

use     work.utils.all;
use     work.iic.all;


entity iic_RawMultiplexer is
	generic (
		PORTS : positive
	);
	port (
		sel    :	in    unsigned(log2ceilnz(PORTS) - 1 downto 0);
		input  : 	inout T_IO_IIC_SERIAL_VECTOR(PORTS - 1 downto 0);
			
		output :	inout T_IO_IIC_SERIAL
	);
end entity;

architecture rtl of iic_RawMultiplexer is
begin
	gen: for i in 0 to PORTS - 1 generate
		input(i).Clock.I <= output.Clock.I when sel = i else '0';
		input(i).Data.I  <= output.Data.I when sel = i else '0';
	end generate;
	
	output.Clock.O <= input(to_index(sel)).Clock.O;
	output.Clock.T <= input(to_index(sel)).Clock.T;
	output.Data.O  <= input(to_index(sel)).Data.O;
	output.Data.T  <= input(to_index(sel)).Data.T;
end architecture;
