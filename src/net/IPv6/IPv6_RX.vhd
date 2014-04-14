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


ENTITY IPv6_RX IS
	GENERIC (
		CHIPSCOPE_KEEP									: BOOLEAN													:= FALSE
	);
	PORT (
		Clock														: IN	STD_LOGIC;																	-- 
		Reset														: IN	STD_LOGIC;																	-- 
		-- STATUS port
		Error														: OUT	STD_LOGIC;
		-- IN port
		In_Valid												: IN	STD_LOGIC;
		In_Data													: IN	T_SLV_8;
		In_SOF													: IN	STD_LOGIC;
		In_EOF													: IN	STD_LOGIC;
		In_Ready												: OUT	STD_LOGIC;
		In_Meta_rst											: OUT	STD_LOGIC;
		In_Meta_SrcMACAddress_nxt				: OUT	STD_LOGIC;
		In_Meta_SrcMACAddress_Data			: IN	T_SLV_8;
		In_Meta_DestMACAddress_nxt			: OUT	STD_LOGIC;
		In_Meta_DestMACAddress_Data			: IN	T_SLV_8;
		In_Meta_EthType									: IN	T_SLV_16;
		-- OUT port
		Out_Valid												: OUT	STD_LOGIC;
		Out_Data												: OUT	T_SLV_8;
		Out_SOF													: OUT	STD_LOGIC;
		Out_EOF													: OUT	STD_LOGIC;
		Out_Ready												: IN	STD_LOGIC;
		Out_Meta_rst										: IN	STD_LOGIC;
		Out_Meta_SrcMACAddress_nxt			: IN	STD_LOGIC;
		Out_Meta_SrcMACAddress_Data			: OUT	T_SLV_8;
		Out_Meta_DestMACAddress_nxt			: IN	STD_LOGIC;
		Out_Meta_DestMACAddress_Data		: OUT	T_SLV_8;
		Out_Meta_EthType								: OUT	T_SLV_16;
		Out_Meta_SrcIPv6Address_nxt			: IN	STD_LOGIC;
		Out_Meta_SrcIPv6Address_Data		: OUT	T_SLV_8;
		Out_Meta_DestIPv6Address_nxt		: IN	STD_LOGIC;
		Out_Meta_DestIPv6Address_Data		: OUT	T_SLV_8;
		Out_Meta_TrafficClass						: OUT	T_SLV_8;
		Out_Meta_FlowLabel							: OUT	T_SLV_24;	--STD_LOGIC_VECTOR(19 DOWNTO 0);
		Out_Meta_Length									: OUT	T_SLV_16;
		Out_Meta_NextHeader							: OUT	T_SLV_8
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


ARCHITECTURE rtl OF IPv6_RX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	SUBTYPE T_BYTEINDEX								IS NATURAL RANGE 0 TO 1;
	SUBTYPE T_IPV6_BYTEINDEX	 				IS NATURAL RANGE 0 TO 15;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_RECEIVE_TRAFFIC_CLASS,
			ST_RECEIVE_FLOW_LABEL_1,	ST_RECEIVE_FLOW_LABEL_2,
			ST_RECEIVE_LENGTH_0,			ST_RECEIVE_LENGTH_1,
			ST_RECEIVE_NEXT_HEADER,		ST_RECEIVE_HOP_LIMIT,
			ST_RECEIVE_SOURCE_ADDRESS,
			ST_RECEIVE_DESTINATION_ADDRESS,

			ST_RECEIVE_DATA_1, ST_RECEIVE_DATA_N,
		ST_DISCARD_FRAME,
		ST_ERROR
	);

	SIGNAL State													: T_STATE											:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State				: SIGNAL IS ite(CHIPSCOPE_KEEP, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL In_Ready_i											: STD_LOGIC;
	SIGNAL Is_DataFlow										: STD_LOGIC;
	SIGNAL Is_SOF													: STD_LOGIC;
	SIGNAL Is_EOF													: STD_LOGIC;

	SIGNAL Out_Valid_i										: STD_LOGIC;
	SIGNAL Out_SOF_i											: STD_LOGIC;
	SIGNAL Out_EOF_i											: STD_LOGIC;

	SUBTYPE T_IP_BYTEINDEX								IS NATURAL RANGE 0 TO 15;
	SIGNAL IP_ByteIndex										: T_IP_BYTEINDEX;

	SIGNAL Register_rst										: STD_LOGIC;
	
	-- IPv6 basic header fields
	SIGNAL TrafficClass_en0								: STD_LOGIC;
	SIGNAL TrafficClass_en1								: STD_LOGIC;
	SIGNAL FlowLabel_en0									: STD_LOGIC;
	SIGNAL FlowLabel_en1									: STD_LOGIC;
	SIGNAL FlowLabel_en2									: STD_LOGIC;
	SIGNAL Length_en0											: STD_LOGIC;
	SIGNAL Length_en1											: STD_LOGIC;
	SIGNAL NextHeader_en									: STD_LOGIC;
	SIGNAL HopLimit_en										: STD_LOGIC;
	SIGNAL SourceIPv6Address_en						: STD_LOGIC;
	SIGNAL DestIPv6Address_en							: STD_LOGIC;
	
	SIGNAL TrafficClass_d									: T_SLV_8													:= (OTHERS => '0');
	SIGNAL FlowLabel_d										: STD_LOGIC_VECTOR(19 DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL Length_d												: T_SLV_16												:= (OTHERS => '0');
	SIGNAL NextHeader_d										: T_SLV_8													:= (OTHERS => '0');
	SIGNAL HopLimit_d											: T_SLV_8													:= (OTHERS => '0');
	SIGNAL SourceIPv6Address_d						: T_NET_IPV6_ADDRESS							:= (OTHERS => (OTHERS => '0'));
	SIGNAL DestIPv6Address_d							: T_NET_IPV6_ADDRESS							:= (OTHERS => (OTHERS => '0'));

	CONSTANT IPV6_ADDRESS_LENGTH					: POSITIVE												:= 16;			-- IPv6 -> 16 bytes
	CONSTANT IPV6_ADDRESS_READER_BITS			: POSITIVE												:= log2ceilnz(IPV6_ADDRESS_LENGTH);

	SIGNAL IPv6SeqCounter_rst							: STD_LOGIC;
	SIGNAL IPv6SeqCounter_en							: STD_LOGIC;
	SIGNAL IPv6SeqCounter_us							: UNSIGNED(IPV6_ADDRESS_READER_BITS - 1 DOWNTO 0)		:= to_unsigned(IPV6_ADDRESS_LENGTH - 1, IPV6_ADDRESS_READER_BITS);

	SIGNAL SrcIPv6Address_Reader_rst			: STD_LOGIC;
	SIGNAL SrcIPv6Address_Reader_en				: STD_LOGIC;
	SIGNAL SrcIPv6Address_Reader_us				: UNSIGNED(IPV6_ADDRESS_READER_BITS - 1 DOWNTO 0)		:= to_unsigned(IPV6_ADDRESS_LENGTH - 1, IPV6_ADDRESS_READER_BITS);
	SIGNAL DestIPv6Address_Reader_rst			: STD_LOGIC;
	SIGNAL DestIPv6Address_Reader_en			: STD_LOGIC;
	SIGNAL DestIPv6Address_Reader_us			: UNSIGNED(IPV6_ADDRESS_READER_BITS - 1 DOWNTO 0)		:= to_unsigned(IPV6_ADDRESS_LENGTH - 1, IPV6_ADDRESS_READER_BITS);

	-- ExtensionHeader: Fragmentation
--	SIGNAL FragmentOffset_en0							: STD_LOGIC;
--	SIGNAL FragmentOffset_en1							: STD_LOGIC;
	
--	SIGNAL FragmentOffset_d								: STD_LOGIC_VECTOR(12 DOWNTO 0)		:= (OTHERS => '0');
	
BEGIN

	In_Ready			<= In_Ready_i;
	Is_DataFlow		<= In_Valid AND In_Ready_i;
	Is_SOF				<= In_Valid AND In_SOF;
	Is_EOF				<= In_Valid AND In_EOF;

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

	PROCESS(State, Is_DataFlow, Is_SOF, Is_EOF, In_Valid, In_Data, In_EOF, Out_Ready, IPv6SeqCounter_us)
	BEGIN
		NextState									<= State;

		Error											<= '0';
		
		In_Ready_i								<= '0';
		Out_Valid_i								<= '0';
		Out_SOF_i									<= '0';
		Out_EOF_i									<= '0';

		-- IPv6 basic header fields
		Register_rst							<= '0';
		TrafficClass_en0					<= '0';
		TrafficClass_en1					<= '0';
		FlowLabel_en0							<= '0';
		FlowLabel_en1							<= '0';
		FlowLabel_en2							<= '0';
		Length_en0								<= '0';
		Length_en1								<= '0';
		NextHeader_en							<= '0';
		HopLimit_en								<= '0';
		SourceIPv6Address_en			<= '0';
		DestIPv6Address_en				<= '0';

		IPv6SeqCounter_rst				<= '0';
		IPv6SeqCounter_en					<= '0';

		-- ExtensionHeader: Fragmentation
--		FragmentOffset_en0				<= '0';
--		FragmentOffset_en1				<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				IF (Is_SOF = '1') THEN
					In_Ready_i						<= '1';
				
					IF (Is_EOF = '0') THEN
						IF (In_Data(3 DOWNTO 0) = x"6") THEN
							TrafficClass_en0	<= '1';
							NextState					<= ST_RECEIVE_TRAFFIC_CLASS;
						ELSE
							NextState					<= ST_DISCARD_FRAME;
						END IF;
					ELSE  -- EOF
						NextState						<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_TRAFFIC_CLASS =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						TrafficClass_en1			<= '1';
						FlowLabel_en0					<= '1';
						NextState							<= ST_RECEIVE_FLOW_LABEL_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_FLOW_LABEL_1 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						FlowLabel_en1					<= '1';
						NextState							<= ST_RECEIVE_FLOW_LABEL_2;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_FLOW_LABEL_2 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						FlowLabel_en2					<= '1';
						NextState							<= ST_RECEIVE_LENGTH_0;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_LENGTH_0 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						Length_en0						<= '1';
						NextState							<= ST_RECEIVE_LENGTH_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_LENGTH_1 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						Length_en1						<= '1';
						NextState							<= ST_RECEIVE_NEXT_HEADER;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_NEXT_HEADER =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						NextHeader_en					<= '1';
						NextState							<= ST_RECEIVE_HOP_LIMIT;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_HOP_LIMIT =>
				IPv6SeqCounter_rst				<= '1';
				
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						HopLimit_en						<= '1';
						NextState							<= ST_RECEIVE_SOURCE_ADDRESS;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_SOURCE_ADDRESS =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					SourceIPv6Address_en		<= '1';
					IPv6SeqCounter_en				<= '1';
					
					IF (Is_EOF = '0') THEN
						IF (IPv6SeqCounter_us = 0) THEN
							IPv6SeqCounter_rst	<= '1';
							NextState						<= ST_RECEIVE_DESTINATION_ADDRESS;
						END IF;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_DESTINATION_ADDRESS =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					DestIPv6Address_en			<= '1';
					IPv6SeqCounter_en				<= '1';
					
					IF (Is_EOF = '0') THEN
						IF (IPv6SeqCounter_us = 0) THEN
							IPv6SeqCounter_rst	<= '1';
							NextState						<= ST_RECEIVE_DATA_1;
						END IF;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_DATA_1 =>
				In_Ready_i								<= Out_Ready;
				Out_Valid_i								<= In_Valid;
				Out_SOF_i									<= '1';
				Out_EOF_i									<= In_EOF;
			
				IF (Is_DataFlow = '1') THEN
					IF (Is_EOF = '0') THEN
						NextState							<= ST_RECEIVE_DATA_N;
					ELSE
						NextState							<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_DATA_N =>
				In_Ready_i								<= Out_Ready;
				Out_Valid_i								<= In_Valid;
				Out_EOF_i									<= In_EOF;
				
				IF (Is_EOF = '1') THEN
					NextState								<= ST_IDLE;
				END IF;
				
			WHEN ST_DISCARD_FRAME =>
				In_Ready_i								<= '1';
				
				IF (Is_EOF = '1') THEN
					NextState								<= ST_ERROR;
				END IF;
			
			WHEN ST_ERROR =>
				Error											<= '1';
				NextState									<= ST_IDLE;
			
		END CASE;
	END PROCESS;
	
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Register_rst) = '1') THEN
				TrafficClass_d						<= (OTHERS => '0');
				FlowLabel_d								<= (OTHERS => '0');
				Length_d									<= (OTHERS => '0');
				NextHeader_d							<= (OTHERS => '0');
				HopLimit_d								<= (OTHERS => '0');
			ELSE
				IF (TrafficClass_en0 = '1') THEN
					TrafficClass_d(7 DOWNTO 4)									<= In_Data(7 DOWNTO 4);
				END IF;
				IF (TrafficClass_en1 = '1') THEN
					TrafficClass_d(3 DOWNTO 0)									<= In_Data(3 DOWNTO 0);
				END IF;
				
				IF (FlowLabel_en0 = '1') THEN
					FlowLabel_d(19 DOWNTO 16)										<= In_Data(7 DOWNTO 4);
				END IF;
				IF (FlowLabel_en1 = '1') THEN
					FlowLabel_d(15 DOWNTO 8)										<= In_Data;
				END IF;
				IF (FlowLabel_en2 = '1') THEN
					FlowLabel_d(7 DOWNTO 0)											<= In_Data;
				END IF;
				
				IF (Length_en0 = '1') THEN
					Length_d(15 DOWNTO 8)												<= In_Data;
				END IF;
				IF (Length_en1 = '1') THEN
					Length_d(7 DOWNTO 0)												<= In_Data;
				END IF;
				
				IF (NextHeader_en = '1') THEN
					NextHeader_d																<= In_Data;
				END IF;
				
				IF (HopLimit_en = '1') THEN
					HopLimit_d																	<= In_Data;
				END IF;

				IF (SourceIPv6Address_en = '1') THEN
					SourceIPv6Address_d(to_integer(IPv6SeqCounter_us))	<= In_Data;
				END IF;
				
				IF (DestIPv6Address_en = '1') THEN
					DestIPv6Address_d(to_integer(IPv6SeqCounter_us))		<= In_Data;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR IPv6SeqCounter_rst) = '1') THEN
				IPv6SeqCounter_us			<= to_unsigned(IPV6_ADDRESS_LENGTH - 1, IPV6_ADDRESS_READER_BITS);
			ELSIF (IPv6SeqCounter_en = '1') THEN
				IPv6SeqCounter_us			<= IPv6SeqCounter_us - 1;
			END IF;
		END IF;
	END PROCESS;
	
	SrcIPv6Address_Reader_rst		<= Out_Meta_rst;
	SrcIPv6Address_Reader_en		<= Out_Meta_SrcIPv6Address_nxt;
	DestIPv6Address_Reader_rst	<= Out_Meta_rst;
	DestIPv6Address_Reader_en		<= Out_Meta_DestIPv6Address_nxt;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR SrcIPv6Address_Reader_rst) = '1') THEN
				SrcIPv6Address_Reader_us		<= to_unsigned(IPV6_ADDRESS_LENGTH - 1, IPV6_ADDRESS_READER_BITS);
			ELSIF (SrcIPv6Address_Reader_en = '1') THEN
				SrcIPv6Address_Reader_us		<= SrcIPv6Address_Reader_us - 1;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR DestIPv6Address_Reader_rst) = '1') THEN
				DestIPv6Address_Reader_us		<= to_unsigned(IPV6_ADDRESS_LENGTH - 1, IPV6_ADDRESS_READER_BITS);
			ELSIF (DestIPv6Address_Reader_en = '1') THEN
				DestIPv6Address_Reader_us		<= DestIPv6Address_Reader_us - 1;
			END IF;
		END IF;
	END PROCESS;
	
	In_Meta_rst												<= 'X';		-- FIXME: 
	In_Meta_SrcMACAddress_nxt					<= Out_Meta_SrcMACAddress_nxt;
	In_Meta_DestMACAddress_nxt				<= Out_Meta_DestMACAddress_nxt;

	Out_Valid													<= Out_Valid_i;
	Out_Data													<= In_Data;
	Out_SOF														<= Out_SOF_i;
	Out_EOF														<= Out_EOF_i;
	Out_Meta_SrcMACAddress_Data				<= In_Meta_SrcMACAddress_Data;
	Out_Meta_DestMACAddress_Data			<= In_Meta_DestMACAddress_Data;
	Out_Meta_EthType									<= In_Meta_EthType;
	Out_Meta_SrcIPv6Address_Data			<= SourceIPv6Address_d(to_integer(SrcIPv6Address_Reader_us));
	Out_Meta_DestIPv6Address_Data			<= DestIPv6Address_d(to_integer(DestIPv6Address_Reader_us));
	Out_Meta_TrafficClass							<= TrafficClass_d;
	Out_Meta_FlowLabel								<= "----" & FlowLabel_d;
	Out_Meta_Length										<= Length_d;
	Out_Meta_NextHeader								<= NextHeader_d;
	
END;
