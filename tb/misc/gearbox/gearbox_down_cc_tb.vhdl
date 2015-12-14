
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
	constant INPUT_BITS						: POSITIVE		:= 20;
	constant OUTPUT_BITS					: POSITIVE		:= 8;
	constant BITS_PER_CHUNK				: POSITIVE		:= 4;
	constant OUTPUT_ORDER					: T_BIT_ORDER	:= MSB_FIRST;
	constant ADD_INPUT_REGISTERS	: BOOLEAN			:= TRUE;
	constant ADD_OUTPUT_REGISTERS	: BOOLEAN			:= FALSE;
	
	constant INPUT_CHUNKS					: POSITIVE		:= INPUT_BITS / BITS_PER_CHUNK;
	
	constant LOOP_COUNT						: POSITIVE		:= 16;
	constant DELAY								: POSITIVE		:= 5;
	
	constant CLOCK_PERIOD					: TIME				:= 10 ns;
	signal Clock									: STD_LOGIC		:= '1';

	signal SyncIn									: STD_LOGIC;
	signal DataIn									: STD_LOGIC_VECTOR(INPUT_BITS - 1 downto 0);
	signal ValidIn								: STD_LOGIC;
	signal Busy										: STD_LOGIC;
	signal DataOut								: STD_LOGIC_VECTOR(OUTPUT_BITS - 1 downto 0);
	signal ValidOut								: STD_LOGIC;
	
	signal StopSimulation					: STD_LOGIC		:= '0';
begin

	Clock		<= Clock xnor StopSimulation after CLOCK_PERIOD;

	process
		variable RandomVar	: RandomPType;							-- protected type from RandomPkg
		variable Temp				: T_SLVV_4(INPUT_CHUNKS - 1 downto 0);
	begin
		RandomVar.InitSeed(RandomVar'instance_name);		-- Generate initial seeds

		SyncIn		<= '0';
		DataIn		<= x"ABCDE";	--(others => 'U');
		ValidIn		<= '0';
		wait until falling_edge(Clock);
		
		for i in 0 to LOOP_COUNT - 1 loop
			SyncIn		<= to_sl(i = 0);
			if (Busy = '0') then
				for j in 0 to INPUT_CHUNKS - 1 loop
					Temp(j)	:= to_slv(RandomVar.RandInt(0, 2**BITS_PER_CHUNK - 1), BITS_PER_CHUNK);
				end loop;
				DataIn		<= to_slv(Temp);
				ValidIn		<= '1';
			end if;
			wait until falling_edge(Clock);
		end loop;
		
		SyncIn		<= '0';
		
		for i in 0 to LOOP_COUNT - 1 loop
			SyncIn		<= to_sl(i = 0);
			if (Busy = '0') then
				if (i mod 2 = 0) then
					for j in 0 to INPUT_CHUNKS - 1 loop
						Temp(j)	:= to_slv(RandomVar.RandInt(0, 2**BITS_PER_CHUNK - 1), BITS_PER_CHUNK);
					end loop;
					DataIn		<= to_slv(Temp);
					ValidIn		<= '1';
				else
					ValidIn		<= '0';
				end if;
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
			In_Busy			=> Busy,
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
