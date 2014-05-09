LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;

LIBRARY	PoC;
USE			PoC.utils.ALL;
USE			PoC.io.ALL;
USE			PoC.lcd.ALL;


ENTITY lcd_LCDBuffer IS
	GENERIC (
		CLOCK_FREQ_MHZ					: REAL				:= 100.0;			-- 100 MHz
		MIN_REFRESH_PERIOD_MS		: REAL				:= 100.0
	);
	PORT (
		Clock				: IN	STD_LOGIC;
		Reset				: IN	STD_LOGIC;
		
		Load				: IN	STD_LOGIC;
		LCDBuffer		:	IN	T_LCD;
		
		CharColumn	:	IN	T_LCD_COLUMN_INDEX;
		CharRow			: IN	T_LCD_ROW_INDEX;
		Char				: OUT	T_LCD_CHAR
	);
END;

ARCHITECTURE rtl OF lcd_LCDBuffer IS
	SIGNAL LCDBuffer_Load		: STD_LOGIC;
	SIGNAL LCDBuffer_d			: T_LCD			:= (OTHERS => (OTHERS => to_rawchar(' ')));
	
BEGIN
	SL : ENTITY PoC.misc_StrobeLimiter
		GENERIC MAP (
			MIN_STROBE_PERIOD_CYCLES	=> TimingToCycles_ms(MIN_REFRESH_PERIOD_MS,	Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
			INITIAL_LOCKED						=> FALSE,
			INITIAL_STROBE						=> TRUE
		)
		PORT MAP (
			Clock											=> Clock,
			I													=> Load,
			O													=> LCDBuffer_Load
		);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				LCDBuffer_d			<= (OTHERS => (OTHERS => to_rawchar(' ')));
			ELSE
				IF (LCDBuffer_Load = '1') THEN
					LCDBuffer_d		<= LCDBuffer;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Char <= to_LCD_CHAR2(LCDBuffer_d(CharRow)(CharColumn));
END;
