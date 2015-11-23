
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;


entity sortnet_BitonicSort is
	generic (
		INPUTS								: POSITIVE	:= 8;
		KEY_BITS							: POSITIVE	:= 16;
		DATA_BITS							: POSITIVE	:= 16;
		ADD_OUTPUT_REGISTERS	: BOOLEAN		:= TRUE
	);
	port (
		Clock									: in	STD_LOGIC;
		Reset									: in	STD_LOGIC;
		
		DataInputs						: in	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
		DataOutputs						: out	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0)
	);
end entity;


architecture rtl of sortnet_BitonicSort is
	signal DataInputMatrix1		: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputMatrix1	: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	
begin
	DataInputMatrix1		<= DataInputs;
	
	sort : entity PoC.sortnet_BitonicSort_Sort
		generic map (
			INPUTS			=> INPUTS,
			KEY_BITS		=> KEY_BITS,
			DATA_BITS		=> DATA_BITS,
			INVERSE			=> FALSE
		)
		port map (
			Clock				=> Clock,
			Reset				=> Reset,
			
			DataInputs	=> DataInputMatrix1,
			DataOutputs	=> DataOutputMatrix1
		);
	
	genOutReg : if (ADD_OUTPUT_REGISTERS = TRUE) generate
		DataOutputs	<= DataOutputMatrix1 when rising_edge(Clock);
	end generate;
	genNoOutReg : if (ADD_OUTPUT_REGISTERS = FALSE) generate
		DataOutputs	<= DataOutputMatrix1;
	end generate;
end architecture;
