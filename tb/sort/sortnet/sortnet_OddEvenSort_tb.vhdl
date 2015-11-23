
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;

-- library OSVVM;
-- use			OSVVM.RandomPkg.all;


entity sortnet_OddEvenSort_tb is
end entity;


architecture tb of sortnet_OddEvenSort_tb is
	constant INPUTS				: POSITIVE	:= 8;
	constant KEY_BITS			: POSITIVE	:= 8;
	constant DATA_BITS		: POSITIVE	:= 8;

	subtype T_KEY					is STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
	subtype T_DATA				is STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
	
	type T_KEY_VECTOR			is array(NATURAL range <>) of T_DATA;
	type T_DATA_VECTOR		is array(NATURAL range <>) of T_DATA;

	function to_kv(slm : T_SLM) return T_KEY_VECTOR is
		variable Result	: T_KEY_VECTOR(slm'range(1));
	begin
		for i in slm'high(1) downto slm'low(1) loop
			for j in slm'high(2) downto slm'low(2) loop
				Result(i)(j)	:= slm(i, j);
			end loop;
		end loop;
		return Result;
	end function;

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
	
	signal KeyInputVector			: T_KEY_VECTOR(INPUTS - 1 downto 0)		:= (others => (others => '0'));
	signal DataInputVector		: T_DATA_VECTOR(INPUTS - 1 downto 0)	:= (others => (others => '0'));
	
	signal DataInputMatrix		: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	signal DataOutputMatrix		: T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
	
	signal KeyOutputVector		: T_KEY_VECTOR(INPUTS - 1 downto 0);
	signal DataOutputVector		: T_DATA_VECTOR(INPUTS - 1 downto 0);
	
	signal StopSimulation			: STD_LOGIC		:= '0';
begin

	Clock	<= Clock xnor StopSimulation after CLOCK_PERIOD;

	process
		-- variable RandomVar : RandomPType;								-- protected type from RandomPkg
	begin
		-- RandomVar.InitSeed(RandomVar'instance_name);		-- Generate initial seeds
		
		wait until rising_edge(Clock);
		
		for i in 0 to 63 loop
			wait until rising_edge(Clock);
		
			for j in 0 to INPUTS - 1 loop
				-- KeyInputVector(j)	<= to_slv(RandomVar.RandInt(0, 255), KEY_BITS);
				KeyInputVector(j)	<= std_logic_vector(unsigned(KeyInputVector(j)) + i + j);
			end loop;
		end loop;
		
		for i in 0 to 7 loop
			wait until rising_edge(Clock);
		end loop;
		
		StopSimulation		<= '1';
		wait;
	end process;
	
	DataInputMatrix		<= to_slm(KeyInputVector);

	sort : entity PoC.sortnet_OddEvenSort
		generic map (
			INPUTS								=> INPUTS,
			KEY_BITS							=> KEY_BITS,
			DATA_BITS							=> DATA_BITS,
			PIPELINE_STAGE_AFTER	=> 2,
			ADD_OUTPUT_REGISTERS	=> TRUE
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
		for i in 0 to 5 loop
			wait until rising_edge(Clock);
		end loop;
		
		for i in 0 to 63 loop
			Check		:= TRUE;
			for j in 0 to INPUTS - 2 loop
				Check	:= Check and (KeyOutputVector(j) <= KeyOutputVector(j + 1));
			end loop;
			assert Check report "ERROR: " severity ERROR;
		end loop;
		
		wait;
	end process;
end architecture;
