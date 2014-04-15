-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:					I²C Controller
-- 
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		The IICController transmitts words over the I²C bus (SerialClock - SCL,
--		SerialData - SDA) and also receives them. This controller utilizes the
--		IICBusController to send/receive bits over the I²C bus. This controller
--		is compatible to the System Management Bus (SMBus).
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany,
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================


LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.io.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalComp.ALL;


ENTITY IICController IS
	GENERIC (
		DEBUG													: BOOLEAN												:= TRUE;
		CLOCK_IN_FREQ_MHZ							: REAL													:= 100.0;					-- 100 MHz
		IIC_FREQ_KHZ									: REAL													:= 100.0;
		ADDRESS_BITS									: POSITIVE											:= 7;
		DATA_BITS											: POSITIVE											:= 8
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		-- IICController master interface
		Master_Request								: IN	STD_LOGIC;
		Master_Grant									: OUT	STD_LOGIC;
		Master_Command								: IN	T_IO_IIC_COMMAND;
		Master_Status									: OUT	T_IO_IIC_STATUS;
		Master_Error									: OUT	T_IO_IIC_ERROR;
		
		Master_Address								: IN	STD_LOGIC_VECTOR(ADDRESS_BITS - 1 DOWNTO 0);

		Master_WP_Valid								: IN	STD_LOGIC;
		Master_WP_Data								: IN	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		Master_WP_Last								: IN	STD_LOGIC;
		Master_WP_Ack									: OUT	STD_LOGIC;
		Master_RP_Valid								: OUT	STD_LOGIC;
		Master_RP_Data								: OUT	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		Master_RP_Last								: OUT	STD_LOGIC;
		Master_RP_Ack									: IN	STD_LOGIC;
		
		-- tristate interface
		SerialClock_i									: IN	STD_LOGIC;
		SerialClock_o									: OUT	STD_LOGIC;
		SerialClock_t									: OUT	STD_LOGIC;
		SerialData_i									: IN	STD_LOGIC;
		SerialData_o									: OUT	STD_LOGIC;
		SerialData_t									: OUT	STD_LOGIC
	);
END ENTITY;


ARCHITECTURE rtl OF IICController IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;
	ATTRIBUTE ENUM_ENCODING					: STRING;
	
	-- if-then-else (ite)
	FUNCTION ite(cond : BOOLEAN; value1 : T_IO_IIC_STATUS; value2 : T_IO_IIC_STATUS) RETURN T_IO_IIC_STATUS IS
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
		-- device address transmission 0
			ST_SEND_DEVICE_ADDRESS0,		ST_SEND_DEVICE_ADDRESS0_WAIT,
			ST_SEND_READWRITE0,					ST_SEND_READWRITE0_WAIT,
			ST_RECEIVE_ACK0,						ST_RECEIVE_ACK0_WAIT,
		-- send byte(s) operation => continue with data bytes
			ST_SEND_DATA1,							ST_SEND_DATA1_WAIT,
			ST_RECEIVE_ACK1,						ST_RECEIVE_ACK1_WAIT,
--			ST_REGISTER_NEXT_BYTE,
		-- receive byte(s) operation => continue with data bytes
			ST_RECEIVE_DATA2,						ST_RECEIVE_DATA2_WAIT,
			ST_SEND_ACK2,								ST_SEND_ACK2_WAIT,
--			ST_REGISTER_NEXT_BYTE,
		-- call operation => send byte(s), restart bus, resend device address, read byte(s)
		ST_SEND_RESTART3,						ST_SEND_RESTART3_WAIT,
			ST_SEND_DEVICE_ADDRESS3,		ST_SEND_DEVICE_ADDRESS3_WAIT,
			ST_SEND_READWRITE3,					ST_SEND_READWRITE3_WAIT,
			ST_RECEIVE_ACK3,						ST_RECEIVE_ACK3_WAIT,
			ST_RECEIVE_DATA3,						ST_RECEIVE_DATA3_WAIT,
			ST_SEND_ACK3,								ST_SEND_ACK3_WAIT,
			ST_SEND_NACK3,							ST_SEND_NACK3_WAIT,
		ST_SEND_STOP,								ST_SEND_STOP_WAIT,
		ST_COMPLETE,
		ST_ERROR,
			ST_ADDRESS_ERROR,
			ST_ACK_ERROR,
			ST_BUS_ERROR
	);
	
	SIGNAL State												: T_STATE													:= ST_IDLE;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	SIGNAL Status_i											: T_IO_IIC_STATUS;
	
	SIGNAL Command_en										: STD_LOGIC;
	SIGNAL Command_d										: T_IO_IIC_COMMAND								:= IO_IIC_CMD_NONE;
	
	SIGNAL BusMaster										: STD_LOGIC;
	SIGNAL BusMode											: STD_LOGIC;
	SIGNAL IICBC_Command								: T_IO_IICBUS_COMMAND;
	SIGNAL IICBC_Status									: T_IO_IICBUS_STATUS;
	
	SIGNAL BitCounter_rst								: STD_LOGIC;
	SIGNAL BitCounter_en								: STD_LOGIC;
	SIGNAL BitCounter_us								: UNSIGNED(3 DOWNTO 0)						:= (OTHERS => '0');
	
	SIGNAL RegOperation_en							: STD_LOGIC;
	SIGNAL RegOperation_d								: STD_LOGIC												:= '0';
	
	SIGNAL Device_Address_en						: STD_LOGIC;
	SIGNAL Device_Address_sh						: STD_LOGIC;
	SIGNAL Device_Address_d							: STD_LOGIC_VECTOR(6 DOWNTO 0)		:= (OTHERS => '0');
	
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

	PROCESS(State, Master_Command, Command_d, IICBC_Status, BitCounter_us, Device_Address_d, RegisterAddress_d, DataRegister_d, In_MoreBytes, Out_LastByte)
		TYPE T_CMDCAT IS (NONE, READ, WRITE);
		VARIABLE CommandCategory	: T_CMDCAT;
	
	BEGIN
		NextState									<= State;

		Status_i									<= IO_IIC_STATUS_IDLE;
		Master_Error							<= IO_IIC_ERROR_NONE;
		
		Master_WP_Ack							<= '0';
		Master_RP_Valid						<= '0';
		Master_RP_Data						<= (OTHERS => '0');
		Master_RP_Last						<= '0';

		Command_en								<= '0';
		Device_Address_en				<= '0';
		RegisterAddress_en				<= '0';
		DataRegister_en						<= '0';

		Device_Address_sh				<= '0';
		RegisterAddress_sh				<= '0';
		DataRegister_sh						<= '0';
		
		BitCounter_rst						<= '0';
		BitCounter_en							<= '0';

		BusMaster									<= '0';
		BusMode										<= '0';
		IICBC_Command							<= IO_IICBUS_CMD_NONE;

		-- precalculated command categories
		CASE Command_d IS
			WHEN IO_IIC_CMD_NONE =>						CommandCategory := NONE;
			WHEN IO_IIC_CMD_CHECK_ADDRESS =>	CommandCategory := READ;
			WHEN IO_IIC_CMD_READ_CURRENT =>		CommandCategory := READ;
			WHEN IO_IIC_CMD_READ_BYTE =>			CommandCategory := READ;
			WHEN IO_IIC_CMD_READ_BYTES =>			CommandCategory := READ;
			WHEN IO_IIC_CMD_WRITE_BYTE =>			CommandCategory := WRITE;
			WHEN IO_IIC_CMD_WRITE_BYTES =>		CommandCategory := WRITE;
			WHEN OTHERS =>										CommandCategory := NONE;
		END CASE;

		CASE State IS
			WHEN ST_IDLE =>
				CASE Master_Command IS
					WHEN IO_IIC_CMD_NONE =>
						NULL;
					
					WHEN IO_IIC_CMD_CHECK_ADDRESS =>
						Command_en							<= '1';
						Device_Address_en				<= '1';
						
						NextState								<= ST_SEND_START;
					
					WHEN IO_IIC_CMD_READ_CURRENT =>
						Command_en							<= '1';
						Device_Address_en				<= '1';
						
						NextState								<= ST_SEND_START;
				
					WHEN IO_IIC_CMD_READ_BYTE =>
						Command_en							<= '1';
						Device_Address_en				<= '1';
						RegisterAddress_en			<= '1';
						
						NextState								<= ST_SEND_START;
						
					WHEN IO_IIC_CMD_READ_BYTES =>
						Command_en							<= '1';
						Device_Address_en				<= '1';
						RegisterAddress_en			<= '1';
						
						NextState								<= ST_SEND_START;
											
					WHEN IO_IIC_CMD_WRITE_BYTE =>
						Command_en							<= '1';
						Device_Address_en				<= '1';
						RegisterAddress_en			<= '1';
						DataRegister_en					<= '1';
						
						NextState								<= ST_SEND_START;
					
					WHEN IO_IIC_CMD_WRITE_BYTES =>
						Command_en							<= '1';
						Device_Address_en				<= '1';
						RegisterAddress_en			<= '1';
						DataRegister_en					<= '1';
		
						NextState								<= ST_SEND_START;
					
					WHEN OTHERS =>
						NextState								<= ST_ERROR;
						
				END CASE;
			
			WHEN ST_SEND_START =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_START_CONDITION;
				
				NextState										<= ST_SEND_START_WAIT;
				
			WHEN ST_SEND_START_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_DEVICE_ADDRESS0;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_DEVICE_ADDRESS0 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				Device_Address_sh						<= '1';
				IF (Device_Address_d(Device_Address_d'high) = '0') THEN
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				ELSE
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				END IF;
				
				NextState										<= ST_SEND_DEVICE_ADDRESS0_WAIT;
				
			WHEN ST_SEND_DEVICE_ADDRESS0_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>
						BitCounter_en						<= '1';
			
						IF (BitCounter_us = (Device_Address_d'length - 1)) THEN
							NextState							<= ST_SEND_READWRITE0;
						ELSE
							NextState							<= ST_SEND_DEVICE_ADDRESS0;
						END IF;
					WHEN IO_IICBUS_STATUS_ERROR =>		NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>										NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_READWRITE0 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE Command_d IS														-- write = 0; read = 1
					WHEN IO_IIC_CMD_CHECK_ADDRESS =>	IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN IO_IIC_CMD_READ_CURRENT =>		IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN IO_IIC_CMD_READ_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN IO_IIC_CMD_READ_BYTES =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN IO_IIC_CMD_WRITE_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN IO_IIC_CMD_WRITE_BYTES =>		IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN OTHERS  =>										IICBC_Command		<= IO_IICBUS_CMD_NONE;
				END CASE;
				
				NextState										<= ST_SEND_READWRITE0_WAIT;
				
			WHEN ST_SEND_READWRITE0_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_ACK0;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_RECEIVE_ACK0 =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_ACK0_WAIT;
				
			WHEN ST_RECEIVE_ACK0_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '0';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>									NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>
						CASE Command_d IS
							WHEN IO_IIC_CMD_CHECK_ADDRESS =>								NextState			<= ST_SEND_STOP;
							WHEN IO_IIC_CMD_READ_CURRENT =>									NextState			<= ST_RECEIVE_DATA;
							WHEN IO_IIC_CMD_READ_BYTE =>										NextState			<= ST_SEND_REGISTER_ADDRESS;
							WHEN IO_IIC_CMD_READ_BYTES =>										NextState			<= ST_SEND_REGISTER_ADDRESS;
							WHEN IO_IIC_CMD_WRITE_BYTE =>										NextState			<= ST_SEND_REGISTER_ADDRESS;
							WHEN IO_IIC_CMD_WRITE_BYTES =>									NextState			<= ST_SEND_REGISTER_ADDRESS;
							WHEN OTHERS =>																	NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>							NextState			<= ST_ACK_ERROR;
					WHEN IO_IICBUS_STATUS_ERROR =>											NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																			NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_REGISTER_ADDRESS =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
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
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
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
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_ACK1_WAIT;
			
			WHEN ST_RECEIVE_ACK1_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '0';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>						NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>
						CASE Command_d IS
							WHEN IO_IIC_CMD_CHECK_ADDRESS =>					NextState			<= ST_SEND_STOP;
							WHEN IO_IIC_CMD_WRITE_BYTE =>							NextState			<= ST_SEND_DATA;
							WHEN IO_IIC_CMD_WRITE_BYTES =>						NextState			<= ST_SEND_DATA;
							WHEN IO_IIC_CMD_READ_CURRENT =>						NextState			<= ST_ERROR;
							WHEN IO_IIC_CMD_READ_BYTE =>							NextState			<= ST_SEND_RESTART;
							WHEN IO_IIC_CMD_READ_BYTES =>							NextState			<= ST_SEND_RESTART;
							WHEN OTHERS  =>														NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>
						CASE Command_d IS
							WHEN IO_IIC_CMD_CHECK_ADDRESS =>					NextState			<= ST_SEND_STOP;
							WHEN OTHERS =>														NextState			<= ST_ACK_ERROR;
						END CASE;
					WHEN OTHERS =>																NextState			<= ST_ERROR;
				END CASE;

			-- write operation => continue writing
			-- ======================================================================
			WHEN ST_SEND_DATA =>
				Status_i										<= IO_IIC_STATUS_WRITING;
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
				Status_i										<= IO_IIC_STATUS_WRITING;
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
				Status_i										<= IO_IIC_STATUS_WRITING;
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_ACK2_WAIT;
			
			WHEN ST_RECEIVE_ACK2_WAIT =>
				Status_i										<= IO_IIC_STATUS_WRITING;
				BusMaster										<= '1';
				BusMode											<= '0';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>						NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>
						CASE Command_d IS
							WHEN IO_IIC_CMD_WRITE_BYTE =>			NextState			<= ST_SEND_STOP;
							WHEN IO_IIC_CMD_WRITE_BYTES =>
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
				Status_i										<= IO_IIC_STATUS_WRITING;
				DataRegister_en							<= '1';
				
				NextState										<= ST_SEND_DATA;
			
			-- read operation
			-- ======================================================================
			WHEN ST_SEND_RESTART =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_RESTART_CONDITION;
			
				NextState										<= ST_SEND_RESTART_WAIT;
			
			WHEN ST_SEND_RESTART_WAIT =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_DEVICE_ADDRESS1;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;

			WHEN ST_SEND_DEVICE_ADDRESS1 =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				Device_Address_sh					<= '1';
				IF (Device_Address_d(Device_Address_d'high) = '0') THEN
					IICBC_Command							<= IO_IICBUS_CMD_SEND_LOW;
				ELSE
					IICBC_Command							<= IO_IICBUS_CMD_SEND_HIGH;
				END IF;
				
				NextState										<= ST_SEND_DEVICE_ADDRESS1_WAIT;
				
			WHEN ST_SEND_DEVICE_ADDRESS1_WAIT =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				IF (IICBC_Status = IO_IICBUS_STATUS_SENDING) THEN
					NULL;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_SEND_COMPLETE) THEN
					BitCounter_en							<= '1';
			
					IF (BitCounter_us = (Device_Address_d'length - 1)) THEN
						NextState								<= ST_SEND_READWRITE1;
					ELSE
						NextState								<= ST_SEND_DEVICE_ADDRESS1;
					END IF;
				ELSIF (IICBC_Status = IO_IICBUS_STATUS_ERROR) THEN
					NextState									<= ST_BUS_ERROR;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_SEND_READWRITE1 =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE Command_d IS														-- write = 0; read = 1
					WHEN IO_IIC_CMD_WRITE_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_NONE;
					WHEN IO_IIC_CMD_WRITE_BYTES =>		IICBC_Command		<= IO_IICBUS_CMD_NONE;
					WHEN IO_IIC_CMD_READ_CURRENT =>		IICBC_Command		<= IO_IICBUS_CMD_NONE;
					WHEN IO_IIC_CMD_READ_BYTE =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN IO_IIC_CMD_READ_BYTES =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN OTHERS  =>										IICBC_Command		<= IO_IICBUS_CMD_NONE;
				END CASE;
				
				NextState										<= ST_SEND_READWRITE1_WAIT;
				
			WHEN ST_SEND_READWRITE1_WAIT =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_ACK3;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_RECEIVE_ACK3 =>
				Status_i										<= IO_IIC_STATUS_READING;
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_ACK3_WAIT;
			
			WHEN ST_RECEIVE_ACK3_WAIT =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '0';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>						NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>
						CASE Command_d IS
							WHEN IO_IIC_CMD_READ_BYTE =>							NextState			<= ST_RECEIVE_DATA;
							WHEN IO_IIC_CMD_READ_BYTES =>							NextState			<= ST_RECEIVE_DATA;
							WHEN OTHERS =>														NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>				NextState			<= ST_ADDRESS_ERROR;
					WHEN IO_IICBUS_STATUS_ERROR =>								NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_RECEIVE_DATA =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '0';
				IICBC_Command								<= IO_IICBUS_CMD_RECEIVE;
				
				NextState										<= ST_RECEIVE_DATA_WAIT;
			
			WHEN ST_RECEIVE_DATA_WAIT =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '0';
			
				IF (IICBC_Status = IO_IICBUS_STATUS_RECEIVING) THEN
					NULL;
				ELSIF ((IICBC_Status = IO_IICBUS_STATUS_RECEIVED_LOW) OR (IICBC_Status = IO_IICBUS_STATUS_RECEIVED_HIGH)) THEN
					BitCounter_en							<= '1';
					DataRegister_sh						<= '1';
					
					IF (BitCounter_us = 7) THEN
						IF ((Out_LastByte = '1') OR (Command_d = IO_IIC_CMD_READ_BYTE)) THEN
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
				Status_i										<= IO_IIC_STATUS_READING;
				BitCounter_rst							<= '1';
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_LOW;
				
				NextState										<= ST_SEND_ACK_WAIT;
				
			WHEN ST_SEND_ACK_WAIT =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_DATA;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_NACK =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_HIGH;
				
				NextState										<= ST_SEND_NACK_WAIT;
				
			WHEN ST_SEND_NACK_WAIT =>
				Status_i										<= IO_IIC_STATUS_READING;
				BusMaster										<= '1';
				BusMode											<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_STOP;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
				
			WHEN ST_SEND_STOP =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				BusMaster										<= '1';
				BusMode											<= '1';
				IICBC_Command								<= IO_IICBUS_CMD_SEND_STOP_CONDITION;
			
				NextState										<= ST_SEND_STOP_WAIT;
			
			WHEN ST_SEND_STOP_WAIT =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READING,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITING));
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_COMPLETE;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_COMPLETE =>
				Status_i										<= ite((CommandCategory = READ),										IO_IIC_STATUS_READ_COMPLETE,
																			 ite(((CommandCategory /= WRITE) AND SIMULATION),	IO_IIC_STATUS_ERROR,
																																												IO_IIC_STATUS_WRITE_COMPLETE));
				NextState										<= ST_IDLE;
			
			WHEN ST_BUS_ERROR =>
				Status_i										<= IO_IIC_STATUS_ERROR;
				Master_Error								<= IO_IIC_ERROR_BUS_ERROR;
				NextState										<= ST_IDLE;
			
			WHEN ST_ACK_ERROR =>
				Status_i										<= IO_IIC_STATUS_ERROR;
				Master_Error								<= IO_IIC_ERROR_ACK_ERROR;
				NextState										<= ST_IDLE;

			WHEN ST_ADDRESS_ERROR =>
				Status_i										<= IO_IIC_STATUS_ERROR;
				Master_Error								<= IO_IIC_ERROR_ADDRESS_ERROR;
				NextState										<= ST_IDLE;
			
			WHEN ST_ERROR =>
				Status_i										<= IO_IIC_STATUS_ERROR;
				Master_Error								<= IO_IIC_ERROR_FSM;
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

	PROCESS(Clock, IICBC_Status)
		VARIABLE DataRegister_si		: STD_LOGIC;
	BEGIN
		CASE IICBC_Status IS
			WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>			DataRegister_si	:= '0';
			WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>		DataRegister_si	:= '1';
			WHEN OTHERS =>														DataRegister_si	:= 'X';
		END CASE;
	
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				Command_d							<= IO_IIC_CMD_NONE;
				Device_Address_d			<= (OTHERS => '0');
				RegisterAddress_d			<= (OTHERS => '0');
				DataRegister_d				<= (OTHERS => '0');
			ELSE
				IF (Command_en	= '1') THEN
					Command_d						<= Master_Command;
				END IF;
			
				IF (Device_Address_en	= '1') THEN
					Device_Address_d		<= Master_Address;
				ELSIF (Device_Address_sh = '1') THEN
					Device_Address_d		<= Device_Address_d(Device_Address_d'high - 1 DOWNTO 0) & Device_Address_d(Device_Address_d'high);
				END IF;
				
				IF (RegisterAddress_en	= '1') THEN
					RegisterAddress_d		<= RegisterAddress;
				ELSIF (RegisterAddress_sh = '1') THEN
					RegisterAddress_d		<= RegisterAddress_d(RegisterAddress_d'high - 1 DOWNTO 0) & ite(SIMULATION, 'U', '0');
				END IF;
				
				IF (DataRegister_en	= '1') THEN
					DataRegister_d			<= Master_WP_Data;
				ELSIF (DataRegister_sh = '1') THEN
					DataRegister_d			<= DataRegister_d(DataRegister_d'high - 1 DOWNTO 0) & DataRegister_si;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Master_Status		<= Status_i;
	Out_Data				<= DataRegister_d;

	IICBC : ENTITY PoC.IICBusController
		GENERIC MAP (
			CLOCK_FREQ_MHZ								=> CLOCK_IN_FREQ_MHZ,
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

	genDBG : IF (DEBUG = TRUE) GENERATE
		-- Configuration
		CONSTANT DBG_TRIGGER_DELAY		: POSITIVE		:= 4;
		CONSTANT DBG_TRIGGER_WINDOWS	: POSITIVE		:= 6;

		
		CONSTANT STATES		: POSITIVE		:= T_STATE'pos(ST_ERROR) + 1;
		CONSTANT BITS			: POSITIVE		:= log2ceilnz(STATES);
	
		FUNCTION to_slv(State : T_STATE) RETURN STD_LOGIC_VECTOR IS
		BEGIN
			RETURN to_slv(T_STATE'pos(State), BITS);
		END FUNCTION;
	
		-- debugging signals
		TYPE T_DBG_CHIPSCOPE IS RECORD
			Command						: T_IO_IIC_COMMAND;
			Status						: T_IO_IIC_STATUS;
			Device_Address		: STD_LOGIC_VECTOR(6 DOWNTO 0);
			RegisterAddress		: T_SLV_8;
			DataIn						: T_SLV_8;
			DataOut						: T_SLV_8;
			State							: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
			IICBC_Command			: T_IO_IICBUS_COMMAND;
			IICBC_Status			: T_IO_IICBUS_STATUS;
			Clock_i						: STD_LOGIC;
			Clock_t						: STD_LOGIC;
			Data_i						: STD_LOGIC;
			Data_t						: STD_LOGIC;
		END RECORD;
		
		TYPE T_DBG_CHIPSCOPE_VECTOR	IS ARRAY(NATURAL RANGE <>) OF T_DBG_CHIPSCOPE;
		
		SIGNAL DBG_DebugVector_d		: T_DBG_CHIPSCOPE_VECTOR(DBG_TRIGGER_DELAY DOWNTO 0);
		
		-- edge detection FFs
		SIGNAL SerialClock_t_d			: STD_LOGIC																					:= '0';
		SIGNAL SerialData_t_d				: STD_LOGIC																					:= '0';
		
		-- trigger delay FFs / trigger valid-window FF
		SIGNAL Trigger_d						: STD_LOGIC_VECTOR(DBG_TRIGGER_WINDOWS DOWNTO 0)		:= (OTHERS => '0');
		SIGNAL Valid_r							: STD_LOGIC																					:= '0';
		
		-- ChipScope trigger signals
		SIGNAL DBG_Trigger					: STD_LOGIC;
		SIGNAL DBG_Valid						: STD_LOGIC;

		-- ChipScope data signals
		SIGNAL DBG_Command					: T_IO_IIC_COMMAND;
		SIGNAL DBG_Status						: T_IO_IIC_STATUS;
		SIGNAL DBG_Device_Address		: STD_LOGIC_VECTOR(ADDRESS_BITS DOWNTO 0);
		SIGNAL DBG_RegisterAddress	: T_SLV_8;
		SIGNAL DBG_DataIn						: T_SLV_8;
		SIGNAL DBG_DataOut					: T_SLV_8;
		SIGNAL DBG_State						: STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
		SIGNAL DBG_IICBC_Command		: T_IO_IICBUS_COMMAND;
		SIGNAL DBG_IICBC_Status			: T_IO_IICBUS_STATUS;
		SIGNAL DBG_Clock_i					: STD_LOGIC;
		SIGNAL DBG_Clock_t					: STD_LOGIC;
		SIGNAL DBG_Data_i						: STD_LOGIC;
		SIGNAL DBG_Data_t						: STD_LOGIC;
		
--		CONSTANT DBG_temp						: STD_LOGIC_VECTOR		:= to_slv(ST_SEND_REGISTER_ADDRESS_WAIT);
		
		ATTRIBUTE KEEP OF DBG_Command					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_Status					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_Device_Address	: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_RegisterAddress	: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_DataIn					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_DataOut					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_State						: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_IICBC_Command		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_IICBC_Status		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_Clock_i					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_Clock_t					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_Data_i					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_Data_t					: SIGNAL IS TRUE;
		
		ATTRIBUTE KEEP OF DBG_Trigger					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_Valid						: SIGNAL IS TRUE;
		
	BEGIN
		DBG_DebugVector_d(0).Command					<= Master_Command;
		DBG_DebugVector_d(0).Status						<= Status_i;
		DBG_DebugVector_d(0).Device_Address		<= Master_Address;
		DBG_DebugVector_d(0).RegisterAddress	<= RegisterAddress;
		DBG_DebugVector_d(0).DataIn						<= Master_WP_Data;
		DBG_DebugVector_d(0).DataOut					<= DataRegister_d;
		DBG_DebugVector_d(0).State						<= to_slv(State);
		DBG_DebugVector_d(0).IICBC_Command		<= IICBC_Command;
		DBG_DebugVector_d(0).IICBC_Status			<= IICBC_Status;
		DBG_DebugVector_d(0).Clock_i					<= SerialClock_i;
		DBG_DebugVector_d(0).Clock_t					<= SerialClock_t_i;
		DBG_DebugVector_d(0).Data_i						<= SerialData_i;
		DBG_DebugVector_d(0).Data_t						<= SerialData_t_i;
	
		genDataDelay : FOR I IN 0 TO DBG_DebugVector_d'high - 1 GENERATE
			DBG_DebugVector_d(I + 1)	<= DBG_DebugVector_d(I) WHEN rising_edge(Clock);
		END GENERATE;
		
		DBG_Command						<= DBG_DebugVector_d(DBG_DebugVector_d'high).Command;
		DBG_Status						<= DBG_DebugVector_d(DBG_DebugVector_d'high).Status;
		DBG_Device_Address		<= DBG_DebugVector_d(DBG_DebugVector_d'high).Device_Address;
		DBG_RegisterAddress		<= DBG_DebugVector_d(DBG_DebugVector_d'high).RegisterAddress;
		DBG_DataIn						<= DBG_DebugVector_d(DBG_DebugVector_d'high).DataIn;
		DBG_DataOut						<= DBG_DebugVector_d(DBG_DebugVector_d'high).DataOut;
		DBG_State							<= DBG_DebugVector_d(DBG_DebugVector_d'high).State;
		DBG_IICBC_Command			<= DBG_DebugVector_d(DBG_DebugVector_d'high).IICBC_Command;
		DBG_IICBC_Status			<= DBG_DebugVector_d(DBG_DebugVector_d'high).IICBC_Status;
		DBG_Clock_i						<= DBG_DebugVector_d(DBG_DebugVector_d'high).Clock_i;
		DBG_Clock_t						<= DBG_DebugVector_d(DBG_DebugVector_d'high).Clock_t;
		DBG_Data_i						<= DBG_DebugVector_d(DBG_DebugVector_d'high).Data_i;
		DBG_Data_t						<= DBG_DebugVector_d(DBG_DebugVector_d'high).Data_t;
		
		SerialClock_t_d				<= SerialClock_t_i		WHEN rising_edge(Clock);
		SerialData_t_d				<= SerialData_t_i			WHEN rising_edge(Clock);
		
		-- trigger on all edges and on all signal lines
		Trigger_d(0)					<= (SerialClock_t_i XOR SerialClock_t_d) OR
														 (SerialData_t_i	XOR SerialData_t_d);
		
		genTriggerDelay : FOR I IN 0 TO Trigger_d'high - 1 GENERATE
			Trigger_d(I + 1)		<= Trigger_d(I) WHEN rising_edge(Clock);
		END GENERATE;
		
		DBG_Trigger						<= Trigger_d(DBG_TRIGGER_DELAY);
		DBG_Valid							<= Trigger_d(0) OR Valid_r;
		
		--											RS-FF:	Q					RST						SET								CLOCK
		Valid_r								<= ffrs(Valid_r, DBG_Trigger, Trigger_d(0)) WHEN rising_edge(Clock);
	END GENERATE;
END;
