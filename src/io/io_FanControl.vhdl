LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalComp.ALL;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;


ENTITY FanControl IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ				: REAL									:= 100.0
	);
	PORT (
		Clock										: IN	STD_LOGIC;
		Reset										: IN	STD_LOGIC;
		
		Fan_PWM									: OUT	STD_LOGIC;
		Fan_Tacho								: IN	STD_LOGIC;
		
		TachoFrequency					: OUT	T_SLV_16
	);
END;

--	System Monitor settings
-- ============================================================================================================================================================
--
--
--									|											 /-----\
--	Temp_ov	 on=80	|	-	-	-	-	-	-	/-------/				\
--									|						 /				|				 \
--	Temp_ov	off=60	|	-	-	-	-	-	/	-	-	-	-	|	-	-	-	-	\----\
--									|					 /					|								\
--									|					/						|							 | \
--	Temp_us	 on=35	|	-	 /---/						|							 |	\
--	Temp_us	off=30	|	-	/	-	-|-	-	-	-	-	-	|	-	-	-	-	-	-	-|-  \------\
--									|  /		 |						|							 |					 \
--	----------------|--------|------------|--------------|----------|---------
--	pwm =						|		min	 |	medium		|		max				 |	medium	|	min
--
-- ============================================================================================================================================================


ARCHITECTURE rtl OF FanControl IS
	CONSTANT TIME_STARTUP_MS	: REAL																							:= 5000.0;		-- 500 ms StartUp time
	CONSTANT PWM_RESOLUTION		: POSITIVE																					:= 4;				-- 4 Bit resolution => 0 to 15 steps
	CONSTANT PWM_FREQ_KHZ			: REAL																							:= 0.020;		-- 20 Hz

	CONSTANT TACHO_RESOLUTION	: POSITIVE																					:= 8;

	SIGNAL PWM_PWMIn					: STD_LOGIC_VECTOR(PWM_RESOLUTION - 1 DOWNTO 0);
	SIGNAL PWM_PWMOut					: STD_LOGIC																					:= '0';

	SIGNAL TC_Timeout					: STD_LOGIC;
	SIGNAL StartUp						: STD_LOGIC;

	SIGNAL Fan_Tacho_meta			: STD_LOGIC																					:= '0';
	SIGNAL Fan_Tacho_d				: STD_LOGIC																					:= '0';
	SIGNAL Tacho_Freq					: STD_LOGIC_VECTOR(TACHO_RESOLUTION - 1 DOWNTO 0);
	SIGNAL Tacho_Frequency		: STD_LOGIC_VECTOR(TACHO_RESOLUTION + 4 DOWNTO 0);
BEGIN

	-- System Monitor and temerature to PWM ratio calculation for Virtex6
	-- ==========================================================================================================================================================
	genVirtex6 : IF (DEVICE = DEVICE_VIRTEX6) GENERATE
		SIGNAL OverTemperature		: STD_LOGIC;
		SIGNAL OverTemperature_d1	: STD_LOGIC																					:= '0';
		SIGNAL OverTemperature_d2	: STD_LOGIC																					:= '0';
		
		SIGNAL UserTemperature		: STD_LOGIC;
		SIGNAL UserTemperature_d1	: STD_LOGIC																					:= '0';
		SIGNAL UserTemperature_d2	: STD_LOGIC																					:= '0';
	BEGIN
		SystemMonitor : SystemMonitor_Virtex6
			PORT MAP (
				Reset								=> Reset,									-- Reset signal for the System Monitor control logic
				
				Alarm_UserTemp			=> UserTemperature,				-- Temperature-sensor alarm output
				Alarm_OverTemp			=> OverTemperature,				-- Over-Temperature alarm output
				Alarm								=> OPEN,									-- OR'ed output of all the Alarms
				VP									=> '0',										-- Dedicated Analog Input Pair
				VN									=> '0'
			);

		OverTemperature_d1	<= OverTemperature		WHEN rising_edge(Clock);
		OverTemperature_d2	<= OverTemperature_d1	WHEN rising_edge(Clock);
		UserTemperature_d1	<= UserTemperature		WHEN rising_edge(Clock);
		UserTemperature_d2	<= UserTemperature_d1	WHEN rising_edge(Clock);

		PROCESS(StartUp, UserTemperature_d2, OverTemperature_d2)
		BEGIN
			PWM_PWMIn			<= (OTHERS => '0');
			
			IF (StartUp = '1') THEN
				PWM_PWMIn		<= to_slv(2**(PWM_RESOLUTION) - 1, PWM_RESOLUTION);			-- 100%; start up
			ELSIF (OverTemperature_d2 = '1') THEN
				PWM_PWMIn		<= to_slv(2**(PWM_RESOLUTION) - 1, PWM_RESOLUTION);			-- 100%
			ELSIF (UserTemperature_d2 = '1') THEN
				PWM_PWMIn		<= to_slv(2**(PWM_RESOLUTION - 1), PWM_RESOLUTION);			-- 50%
			ELSE
				PWM_PWMIn		<= to_slv(4, PWM_RESOLUTION);														-- 13%
			END IF;
		END PROCESS;
	END GENERATE;
	
	-- System Monitor and temerature to PWM ratio calculation for Virtex7
	-- ==========================================================================================================================================================
	genVirtex7 : IF (DEVICE = DEVICE_VIRTEX7) GENERATE
		SIGNAL OverTemperature		: STD_LOGIC;
		SIGNAL OverTemperature_d1	: STD_LOGIC																					:= '0';
		SIGNAL OverTemperature_d2	: STD_LOGIC																					:= '0';
		
		SIGNAL UserTemperature		: STD_LOGIC;
		SIGNAL UserTemperature_d1	: STD_LOGIC																					:= '0';
		SIGNAL UserTemperature_d2	: STD_LOGIC																					:= '0';
	BEGIN
		SystemMonitor : SystemMonitor_Virtex7
			PORT MAP (
				Reset								=> Reset,									-- Reset signal for the System Monitor control logic
				
				Alarm_UserTemp			=> UserTemperature,				-- Temperature-sensor alarm output
				Alarm_OverTemp			=> OverTemperature,				-- Over-Temperature alarm output
				Alarm								=> OPEN,									-- OR'ed output of all the Alarms
				VP									=> '0',										-- Dedicated Analog Input Pair
				VN									=> '0'
			);

		OverTemperature_d1	<= OverTemperature		WHEN rising_edge(Clock);
		OverTemperature_d2	<= OverTemperature_d1	WHEN rising_edge(Clock);
		UserTemperature_d1	<= UserTemperature		WHEN rising_edge(Clock);
		UserTemperature_d2	<= UserTemperature_d1	WHEN rising_edge(Clock);

		PROCESS(StartUp, UserTemperature_d2, OverTemperature_d2)
		BEGIN
			PWM_PWMIn			<= (OTHERS => '0');
		
			IF (StartUp = '1') THEN
				PWM_PWMIn		<= to_slv(2**(PWM_RESOLUTION) - 1, PWM_RESOLUTION);			-- 100%; start up
			ELSIF (OverTemperature_d2 = '1') THEN
				PWM_PWMIn		<= to_slv(2**(PWM_RESOLUTION) - 1, PWM_RESOLUTION);			-- 100%
			ELSIF (UserTemperature_d2 = '1') THEN
				PWM_PWMIn		<= to_slv(2**(PWM_RESOLUTION - 1), PWM_RESOLUTION);			-- 50%
			ELSE
				PWM_PWMIn		<= to_slv(4, PWM_RESOLUTION);														-- 13%
			END IF;
		END PROCESS;
	END GENERATE;
	
	-- startup timer
	-- ==========================================================================================================================================================
	TC : ENTITY L_IO.TimingCounter
		GENERIC MAP (
			TIMING_TABLE				=> (0 => TimingToCycles_ms(TIME_STARTUP_MS, Freq_MHz2Real_ns(CLOCK_IN_FREQ_MHZ)))								-- timing table
		)
		PORT MAP (
			Clock								=> Clock,																			-- clock
			Enable							=> StartUp,																		-- enable counter
			Load								=> '0',																				-- load Timing Value from TIMING_TABLE selected by slot
			Slot								=> 0,																					-- 
			Timeout							=> TC_Timeout																	-- timing reached
		);
		
	StartUp	<= NOT TC_Timeout;
	
	-- PWM signal modulator
	-- ==========================================================================================================================================================
	PWM : ENTITY L_IO.PulseWidthModulation
		GENERIC MAP (
			CLOCK_IN_FREQ_MHZ		=> CLOCK_IN_FREQ_MHZ,		--
			PWM_FREQ_kHz				=> PWM_FREQ_kHz,				-- 
			PWM_RESOLUTION			=> PWM_RESOLUTION				-- 
		)
		PORT MAP (
			Clock								=> Clock,
			Reset								=> Reset,
			PWMIn								=> PWM_PWMIn,
			PWMOut							=> PWM_PWMOut
		);

	Fan_PWM 		<= PWM_PWMOut	WHEN rising_edge(Clock);
	
	-- tacho signal interpretation -> convert to RPM
	-- ==========================================================================================================================================================
	Fan_Tacho_meta	<= Fan_Tacho			WHEN rising_edge(Clock);
	Fan_Tacho_d			<= Fan_Tacho_meta	WHEN rising_edge(Clock);
	
	Tacho : ENTITY L_IO.FrequencyCounter
		GENERIC MAP (
			CLOCK_IN_FREQ_MHZ		=> CLOCK_IN_FREQ_MHZ,		--
			TIMEBASE_s					=> (60.0 / 64.0),				-- ca. 1 second
			RESOLUTION					=> 8										-- max. ca. 256 RPS -> max. ca. 16k RPM
		)
		PORT MAP (
			Clock								=> Clock,
			Reset								=> Reset,
			FreqIn							=> Fan_Tacho_d,
			FreqOut							=> Tacho_Freq
		);
	
	-- multiply by 64; divide by 2 for RPMs (2 impulses per revolution) => append 5x '0'
	TachoFrequency	<= resize(Tacho_Freq & "00000", TachoFrequency'length);		-- resizing to 16 bit
END;
