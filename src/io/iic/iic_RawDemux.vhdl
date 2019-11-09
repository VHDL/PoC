library IEEE;
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;

use     work.utils.all;
use     work.iic.all;


entity iic_RawDemultiplexer is
	generic (
		PORTS : positive
	);
	port (
		sel    :	in    unsigned(log2ceilnz(PORTS) - 1 downto 0);
		input  :	inout T_IO_IIC_SERIAL;
			
		output : 	inout T_IO_IIC_SERIAL_VECTOR(PORTS - 1 downto 0)
	);
end entity;

architecture rtl of iic_RawDemultiplexer is
begin
	gen: for i in 0 to PORTS - 1 generate
		output(i).Clock.O <= input.Clock.O when sel = i else '0';
		output(i).Clock.T <= input.Clock.T when sel = i else '0';
		output(i).Data.O  <= input.Data.O when sel = i else '0';
		output(i).Data.T  <= input.Data.T when sel = i else '0';
	end generate;
		
	input.Clock.I <= output(to_index(sel)).Clock.I;
	input.Data.I  <= output(to_index(sel)).Data.I;
end architecture;
