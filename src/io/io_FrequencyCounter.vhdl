LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.io.ALL;


ENTITY FrequencyCounter IS
	GENERIC (
		CLOCK_FREQ_MHZ						: REAL									:= 100.0;
		TIMEBASE_s								: REAL									:= 1.0;
		RESOLUTION								: POSITIVE							:= 8
	);
	PORT (
		Clock				: IN	STD_LOGIC;
		Reset				: IN	STD_LOGIC;
    FreqIn			: IN	STD_LOGIC;
		FreqOut			: OUT	STD_LOGIC_VECTOR(RESOLUTION - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF FrequencyCounter IS
	CONSTANT TIMEBASECOUNTER_MAX				: POSITIVE																		:= TimingToCycles_s(TIMEBASE_s, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ));
	CONSTANT TIMEBASECOUNTER_BW					: POSITIVE																		:= log2ceilnz(TIMEBASECOUNTER_MAX);
	CONSTANT REQUENCYCOUNTER_MAX				: POSITIVE																		:= 2**RESOLUTION;
	CONSTANT FREQUENCYCOUNTER_BW				: POSITIVE																		:= RESOLUTION;
	
	SIGNAL TimeBaseCounter_us						: UNSIGNED(TIMEBASECOUNTER_BW - 1 DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL TimeBaseCounter_ov						: STD_LOGIC;
	SIGNAL FrequencyCounter_us					: UNSIGNED(FREQUENCYCOUNTER_BW DOWNTO 0)			:= (OTHERS => '0');
	SIGNAL FrequencyCounter_ov					: STD_LOGIC;
	
	SIGNAL FreqIn_d											: STD_LOGIC																		:= '0';
	SIGNAL FreqIn_re										: STD_LOGIC;
	
	SIGNAL FreqOut_d										: STD_LOGIC_VECTOR(RESOLUTION - 1 DOWNTO 0)		:= (OTHERS => '0');
BEGIN

	FreqIn_d	<= FreqIn WHEN rising_edge(Clock);
	FreqIn_re	<= NOT FreqIn_d AND FreqIn;

	-- timebase counter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') OR (TimeBaseCounter_ov = '1') THEN
				TimeBaseCounter_us		<= (OTHERS => '0');
			ELSE
				TimeBaseCounter_us		<= TimeBaseCounter_us + 1;
			END IF;
		END IF;
	END PROCESS;
	
	TimeBaseCounter_ov	<= to_sl(TimeBaseCounter_us = TIMEBASECOUNTER_MAX);
	
	-- frequency counter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') OR (TimeBaseCounter_ov = '1') THEN
				FrequencyCounter_us		<= (OTHERS => '0');
			ELSE
				IF (FrequencyCounter_ov = '0') AND (FreqIn_re = '1') THEN
					FrequencyCounter_us		<= FrequencyCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	FrequencyCounter_ov	<= FrequencyCounter_us(FrequencyCounter_us'high);
	
	-- hold counter value until next TimeBaseCounter event
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				FreqOut_d			<= (OTHERS => '0');
			ELSE
				IF (TimeBaseCounter_ov = '1') THEN
					IF (FrequencyCounter_ov = '1') THEN
						FreqOut_d	<= (OTHERS => '1');
					ELSE
						FreqOut_d	<= std_logic_vector(FrequencyCounter_us(FreqOut_d'range));
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	FreqOut		<= FreqOut_d;
END;
