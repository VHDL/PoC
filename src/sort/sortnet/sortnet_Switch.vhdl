
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.components.all;


entity sortnet_Switch is
	generic (
		KEY_BITS		: POSITIVE		:= 32;
		DATA_BITS		: NATURAL			:= 8;
		INVERSE			: BOOLEAN			:= FALSE
	);
	port (
		DataIn0		: in	STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
		DataIn1		: in	STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
		DataOut0	: out	STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
		DataOut1	: out	STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0)
	);
end entity;


architecture rtl of sortnet_Switch is
	signal Greater		: STD_LOGIC;
	signal Switch			: STD_LOGIC;
begin
	Greater		<= to_sl(unsigned(DataIn0(KEY_BITS - 1 downto 0)) > unsigned(DataIn1(KEY_BITS - 1 downto 0)));
	Switch		<= Greater xor to_sl(INVERSE);
	
	DataOut0	<= mux(Switch, DataIn0, DataIn1);
	DataOut1	<= mux(Switch, DataIn1, DataIn0);
end architecture;
