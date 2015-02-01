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


ENTITY ICMPv6_RX IS
	PORT (
		Clock											: IN	STD_LOGIC;																	-- 
		Reset											: IN	STD_LOGIC;																	-- 
		
		Error											: OUT	STD_LOGIC;
		
		RX_Valid									: IN	STD_LOGIC;
		RX_Data										: IN	T_SLV_8;
		RX_SOF										: IN	STD_LOGIC;
		RX_EOF										: IN	STD_LOGIC;
		RX_Ack										: OUT	STD_LOGIC;
		
		Received_EchoRequest			: OUT	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF ICMPv6_RX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_RECEIVED_ECHOREQUEST,
				ST_RECEIVED_ECHOREQUEST_CODEFIELD,
				ST_RECEIVED_ECHOREQUEST_CHECKSUM_0,
				ST_RECEIVED_ECHOREQUEST_CHECKSUM_1,
		ST_DISCARD_FRAME, ST_ERROR
	);

	SIGNAL State											: T_STATE											:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS "gray";		--"speed1";

	SIGNAL Is_SOF											: STD_LOGIC;
	SIGNAL Is_EOF											: STD_LOGIC;

BEGIN

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

	PROCESS(State, Is_SOF, Is_EOF, RX_Valid, RX_Data)
	BEGIN
		NextState													<= State;
		
		RX_Ack														<= '0';

		Received_EchoRequest							<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				IF (Is_SOF = '1') THEN
					RX_Ack									<= '1';
				
					IF (Is_EOF = '0') THEN
						IF (RX_Data = x"08") THEN
							NextState							<= ST_RECEIVED_ECHOREQUEST;
						ELSE
							NextState							<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NextState								<= ST_ERROR;
					END IF;
				END IF;
			
			WHEN ST_RECEIVED_ECHOREQUEST =>
				RX_Ack										<= '1';
				
				IF (Is_EOF = '0') THEN
					IF (RX_Data = x"00") THEN
						NextState							<= ST_RECEIVED_ECHOREQUEST_CODEFIELD;
					ELSE
						NextState							<= ST_DISCARD_FRAME;
					END IF;
				ELSE
					NextState								<= ST_ERROR;
				END IF;

			WHEN ST_RECEIVED_ECHOREQUEST_CODEFIELD =>
				RX_Ack										<= '1';
				
				IF (Is_EOF = '0') THEN
					IF (RX_Data = x"00") THEN
						NextState							<= ST_RECEIVED_ECHOREQUEST_CHECKSUM_0;
					ELSE
						NextState							<= ST_DISCARD_FRAME;
					END IF;
				ELSE
					NextState								<= ST_ERROR;
				END IF;
	
			WHEN ST_RECEIVED_ECHOREQUEST_CHECKSUM_0 =>
				RX_Ack										<= '1';
				
				IF (Is_EOF = '1') THEN
					IF (RX_Data = x"00") THEN
						Received_EchoRequest	<= '1';
						NextState							<= ST_IDLE;
					ELSE
						NextState							<= ST_ERROR;
					END IF;
				ELSE
					NextState								<= ST_DISCARD_FRAME;
				END IF;

			WHEN ST_RECEIVED_ECHOREQUEST_CHECKSUM_1 =>
				NULL;

			WHEN ST_DISCARD_FRAME =>
				RX_Ack											<= '1';
				
				IF (Is_EOF = '1') THEN
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_ERROR =>
				Error												<= '1';
				NextState										<= ST_IDLE;
			
		END CASE;
	END PROCESS;
	
END;
