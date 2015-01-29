LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;

ENTITY LocalLink_PerformanceCounter IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ					: REAL									:= 100.0;
		AGGREGATION_INTERVAL_MS		: REAL									:= 500.0
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		In_Valid									: IN	STD_LOGIC;
		In_Data										: IN	T_SLV_8;
		In_SOF										: IN	STD_LOGIC;
		In_EOF										: IN	STD_LOGIC;
		In_Ack										: OUT	STD_LOGIC;

		Out_Valid									: OUT	STD_LOGIC;
		Out_Data									: OUT	T_SLV_8;
		Out_SOF										: OUT	STD_LOGIC;
		Out_EOF										: OUT	STD_LOGIC;
		Out_Ack										: IN	STD_LOGIC;
		
		PacketsPerSecond					: OUT	T_SLV_32;
		BytesPerSecond						: OUT	T_SLV_32
	);
END;

ARCHITECTURE rtl OF LocalLink_PerformanceCounter IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	SIGNAL In_Ack_i									: STD_LOGIC;
	
	SIGNAL Is_NewPacket								: STD_LOGIC;
	SIGNAL Is_DataFlow								: STD_LOGIC;
	
	SIGNAL PacketCounter_rst					: STD_LOGIC;
	SIGNAL PacketCounter_en						: STD_LOGIC;
	SIGNAL PacketCounter_us						: UNSIGNED(31 DOWNTO 0)			:= (OTHERS => '0');

	SIGNAL ByteCounter_rst						: STD_LOGIC;
	SIGNAL ByteCounter_en							: STD_LOGIC;
	SIGNAL ByteCounter_us							: UNSIGNED(31 DOWNTO 0)			:= (OTHERS => '0');
	
	SIGNAL TimeBaseCounter_rst				: STD_LOGIC;
	SIGNAL TimeBaseCounter_en					: STD_LOGIC;
	SIGNAL TimeBaseCounter_us					: UNSIGNED(31 DOWNTO 0)			:= (OTHERS => '0');
	SIGNAL TimeBaseCounter_ov					: STD_LOGIC;

	SIGNAL PacketsPerSecond_d					: T_SLV_32									:= (OTHERS => '0');
	SIGNAL BytesPerSecond_d						: T_SLV_32									:= (OTHERS => '0');
BEGIN
	-- data path
	Out_Valid		<= In_Valid;
	Out_Data		<= In_Data;
	Out_SOF			<= In_SOF;
	Out_EOF			<= In_EOF;
	
	In_Ack_i	<= Out_Ack;
	In_Ack			<= In_Ack_i;
	
	-- triggers
	Is_NewPacket	<= In_Valid AND In_SOF;
	Is_DataFlow		<= In_Valid AND In_Ack_i;
	
	-- counter control
	PacketCounter_rst	<= TimeBaseCounter_ov;
	ByteCounter_rst		<= TimeBaseCounter_ov;
	
	PacketCounter_en	<= Is_NewPacket;
	ByteCounter_en		<= Is_DataFlow;
	
	-- packet and byte counters
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR PacketCounter_rst) = '1') THEN
				PacketCounter_us				<= (OTHERS => '0');
			ELSE
				IF (PacketCounter_en = '1') THEN
					PacketCounter_us			<= PacketCounter_us + 1;
				END IF;
			END IF;
			
			IF ((Reset OR ByteCounter_rst)= '1') THEN
				ByteCounter_us					<= (OTHERS => '0');
			ELSE
				IF (ByteCounter_en = '1') THEN
					ByteCounter_us				<= ByteCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	-- timebase
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR TimeBaseCounter_rst) = '1') THEN
				TimeBaseCounter_us				<= (OTHERS => '0');
			ELSE
				IF (TimeBaseCounter_en = '1') THEN
					TimeBaseCounter_us			<= TimeBaseCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	TimeBaseCounter_ov		<= to_sl(TimeBaseCounter_us = TimingToCycles_ms(AGGREGATION_INTERVAL_MS, Freq_MHz2Real_ns(CLOCK_IN_FREQ_MHZ)));
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				PacketsPerSecond_d		<= (OTHERS => '0');
				BytesPerSecond_d			<= (OTHERS => '0');
			ELSE
				IF (TimeBaseCounter_ov = '1') THEN
					PacketsPerSecond_d	<= std_logic_vector(PacketCounter_us);
					BytesPerSecond_d		<= std_logic_vector(ByteCounter_us);
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	PacketsPerSecond		<= std_logic_vector(PacketsPerSecond_d(29 DOWNTO 0))	& "00";
	BytesPerSecond			<= std_logic_vector(BytesPerSecond_d(29 DOWNTO 0))		& "00";
END ARCHITECTURE;
