-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

LIBRARY	PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
USE			PoC.io.ALL;
USE			PoC.lcd.ALL;


ENTITY lcd_LCDController_KS0066U IS
	GENERIC (
		SPEEDUP_SIMULATION				: BOOLEAN												:= TRUE;
		CLOCK_FREQ_MHZ						: REAL													:= 125.0;					-- 125 MHz
		LCD_BUS_BITS							: POSITIVE											:= 4
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		Command										: IN	T_IO_LCD_COMMAND;
		Status										: OUT	T_IO_LCD_STATUS;
		
		DataOut										: OUT	T_SLV_8;
		
		LCD_BusEnable							: OUT	STD_LOGIC;
		LCD_ReadWrite							: OUT	STD_LOGIC;
		LCD_RegisterSelect				: OUT	STD_LOGIC;
		LCD_Data_i								: IN	STD_LOGIC_VECTOR(7 DOWNTO (8 - LCD_BUS_BITS));
		LCD_Data_o								: OUT	STD_LOGIC_VECTOR(7 DOWNTO (8 - LCD_BUS_BITS));
		LCD_Data_t								: OUT	STD_LOGIC_VECTOR(7 DOWNTO (8 - LCD_BUS_BITS))
	);
END;

ARCHITECTURE rtl OF lcd_LCDController_KS0066U IS
	ATTRIBUTE KEEP														: BOOLEAN;
	ATTRIBUTE FSM_ENCODING										: STRING;
	
	TYPE T_STATE IS (
		ST_RESET,
		-- initialization
			ST_INIT_SET_FUNCTION,		ST_INIT_SET_FUNCTION_WAIT,
			ST_INIT_DISPLAY_ON,			ST_INIT_DISPLAY_ON_WAIT,
			ST_INIT_DISPLAY_CLEAR,	ST_INIT_DISPLAY_CLEAR_WAIT,
			ST_INIT_SET_ENTRY_MODE,	ST_INIT_SET_ENTRY_MODE_WAIT,
		ST_IDLE,
		ST_GO_HOME,			ST_GO_HOME_WAIT,
		ST_WRITE_CHAR,	ST_WRITE_CHAR_WAIT,
		
		ST_ERROR
	);
	
	SIGNAL State				: T_STATE						:= ST_INIT;
	SIGNAL NextState		: T_STATE;
	
BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_INIT;
			ELSE
				State			: NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Strobe, ReadWrite)
	BEGIN
		NextState										<= State;
	
		Status											<= LCD_CTRL_STATUS_IDLE;
	
		FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_NONE;
		FSM_LCDBC_RegisterAddress		<= '0';
		FSM_LCDBC_Data							<= KS0066U_CMD_NONE;
	
		CASE State IS
			WHEN ST_RESET =>
				IF (LCDBC_Status = IO_LCDBUS_STATUS_IDLE) THEN
					NextState									<= ST_INIT_SET_FUNCTION;
				END IF;
			
			-- set function
			-- ===============================
			WHEN ST_INIT_SET_FUNCTION =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_WRITE;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				FSM_LCDBC_Data							<= KS0066U_CMD_SET_FUNCTION;
				
				NextState										<= ST_INIT_SET_FUNCTION_WAIT;
			
			WHEN ST_INIT_SET_FUNCTION_WAIT =>
				IF (LCDBC_Status = IO_LCDBUS_STATUS_WRITING) THEN
					NULL;
				ELSIF (LCDBC_Status = IO_LCDBUS_STATUS_WRITE_COMPLETE) THEN
					NextState									<= ST_INIT_SET_FUNCTION_POLL_LCDBUS;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_INIT_SET_FUNCTION_POLL_LCDBUS =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_READ;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				
				NextState										<= ST_INIT_SET_FUNCTION_POLL_LCDBUS_WAIT;
			
			WHEN ST_INIT_SET_FUNCTION_POLL_LCDBUS_WAIT =>
				IF (LCDBC_Status = IO_LCDBUS_STATUS_READING) THEN
					NULL;
				ELSIF (LCDBC_Status = IO_LCDBUS_STATUS_READ_COMPLETE) THEN
					IF (LCDBC_Data(7) = '0') THEN
						NextState								<= ST_INIT_SET_FUNCTION_POLL_LCDBUS;
					ELSE
						NextState								<= ST_INIT_DISPLAY_ON;
					END IF;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			-- display on
			-- ===============================
			WHEN ST_INIT_DISPLAY_ON =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_WRITE;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				FSM_LCDBC_Data							<= KS0066U_CMD_DISPLAY_ON;
				
				NextState										<= ST_INIT_DISPLAY_ON_WAIT;
			
			WHEN ST_INIT_DISPLAY_ON_WAIT =>
				IF (LCDBC_Status = IO_LCDBUS_STATUS_WRITING) THEN
					NULL;
				ELSIF (LCDBC_Status = IO_LCDBUS_STATUS_WRITE_COMPLETE) THEN
					NextState									<= ST_INIT_DISPLAY_ON_POLL_LCDBUS;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_INIT_DISPLAY_ON_POLL_LCDBUS =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_READ;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				
				NextState										<= ST_INIT_DISPLAY_ON_POLL_LCDBUS_WAIT;
			
			WHEN ST_INIT_DISPLAY_ON_POLL_LCDBUS_WAIT =>
				IF (LCDBC_Status = IO_LCDBUS_STATUS_READING) THEN
					NULL;
				ELSIF (LCDBC_Status = IO_LCDBUS_STATUS_READ_COMPLETE) THEN
					IF (LCDBC_Data(7) = '0') THEN
						NextState								<= ST_INIT_DISPLAY_ON_POLL_LCDBUS;
					ELSE
						NextState								<= ST_INIT_CLEAR_DISPLAY;
					END IF;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			-- clear display
			-- ===============================
			WHEN ST_INIT_CLEAR_DISPLAY =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_WRITE;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				FSM_LCDBC_Data							<= KS0066U_CMD_CLEAR_DISPLAY;
				
				NextState										<= ST_INIT_CLEAR_DISPLAY_WAIT;
			
			WHEN ST_INIT_CLEAR_DISPLAY_WAIT =>
				IF (LCDBC_Status = IO_LCDBUS_STATUS_WRITING) THEN
					NULL;
				ELSIF (LCDBC_Status = IO_LCDBUS_STATUS_WRITE_COMPLETE) THEN
					NextState									<= ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_READ;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				
				NextState										<= ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS_WAIT;
			
			WHEN ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS_WAIT =>
				IF (LCDBC_Status = IO_LCDBUS_STATUS_READING) THEN
					NULL;
				ELSIF (LCDBC_Status = IO_LCDBUS_STATUS_READ_COMPLETE) THEN
					IF (LCDBC_Data(7) = '0') THEN
						NextState								<= ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS;
					ELSE
						NextState								<= ST_INIT_SET_ENTRY_MODE;
					END IF;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			-- Set entry mode
			-- ===============================
			WHEN ST_INIT_SET_ENTRY_MODE =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_WRITE;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				FSM_LCDBC_Data							<= KS0066U_CMD_SET_ENTRY_MODE;
				
				NextState										<= ST_INIT_SET_ENTRY_MODE_WAIT;
			
			WHEN ST_INIT_SET_ENTRY_MODE_WAIT =>
				IF (LCDBC_Status = IO_LCDBUS_STATUS_WRITING) THEN
					NULL;
				ELSIF (LCDBC_Status = IO_LCDBUS_STATUS_WRITE_COMPLETE) THEN
					NextState									<= ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			WHEN ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_READ;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				
				NextState										<= ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS_WAIT;
			
			WHEN ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS_WAIT =>
				IF (LCDBC_Status = IO_LCDBUS_STATUS_READING) THEN
					NULL;
				ELSIF (LCDBC_Status = IO_LCDBUS_STATUS_READ_COMPLETE) THEN
					IF (LCDBC_Data(7) = '0') THEN
						NextState								<= ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS;
					ELSE
						NextState								<= ST_INIT_DISPLAY_ON;
					END IF;
				ELSE
					NextState									<= ST_ERROR;
				END IF;
			
			-- IDLE
			-- ===============================
			WHEN ST_IDLE =>
				null;
				
			WHEN ST_x =>
				null;
				
			WHEN ST_ERROR =>
				null;
				
					
		END CASE;
	END PROCESS;
	
	LCDBC : ENTITY PoC.lcd_LCDBusController
		GENERIC MAP (
			SPEEDUP_SIMULATION			=> SPEEDUP_SIMULATION,
			CLOCK_FREQ_MHZ					=> CLOCK_FREQ_MHZ,
			LCD_BUS_BITS						=> LCD_BUS_BITS
		)
		PORT MAP (
			Clock										=> Clock,
			Reset										=> Reset,
			
			Command									=> FSM_LCDBC_Command,
			Status									=> LCDBC_Status,
			RegisterAddress					=> FSM_LCDBC_RegisterAddress,
			
			DataIn									=> FSM_LCDBC_Data,
			DataOut									=> LCDBC_Data,
			
			LCD_BusEnable						=> LCD_BusEnable,
			LCD_ReadWrite						=> LCD_ReadWrite,
			LCD_RegisterSelect			=> LCD_RegisterSelect,
			LCD_Data_i							=> LCD_Data_i,
			LCD_Data_o							=> LCD_Data_o,
			LCD_Data_t							=> LCD_Data_t
		);
END;
