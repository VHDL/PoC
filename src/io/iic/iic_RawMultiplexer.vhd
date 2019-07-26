library IEEE;
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;

use     work.utils.all;
use     work.io.all;


entity iic_RawMultiplexer is
	generic (
		PORTS : positive
	);
	port (
		sel    :	in  unsigned(log2ceilnz(PORTS) - 1 downto 0);
		input  :	in T_IO_TRISTATE;
			
		output : 	in T_IO_TRISTATE_VECTOR(PORTS - 1 downto 0)
	);
end entity;

architecture rtl of iic_RawMultiplexer is
begin
	gen: for i in 0 to PORTS - 1 generate
		output(i).O <= input.O when sel = i else '0';
		output(i).T <= input.T when sel = i else '0';
	end generate;
		
	input.I <= output(to_index(sel)).I;
end entity;
