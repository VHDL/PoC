
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.math.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;
-- simulation only packages
use			PoC.sim_global.all;
use			PoC.sim_types.all;
use			PoC.simulation.all;

-- library OSVVM;
-- use			OSVVM.RandomPkg.all;


entity sort_LeastFrequentlyUsed_tb is
end entity;


architecture tb of sort_LeastFrequentlyUsed_tb is
	constant CLOCK_FREQ				: FREQ				:= 100 MHz;
	
	signal Clock							: STD_LOGIC;
	
begin
	-- initialize global simulation status
	simInitialize;
	simGenerateClock(Clock, CLOCK_FREQ);

	procStimuli : process
		constant simProcessID	: T_SIM_PROCESS_ID		:= simRegisterProcess("Stimuli");
		-- variable RandomVar		: RandomPType;								-- protected type from RandomPkg
	begin
		-- RandomVar.InitSeed(RandomVar'instance_name);		-- Generate initial seeds
		
		wait until rising_edge(Clock);
		
		-- This process is finished
		simDeactivateProcess(simProcessID);
		wait;		-- forever
	end process;
	
	DataInputMatrix		<= to_slm(KeyInputVector);

	lru : entity PoC.sort_LeastFrequentlyUsed is
		generic (
			ELEMENTS			=> 16
			KEY_BITS			=> 4
			DATA_BITS			=> 8
			COUNTER_BITS	: POSITIVE		:= 8
		);
		port (
			Clock					: in	STD_LOGIC;
			Reset					: in	STD_LOGIC;
			
			Access				: in	STD_LOGIC;
			Key						: in	STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
			
			LFU_Valid			: out	STD_LOGIC;
			LFU_Key				: out	STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0)
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
			simAssertion(Check, "Result is not monotonic.");
		end loop;

		-- This process is finished
		simDeactivateProcess(simProcessID);
		-- Report overall result
		globalSimulationStatus.finalize;
		wait;  -- forever
	end process;
end architecture;
