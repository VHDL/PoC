LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY ARP_BroadCast_Receiver IS
	GENERIC (
		ALLOWED_PROTOCOL_IPV4				: BOOLEAN												:= TRUE;
		ALLOWED_PROTOCOL_IPV6				: BOOLEAN												:= FALSE
	);
	PORT (
		Clock												: IN	STD_LOGIC;																	-- 
		Reset												: IN	STD_LOGIC;																	-- 
		
		RX_Valid										: IN	STD_LOGIC;
		RX_Data											: IN	T_SLV_8;
		RX_SOF											: IN	STD_LOGIC;
		RX_EOF											: IN	STD_LOGIC;
		RX_Ready										: OUT	STD_LOGIC;
		RX_Meta_rst									: OUT	STD_LOGIC;
		RX_Meta_SrcMACAddress_nxt		: OUT	STD_LOGIC;
		RX_Meta_SrcMACAddress_Data	: IN	T_SLV_8;
		RX_Meta_DestMACAddress_nxt	: OUT	STD_LOGIC;
		RX_Meta_DestMACAddress_Data	: IN	T_SLV_8;
		
		Clear												: IN	STD_LOGIC;
		Error												: OUT STD_LOGIC;
		
		RequestReceived							: OUT	STD_LOGIC;
		Address_rst									: IN	STD_LOGIC;
		SenderMACAddress_nxt				: IN	STD_LOGIC;
		SenderMACAddress_Data				: OUT	T_SLV_8;
		SenderIPAddress_nxt					: IN	STD_LOGIC;
		SenderIPAddress_Data				: OUT	T_SLV_8;
		TargetIPAddress_nxt					: IN	STD_LOGIC;
		TargetIPAddress_Data				: OUT	T_SLV_8
	);
END;

-- Endianess: big-endian
-- Alignment: 1 byte
--
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| HardwareType (Ethernet = 0x0001)																| ProtocolType (IPv4 = 0x0800; IPv6 = 0x86DD)											|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| Hardware_Length (= 0x06)			 | Protocol_Length (= 0x04; 0x10) | Operation (Request = 0x0001)																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| SenderMACAddress																																																									|
--	+                                +                                +--------------------------------+--------------------------------+
--	|																																	| SenderIPAddress																									|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	|																																	| TargetMACAddress (= 00:00:00:00:00:00)													|
--	+--------------------------------+--------------------------------+                                +                                +
--	|																																																																		|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| TargetIPAddress																																																										|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+

ARCHITECTURE rtl OF ARP_BroadCast_Receiver IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
																	ST_RECEIVE_HARDWARE_TYPE_1,
			ST_RECEIVE_PROTOCOL_TYPE_0, ST_RECEIVE_PROTOCOL_TYPE_1,
			ST_RECEIVE_HARDWARE_ADDRESS_LENGTH, ST_RECEIVE_PROTOCOL_ADDRESS_LENGTH,
			ST_RECEIVE_OPERATION_0,			ST_RECEIVE_OPERATION_1,
			ST_RECEIVE_SENDER_MAC,			ST_RECEIVE_SENDER_IP,
			ST_RECEIVE_TARGET_MAC,			ST_RECEIVE_TARGET_IP,
		ST_DISCARD_ETHERNET_PADDING_BYTES,
		ST_COMPLETE,
		ST_DISCARD_FRAME, ST_ERROR
	);

	SIGNAL State													: T_STATE																												:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State				: SIGNAL IS "gray";		--"speed1";

	SIGNAL Is_SOF													: STD_LOGIC;
	SIGNAL Is_EOF													: STD_LOGIC;

	CONSTANT HARDWARE_ADDRESS_LENGTH			: POSITIVE																											:= 6;			-- MAC -> 6 bytes
	CONSTANT PROTOCOL_IPV4_ADDRESS_LENGTH	: POSITIVE																											:= 4;			-- IPv4 -> 4 bytes
	CONSTANT PROTOCOL_IPV6_ADDRESS_LENGTH	: POSITIVE																											:= 16;		-- IPv6 -> 16 bytes
	CONSTANT PROTOCOL_ADDRESS_LENGTH			: POSITIVE																											:= ite((ALLOWED_PROTOCOL_IPV6 = FALSE), PROTOCOL_IPV4_ADDRESS_LENGTH, PROTOCOL_IPV6_ADDRESS_LENGTH);		-- IPv4 -> 4 bytes; IPv6 -> 16 bytes

	SUBTYPE T_HARDWARE_ADDRESS_INDEX			 IS NATURAL RANGE 0 TO HARDWARE_ADDRESS_LENGTH - 1;
	SUBTYPE T_PROTOCOL_ADDRESS_INDEX			 IS NATURAL RANGE 0 TO PROTOCOL_ADDRESS_LENGTH - 1;

	SIGNAL IsIPv4_set											: STD_LOGIC;
	SIGNAL IsIPv4_r												: STD_LOGIC																											:= '0';
	SIGNAL IsIPv6_set											: STD_LOGIC;
	SIGNAL IsIPv6_r												: STD_LOGIC																											:= '0';


	CONSTANT WRITER_COUNTER_BITS					: POSITIVE																											:= log2ceilnz(imax(HARDWARE_ADDRESS_LENGTH, PROTOCOL_ADDRESS_LENGTH));
	SIGNAL Writer_Counter_rst							: STD_LOGIC;
	SIGNAL Writer_Counter_en							: STD_LOGIC;
	SIGNAL Writer_Counter_us							: UNSIGNED(WRITER_COUNTER_BITS - 1 DOWNTO 0)										:= (OTHERS => '0');

	SIGNAL Reader_SenderMAC_Counter_rst		: STD_LOGIC;
	SIGNAL Reader_SenderMAC_Counter_en		: STD_LOGIC;
	SIGNAL Reader_SenderMAC_Counter_us		: UNSIGNED(log2ceilnz(HARDWARE_ADDRESS_LENGTH) - 1 DOWNTO 0)		:= (OTHERS => '0');

	SIGNAL Reader_SenderIP_Counter_rst		: STD_LOGIC;
	SIGNAL Reader_SenderIP_Counter_en			: STD_LOGIC;
	SIGNAL Reader_SenderIP_Counter_us			: UNSIGNED(log2ceilnz(PROTOCOL_ADDRESS_LENGTH) - 1 DOWNTO 0)		:= (OTHERS => '0');

	SIGNAL Reader_TargetIP_Counter_rst		: STD_LOGIC;
	SIGNAL Reader_TargetIP_Counter_en			: STD_LOGIC;
	SIGNAL Reader_TargetIP_Counter_us			: UNSIGNED(log2ceilnz(PROTOCOL_ADDRESS_LENGTH) - 1 DOWNTO 0)		:= (OTHERS => '0');

--	SIGNAL SenderMACAddress_Data_rst			: STD_LOGIC;
	SIGNAL SenderHardwareAddress_en				: STD_LOGIC;
	SIGNAL SenderHardwareAddress_us				: UNSIGNED(log2ceilnz(HARDWARE_ADDRESS_LENGTH) - 1 DOWNTO 0);
	SIGNAL SenderHardwareAddress_d				: T_SLVV_8(HARDWARE_ADDRESS_LENGTH - 1 DOWNTO 0)								:= (OTHERS => (OTHERS => '0'));

--	SIGNAL SenderIPv4Address_Data_rst			: STD_LOGIC;
	SIGNAL SenderProtocolAddress_en				: STD_LOGIC;
	SIGNAL SenderProtocolAddress_us				: UNSIGNED(log2ceilnz(PROTOCOL_ADDRESS_LENGTH) - 1 DOWNTO 0);
	SIGNAL SenderProtocolAddress_d				: T_SLVV_8(PROTOCOL_ADDRESS_LENGTH - 1 DOWNTO 0)								:= (OTHERS => (OTHERS => '0'));
	
--	SIGNAL TargetIPv4Address_Data_rst			: STD_LOGIC;
	SIGNAL TargetProtocolAddress_en				: STD_LOGIC;
	SIGNAL TargetProtocolAddress_us				: UNSIGNED(log2ceilnz(PROTOCOL_ADDRESS_LENGTH) - 1 DOWNTO 0);
	SIGNAL TargetProtocolAddress_d				: T_SLVV_8(PROTOCOL_ADDRESS_LENGTH - 1 DOWNTO 0)								:= (OTHERS => (OTHERS => '0'));

BEGIN
	ASSERT (ALLOWED_PROTOCOL_IPV4 OR ALLOWED_PROTOCOL_IPV6) REPORT "At least one protocol must be selected: IPv4, IPv6" SEVERITY FAILURE;

	RX_Meta_rst									<= '0';
	RX_Meta_SrcMACAddress_nxt		<= '0';
	RX_Meta_DestMACAddress_nxt	<= '0';

	Is_SOF		<= RX_Valid AND RX_SOF;
	Is_EOF		<= RX_Valid AND RX_EOF;

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

	PROCESS(State,
					Clear,
					RX_Valid, RX_Data, Is_SOF, Is_EOF,
					IsIPv4_r, IsIPv6_r, Writer_Counter_us,
					Address_rst,
					SenderMACAddress_nxt, SenderIPAddress_nxt, TargetIPAddress_nxt)
	BEGIN
		NextState											<= State;
		
		RX_Ready											<= '0';

		RequestReceived								<= '0';
		Error													<= '0';
		
		IsIPv4_set										<= '0';
		IsIPv6_set										<= '0';

		Writer_Counter_rst						<= '0';
		Writer_Counter_en							<= '0';

		Reader_SenderMAC_Counter_rst	<= Clear OR Address_rst;
		Reader_SenderMAC_Counter_en		<= SenderMACAddress_nxt;
		SenderHardwareAddress_en			<= '0';
		SenderHardwareAddress_us			<= Writer_Counter_us(SenderHardwareAddress_us'range);

		Reader_SenderIP_Counter_rst		<= Clear OR Address_rst;
		Reader_SenderIP_Counter_en		<= SenderIPAddress_nxt;
		SenderProtocolAddress_en			<= '0';
		SenderProtocolAddress_us			<= Writer_Counter_us(SenderProtocolAddress_us'range);
		
		Reader_TargetIP_Counter_rst		<= Clear OR Address_rst;
		Reader_TargetIP_Counter_en		<= TargetIPAddress_nxt;
		TargetProtocolAddress_en			<= '0';
		TargetProtocolAddress_us			<= Writer_Counter_us(TargetProtocolAddress_us'range);

		CASE State IS
			WHEN ST_IDLE =>
				IF (Is_SOF = '1') THEN
					RX_Ready				<= '1';
				
					IF (Is_EOF = '0') THEN
						IF (RX_Data = x"00") THEN
							NextState		<= ST_RECEIVE_HARDWARE_TYPE_1;
						ELSE
							NextState		<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState		<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_HARDWARE_TYPE_1 =>
				IF (RX_Valid = '1') THEN
					RX_Ready				<= '1';
				
					IF (Is_EOF = '0') THEN
						IF (RX_Data = x"01") THEN
							NextState		<= ST_RECEIVE_PROTOCOL_TYPE_0;
						ELSE
							NextState		<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState		<= ST_ERROR;
					END IF;
				END IF;
		
			WHEN ST_RECEIVE_PROTOCOL_TYPE_0 =>
				IF (RX_Valid = '1') THEN
					RX_Ready				<= '1';
				
					IF (Is_EOF = '0') THEN
						IF ((ALLOWED_PROTOCOL_IPV4 = TRUE) AND (RX_Data = x"08")) THEN
							IsIPv4_set	<= '1';
							NextState		<= ST_RECEIVE_PROTOCOL_TYPE_1;
						ELSIF ((ALLOWED_PROTOCOL_IPV6 = TRUE) AND (RX_Data = x"86")) THEN
							IsIPv6_set	<= '1';
							NextState		<= ST_RECEIVE_PROTOCOL_TYPE_1;
						ELSE
							NextState		<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState		<= ST_ERROR;
					END IF;
				END IF;
		
			WHEN ST_RECEIVE_PROTOCOL_TYPE_1 =>
				IF (RX_Valid = '1') THEN
					RX_Ready				<= '1';
				
					IF (Is_EOF = '0') THEN
						IF ((IsIPv4_r = '1') AND (RX_Data = x"00")) THEN
							NextState		<= ST_RECEIVE_HARDWARE_ADDRESS_LENGTH;
						ELSIF ((IsIPv6_r = '1') AND (RX_Data = x"66")) THEN
							NextState		<= ST_RECEIVE_HARDWARE_ADDRESS_LENGTH;
						ELSE
							NextState		<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState		<= ST_ERROR;
					END IF;
				END IF;
		
			WHEN ST_RECEIVE_HARDWARE_ADDRESS_LENGTH =>
				IF (RX_Valid = '1') THEN
					RX_Ready				<= '1';
				
					IF (Is_EOF = '0') THEN
						IF (RX_Data = x"06") THEN
							NextState		<= ST_RECEIVE_PROTOCOL_ADDRESS_LENGTH;
						ELSE
							NextState		<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState		<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_PROTOCOL_ADDRESS_LENGTH =>
				IF (RX_Valid = '1') THEN
					RX_Ready				<= '1';
				
					IF (Is_EOF = '0') THEN
						IF ((IsIPv4_r = '1') AND (RX_Data = x"04")) THEN
							NextState		<= ST_RECEIVE_OPERATION_0;
						ELSIF ((IsIPv6_r = '1') AND (RX_Data = x"10")) THEN
							NextState		<= ST_RECEIVE_OPERATION_0;
						ELSE
							NextState		<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState		<= ST_ERROR;
					END IF;
				END IF;

			WHEN ST_RECEIVE_OPERATION_0 =>
				IF (RX_Valid = '1') THEN
					RX_Ready				<= '1';
					
					IF (Is_EOF = '0') THEN
						IF (RX_Data = x"00") THEN
							NextState		<= ST_RECEIVE_OPERATION_1;
						ELSE
							NextState		<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState		<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_OPERATION_1 =>
				IF (RX_Valid = '1') THEN
					RX_Ready				<= '1';
					
					IF (Is_EOF = '0') THEN
						IF (RX_Data = x"01") THEN
							NextState		<= ST_RECEIVE_SENDER_MAC;
						ELSE
							NextState		<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState			<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_SENDER_MAC =>
				IF (RX_Valid = '1') THEN
					RX_Ready									<= '1';
					Writer_Counter_en					<= '1';
					SenderHardwareAddress_en	<= '1';
					
					IF (Is_EOF = '0') THEN
						IF (Writer_Counter_us = (HARDWARE_ADDRESS_LENGTH - 1)) THEN
							Writer_Counter_rst		<= '1';
							NextState							<= ST_RECEIVE_SENDER_IP;
						END IF;
					ELSE
						NextState								<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_SENDER_IP =>
				IF (RX_Valid = '1') THEN
					RX_Ready									<= '1';
					Writer_Counter_en					<= '1';
					SenderProtocolAddress_en	<= '1';
					
					IF (Is_EOF = '0') THEN
						IF ((IsIPv4_r = '1') AND (Writer_Counter_us = (PROTOCOL_IPV4_ADDRESS_LENGTH - 1))) THEN
							Writer_Counter_rst		<= '1';
							NextState							<= ST_RECEIVE_TARGET_MAC;
						ELSIF ((IsIPv6_r = '1') AND (Writer_Counter_us = (PROTOCOL_IPV6_ADDRESS_LENGTH - 1))) THEN
							Writer_Counter_rst		<= '1';
							NextState							<= ST_RECEIVE_TARGET_MAC;
						END IF;
					ELSE
						NextState								<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_TARGET_MAC =>
				IF (RX_Valid = '1') THEN
					RX_Ready									<= '1';
					Writer_Counter_en					<= '1';			-- needed to count incoming bytes
					
					IF (Is_EOF = '0') THEN
						IF (RX_Data = x"00") THEN
							IF (Writer_Counter_us = (HARDWARE_ADDRESS_LENGTH - 1)) THEN
								Writer_Counter_rst	<= '1';
								NextState						<= ST_RECEIVE_TARGET_IP;
							END IF;
						ELSE
							NextState							<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState								<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_TARGET_IP =>
				IF (RX_Valid = '1') THEN
					RX_Ready									<= '1';
					Writer_Counter_en					<= '1';
					TargetProtocolAddress_en	<= '1';
					
					IF (Is_EOF = '0') THEN
						IF ((IsIPv4_r = '1') AND (Writer_Counter_us = (PROTOCOL_IPV4_ADDRESS_LENGTH - 1))) THEN
							Writer_Counter_rst		<= '1';
							NextState							<= ST_DISCARD_ETHERNET_PADDING_BYTES;
						ELSIF ((IsIPv6_r = '1') AND (Writer_Counter_us = (PROTOCOL_IPV6_ADDRESS_LENGTH - 1))) THEN
							Writer_Counter_rst		<= '1';
							NextState							<= ST_DISCARD_ETHERNET_PADDING_BYTES;
						END IF;
					ELSE
						IF ((IsIPv4_r = '1') AND (Writer_Counter_us = (PROTOCOL_IPV4_ADDRESS_LENGTH - 1))) THEN
							Writer_Counter_rst		<= '1';
							NextState							<= ST_COMPLETE;
						ELSIF ((IsIPv6_r = '1') AND (Writer_Counter_us = (PROTOCOL_IPV6_ADDRESS_LENGTH - 1))) THEN
							Writer_Counter_rst		<= '1';
							NextState							<= ST_COMPLETE;
						ELSE
							NextState							<= ST_ERROR;
						END IF;
					END IF;
				END IF;
			
			WHEN ST_DISCARD_ETHERNET_PADDING_BYTES =>
				RX_Ready										<= '1';
				
				IF (Is_EOF = '1') THEN
					NextState									<= ST_COMPLETE;
				END IF;
			
			WHEN ST_COMPLETE =>
				RequestReceived							<= '1';
				
				IF (Clear = '1') THEN
					NextState									<= ST_IDLE;
				END IF;
			
			WHEN ST_DISCARD_FRAME =>
				RX_Ready										<= '1';
				
				IF (Is_EOF = '1') THEN
					NextState									<= ST_ERROR;
				END IF;
				
			WHEN ST_ERROR =>
				Error												<= '1';
				
				IF (Clear = '1') THEN
					NextState									<= ST_IDLE;
				END IF;
			
		END CASE;
	END PROCESS;
	
		
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Clear) = '1') THEN
				IsIPv4_r			<= '0';
				IsIPv6_r			<= '0';
			ELSE
				IF (IsIPv4_set = '1') THEN
					IsIPv4_r		<= '1';
				END IF;
				
				IF (IsIPv6_set = '1') THEN
					IsIPv6_r		<= '1';
				END IF;
			END IF;
		END IF;
	END PROCESS;


	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Writer_Counter_rst = '1') THEN
				Writer_Counter_us								<= (OTHERS => '0');
			ELSE
				IF (Writer_Counter_en = '1') THEN
					Writer_Counter_us							<= Writer_Counter_us + 1;
				END IF;
			END IF;
			
			IF (Reader_SenderMAC_Counter_rst = '1') THEN
				Reader_SenderMAC_Counter_us			<= (OTHERS => '0');
			ELSE
				IF (Reader_SenderMAC_Counter_en = '1') THEN
					Reader_SenderMAC_Counter_us		<= Reader_SenderMAC_Counter_us + 1;
				END IF;
			END IF;
			
			IF (Reader_SenderIP_Counter_rst = '1') THEN
				Reader_SenderIP_Counter_us			<= (OTHERS => '0');
			ELSE
				IF (Reader_SenderIP_Counter_en = '1') THEN
					Reader_SenderIP_Counter_us		<= Reader_SenderIP_Counter_us + 1;
				END IF;
			END IF;
			
			IF (Reader_TargetIP_Counter_rst = '1') THEN
				Reader_TargetIP_Counter_us			<= (OTHERS => '0');
			ELSE
				IF (Reader_TargetIP_Counter_en = '1') THEN
					Reader_TargetIP_Counter_us		<= Reader_TargetIP_Counter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;


	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (SenderHardwareAddress_en = '1') THEN
				SenderHardwareAddress_d(to_integer(SenderHardwareAddress_us))		<= RX_Data;
			END IF;
			
			IF (SenderProtocolAddress_en = '1') THEN
				SenderProtocolAddress_d(to_integer(SenderProtocolAddress_us))		<= RX_Data;
			END IF;
			
			IF (TargetProtocolAddress_en = '1') THEN
				TargetProtocolAddress_d(to_integer(TargetProtocolAddress_us))		<= RX_Data;
			END IF;
		END IF;
	END PROCESS;

	SenderMACAddress_Data				<= SenderHardwareAddress_d(ite((NOT SIMULATION), to_integer(Reader_SenderMAC_Counter_us), imin(to_integer(Reader_SenderMAC_Counter_us), 5)));
	SenderIPAddress_Data				<= SenderProtocolAddress_d(ite((NOT SIMULATION), to_integer(Reader_SenderIP_Counter_us), imin(to_integer(Reader_SenderIP_Counter_us), 3)));
	TargetIPAddress_Data				<= TargetProtocolAddress_d(ite((NOT SIMULATION), to_integer(Reader_TargetIP_Counter_us), imin(to_integer(Reader_TargetIP_Counter_us), 3)));

END;
