LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.io.ALL;


ENTITY GlitchFilter IS
  GENERIC (
		CLOCK_FREQ_MHZ										: REAL				:= 100.0;
		HIGH_SPIKE_SUPPRESSION_TIME_NS		: REAL				:= 50.0;
		LOW_SPIKE_SUPPRESSION_TIME_NS			: REAL				:= 50.0
	);
  PORT (
		Clock		: IN STD_LOGIC;
		I				: IN STD_LOGIC;
		O				: OUT STD_LOGIC
	);
END;


ARCHITECTURE rtl OF GlitchFilter IS
	-- Timing table ID
	CONSTANT TTID_HIGH_SPIKE				: NATURAL		:= 0;
	CONSTANT TTID_LOW_SPIKE					: NATURAL		:= 1;
	
	-- Timing table
	CONSTANT TIMING_TABLE						: T_NATVEC	:= (
		TTID_HIGH_SPIKE			=> TimingToCycles_ns(HIGH_SPIKE_SUPPRESSION_TIME_NS,	Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_LOW_SPIKE			=> TimingToCycles_ns(LOW_SPIKE_SUPPRESSION_TIME_NS,		Freq_MHz2Real_ns(CLOCK_FREQ_MHZ))
	);

	SIGNAL State										: STD_LOGIC												:= '0';
	SIGNAL NextState								: STD_LOGIC;

	SIGNAL TC_en										: STD_LOGIC;
	SIGNAL TC_Load									: STD_LOGIC;
	SIGNAL TC_Slot									: NATURAL;
	SIGNAL TC_Timeout								: STD_LOGIC;

BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			State		<= NextState;
		END IF;
	END PROCESS;

	PROCESS(State, I, TC_Timeout)
	BEGIN
		NextState		<= State;
		
		TC_en				<= '0';
		TC_Load			<= '0';
		TC_Slot			<= 0;
		
		CASE State IS
			WHEN '0' =>
				TC_Slot			<= 0;
			
				IF (I = '1') THEN
					TC_en			<= '1';
				ELSE
					TC_Load		<= '1';
				END IF;
				
				IF (TC_Timeout = '1') THEN
					NextState	<= '1';
				END IF;

			WHEN '1' =>
				TC_Slot			<= 1;
			
				IF (I = '0') THEN
					TC_en			<= '1';
				ELSE
					TC_Load		<= '1';
				END IF;
				
				IF (TC_Timeout = '1') THEN
					NextState	<= '0';
				END IF;
			
			WHEN OTHERS =>
				NULL;
			
		END CASE;
	END PROCESS;

	TC : ENTITY PoC.TimingCounter
		GENERIC MAP (
			TIMING_TABLE				=> TIMING_TABLE										-- timing table
		)
		PORT MAP (
			Clock								=> Clock,													-- clock
			Enable							=> TC_en,													-- enable counter
			Load								=> TC_Load,												-- load Timing Value from TIMING_TABLE selected by slot
			Slot								=> TC_Slot,												-- 
			Timeout							=> TC_Timeout											-- timing reached
		);	

	O <= State;
END;