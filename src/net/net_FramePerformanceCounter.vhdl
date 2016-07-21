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
		AGGREGATION_INTERVAL			: time									:= 500 ms
	);
	port (
		Clock											: in	std_logic;
		Reset											: in	std_logic;

		In_Valid									: in	std_logic;
		In_Data										: in	T_SLV_8;
		In_SOF										: in	std_logic;
		In_EOF										: in	std_logic;
		In_Ack										: out	std_logic;

		Out_Valid									: out	std_logic;
		Out_Data									: out	T_SLV_8;
		Out_SOF										: out	std_logic;
		Out_EOF										: out	std_logic;
		Out_Ack										: in	std_logic;

		PacketsPerSecond					: out	T_SLV_32;
		BytesPerSecond						: out	T_SLV_32
	);
end;

architecture rtl of LocalLink_PerformanceCounter is
	attribute KEEP										: boolean;
	attribute FSM_ENCODING						: string;

	signal In_Ack_i									: std_logic;

	signal Is_NewPacket								: std_logic;
	signal Is_DataFlow								: std_logic;

	signal PacketCounter_rst					: std_logic;
	signal PacketCounter_en						: std_logic;
	signal PacketCounter_us						: unsigned(31 downto 0)			:= (others => '0');

	signal ByteCounter_rst						: std_logic;
	signal ByteCounter_en							: std_logic;
	signal ByteCounter_us							: unsigned(31 downto 0)			:= (others => '0');

	signal TimeBaseCounter_rst				: std_logic;
	signal TimeBaseCounter_en					: std_logic;
	signal TimeBaseCounter_us					: unsigned(31 downto 0)			:= (others => '0');
	signal TimeBaseCounter_ov					: std_logic;

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
	Is_NewPacket	<= In_Valid and In_SOF;
	Is_DataFlow		<= In_Valid and In_Ack_i;

	-- counter control
	PacketCounter_rst	<= TimeBaseCounter_ov;
	ByteCounter_rst		<= TimeBaseCounter_ov;

	PacketCounter_en	<= Is_NewPacket;
	ByteCounter_en		<= Is_DataFlow;

	-- packet and byte counters
	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset or PacketCounter_rst) = '1') then
				PacketCounter_us				<= (others => '0');
			else
				if (PacketCounter_en = '1') then
					PacketCounter_us			<= PacketCounter_us + 1;
				end if;
			end if;

			if ((Reset or ByteCounter_rst)= '1') then
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
			if ((Reset or TimeBaseCounter_rst) = '1') then
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
