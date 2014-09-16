-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;

LIBRARY PoC;
USE			PoC.physical.ALL;


ENTITY io_FanControl IS
	GENERIC (
		CLOCK_FREQ							: FREQ
	);
	PORT (
		Clock										: IN	STD_LOGIC;
		Reset										: IN	STD_LOGIC;
		
		Fan_PWM									: OUT	STD_LOGIC;
		Fan_Tacho								: IN	STD_LOGIC;
		
		TachoFrequency					: out std_logic_vector(15 downto 0)
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

LIBRARY IEEE;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.components.ALL;
USE			PoC.io.ALL;
USE			PoC.xil.ALL;


ARCHITECTURE rtl OF io_FanControl IS
	CONSTANT TIME_STARTUP			: TIME																							:= 500.0 ms;	-- StartUp time
	CONSTANT PWM_RESOLUTION		: POSITIVE																					:= 4;					-- 4 Bit resolution => 0 to 15 steps
	CONSTANT PWM_FREQ					: FREQ																							:= 20 Hz;			-- 

	CONSTANT TACHO_RESOLUTION	: POSITIVE																					:= 8;

	SIGNAL PWM_PWMIn					: STD_LOGIC_VECTOR(PWM_RESOLUTION - 1 DOWNTO 0);
	SIGNAL PWM_PWMOut					: STD_LOGIC																					:= '0';

	SIGNAL TC_Timeout					: STD_LOGIC;
	SIGNAL StartUp						: STD_LOGIC;
	
	SIGNAL Tacho_Freq					: STD_LOGIC_VECTOR(TACHO_RESOLUTION - 1 DOWNTO 0);
	SIGNAL Tacho_Frequency		: STD_LOGIC_VECTOR(TACHO_RESOLUTION + 4 DOWNTO 0);
BEGIN

	-- System Monitor and temerature to PWM ratio calculation for Virtex6
	-- ==========================================================================================================================================================
	genXilinx : IF (VENDOR = VENDOR_XILINX) GENERATE
		SIGNAL OverTemperature_async	: STD_LOGIC;
		SIGNAL OverTemperature_sync		: STD_LOGIC;
		                                         
		SIGNAL UserTemperature_async	: STD_LOGIC;
		SIGNAL UserTemperature_sync		: STD_LOGIC;
		
	BEGIN
		genVirtex6 : IF (DEVICE = DEVICE_VIRTEX6) GENERATE
			SystemMonitor : xil_SystemMonitor_Virtex6
				PORT MAP (
					Reset								=> Reset,										-- Reset signal for the System Monitor control logic
					
					Alarm_UserTemp			=> UserTemperature_async,		-- Temperature-sensor alarm output
					Alarm_OverTemp			=> OverTemperature_async,		-- Over-Temperature alarm output
					Alarm								=> OPEN,										-- OR'ed output of all the Alarms
					VP									=> '0',											-- Dedicated Analog Input Pair
					VN									=> '0'
				);
		END GENERATE;
		genSeries7 : IF (DEVICE_SERIES = 7) GENERATE
			SystemMonitor : xil_SystemMonitor_Series7
				PORT MAP (
					Reset								=> Reset,										-- Reset signal for the System Monitor control logic
					
					Alarm_UserTemp			=> UserTemperature_async,		-- Temperature-sensor alarm output
					Alarm_OverTemp			=> OverTemperature_async,		-- Over-Temperature alarm output
					Alarm								=> OPEN,										-- OR'ed output of all the Alarms
					VP									=> '0',											-- Dedicated Analog Input Pair
					VN									=> '0'
				);
		END GENERATE;

		sync : ENTITY PoC.xil_SyncBits
			GENERIC MAP (
				BITS			=> 2,
				INIT			=> "00"
			)
			PORT MAP (
				Clock				=> Clock,
				Input(0)		=> OverTemperature_async,
				Input(1)		=> OverTemperature_sync,
				Output(0)		=> UserTemperature_async,
				Output(1)		=> UserTemperature_sync
			);

		PROCESS(StartUp, UserTemperature_sync, OverTemperature_sync)
		BEGIN
			IF		(StartUp = '1') THEN								PWM_PWMIn <= to_slv(2**(PWM_RESOLUTION) - 1, PWM_RESOLUTION);			-- 100%; start up
			ELSIF (OverTemperature_sync = '1') THEN		PWM_PWMIn <= to_slv(2**(PWM_RESOLUTION) - 1, PWM_RESOLUTION);			-- 100%
			ELSIF (UserTemperature_sync = '1') THEN		PWM_PWMIn <= to_slv(2**(PWM_RESOLUTION - 1), PWM_RESOLUTION);			-- 50%
			ELSE																			PWM_PWMIn <= to_slv(4, PWM_RESOLUTION);														-- 13%
			END IF;
		END PROCESS;
	END GENERATE;
	
	-- timer for warm-up control
	-- ==========================================================================================================================================================
	TC : ENTITY PoC.io_TimingCounter
		GENERIC MAP (
			TIMING_TABLE				=> (0 => TimingToCycles(TIME_STARTUP, CLOCK_FREQ))	-- timing table
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
	PWM : ENTITY PoC.io_PulseWidthModulation
		GENERIC MAP (
			CLOCK_FREQ					=> CLOCK_FREQ,				--
			PWM_FREQ						=> PWM_FREQ,					-- 
			PWM_RESOLUTION			=> PWM_RESOLUTION			-- 
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
	Tacho : ENTITY PoC.io_FrequencyCounter
		GENERIC MAP (
			CLOCK_FREQ					=> CLOCK_FREQ,					--
			TIMEBASE						=> (60.0 sec / 64.0),		-- ca. 1 second
			RESOLUTION					=> 8										-- max. ca. 256 RPS -> max. ca. 16k RPM
		)
		PORT MAP (
			Clock								=> Clock,
			Reset								=> Reset,
			FreqIn							=> Fan_Tacho,
			FreqOut							=> Tacho_Freq
		);
	
	-- multiply by 64; divide by 2 for RPMs (2 impulses per revolution) => append 5x '0'
	TachoFrequency	<= resize(Tacho_Freq & "00000", TachoFrequency'length);		-- resizing to 16 bit
END;
