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


ENTITY MAC_TX_DestMAC_Prepender IS
	GENERIC (
		CHIPSCOPE_KEEP								: BOOLEAN													:= FALSE
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		In_Valid											: IN	STD_LOGIC;
		In_Data												: IN	T_SLV_8;
		In_SOF												: IN	STD_LOGIC;
		In_EOF												: IN	STD_LOGIC;
		In_Ready											: OUT	STD_LOGIC;
		In_Meta_rst										: OUT	STD_LOGIC;
		In_Meta_DestMACAddress_nxt		: OUT	STD_LOGIC;
		In_Meta_DestMACAddress_Data		: IN	T_SLV_8;
		
		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ready											: IN	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF MAC_TX_DestMAC_Prepender IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_PREPEND_DEST_MAC_1,
			ST_PREPEND_DEST_MAC_2,
			ST_PREPEND_DEST_MAC_3,
			ST_PREPEND_DEST_MAC_4,
			ST_PREPEND_DEST_MAC_5,
			ST_PAYLOAD
	);

	SIGNAL State										: T_STATE																						:= ST_IDLE;
	SIGNAL NextState								: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State	: SIGNAL IS ite(CHIPSCOPE_KEEP, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL Is_DataFlow							: STD_LOGIC;
	SIGNAL Is_SOF										: STD_LOGIC;
	SIGNAL Is_EOF										: STD_LOGIC;
	
BEGIN

	Is_DataFlow		<= In_Valid AND Out_Ready;
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

	PROCESS(State, In_Valid, In_Data, In_EOF, Is_DataFlow, Is_SOF, Is_EOF, Out_Ready, In_Meta_DestMACAddress_Data)
	BEGIN
		NextState										<= State;
		
		Out_Valid										<= '0';
		Out_Data										<= In_Data;
		Out_SOF											<= '0';
		Out_EOF											<= '0';

		In_Ready										<= '0';
		In_Meta_rst									<= '0';
--		In_Meta_DestMACAddress_rev	<= '1';					-- read destination MAC address in Big-Endian order
		In_Meta_DestMACAddress_nxt	<= '0';
	
		CASE State IS
			WHEN ST_IDLE =>
				In_Meta_rst											<= '1';
				Out_Data												<= In_Meta_DestMACAddress_Data;
					
				IF (Is_SOF = '1') THEN
					In_Meta_rst										<= '0';
					In_Meta_DestMACAddress_nxt		<= Out_Ready;
				
					Out_Valid											<= '1';
					Out_SOF												<= '1';
					
					IF (Out_Ready = '1') THEN
						NextState										<= ST_PREPEND_DEST_MAC_1;
					END IF;
				END IF;

			WHEN ST_PREPEND_DEST_MAC_1 =>
				In_Meta_DestMACAddress_nxt			<= Out_Ready;
				
				Out_Valid												<= '1';
				Out_Data												<= In_Meta_DestMACAddress_Data;
					
				IF (Out_Ready = '1') THEN
					NextState											<= ST_PREPEND_DEST_MAC_2;
				END IF;

			WHEN ST_PREPEND_DEST_MAC_2 =>
				In_Meta_DestMACAddress_nxt			<= Out_Ready;
				
				Out_Valid												<= '1';
				Out_Data												<= In_Meta_DestMACAddress_Data;
					
				IF (Out_Ready = '1') THEN
					NextState											<= ST_PREPEND_DEST_MAC_3;
				END IF;
				
			WHEN ST_PREPEND_DEST_MAC_3 =>
				In_Meta_DestMACAddress_nxt			<= Out_Ready;
				
				Out_Valid												<= '1';
				Out_Data												<= In_Meta_DestMACAddress_Data;
					
				IF (Out_Ready = '1') THEN
					NextState											<= ST_PREPEND_DEST_MAC_4;
				END IF;
				
			WHEN ST_PREPEND_DEST_MAC_4 =>
				In_Meta_DestMACAddress_nxt			<= Out_Ready;
				
				Out_Valid												<= '1';
				Out_Data												<= In_Meta_DestMACAddress_Data;
					
				IF (Out_Ready = '1') THEN
					NextState											<= ST_PREPEND_DEST_MAC_5;
				END IF;
				
			WHEN ST_PREPEND_DEST_MAC_5 =>
				In_Meta_DestMACAddress_nxt			<= Out_Ready;
				
				Out_Valid												<= '1';
				Out_Data												<= In_Meta_DestMACAddress_Data;
					
				IF (Out_Ready = '1') THEN
					NextState											<= ST_PAYLOAD;
				END IF;
			
			WHEN ST_PAYLOAD =>
				In_Ready												<= Out_Ready;
				
				Out_Valid												<= In_Valid;
				Out_EOF													<= In_EOF;

				IF ((Is_DataFlow AND Is_EOF) = '1') THEN
					NextState											<= ST_IDLE;
				END IF;
			
		END CASE;
	END PROCESS;

END ARCHITECTURE;
