LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE PoC.config.ALL;

LIBRARY L_Global;
USE L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE L_IO.IOTypes.ALL;

LIBRARY L_SATAController;
USE L_SATAController.SATATypes.ALL;

ENTITY DeviceDetector IS
        GENERIC (
		CHIPSCOPE_KEEP		: BOOLEAN				:= FALSE;
		CLOCK_FREQ_MHZ		: REAL					:= 150.0;						-- 150 MHz
		NO_DEVICE_TIMEOUT_MS	: REAL					:= 0.5;							-- 0,5 ms
		NEW_DEVICE_TIMEOUT_MS	: REAL					:= 0.01							-- 10 us				-- TODO: unused?
	);
	PORT (
	        Clock			: IN STD_LOGIC;
		ElectricalIDLE		: IN STD_LOGIC;
		NoDevice		: OUT STD_LOGIC;
		NewDevice		: OUT STD_LOGIC
	);
END;

ARCHITECTURE rtl OF DeviceDetector IS
	ATTRIBUTE KEEP		: BOOLEAN;
	ATTRIBUTE FSM_ENCODING	: STRING;

	-- Statemachine
	TYPE T_State IS (ST_NORMAL_MODE, ST_NO_DEVICE, ST_NEW_DEVICE);
	
	SIGNAL State				: T_State												:= ST_NORMAL_MODE;
	SIGNAL NextState			: T_State;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(CHIPSCOPE_KEEP, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL ElectricalIDLE_i			: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";

	SIGNAL TC_load				: STD_LOGIC;
	SIGNAL TC_en				: STD_LOGIC;
	SIGNAL TC_timeout			: STD_LOGIC;
	SIGNAL TD_timeout			: STD_LOGIC;

BEGIN

	ElectricalIDLE_i <= ElectricalIDLE_i(0) & ElectricalIDLE WHEN rising_edge(Clock);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			State <= NextState;
		END IF;
	END PROCESS;

	PROCESS(State, ElectricalIDLE_i, TC_timeout, TD_timeout)
	BEGIN
		NextState			<= State;
		
		NoDevice			<= '0';
		NewDevice			<= '0';

		CASE State IS
			WHEN ST_NORMAL_MODE =>
				IF (TC_timeout = '1') THEN
					NextState	<= ST_NO_DEVICE;
				END IF;
			
			WHEN ST_NO_DEVICE =>
				NoDevice		<= '1';
			
				IF (TD_timeout = '1') THEN
					NextState	<= ST_NEW_DEVICE;
				END IF;

			WHEN ST_NEW_DEVICE =>
				NewDevice		<= '1';
				NextState		<= ST_NORMAL_MODE;

		END CASE;
	END PROCESS;
	
	TC : ENTITY L_IO.TimingCounter
	GENERIC MAP ( -- timing table
		TIMING_TABLE => T_NATVEC'(0 => TimingToCycles_ms(NO_DEVICE_TIMEOUT_MS, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)))
	)
	PORT MAP (
		Clock	=> Clock,
		Enable	=> TC_en,
		Load	=> TC_load,
		Slot	=> 0,
		Timeout	=> TC_timeout
	);
		
	TC_load <= ElectricalIDLE_i(0) and not ElectricalIDLE_i(1);
	TC_en <= ElectricalIDLE_i(0);

	TD : ENTITY L_IO.TimingCounter
	GENERIC MAP ( -- timing table
		TIMING_TABLE => T_NATVEC'(0 => TimingToCycles_ms(1000, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)))
	)
	PORT MAP (
		Clock	=> Clock,
		Enable	=> '1',
		Load	=> TC_timeout,
		Slot	=> 0,
		Timeout	=> TD_timeout
	);
		
END;