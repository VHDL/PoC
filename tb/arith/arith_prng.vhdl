LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
--USE			PoC.simulation.ALL;


ENTITY test_arith_prng IS

END;


ARCHITECTURE test OF test_arith_prng IS
	CONSTANT CLOCK_100MHZ_PERIOD			: TIME															:= 10.0 ns;

	CONSTANT COMPARE_LIST							: T_SLVV_8(0 TO 255)								:= (OTHERS => x"00");

	SIGNAL Clock											: STD_LOGIC													:= '1';
	SIGNAL Reset											: STD_LOGIC													:= '0';
	SIGNAL Test_got										: STD_LOGIC													:= '0';
	SIGNAL PRNG_Value									: T_SLV_8;
	
BEGIN

	ClockProcess100MHz : PROCESS(Clock)
  BEGIN
		Clock <= NOT Clock AFTER CLOCK_100MHZ_PERIOD / 2;
  END PROCESS;

	PROCESS
	
	BEGIN
		WAIT UNTIL rising_edge(Clock);
		
		Reset						<= '1';
		WAIT UNTIL rising_edge(Clock);
	
		Reset						<= '0';
		WAIT UNTIL rising_edge(Clock);
	
		Test_got				<= '1';
		WAIT UNTIL rising_edge(Clock);
		WAIT;
	END PROCESS;

	prng2 : entity PoC.arith_prng
		generic map (
			BITS		=> 8,
			SEED		=> 18
--			SEED		=> x"12"
		)
		port map (
			clk			=> Clock,						
			rst			=> Reset,						-- reset value to initial seed
			got			=> Test_got,				-- the current value has been got, and a new value should be calculated
			val			=> PRNG_Value				-- the pseudo-random number
		);

END;