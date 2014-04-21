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
USE			PoC.vectors.ALL;
USE			PoC.io.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalComp.ALL;


ENTITY IICController IS
	GENERIC (
		DEBUG													: BOOLEAN												:= TRUE;
		CLOCK_FREQ_MHZ								: REAL													:= 100.0;					-- 100 MHz
		IIC_BUSMODE										: T_IO_IIC_BUSMODE							:= IO_IIC_BUSMODE_STANDARDMODE;
		IIC_ADDRESS										: STD_LOGIC_VECTOR							:= (7 DOWNTO 1 => '0') & '-';
		ADDRESS_BITS									: POSITIVE											:= 7;
		DATA_BITS											: POSITIVE											:= 8;
		ALLOW_MEALY_TRANSITION				: BOOLEAN												:= TRUE
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
	
	CONSTANT SMBUS_COMPLIANCE				: BOOLEAN				:= (IIC_BUSMODE = IO_IIC_BUSMODE_SMBUS);
	
	-- if-then-else (ite)
	FUNCTION ite(cond : BOOLEAN; value1 : T_IO_IIC_STATUS; value2 : T_IO_IIC_STATUS) RETURN T_IO_IIC_STATUS IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END;
	
	FUNCTION to_IICBus_Command(value : STD_LOGIC) RETURN T_IO_IICBUS_COMMAND IS
	BEGIN
		CASE value IS
			WHEN '0' =>			RETURN IO_IICBUS_CMD_SEND_LOW;
			WHEN '1' =>			RETURN IO_IICBUS_CMD_SEND_HIGH;
			WHEN OTHERS =>	RETURN IO_IICBUS_CMD_NONE;
		END CASE;
	END;
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_REQUEST,
		ST_SAVE_ADDRESS,
		ST_SEND_START,							ST_SEND_START_WAIT,
		-- device address transmission 0
			ST_SEND_DEVICE_ADDRESS0,		ST_SEND_DEVICE_ADDRESS0_WAIT,
			ST_SEND_READWRITE0,					ST_SEND_READWRITE0_WAIT,
			ST_RECEIVE_ACK0,						ST_RECEIVE_ACK0_WAIT,
		-- send byte(s) operation => continue with data bytes
			ST_SEND_DATA1,							ST_SEND_DATA1_WAIT,
			ST_RECEIVE_ACK1,						ST_RECEIVE_ACK1_WAIT,
		-- receive byte(s) operation => continue with data bytes
			ST_RECEIVE_DATA2,						ST_RECEIVE_DATA2_WAIT,
			ST_SEND_ACK2,								ST_SEND_ACK2_WAIT,
			ST_SEND_NACK2,							ST_SEND_NACK2_WAIT,
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
	SIGNAL Error_i											: T_IO_IIC_ERROR;
	
	SIGNAL Command_en										: STD_LOGIC;
	SIGNAL Command_d										: T_IO_IIC_COMMAND								:= IO_IIC_CMD_NONE;
	
	SIGNAL IICBC_Request								: STD_LOGIC;
	SIGNAL IICBC_Grant									: STD_LOGIC;
	SIGNAL IICBC_BusMaster							: STD_LOGIC;
	SIGNAL IICBC_BusMode								: STD_LOGIC;
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
	
	SIGNAL LastRegister_en							: STD_LOGIC;
	SIGNAL LastRegister_d								: STD_LOGIC												:= '0';

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

	PROCESS(State, Master_Request, Master_Command, Command_d, IICBC_Grant, IICBC_Status, BitCounter_us, Device_Address_d, DataRegister_d, LastRegister_d)
		TYPE T_CMDCAT IS (NONE, SENDING, RECEIVING, EXECUTING, CALLING);
		VARIABLE CommandCategory	: T_CMDCAT;
	
	BEGIN
		NextState									<= State;

		Status_i									<= IO_IIC_STATUS_IDLE;
		Error_i										<= IO_IIC_ERROR_NONE;
		
		Master_Grant							<= '0';
		
		Master_WP_Ack							<= '0';
		Master_RP_Valid						<= '0';
		Master_RP_Last						<= '0';

		Command_en								<= '0';
		Device_Address_en					<= '0';
		DataRegister_en						<= '0';
		LastRegister_en						<= '0';

		Device_Address_sh					<= '0';
		DataRegister_sh						<= '0';
		
		BitCounter_rst						<= '0';
		BitCounter_en							<= '0';

		IICBC_Request							<= '0';
		IICBC_BusMaster						<= '0';
		IICBC_BusMode							<= '0';
		IICBC_Command							<= IO_IICBUS_CMD_NONE;

		-- precalculated command categories
		CASE Command_d IS
			WHEN IO_IIC_CMD_NONE =>									CommandCategory := NONE;
			WHEN IO_IIC_CMD_QUICKCOMMAND_READ =>		CommandCategory := EXECUTING;
			WHEN IO_IIC_CMD_QUICKCOMMAND_WRITE =>		CommandCategory := EXECUTING;
			WHEN IO_IIC_CMD_SEND_BYTES =>						CommandCategory := SENDING;
			WHEN IO_IIC_CMD_RECEIVE_BYTES =>				CommandCategory := RECEIVING;
			WHEN IO_IIC_CMD_PROCESS_CALL =>					CommandCategory := CALLING;
			WHEN OTHERS =>													CommandCategory := NONE;
		END CASE;

		CASE State IS
			WHEN ST_IDLE =>
				Status_i												<= IO_IIC_STATUS_IDLE;
				
				IF (Master_Request = '1') THEN
					NextState											<= ST_REQUEST;
					
					IF ALLOW_MEALY_TRANSITION THEN
						IICBC_Request								<= '1';
						
						IF (IICBC_Grant = '1') THEN
							Master_Grant							<= '1';
							NextState									<= ST_SAVE_ADDRESS;
						END IF;
					END IF;
				END IF;
			
			WHEN ST_REQUEST =>
				IICBC_Request										<= '1';
			
				IF (IICBC_Grant = '1') THEN
					Master_Grant									<= '1';
					NextState											<= ST_SAVE_ADDRESS;
				END IF;
			
			WHEN ST_SAVE_ADDRESS =>
				Master_Grant										<= IICBC_Grant;
				Status_i												<= IO_IIC_STATUS_IDLE;
				IICBC_Request										<= '1';
							
				CASE Master_Command IS
					WHEN IO_IIC_CMD_NONE =>
						NULL;
					
					WHEN IO_IIC_CMD_QUICKCOMMAND_READ =>
						Command_en									<= '1';
						Device_Address_en						<= '1';
						
						NextState										<= ST_SEND_START;
					
					WHEN IO_IIC_CMD_QUICKCOMMAND_WRITE =>
						Command_en									<= '1';
						Device_Address_en						<= '1';
						
						NextState										<= ST_SEND_START;
				
					WHEN IO_IIC_CMD_SEND_BYTES =>
						Command_en									<= '1';
						Device_Address_en						<= '1';
						DataRegister_en							<= '1';
						LastRegister_en							<= '1';
						Master_WP_Ack								<= '1';
						
						NextState										<= ST_SEND_START;
						
					WHEN IO_IIC_CMD_RECEIVE_BYTES =>
						Command_en									<= '1';
						Device_Address_en						<= '1';
						
						NextState										<= ST_SEND_START;
											
					WHEN IO_IIC_CMD_PROCESS_CALL =>
						Command_en									<= '1';
						Device_Address_en						<= '1';
						DataRegister_en							<= '1';
						LastRegister_en							<= '1';
						Master_WP_Ack								<= '1';
						
						NextState										<= ST_SEND_START;
					
					WHEN OTHERS =>
						NextState										<= ST_ERROR;
						
				END CASE;
			
			WHEN ST_SEND_START =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_SEND_START_CONDITION;
					
				NextState												<= ST_SEND_START_WAIT;
				
			WHEN ST_SEND_START_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_DEVICE_ADDRESS0;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_DEVICE_ADDRESS0 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				IICBC_Command										<= to_IICBus_Command(Device_Address_d(Device_Address_d'high));
				Device_Address_sh								<= '1';
				
				NextState												<= ST_SEND_DEVICE_ADDRESS0_WAIT;
				
			WHEN ST_SEND_DEVICE_ADDRESS0_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>
						BitCounter_en								<= '1';
			
						IF (BitCounter_us = (Device_Address_d'length - 1)) THEN
							NextState									<= ST_SEND_READWRITE0;
						ELSE
							NextState									<= ST_SEND_DEVICE_ADDRESS0;
						END IF;
					WHEN IO_IICBUS_STATUS_ERROR =>		NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>										NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_READWRITE0 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE Command_d IS														-- write = 0; read = 1
					WHEN IO_IIC_CMD_QUICKCOMMAND_READ =>	IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN IO_IIC_CMD_QUICKCOMMAND_WRITE =>	IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN IO_IIC_CMD_SEND_BYTES =>					IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN IO_IIC_CMD_RECEIVE_BYTES =>			IICBC_Command		<= IO_IICBUS_CMD_SEND_HIGH;
					WHEN IO_IIC_CMD_PROCESS_CALL =>				IICBC_Command		<= IO_IICBUS_CMD_SEND_LOW;
					WHEN OTHERS  =>												IICBC_Command		<= IO_IICBUS_CMD_NONE;
				END CASE;
				
				NextState												<= ST_SEND_READWRITE0_WAIT;
				
			WHEN ST_SEND_READWRITE0_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_ACK0;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_RECEIVE_ACK0 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				BitCounter_rst									<= '1';
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_RECEIVE;
				
				NextState												<= ST_RECEIVE_ACK0_WAIT;
				
			WHEN ST_RECEIVE_ACK0_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>									NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>								-- ACK
						CASE Command_d IS
							WHEN IO_IIC_CMD_QUICKCOMMAND_WRITE =>						NextState			<= ST_SEND_STOP;
							WHEN IO_IIC_CMD_QUICKCOMMAND_READ =>						NextState			<= ST_SEND_STOP;
							WHEN IO_IIC_CMD_SEND_BYTES =>										NextState			<= ST_SEND_DATA1;
							WHEN IO_IIC_CMD_RECEIVE_BYTES =>								NextState			<= ST_RECEIVE_DATA2;
							WHEN IO_IIC_CMD_PROCESS_CALL =>									NextState			<= ST_SEND_DATA1;
							WHEN OTHERS =>																	NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>							-- NACK
						IF (SMBUS_COMPLIANCE = TRUE) THEN
																															NextState			<= ST_ACK_ERROR;			-- TODO: send stop
						ELSE
							CASE Command_d IS
								WHEN IO_IIC_CMD_QUICKCOMMAND_WRITE =>					NextState			<= ST_ADDRESS_ERROR;	-- TODO: send stop
								WHEN IO_IIC_CMD_QUICKCOMMAND_READ =>					NextState			<= ST_ADDRESS_ERROR;	-- TODO: send stop
								WHEN IO_IIC_CMD_SEND_BYTES =>									NextState			<= ST_ADDRESS_ERROR;	-- TODO: send stop
								WHEN IO_IIC_CMD_RECEIVE_BYTES =>							NextState			<= ST_ADDRESS_ERROR;	-- TODO: send stop
								WHEN IO_IIC_CMD_PROCESS_CALL =>								NextState			<= ST_ADDRESS_ERROR;	-- TODO: send stop
								WHEN OTHERS =>																NextState			<= ST_ERROR;
							END CASE;
						END IF;
					WHEN IO_IICBUS_STATUS_ERROR =>											NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																			NextState			<= ST_ERROR;
				END CASE;

			-- write operation => continue writing
			-- ======================================================================
			WHEN ST_SEND_DATA1 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				IICBC_Command										<= to_IICBus_Command(DataRegister_d(DataRegister_d'high));
				DataRegister_sh									<= '1';
				
				NextState												<= ST_SEND_DATA1_WAIT;
				
			WHEN ST_SEND_DATA1_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';

				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>
						BitCounter_en								<= '1';
			
						IF (BitCounter_us = (DataRegister_d'length - 1)) THEN
							NextState									<= ST_SEND_DATA1;
						ELSE
							NextState									<= ST_RECEIVE_ACK1;
						END IF;
					WHEN IO_IICBUS_STATUS_ERROR =>		NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>										NextState			<= ST_ERROR;
				END CASE;
				
			WHEN ST_RECEIVE_ACK1 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				BitCounter_rst									<= '1';
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_RECEIVE;
				
				NextState												<= ST_RECEIVE_ACK1_WAIT;
				
			WHEN ST_RECEIVE_ACK1_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>									NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>								-- ACK
						IF (LastRegister_d = '1') THEN										-- no more byte to be send?
							CASE Command_d IS
								WHEN IO_IIC_CMD_SEND_BYTES =>		NextState	<= ST_SEND_STOP;			-- command complete, free bus
								WHEN IO_IIC_CMD_PROCESS_CALL =>	NextState	<= ST_SEND_RESTART3;	-- bus turnaround
								WHEN OTHERS =>									NextState	<= ST_ERROR;
							END CASE;
						ELSE																							-- register next byte
							DataRegister_en		<= '1';
							LastRegister_en		<= '1';
								
							NextState					<= ST_SEND_DATA1;
						END IF;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>							-- NACK
						CASE Command_d IS
							WHEN IO_IIC_CMD_SEND_BYTES =>										NextState			<= ST_ACK_ERROR;				-- TODO: send stop
							WHEN IO_IIC_CMD_PROCESS_CALL =>									NextState			<= ST_ACK_ERROR;				-- TODO: send stop
							WHEN OTHERS =>																	NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_ERROR =>											NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																			NextState			<= ST_ERROR;
				END CASE;


			-- read operation => continue with reading without restart
			-- ======================================================================
			WHEN ST_RECEIVE_DATA2 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_RECEIVE;
				
				NextState												<= ST_RECEIVE_DATA2_WAIT;
				
			WHEN ST_RECEIVE_DATA2_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>									NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW | IO_IICBUS_STATUS_RECEIVED_HIGH =>		-- LOW or HIGH
						BitCounter_en								<= '1';
						DataRegister_sh							<= '1';
					
						IF (BitCounter_us = (DataRegister_d'length - 1)) THEN										-- current byte is full

-- FIXME: if receive abort is wished => send NACK
--
--							IF ((Out_LastByte = '1') OR (Command_d = IO_IIC_CMD_READ_BYTE)) THEN
--								NextState								<= ST_SEND_NACK2;
--							ELSE
								NextState								<= ST_SEND_ACK2;
--							END IF;
						ELSE
							NextState									<= ST_RECEIVE_DATA2;
						END IF;
					WHEN IO_IICBUS_STATUS_ERROR =>											NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																			NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_ACK2 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				BitCounter_rst									<= '1';
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_SEND_LOW;			-- ACK
				
				NextState												<= ST_SEND_ACK2_WAIT;
				
			WHEN ST_SEND_ACK2_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_DATA2;			-- receive more bytes
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_NACK2 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				BitCounter_rst									<= '1';
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_SEND_HIGH;			-- NACK
				
				NextState												<= ST_SEND_NACK2_WAIT;
				
			WHEN ST_SEND_NACK2_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_STOP;			-- receiving complete, free bus
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
	

			-- read operation after restart => continue with reading
			-- ======================================================================
			WHEN ST_SEND_RESTART3 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_SEND_RESTART_CONDITION;
					
				NextState												<= ST_SEND_RESTART3_WAIT;
				
			WHEN ST_SEND_RESTART3_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_DEVICE_ADDRESS3;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_DEVICE_ADDRESS3 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				IICBC_Command										<= to_IICBus_Command(Device_Address_d(Device_Address_d'high));
				Device_Address_sh								<= '1';
				
				NextState												<= ST_SEND_DEVICE_ADDRESS3_WAIT;
				
			WHEN ST_SEND_DEVICE_ADDRESS3_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>
						BitCounter_en								<= '1';
			
						IF (BitCounter_us = (Device_Address_d'length - 1)) THEN
							NextState									<= ST_SEND_READWRITE3;
						ELSE
							NextState									<= ST_SEND_DEVICE_ADDRESS3;
						END IF;
					WHEN IO_IICBUS_STATUS_ERROR =>		NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>										NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_READWRITE3 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_SEND_HIGH;			-- 1 = read
				
				NextState												<= ST_SEND_READWRITE3_WAIT;
				
			WHEN ST_SEND_READWRITE3_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_ACK3;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_RECEIVE_ACK3 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				BitCounter_rst									<= '1';
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_RECEIVE;
				
				NextState												<= ST_RECEIVE_ACK3_WAIT;
				
			WHEN ST_RECEIVE_ACK3_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>									NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW =>								-- ACK
						CASE Command_d IS
							WHEN IO_IIC_CMD_PROCESS_CALL =>									NextState			<= ST_RECEIVE_DATA3;
							WHEN OTHERS =>																	NextState			<= ST_ERROR;
						END CASE;
					WHEN IO_IICBUS_STATUS_RECEIVED_HIGH =>							-- NACK
						IF (SMBUS_COMPLIANCE = TRUE) THEN
																															NextState			<= ST_ACK_ERROR;			-- TODO: send stop
						ELSE
							CASE Command_d IS
								WHEN IO_IIC_CMD_PROCESS_CALL =>								NextState			<= ST_ADDRESS_ERROR;	-- TODO: send stop
								WHEN OTHERS =>																NextState			<= ST_ERROR;
							END CASE;
						END IF;
					WHEN IO_IICBUS_STATUS_ERROR =>											NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																			NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_RECEIVE_DATA3 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_RECEIVE;
				
				NextState												<= ST_RECEIVE_DATA3_WAIT;
				
			WHEN ST_RECEIVE_DATA3_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
			
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_RECEIVING =>									NULL;
					WHEN IO_IICBUS_STATUS_RECEIVED_LOW | IO_IICBUS_STATUS_RECEIVED_HIGH =>		-- LOW or HIGH
						BitCounter_en								<= '1';
						DataRegister_sh							<= '1';
					
						IF (BitCounter_us = (DataRegister_d'length - 1)) THEN										-- current byte is full

-- FIXME: if receive abort is wished => send NACK
--
--							IF ((Out_LastByte = '1') OR (Command_d = IO_IIC_CMD_READ_BYTE)) THEN
--								NextState								<= ST_SEND_NACK3;
--							ELSE
								NextState								<= ST_SEND_ACK3;
--							END IF;
						ELSE
							NextState									<= ST_RECEIVE_DATA3;
						END IF;
					WHEN IO_IICBUS_STATUS_ERROR =>											NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>																			NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_ACK3 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				BitCounter_rst									<= '1';
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_SEND_LOW;			-- ACK
				
				NextState												<= ST_SEND_ACK3_WAIT;
				
			WHEN ST_SEND_ACK3_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_RECEIVE_DATA3;			-- receive more bytes
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_NACK3 =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				BitCounter_rst									<= '1';
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_SEND_HIGH;			-- NACK
				
				NextState												<= ST_SEND_NACK3_WAIT;
				
			WHEN ST_SEND_NACK3_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_SEND_STOP;			-- receiving complete, free bus
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;

			WHEN ST_SEND_STOP =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				IICBC_Command										<= IO_IICBUS_CMD_SEND_STOP_CONDITION;
					
				NextState												<= ST_SEND_STOP_WAIT;
				
			WHEN ST_SEND_STOP_WAIT =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTING;
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SENDING;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVING;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALLING;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;
				
				IICBC_Request										<= '1';
				
				CASE IICBC_Status IS
					WHEN IO_IICBUS_STATUS_SENDING =>					NULL;
					WHEN IO_IICBUS_STATUS_SEND_COMPLETE =>		NextState			<= ST_COMPLETE;
					WHEN IO_IICBUS_STATUS_ERROR =>						NextState			<= ST_BUS_ERROR;
					WHEN OTHERS =>														NextState			<= ST_ERROR;
				END CASE;

-- ======================================================================

			WHEN ST_COMPLETE =>
				Master_Grant										<= IICBC_Grant;
				CASE CommandCategory IS
					WHEN EXECUTING =>		Status_i	<= IO_IIC_STATUS_EXECUTE_OK;		-- TODO: IO_IIC_STATUS_EXECUTE_ERROR
					WHEN SENDING =>			Status_i	<= IO_IIC_STATUS_SEND_COMPLETE;
					WHEN RECEIVING =>		Status_i	<= IO_IIC_STATUS_RECEIVE_COMPLETE;
					WHEN CALLING =>			Status_i	<= IO_IIC_STATUS_CALL_COMPLETE;
					WHEN OTHERS =>			Status_i	<= ite(SIMULATION, IO_IIC_STATUS_ERROR, IO_IIC_STATUS_IDLE);
				END CASE;

				IICBC_Request										<= '1';

				NextState												<= ST_IDLE;
			
			WHEN ST_BUS_ERROR =>
				Status_i												<= IO_IIC_STATUS_ERROR;
				Error_i													<= IO_IIC_ERROR_BUS_ERROR;
				
				-- FIXME: free bus ???
				
				NextState												<= ST_IDLE;
			
			WHEN ST_ACK_ERROR =>
				Status_i												<= IO_IIC_STATUS_ERROR;
				Error_i													<= IO_IIC_ERROR_ACK_ERROR;
				
				-- FIXME: free bus !
				
				NextState												<= ST_IDLE;

			WHEN ST_ADDRESS_ERROR =>
				Status_i												<= IO_IIC_STATUS_ERROR;
				Error_i													<= IO_IIC_ERROR_ADDRESS_ERROR;
				
				-- FIXME: free bus !
				
				NextState												<= ST_IDLE;
			
			WHEN ST_ERROR =>
				Status_i												<= IO_IIC_STATUS_ERROR;
				Error_i													<= IO_IIC_ERROR_FSM;
				NextState												<= ST_IDLE;
			
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
				
				IF (DataRegister_en	= '1') THEN
					DataRegister_d			<= Master_WP_Data;
				ELSIF (DataRegister_sh = '1') THEN
					DataRegister_d			<= DataRegister_d(DataRegister_d'high - 1 DOWNTO 0) & DataRegister_si;
				END IF;
				
				IF (LastRegister_en	= '1') THEN
					LastRegister_d			<= Master_WP_Last;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Master_Status		<= Status_i;
	Master_Error		<= Error_i;
	
	Master_RP_Data	<= DataRegister_d;

	IICBC : ENTITY PoC.IICBusController
		GENERIC MAP (
			CLOCK_FREQ_MHZ								=> CLOCK_FREQ_MHZ,
			IIC_BUSMODE										=> IIC_BUSMODE,
			ALLOW_MEALY_TRANSITION				=> ALLOW_MEALY_TRANSITION
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			Request												=> IICBC_Request,
			Grant													=> IICBC_Grant,
			
			Command												=> IICBC_Command,
			Status												=> IICBC_Status,

--			BusMaster											=> IICBC_BusMaster,
--			BusMode												=> IICBC_BusMode,											-- 0 = passive; 1 = active
			
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

--		CONSTANT STATES		: POSITIVE		:= T_STATE'pos(ST_ERROR) + 1;
--		CONSTANT BITS			: POSITIVE		:= log2ceilnz(STATES);
		CONSTANT BITS			: POSITIVE		:= log2ceil(T_STATE'pos(T_STATE'high));
	
		FUNCTION to_slv(State : T_STATE) RETURN STD_LOGIC_VECTOR IS
		BEGIN
			RETURN to_slv(T_STATE'pos(State), BITS);
		END FUNCTION;
	
		-- debugging signals
		TYPE T_DBG_CHIPSCOPE IS RECORD
			Command						: T_IO_IIC_COMMAND;
			Status						: T_IO_IIC_STATUS;
			Device_Address		: STD_LOGIC_VECTOR(6 DOWNTO 0);
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
