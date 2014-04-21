LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;


ENTITY IPv4_RX IS
	GENERIC (
		DEBUG									: BOOLEAN													:= FALSE
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
		Out_Meta_SrcIPv4Address_nxt			: IN	STD_LOGIC;
		Out_Meta_SrcIPv4Address_Data		: OUT	T_SLV_8;
		Out_Meta_DestIPv4Address_nxt		: IN	STD_LOGIC;
		Out_Meta_DestIPv4Address_Data		: OUT	T_SLV_8;
		Out_Meta_Length									: OUT	T_SLV_16;
		Out_Meta_Protocol								: OUT	T_SLV_8
	);
END;

-- Endianess: big-endian
-- Alignment: 4 byte
--
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+----------------+---------------+--------------------------------+--------------------------------+--------------------------------+
--	| IPVers. (0x04) | IHL(HeaderLen)| TypeOfService									| TotalLength																											|
--	+----------------+---------------+--------------------------------+-------+------------------------+--------------------------------+
--	| Identification																									|R DF MF| FragmentOffset																					|
--	+--------------------------------+--------------------------------+-------+------------------------+--------------------------------+
--	| TimeToLive										 | Protocol												| HeaderChecksum																									|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| SourceAddress																																																											|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| DestinationAddress																																																								|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| Options																																													 | Padding												|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| Payload																																																														|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+


ARCHITECTURE rtl OF IPv4_RX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
																		ST_RECEIVE_TYPE_OF_SERVICE,		ST_RECEIVE_TOTAL_LENGTH_0,		ST_RECEIVE_TOTAL_LENGTH_1,
			ST_RECEIVE_IDENTIFICATION_0,	ST_RECEIVE_IDENTIFICATION_1,	ST_RECEIVE_FLAGS,							ST_RECEIVE_FRAGMENT_OFFSET_1,
			ST_RECEIVE_TIME_TO_LIVE,			ST_RECEIVE_PROTOCOL,					ST_RECEIVE_HEADER_CHECKSUM_0,	ST_RECEIVE_HEADER_CHECKSUM_1,
			ST_RECEIVE_SOURCE_ADDRESS,
			ST_RECEIVE_DESTINATION_ADDRESS,
--			ST_RECEIVE_OPTIONS,
			ST_RECEIVE_DATA_1,						ST_RECEIVE_DATA_N,
		ST_DISCARD_FRAME,
		ST_ERROR
	);

	SIGNAL State													: T_STATE											:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State				: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL In_Ready_i											: STD_LOGIC;
	SIGNAL Is_DataFlow										: STD_LOGIC;
	SIGNAL Is_SOF													: STD_LOGIC;
	SIGNAL Is_EOF													: STD_LOGIC;

	SIGNAL Out_Valid_i										: STD_LOGIC;
	SIGNAL Out_SOF_i											: STD_LOGIC;
	SIGNAL Out_EOF_i											: STD_LOGIC;

	SUBTYPE T_IPV4_BYTEINDEX	 						IS NATURAL RANGE 0 TO 3;
	SIGNAL IP_ByteIndex										: T_IPV4_BYTEINDEX;

	SIGNAL Register_rst										: STD_LOGIC;
	
	-- IPv4 Basic Header
	SIGNAL HeaderLength_en								: STD_LOGIC;
	SIGNAL TypeOfService_en								: STD_LOGIC;
	SIGNAL TotalLength_en0								: STD_LOGIC;
	SIGNAL TotalLength_en1								: STD_LOGIC;
--	SIGNAL Identification_en0							: STD_LOGIC;
--	SIGNAL Identification_en1							: STD_LOGIC;
	SIGNAL Flags_en												: STD_LOGIC;
--	SIGNAL FragmentOffset_en0							: STD_LOGIC;
--	SIGNAL FragmentOffset_en1							: STD_LOGIC;
	SIGNAL TimeToLive_en									: STD_LOGIC;
	SIGNAL Protocol_en										: STD_LOGIC;
	SIGNAL HeaderChecksum_en0							: STD_LOGIC;
	SIGNAL HeaderChecksum_en1							: STD_LOGIC;
	SIGNAL SourceIPv4Address_en						: STD_LOGIC;
	SIGNAL DestIPv4Address_en							: STD_LOGIC;
	
	SIGNAL HeaderLength_d									: T_SLV_4													:= (OTHERS => '0');
	SIGNAL TypeOfService_d								: T_SLV_8													:= (OTHERS => '0');
	SIGNAL TotalLength_d									: T_SLV_16												:= (OTHERS => '0');
--	SIGNAL Identification_d								: T_SLV_16												:= (OTHERS => '0');
	SIGNAL Flag_DontFragment_d						: STD_LOGIC												:= '0';
	SIGNAL Flag_MoreFragmenta_d						: STD_LOGIC												:= '0';
--	SIGNAL FragmentOffset_d								: STD_LOGIC_VECTOR(12 DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL TimeToLive_d										: T_SLV_8													:= (OTHERS => '0');
	SIGNAL Protocol_d											: T_SLV_8													:= (OTHERS => '0');
	SIGNAL HeaderChecksum_d								: T_SLV_16												:= (OTHERS => '0');
	SIGNAL SourceIPv4Address_d						: T_NET_IPV4_ADDRESS							:= (OTHERS => (OTHERS => '0'));
	SIGNAL DestIPv4Address_d							: T_NET_IPV4_ADDRESS							:= (OTHERS => (OTHERS => '0'));

	CONSTANT IPV4_ADDRESS_LENGTH					: POSITIVE												:= 4;			-- IPv4 -> 4 bytes
	CONSTANT IPV4_ADDRESS_READER_BITS			: POSITIVE												:= log2ceilnz(IPV4_ADDRESS_LENGTH);

	SIGNAL IPv4SeqCounter_rst							: STD_LOGIC;
	SIGNAL IPv4SeqCounter_en							: STD_LOGIC;
	SIGNAL IPv4SeqCounter_us							: UNSIGNED(IPV4_ADDRESS_READER_BITS - 1 DOWNTO 0)		:= to_unsigned(IPV4_ADDRESS_LENGTH - 1, IPV4_ADDRESS_READER_BITS);

	SIGNAL SrcIPv4Address_Reader_rst			: STD_LOGIC;
	SIGNAL SrcIPv4Address_Reader_en				: STD_LOGIC;
	SIGNAL SrcIPv4Address_Reader_us				: UNSIGNED(IPV4_ADDRESS_READER_BITS - 1 DOWNTO 0)		:= to_unsigned(IPV4_ADDRESS_LENGTH - 1, IPV4_ADDRESS_READER_BITS);
	SIGNAL DestIPv4Address_Reader_rst			: STD_LOGIC;
	SIGNAL DestIPv4Address_Reader_en			: STD_LOGIC;
	SIGNAL DestIPv4Address_Reader_us			: UNSIGNED(IPV4_ADDRESS_READER_BITS - 1 DOWNTO 0)		:= to_unsigned(IPV4_ADDRESS_LENGTH - 1, IPV4_ADDRESS_READER_BITS);

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

	PROCESS(State, Is_DataFlow, Is_SOF, Is_EOF, In_Valid, In_Data, In_EOF, IPv4SeqCounter_us, Out_Ready)
	BEGIN
		NextState									<= State;

		Error											<= '0';
		
		In_Ready_i								<= '0';
		Out_Valid_i								<= '0';
		Out_SOF_i									<= '0';
		Out_EOF_i									<= In_EOF;

		IPv4SeqCounter_rst				<= '0';
		IPv4SeqCounter_en					<= '0';

		-- IPv4 Basic Header
		Register_rst							<= '0';
		HeaderLength_en						<= '0';
		TypeOfService_en					<= '0';
		TotalLength_en0						<= '0';
		TotalLength_en1						<= '0';
--		Identification_en0				<= '0';
--		Identification_en1				<= '0';
		Flags_en									<= '0';
--		FragmentOffset_en0				<= '0';
--		FragmentOffset_en1				<= '0';
		TimeToLive_en							<= '0';
		Protocol_en								<= '0';
		HeaderChecksum_en0				<= '0';
		HeaderChecksum_en1				<= '0';
		SourceIPv4Address_en			<= '0';
		DestIPv4Address_en				<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				IF (Is_SOF = '1') THEN
					In_Ready_i						<= '1';
				
					IF (Is_EOF = '0') THEN
						IF (In_Data(3 DOWNTO 0) = x"4") THEN
							HeaderLength_en		<= '1';
							NextState					<= ST_RECEIVE_TYPE_OF_SERVICE;
						ELSE
							NextState					<= ST_DISCARD_FRAME;
						END IF;
					ELSE  -- EOF
						NextState						<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_TYPE_OF_SERVICE =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						TypeOfService_en			<= '1';
						NextState							<= ST_RECEIVE_TOTAL_LENGTH_0;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_TOTAL_LENGTH_0 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						TotalLength_en0				<= '1';
						NextState							<= ST_RECEIVE_TOTAL_LENGTH_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_TOTAL_LENGTH_1 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						TotalLength_en1				<= '1';
						NextState							<= ST_RECEIVE_IDENTIFICATION_0;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_IDENTIFICATION_0 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
--						Identification_en0		<= '1';
						NextState							<= ST_RECEIVE_IDENTIFICATION_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_IDENTIFICATION_1 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
--						Identification_en1		<= '1';
						NextState							<= ST_RECEIVE_FLAGS;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_FLAGS =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						Flags_en							<= '1';
--						FragmentOffset_en0		<= '1';
						NextState							<= ST_RECEIVE_FRAGMENT_OFFSET_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_FRAGMENT_OFFSET_1 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
--						FragmentOffset_en1		<= '1';
						NextState							<= ST_RECEIVE_TIME_TO_LIVE;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_TIME_TO_LIVE =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						TimeToLive_en					<= '1';
						NextState							<= ST_RECEIVE_PROTOCOL;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_PROTOCOL =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						Protocol_en						<= '1';
						NextState							<= ST_RECEIVE_HEADER_CHECKSUM_0;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;

			WHEN ST_RECEIVE_HEADER_CHECKSUM_0 =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						HeaderChecksum_en0		<= '1';
						NextState							<= ST_RECEIVE_HEADER_CHECKSUM_1;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;

			WHEN ST_RECEIVE_HEADER_CHECKSUM_1 =>
				IPv4SeqCounter_rst				<= '1';
				
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					IF (Is_EOF = '0') THEN
						HeaderChecksum_en1		<= '1';
						NextState							<= ST_RECEIVE_SOURCE_ADDRESS;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_SOURCE_ADDRESS =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					SourceIPv4Address_en		<= '1';
					IPv4SeqCounter_en				<= '1';
					
					IF (Is_EOF = '0') THEN
						IF (IPv4SeqCounter_us = 0) THEN
							IPv4SeqCounter_rst	<= '1';
							NextState						<= ST_RECEIVE_DESTINATION_ADDRESS;
						END IF;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_DESTINATION_ADDRESS =>
				IF (In_Valid = '1') THEN
					In_Ready_i							<= '1';
					
					DestIPv4Address_en			<= '1';
					IPv4SeqCounter_en				<= '1';
					
					IF (Is_EOF = '0') THEN
						IF (IPv4SeqCounter_us = 0) THEN
							IPv4SeqCounter_rst	<= '1';
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
				HeaderLength_d						<= (OTHERS => '0');
				TypeOfService_d						<= (OTHERS => '0');
				TotalLength_d							<= (OTHERS => '0');
--				Identification_d					<= (OTHERS => '0');
				Flag_DontFragment_d				<= '0';
				Flag_MoreFragmenta_d			<= '0';
--				FragmentOffset_d					<= (OTHERS => '0');
				TimeToLive_d							<= (OTHERS => '0');
				Protocol_d								<= (OTHERS => '0');
				HeaderChecksum_d					<= (OTHERS => '0');
				SourceIPv4Address_d				<= (OTHERS => (OTHERS => '0'));
				DestIPv4Address_d					<= (OTHERS => (OTHERS => '0'));
			ELSE
				IF (HeaderLength_en = '1') THEN
					HeaderLength_d									<= In_Data(3 DOWNTO 0);
				END IF;
				
				IF (TypeOfService_en = '1') THEN
					TypeOfService_d									<= In_Data;
				END IF;
				
				IF (TotalLength_en0 = '1') THEN
					TotalLength_d(15 DOWNTO 8)			<= In_Data;
				END IF;
				IF (TotalLength_en1 = '1') THEN
					TotalLength_d(7 DOWNTO 0)				<= In_Data;
				END IF;
				
--				IF (Identification_en0 = '1') THEN
--					Identification_d(15 DOWNTO 8)		<= In_Data;
--				END IF;
--				IF (Identification_en1 = '1') THEN
--					Identification_d(7 DOWNTO 0)		<= In_Data;
--				END IF;
				
				IF (Flags_en = '1') THEN
					Flag_DontFragment_d							<= In_Data(6);
					Flag_MoreFragmenta_d						<= In_Data(5);
				END IF;
				
--				IF (FragmentOffset_en0 = '1') THEN
--					FragmentOffset_d(12 DOWNTO 8)		<= In_Data(4 DOWNTO 0);
--				END IF;
--				IF (FragmentOffset_en1 = '1') THEN
--					FragmentOffset_d(7 DOWNTO 0)		<= In_Data;
--				END IF;

				IF (TimeToLive_en = '1') THEN
					TimeToLive_d										<= In_Data;
				END IF;
				
				IF (Protocol_en = '1') THEN
					Protocol_d											<= In_Data;
				END IF;

				IF (HeaderChecksum_en0 = '1') THEN
					HeaderChecksum_d(15 DOWNTO 8)		<= In_Data;
				END IF;
				IF (HeaderChecksum_en1 = '1') THEN
					HeaderChecksum_d(7 DOWNTO 0)		<= In_Data;
				END IF;

				IF (SourceIPv4Address_en = '1') THEN
					SourceIPv4Address_d(to_integer(IPv4SeqCounter_us))	<= In_Data;
				END IF;
				
				IF (DestIPv4Address_en = '1') THEN
					DestIPv4Address_d(to_integer(IPv4SeqCounter_us))		<= In_Data;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR IPv4SeqCounter_rst) = '1') THEN
				IPv4SeqCounter_us				<= to_unsigned(IPV4_ADDRESS_LENGTH - 1, IPV4_ADDRESS_READER_BITS);
			ELSIF (IPv4SeqCounter_en = '1') THEN
				IPv4SeqCounter_us			<= IPv4SeqCounter_us - 1;
			END IF;
		END IF;
	END PROCESS;
	
	SrcIPv4Address_Reader_rst		<= Out_Meta_rst;
	SrcIPv4Address_Reader_en		<= Out_Meta_SrcIPv4Address_nxt;
	DestIPv4Address_Reader_rst	<= Out_Meta_rst;
	DestIPv4Address_Reader_en		<= Out_Meta_DestIPv4Address_nxt;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR SrcIPv4Address_Reader_rst) = '1') THEN
				SrcIPv4Address_Reader_us		<= to_unsigned(IPV4_ADDRESS_LENGTH - 1, IPV4_ADDRESS_READER_BITS);
			ELSIF (SrcIPv4Address_Reader_en = '1') THEN
				SrcIPv4Address_Reader_us		<= SrcIPv4Address_Reader_us - 1;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR DestIPv4Address_Reader_rst) = '1') THEN
				DestIPv4Address_Reader_us		<= to_unsigned(IPV4_ADDRESS_LENGTH - 1, IPV4_ADDRESS_READER_BITS);
			ELSIF (DestIPv4Address_Reader_en = '1') THEN
				DestIPv4Address_Reader_us		<= DestIPv4Address_Reader_us - 1;
			END IF;
		END IF;
	END PROCESS;
	
	In_Meta_rst												<= Out_Meta_rst;
	In_Meta_SrcMACAddress_nxt					<= Out_Meta_SrcMACAddress_nxt;
	In_Meta_DestMACAddress_nxt				<= Out_Meta_DestMACAddress_nxt;

	Out_Valid													<= Out_Valid_i;
	Out_Data													<= In_Data;
	Out_SOF														<= Out_SOF_i;
	Out_EOF														<= Out_EOF_i;
	Out_Meta_SrcMACAddress_Data				<= In_Meta_SrcMACAddress_Data;
	Out_Meta_DestMACAddress_Data			<= In_Meta_DestMACAddress_Data;
	Out_Meta_EthType									<= In_Meta_EthType;
	Out_Meta_SrcIPv4Address_Data			<= SourceIPv4Address_d(to_integer(SrcIPv4Address_Reader_us));
	Out_Meta_DestIPv4Address_Data			<= DestIPv4Address_d(to_integer(DestIPv4Address_Reader_us));
	Out_Meta_Length										<= TotalLength_d;
	Out_Meta_Protocol									<= Protocol_d;
	
END;
