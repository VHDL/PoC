LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.all;
USE			IEEE.NUMERIC_STD.all;

LIBRARY	UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;


ENTITY xil_SystemMonitor_Virtex6 IS
	PORT (
		Reset								: IN	STD_LOGIC;				-- Reset signal for the System Monitor control logic
		
		Alarm_UserTemp			: OUT	STD_LOGIC;				-- Temperature-sensor alarm output
		Alarm_OverTemp			: OUT	STD_LOGIC;				-- Over-Temperature alarm output
		Alarm								: OUT	STD_LOGIC;				-- OR'ed output of all the Alarms
		VP									: IN	STD_LOGIC;				-- Dedicated Analog Input Pair
		VN									: IN	STD_LOGIC
	);
END;


ARCHITECTURE xilinx OF xil_SystemMonitor_Virtex6 IS
	SIGNAL FLOAT_VCCAUX_ALARM		: STD_LOGIC;
	SIGNAL FLOAT_VCCINT_ALARM		: STD_LOGIC;
	SIGNAL aux_channel_p				: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL aux_channel_n				: STD_LOGIC_VECTOR(15 DOWNTO 0);

	SIGNAL SysMonitor_Alarm			: STD_LOGIC_VECTOR(2 DOWNTO 0);
BEGIN
	genAUXChannel : FOR I IN 0 TO 15 GENERATE
		aux_channel_p(I) <= '0';
		aux_channel_n(I) <= '0';
	END GENERATE;

	SysMonitor : SYSMON
		GENERIC MAP (
			INIT_40						=> x"0000",										-- config reg 0
			INIT_41						=> x"300c",										-- config reg 1
			INIT_42						=> x"0a00",										-- config reg 2
			INIT_48						=> x"0100",										-- Sequencer channel selection
			INIT_49						=> x"0000",										-- Sequencer channel selection
			INIT_4A						=> x"0000",										-- Sequencer Average selection
			INIT_4B						=> x"0000",										-- Sequencer Average selection
			INIT_4C						=> x"0000",										-- Sequencer Bipolar selection
			INIT_4D						=> x"0000",										-- Sequencer Bipolar selection
			INIT_4E						=> x"0000",										-- Sequencer Acq time selection
			INIT_4F						=> x"0000",										-- Sequencer Acq time selection
			INIT_50						=> x"a418",										-- Temp alarm trigger
			INIT_51						=> x"5999",										-- Vccint upper alarm limit
			INIT_52						=> x"e000",										-- Vccaux upper alarm limit
			INIT_53						=> x"b363",										-- Temp alarm OT upper
			INIT_54						=> x"9c87",										-- Temp alarm reset
			INIT_55						=> x"5111",										-- Vccint lower alarm limit
			INIT_56						=> x"caaa",										-- Vccaux lower alarm limit
			INIT_57						=> x"a425",										-- Temp alarm OT reset
			SIM_DEVICE				=> "VIRTEX6",
			SIM_MONITOR_FILE	=> "SystemMonitor_sim.txt"
		)
		PORT MAP (
			-- Control and Clock
			RESET								=> Reset,
			CONVSTCLK						=> '0',
			CONVST							=> '0',
			-- DRP port
			DCLK								=> '0',
			DEN									=> '0',
			DADDR								=> "0000000",
			DWE									=> '0',
			DI									=> x"0000",
			DO									=> OPEN,
			DRDY								=> OPEN,
			-- External analog inputs
			VAUXN								=> aux_channel_n(15 DOWNTO 0),
			VAUXP								=> aux_channel_p(15 DOWNTO 0),
			VN									=> VN,
			VP									=> VP,
			-- Alarms
			OT									=> Alarm_OverTemp,
			ALM									=> SysMonitor_Alarm,
			-- Status
			CHANNEL							=> OPEN,
			BUSY								=> OPEN,
			EOC									=> OPEN,
			EOS									=> OPEN,

			JTAGBUSY						=> OPEN,
			JTAGLOCKED					=> OPEN,
			JTAGMODIFIED				=> OPEN
		);
	
	Alarm_UserTemp	<= SysMonitor_Alarm(0);
END;
