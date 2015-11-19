
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;


entity sortnet_BitonicSort is
	generic (
		INPUTS			: POSITIVE	:= 8;
		KEY_BITS		: POSITIVE	:= 32;
		DATA_BITS		: POSITIVE	:= 8;
		INVERSE			: BOOLEAN		:= FALSE
	);
	port (
		Clock				: in	STD_LOGIC;
		Reset				: in	STD_LOGIC;
		
		DataInputs	: in	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
		DataOutputs	: out	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0)
	);
end entity;


library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.components.all;


entity sortnet_BitonicMerge is
	generic (
		INPUTS			: POSITIVE	:= 8;
		KEY_BITS		: POSITIVE	:= 32;
		DATA_BITS		: POSITIVE	:= 8;
		INVERSE			: BOOLEAN		:= FALSE
	);
	port (
		Clock				: in	STD_LOGIC;
		Reset				: in	STD_LOGIC;
		
		DataInputs	: in	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
		DataOutputs	: out	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0)
	);
end entity;


architecture rtl of sortnet_BitonicSort is
	constant HALF_INPUTS			: NATURAL		:= INPUTS / 2;

	signal DataInputMatrix1		: T_SLM(HALF_INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataInputMatrix2		: T_SLM(HALF_INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputMatrix1	: T_SLM(HALF_INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputMatrix2	: T_SLM(HALF_INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	
	signal DataInputMatrix3		: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputMatrix3	: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	
begin
	genMergers : if (INPUTS > 1) generate
		DataInputMatrix1	<= slm_slice_rows(DataInputs, HALF_INPUTS - 1, 0);
		DataInputMatrix2	<= slm_slice_rows(DataInputs, INPUTS - 1, HALF_INPUTS);
		
		sort1 : entity PoC.sortnet_BitonicSort
			generic map (
				INPUTS			=> HALF_INPUTS,
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
		sort2 : entity PoC.sortnet_BitonicSort
			generic map (
				INPUTS			=> INPUTS - HALF_INPUTS,
				KEY_BITS		=> KEY_BITS,
				DATA_BITS		=> DATA_BITS,
				INVERSE			=> TRUE
			)
			port map (
				Clock				=> Clock,
				Reset				=> Reset,
				
				DataInputs	=> DataInputMatrix2,
				DataOutputs	=> DataOutputMatrix2
			);
		
		DataInputMatrix3	<= slm_merge_rows(DataInputMatrix1, DataInputMatrix2);
		
		merge : entity PoC.sortnet_BitonicMerge
			generic map (
				INPUTS			=> INPUTS,
				KEY_BITS		=> KEY_BITS,
				DATA_BITS		=> DATA_BITS,
				INVERSE			=> INVERSE
			)
			port map (
				Clock				=> Clock,
				Reset				=> Reset,
				
				DataInputs	=> DataInputMatrix3,
				DataOutputs	=> DataOutputMatrix3
			);
		
		DataOutputs		<= DataOutputMatrix3;
	end generate;
	genPassThrough : if (INPUTS = 1) generate
		DataOutputs		<= DataInputs;
	end generate;
end architecture;


architecture rtl of sortnet_BitonicMerge is
	constant HALF_INPUTS	: NATURAL		:= INPUTS / 2;

	subtype T_DATA				is STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
	type T_DATA_VECTOR		is array(NATURAL range <>) of T_DATA;

	function to_dv(slm : T_SLM) return T_DATA_VECTOR is
		variable Result	: T_DATA_VECTOR(slm'range(1));
	begin
		for i in slm'high(1) downto slm'low(1) loop
			for j in slm'high(2) downto slm'low(2) loop
				Result(i)(j)	:= slm(i, j);
			end loop;
		end loop;
		return Result;
	end function;
	
	function to_slm(dv : T_DATA_VECTOR) return T_SLM is
		variable Result	: T_SLM(dv'range, T_DATA'range);
	begin
		for i in dv'range loop
			for j in T_DATA'range loop
				Result(i, j)	:= dv(i)(j);
			end loop;
		end loop;
		return Result;
	end function;
	
	signal DataInputVector		: T_DATA_VECTOR(INPUTS - 1 downto 0);
	signal IntermediateVector	: T_DATA_VECTOR(INPUTS - 1 downto 0);
	
	signal DataInputMatrix1		: T_SLM(HALF_INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataInputMatrix2		: T_SLM(HALF_INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputMatrix1	: T_SLM(HALF_INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputMatrix2	: T_SLM(HALF_INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputVector		: T_DATA_VECTOR(INPUTS - 1 downto 0);
	
begin
	genMergers : if (INPUTS > 1) generate
		DataInputVector		<= to_dv(DataInputs);
	
		genSwitches : for i in 0 to HALF_INPUTS - 1 generate
			signal Smaller		: STD_LOGIC;
			signal Switch			: STD_LOGIC;
		begin
			Smaller <= to_sl(DataInputVector(i)(KEY_BITS - 1 downto 0) < DataInputVector(i + HALF_INPUTS)(KEY_BITS - 1 downto 0));
			Switch	<= Smaller xnor to_sl(INVERSE);
			IntermediateVector(i)								<= mux(Switch, DataInputVector(i),							DataInputVector(i + HALF_INPUTS));
			IntermediateVector(i + HALF_INPUTS)	<= mux(Switch, DataInputVector(i + HALF_INPUTS),	DataInputVector(i));
		end generate;
		
		DataInputMatrix1	<= to_slm(IntermediateVector(HALF_INPUTS - 1 downto 0));
		DataInputMatrix2	<= to_slm(IntermediateVector(INPUTS - 1 downto HALF_INPUTS));
		
		merge1 : entity PoC.sortnet_BitonicMerge
			generic map (
				INPUTS			=> HALF_INPUTS,
				KEY_BITS		=> KEY_BITS,
				DATA_BITS		=> DATA_BITS,
				INVERSE			=> INVERSE
			)
			port map (
				Clock				=> Clock,
				Reset				=> Reset,
				
				DataInputs	=> DataInputMatrix1,
				DataOutputs	=> DataOutputMatrix1
			);
		merge2 : entity PoC.sortnet_BitonicMerge
			generic map (
				INPUTS			=> INPUTS - HALF_INPUTS,
				KEY_BITS		=> KEY_BITS,
				DATA_BITS		=> DATA_BITS,
				INVERSE			=> INVERSE
			)
			port map (
				Clock				=> Clock,
				Reset				=> Reset,
				
				DataInputs	=> DataInputMatrix2,
				DataOutputs	=> DataOutputMatrix2
			);
		
		DataOutputs		<= slm_merge_rows(DataOutputMatrix1, DataOutputMatrix2);
	end generate;
	genPassThrough : if (INPUTS = 1) generate
		DataOutputs	<= DataInputs;
	end generate;
end architecture;
