
library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.math.all;
use			PoC.utils.all;
use			PoC.vectors.all;
-- simulation only packages
use			PoC.sim_global.all;
use			PoC.sim_types.all;
use			PoC.simulation.all;

library OSVVM;
use			OSVVM.RandomPkg.all;


entity sort_LeastRecentlyUsed_tb is
end entity;


architecture tb of sort_LeastRecentlyUsed_tb is
	constant ELEMENTS					: POSITIVE	:= 8;
	constant KEY_BITS					: POSITIVE	:= 3;	--8;
	constant DATA_BITS				: NATURAL		:= 3;
	
	constant LOOP_COUNT				: POSITIVE	:= 32;
	
	constant CLOCK_PERIOD			: TIME				:= 10 ns;
	signal Clock							: STD_LOGIC		:= '1';
	
	function create_keys return T_SLM is
		variable slm		: T_SLM(ELEMENTS - 1 downto 0, KEY_BITS - 1 downto 0);
		variable row		: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
	begin
		for i in slm'range(1) loop
			row					:= to_slv((slm'high(1) - i), row'length);
			for j in row'range loop
				slm(i, j)	:= row(j);
			end loop;
		end loop;
		return slm;
	end function;

	constant INITIAL_KEYS				: T_SLM(ELEMENTS - 1 DOWNTO 0, KEY_BITS - 1 DOWNTO 0)		:= create_keys;
	
	signal Insert							: STD_LOGIC;
	signal KeyIn							: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
	signal Invalidate					: STD_LOGIC;
	
	signal Valid							: STD_LOGIC;
	signal LRU_Element				: STD_LOGIC_VECTOR(KEY_BITS - 1 downto 0);
	
	signal StopSimulation			: STD_LOGIC		:= '0';
begin

	Clock	<= Clock xnor StopSimulation after CLOCK_PERIOD;

	process
		variable RandomVar	: RandomPType;								-- protected type from RandomPkg
		variable Command		: INTEGER range 0 to 1;--2;
	begin
		RandomVar.InitSeed(RandomVar'instance_name);		-- Generate initial seeds
		
		Insert			<= '0';
		Invalidate	<= '0';
		KeyIn				<= (others => '0');
		wait until falling_edge(Clock);
		
		for i in 0 to LOOP_COUNT - 1 loop
			
			Insert			<= '0';
			Invalidate	<= '0';
			Command			:= RandomVar.RandInt(0, 1);
			case Command is
				when 0 =>	-- NOP
				when 1 =>	-- Insert
					Insert			<= '1';
					KeyIn	<= to_slv(RandomVar.RandInt(0, (2**KEY_BITS - 1)), KEY_BITS);
				-- when 2 =>	-- Invalidate
					-- Invalidate	<= '1';
					-- KeyIn	<= to_slv(RandomVar.RandInt(0, (2**KEY_BITS - 1)), KEY_BITS);
			end case;
			wait until falling_edge(Clock);
		end loop;
		
		for i in 0 to 3 loop
			wait until falling_edge(Clock);
		end loop;
		
		StopSimulation		<= '1';
		wait;
	end process;
	
	sort : entity PoC.sort_LeastRecentlyUsed
		generic map (
			ELEMENTS					=> ELEMENTS,
			KEY_BITS					=> KEY_BITS,
			DATA_BITS					=> DATA_BITS,
			INITIAL_ELEMENTS	=> INITIAL_KEYS,	--(0 to ELEMENTS - 1 => (KEY_BITS - 1 downto 0 => '0')),
			INITIAL_VALIDS		=> (0 to ELEMENTS - 1 => '1')
		)
		port map (
			Clock							=> Clock,
			Reset							=> '0',

			Insert						=> Insert,
			Invalidate				=> Invalidate,
			KeyIn							=> KeyIn,

			Valid							=> Valid,
			LRU_Element				=> LRU_Element,

			DBG_Elements			=> open,
			DBG_Valids				=> open
		);
	
	process
		variable	Check		: BOOLEAN;
	begin
		Check		:= TRUE;
		
		for i in 0 to LOOP_COUNT - 1 loop
			wait until rising_edge(Clock);
			-- TODO: 
		end loop;
		
		simAssertion(Check, "Result is not monotonic.");

		-- This process is finished
		simDeactivateProcess(simProcessID);
		-- Report overall result
		globalSimulationStatus.finalize;
		wait;  -- forever
	end process;
end architecture;
