LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;

LIBRARY	L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY	L_IO;
USE			L_IO.IOTypes.ALL;

ENTITY Debounce IS
  GENERIC (
	  CLOCK_FREQ_MHZ					: REAL					:= 50.0;
		DEBOUNCE_TIME_MS				: REAL					:= 5.0;
		BW											: POSITIVE			:= 1
	);
  PORT (
	  Clock										: IN	STD_LOGIC;
		I												: IN	STD_LOGIC_VECTOR(BW - 1 DOWNTO 0);
		O												: OUT STD_LOGIC_VECTOR(BW - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF Debounce IS
  -- Debounce Clock Cycles
	CONSTANT COUNTER_CYCLES		: POSITIVE := TimingToCycles_ms(DEBOUNCE_TIME_MS, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)) - 1;
	CONSTANT COUNTER_BW				: POSITIVE := log2ceil(COUNTER_CYCLES);

  -- Statemaschine
  TYPE T_STATE IS (ST_LOW, ST_LOW_LOCKED, ST_HIGH, ST_HIGH_LOCKED);
	
	SIGNAL I_meta							: STD_LOGIC_VECTOR(BW - 1 DOWNTO 0)			:= (OTHERS => '0');
	SIGNAL I_d								: STD_LOGIC_VECTOR(BW - 1 DOWNTO 0)			:= (OTHERS => '0');
	
BEGIN
	
	I_meta	<= I			WHEN rising_edge(Clock);
	I_d			<= I_meta WHEN rising_edge(Clock);
	
	
	gen : FOR J IN 0 TO BW - 1 GENERATE
	  SIGNAL State						: T_STATE										:= ST_LOW;
		SIGNAL NextState				: T_STATE;
		
		SIGNAL Counter_us				: UNSIGNED(COUNTER_BW DOWNTO 0)		:= (OTHERS => '0');
		SIGNAL Counter_en				: STD_LOGIC;
		SIGNAL Counter_ov				: STD_LOGIC;
		
	BEGIN
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				State			<= NextState;
			END IF;
		END PROCESS;

		PROCESS(State, I_d, Counter_ov)
		BEGIN
			NextState			<= State;
			
			O(J)					<= '0';
			Counter_en		<= '0';

			CASE State IS
				WHEN ST_LOW =>
					IF (I_d(J) = '1') THEN
						NextState		<= ST_HIGH_LOCKED;
					END IF;
				
				WHEN ST_HIGH_LOCKED =>
					O(J)					<= '1';
					Counter_en		<= '1';
				
					IF (Counter_ov = '1') THEN
						NextState		<= ST_HIGH;
					END IF;
				
				WHEN ST_HIGH =>
					O(J)					<= '1';
				
					IF (I_d(J) = '0') THEN
						NextState		<= ST_LOW_LOCKED;
					END IF;
				
				WHEN ST_LOW_LOCKED =>
					Counter_en		<= '1';
				
					IF (Counter_ov = '1') THEN
						NextState		<= ST_LOW;
					END IF;
					
			END CASE;
		END PROCESS;
		
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Counter_en = '0') THEN
					Counter_us		<= (OTHERS => '0');
				ELSE
					Counter_us		<= Counter_us + 1;
				END IF;
			END IF;
		END PROCESS;
		
		Counter_ov <= '1' WHEN (Counter_us = COUNTER_CYCLES) ELSE '0';
		
	END GENERATE;
END;