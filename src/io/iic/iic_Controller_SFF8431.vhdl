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

ENTITY IICController_SFF8431 IS
	GENERIC (
		DEBUG													: BOOLEAN												:= TRUE;
		CLOCK_FREQ_MHZ								: REAL													:= 100.0;					-- 100 MHz
		IIC_FREQ_KHZ									: REAL													:= 100.0
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		-- IICController interface
		Command												: IN	T_IO_IIC_SFF8431_COMMAND;
		Status												: OUT	T_IO_IIC_SFF8431_STATUS;
		Error													: OUT	T_IO_IIC_SFF8431_ERROR;
		
		PhysicalAddress								: IN	STD_LOGIC_VECTOR(6 DOWNTO 0);
		RegisterAddress								: IN	T_SLV_8;

		In_MoreBytes									: IN	STD_LOGIC;
		In_Data												: IN	T_SLV_8;
		In_NextByte										: OUT	STD_LOGIC;
		
		Out_LastByte									: IN	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_Valid											: OUT	STD_LOGIC;
				
		-- tristate interface
		SerialClock_i									: IN	STD_LOGIC;
		SerialClock_o									: OUT	STD_LOGIC;
		SerialClock_t									: OUT	STD_LOGIC;
		SerialData_i									: IN	STD_LOGIC;
		SerialData_o									: OUT	STD_LOGIC;
		SerialData_t									: OUT	STD_LOGIC
	);
END ENTITY;

-- TODOs
--	

ARCHITECTURE rtl OF IICController_SFF8431 IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	ATTRIBUTE ENUM_ENCODING						: STRING;
	
	-- if-then-else (ite)
	FUNCTION ite(cond : BOOLEAN; value1 : T_IO_IIC_SFF8431_STATUS; value2 : T_IO_IIC_SFF8431_STATUS) RETURN T_IO_IIC_SFF8431_STATUS IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END;
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_SEND_START,							ST_SEND_START_WAIT,
		-- address operation for random access => dummy write to internal SFP address register
			ST_SEND_PHYSICAL_ADDRESS0,	ST_SEND_PHYSICAL_ADDRESS0_WAIT,
			ST_SEND_READWRITE0,					ST_SEND_READWRITE0_WAIT,
			ST_RECEIVE_ACK0,						ST_RECEIVE_ACK0_WAIT,
			ST_SEND_REGISTER_ADDRESS,		ST_SEND_REGISTER_ADDRESS_WAIT,
			ST_RECEIVE_ACK1,						ST_RECEIVE_ACK1_WAIT,
		-- write operation => continue with data bytes
			ST_SEND_DATA,								ST_SEND_DATA_WAIT,
			ST_RECEIVE_ACK2,						ST_RECEIVE_ACK2_WAIT,
			ST_REGISTER_NEXT_BYTE,
		-- read operation => restart bus, resend physical address, read data bytes
		ST_SEND_RESTART,						ST_SEND_RESTART_WAIT,
			ST_SEND_PHYSICAL_ADDRESS1,	ST_SEND_PHYSICAL_ADDRESS1_WAIT,
			ST_SEND_READWRITE1,					ST_SEND_READWRITE1_WAIT,
			ST_RECEIVE_ACK3,						ST_RECEIVE_ACK3_WAIT,
			ST_RECEIVE_DATA,						ST_RECEIVE_DATA_WAIT,
			ST_SEND_ACK,								ST_SEND_ACK_WAIT,
			ST_SEND_NACK,								ST_SEND_NACK_WAIT,
		ST_SEND_STOP,								ST_SEND_STOP_WAIT,
		ST_COMPLETE,
		ST_BUS_ERROR, ST_ADDRESS_ERROR, ST_ACK_ERROR, ST_ERROR
	);
	
	SIGNAL State												: T_STATE													:= ST_IDLE;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS "gray";
	
	SIGNAL Status_i											: T_IO_IIC_SFF8431_STATUS;
	SIGNAL Error_i											: T_IO_IIC_SFF8431_ERROR;
	
	SIGNAL Command_en										: STD_LOGIC;
	SIGNAL Command_d										: T_IO_IIC_SFF8431_COMMAND				:= IO_IIC_SFF8431_CMD_NONE;
	
	SIGNAL BusMaster										: STD_LOGIC;
	SIGNAL BusMode											: STD_LOGIC;
	SIGNAL IICBC_Command								: T_IO_IICBUS_COMMAND;
	SIGNAL IICBC_Status									: T_IO_IICBUS_STATUS;
	
	SIGNAL BitCounter_rst								: STD_LOGIC;
	SIGNAL BitCounter_en								: STD_LOGIC;
	SIGNAL BitCounter_us								: UNSIGNED(3 DOWNTO 0)						:= (OTHERS => '0');
	
	SIGNAL RegOperation_en							: STD_LOGIC;
	SIGNAL RegOperation_d								: STD_LOGIC												:= '0';
	
	SIGNAL PhysicalAddress_en						: STD_LOGIC;
	SIGNAL PhysicalAddress_sh						: STD_LOGIC;
	SIGNAL PhysicalAddress_d						: STD_LOGIC_VECTOR(6 DOWNTO 0)		:= (OTHERS => '0');
	
	SIGNAL RegisterAddress_en						: STD_LOGIC;
	SIGNAL RegisterAddress_sh						: STD_LOGIC;
	SIGNAL RegisterAddress_d						: T_SLV_8													:= (OTHERS => '0');
	
	SIGNAL DataRegister_en							: STD_LOGIC;
	SIGNAL DataRegister_sh							: STD_LOGIC;
	SIGNAL DataRegister_d								: T_SLV_8													:= (OTHERS => '0');

	SIGNAL SerialClock_t_i							: STD_LOGIC;
	SIGNAL SerialData_t_i								: STD_LOGIC;

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

	PROCESS(State, Command, Command_d, IICBC_Status, BitCounter_us, PhysicalAddress_d, RegisterAddress_d, DataRegister_d, In_MoreBytes, Out_LastByte)
		TYPE T_CMDCAT IS (NONE, READ, WRITE);
		VARIABLE CommandCategory	: T_CMDCAT;
	
	BEGIN
		NextState									<= State;

		Status_i									<= IO_IIC_SFF8431_STATUS_IDLE;
		Error_i										<= IO_IIC_SFF8431_ERROR_NONE;
		
		In_NextByte								<= '0';
		Out_Valid									<= '0';

		Command_en								<= '0';
		PhysicalAddress_en				<= '0';
		RegisterAddress_en				<= '0';
		DataRegister_en						<= '0';

		PhysicalAddress_sh				<= '0';
		RegisterAddress_sh				<= '0';
		DataRegister_sh						<= '0';
		
		BitCounter_rst						<= '0';
		BitCounter_en							<= '0';

		BusMaster									<= '0';
		BusMode										<= '0';
		IICBC_Command							<= IO_IICBUS_CMD_NONE;

		-- precalculated command categories
		CASE Command_d IS
			WHEN IO_IIC_SFF8431_CMD_NONE =>						CommandCategory := NONE;
--			WHEN IO_IIC_SFF8431_CMD_ADDRESS_CHECK =>	CommandCategory := READ;
			WHEN IO_IIC_SFF8431_CMD_READ_CURRENT =>		CommandCategory := READ;
			WHEN IO_IIC_SFF8431_CMD_READ_BYTE =>			CommandCategory := READ;
			WHEN IO_IIC_SFF8431_CMD_READ_BYTES =>			CommandCategory := READ;
			WHEN IO_IIC_SFF8431_CMD_WRITE_BYTE =>			CommandCategory := WRITE;
			WHEN IO_IIC_SFF8431_CMD_WRITE_BYTES =>		CommandCategory := WRITE;
			WHEN OTHERS =>														CommandCategory := NONE;
		END CASE;

		CASE State IS
			WHEN ST_IDLE =>
				CASE Command IS
					WHEN IO_IIC_SFF8431_CMD_NONE =>
						NULL;
					
--					WHEN IO_IIC_SFF8431_CMD_ADDRESS_CHECK =>
--						Command_en							<= '1';
--						PhysicalAddress_en			<= '1';
--						
--						NextState								<= ST_SEND_START;
					
					WHEN IO_IIC_SFF8431_CMD_READ_CURRENT =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';
						
						NextState								<= ST_SEND_START;
				
					WHEN IO_IIC_SFF8431_CMD_READ_BYTE =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';
						RegisterAddress_en			<= '1';
						
						NextState								<= ST_SEND_START;
						
					WHEN IO_IIC_SFF8431_CMD_READ_BYTES =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';
						RegisterAddress_en			<= '1';
						
						NextState								<= ST_SEND_START;
											
					WHEN IO_IIC_SFF8431_CMD_WRITE_BYTE =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';
						RegisterAddress_en			<= '1';
						DataRegister_en					<= '1';
						
						NextState								<= ST_SEND_START;
					
					WHEN IO_IIC_SFF8431_CMD_WRITE_BYTES =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';
						RegisterAddress_en			<= '1';
						DataRegister_en					<= '1';
		
						NextState								<= ST_SEND_START;
					
					WHEN OTHERS =>
						NextState								<= ST_ERROR;
						
				END CASE;
			
			WHEN ST_SEND_START =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_START_CONDITION;
				
				NextState										<= ST_SEND_START_WAIT;
				
			WHEN ST_SEND_START_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_PHYSICAL_ADDRESS0;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_PHYSICAL_ADDRESS0 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				PhysicalAddress_sh					<= '1';
				IF (PhysicalAddress_d(PhysicalAddress_d'high) = '0') THEN
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				ELSE
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				END IF;
				
				NextState										<= ST_SEND_PHYSICAL_ADDRESS0_WAIT;
				
			WHEN ST_SEND_PHYSICAL_ADDRESS0_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				IF (IICBC_Status = IO_IICBUS_STATUS_SENDING) THEN
					NULL;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_SEND_COMPLETE) THEN
					BitCounter_en							<= '1';
			
					IF (BitCounter_us = (PhysicalAddress_d'length - 1)) THEN
						NextState								<= ST_SEND_READWRITE0;
					ELSE
						NextState								<= ST_SEND_PHYSICAL_ADDRESS0;
					END IF;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_ERROR) THEN
					NextState									<= ST_BUS_ERROR;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_SEND_READWRITE0 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE Command_d IS														-- write = 0; read = 1
--					WHEN IO_IIC_SFF8431_CMD_ADDRESS_CHECK =>	IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN IO_IIC_SFF8431_CMD_READ_CURRENT =>		IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN IO_IIC_SFF8431_CMD_READ_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN IO_IIC_SFF8431_CMD_READ_BYTES =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN IO_IIC_SFF8431_CMD_WRITE_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN IO_IIC_SFF8431_CMD_WRITE_BYTES =>		IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN OTHERS  =>														IICBC_Command		<= IO_IICBUS_CMD_NONE;
				END CASE;
				
				NextState										<= ST_SEND_READWRITE0_WAIT;
				
			WHEN ST_SEND_READWRITE0_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_ACK0;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_RECEIVE_ACK0 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_ACK0_WAIT;
				
			WHEN ST_RECEIVE_ACK0_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '0';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>									NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>
						CASE Command_d IS
--							WHEN IO_IIC_SFF8431_CMD_ADDRESS_CHECK =>				NextState			<= ST_SEND_STOP;
							WHEN IO_IIC_SFF8431_CMD_READ_CURRENT =>					NextState			<= ST_RECEIVE_DATA;
							WHEN IO_IIC_SFF8431_CMD_READ_BYTE =>						NextState			<= ST_SEND_REGISTER_ADDRESS;
							WHEN IO_IIC_SFF8431_CMD_READ_BYTES =>						NextState			<= ST_SEND_REGISTER_ADDRESS;
							WHEN IO_IIC_SFF8431_CMD_WRITE_BYTE =>						NextState			<= ST_SEND_REGISTER_ADDRESS;
							WHEN IO_IIC_SFF8431_CMD_WRITE_BYTES =>					NextState			<= ST_SEND_REGISTER_ADDRESS;
							WHEN OTHERS =>																	NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>							NextState			<= ST_ACK_ERROR;
					WHEN IO_IICBUS_STATUS_ERROR =>											NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																			NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_REGISTER_ADDRESS =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				RegisterAddress_sh					<= '1';
				IF (RegisterAddress_d(RegisterAddress_d'high) = '0') THEN
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				ELSE
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				END IF;
				
				NextState										<= ST_SEND_REGISTER_ADDRESS_WAIT;
				
			WHEN ST_SEND_REGISTER_ADDRESS_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';

				IF (IICBC_Status = IO_IICBUS_STATUS_SENDING) THEN
					NULL;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_SEND_COMPLETE) THEN
					BitCounter_en							<= '1';
			
					IF (BitCounter_us = (RegisterAddress_d'length - 1)) THEN
						NextState								<= ST_RECEIVE_ACK1;
					ELSE
						NextState								<= ST_SEND_REGISTER_ADDRESS;
					END IF;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_ERROR) THEN
					NextState									<= ST_BUS_ERROR;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
				
			WHEN ST_RECEIVE_ACK1 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_ACK1_WAIT;
			
			WHEN ST_RECEIVE_ACK1_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '0';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>								NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>
						CASE Command_d IS
							WHEN IO_IIC_SFF8431_CMD_WRITE_BYTE =>			NextState			<= ST_SEND_DATA;
							WHEN IO_IIC_SFF8431_CMD_WRITE_BYTES =>		NextState			<= ST_SEND_DATA;
							WHEN IO_IIC_SFF8431_CMD_READ_CURRENT =>		NextState			<= ST_ERROR;
							WHEN IO_IIC_SFF8431_CMD_READ_BYTE =>			NextState			<= ST_SEND_RESTART;
							WHEN IO_IIC_SFF8431_CMD_READ_BYTES =>			NextState			<= ST_SEND_RESTART;
							WHEN OTHERS  =>														NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>				NextState			<= ST_ACK_ERROR;
					WHEN OTHERS =>																NextState			<= ST_ERROR;
				END CASE;

			-- write operation => continue writing
			-- ======================================================================
			WHEN ST_SEND_DATA =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				DataRegister_sh							<= '1';
				IF (DataRegister_d(DataRegister_d'high) = '0') THEN
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				ELSE
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				END IF;
				
				NextState										<= ST_SEND_DATA_WAIT;
				
			WHEN ST_SEND_DATA_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				IF (IICBC_Status = IO_IICBUS_STATUS_SENDING) THEN
					NULL;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_SEND_COMPLETE) THEN
					BitCounter_en							<= '1';
			
					IF (BitCounter_us = 7) THEN
						NextState								<= ST_RECEIVE_ACK2;
					ELSE
						NextState								<= ST_SEND_DATA;
					END IF;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_ERROR) THEN
					NextState									<= ST_BUS_ERROR;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_RECEIVE_ACK2 =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_ACK2_WAIT;
			
			WHEN ST_RECEIVE_ACK2_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				BusMaster										<= '1';
				BusMode											<= '0';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>						NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>
						CASE Command_d IS
							WHEN IO_IIC_SFF8431_CMD_WRITE_BYTE =>			NextState			<= ST_SEND_STOP;
							WHEN IO_IIC_SFF8431_CMD_WRITE_BYTES =>
								IF (In_MoreBytes = '1') THEN
									In_NextByte				<= '1';
									NextState					<= ST_REGISTER_NEXT_BYTE;
								ELSE
									NextState					<= ST_SEND_STOP;
								END IF;
							WHEN OTHERS =>														NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>				NextState			<= ST_ACK_ERROR;
					WHEN IO_IICBUS_STATUS_ERROR =>								NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_REGISTER_NEXT_BYTE =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				DataRegister_en							<= '1';
				
				NextState										<= ST_SEND_DATA;
			
			-- read operation
			-- ======================================================================
			WHEN ST_SEND_RESTART =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_RESTART_CONDITION;
			
				NextState										<= ST_SEND_RESTART_WAIT;
			
			WHEN ST_SEND_RESTART_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_PHYSICAL_ADDRESS1;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;

			WHEN ST_SEND_PHYSICAL_ADDRESS1 =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				PhysicalAddress_sh					<= '1';
				IF (PhysicalAddress_d(PhysicalAddress_d'high) = '0') THEN
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				ELSE
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				END IF;
				
				NextState										<= ST_SEND_PHYSICAL_ADDRESS1_WAIT;
				
			WHEN ST_SEND_PHYSICAL_ADDRESS1_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				IF (IICBC_Status = IO_IICBUS_STATUS_SENDING) THEN
					NULL;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_SEND_COMPLETE) THEN
					BitCounter_en							<= '1';
			
					IF (BitCounter_us = (PhysicalAddress_d'length - 1)) THEN
						NextState								<= ST_SEND_READWRITE1;
					ELSE
						NextState								<= ST_SEND_PHYSICAL_ADDRESS1;
					END IF;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_ERROR) THEN
					NextState									<= ST_BUS_ERROR;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_SEND_READWRITE1 =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE Command_d IS														-- write = 0; read = 1
					WHEN IO_IIC_SFF8431_CMD_WRITE_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_NONE;
					WHEN IO_IIC_SFF8431_CMD_WRITE_BYTES =>		IICBC_Command		<= IO_IICBUS_CMD_NONE;
					WHEN IO_IIC_SFF8431_CMD_READ_CURRENT =>		IICBC_Command		<= IO_IICBUS_CMD_NONE;
					WHEN IO_IIC_SFF8431_CMD_READ_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN IO_IIC_SFF8431_CMD_READ_BYTES =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN OTHERS  =>														IICBC_Command		<= IO_IICBUS_CMD_NONE;
				END CASE;
				
				NextState										<= ST_SEND_READWRITE1_WAIT;
				
			WHEN ST_SEND_READWRITE1_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_ACK3;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_RECEIVE_ACK3 =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_ACK3_WAIT;
			
			WHEN ST_RECEIVE_ACK3_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '0';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>						NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>
						CASE Command_d IS
							WHEN IO_IIC_SFF8431_CMD_READ_BYTE =>			NextState			<= ST_RECEIVE_DATA;
							WHEN IO_IIC_SFF8431_CMD_READ_BYTES =>			NextState			<= ST_RECEIVE_DATA;
							WHEN OTHERS =>														NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>				NextState			<= ST_ACK_ERROR;
					WHEN IO_IICBUS_STATUS_ERROR =>								NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_RECEIVE_DATA =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_DATA_WAIT;
			
			WHEN ST_RECEIVE_DATA_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '0';
			
				IF (IICBC_Status = IO_IICBUS_STATUS_RECEIVING) THEN
					NULL;
				ELSIF ((IICBC_Status = IO_IICBUS_STATUS_RECEIVED_LOW) OR (IICBC_Status = IO_IICBUS_STATUS_RECEIVED_HIGH)) THEN
					BitCounter_en							<= '1';
					DataRegister_sh						<= '1';
					
					IF (BitCounter_us = 7) THEN
						IF ((Out_LastByte = '1') OR (Command_d = IO_IIC_SFF8431_CMD_READ_BYTE)) THEN
							NextState							<= ST_SEND_NACK;
						ELSE
							NextState							<= ST_SEND_ACK;
						END IF;
					ELSE
						NextState								<= ST_RECEIVE_DATA;
					END IF;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_ERROR) THEN
					NextState									<= ST_BUS_ERROR;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_SEND_ACK =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				Out_Valid										<= '1';
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_LOW;
				
				NextState										<= ST_SEND_ACK_WAIT;
				
			WHEN ST_SEND_ACK_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_DATA;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_NACK =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_HIGH;
				
				NextState										<= ST_SEND_NACK_WAIT;
				
			WHEN ST_SEND_NACK_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_STOP;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
				
			WHEN ST_SEND_STOP =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_STOP_CONDITION;
			
				NextState										<= ST_SEND_STOP_WAIT;
			
			WHEN ST_SEND_STOP_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_COMPLETE;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_COMPLETE =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READ_COMPLETE,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITE_COMPLETE));
				NextState										<= ST_IDLE;
			
			WHEN ST_BUS_ERROR =>
				Status_i										<= IO_IIC_SFF8431_STATUS_ERROR;
				Error_i											<= IO_IIC_SFF8431_ERROR_BUS_ERROR;
				NextState										<= ST_IDLE;
			
			WHEN ST_ADDRESS_ERROR =>
				Status_i										<= IO_IIC_SFF8431_STATUS_ERROR;
				Error_i											<= IO_IIC_SFF8431_ERROR_ADDRESS_ERROR;
				NextState										<= ST_IDLE;
			
			WHEN ST_ACK_ERROR =>
				Status_i										<= IO_IIC_SFF8431_STATUS_ERROR;
				Error_i											<= IO_IIC_SFF8431_ERROR_ACK_ERROR;
				NextState										<= ST_IDLE;
			
			WHEN ST_ERROR =>
				Status_i										<= IO_IIC_SFF8431_STATUS_ERROR;
				Error_i											<= IO_IIC_SFF8431_ERROR_FSM;
				NextState										<= ST_IDLE;
			
		END CASE;
	END PROCESS;


	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR BitCounter_rst) = '1') THEN
				BitCounter_us						<= (OTHERS => '0');
			ELSE
				IF (BitCounter_en	= '1') THEN
					BitCounter_us					<= BitCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(Clock, IICBC_Status )
		VARIABLE DataRegister_si		: STD_LOGIC;
	BEGIN
		CASE IICBC_Status IS
			WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>			DataRegister_si	:= '0';
			WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>		DataRegister_si	:= '1';
			WHEN OTHERS =>														DataRegister_si	:= 'X';
		END CASE;
	
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				Command_d							<= IO_IIC_SFF8431_CMD_NONE;
				PhysicalAddress_d			<= (OTHERS => '0');
				RegisterAddress_d			<= (OTHERS => '0');
				DataRegister_d				<= (OTHERS => '0');
			ELSE
				IF (Command_en	= '1') THEN
					Command_d					<= Command;
				END IF;
			
				IF (PhysicalAddress_en	= '1') THEN
					PhysicalAddress_d	<= PhysicalAddress;
				ELSIF (PhysicalAddress_sh = '1') THEN
					PhysicalAddress_d	<= PhysicalAddress_d(PhysicalAddress_d'high - 1 DOWNTO 0) & PhysicalAddress_d(PhysicalAddress_d'high);
				END IF;
				
				IF (RegisterAddress_en	= '1') THEN
					RegisterAddress_d	<= RegisterAddress;
				ELSIF (RegisterAddress_sh = '1') THEN
					RegisterAddress_d	<= RegisterAddress_d(RegisterAddress_d'high - 1 DOWNTO 0) & ite(SIMULATION, 'U', '0');
				END IF;
				
				IF (DataRegister_en	= '1') THEN
					DataRegister_d			<= In_Data;
				ELSIF (DataRegister_sh = '1') THEN
					DataRegister_d			<= DataRegister_d(DataRegister_d'high - 1 DOWNTO 0) & DataRegister_si;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Status		<= Status_i;
	Out_Data	<= DataRegister_d;

	IICBC : ENTITY L_IO.IICBusController
		GENERIC MAP (
			CLOCK_FREQ_MHZ							=> CLOCK_FREQ_MHZ,
			IIC_FREQ_KHZ									=> IIC_FREQ_KHZ
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			BusMaster											=> BusMaster,
			BusMode												=> BusMode,											-- 0 = passive; 1 = active
			
			Command												=> IICBC_Command,
			Status												=> IICBC_Status,
			
			SerialClock_i									=> SerialClock_i,
			SerialClock_o									=> SerialClock_o,
			SerialClock_t									=> SerialClock_t_i,
			SerialData_i									=> SerialData_i,
			SerialData_o									=> SerialData_o,
			SerialData_t									=> SerialData_t_i
		);

	SerialClock_t		<= SerialClock_t_i;
	SerialData_t		<= SerialData_t_i;

	genCSP : IF (DEBUG = TRUE) GENERATE
--		CONSTANT STATES		: POSITIVE		:= T_STATE'pos(ST_ERROR) + 1;
--		CONSTANT BITS			: POSITIVE		:= log2ceilnz(STATES);
--	
--		FUNCTION to_slv(State : T_STATE) RETURN STD_LOGIC_VECTOR IS
--		BEGIN
--			RETURN std_logic_vector(to_unsigned(T_STATE'pos(State), BITS));
--		END FUNCTION;
	
		-- debugging signals
		TYPE T_DBG_CHIPSCOPE IS RECORD
			Command						: T_IO_IIC_SFF8431_COMMAND;
			Status						: T_IO_IIC_SFF8431_STATUS;
			PhysicalAddress		: STD_LOGIC_VECTOR(6 DOWNTO 0);
			RegisterAddress		: T_SLV_8;
			DataIn						: T_SLV_8;
			DataOut						: T_SLV_8;
			State							: T_STATE;
			IICBC_Command			: T_IO_IICBUS_COMMAND;
			IICBC_Status			: T_IO_IICBUS_STATUS;
			Clock_i						: STD_LOGIC;
			Clock_t						: STD_LOGIC;
			Data_i						: STD_LOGIC;
			Data_t						: STD_LOGIC;
		END RECORD;
		
		SIGNAL CSP_DebugVector_i		: T_DBG_CHIPSCOPE;
		SIGNAL CSP_DebugVector_d1		: T_DBG_CHIPSCOPE;
		SIGNAL CSP_DebugVector_d2		: T_DBG_CHIPSCOPE;
		SIGNAL CSP_DebugVector_d3		: T_DBG_CHIPSCOPE;
		SIGNAL CSP_DebugVector_d4		: T_DBG_CHIPSCOPE;
		SIGNAL CSP_DebugVector			: T_DBG_CHIPSCOPE;
		
		SIGNAL CSP_Command					: T_IO_IIC_SFF8431_COMMAND;
		SIGNAL CSP_Status						: T_IO_IIC_SFF8431_STATUS;
		SIGNAL CSP_PhysicalAddress	: STD_LOGIC_VECTOR(6 DOWNTO 0);
		SIGNAL CSP_RegisterAddress	: T_SLV_8;
		SIGNAL CSP_DataIn						: T_SLV_8;
		SIGNAL CSP_DataOut					: T_SLV_8;
		SIGNAL CSP_State						: T_STATE;
		SIGNAL CSP_IICBC_Command		: T_IO_IICBUS_COMMAND;
		SIGNAL CSP_IICBC_Status			: T_IO_IICBUS_STATUS;
		SIGNAL CSP_Clock_i					: STD_LOGIC;
		SIGNAL CSP_Clock_t					: STD_LOGIC;
		SIGNAL CSP_Data_i						: STD_LOGIC;
		SIGNAL CSP_Data_t						: STD_LOGIC;
		
		SIGNAL SerialClock_t_d			: STD_LOGIC;
		SIGNAL SerialData_t_d				: STD_LOGIC;
		
		SIGNAL Trigger_i						: STD_LOGIC;
		SIGNAL Trigger_d1						: STD_LOGIC;
		SIGNAL Trigger_d2						: STD_LOGIC;
		SIGNAL Trigger_d3						: STD_LOGIC;
		SIGNAL Trigger_d4						: STD_LOGIC;
		SIGNAL Trigger_d5						: STD_LOGIC;
		SIGNAL Trigger_d6						: STD_LOGIC;
		SIGNAL Valid_r							: STD_LOGIC;
		
		SIGNAL CSP_Trigger					: STD_LOGIC;
		SIGNAL CSP_Valid						: STD_LOGIC;
		
		ATTRIBUTE KEEP OF CSP_Command					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_Status					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_PhysicalAddress	: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_RegisterAddress	: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_DataIn					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_DataOut					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_State						: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_IICBC_Command		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_IICBC_Status		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_Clock_i					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_Clock_t					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_Data_i					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_Data_t					: SIGNAL IS TRUE;
		
		ATTRIBUTE KEEP OF CSP_Trigger					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_Valid						: SIGNAL IS TRUE;
	BEGIN
		CSP_DebugVector_i.Command						<= Command;
		CSP_DebugVector_i.Status						<= Status_i;
		CSP_DebugVector_i.PhysicalAddress		<= PhysicalAddress;
		CSP_DebugVector_i.RegisterAddress		<= RegisterAddress;
		CSP_DebugVector_i.DataIn						<= In_Data;
		CSP_DebugVector_i.DataOut						<= DataRegister_d;
		CSP_DebugVector_i.State							<= State;
		CSP_DebugVector_i.IICBC_Command			<= IICBC_Command;
		CSP_DebugVector_i.IICBC_Status			<= IICBC_Status;
		CSP_DebugVector_i.Clock_i						<= SerialClock_i;
		CSP_DebugVector_i.Clock_t						<= SerialClock_t_i;
		CSP_DebugVector_i.Data_i						<= SerialData_i;
		CSP_DebugVector_i.Data_t						<= SerialData_t_i;
	
		CSP_DebugVector_d1	<= CSP_DebugVector_i	WHEN rising_edge(Clock);
		CSP_DebugVector_d2	<= CSP_DebugVector_d1	WHEN rising_edge(Clock);
		CSP_DebugVector_d3	<= CSP_DebugVector_d2	WHEN rising_edge(Clock);
		CSP_DebugVector_d4	<= CSP_DebugVector_d3	WHEN rising_edge(Clock);
		CSP_DebugVector			<= CSP_DebugVector_d4;

		CSP_Command						<= CSP_DebugVector.Command;
		CSP_Status						<= CSP_DebugVector.Status;
		CSP_PhysicalAddress		<= CSP_DebugVector.PhysicalAddress;
		CSP_RegisterAddress		<= CSP_DebugVector.RegisterAddress;
		CSP_DataIn						<= CSP_DebugVector.DataIn;
		CSP_DataOut						<= CSP_DebugVector.DataOut;
		CSP_State							<= CSP_DebugVector.State;
		CSP_IICBC_Command			<= CSP_DebugVector.IICBC_Command;
		CSP_IICBC_Status			<= CSP_DebugVector.IICBC_Status;
		CSP_Clock_i						<= CSP_DebugVector.Clock_i;
		CSP_Clock_t						<= CSP_DebugVector.Clock_t;
		CSP_Data_i						<= CSP_DebugVector.Data_i;
		CSP_Data_t						<= CSP_DebugVector.Data_t;
		
		SerialClock_t_d			<= SerialClock_t_i		WHEN rising_edge(Clock);
		SerialData_t_d			<= SerialData_t_i			WHEN rising_edge(Clock);
		
		Trigger_i						<= (SerialClock_t_i XOR SerialClock_t_d) OR (SerialData_t_i XOR SerialData_t_d);
		Trigger_d1					<= Trigger_i					WHEN rising_edge(Clock);
		Trigger_d2					<= Trigger_d1					WHEN rising_edge(Clock);
		Trigger_d3					<= Trigger_d2					WHEN rising_edge(Clock);
		Trigger_d4					<= Trigger_d3					WHEN rising_edge(Clock);
		Trigger_d5					<= Trigger_d4					WHEN rising_edge(Clock);
		Trigger_d6					<= Trigger_d5					WHEN rising_edge(Clock);
		
		CSP_Trigger					<= Trigger_d4;
		CSP_Valid						<= Trigger_i OR Valid_r;
		
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Trigger_d6 = '1') THEN
					Valid_r				<= '0';
				ELSIF (Trigger_i = '1') THEN
					Valid_r				<= '1';
				END IF;
			END IF;
		END PROCESS;
		
	END GENERATE;
END;
