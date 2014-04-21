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


ENTITY IPv4_TX IS
	GENERIC (
		DEBUG									: BOOLEAN													:= FALSE
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
		In_Meta_SrcIPv4Address_nxt			: OUT	STD_LOGIC;
		In_Meta_SrcIPv4Address_Data			: IN	T_SLV_8;
		In_Meta_DestIPv4Address_nxt			: OUT	STD_LOGIC;
		In_Meta_DestIPv4Address_Data		: IN	T_SLV_8;
		In_Meta_Length									: IN	T_SLV_16;
		In_Meta_Protocol								: IN	T_SLV_8;
		-- ARP port
		ARP_IPCache_Query								: OUT	STD_LOGIC;
		ARP_IPCache_IPv4Address_rst			: IN	STD_LOGIC;
		ARP_IPCache_IPv4Address_nxt			: IN	STD_LOGIC;
		ARP_IPCache_IPv4Address_Data		: OUT	T_SLV_8;
		ARP_IPCache_Valid								: IN	STD_LOGIC;
		ARP_IPCache_MACAddress_rst			: OUT	STD_LOGIC;
		ARP_IPCache_MACAddress_nxt			: OUT	STD_LOGIC;
		ARP_IPCache_MACAddress_Data			: IN	T_SLV_8;
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
-- Alignment: 4 byte
--
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+----------------+---------------+--------------------------------+--------------------------------+--------------------------------+
--	| IPVers. (0x4)	 | IHL (0x5)		 | TypeOfService									| TotalLength																											|
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

ARCHITECTURE rtl OF IPv4_TX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_ARP_QUERY,									ST_ARP_QUERY_WAIT,
			ST_CHECKSUM_IPV4_ADDRESSES,
				ST_CHECKSUM_IPVERSION_LENGTH_0,							ST_CHECKSUM_TYPE_OF_SERVICE_LENGTH_1,
				ST_CHECKSUM_IDENTIFICAION_FRAGMENTOFFSET_0,	ST_CHECKSUM_IDENTIFICAION_FRAGMENTOFFSET_1,
				ST_CHECKSUM_TIME_TO_LIVE,				ST_CHECKSUM_PROTOCOL,
			ST_CARRY_0, ST_CARRY_1,
			ST_SEND_VERSION,							ST_SEND_TYPE_OF_SERVICE,	ST_SEND_TOTAL_LENGTH_0,			ST_SEND_TOTAL_LENGTH_1,
			ST_SEND_IDENTIFICATION_0,			ST_SEND_IDENTIFICATION_1,	ST_SEND_FLAGS,							ST_SEND_FRAGMENT_OFFSET,
			ST_SEND_TIME_TO_LIVE,					ST_SEND_PROTOCOL,					ST_SEND_HEADER_CHECKSUM_0,	ST_SEND_HEADER_CHECKSUM_1,
			ST_SEND_SOURCE_ADDRESS,
			ST_SEND_DESTINATION_ADDRESS,
--			ST_SEND_OPTIONS_0,						ST_SEND_OPTIONS_1,				ST_SEND_OPTIONS_2,					ST_SEND_PADDING,
			ST_SEND_DATA,
		ST_DISCARD_FRAME,
		ST_ERROR
	);

	SIGNAL State											: T_STATE											:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL In_Ready_i									: STD_LOGIC;

	SIGNAL UpperLayerPacketLength			: STD_LOGIC_VECTOR(15 DOWNTO 0);

	SIGNAL InternetHeaderLength				: T_SLV_4;
	SIGNAL TypeOfService							: T_NET_IPV4_TYPE_OF_SERVICE;
	SIGNAL TotalLength								: T_SLV_16;
	SIGNAL Identification							: T_SLV_16;
	SIGNAL Flag_DontFragment					: STD_LOGIC;
	SIGNAL Flag_MoreFragments					: STD_LOGIC;
	SIGNAL FragmentOffset							: STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL TimeToLive									: T_SLV_8;
	SIGNAL Protocol										: T_SLV_8;
	SIGNAL HeaderChecksum							: T_SLV_16;

	SIGNAL IPv4SeqCounter_rst					: STD_LOGIC;
	SIGNAL IPv4SeqCounter_en					: STD_LOGIC;
	SIGNAL IPv4SeqCounter_us					: UNSIGNED(1 DOWNTO 0)				:= (OTHERS => '0');

	SIGNAL Checksum_rst								: STD_LOGIC;
	SIGNAL Checksum_en								: STD_LOGIC;
	SIGNAL Checksum_Addend0_us				: UNSIGNED(T_SLV_8'range);
	SIGNAL Checksum_Addend1_us				: UNSIGNED(T_SLV_8'range);
	SIGNAL Checksum0_nxt0_us					: UNSIGNED(T_SLV_8'high + 1 DOWNTO 0);
	SIGNAL Checksum0_nxt1_us					: UNSIGNED(T_SLV_8'high + 1 DOWNTO 0);
	SIGNAL Checksum0_d_us							: UNSIGNED(T_SLV_8'high DOWNTO 0)												:= (OTHERS => '0');
	SIGNAL Checksum0_cy								: UNSIGNED(T_SLV_2'range);
	SIGNAL Checksum1_nxt_us						: UNSIGNED(T_SLV_8'range);
	SIGNAL Checksum1_d_us							: UNSIGNED(T_SLV_8'range)																:= (OTHERS => '0');
	SIGNAL Checksum0_cy0							: STD_LOGIC;
	SIGNAL Checksum0_cy0_d						: STD_LOGIC																							:= '0';
	SIGNAL Checksum0_cy1							: STD_LOGIC;
	SIGNAL Checksum0_cy1_d						: STD_LOGIC																							:= '0';

	SIGNAL Checksum_i									: T_SLV_16;
	SIGNAL Checksum										: T_SLV_16;
	SIGNAL Checksum_mux_rst						: STD_LOGIC;
	SIGNAL Checksum_mux_set						: STD_LOGIC;
	SIGNAL Checksum_mux_r							: STD_LOGIC																							:= '0';

BEGIN

	UpperLayerPacketLength	<= std_logic_vector(unsigned(In_Meta_Length) + 20);

	InternetHeaderLength		<= x"5";											-- standard IPv4 header length withou option fields (20 bytes -> 5 * 32-words)
	TypeOfService						<= C_NET_IPV4_TOS_DEFAULT;		-- Type of Service: routine, normal delay, normal throughput, normal relibility
	TotalLength							<= UpperLayerPacketLength;
	Identification					<= x"0000";
	Flag_DontFragment				<= '0';
	Flag_MoreFragments			<= '0';
	FragmentOffset					<= (OTHERS => '0');
	TimeToLive							<= x"40";											-- TTL = 64; see RFC 791
	Protocol								<= In_Meta_Protocol;
	
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
					Out_Ready, Out_Meta_rst, Out_Meta_DestMACAddress_nxt,
					ARP_IPCache_Valid, ARP_IPCache_IPv4Address_rst, ARP_IPCache_IPv4Address_nxt, ARP_IPCache_MACAddress_Data,
					In_Meta_DestIPv4Address_Data, In_Meta_SrcIPv4Address_Data, In_Meta_Protocol,
					InternetHeaderLength, UpperLayerPacketLength, TypeOfService, Flag_DontFragment, Flag_MoreFragments,
					Identification, FragmentOffset, TimeToLive, Protocol,
					IPv4SeqCounter_us, Checksum0_cy, Checksum)
	BEGIN
		NextState													<= State;
		
		In_Ready_i												<= '0';
		
		Out_Valid													<= '0';
		Out_Data													<= (OTHERS => '0');
		Out_SOF														<= '0';
		Out_EOF														<= '0';

		In_Meta_rst												<= '0';

		ARP_IPCache_Query									<= '0';
		In_Meta_SrcIPv4Address_nxt				<= '0';
		In_Meta_DestIPv4Address_nxt				<= '0';
		ARP_IPCache_IPv4Address_Data			<= In_Meta_DestIPv4Address_Data;
		
		ARP_IPCache_MACAddress_rst				<= Out_Meta_rst;
		ARP_IPCache_MACAddress_nxt				<= Out_Meta_DestMACAddress_nxt;
		Out_Meta_DestMACAddress_Data			<= ARP_IPCache_MACAddress_Data;

		IPv4SeqCounter_rst								<= '0';
		IPv4SeqCounter_en									<= '0';

		Checksum_rst											<= '0';
		Checksum_en												<= '0';
		Checksum_Addend0_us								<= (OTHERS => '0');
		Checksum_Addend1_us								<= (OTHERS => '0');
		Checksum_mux_rst									<= '0';
		Checksum_mux_set									<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				In_Meta_rst										<= ARP_IPCache_IPv4Address_rst;
				In_Meta_DestIPv4Address_nxt		<= ARP_IPCache_IPv4Address_nxt;
				
				IPv4SeqCounter_rst						<= '1';
				Checksum_rst									<= '1';
				
				IF ((In_Valid AND In_SOF) = '1') THEN
					NextState										<= ST_ARP_QUERY;
				END IF;
			
			WHEN ST_ARP_QUERY =>
				Out_Data											<= x"4" & InternetHeaderLength;
				Out_SOF												<= '1';

				In_Meta_rst										<= ARP_IPCache_IPv4Address_rst;
				In_Meta_DestIPv4Address_nxt		<= ARP_IPCache_IPv4Address_nxt;

				ARP_IPCache_Query							<= '1';
				
				IF (ARP_IPCache_Valid = '1') THEN
					Out_Valid										<= '1';
					In_Meta_rst									<= '1';		-- reset metadata
					
--					IF (Out_Ready = '1') THEN
--						NextState									<= ST_SEND_TYPE_OF_SERVICE;
--					ELSE
--						NextState									<= ST_SEND_VERSION;
--					END IF;
					NextState										<= ST_CHECKSUM_IPV4_ADDRESSES;
				ELSE
					NextState										<= ST_ARP_QUERY_WAIT;
				END IF;
			
			WHEN ST_ARP_QUERY_WAIT =>
				Out_Valid											<= '0';
				Out_Data											<= x"4" & InternetHeaderLength;
				Out_SOF												<= '1';
			
				In_Meta_rst										<= ARP_IPCache_IPv4Address_rst;
				In_Meta_DestIPv4Address_nxt		<= ARP_IPCache_IPv4Address_nxt;
			
				IF (ARP_IPCache_Valid = '1') THEN
					Out_Valid										<= '1';
					In_Meta_rst									<= '1';		-- reset metadata
					
--					IF (Out_Ready = '1') THEN
--						NextState									<= ST_SEND_TYPE_OF_SERVICE;
--					ELSE
--						NextState									<= ST_SEND_VERSION;
--					END IF;
					NextState										<= ST_CHECKSUM_IPV4_ADDRESSES;
				END IF;
			
			-- calculate checksum for IPv4 header
			-- ----------------------------------------------------------------------
			WHEN ST_CHECKSUM_IPV4_ADDRESSES =>
				In_Meta_SrcIPv4Address_nxt		<= '1';
				In_Meta_DestIPv4Address_nxt		<= '1';
				
				IPv4SeqCounter_en							<= '1';
				Checksum_en										<= '1';
				Checksum_Addend0_us						<= unsigned(In_Meta_SrcIPv4Address_Data);
				Checksum_Addend1_us						<= unsigned(In_Meta_DestIPv4Address_Data);
				
				IF (IPv4SeqCounter_us = 3) THEN
					NextState										<= ST_CHECKSUM_IPVERSION_LENGTH_0;
				END IF;
			
			WHEN ST_CHECKSUM_IPVERSION_LENGTH_0 =>
				Checksum_en										<= '1';
				Checksum_Addend0_us						<= unsigned(UpperLayerPacketLength(15 DOWNTO 8));
				Checksum_Addend1_us						<= unsigned(std_logic_vector'(x"4" & InternetHeaderLength));
				
				NextState											<= ST_CHECKSUM_TYPE_OF_SERVICE_LENGTH_1;

			WHEN ST_CHECKSUM_TYPE_OF_SERVICE_LENGTH_1 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(UpperLayerPacketLength(7 DOWNTO 0));
				Checksum_Addend1_us				<= unsigned(to_slv(TypeOfService));
			
				NextState									<= ST_CHECKSUM_IDENTIFICAION_FRAGMENTOFFSET_0;

			WHEN ST_CHECKSUM_IDENTIFICAION_FRAGMENTOFFSET_0 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(Identification(15 DOWNTO 8));
				Checksum_Addend1_us				<= unsigned(std_logic_vector'('0' & Flag_DontFragment & Flag_MoreFragments & FragmentOffset(12 DOWNTO 8)));
			
				NextState									<= ST_CHECKSUM_IDENTIFICAION_FRAGMENTOFFSET_1;

			WHEN ST_CHECKSUM_IDENTIFICAION_FRAGMENTOFFSET_1 =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(Identification(7 DOWNTO 0));
				Checksum_Addend1_us				<= unsigned(FragmentOffset(7 DOWNTO 0));
				
				NextState									<= ST_CHECKSUM_TIME_TO_LIVE;
			
			WHEN ST_CHECKSUM_TIME_TO_LIVE =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(TimeToLive);
				Checksum_Addend1_us				<= (OTHERS => '0');	--unsigned(In_Meta_Checksum(15 DOWNTO 8));
				
				NextState									<= ST_CHECKSUM_PROTOCOL;

			WHEN ST_CHECKSUM_PROTOCOL =>
				Checksum_en								<= '1';
				Checksum_Addend0_us				<= unsigned(Protocol);
				Checksum_Addend1_us				<= (OTHERS => '0');	--unsigned(In_Meta_Checksum(7 DOWNTO 0));
			
				IF (Checksum0_cy = "00") THEN
					NextState								<= ST_SEND_VERSION;
				ELSE
					NextState								<= ST_CARRY_0;
				END IF;
				
			-- circulate carry bit
			-- ----------------------------------------------------------------------
			WHEN ST_CARRY_0 =>
				In_Meta_rst								<= Out_Meta_rst;
				
				Checksum_en								<= '1';
				Checksum_mux_set					<= '1';
				
				IF (Checksum0_cy = "00") THEN
					NextState								<= ST_SEND_VERSION;
				ELSE
					NextState								<= ST_CARRY_1;
				END IF;
			
			WHEN ST_CARRY_1 =>
				In_Meta_rst								<= Out_Meta_rst;
			
				Checksum_en								<= '1';
				Checksum_mux_rst					<= '1';
				
				NextState									<= ST_SEND_VERSION;
				
			-- assamble header
			-- ----------------------------------------------------------------------
			WHEN ST_SEND_VERSION =>
				Out_Valid											<= '1';
				Out_Data											<= x"4" & InternetHeaderLength;
				Out_SOF												<= '1';

				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_TYPE_OF_SERVICE;
				END IF;
			
			WHEN ST_SEND_TYPE_OF_SERVICE =>
				Out_Valid											<= '1';
				Out_Data											<= to_slv(TypeOfService);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_TOTAL_LENGTH_0;
				END IF;

			WHEN ST_SEND_TOTAL_LENGTH_0 =>
				Out_Valid											<= '1';
				Out_Data											<= std_logic_vector(TotalLength(15 DOWNTO 8));
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_TOTAL_LENGTH_1;
				END IF;
				
			WHEN ST_SEND_TOTAL_LENGTH_1 =>
				Out_Valid											<= '1';
				Out_Data											<= std_logic_vector(TotalLength(7 DOWNTO 0));
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_IDENTIFICATION_0;
				END IF;
				
			WHEN ST_SEND_IDENTIFICATION_0 =>
				Out_Valid											<= '1';
				Out_Data											<= Identification(15 DOWNTO 8);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_IDENTIFICATION_1;
				END IF;
				
			WHEN ST_SEND_IDENTIFICATION_1 =>
				Out_Valid											<= '1';
				Out_Data											<= Identification(7 DOWNTO 0);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_FLAGS;
				END IF;
				
			WHEN ST_SEND_FLAGS =>
				Out_Valid											<= '1';
				Out_Data(7)										<= '0';
				Out_Data(6)										<= Flag_DontFragment;
				Out_Data(5)										<= Flag_MoreFragments;
				Out_Data(4 DOWNTO 0)					<= FragmentOffset(12 DOWNTO 8);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_FRAGMENT_OFFSET;
				END IF;
			
			WHEN ST_SEND_FRAGMENT_OFFSET =>
				Out_Valid											<= '1';
				Out_Data											<= FragmentOffset(7 DOWNTO 0);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_TIME_TO_LIVE;
				END IF;
				
			WHEN ST_SEND_TIME_TO_LIVE =>
				Out_Valid											<= '1';
				Out_Data											<= TimeToLive;
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_PROTOCOL;
				END IF;
				
			WHEN ST_SEND_PROTOCOL =>
				Out_Valid											<= '1';
				Out_Data											<= Protocol;
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_HEADER_CHECKSUM_0;
				END IF;
				
			WHEN ST_SEND_HEADER_CHECKSUM_0 =>
				Out_Valid											<= '1';
				Out_Data											<= Checksum(15 DOWNTO 8);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_HEADER_CHECKSUM_1;
				END IF;

			WHEN ST_SEND_HEADER_CHECKSUM_1 =>
				Out_Valid											<= '1';
				Out_Data											<= Checksum(7 DOWNTO 0);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_SOURCE_ADDRESS;
				END IF;
			
			WHEN ST_SEND_SOURCE_ADDRESS =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_SrcIPv4Address_Data;
				
				IF (Out_Ready = '1') THEN
					In_Meta_SrcIPv4Address_nxt	<= '1';
					IPv4SeqCounter_en						<= '1';
				
					IF (IPv4SeqCounter_us = 3) THEN
						NextState									<= ST_SEND_DESTINATION_ADDRESS;
					END IF;
				END IF;
			
			WHEN ST_SEND_DESTINATION_ADDRESS =>
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_DestIPv4Address_Data;
				
				IF (Out_Ready = '1') THEN
					In_Meta_DestIPv4Address_nxt	<= '1';
					IPv4SeqCounter_en						<= '1';
				
					IF (IPv4SeqCounter_us = 3) THEN
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
			IF ((Reset OR IPv4SeqCounter_rst) = '1') THEN
				IPv4SeqCounter_us			<= (OTHERS => '0');
			ELSE
				IF (IPv4SeqCounter_en = '1') THEN
					IPv4SeqCounter_us		<= IPv4SeqCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

Checksum0_nxt0_us		<= ("0" & Checksum1_d_us)
													+ ("0" & Checksum_Addend0_us)
													+ ((Checksum_Addend0_us'range => '0') & Checksum0_cy0_d);
	Checksum0_nxt1_us		<= ("0" & Checksum0_nxt0_us(Checksum0_nxt0_us'high - 1 DOWNTO 0))
													+ ("0" & Checksum_Addend1_us)
													+ ((Checksum_Addend1_us'range => '0') & Checksum0_cy1_d);
	Checksum1_nxt_us		<= Checksum0_d_us(Checksum1_d_us'range);
	
	Checksum0_cy0				<= Checksum0_nxt0_us(Checksum0_nxt0_us'high);
	Checksum0_cy1				<= Checksum0_nxt1_us(Checksum0_nxt1_us'high);
	Checksum0_cy				<= Checksum0_cy1 & Checksum0_cy0;

					
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Checksum_rst = '1') THEN
				Checksum0_d_us			<= (OTHERS => '0');
				Checksum1_d_us			<= (OTHERS => '0');
			ELSE
				IF (Checksum_en = '1') THEN
					Checksum0_d_us		<= Checksum0_nxt1_us(Checksum0_nxt1_us'high - 1 DOWNTO 0);
					Checksum1_d_us		<= Checksum1_nxt_us;
					
					Checksum0_cy0_d		<= Checksum0_cy0;
					Checksum0_cy1_d		<= Checksum0_cy1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Checksum_i		<= not (std_logic_vector(Checksum0_nxt1_us(Checksum0_nxt1_us'high - 1 DOWNTO 0)) & std_logic_vector(Checksum1_nxt_us));
	Checksum			<= ite((Checksum_mux_r = '0'), Checksum_i, swap(Checksum_i, 8));

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Checksum_mux_rst) = '1') THEN
				Checksum_mux_r		<= '0';
			ELSIF (Checksum_mux_set = '1') THEN
				Checksum_mux_r		<= '1';
			END IF;
		END IF;
	END PROCESS;

	In_Ready												<= In_Ready_i;
END;