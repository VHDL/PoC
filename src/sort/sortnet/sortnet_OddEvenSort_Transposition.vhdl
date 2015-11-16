
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;


entity sortnet_OddEven_Transposition is
	generic (
		INPUTS								: POSITIVE	:= 64;
		KEY_BITS							: POSITIVE	:= 32;
		DATA_BITS							: NATURAL		:= 1;
		PIPELINE_STAGE_AFTER	: NATURAL		:= 2;
		ADD_OUTPUT_REGISTERS	: BOOLEAN		:= TRUE
	);
	port (
		Clock				: in	STD_LOGIC;
		Reset				: in	STD_LOGIC;
		
		DataInputs	: in	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0);
		DataOutputs	: out	T_SLM(INPUTS - 1 downto 0, DATA_BITS - 1 downto 0)
	);
end entity;


architecture rtl of sortnet_OddEven_Transposition is
	constant C_VERBOSE	: BOOLEAN	:= FALSE;

	constant STAGES			: POSITIVE		:= INPUTS;

	subtype T_DATA			is STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
	type T_DATA_VECTOR	is array(NATURAL range <>) of T_DATA;
	type T_DATA_MATRIX	is array(NATURAL range <>, NATURAL range <>) of T_DATA;

	function to_dv(slm : T_SLM) return T_DATA_VECTOR is
		variable Result	: T_DATA_VECTOR(slm'range(1));
	begin
		for i in slm'range(1) loop
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
	
	signal DataInputVector	: T_DATA_VECTOR(INPUTS - 1 downto 0);
	signal DataInputMatrix	: T_DATA_MATRIX(STAGES - 1 downto 0, INPUTS - 1 downto 0);
	signal DataOutputMatrix	: T_DATA_MATRIX(STAGES - 1 downto 0, INPUTS - 1 downto 0);
	signal DataOutputVector	: T_DATA_VECTOR(INPUTS - 1 downto 0);
	
begin
	DataInputVector	<= to_dv(DataInputs);

	genInputs : for i in 0 to INPUTS - 1 generate
		DataInputMatrix(0, i)	<= DataInputVector(i);
	end generate;
	
	genConStage : for stage in 0 to STAGES - 2 generate
		constant INSERT_REGISTER : BOOLEAN	:= ((PIPELINE_STAGE_AFTER > 0) and (stage mod PIPELINE_STAGE_AFTER = 0));
	begin
		assert (not C_VERBOSE) report "stage: " & INTEGER'image(stage) & "  ins_reg: " & BOOLEAN'image(INSERT_REGISTER) severity NOTE;
		
		genCon : for i in 0 to INPUTS - 1 generate
			genPipeStage : if (INSERT_REGISTER = TRUE) generate
				DataInputMatrix(stage + 1, i)	<= DataOutputMatrix(stage, i)	when rising_edge(Clock);
			end generate;
			genNoPipeStage : if (INSERT_REGISTER = FALSE) generate
				DataInputMatrix(stage + 1, i)	<= DataOutputMatrix(stage, i);
			end generate;
		end generate;
	end generate;
	
	genSwitchStage : for stage in 0 to STAGES - 1 generate
	begin
		assert (not C_VERBOSE) report "stage: " & INTEGER'image(stage) severity NOTE;
		
		genEven : if (stage mod 2 = 0) generate
			genEvenSwitch : for i in 0 to (INPUTS / 2) - 1 generate
				sw : entity PoC.sortnet_Switch
					generic map (
						KEY_BITS		=> KEY_BITS,
						DATA_BITS		=> DATA_BITS
					)
					port map (
						DataIn0		=> DataInputMatrix(stage, 2 * i),
						DataIn1		=> DataInputMatrix(stage, 2 * i + 1),
						DataOut0	=> DataOutputMatrix(stage, 2 * i),
						DataOut1	=> DataOutputMatrix(stage, 2 * i + 1)
					);
			end generate;
		end generate;
		genOdd : if (stage mod 2 = 1) generate
			DataOutputMatrix(stage, 0)					<= DataInputMatrix(stage, 0);
			DataOutputMatrix(stage, INPUTS - 1)	<= DataInputMatrix(stage, INPUTS - 1);
			
			genOddSwitch : for i in 0 to ((INPUTS - 1) / 2) - 1 generate
				sw : entity PoC.sortnet_Switch
					generic map (
						KEY_BITS		=> KEY_BITS,
						DATA_BITS		=> DATA_BITS
					)
					port map (
						DataIn0		=> DataInputMatrix(stage, 2 * i + 1),
						DataIn1		=> DataInputMatrix(stage, 2 * i + 2),
						DataOut0	=> DataOutputMatrix(stage, 2 * i + 1),
						DataOut1	=> DataOutputMatrix(stage, 2 * i + 2)
					);
			end generate;
		end generate;
	end generate;

	genOutputs : for i in 0 to INPUTS - 1 generate
		DataOutputVector(i)		<= DataOutputMatrix(STAGES - 1, i);
	end generate;

	genOutReg : if (ADD_OUTPUT_REGISTERS = TRUE) generate
		DataOutputs	<= to_slm(DataOutputVector)	when rising_edge(Clock);
	end generate;
	genNoOutReg : if (ADD_OUTPUT_REGISTERS = FALSE) generate
		DataOutputs	<= to_slm(DataOutputVector);
	end generate;
end architecture;
