library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;

entity LocalLink_PerformanceCounter is
	generic (
		CLOCK_IN_FREQ							: FREQ									:= 100 MHz;
		AGGREGATION_INTERVAL			: TIME									:= 500 ms
	);
	port (
		Clock											: in	STD_LOGIC;
		Reset											: in	STD_LOGIC;

		In_Valid									: in	STD_LOGIC;
		In_Data										: in	T_SLV_8;
		In_SOF										: in	STD_LOGIC;
		In_EOF										: in	STD_LOGIC;
		In_Ack										: out	STD_LOGIC;

		Out_Valid									: out	STD_LOGIC;
		Out_Data									: out	T_SLV_8;
		Out_SOF										: out	STD_LOGIC;
		Out_EOF										: out	STD_LOGIC;
		Out_Ack										: in	STD_LOGIC;

		PacketsPerSecond					: out	T_SLV_32;
		BytesPerSecond						: out	T_SLV_32
	);
end;

architecture rtl of LocalLink_PerformanceCounter is
	attribute KEEP										: BOOLEAN;
	attribute FSM_ENCODING						: STRING;

	signal In_Ack_i									: STD_LOGIC;

	signal Is_NewPacket								: STD_LOGIC;
	signal Is_DataFlow								: STD_LOGIC;

	signal PacketCounter_rst					: STD_LOGIC;
	signal PacketCounter_en						: STD_LOGIC;
	signal PacketCounter_us						: UNSIGNED(31 downto 0)			:= (others => '0');

	signal ByteCounter_rst						: STD_LOGIC;
	signal ByteCounter_en							: STD_LOGIC;
	signal ByteCounter_us							: UNSIGNED(31 downto 0)			:= (others => '0');

	signal TimeBaseCounter_rst				: STD_LOGIC;
	signal TimeBaseCounter_en					: STD_LOGIC;
	signal TimeBaseCounter_us					: UNSIGNED(31 downto 0)			:= (others => '0');
	signal TimeBaseCounter_ov					: STD_LOGIC;

	signal PacketsPerSecond_d					: T_SLV_32									:= (others => '0');
	signal BytesPerSecond_d						: T_SLV_32									:= (others => '0');
begin
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
	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset OR PacketCounter_rst) = '1') then
				PacketCounter_us				<= (others => '0');
			else
				if (PacketCounter_en = '1') then
					PacketCounter_us			<= PacketCounter_us + 1;
				end if;
			end if;

			if ((Reset OR ByteCounter_rst)= '1') then
				ByteCounter_us					<= (others => '0');
			else
				if (ByteCounter_en = '1') then
					ByteCounter_us				<= ByteCounter_us + 1;
				end if;
			end if;
		end if;
	end process;

	-- timebase
	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset OR TimeBaseCounter_rst) = '1') then
				TimeBaseCounter_us				<= (others => '0');
			else
				if (TimeBaseCounter_en = '1') then
					TimeBaseCounter_us			<= TimeBaseCounter_us + 1;
				end if;
			end if;
		end if;
	end process;

	TimeBaseCounter_ov		<= to_sl(TimeBaseCounter_us = TimingToCycles(AGGREGATION_INTERVAL, CLOCK_IN_FREQ));

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				PacketsPerSecond_d		<= (others => '0');
				BytesPerSecond_d			<= (others => '0');
			else
				if (TimeBaseCounter_ov = '1') then
					PacketsPerSecond_d	<= std_logic_vector(PacketCounter_us);
					BytesPerSecond_d		<= std_logic_vector(ByteCounter_us);
				end if;
			end if;
		end if;
	end process;

	PacketsPerSecond		<= std_logic_vector(PacketsPerSecond_d(29 downto 0))	& "00";
	BytesPerSecond			<= std_logic_vector(BytesPerSecond_d(29 downto 0))		& "00";
end architecture;
