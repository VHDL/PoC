LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
--USE			PoC.config.ALL;
USE			PoC.utils.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;

ENTITY MDIO_SFF8431_Adapter IS
	GENERIC (
		DEBUG													: BOOLEAN												:= TRUE
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		-- MDIO interface
		Command												: IN	T_NET_ETH_MDIOCONTROLLER_COMMAND;
		Status												: OUT	T_NET_ETH_MDIOCONTROLLER_STATUS;
		Error													: OUT	T_NET_ETH_MDIOCONTROLLER_ERROR;
		
		Physical_Address							: IN	STD_LOGIC_VECTOR(6 DOWNTO 0);
		Register_Address							: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
		Register_DataIn								: IN	T_SLV_16;
		Register_DataOut							: OUT	T_SLV_16;
		
		-- IICController_SFF8431 interface
		SFF8431_Command								: OUT	T_IO_IIC_SFF8431_COMMAND;
		SFF8431_Status								: IN	T_IO_IIC_SFF8431_STATUS;
		SFF8431_Error									: IN	T_IO_IIC_SFF8431_ERROR;
		
		SFF8431_PhysicalAddress				: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		SFF8431_RegisterAddress				: OUT	T_SLV_8;
		
		SFF8431_LastByte							: OUT	STD_LOGIC;
		SFF8431_DataIn								: IN	T_SLV_8;
		SFF8431_Valid									: IN	STD_LOGIC;
			
		SFF8431_MoreBytes							: OUT	STD_LOGIC;
		SFF8431_DataOut								: OUT	T_SLV_8;
		SFF8431_NextByte							: IN	STD_LOGIC
	);
END ENTITY;

-- TODOs
--	add Status = NET_ETH_MDIOC_STATUS_ADDRESS_ERROR if IICC.Status = ACK_ERROR

ARCHITECTURE rtl OF MDIO_SFF8431_Adapter IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_READ_SEND_COMMAND,
			ST_READ_BYTE_0,
			ST_READ_BYTE_1,
			ST_READ_BYTES_COMPLETE,
		ST_WRITE_SEND_COMMAND,
			ST_WRITE_BYTE_0,
			ST_WRITE_BYTE_1,
			ST_WRITE_BYTES_COMPLETE,
		ST_ADDRESS_ERROR, ST_ERROR
	);
	
	SIGNAL State											: T_STATE										:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS "gray";
	
	SUBTYPE T_BYTE_INDEX IS NATURAL  RANGE 0 TO 1;
	SIGNAL DataRegister_Load					: STD_LOGIC;
	SIGNAL DataRegister_we						: STD_LOGIC;
	SIGNAL DataRegister_d							: T_SLVV_8(1 DOWNTO 0)			:= (OTHERS => (OTHERS => '0'));
	SIGNAL DataRegister_idx						: T_BYTE_INDEX;	

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

	PROCESS(State, Command, SFF8431_Status, SFF8431_NextByte, SFF8431_Valid)
	BEGIN
		NextState									<= State;

		Status										<= NET_ETH_MDIOC_STATUS_IDLE;
		Error											<= NET_ETH_MDIOC_ERROR_NONE;

		SFF8431_Command						<= IO_IIC_SFF8431_CMD_NONE;
		SFF8431_LastByte					<= '0';
		SFF8431_MoreBytes					<= '0';

		DataRegister_Load					<= '0';
		DataRegister_we						<= '0';
		DataRegister_idx					<= 0;

		CASE State IS
			WHEN ST_IDLE =>
				CASE Command IS
					WHEN NET_ETH_MDIOC_CMD_NONE =>
						NULL;
				
					WHEN NET_ETH_MDIOC_CMD_READ =>
						NextState						<= ST_READ_SEND_COMMAND;
					
					WHEN NET_ETH_MDIOC_CMD_WRITE =>
						DataRegister_Load		<= '1';
						
						NextState						<= ST_WRITE_SEND_COMMAND;
					
					WHEN OTHERS =>
						NextState						<= ST_ERROR;
						
				END CASE;
			
			WHEN ST_READ_SEND_COMMAND =>
				Status									<= NET_ETH_MDIOC_STATUS_READING;
				SFF8431_Command 				<= IO_IIC_SFF8431_CMD_READ_BYTES;
				DataRegister_idx				<= 0;
			
				NextState								<= ST_READ_BYTE_0;
			
			WHEN ST_READ_BYTE_0 =>
				Status									<= NET_ETH_MDIOC_STATUS_READING;
				SFF8431_LastByte				<= '0';
			
				CASE SFF8431_Status IS
					WHEN IO_IIC_SFF8431_STATUS_READING =>
						IF (SFF8431_Valid = '1') THEN
							DataRegister_we		<= '1';
							NextState					<= ST_READ_BYTE_1;
						END IF;
					WHEN IO_IIC_SFF8431_STATUS_READ_COMPLETE =>			NextState		<= ST_ERROR;
					WHEN IO_IIC_SFF8431_STATUS_ERROR =>
						CASE SFF8431_Error IS
							WHEN IO_IIC_SFF8431_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_SFF8431_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_SFF8431_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>															NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>																	NextState		<= ST_ERROR;
				END CASE;
			
			WHEN ST_READ_BYTE_1 =>
				Status									<= NET_ETH_MDIOC_STATUS_READING;
				DataRegister_idx				<= 1;
				SFF8431_LastByte				<= '1';

				CASE SFF8431_Status IS
					WHEN IO_IIC_SFF8431_STATUS_READING =>						NULL;
					WHEN IO_IIC_SFF8431_STATUS_READ_COMPLETE =>
						DataRegister_we			<= '1';
						NextState						<= ST_READ_BYTES_COMPLETE;
					WHEN IO_IIC_SFF8431_STATUS_ERROR =>
						CASE SFF8431_Error IS
							WHEN IO_IIC_SFF8431_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_SFF8431_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_SFF8431_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>															NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>																	NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_READ_BYTES_COMPLETE =>
				Status									<= NET_ETH_MDIOC_STATUS_READ_COMPLETE;
				NextState								<= ST_IDLE;
			
			WHEN ST_WRITE_SEND_COMMAND =>
				Status									<= NET_ETH_MDIOC_STATUS_WRITING;
				SFF8431_Command 				<= IO_IIC_SFF8431_CMD_WRITE_BYTES;
				DataRegister_idx				<= 0;
			
				NextState								<= ST_WRITE_BYTE_0;
			
			WHEN ST_WRITE_BYTE_0 =>
				Status									<= NET_ETH_MDIOC_STATUS_WRITING;
				DataRegister_idx				<= 0;
				SFF8431_MoreBytes				<= '1';
				
				CASE SFF8431_Status IS
					WHEN IO_IIC_SFF8431_STATUS_WRITING =>
						IF (SFF8431_NextByte = '1') THEN
							NextState					<= ST_WRITE_BYTE_1;
						END IF;
					WHEN IO_IIC_SFF8431_STATUS_WRITE_COMPLETE =>		NextState		<= ST_ERROR;
					WHEN IO_IIC_SFF8431_STATUS_ERROR =>
						CASE SFF8431_Error IS
							WHEN IO_IIC_SFF8431_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_SFF8431_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_SFF8431_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>															NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>																	NextState		<= ST_ERROR;
				END CASE;
				
			WHEN ST_WRITE_BYTE_1 =>
				Status									<= NET_ETH_MDIOC_STATUS_WRITING;
				DataRegister_idx				<= 1;
				SFF8431_MoreBytes				<= '0';

				CASE SFF8431_Status IS
					WHEN IO_IIC_SFF8431_STATUS_WRITING =>						NULL;
					WHEN IO_IIC_SFF8431_STATUS_WRITE_COMPLETE =>		NextState		<= ST_WRITE_BYTES_COMPLETE;
					WHEN IO_IIC_SFF8431_STATUS_ERROR =>
						CASE SFF8431_Error IS
							WHEN IO_IIC_SFF8431_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_SFF8431_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_SFF8431_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>															NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>																	NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_WRITE_BYTES_COMPLETE =>
				Status									<= NET_ETH_MDIOC_STATUS_WRITE_COMPLETE;
				NextState								<= ST_IDLE;
			
			WHEN ST_ADDRESS_ERROR =>
				Status									<= NET_ETH_MDIOC_STATUS_ERROR;
				Error										<= NET_ETH_MDIOC_ERROR_ADDRESS_NOT_FOUND;
				NextState								<= ST_IDLE;
			
			WHEN ST_ERROR =>
				Status									<= NET_ETH_MDIOC_STATUS_ERROR;
				Error										<= NET_ETH_MDIOC_ERROR_FSM;
				NextState								<= ST_IDLE;
			
		END CASE;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				DataRegister_d											<= (OTHERS => (OTHERS => '0'));
			ELSE
				IF (DataRegister_Load	= '1') THEN
					DataRegister_d(0)									<= Register_DataIn(7 DOWNTO 0);
					DataRegister_d(1)									<= Register_DataIn(15 DOWNTO 8);
				ELSIF (DataRegister_we	= '1') THEN
					DataRegister_d(DataRegister_idx)	<= SFF8431_DataIn;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Register_DataOut(7 DOWNTO 0)	<= DataRegister_d(0);
	Register_DataOut(15 DOWNTO 8)	<= DataRegister_d(1);

	SFF8431_PhysicalAddress				<= 					Physical_Address;
	SFF8431_RegisterAddress				<= "000"	& Register_Address;
	SFF8431_DataOut								<= DataRegister_d(DataRegister_idx);
END;
