LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY ICMPv4_TX IS
	GENERIC (
		DEBUG													: BOOLEAN											:= FALSE;
		SOURCE_IPV4ADDRESS						: T_NET_IPV4_ADDRESS					:= C_NET_IPV4_ADDRESS_EMPTY
	);
	PORT (
		Clock													: IN	STD_LOGIC;																	-- 
		Reset													: IN	STD_LOGIC;																	-- 
		-- CSE interface
		Command												: IN	T_NET_ICMPV4_TX_COMMAND;
		Status												: OUT	T_NET_ICMPV4_TX_STATUS;
		Error													: OUT	T_NET_ICMPV4_TX_ERROR;
		-- OUT port
		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ready											: IN	STD_LOGIC;
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_SrcIPv4Address_nxt		: IN	STD_LOGIC;
		Out_Meta_SrcIPv4Address_Data	: OUT	T_SLV_8;
		Out_Meta_DestIPv4Address_nxt	: IN	STD_LOGIC;
		Out_Meta_DestIPv4Address_Data	: OUT	T_SLV_8;
		Out_Meta_Length								: OUT	T_SLV_16;
		-- IN port
		In_Meta_rst										: OUT	STD_LOGIC;
		In_Meta_IPv4Address_nxt				: OUT	STD_LOGIC;
		In_Meta_IPv4Address_Data			: IN	T_SLV_8;
		In_Meta_Type									: IN	T_SLV_8;
		In_Meta_Code									: IN	T_SLV_8;
		In_Meta_Identification				: IN	T_SLV_16;
		In_Meta_SequenceNumber				: IN	T_SLV_16;
		In_Meta_Payload_nxt						: OUT	STD_LOGIC;
		In_Meta_Payload_last					: IN	STD_LOGIC;
		In_Meta_Payload_Data					: IN	T_SLV_8
	);
END;

-- Endianess: big-endian
-- Alignment: 1 byte
--
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+================================+================================+================================+================================+
--	| Type 							 						 | Code														| Checksum																												|
--	+================================+================================+================================+================================+
--	| Payload	(optional)																																																								|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+================================+================================+================================+================================+


-- ICMPv4 - Type = {0, 8} => echo reply, echo request
-- 
--								Byte 0													Byte 1														Byte 2													Byte 3
--	+================================+================================+================================+================================+
--	| SourceAddress 							 																																																			|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| DestinationAddress																																																								|
--	+--------------------------------+--------------------------------+--------------------------------+--------------------------------+
--	| 0x00 							 						 | Protocol												| Length																													|
--	+================================+================================+================================+================================+
--	| UDP header (see above)																																																						|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+================================+================================+================================+================================+
--	| Payload																																																														|
--	~                                ~                                ~                                ~                                ~
--	|																																																																		|
--	+================================+================================+================================+================================+

ARCHITECTURE rtl OF ICMPv4_TX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_SEND_ECHO_TYPE,
				ST_SEND_ECHO_CODE,
				ST_SEND_ECHOREQUEST_CHECKSUM_0,
				ST_SEND_ECHOREQUEST_CHECKSUM_1,
				ST_SEND_ECHOREQUEST_IDENTIFIER_0,
				ST_SEND_ECHOREQUEST_IDENTIFIER_1,
				ST_SEND_ECHOREQUEST_SEQUENCENUMBER_0,
				ST_SEND_ECHOREQUEST_SEQUENCENUMBER_1,
				ST_SEND_ECHOREQUEST_DATA,
				ST_SEND_ECHOREPLY_DATA,
		ST_COMPLETE
	);

	SIGNAL State													: T_STATE													:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State				: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL Checksum												: T_SLV_16;

	CONSTANT PAYLOAD											: STD_LOGIC_VECTOR(255 DOWNTO 0)	:= x"00010203" & x"04050607" & x"08090A0B" & x"0C0D0E0F" & x"10111213" & x"14151617" & x"18191A1B" & x"1C1D1E1F";
	CONSTANT PAYLOAD_ROM									: T_SLVV_8												:= to_slvv_8(PAYLOAD);
	
	SIGNAL PayloadROM_Reader_nxt					: STD_LOGIC;
	SIGNAL PayloadROM_Reader_ov						: STD_LOGIC;
	SIGNAL PayloadROM_Reader_us						: UNSIGNED(log2ceilnz(PAYLOAD_ROM'length) - 1 DOWNTO 0)			:= (OTHERS => '0');
	SIGNAL PayloadROM_Data								: T_SLV_8;

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

	PROCESS(State, Command, Out_Ready, PayloadROM_Reader_ov, PayloadROM_Data)
	BEGIN
		NextState													<= State;

		Status														<= NET_ICMPV4_TX_STATUS_IDLE;
		Error															<= NET_ICMPV4_TX_ERROR_NONE;
		
		Out_Valid													<= '0';
		Out_Data													<= (OTHERS => '0');
		Out_SOF														<= '0';
		Out_EOF														<= '0';
		Out_Meta_Length										<= (OTHERS => '0');

		PayloadROM_Reader_nxt							<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				CASE Command IS
					WHEN NET_ICMPV4_TX_CMD_NONE =>
						NULL;
						
					WHEN NET_ICMPV4_TX_CMD_ECHO_REQUEST =>
						-- TODO: check if Type equal to Command
						NextState									<= ST_SEND_ECHO_TYPE;
						
					WHEN NET_ICMPV4_TX_CMD_ECHO_REPLY =>
						-- TODO: check if Type equal to Command
						NextState									<= ST_SEND_ECHO_TYPE;
						
				END CASE;
			
			WHEN ST_SEND_ECHO_TYPE =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_Type;
				Out_SOF												<= '1';
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_ECHO_CODE;
				END IF;
			
			WHEN ST_SEND_ECHO_CODE =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_Code;
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_ECHOREQUEST_CHECKSUM_0;
				END IF;
			
			WHEN ST_SEND_ECHOREQUEST_CHECKSUM_0 =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= Checksum(15 DOWNTO 8);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_ECHOREQUEST_CHECKSUM_1;
				END IF;
			
			WHEN ST_SEND_ECHOREQUEST_CHECKSUM_1 =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= Checksum(7 DOWNTO 0);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_ECHOREQUEST_IDENTIFIER_0;
				END IF;
			
			WHEN ST_SEND_ECHOREQUEST_IDENTIFIER_0 =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_Identification(15 DOWNTO 8);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_ECHOREQUEST_IDENTIFIER_1;
				END IF;
			
			WHEN ST_SEND_ECHOREQUEST_IDENTIFIER_1 =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_Identification(7 DOWNTO 0);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_ECHOREQUEST_SEQUENCENUMBER_0;
				END IF;
			
			WHEN ST_SEND_ECHOREQUEST_SEQUENCENUMBER_0 =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_SequenceNumber(15 DOWNTO 8);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_ECHOREQUEST_SEQUENCENUMBER_1;
				END IF;
			
			WHEN ST_SEND_ECHOREQUEST_SEQUENCENUMBER_1 =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_SequenceNumber(7 DOWNTO 0);
				
				IF (Out_Ready = '1') THEN
					NextState										<= ST_SEND_ECHOREQUEST_DATA;
				END IF;
			
			WHEN ST_SEND_ECHOREQUEST_DATA =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= PayloadROM_Data;
				
				PayloadROM_Reader_nxt					<= '1';
				
				IF (Out_Ready = '1') THEN
					IF (PayloadROM_Reader_ov = '1') THEN
						Out_EOF										<= '1';
						NextState									<= ST_COMPLETE;
					END IF;
				END IF;

			WHEN ST_SEND_ECHOREPLY_DATA =>
				Status												<= NET_ICMPV4_TX_STATUS_SENDING;
				
				Out_Valid											<= '1';
				Out_Data											<= In_Meta_Payload_Data;
				
				In_Meta_Payload_nxt						<= '1';
				
				IF (Out_Ready = '1') THEN
					IF (In_Meta_Payload_last = '1') THEN
						Out_EOF											<= '1';
				
						NextState										<= ST_COMPLETE;
					END IF;
				END IF;
			
			WHEN ST_COMPLETE =>
				Status												<= NET_ICMPV4_TX_STATUS_SEND_COMPLETE;
			
				NextState											<= ST_IDLE;
			
		END CASE;
	END PROCESS;


	Checksum			<= x"0000";
	
	
	SourceIPv4Seq : ENTITY L_Global.Sequenzer
		GENERIC MAP (
			INPUT_BITS						=> 32,
			OUTPUT_BITS						=> 8,
			REGISTERED						=> FALSE
		)
		PORT MAP (
			Clock									=> Clock,
			Reset									=> Reset,
			
			Input									=> to_slv(SOURCE_IPV4ADDRESS),
			rst										=> Out_Meta_rst,
			rev										=> '1',
			nxt										=> Out_Meta_SrcIPv4Address_nxt,
			Output								=> Out_Meta_SrcIPv4Address_Data
		);
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (PayloadROM_Reader_nxt = '0') THEN
				PayloadROM_Reader_us	<= (OTHERS => '0');
			ELSE
				PayloadROM_Reader_us	<= PayloadROM_Reader_us + 1;
			END IF;
		END IF;
	END PROCESS;

	PayloadROM_Reader_ov						<= to_sl(PayloadROM_Reader_us = (PAYLOAD_ROM'length - 1));
	PayloadROM_Data									<= PAYLOAD_ROM(to_integer(PayloadROM_Reader_us));
	
	In_Meta_IPv4Address_nxt					<= Out_Meta_DestIPv4Address_nxt;
	Out_Meta_DestIPv4Address_Data		<= In_Meta_IPv4Address_Data;
END;
