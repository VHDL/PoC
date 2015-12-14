
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


entity gearbox_down_cc_tb is
end entity;


architecture tb of gearbox_down_cc_tb is
	constant INPUT_BITS						: POSITIVE		:= 36;
	constant OUTPUT_BITS					: POSITIVE		:= 8;
	constant OUTPUT_ORDER					: T_BIT_ORDER	:= MSB_FIRST;
	constant ADD_INPUT_REGISTERS	: BOOLEAN			:= TRUE;
	constant ADD_OUTPUT_REGISTERS	: BOOLEAN			:= FALSE;
	
	constant BITS_PER_CHUNK				: POSITIVE		:= greatestCommonDivisor(INPUT_BITS, OUTPUT_BITS);
	constant INPUT_CHUNKS					: POSITIVE		:= INPUT_BITS / BITS_PER_CHUNK;
	constant OUTPUT_CHUNKS				: POSITIVE		:= OUTPUT_BITS / BITS_PER_CHUNK;
	
	subtype T_CHUNK			is STD_LOGIC_VECTOR(BITS_PER_CHUNK - 1 downto 0);
	type T_CHUNK_VECTOR	is array(NATURAL range <>) of T_CHUNK;
	
	function to_slv(slvv : T_CHUNK_VECTOR) return STD_LOGIC_VECTOR is
		variable slv			: STD_LOGIC_VECTOR((slvv'length * BITS_PER_CHUNK) - 1 downto 0);
	begin
		for i in slvv'range loop
			slv(((i + 1) * BITS_PER_CHUNK) - 1 downto (i * BITS_PER_CHUNK))		:= slvv(i);
		end loop;
		return slv;
	end function;
	
	constant LOOP_COUNT						: POSITIVE		:= 16;
	constant DELAY								: POSITIVE		:= 5;
	
	constant CLOCK_PERIOD					: TIME				:= 10 ns;
	signal Clock									: STD_LOGIC		:= '1';

	signal SyncIn									: STD_LOGIC;
	signal DataIn									: STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0);
	signal ValidIn								: STD_LOGIC;
	signal Nxt										: STD_LOGIC;
	signal DataOut								: STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);
	signal ValidOut								: STD_LOGIC;
	
	signal StopSimulation					: STD_LOGIC		:= '0';
begin

	Clock		<= Clock xnor StopSimulation after CLOCK_PERIOD;

	process
		variable RandomVar	: RandomPType;							-- protected type from RandomPkg
	
		impure function genChunkedRandomValue return STD_LOGIC_VECTOR is
			variable Temp			: T_CHUNK_VECTOR(INPUT_CHUNKS - 1 downto 0);
		begin
			for j in 0 to INPUT_CHUNKS - 1 loop
				Temp(j)	:= to_slv(RandomVar.RandInt(0, 2**BITS_PER_CHUNK - 1), BITS_PER_CHUNK);
			end loop;
			return to_slv(Temp);
		end function;
	begin
		RandomVar.InitSeed(RandomVar'instance_name);		-- Generate initial seeds

		SyncIn		<= '0';
		DataIn		<= x"0A1B2CDEF";
		ValidIn		<= '0';
		wait until falling_edge(Clock);
		
		SyncIn		<= '1';
		ValidIn		<= '1';
		DataIn		<= genChunkedRandomValue;
		wait until falling_edge(Clock);
		
		SyncIn		<= '0';
		for i in 0 to LOOP_COUNT - 1 loop
			if (Nxt = '1') then
				DataIn		<= genChunkedRandomValue;
				ValidIn		<= '1';
			end if;
			wait until falling_edge(Clock);
		end loop;
		
		SyncIn		<= '1';
		ValidIn		<= '1';
		DataIn		<= genChunkedRandomValue;
		wait until falling_edge(Clock);
		
		SyncIn		<= '0';
		for i in 0 to LOOP_COUNT - 1 loop
			if (Nxt = '1') then
				if (i mod 2 = 1) then
					DataIn		<= genChunkedRandomValue;
					ValidIn		<= '1';
				else
					ValidIn		<= '0';
				end if;
			elsif (ValidIn = '0') then
				ValidIn			<= '1';
			end if;
			wait until falling_edge(Clock);
		end loop;
		
		DataIn		<= (others => '0');
		ValidIn		<= '0';
		
		for i in 0 to DELAY - 1 loop
			wait until falling_edge(Clock);
		end loop;
		
		StopSimulation		<= '1';
		wait;
	end process;
	
	gear : entity PoC.gearbox_down_cc
		generic map (
			INPUT_BITS						=> INPUT_BITS,
			OUTPUT_BITS						=> OUTPUT_BITS,
			-- OUTPUT_ORDER					=> OUTPUT_ORDER,
			ADD_INPUT_REGISTERS		=> ADD_INPUT_REGISTERS,
			ADD_OUTPUT_REGISTERS	=> ADD_OUTPUT_REGISTERS
		)
		port map (
			Clock				=> Clock,
			
			In_Sync			=> SyncIn,
			In_Data			=> DataIn,
			In_Valid		=> ValidIn,
			In_Next			=> Nxt,
			Out_Data		=> DataOut,
			Out_Valid		=> ValidOut
		);
	
	process
		variable	Check		: BOOLEAN;
	begin
		Check		:= TRUE;
		
		for i in 0 to LOOP_COUNT - 20 loop
			wait until rising_edge(Clock);
		end loop;
		
		tbAssert(Check, "TODO: ");

		-- Report overall result
		tbPrintResult;

    wait;  -- forever
	end process;
end architecture;
