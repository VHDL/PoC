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


ENTITY ICMPv6_TX IS
	PORT (
		Clock											: IN	STD_LOGIC;																	-- 
		Reset											: IN	STD_LOGIC;																	-- 
		
		TX_Valid									: OUT	STD_LOGIC;
		TX_Data										: OUT	T_SLV_8;
		TX_SOF										: OUT	STD_LOGIC;
		TX_EOF										: OUT	STD_LOGIC;
		TX_Ready									: IN	STD_LOGIC;
		
		Send_EchoResponse					: IN	STD_LOGIC;
		Send_Complete							: OUT STD_LOGIC
	);
END;

ARCHITECTURE rtl OF ICMPv6_TX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_SEND_ECHOREQUEST_TYPE,
				ST_SEND_ECHOREQUEST_CODEFIELD,
				ST_SEND_ECHOREQUEST_CHECKSUM_0,
				ST_SEND_ECHOREQUEST_CHECKSUM_1,
				ST_SEND_ECHOREQUEST_IDENTIFIER_0,
				ST_SEND_ECHOREQUEST_IDENTIFIER_1,
				ST_SEND_ECHOREQUEST_SEQUENCENUMBER_0,
				ST_SEND_ECHOREQUEST_SEQUENCENUMBER_1,
				ST_SEND_DATA,
		ST_COMPLETE
	);

	SIGNAL State											: T_STATE											:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS "gray";		--"speed1";

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

	PROCESS(State, Send_EchoResponse, TX_Ready)
	BEGIN
		NextState							<= State;
		
		TX_Valid							<= '1';
		TX_Data								<= (OTHERS => '0');
		TX_SOF								<= '0';
		TX_EOF								<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				TX_Valid					<= '0';

				IF (Send_EchoResponse = '1') THEN
					NextState				<= ST_SEND_ECHOREQUEST_TYPE;
				END IF;
			
			WHEN ST_SEND_ECHOREQUEST_TYPE =>
				NULL;
			
			WHEN ST_SEND_ECHOREQUEST_CODEFIELD =>
				NULL;
			
			WHEN ST_SEND_ECHOREQUEST_CHECKSUM_0 =>
				NULL;
			
			WHEN ST_SEND_ECHOREQUEST_CHECKSUM_1 =>
				NULL;
			
			WHEN ST_SEND_ECHOREQUEST_IDENTIFIER_0 =>
				NULL;
			
			WHEN ST_SEND_ECHOREQUEST_IDENTIFIER_1 =>
				NULL;
			
			WHEN ST_SEND_ECHOREQUEST_SEQUENCENUMBER_0 =>
				NULL;
			
			WHEN ST_SEND_ECHOREQUEST_SEQUENCENUMBER_1 =>
				NULL;
			
			WHEN ST_SEND_DATA =>
				NULL;
			
			WHEN ST_COMPLETE =>
				NULL;
			
		END CASE;
	END PROCESS;

END;
