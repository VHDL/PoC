
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.math.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.simulation.ALL;

library OSVVM;
use			OSVVM.RandomPkg.all;


entity sortnet_BitonicSort_tb is
end entity;


architecture tb of sortnet_BitonicSort_tb is
	constant INPUTS									: POSITIVE	:= 32;
	constant KEY_BITS								: POSITIVE	:= 32;
	constant DATA_BITS							: POSITIVE	:= 32;
	constant PIPELINE_STAGE_AFTER		: NATURAL		:= 2;

	constant LOOP_COUNT							: POSITIVE	:= 1024;
	
	constant STAGES									: POSITIVE	:= triangularNumber(log2ceil(INPUTS));
	constant DELAY									: NATURAL		:= STAGES / PIPELINE_STAGE_AFTER;
	
	subtype T_KEY					is STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
	subtype T_DATA				is STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
	
	type T_KEY_VECTOR			is array(NATURAL range <>) of T_KEY;
	type T_DATA_VECTOR		is array(NATURAL range <>) of T_DATA;

	function to_kv(slm : T_SLM) return T_KEY_VECTOR is
		variable Result	: T_KEY_VECTOR(slm'range(1));
	begin
		for i in slm'high(1) downto slm'low(1) loop
			for j in T_KEY'high downto T_KEY'low loop
				Result(i)(j)	:= slm(i, j);
			end loop;
		end loop;
		return Result;
	end function;

	function to_dv(slm : T_SLM) return T_DATA_VECTOR is
		variable Result	: T_DATA_VECTOR(slm'range(1));
	begin
		for i in slm'high(1) downto slm'low(1) loop
			for j in (T_DATA'high + T_KEY'length) downto (T_DATA'low + T_KEY'length) loop
				Result(i)(j)	:= slm(i, j);
			end loop;
		end loop;
		return Result;
	end function;
	
	function to_slm(kv : T_KEY_VECTOR) return T_SLM is
		variable Result	: T_SLM(kv'range, T_KEY'range);
	begin
		for i in kv'range loop
			for j in T_KEY'range loop
				Result(i, j)	:= kv(i)(j);
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
	
	constant CLOCK_PERIOD			: TIME				:= 10 ns;
	signal Clock							: STD_LOGIC		:= '1';
	
	signal KeyInputVector			: T_KEY_VECTOR(INPUTS - 1 downto 0)			:= (others => (others => '0'));
	signal DataInputVector		: T_DATA_VECTOR(INPUTS - 1 downto 0)		:= (others => (others => '0'));
	
	signal DataInputMatrix		: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputMatrix		: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	
	signal KeyOutputVector		: T_KEY_VECTOR(INPUTS - 1 downto 0);
	signal DataOutputVector		: T_DATA_VECTOR(INPUTS - 1 downto 0);
	
	signal StopSimulation			: STD_LOGIC		:= '0';
begin

	Clock	<= Clock xnor StopSimulation after CLOCK_PERIOD;

	process
		variable RandomVar : RandomPType;								-- protected type from RandomPkg
	begin
		RandomVar.InitSeed(RandomVar'instance_name);		-- Generate initial seeds
		
		wait until rising_edge(Clock);
		
		for i in 0 to LOOP_COUNT - 1 loop
			wait until rising_edge(Clock);
			for j in 0 to INPUTS - 1 loop
				KeyInputVector(j)	<= RandomVar.RandSlv(KEY_BITS);
			end loop;
		end loop;
		
		for i in 0 to DELAY + 7 loop
			wait until rising_edge(Clock);
		end loop;
		
		StopSimulation		<= '1';
		wait;
	end process;
	
	DataInputMatrix		<= to_slm(KeyInputVector);

	sort : entity PoC.sortnet_BitonicSort
		generic map (
			INPUTS								=> INPUTS,
			KEY_BITS							=> KEY_BITS,
			DATA_BITS							=> DATA_BITS,
			PIPELINE_STAGE_AFTER	=> PIPELINE_STAGE_AFTER
		)
		port map (
			Clock				=> Clock,
			Reset				=> '0',
			
			DataInputs	=> DataInputMatrix,
			DataOutputs	=> DataOutputMatrix
		);
	
	KeyOutputVector	<= to_kv(DataOutputMatrix);
	
	process
		variable	Check		: BOOLEAN;
	begin
		report "Delay=" & INTEGER'image(DELAY) severity NOTE;
	
		for i in 0 to DELAY - 1 loop
			wait until rising_edge(Clock);
		end loop;
		
		for i in 0 to LOOP_COUNT - 1 loop
			wait until rising_edge(Clock);
			Check		:= TRUE;
			for j in 0 to INPUTS - 2 loop
				Check	:= Check and (KeyOutputVector(j) <= KeyOutputVector(j + 1));
			end loop;
			tbAssert(Check, "Result is not monotonic.");
		end loop;

		report "Patrick" severity Note;
		
		-- Report overall result
		tbPrintResult;

    wait;  -- forever
	end process;
	
	blkGTKW : block
		signal INPUT_0		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal INPUT_1		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal INPUT_2		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal INPUT_3		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal INPUT_4		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal INPUT_5		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal INPUT_6		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal INPUT_7		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		
		signal OUTPUT_0		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal OUTPUT_1		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal OUTPUT_2		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal OUTPUT_3		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal OUTPUT_4		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal OUTPUT_5		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal OUTPUT_6		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
		signal OUTPUT_7		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
	begin
		INPUT_0		<= KeyInputVector(0);
		INPUT_1		<= KeyInputVector(1);
		INPUT_2		<= KeyInputVector(2);
		INPUT_3		<= KeyInputVector(3);
		INPUT_4		<= KeyInputVector(4);
		INPUT_5		<= KeyInputVector(5);
		INPUT_6		<= KeyInputVector(6);
		INPUT_7		<= KeyInputVector(7);
		
		OUTPUT_0	<= KeyOutputVector(0);
		OUTPUT_1	<= KeyOutputVector(1);
		OUTPUT_2	<= KeyOutputVector(2);
		OUTPUT_3	<= KeyOutputVector(3);
		OUTPUT_4	<= KeyOutputVector(4);
		OUTPUT_5	<= KeyOutputVector(5);
		OUTPUT_6	<= KeyOutputVector(6);
		OUTPUT_7	<= KeyOutputVector(7);
	end block;
end architecture;
