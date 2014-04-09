LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;


ENTITY IPv6_TX IS
	GENERIC (
		CHIPSCOPE_KEEP									: BOOLEAN													:= FALSE
	);
	PORT (
		Clock														: IN	STD_LOGIC;																	-- 
		Reset														: IN	STD_LOGIC;																	-- 
		-- IN port
		In_Valid												: IN	STD_LOGIC;
		In_Data													: IN	T_SLV_8;
		In_SOF													: IN	STD_LOGIC;
		In_EOF													: IN	STD_LOGIC;
		In_Ready												: OUT	STD_LOGIC;
		In_Meta_rst											: OUT	STD_LOGIC;
		In_Meta_SrcIPv6Address_nxt			: OUT	STD_LOGIC;
		In_Meta_SrcIPv6Address_Data			: IN	T_SLV_8;
		In_Meta_DestIPv6Address_nxt			: OUT	STD_LOGIC;
		In_Meta_DestIPv6Address_Data		: IN	T_SLV_8;
		In_Meta_TrafficClass						: IN	T_SLV_8;
		In_Meta_FlowLabel								: IN	STD_LOGIC_VECTOR(19 DOWNTO 0);
		In_Meta_Length									: IN	T_SLV_16;
		In_Meta_NextHeader							: IN	T_SLV_8;
		-- to NDP layer
		NDP_NextHop_Query								: OUT	STD_LOGIC;
		NDP_NextHop_IPv6Address_rst			: IN	STD_LOGIC;
		NDP_NextHop_IPv6Address_nxt			: IN	STD_LOGIC;
		NDP_NextHop_IPv6Address_Data		: OUT	T_SLV_8;
		-- from NDP layer
		NDP_NextHop_Valid								: IN	STD_LOGIC;
		NDP_NextHop_MACAddress_rst			: OUT	STD_LOGIC;
		NDP_NextHop_MACAddress_nxt			: OUT	STD_LOGIC;
		NDP_NextHop_MACAddress_Data			: IN	T_SLV_8;
		-- OUT port
		Out_Valid												: OUT	STD_LOGIC;
		Out_Data												: OUT	T_SLV_8;
		Out_SOF													: OUT	STD_LOGIC;
		Out_EOF													: OUT	STD_LOGIC;
		Out_Ready												: IN	STD_LOGIC;
		Out_Meta_rst										: IN	STD_LOGIC;
		Out_Meta_DestMACAddress_nxt			: IN	STD_LOGIC;
		Out_Meta_DestMACAddress_Data		: OUT	T_SLV_8
	);
END;

-- Endianess: big-endian
-- Alignment: 8 byte
--
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+----------------+---------------+----------------+---------------+--------------------------------+--------------------------------+
--	| IPVers. (0x06) | TrafficClass 							 		| FlowLabel																																				|
--	+----------------+---------------+----------------+---------------+--------------------------------+--------------------------------+
--	| PayloadLength																										| NextHeader										 | HopLimit												|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| SourceAddress																																																											|
--	+                                +                                +                                +                                +
--	|																																																																		|
--	+                                +                                +                                +                                +
--	|																																																																		|
--	+                                +                                +                                +                                +
--	|																																																																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| DestinationAddress																																																								|
--	+                                +                                +                                +                                +
--	|																																																																		|
--	+                                +                                +                                +                                +
--	|																																																																		|
--	+                                +                                +                                +                                +
--	|																																																																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| ExtensionHeader(s)																																																								|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| Payload																																																														|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+

ARCHITECTURE rtl OF IPv6_TX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_NDP_QUERY,								ST_NDP_QUERY_WAIT,
			ST_SEND_VERSION,
			ST_SEND_TRAFFIC_CLASS,
			ST_SEND_FLOW_LABEL_1,				ST_SEND_FLOW_LABEL_2,
			ST_SEND_In_Meta_Length_0,		ST_SEND_In_Meta_Length_1,
			ST_SEND_NEXT_HEADER,				ST_SEND_HOP_LIMIT,
			ST_SEND_SOURCE_ADDRESS,
			ST_SEND_DESTINATION_ADDRESS,
			ST_SEND_DATA,
		ST_DISCARD_FRAME,
		ST_ERROR
	);

	SIGNAL State											: T_STATE											:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(CHIPSCOPE_KEEP, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL In_Ready_i									: STD_LOGIC;

	SIGNAL IPv6SeqCounter_rst					: STD_LOGIC;
	SIGNAL IPv6SeqCounter_en					: STD_LOGIC;
	SIGNAL IPv6SeqCounter_us					: UNSIGNED(3 DOWNTO 0)				:= (OTHERS => '0');

BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_IDLE;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, In_Valid, In_SOF, In_EOF, In_Data,
					In_Meta_Length,
					Out_Ready, Out_Meta_rst, Out_Meta_DestMACAddress_nxt,--Out_Meta_DestMACAddress_rev, 
					NDP_NextHop_Valid, NDP_NextHop_IPv6Address_rst, NDP_NextHop_IPv6Address_nxt, NDP_NextHop_MACAddress_Data,--NDP_NextHop_IPv6Address_rev, 
					In_Meta_DestIPv6Address_Data, In_Meta_SrcIPv6Address_Data, In_Meta_TrafficClass, In_Meta_FlowLabel, In_Meta_NextHeader,
					IPv6SeqCounter_us)
	BEGIN
		NextState													<= State;
		
		In_Ready_i												<= '0';
		
		Out_Valid													<= '0';
		Out_Data													<= (OTHERS => '0');
		Out_SOF														<= '0';
		Out_EOF														<= '0';

		In_Meta_rst												<= '0';

		NDP_NextHop_Query									<= '0';
		In_Meta_SrcIPv6Address_nxt				<= '0';
		In_Meta_DestIPv6Address_nxt				<= '0';
		NDP_NextHop_IPv6Address_Data			<= In_Meta_DestIPv6Address_Data;
		
		NDP_NextHop_MACAddress_rst				<= Out_Meta_rst;
		NDP_NextHop_MACAddress_nxt				<= Out_Meta_DestMACAddress_nxt;
		Out_Meta_DestMACAddress_Data			<= NDP_NextHop_MACAddress_Data;

		IPv6SeqCounter_rst								<= '0';
		IPv6SeqCounter_en									<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				In_Meta_rst										<= NDP_NextHop_IPv6Address_rst;
				In_Meta_DestIPv6Address_nxt		<= NDP_NextHop_IPv6Address_nxt;
				
				IF ((In_Valid AND In_SOF) = '1') THEN
					NextState										<= ST_NDP_QUERY;
				END IF;
			
			WHEN ST_NDP_QUERY =>
				Out_Data											<= x"6" & In_Meta_TrafficClass(7 DOWNTO 4);
				Out_SOF												<= '1';

				In_Meta_rst											<= NDP_NextHop_IPv6Address_rst;
				In_Meta_DestIPv6Address_nxt		<= NDP_NextHop_IPv6Address_nxt;

				NDP_NextHop_Query							<= '1';
				
				IF (NDP_NextHop_Valid = '1') THEN
					Out_Valid										<= '1';
					In_Meta_rst									<= '1';		-- reset metadata
					
					IF (Out_Ready = '1') THEN
						NextState									<= ST_SEND_TRAFFIC_CLASS;
					ELSE
						NextState									<= ST_SEND_VERSION;
					END IF;
				ELSE
					NextState										<= ST_NDP_QUERY_WAIT;
				END IF;
			
			WHEN ST_NDP_QUERY_WAIT =>
				Out_Valid											<= '0';
				Out_Data											<= x"6" & In_Meta_TrafficClass(7 DOWNTO 4);
				Out_SOF												<= '1';
			
				In_Meta_rst										<= NDP_NextHop_IPv6Address_rst;
				In_Meta_DestIPv6Address_nxt		<= NDP_NextHop_IPv6Address_nxt;
			
				IF (NDP_NextHop_Valid = '1') THEN
					Out_Valid										<= '1';
					In_Meta_rst									<= '1';		-- reset metadata
					
					IF (Out_Ready = '1') THEN
						NextState									<= ST_SEND_TRAFFIC_CLASS;
					ELSE
						NextState									<= ST_SEND_VERSION;
					END IF;
				END IF;
			
			WHEN ST_SEND_VERSION =>
				Out_Valid											<= '1';
				Out_Data											<= x"6" & In_Meta_TrafficClass(7 DOWNTO 4);
				Out_SOF												<= '1';

				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_TRAFFIC_CLASS;
				END IF;
			
			WHEN ST_SEND_TRAFFIC_CLASS =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_TrafficClass(3 DOWNTO 0) & In_Meta_FlowLabel(19 DOWNTO 16);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_FLOW_LABEL_1;
				END IF;

			WHEN ST_SEND_FLOW_LABEL_1 =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_FlowLabel(15 DOWNTO 8);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_FLOW_LABEL_2;
				END IF;
				
			WHEN ST_SEND_FLOW_LABEL_2 =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_FlowLabel(7 DOWNTO 0);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_In_Meta_Length_0;
				END IF;
				
			WHEN ST_SEND_In_Meta_Length_0 =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_Length(15 DOWNTO 8);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_In_Meta_Length_1;
				END IF;
				
			WHEN ST_SEND_In_Meta_Length_1 =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_Length(7 DOWNTO 0);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_NEXT_HEADER;
				END IF;
				
			WHEN ST_SEND_NEXT_HEADER =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_NextHeader;
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_HOP_LIMIT;
				END IF;
			
			WHEN ST_SEND_HOP_LIMIT =>
				Out_Valid											<= '1';
				Out_Data											<= x"02";		-- TODO: read from cache / routing info
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_SOURCE_ADDRESS;
				END IF;
			
			WHEN ST_SEND_SOURCE_ADDRESS =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_SrcIPv6Address_Data;
				
				IF (Out_Ready = '1') THEN
					In_Meta_SrcIPv6Address_nxt			<= '1';
					IPv6SeqCounter_en						<= '1';
				
					IF (IPv6SeqCounter_us = 15) THEN
						NextState									<= ST_SEND_DESTINATION_ADDRESS;
					END IF;
				END IF;
			
			WHEN ST_SEND_DESTINATION_ADDRESS =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_DestIPv6Address_Data;
				
				IF (Out_Ready = '1') THEN
					In_Meta_DestIPv6Address_nxt	<= '1';
					IPv6SeqCounter_en						<= '1';
				
					IF (IPv6SeqCounter_us = 15) THEN
						NextState									<= ST_SEND_DATA;
					END IF;
				END IF;
			
			WHEN ST_SEND_DATA =>
				Out_Valid												<= In_Valid;
				Out_Data												<= In_Data;
				Out_EOF													<= In_EOF;
				In_Ready_i											<= Out_Ready;
				
				IF ((In_EOF AND Out_Ready) = '1') THEN
					In_Meta_rst										<= '1';
					NextState											<= ST_IDLE;
				END IF;
			
			WHEN ST_DISCARD_FRAME =>
				NULL;
			
			WHEN ST_ERROR =>
				NULL;
				
		END CASE;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR IPv6SeqCounter_rst) = '1') THEN
				IPv6SeqCounter_us			<= (OTHERS => '0');
			ELSE
				IF (IPv6SeqCounter_en = '1') THEN
					IPv6SeqCounter_us		<= IPv6SeqCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	In_Ready												<= In_Ready_i;
END;