library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
--use			PoC.config.all;
use			PoC.utils.all;

library L_Global;
use			PoC.GlobalTypes.all;

library L_IO;
use			L_IO.IOTypes.all;

entity IICController_SFF8431 is
	generic (
		DEBUG													: boolean												:= TRUE;
		CLOCK_FREQ_MHZ								: REAL													:= 100.0;					-- 100 MHz
		IIC_FREQ_KHZ									: REAL													:= 100.0
	);
	port (
		Clock													: in	std_logic;
		Reset													: in	std_logic;

		-- IICController interface
		Command												: in	T_IO_IIC_SFF8431_COMMAND;
		Status												: out	T_IO_IIC_SFF8431_STATUS;
		Error													: out	T_IO_IIC_SFF8431_ERROR;

		PhysicalAddress								: in	std_logic_vector(6 downto 0);
		RegisterAddress								: in	T_SLV_8;

		In_MoreBytes									: in	std_logic;
		In_Data												: in	T_SLV_8;
		In_NextByte										: out	std_logic;

		Out_LastByte									: in	std_logic;
		Out_Data											: out	T_SLV_8;
		Out_Valid											: out	std_logic;

		-- tristate interface
		SerialClock_i									: in	std_logic;
		SerialClock_o									: out	std_logic;
		SerialClock_t									: out	std_logic;
		SerialData_i									: in	std_logic;
		SerialData_o									: out	std_logic;
		SerialData_t									: out	std_logic
	);
end entity;

-- TODOs
--

architecture rtl of IICController_SFF8431 is
	attribute KEEP										: boolean;
	attribute FSM_ENCODING						: string;
	attribute ENUM_ENCODING						: string;

	-- if-then-else (ite)
	function ite(cond : boolean; value1 : T_IO_IIC_SFF8431_STATUS; value2 : T_IO_IIC_SFF8431_STATUS) return T_IO_IIC_SFF8431_STATUS is
	begin
		if cond then
			return value1;
		else
			return value2;
		end if;
	end;

	type T_STATE is (
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

	signal State												: T_STATE													:= ST_IDLE;
	signal NextState										: T_STATE;
	attribute FSM_ENCODING of State			: signal is "gray";

	signal Status_i											: T_IO_IIC_SFF8431_STATUS;
	signal Error_i											: T_IO_IIC_SFF8431_ERROR;

	signal Command_en										: std_logic;
	signal Command_d										: T_IO_IIC_SFF8431_COMMAND				:= IO_IIC_SFF8431_CMD_NONE;

	signal BusMaster										: std_logic;
	signal BusMode											: std_logic;
	signal IICBC_Command								: T_IO_IICBUS_COMMAND;
	signal IICBC_Status									: T_IO_IICBUS_STATUS;

	signal BitCounter_rst								: std_logic;
	signal BitCounter_en								: std_logic;
	signal BitCounter_us								: unsigned(3 downto 0)						:= (others => '0');

	signal RegOperation_en							: std_logic;
	signal RegOperation_d								: std_logic												:= '0';

	signal PhysicalAddress_en						: std_logic;
	signal PhysicalAddress_sh						: std_logic;
	signal PhysicalAddress_d						: std_logic_vector(6 downto 0)		:= (others => '0');

	signal RegisterAddress_en						: std_logic;
	signal RegisterAddress_sh						: std_logic;
	signal RegisterAddress_d						: T_SLV_8													:= (others => '0');

	signal DataRegister_en							: std_logic;
	signal DataRegister_sh							: std_logic;
	signal DataRegister_d								: T_SLV_8													:= (others => '0');

	signal SerialClock_t_i							: std_logic;
	signal SerialData_t_i								: std_logic;

begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State			<= ST_IDLE;
			else
				State			<= NextState;
			end if;
		end if;
	end process;

	process(State, Command, Command_d, IICBC_Status, BitCounter_us, PhysicalAddress_d, RegisterAddress_d, DataRegister_d, In_MoreBytes, Out_LastByte)
		type T_CMDCAT is (NONE, READ, WRITE);
		variable CommandCategory	: T_CMDCAT;

	begin
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
		case Command_d is
			when IO_IIC_SFF8431_CMD_NONE =>						CommandCategory := NONE;
--			when IO_IIC_SFF8431_CMD_ADDRESS_CHECK =>	CommandCategory := READ;
			when IO_IIC_SFF8431_CMD_READ_CURRENT =>		CommandCategory := READ;
			when IO_IIC_SFF8431_CMD_READ_BYTE =>			CommandCategory := READ;
			when IO_IIC_SFF8431_CMD_READ_BYTES =>			CommandCategory := READ;
			when IO_IIC_SFF8431_CMD_WRITE_BYTE =>			CommandCategory := WRITE;
			when IO_IIC_SFF8431_CMD_WRITE_BYTES =>		CommandCategory := WRITE;
			when others =>														CommandCategory := NONE;
		end case;

		case State is
			when ST_IDLE =>
				case Command is
					when IO_IIC_SFF8431_CMD_NONE =>
						null;

--					when IO_IIC_SFF8431_CMD_ADDRESS_CHECK =>
--						Command_en							<= '1';
--						PhysicalAddress_en			<= '1';
--
--						NextState								<= ST_SEND_START;

					when IO_IIC_SFF8431_CMD_READ_CURRENT =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';

						NextState								<= ST_SEND_START;

					when IO_IIC_SFF8431_CMD_READ_BYTE =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';
						RegisterAddress_en			<= '1';

						NextState								<= ST_SEND_START;

					when IO_IIC_SFF8431_CMD_READ_BYTES =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';
						RegisterAddress_en			<= '1';

						NextState								<= ST_SEND_START;

					when IO_IIC_SFF8431_CMD_WRITE_BYTE =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';
						RegisterAddress_en			<= '1';
						DataRegister_en					<= '1';

						NextState								<= ST_SEND_START;

					when IO_IIC_SFF8431_CMD_WRITE_BYTES =>
						Command_en							<= '1';
						PhysicalAddress_en			<= '1';
						RegisterAddress_en			<= '1';
						DataRegister_en					<= '1';

						NextState								<= ST_SEND_START;

					when others =>
						NextState								<= ST_ERROR;

				end case;

			when ST_SEND_START =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_START_CONDITION;

				NextState										<= ST_SEND_START_WAIT;

			when ST_SEND_START_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';

				case IICBC_Status is
					when IO_IICBUS_STATUS_SENDING =>					null;
					when IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_PHYSICAL_ADDRESS0;
					when IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					when others =>														NextState			<= ST_ERROR;
				end case;

			when ST_SEND_PHYSICAL_ADDRESS0 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';

				PhysicalAddress_sh					<= '1';
				if (PhysicalAddress_d(PhysicalAddress_d'high) = '0') then
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				else
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				end if;

				NextState										<= ST_SEND_PHYSICAL_ADDRESS0_WAIT;

			when ST_SEND_PHYSICAL_ADDRESS0_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';

				if IICBC_Status = IO_IICBUS_STATUS_SENDING then
					null;
				elsif IICBC_Status = IO_IICBUS_STATUS_SEND_COMPLETE then
					BitCounter_en							<= '1';

					if (BitCounter_us = (PhysicalAddress_d'length - 1)) then
						NextState								<= ST_SEND_READWRITE0;
					else
						NextState								<= ST_SEND_PHYSICAL_ADDRESS0;
					end if;
				elsif IICBC_Status = IO_IICBUS_STATUS_ERROR then
					NextState									<= ST_BUS_ERROR;
				else
					NextState									<= ST_ERROR;
				end if;

			when ST_SEND_READWRITE0 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';

				case Command_d is														-- write = 0; read = 1
--					when IO_IIC_SFF8431_CMD_ADDRESS_CHECK =>	IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					when IO_IIC_SFF8431_CMD_READ_CURRENT =>		IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					when IO_IIC_SFF8431_CMD_READ_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					when IO_IIC_SFF8431_CMD_READ_BYTES =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					when IO_IIC_SFF8431_CMD_WRITE_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					when IO_IIC_SFF8431_CMD_WRITE_BYTES =>		IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					when others  =>														IICBC_Command		<= IO_IICBUS_CMD_NONE;
				end case;

				NextState										<= ST_SEND_READWRITE0_WAIT;

			when ST_SEND_READWRITE0_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';

				case IICBC_Status is
					when IO_IICBUS_STATUS_SENDING =>					null;
					when IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_ACK0;
					when IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					when others =>														NextState			<= ST_ERROR;
				end case;

			when ST_RECEIVE_ACK0 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;

				NextState										<= ST_RECEIVE_ACK0_WAIT;

			when ST_RECEIVE_ACK0_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '0';

				case IICBC_Status is
					when IO_IICBUS_STATUS_RECEIVING =>									null;
					when IO_IICBUS_STATUS_RECEIVED_LOW =>
						case Command_d is
--							when IO_IIC_SFF8431_CMD_ADDRESS_CHECK =>				NextState			<= ST_SEND_STOP;
							when IO_IIC_SFF8431_CMD_READ_CURRENT =>					NextState			<= ST_RECEIVE_DATA;
							when IO_IIC_SFF8431_CMD_READ_BYTE =>						NextState			<= ST_SEND_REGISTER_ADDRESS;
							when IO_IIC_SFF8431_CMD_READ_BYTES =>						NextState			<= ST_SEND_REGISTER_ADDRESS;
							when IO_IIC_SFF8431_CMD_WRITE_BYTE =>						NextState			<= ST_SEND_REGISTER_ADDRESS;
							when IO_IIC_SFF8431_CMD_WRITE_BYTES =>					NextState			<= ST_SEND_REGISTER_ADDRESS;
							when others =>																	NextState			<= ST_ERROR;
						end case;
					when IO_IICBUS_STATUS_RECEIVED_HIGH =>							NextState			<= ST_ACK_ERROR;
					when IO_IICBUS_STATUS_ERROR =>											NextState			<= ST_BUS_ERROR;
					when others =>																			NextState			<= ST_ERROR;
				end case;

			when ST_SEND_REGISTER_ADDRESS =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';

				RegisterAddress_sh					<= '1';
				if (RegisterAddress_d(RegisterAddress_d'high) = '0') then
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				else
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				end if;

				NextState										<= ST_SEND_REGISTER_ADDRESS_WAIT;

			when ST_SEND_REGISTER_ADDRESS_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';

				if IICBC_Status = IO_IICBUS_STATUS_SENDING then
					null;
				elsif IICBC_Status = IO_IICBUS_STATUS_SEND_COMPLETE then
					BitCounter_en							<= '1';

					if (BitCounter_us = (RegisterAddress_d'length - 1)) then
						NextState								<= ST_RECEIVE_ACK1;
					else
						NextState								<= ST_SEND_REGISTER_ADDRESS;
					end if;
				elsif IICBC_Status = IO_IICBUS_STATUS_ERROR then
					NextState									<= ST_BUS_ERROR;
				else
					NextState									<= ST_ERROR;
				end if;

			when ST_RECEIVE_ACK1 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;

				NextState										<= ST_RECEIVE_ACK1_WAIT;

			when ST_RECEIVE_ACK1_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '0';

				case IICBC_Status is
					when IO_IICBUS_STATUS_RECEIVING =>								null;
					when IO_IICBUS_STATUS_RECEIVED_LOW =>
						case Command_d is
							when IO_IIC_SFF8431_CMD_WRITE_BYTE =>			NextState			<= ST_SEND_DATA;
							when IO_IIC_SFF8431_CMD_WRITE_BYTES =>		NextState			<= ST_SEND_DATA;
							when IO_IIC_SFF8431_CMD_READ_CURRENT =>		NextState			<= ST_ERROR;
							when IO_IIC_SFF8431_CMD_READ_BYTE =>			NextState			<= ST_SEND_RESTART;
							when IO_IIC_SFF8431_CMD_READ_BYTES =>			NextState			<= ST_SEND_RESTART;
							when others  =>														NextState			<= ST_ERROR;
						end case;
					when IO_IICBUS_STATUS_RECEIVED_HIGH =>				NextState			<= ST_ACK_ERROR;
					when others =>																NextState			<= ST_ERROR;
				end case;

			-- write operation => continue writing
			-- ======================================================================
			when ST_SEND_DATA =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				BusMaster										<= '1';
				BusMode											<= '1';

				DataRegister_sh							<= '1';
				if (DataRegister_d(DataRegister_d'high) = '0') then
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				else
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				end if;

				NextState										<= ST_SEND_DATA_WAIT;

			when ST_SEND_DATA_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				BusMaster										<= '1';
				BusMode											<= '1';

				if IICBC_Status = IO_IICBUS_STATUS_SENDING then
					null;
				elsif IICBC_Status = IO_IICBUS_STATUS_SEND_COMPLETE then
					BitCounter_en							<= '1';

					if BitCounter_us = 7 then
						NextState								<= ST_RECEIVE_ACK2;
					else
						NextState								<= ST_SEND_DATA;
					end if;
				elsif IICBC_Status = IO_IICBUS_STATUS_ERROR then
					NextState									<= ST_BUS_ERROR;
				else
					NextState									<= ST_ERROR;
				end if;

			when ST_RECEIVE_ACK2 =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;

				NextState										<= ST_RECEIVE_ACK2_WAIT;

			when ST_RECEIVE_ACK2_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				BusMaster										<= '1';
				BusMode											<= '0';

				case IICBC_Status is
					when IO_IICBUS_STATUS_RECEIVING =>						null;
					when IO_IICBUS_STATUS_RECEIVED_LOW =>
						case Command_d is
							when IO_IIC_SFF8431_CMD_WRITE_BYTE =>			NextState			<= ST_SEND_STOP;
							when IO_IIC_SFF8431_CMD_WRITE_BYTES =>
								if (In_MoreBytes = '1') then
									In_NextByte				<= '1';
									NextState					<= ST_REGISTER_NEXT_BYTE;
								else
									NextState					<= ST_SEND_STOP;
								end if;
							when others =>														NextState			<= ST_ERROR;
						end case;
					when IO_IICBUS_STATUS_RECEIVED_HIGH =>				NextState			<= ST_ACK_ERROR;
					when IO_IICBUS_STATUS_ERROR =>								NextState			<= ST_BUS_ERROR;
					when others =>																NextState			<= ST_ERROR;
				end case;

			when ST_REGISTER_NEXT_BYTE =>
				Status_i										<= IO_IIC_SFF8431_STATUS_WRITING;
				DataRegister_en							<= '1';

				NextState										<= ST_SEND_DATA;

			-- read operation
			-- ======================================================================
			when ST_SEND_RESTART =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_RESTART_CONDITION;

				NextState										<= ST_SEND_RESTART_WAIT;

			when ST_SEND_RESTART_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';

				case IICBC_Status is
					when IO_IICBUS_STATUS_SENDING =>					null;
					when IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_PHYSICAL_ADDRESS1;
					when IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					when others =>														NextState			<= ST_ERROR;
				end case;

			when ST_SEND_PHYSICAL_ADDRESS1 =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';

				PhysicalAddress_sh					<= '1';
				if (PhysicalAddress_d(PhysicalAddress_d'high) = '0') then
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				else
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				end if;

				NextState										<= ST_SEND_PHYSICAL_ADDRESS1_WAIT;

			when ST_SEND_PHYSICAL_ADDRESS1_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';

				if IICBC_Status = IO_IICBUS_STATUS_SENDING then
					null;
				elsif IICBC_Status = IO_IICBUS_STATUS_SEND_COMPLETE then
					BitCounter_en							<= '1';

					if (BitCounter_us = (PhysicalAddress_d'length - 1)) then
						NextState								<= ST_SEND_READWRITE1;
					else
						NextState								<= ST_SEND_PHYSICAL_ADDRESS1;
					end if;
				elsif IICBC_Status = IO_IICBUS_STATUS_ERROR then
					NextState									<= ST_BUS_ERROR;
				else
					NextState									<= ST_ERROR;
				end if;

			when ST_SEND_READWRITE1 =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';

				case Command_d is														-- write = 0; read = 1
					when IO_IIC_SFF8431_CMD_WRITE_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_NONE;
					when IO_IIC_SFF8431_CMD_WRITE_BYTES =>		IICBC_Command		<= IO_IICBUS_CMD_NONE;
					when IO_IIC_SFF8431_CMD_READ_CURRENT =>		IICBC_Command		<= IO_IICBUS_CMD_NONE;
					when IO_IIC_SFF8431_CMD_READ_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					when IO_IIC_SFF8431_CMD_READ_BYTES =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					when others  =>														IICBC_Command		<= IO_IICBUS_CMD_NONE;
				end case;

				NextState										<= ST_SEND_READWRITE1_WAIT;

			when ST_SEND_READWRITE1_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';

				case IICBC_Status is
					when IO_IICBUS_STATUS_SENDING =>					null;
					when IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_ACK3;
					when IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					when others =>														NextState			<= ST_ERROR;
				end case;

			when ST_RECEIVE_ACK3 =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;

				NextState										<= ST_RECEIVE_ACK3_WAIT;

			when ST_RECEIVE_ACK3_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '0';

				case IICBC_Status is
					when IO_IICBUS_STATUS_RECEIVING =>						null;
					when IO_IICBUS_STATUS_RECEIVED_LOW =>
						case Command_d is
							when IO_IIC_SFF8431_CMD_READ_BYTE =>			NextState			<= ST_RECEIVE_DATA;
							when IO_IIC_SFF8431_CMD_READ_BYTES =>			NextState			<= ST_RECEIVE_DATA;
							when others =>														NextState			<= ST_ERROR;
						end case;
					when IO_IICBUS_STATUS_RECEIVED_HIGH =>				NextState			<= ST_ACK_ERROR;
					when IO_IICBUS_STATUS_ERROR =>								NextState			<= ST_BUS_ERROR;
					when others =>																NextState			<= ST_ERROR;
				end case;

			when ST_RECEIVE_DATA =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;

				NextState										<= ST_RECEIVE_DATA_WAIT;

			when ST_RECEIVE_DATA_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '0';

				if IICBC_Status = IO_IICBUS_STATUS_RECEIVING then
					null;
				elsif (IICBC_Status = IO_IICBUS_STATUS_RECEIVED_LOW) or (IICBC_Status = IO_IICBUS_STATUS_RECEIVED_HIGH) then
					BitCounter_en							<= '1';
					DataRegister_sh						<= '1';

					if BitCounter_us = 7 then
						if ((Out_LastByte = '1') or (Command_d = IO_IIC_SFF8431_CMD_READ_BYTE)) then
							NextState							<= ST_SEND_NACK;
						else
							NextState							<= ST_SEND_ACK;
						end if;
					else
						NextState								<= ST_RECEIVE_DATA;
					end if;
				elsif IICBC_Status = IO_IICBUS_STATUS_ERROR then
					NextState									<= ST_BUS_ERROR;
				else
					NextState									<= ST_ERROR;
				end if;

			when ST_SEND_ACK =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				Out_Valid										<= '1';
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_LOW;

				NextState										<= ST_SEND_ACK_WAIT;

			when ST_SEND_ACK_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';

				case IICBC_Status is
					when IO_IICBUS_STATUS_SENDING =>					null;
					when IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_DATA;
					when IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					when others =>														NextState			<= ST_ERROR;
				end case;

			when ST_SEND_NACK =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_HIGH;

				NextState										<= ST_SEND_NACK_WAIT;

			when ST_SEND_NACK_WAIT =>
				Status_i										<= IO_IIC_SFF8431_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';

				case IICBC_Status is
					when IO_IICBUS_STATUS_SENDING =>					null;
					when IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_STOP;
					when IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					when others =>														NextState			<= ST_ERROR;
				end case;

			when ST_SEND_STOP =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_STOP_CONDITION;

				NextState										<= ST_SEND_STOP_WAIT;

			when ST_SEND_STOP_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITING));
				case IICBC_Status is
					when IO_IICBUS_STATUS_SENDING =>					null;
					when IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_COMPLETE;
					when IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					when others =>														NextState			<= ST_ERROR;
				end case;

			when ST_COMPLETE =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_SFF8431_STATUS_READ_COMPLETE,
																			 ite(((CommandCategory /= WRITE) and SIMULATION),	IO_IIC_SFF8431_STATUS_ERROR,
																																												IO_IIC_SFF8431_STATUS_WRITE_COMPLETE));
				NextState										<= ST_IDLE;

			when ST_BUS_ERROR =>
				Status_i										<= IO_IIC_SFF8431_STATUS_ERROR;
				Error_i											<= IO_IIC_SFF8431_ERROR_BUS_ERROR;
				NextState										<= ST_IDLE;

			when ST_ADDRESS_ERROR =>
				Status_i										<= IO_IIC_SFF8431_STATUS_ERROR;
				Error_i											<= IO_IIC_SFF8431_ERROR_ADDRESS_ERROR;
				NextState										<= ST_IDLE;

			when ST_ACK_ERROR =>
				Status_i										<= IO_IIC_SFF8431_STATUS_ERROR;
				Error_i											<= IO_IIC_SFF8431_ERROR_ACK_ERROR;
				NextState										<= ST_IDLE;

			when ST_ERROR =>
				Status_i										<= IO_IIC_SFF8431_STATUS_ERROR;
				Error_i											<= IO_IIC_SFF8431_ERROR_FSM;
				NextState										<= ST_IDLE;

		end case;
	end process;


	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset or BitCounter_rst) = '1') then
				BitCounter_us						<= (others => '0');
			else
				if (BitCounter_en	= '1') then
					BitCounter_us					<= BitCounter_us + 1;
				end if;
			end if;
		end if;
	end process;

	process(Clock, IICBC_Status )
		variable DataRegister_si		: std_logic;
	begin
		case IICBC_Status is
			when IO_IICBUS_STATUS_RECEIVED_LOW =>			DataRegister_si	:= '0';
			when IO_IICBUS_STATUS_RECEIVED_HIGH =>		DataRegister_si	:= '1';
			when others =>														DataRegister_si	:= 'X';
		end case;

		if rising_edge(Clock) then
			if (Reset = '1') then
				Command_d							<= IO_IIC_SFF8431_CMD_NONE;
				PhysicalAddress_d			<= (others => '0');
				RegisterAddress_d			<= (others => '0');
				DataRegister_d				<= (others => '0');
			else
				if (Command_en	= '1') then
					Command_d					<= Command;
				end if;

				if (PhysicalAddress_en	= '1') then
					PhysicalAddress_d	<= PhysicalAddress;
				elsif (PhysicalAddress_sh = '1') then
					PhysicalAddress_d	<= PhysicalAddress_d(PhysicalAddress_d'high - 1 downto 0) & PhysicalAddress_d(PhysicalAddress_d'high);
				end if;

				if (RegisterAddress_en	= '1') then
					RegisterAddress_d	<= RegisterAddress;
				elsif (RegisterAddress_sh = '1') then
					RegisterAddress_d	<= RegisterAddress_d(RegisterAddress_d'high - 1 downto 0) & ite(SIMULATION, 'U', '0');
				end if;

				if (DataRegister_en	= '1') then
					DataRegister_d			<= In_Data;
				elsif (DataRegister_sh = '1') then
					DataRegister_d			<= DataRegister_d(DataRegister_d'high - 1 downto 0) & DataRegister_si;
				end if;
			end if;
		end if;
	end process;

	Status		<= Status_i;
	Out_Data	<= DataRegister_d;

	IICBC : entity L_IO.IICBusController
		generic map (
			CLOCK_FREQ_MHZ							=> CLOCK_FREQ_MHZ,
			IIC_FREQ_KHZ									=> IIC_FREQ_KHZ
		)
		port map (
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

	genCSP : if DEBUG generate
--		constant STATES		: POSITIVE		:= T_STATE'pos(ST_ERROR) + 1;
--		constant BITS			: POSITIVE		:= log2ceilnz(STATES);
--
--		function to_slv(State : T_STATE) return STD_LOGIC_VECTOR is
--		begin
--			return std_logic_vector(to_unsigned(T_STATE'pos(State), BITS));
--		END function;

		-- debugging signals
		type T_DBG_CHIPSCOPE is record
			Command						: T_IO_IIC_SFF8431_COMMAND;
			Status						: T_IO_IIC_SFF8431_STATUS;
			PhysicalAddress		: std_logic_vector(6 downto 0);
			RegisterAddress		: T_SLV_8;
			DataIn						: T_SLV_8;
			DataOut						: T_SLV_8;
			State							: T_STATE;
			IICBC_Command			: T_IO_IICBUS_COMMAND;
			IICBC_Status			: T_IO_IICBUS_STATUS;
			Clock_i						: std_logic;
			Clock_t						: std_logic;
			Data_i						: std_logic;
			Data_t						: std_logic;
		end record;

		signal CSP_DebugVector_i		: T_DBG_CHIPSCOPE;
		signal CSP_DebugVector_d1		: T_DBG_CHIPSCOPE;
		signal CSP_DebugVector_d2		: T_DBG_CHIPSCOPE;
		signal CSP_DebugVector_d3		: T_DBG_CHIPSCOPE;
		signal CSP_DebugVector_d4		: T_DBG_CHIPSCOPE;
		signal CSP_DebugVector			: T_DBG_CHIPSCOPE;

		signal CSP_Command					: T_IO_IIC_SFF8431_COMMAND;
		signal CSP_Status						: T_IO_IIC_SFF8431_STATUS;
		signal CSP_PhysicalAddress	: std_logic_vector(6 downto 0);
		signal CSP_RegisterAddress	: T_SLV_8;
		signal CSP_DataIn						: T_SLV_8;
		signal CSP_DataOut					: T_SLV_8;
		signal CSP_State						: T_STATE;
		signal CSP_IICBC_Command		: T_IO_IICBUS_COMMAND;
		signal CSP_IICBC_Status			: T_IO_IICBUS_STATUS;
		signal CSP_Clock_i					: std_logic;
		signal CSP_Clock_t					: std_logic;
		signal CSP_Data_i						: std_logic;
		signal CSP_Data_t						: std_logic;

		signal SerialClock_t_d			: std_logic;
		signal SerialData_t_d				: std_logic;

		signal Trigger_i						: std_logic;
		signal Trigger_d1						: std_logic;
		signal Trigger_d2						: std_logic;
		signal Trigger_d3						: std_logic;
		signal Trigger_d4						: std_logic;
		signal Trigger_d5						: std_logic;
		signal Trigger_d6						: std_logic;
		signal Valid_r							: std_logic;

		signal CSP_Trigger					: std_logic;
		signal CSP_Valid						: std_logic;

		attribute KEEP of CSP_Command					: signal is TRUE;
		attribute KEEP of CSP_Status					: signal is TRUE;
		attribute KEEP of CSP_PhysicalAddress	: signal is TRUE;
		attribute KEEP of CSP_RegisterAddress	: signal is TRUE;
		attribute KEEP of CSP_DataIn					: signal is TRUE;
		attribute KEEP of CSP_DataOut					: signal is TRUE;
		attribute KEEP of CSP_State						: signal is TRUE;
		attribute KEEP of CSP_IICBC_Command		: signal is TRUE;
		attribute KEEP of CSP_IICBC_Status		: signal is TRUE;
		attribute KEEP of CSP_Clock_i					: signal is TRUE;
		attribute KEEP of CSP_Clock_t					: signal is TRUE;
		attribute KEEP of CSP_Data_i					: signal is TRUE;
		attribute KEEP of CSP_Data_t					: signal is TRUE;

		attribute KEEP of CSP_Trigger					: signal is TRUE;
		attribute KEEP of CSP_Valid						: signal is TRUE;
	begin
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

		CSP_DebugVector_d1	<= CSP_DebugVector_i	when rising_edge(Clock);
		CSP_DebugVector_d2	<= CSP_DebugVector_d1	when rising_edge(Clock);
		CSP_DebugVector_d3	<= CSP_DebugVector_d2	when rising_edge(Clock);
		CSP_DebugVector_d4	<= CSP_DebugVector_d3	when rising_edge(Clock);
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

		SerialClock_t_d			<= SerialClock_t_i		when rising_edge(Clock);
		SerialData_t_d			<= SerialData_t_i			when rising_edge(Clock);

		Trigger_i						<= (SerialClock_t_i xor SerialClock_t_d) or (SerialData_t_i xor SerialData_t_d);
		Trigger_d1					<= Trigger_i					when rising_edge(Clock);
		Trigger_d2					<= Trigger_d1					when rising_edge(Clock);
		Trigger_d3					<= Trigger_d2					when rising_edge(Clock);
		Trigger_d4					<= Trigger_d3					when rising_edge(Clock);
		Trigger_d5					<= Trigger_d4					when rising_edge(Clock);
		Trigger_d6					<= Trigger_d5					when rising_edge(Clock);

		CSP_Trigger					<= Trigger_d4;
		CSP_Valid						<= Trigger_i or Valid_r;

		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Trigger_d6 = '1') then
					Valid_r				<= '0';
				elsif (Trigger_i = '1') then
					Valid_r				<= '1';
				end if;
			end if;
		end process;

	end generate;
end;
