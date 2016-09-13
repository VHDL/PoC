-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
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
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;

library	PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.io.all;
use			PoC.lcd.all;


entity lcd_LCDController_KS0066U is
	generic (
		SPEEDUP_SIMULATION				: boolean												:= TRUE;
		CLOCK_FREQ_MHZ						: REAL													:= 125.0;					-- 125 MHz
		LCD_BUS_BITS							: positive											:= 4
	);
	port (
		Clock											: in	std_logic;
		Reset											: in	std_logic;

		Command										: in	T_IO_LCD_COMMAND;
		Status										: out	T_IO_LCD_STATUS;

		DataOut										: out	T_SLV_8;

		LCD_BusEnable							: out	std_logic;
		LCD_ReadWrite							: out	std_logic;
		LCD_RegisterSelect				: out	std_logic;
		LCD_Data_i								: in	std_logic_vector(7 downto (8 - LCD_BUS_BITS));
		LCD_Data_o								: out	std_logic_vector(7 downto (8 - LCD_BUS_BITS));
		LCD_Data_t								: out	std_logic_vector(7 downto (8 - LCD_BUS_BITS))
	);
end  entity;

architecture rtl of lcd_LCDController_KS0066U is
	attribute KEEP														: boolean;
	attribute FSM_ENCODING										: string;

	type T_STATE is (
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

	signal State				: T_STATE						:= ST_INIT;
	signal NextState		: T_STATE;

begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State			<= ST_INIT;
			else
				State			: NextState;
			end if;
		end if;
	end process;

	process(State, Strobe, ReadWrite)
	begin
		NextState										<= State;

		Status											<= LCD_CTRL_STATUS_IDLE;

		FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_NONE;
		FSM_LCDBC_RegisterAddress		<= '0';
		FSM_LCDBC_Data							<= KS0066U_CMD_NONE;

		case State is
			when ST_RESET =>
				if LCDBC_Status = IO_LCDBUS_STATUS_IDLE then
					NextState									<= ST_INIT_SET_FUNCTION;
				end if;

			-- set function
			-- ===============================
			when ST_INIT_SET_FUNCTION =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_WRITE;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				FSM_LCDBC_Data							<= KS0066U_CMD_SET_FUNCTION;

				NextState										<= ST_INIT_SET_FUNCTION_WAIT;

			when ST_INIT_SET_FUNCTION_WAIT =>
				if LCDBC_Status = IO_LCDBUS_STATUS_WRITING then
					null;
				elsif LCDBC_Status = IO_LCDBUS_STATUS_WRITE_COMPLETE then
					NextState									<= ST_INIT_SET_FUNCTION_POLL_LCDBUS;
				else
					NextState									<= ST_ERROR;
				end if;

			when ST_INIT_SET_FUNCTION_POLL_LCDBUS =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_READ;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;

				NextState										<= ST_INIT_SET_FUNCTION_POLL_LCDBUS_WAIT;

			when ST_INIT_SET_FUNCTION_POLL_LCDBUS_WAIT =>
				if LCDBC_Status = IO_LCDBUS_STATUS_READING then
					null;
				elsif LCDBC_Status = IO_LCDBUS_STATUS_READ_COMPLETE then
					if (LCDBC_Data(7) = '0') then
						NextState								<= ST_INIT_SET_FUNCTION_POLL_LCDBUS;
					else
						NextState								<= ST_INIT_DISPLAY_ON;
					end if;
				else
					NextState									<= ST_ERROR;
				end if;

			-- display on
			-- ===============================
			when ST_INIT_DISPLAY_ON =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_WRITE;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				FSM_LCDBC_Data							<= KS0066U_CMD_DISPLAY_ON;

				NextState										<= ST_INIT_DISPLAY_ON_WAIT;

			when ST_INIT_DISPLAY_ON_WAIT =>
				if LCDBC_Status = IO_LCDBUS_STATUS_WRITING then
					null;
				elsif LCDBC_Status = IO_LCDBUS_STATUS_WRITE_COMPLETE then
					NextState									<= ST_INIT_DISPLAY_ON_POLL_LCDBUS;
				else
					NextState									<= ST_ERROR;
				end if;

			when ST_INIT_DISPLAY_ON_POLL_LCDBUS =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_READ;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;

				NextState										<= ST_INIT_DISPLAY_ON_POLL_LCDBUS_WAIT;

			when ST_INIT_DISPLAY_ON_POLL_LCDBUS_WAIT =>
				if LCDBC_Status = IO_LCDBUS_STATUS_READING then
					null;
				elsif LCDBC_Status = IO_LCDBUS_STATUS_READ_COMPLETE then
					if (LCDBC_Data(7) = '0') then
						NextState								<= ST_INIT_DISPLAY_ON_POLL_LCDBUS;
					else
						NextState								<= ST_INIT_CLEAR_DISPLAY;
					end if;
				else
					NextState									<= ST_ERROR;
				end if;

			-- clear display
			-- ===============================
			when ST_INIT_CLEAR_DISPLAY =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_WRITE;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				FSM_LCDBC_Data							<= KS0066U_CMD_CLEAR_DISPLAY;

				NextState										<= ST_INIT_CLEAR_DISPLAY_WAIT;

			when ST_INIT_CLEAR_DISPLAY_WAIT =>
				if LCDBC_Status = IO_LCDBUS_STATUS_WRITING then
					null;
				elsif LCDBC_Status = IO_LCDBUS_STATUS_WRITE_COMPLETE then
					NextState									<= ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS;
				else
					NextState									<= ST_ERROR;
				end if;

			when ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_READ;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;

				NextState										<= ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS_WAIT;

			when ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS_WAIT =>
				if LCDBC_Status = IO_LCDBUS_STATUS_READING then
					null;
				elsif LCDBC_Status = IO_LCDBUS_STATUS_READ_COMPLETE then
					if (LCDBC_Data(7) = '0') then
						NextState								<= ST_INIT_CLEAR_DISPLAY_POLL_LCDBUS;
					else
						NextState								<= ST_INIT_SET_ENTRY_MODE;
					end if;
				else
					NextState									<= ST_ERROR;
				end if;

			-- Set entry mode
			-- ===============================
			when ST_INIT_SET_ENTRY_MODE =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_WRITE;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;
				FSM_LCDBC_Data							<= KS0066U_CMD_SET_ENTRY_MODE;

				NextState										<= ST_INIT_SET_ENTRY_MODE_WAIT;

			when ST_INIT_SET_ENTRY_MODE_WAIT =>
				if LCDBC_Status = IO_LCDBUS_STATUS_WRITING then
					null;
				elsif LCDBC_Status = IO_LCDBUS_STATUS_WRITE_COMPLETE then
					NextState									<= ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS;
				else
					NextState									<= ST_ERROR;
				end if;

			when ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS =>
				FSM_LCDBC_Command						<= LCD_BUSCTRL_CMD_READ;
				FSM_LCDBC_RegisterAddress		<= KS0066U_REG_COMMAND;

				NextState										<= ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS_WAIT;

			when ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS_WAIT =>
				if LCDBC_Status = IO_LCDBUS_STATUS_READING then
					null;
				elsif LCDBC_Status = IO_LCDBUS_STATUS_READ_COMPLETE then
					if (LCDBC_Data(7) = '0') then
						NextState								<= ST_INIT_SET_ENTRY_MODE_POLL_LCDBUS;
					else
						NextState								<= ST_INIT_DISPLAY_ON;
					end if;
				else
					NextState									<= ST_ERROR;
				end if;

			-- IDLE
			-- ===============================
			when ST_IDLE =>
				null;

			when ST_x =>
				null;

			when ST_ERROR =>
				null;


		end case;
	end process;

	LCDBC : entity PoC.lcd_LCDBusController
		generic map (
			SPEEDUP_SIMULATION			=> SPEEDUP_SIMULATION,
			CLOCK_FREQ_MHZ					=> CLOCK_FREQ_MHZ,
			LCD_BUS_BITS						=> LCD_BUS_BITS
		)
		port map (
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
end;
