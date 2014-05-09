LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY ICMPv4_RX IS
	GENERIC (
		DEBUG													: BOOLEAN											:= FALSE
	);
	PORT (
		Clock													: IN	STD_LOGIC;																	-- 
		Reset													: IN	STD_LOGIC;																	-- 
		-- CSE interface
		Command												: IN	T_NET_ICMPV4_RX_COMMAND;
		Status												: OUT	T_NET_ICMPV4_RX_STATUS;
		Error													: OUT	T_NET_ICMPV4_RX_ERROR;
		-- IN port
		In_Valid											: IN	STD_LOGIC;
		In_Data												: IN	T_SLV_8;
		In_SOF												: IN	STD_LOGIC;
		In_EOF												: IN	STD_LOGIC;
		In_Ready											: OUT	STD_LOGIC;
		In_Meta_rst										: OUT	STD_LOGIC;
		In_Meta_SrcMACAddress_nxt			: OUT	STD_LOGIC;
		In_Meta_SrcMACAddress_Data		: IN	T_SLV_8;
		In_Meta_DestMACAddress_nxt		: OUT	STD_LOGIC;
		In_Meta_DestMACAddress_Data		: IN	T_SLV_8;
		In_Meta_SrcIPv4Address_nxt		: OUT	STD_LOGIC;
		In_Meta_SrcIPv4Address_Data		: IN	T_SLV_8;
		In_Meta_DestIPv4Address_nxt		: OUT	STD_LOGIC;
		In_Meta_DestIPv4Address_Data	: IN	T_SLV_8;
		In_Meta_Length								: IN	T_SLV_16;
		-- OUT Port
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_SrcMACAddress_nxt		: IN	STD_LOGIC;
		Out_Meta_SrcMACAddress_Data		: OUT	T_SLV_8;
		Out_Meta_DestMACAddress_nxt		: IN	STD_LOGIC;
		Out_Meta_DestMACAddress_Data	: OUT	T_SLV_8;
		Out_Meta_SrcIPv4Address_nxt		: IN	STD_LOGIC;
		Out_Meta_SrcIPv4Address_Data	: OUT	T_SLV_8;
		Out_Meta_DestIPv4Address_nxt	: IN	STD_LOGIC;
		Out_Meta_DestIPv4Address_Data	: OUT	T_SLV_8;
		Out_Meta_Length								: OUT	T_SLV_16;
		Out_Meta_Type									: OUT	T_SLV_8;
		Out_Meta_Code									: OUT	T_SLV_8;
		Out_Meta_Identification				: OUT	T_SLV_16;
		Out_Meta_SequenceNumber				: OUT	T_SLV_16;
		Out_Meta_Payload_nxt					: IN	STD_LOGIC;
		Out_Meta_Payload_last					: OUT	STD_LOGIC;
		Out_Meta_Payload_Data					: OUT	T_SLV_8
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



ARCHITECTURE rtl OF ICMPv4_RX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_RECEIVE_ECHO_CODE,
				ST_RECEIVE_ECHO_CHECKSUM_0,
				ST_RECEIVE_ECHO_CHECKSUM_1,
				ST_RECEIVE_ECHO_IDENTIFIER_0,
				ST_RECEIVE_ECHO_IDENTIFIER_1,
				ST_RECEIVE_ECHO_SEQ_NUMBER_0,
				ST_RECEIVE_ECHO_SEQ_NUMBER_1,
				ST_RECEIVE_ECHO_DATA,
				ST_RECEIVE_ECHO_COMPLETE,
		ST_DISCARD_FRAME,
		ST_ERROR
	);

	SIGNAL State													: T_STATE											:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State				: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL Register_rst										: STD_LOGIC;
	
	-- UDP header fields
	SIGNAL Type_en												: STD_LOGIC;
	SIGNAL Code_en												: STD_LOGIC;
	SIGNAL Checksum_en0										: STD_LOGIC;
	SIGNAL Checksum_en1										: STD_LOGIC;
	SIGNAL Identification_en0							: STD_LOGIC;
	SIGNAL Identification_en1							: STD_LOGIC;
	SIGNAL SequenceNumber_en0							: STD_LOGIC;
	SIGNAL SequenceNumber_en1							: STD_LOGIC;
	
	SIGNAL Type_d													: T_SLV_8											:= (OTHERS => '0');
	SIGNAL Code_d													: T_SLV_8											:= (OTHERS => '0');
	SIGNAL Checksum_d											: T_SLV_16										:= (OTHERS => '0');
	SIGNAL Identification_d								: T_SLV_16										:= (OTHERS => '0');
	SIGNAL SequenceNumber_d								: T_SLV_16										:= (OTHERS => '0');

	SIGNAL MetaFIFO_put										: STD_LOGIC;
	SIGNAL MetaFIFO_DataIn								: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL MetaFIFO_Full									: STD_LOGIC;
	SIGNAL MetaFIFO_Commit								: STD_LOGIC;
	SIGNAL MetaFIFO_Rollback							: STD_LOGIC;
--	SIGNAL MetaFIFO_Valid									: STD_LOGIC;
	SIGNAL MetaFIFO_DataOut								: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL MetaFIFO_got										: STD_LOGIC;

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

	PROCESS(State, Command, In_Valid, In_Data, In_SOF, In_EOF, Out_Meta_rst, Out_Meta_Payload_nxt)
	BEGIN
		NextState													<= State;

		Status														<= NET_ICMPV4_RX_STATUS_IDLE;
		Error															<= NET_ICMPV4_RX_ERROR_NONE;
		
		In_Ready													<= '0';
		In_Meta_rst												<= '0';
		In_Meta_SrcMACAddress_nxt					<= '0';
		In_Meta_DestMACAddress_nxt				<= '0';
		In_Meta_SrcIPv4Address_nxt				<= '0';
		In_Meta_DestIPv4Address_nxt				<= '0';

		Register_rst											<= to_sl(Command = NET_ICMPV4_RX_CMD_CLEAR);
		Type_en														<= '0';
		Code_en														<= '0';
		Checksum_en0											<= '0';
		Checksum_en1											<= '0';
		Identification_en0								<= '0';
		Identification_en1								<= '0';
		SequenceNumber_en0								<= '0';
		SequenceNumber_en1								<= '0';

		MetaFIFO_put											<= '0';
		MetaFIFO_DataIn(In_Data'range)		<= In_Data;
		MetaFIFO_DataIn(In_Data'length)		<= In_EOF;
		MetaFIFO_got											<= '0';
		MetaFIFO_Commit										<= '0';
		MetaFIFO_Rollback									<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				IF ((In_Valid AND In_SOF) = '1') THEN
					In_Ready										<= '1';
				
					IF (In_EOF = '0') THEN
						Type_en										<= '1';
					
						IF (In_Data = C_NET_ICMPV4_TYPE_ECHO_REPLY) THEN
							NextState								<= ST_RECEIVE_ECHO_CODE;
						ELSIF (In_Data = C_NET_ICMPV4_TYPE_ECHO_REQUEST) THEN
							NextState								<= ST_RECEIVE_ECHO_CODE;
						ELSE
							NextState								<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState									<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_ECHO_CODE =>
				Status												<= NET_ICMPV4_RX_STATUS_RECEIVING;
				
				IF (In_Valid = '1') THEN
					In_Ready										<= '1';
				
					IF (In_EOF = '0') THEN
						Code_en										<= '1';
						
						IF (In_Data = C_NET_ICMPV4_CODE_ECHO_REPLY) THEN
							NextState								<= ST_RECEIVE_ECHO_CHECKSUM_0;
						ELSIF (In_Data = C_NET_ICMPV4_CODE_ECHO_REQUEST) THEN
							NextState								<= ST_RECEIVE_ECHO_CHECKSUM_0;
						ELSE
							NextState								<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState									<= ST_ERROR;
					END IF;
				END IF;

			WHEN ST_RECEIVE_ECHO_CHECKSUM_0 =>
				Status												<= NET_ICMPV4_RX_STATUS_RECEIVING;
				
				IF (In_Valid = '1') THEN
					In_Ready										<= '1';
				
					IF (In_EOF = '0') THEN
						Checksum_en0							<= '1';
						NextState									<= ST_RECEIVE_ECHO_CHECKSUM_1;
					ELSE
						NextState									<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_ECHO_CHECKSUM_1 =>
				Status												<= NET_ICMPV4_RX_STATUS_RECEIVING;
				
				IF (In_Valid = '1') THEN
					In_Ready										<= '1';
				
					IF (In_EOF = '0') THEN
						Checksum_en1							<= '1';
						NextState									<= ST_RECEIVE_ECHO_IDENTIFIER_0;
					ELSE
						NextState									<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_ECHO_IDENTIFIER_0 =>
				Status												<= NET_ICMPV4_RX_STATUS_RECEIVING;
				
				IF (In_Valid = '1') THEN
					In_Ready										<= '1';
				
					IF (In_EOF = '0') THEN
						Identification_en0				<= '1';
						NextState									<= ST_RECEIVE_ECHO_IDENTIFIER_1;
					ELSE
						NextState									<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_ECHO_IDENTIFIER_1 =>
				Status												<= NET_ICMPV4_RX_STATUS_RECEIVING;
				
				IF (In_Valid = '1') THEN
					In_Ready										<= '1';
				
					IF (In_EOF = '0') THEN
						Identification_en1				<= '1';
						NextState									<= ST_RECEIVE_ECHO_SEQ_NUMBER_0;
					ELSE
						NextState									<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_ECHO_SEQ_NUMBER_0 =>
				Status												<= NET_ICMPV4_RX_STATUS_RECEIVING;
				
				IF (In_Valid = '1') THEN
					In_Ready										<= '1';
				
					IF (In_EOF = '0') THEN
						SequenceNumber_en0				<= '1';
						NextState									<= ST_RECEIVE_ECHO_SEQ_NUMBER_1;
					ELSE
						NextState									<= ST_ERROR;
					END IF;
				END IF;
				
			WHEN ST_RECEIVE_ECHO_SEQ_NUMBER_1 =>
				Status												<= NET_ICMPV4_RX_STATUS_RECEIVING;
				
				IF (In_Valid = '1') THEN
					In_Ready										<= '1';
				
					IF (In_EOF = '0') THEN
						SequenceNumber_en1				<= '1';
						NextState									<= ST_RECEIVE_ECHO_DATA;
					ELSE
						NextState									<= ST_ERROR;
					END IF;
				END IF;

			WHEN ST_RECEIVE_ECHO_DATA =>
				Status												<= NET_ICMPV4_RX_STATUS_RECEIVING;
				
				IF (In_Valid = '1') THEN
					In_Ready										<= '1';
				
					MetaFIFO_put								<= '1';
	
					IF (In_EOF = '1') THEN
						MetaFIFO_Commit						<= '1';
						NextState									<= ST_RECEIVE_ECHO_COMPLETE;
					END IF;
				END IF;

			WHEN ST_RECEIVE_ECHO_COMPLETE =>
				IF (Code_d = C_NET_ICMPV4_TYPE_ECHO_REPLY) THEN
					Status											<= NET_ICMPV4_RX_STATUS_RECEIVED_ECHO_REPLY;
				ELSIF (Code_d = C_NET_ICMPV4_TYPE_ECHO_REQUEST) THEN
					Status											<= NET_ICMPV4_RX_STATUS_RECEIVED_ECHO_REQUEST;
				END IF;

				In_Meta_SrcMACAddress_nxt			<= Out_Meta_SrcMACAddress_nxt;
				In_Meta_DestMACAddress_nxt		<= Out_Meta_DestMACAddress_nxt;
				In_Meta_SrcIPv4Address_nxt		<= Out_Meta_SrcIPv4Address_nxt;
				In_Meta_DestIPv4Address_nxt		<= Out_Meta_DestIPv4Address_nxt;

				MetaFIFO_got									<= Out_Meta_Payload_nxt;
				MetaFIFO_Rollback							<= Out_Meta_rst;

				IF (Command = NET_ICMPV4_RX_CMD_CLEAR) THEN
					NextState										<= ST_IDLE;
				END IF;

			WHEN ST_DISCARD_FRAME =>
				In_Ready											<= '1';
				
				IF ((In_Valid AND In_EOF) = '1') THEN
					NextState										<= ST_ERROR;
				END IF;
			
			WHEN ST_ERROR =>
				Status												<= NET_ICMPV4_RX_STATUS_ERROR;
				Error													<= NET_ICMPV4_RX_ERROR_FSM;
				
				NextState											<= ST_IDLE;
			
		END CASE;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Register_rst) = '1') THEN
				Type_d															<= (OTHERS => '0');
				Code_d															<= (OTHERS => '0');
				Checksum_d													<= (OTHERS => '0');
				Identification_d										<= (OTHERS => '0');
				SequenceNumber_d										<= (OTHERS => '0');
			ELSE
				IF (Type_en = '1') THEN
					Type_d														<= In_Data;
				END IF;
				IF (Code_en = '1') THEN
					Code_d														<= In_Data;
				END IF;
				
				IF (Checksum_en0 = '1') THEN
					Checksum_d(7 DOWNTO 0)						<= In_Data;
				END IF;
				IF (Checksum_en1 = '1') THEN
					Checksum_d(15 DOWNTO 8)						<= In_Data;
				END IF;
				
				IF (Identification_en0 = '1') THEN
					Identification_d(7 DOWNTO 0)			<= In_Data;
				END IF;
				IF (Identification_en1 = '1') THEN
					Identification_d(15 DOWNTO 8)			<= In_Data;
				END IF;
				
				IF (SequenceNumber_en1 = '1') THEN
					SequenceNumber_d(7 DOWNTO 0)			<= In_Data;
				END IF;
				IF (SequenceNumber_en1 = '1') THEN
					SequenceNumber_d(15 DOWNTO 8)			<= In_Data;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	-- FIXME: monitor MetaFIFO_Full signal
	
	PayloadFIFO : ENTITY PoC.fifo_cc_got_tempgot
		GENERIC MAP (
			D_BITS							=> MetaFIFO_DataIn'length,	-- Data Width
			MIN_DEPTH						=> 64,											-- Minimum FIFO Depth
			DATA_REG						=> TRUE,										-- Store Data Content in Registers
			STATE_REG						=> FALSE,										-- Registered Full/Empty Indicators
			OUTPUT_REG					=> FALSE,										-- Registered FIFO Output
			ESTATE_WR_BITS			=> 0,												-- Empty State Bits
			FSTATE_RD_BITS			=> 0												-- Full State Bits
		)
		PORT MAP (
			-- Global Reset and Clock
			clk									=> Clock,
			rst									=> Reset,
			
			-- Writing Interface
			put									=> MetaFIFO_put,
			din									=> MetaFIFO_DataIn,
			full								=> MetaFIFO_Full,
			estate_wr						=> OPEN,

			-- Reading Interface
			got									=> MetaFIFO_got,
			dout								=> MetaFIFO_DataOut,
			valid								=> OPEN,	--MetaFIFO_Valid,
			fstate_rd						=> OPEN,

			commit							=> MetaFIFO_Commit,
			rollback						=> MetaFIFO_Rollback
		);

	Out_Meta_SrcMACAddress_Data			<= In_Meta_SrcMACAddress_Data;
	Out_Meta_DestMACAddress_Data		<= In_Meta_DestMACAddress_Data;
	Out_Meta_SrcIPv4Address_Data		<= In_Meta_SrcIPv4Address_Data;
	Out_Meta_DestIPv4Address_Data		<= In_Meta_DestIPv4Address_Data;
	Out_Meta_Length									<= In_Meta_Length;
	Out_Meta_Type										<= Type_d;
	Out_Meta_Code										<= Code_d;
	Out_Meta_Identification					<= Identification_d;
	Out_Meta_SequenceNumber					<= SequenceNumber_d;
	Out_Meta_Payload_last						<= MetaFIFO_DataOut(Out_Meta_Payload_Data'length);
	Out_Meta_Payload_Data						<= MetaFIFO_DataOut(Out_Meta_Payload_Data'range);
END;
