-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- ============================================================================
-- Entity:				 	TODO
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
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.physical.ALL;
USE			PoC.io.ALL;
USE			PoC.net.ALL;


ENTITY mdio_MDIOController IS
	GENERIC (
		DEBUG											: BOOLEAN							:= TRUE;
		CLOCK_FREQ								: FREQ								:= 125 MHz;				-- 125 MHz
--		PREAMBLE_SUPRESSION				: BOOLEAN							:= FALSE;					-- TODO: supported by Marvel 88E1111's, minimum preamble length = 1 bit
		BAUDRATE									: BAUD								:= 1 MBd					-- 1.0 MBaud
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;

		-- MDIOController interface
		Command										: IN	T_IO_MDIO_MDIOCONTROLLER_COMMAND;
		Status										: OUT	T_IO_MDIO_MDIOCONTROLLER_STATUS;
		Error											: OUT	T_IO_MDIO_MDIOCONTROLLER_ERROR;

		DeviceAddress							: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
		RegisterAddress						: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
		DataIn										: IN	T_SLV_16;
		DataOut										: OUT	T_SLV_16;

		-- tri-state interface
		MD_Clock_i								: IN	STD_LOGIC;			-- IEEE 802.3: MDC		-> Managament Data Clock I
		MD_Clock_o								: OUT	STD_LOGIC;			-- IEEE 802.3: MDC		-> Managament Data Clock O
		MD_Clock_t								: OUT	STD_LOGIC;			-- IEEE 802.3: MDC		-> Managament Data Clock tri-state
		MD_Data_i									: IN	STD_LOGIC;			-- IEEE 802.3: MDIO		-> Managament Data I
		MD_Data_o									: OUT	STD_LOGIC;			-- IEEE 802.3: MDIO		-> Managament Data O
		MD_Data_t									: OUT	STD_LOGIC				-- IEEE 802.3: MDIO		-> Managament Data tri-state
	);
END;

-- TODO: preamble suppression, e.g. Marvel E1111 requires only 1 idle-bit between operations

ARCHITECTURE rtl OF mdio_MDIOController IS
	ATTRIBUTE KEEP											: BOOLEAN;
	ATTRIBUTE FSM_ENCODING							: STRING;

	TYPE T_STATE IS (
		ST_IDLE,
		ST_CHECK_ADR_WAIT_FOR_CLOCK,				ST_READ_WAIT_FOR_CLOCK, 				ST_WRITE_WAIT_FOR_CLOCK,
		ST_CHECK_ADR_SEND_PREAMBLE,					ST_READ_SEND_PREAMBLE,					ST_WRITE_SEND_PREAMBLE,
		ST_CHECK_ADR_SEND_START_0,					ST_READ_SEND_START_0,						ST_WRITE_SEND_START_0,
			ST_CHECK_ADR_SEND_START_1,				ST_READ_SEND_START_1,						ST_WRITE_SEND_START_1,
		ST_CHECK_ADR_SEND_OPERATION_0,			ST_READ_SEND_OPERATION_0,				ST_WRITE_SEND_OPERATION_0,
			ST_CHECK_ADR_SEND_OPERATION_1,		ST_READ_SEND_OPERATION_1,				ST_WRITE_SEND_OPERATION_1,
		ST_CHECK_ADR_SEND_DeviceAddress,	ST_READ_SEND_DeviceAddress,	ST_WRITE_SEND_DeviceAddress,
		ST_CHECK_ADR_SEND_RegisterAddress,	ST_READ_SEND_RegisterAddress,	ST_WRITE_SEND_RegisterAddress,
		ST_CHECK_ADR_TURNAROUND_CYCLE_0,		ST_READ_TURNAROUND_CYCLE_0,			ST_WRITE_TURNAROUND_CYCLE_0,
			ST_CHECK_ADR_TURNAROUND_CYCLE_1,	ST_READ_TURNAROUND_CYCLE_1,			ST_WRITE_TURNAROUND_CYCLE_1,
				ST_CHECK_OK,
				ST_CHECK_FAILED,
		ST_READ_RECEIVE_REGISTER_DATA,			ST_READ_COMPLETE,
		ST_WRITE_SEND_REGISTER_DATA,				ST_WRITE_COMPLETE,
		ST_ERROR,
			ST_ADDRESS_ERROR
	);

	SIGNAL State												: T_STATE																:= ST_IDLE;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL RegPhysicalAddress_en				: STD_LOGIC;
	SIGNAL RegPhysicalAddress_sh				: STD_LOGIC;
	SIGNAL RegPhysicalAddress_d					: STD_LOGIC_VECTOR(4 DOWNTO 0)					:= (OTHERS => '0');

	SIGNAL RegRegisterAddress_en				: STD_LOGIC;
	SIGNAL RegRegisterAddress_sh				: STD_LOGIC;
	SIGNAL RegRegisterAddress_d					: STD_LOGIC_VECTOR(4 DOWNTO 0)					:= (OTHERS => '0');

	SIGNAL RegRegisterData_en						: STD_LOGIC;
	SIGNAL RegRegisterData_shi					: STD_LOGIC;
	SIGNAL RegRegisterData_sho					: STD_LOGIC;
	SIGNAL RegRegisterData_d						: T_SLV_16															:= (OTHERS => '0');

	SIGNAL RegRegisterData_Valid_set		: STD_LOGIC;
	SIGNAL RegRegisterData_Valid_r			: STD_LOGIC															:= '0';

	SIGNAL BitCounter_rst								: STD_LOGIC;
	SIGNAL BitCounter_en								: STD_LOGIC;
	SIGNAL BitCounter_us								: UNSIGNED(4 DOWNTO 0)									:= (OTHERS => '0');

	SIGNAL MD_DataIn										: STD_LOGIC;
	SIGNAL MD_Data_en										: STD_LOGIC;
	SIGNAL MD_Data_o_nxt								: STD_LOGIC;
	SIGNAL MD_Data_t_nxt								: STD_LOGIC;

	SIGNAL MD_Clock_re									: STD_LOGIC;
	SIGNAL MD_Clock_fe									: STD_LOGIC;

	ATTRIBUTE KEEP OF MD_DataIn					: SIGNAL IS DEBUG;

BEGIN

--	ASSERT FALSE REPORT "BAUDRATE: " & to_string(BAUDRATE) SEVERITY NOTE;


	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State				<= ST_IDLE;
			ELSE
				State				<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Command, MD_Clock_re, MD_Clock_fe, MD_DataIn, BitCounter_us, RegPhysicalAddress_d, RegRegisterAddress_d, RegRegisterData_d)
	BEGIN
		NextState								<= State;

		Status									<= IO_MDIO_MDIOC_STATUS_IDLE;
		Error										<= IO_MDIO_MDIOC_ERROR_NONE;

		RegPhysicalAddress_en		<= '0';
		RegRegisterAddress_en		<= '0';
		RegRegisterData_en			<= '0';

		RegPhysicalAddress_sh		<= '0';
		RegRegisterAddress_sh		<= '0';
		RegRegisterData_sho			<= '0';
		RegRegisterData_shi			<= '0';

		BitCounter_rst					<= '0';
		BitCounter_en						<= '0';

		MD_Data_en							<= '0';
		MD_Data_o_nxt						<= '0';
		MD_Data_t_nxt						<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				BitCounter_rst							<= '1';

				CASE Command IS
					WHEN IO_MDIO_MDIOC_CMD_NONE =>
						NULL;

					WHEN IO_MDIO_MDIOC_CMD_CHECK_ADDRESS =>
						RegPhysicalAddress_en		<= '1';
						RegRegisterAddress_en		<= '1';

						NextState								<= ST_CHECK_ADR_WAIT_FOR_CLOCK;

					WHEN IO_MDIO_MDIOC_CMD_READ =>
						RegPhysicalAddress_en		<= '1';
						RegRegisterAddress_en		<= '1';

						NextState								<= ST_READ_WAIT_FOR_CLOCK;

					WHEN IO_MDIO_MDIOC_CMD_WRITE =>
						RegPhysicalAddress_en		<= '1';
						RegRegisterAddress_en		<= '1';
						RegRegisterData_en			<= '1';

						NextState								<= ST_WRITE_WAIT_FOR_CLOCK;

					WHEN OTHERS =>
						NextState								<= ST_ERROR;

				END CASE;

			-- Command_ CHECK_ADDRESS
			-- ======================================================================================================================================================
			WHEN ST_CHECK_ADR_WAIT_FOR_CLOCK =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_CHECK_ADR_SEND_PREAMBLE;
				END IF;

			WHEN ST_CHECK_ADR_SEND_PREAMBLE =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 31) THEN
						NextState								<= ST_CHECK_ADR_SEND_START_0;
					END IF;
				END IF;

			WHEN ST_CHECK_ADR_SEND_START_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_CHECK_ADR_SEND_START_1;
				END IF;

			WHEN ST_CHECK_ADR_SEND_START_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_CHECK_ADR_SEND_OPERATION_0;
				END IF;

			WHEN ST_CHECK_ADR_SEND_OPERATION_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';				-- OpCode Bit 1 = 1 (read)
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_CHECK_ADR_SEND_OPERATION_1;
				END IF;

			WHEN ST_CHECK_ADR_SEND_OPERATION_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';				-- OpCode Bit 0 = 0 (read)
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_CHECK_ADR_SEND_DeviceAddress;
				END IF;

			WHEN ST_CHECK_ADR_SEND_DeviceAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegPhysicalAddress_d(RegPhysicalAddress_d'high);
					RegPhysicalAddress_sh			<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 4) THEN
						BitCounter_rst					<= '1';
						NextState								<= ST_CHECK_ADR_SEND_RegisterAddress;
					END IF;
				END IF;

			WHEN ST_CHECK_ADR_SEND_RegisterAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegRegisterAddress_d(RegRegisterAddress_d'high);
					RegRegisterAddress_sh			<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 4) THEN
						BitCounter_rst					<= '1';
						NextState								<= ST_CHECK_ADR_TURNAROUND_CYCLE_0;
					END IF;
				END IF;

			WHEN ST_CHECK_ADR_TURNAROUND_CYCLE_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = read -> bus turnaround
					MD_Data_t_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_CHECK_ADR_TURNAROUND_CYCLE_1;
				END IF;

			WHEN ST_CHECK_ADR_TURNAROUND_CYCLE_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = read -> bus turnaround
					MD_Data_t_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					IF (MD_DataIn = '0') THEN
						NextState							<= ST_CHECK_OK;
					ELSE
						NextState							<= ST_CHECK_FAILED;	-- MD_DataIn = 1 (pullup is active; no response from device -> unknown physical address)
					END IF;
				END IF;

			WHEN ST_CHECK_OK =>
				Status										<= IO_MDIO_MDIOC_STATUS_CHECK_OK;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;

			WHEN ST_CHECK_FAILED =>
				Status										<= IO_MDIO_MDIOC_STATUS_CHECK_FAILED;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;

			-- Command: READ
			-- ======================================================================================================================================================
			WHEN ST_READ_WAIT_FOR_CLOCK =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_READ_SEND_PREAMBLE;
				END IF;

			WHEN ST_READ_SEND_PREAMBLE =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 31) THEN
						NextState								<= ST_READ_SEND_START_0;
					END IF;
				END IF;

			WHEN ST_READ_SEND_START_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_READ_SEND_START_1;
				END IF;

			WHEN ST_READ_SEND_START_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_READ_SEND_OPERATION_0;
				END IF;

			WHEN ST_READ_SEND_OPERATION_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';				-- OpCode Bit 1 = 1 (read)
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_READ_SEND_OPERATION_1;
				END IF;

			WHEN ST_READ_SEND_OPERATION_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';				-- OpCode Bit 0 = 0 (read)
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_READ_SEND_DeviceAddress;
				END IF;

			WHEN ST_READ_SEND_DeviceAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegPhysicalAddress_d(RegPhysicalAddress_d'high);
					RegPhysicalAddress_sh			<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 4) THEN
						BitCounter_rst					<= '1';
						NextState								<= ST_READ_SEND_RegisterAddress;
					END IF;
				END IF;

			WHEN ST_READ_SEND_RegisterAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegRegisterAddress_d(RegRegisterAddress_d'high);
					RegRegisterAddress_sh			<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 4) THEN
						BitCounter_rst					<= '1';
						NextState								<= ST_READ_TURNAROUND_CYCLE_0;
					END IF;
				END IF;

			WHEN ST_READ_TURNAROUND_CYCLE_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = read -> bus turnaround
					MD_Data_t_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_READ_TURNAROUND_CYCLE_1;
				END IF;

			WHEN ST_READ_TURNAROUND_CYCLE_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = read -> bus turnaround
					MD_Data_t_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					IF (MD_DataIn = '0') THEN
						NextState								<= ST_READ_RECEIVE_REGISTER_DATA;
					ELSE
						NextState								<= ST_ADDRESS_ERROR;						-- MD_DataIn = 1 (pullup is active; no response from device -> unknown physical address)
					END IF;
				END IF;

			WHEN ST_READ_RECEIVE_REGISTER_DATA =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				IF (MD_Clock_re = '1') THEN
					RegRegisterData_shi				<= '1';
					BitCounter_en							<= '1';

					IF (BitCounter_us = 15) THEN
						RegRegisterData_Valid_set		<= '1';
						NextState										<= ST_READ_COMPLETE;
					END IF;
				END IF;

			WHEN ST_READ_COMPLETE =>
				Status										<= IO_MDIO_MDIOC_STATUS_READ_COMPLETE;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;


			-- Command: WRITE
			-- ======================================================================================================================================================
			WHEN ST_WRITE_WAIT_FOR_CLOCK =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_WRITE_SEND_PREAMBLE;
				END IF;

			WHEN ST_WRITE_SEND_PREAMBLE =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 31) THEN
						NextState								<= ST_WRITE_SEND_START_0;
					END IF;
				END IF;

			WHEN ST_WRITE_SEND_START_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_WRITE_SEND_START_1;
				END IF;

			WHEN ST_WRITE_SEND_START_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_WRITE_SEND_OPERATION_0;
				END IF;

			WHEN ST_WRITE_SEND_OPERATION_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';				-- OpCode Bit 1 = 0 (write)
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_WRITE_SEND_OPERATION_1;
				END IF;

			WHEN ST_WRITE_SEND_OPERATION_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';				-- OpCode Bit 0 = 1 (write)
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_WRITE_SEND_DeviceAddress;
				END IF;

			WHEN ST_WRITE_SEND_DeviceAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegPhysicalAddress_d(RegPhysicalAddress_d'high);
					RegPhysicalAddress_sh			<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 4) THEN
						BitCounter_rst					<= '1';
						NextState								<= ST_WRITE_SEND_RegisterAddress;
					END IF;
				END IF;

			WHEN ST_WRITE_SEND_RegisterAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegRegisterAddress_d(RegRegisterAddress_d'high);
					RegRegisterAddress_sh			<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 4) THEN
						BitCounter_rst					<= '1';
						NextState								<= ST_WRITE_TURNAROUND_CYCLE_0;
					END IF;
				END IF;

			WHEN ST_WRITE_TURNAROUND_CYCLE_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';						-- Operation = write -> send "10"
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_WRITE_TURNAROUND_CYCLE_1;
				END IF;

			WHEN ST_WRITE_TURNAROUND_CYCLE_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = write -> send "10"
				END IF;

				IF (MD_Clock_re = '1') THEN
					NextState									<= ST_WRITE_SEND_REGISTER_DATA;
				END IF;

			WHEN ST_WRITE_SEND_REGISTER_DATA =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegRegisterData_d(RegRegisterData_d'high);
					RegRegisterData_sho				<= '1';
				END IF;

				IF (MD_Clock_re = '1') THEN
					BitCounter_en							<= '1';

					IF (BitCounter_us = 15) THEN
						NextState								<= ST_WRITE_COMPLETE;
					END IF;
				END IF;

			WHEN ST_WRITE_COMPLETE =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITE_COMPLETE;

				IF (MD_Clock_fe = '1') THEN
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';
					MD_Data_t_nxt							<= '1';

					RegRegisterData_Valid_set	<= '1';

					NextState									<= ST_IDLE;
				END IF;

			WHEN ST_ADDRESS_ERROR =>
				Status										<= IO_MDIO_MDIOC_STATUS_ERROR;
				Error											<= IO_MDIO_MDIOC_ERROR_ADDRESS_NOT_FOUND;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;

			WHEN ST_ERROR =>
				Status										<= IO_MDIO_MDIOC_STATUS_ERROR;
				Error											<= IO_MDIO_MDIOC_ERROR_FSM;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;

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

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				RegPhysicalAddress_d		<= (OTHERS => '0');
				RegRegisterAddress_d		<= (OTHERS => '0');
				RegRegisterData_d				<= (OTHERS => '0');
				RegRegisterData_Valid_r	<= '0';
			ELSE
				IF (RegPhysicalAddress_en	= '1') THEN
					RegPhysicalAddress_d	<= DeviceAddress;
				ELSIF (RegPhysicalAddress_sh = '1') THEN
					RegPhysicalAddress_d	<= RegPhysicalAddress_d(RegPhysicalAddress_d'high - 1 DOWNTO 0) & RegPhysicalAddress_d(RegPhysicalAddress_d'high);
				END IF;

				IF (RegRegisterAddress_en	= '1') THEN
					RegRegisterAddress_d	<= RegisterAddress;
				ELSIF (RegRegisterAddress_sh = '1') THEN
					RegRegisterAddress_d	<= RegRegisterAddress_d(RegRegisterAddress_d'high - 1 DOWNTO 0) & RegRegisterAddress_d(RegRegisterAddress_d'high);
				END IF;

				IF (RegRegisterData_en	= '1') THEN
					RegRegisterData_d			<= DataIn;
				ELSIF (RegRegisterData_sho = '1') THEN
					RegRegisterData_d			<= RegRegisterData_d(RegRegisterData_d'high - 1 DOWNTO 0) & RegRegisterData_d(RegRegisterData_d'high);
				ELSIF (RegRegisterData_shi = '1') THEN
					RegRegisterData_d			<= RegRegisterData_d(RegRegisterData_d'high - 1 DOWNTO 0) & MD_DataIn;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	DataOut	<= RegRegisterData_d;

	-- ==========================================================================================================================================================
	-- Management Data Clock
	-- ==========================================================================================================================================================
	blkMDClock : BLOCK
		CONSTANT CLOCKCOUNTER_MAX_FALLING_EDGE	: NATURAL		:= TimingToCycles(to_time(to_freq(BAUDRATE) / 2.0), CLOCK_FREQ);
		CONSTANT CLOCKCOUNTER_MAX_RISING_EDGE		: NATURAL		:= TimingToCycles(to_time(to_freq(BAUDRATE) / 2.0), CLOCK_FREQ);
		CONSTANT CLOCKCOUNTER_BITS							: POSITIVE	:= log2ceilnz(CLOCKCOUNTER_MAX_RISING_EDGE + CLOCKCOUNTER_MAX_FALLING_EDGE);

		SIGNAL ClockCounter_rst			: STD_LOGIC;
		SIGNAL ClockCounter_us			: UNSIGNED(CLOCKCOUNTER_BITS - 1 DOWNTO 0)	:= (OTHERS => '0');

		SIGNAL MD_Clock_i						: STD_LOGIC																	:= '0';
		SIGNAL MD_Clock_r						: STD_LOGIC																	:= '0';
		SIGNAL MD_Clock_d1					: STD_LOGIC																	:= '0';
		SIGNAL MD_Clock_d2					: STD_LOGIC																	:= '0';
	BEGIN
		ASSERT FALSE REPORT "CLOCKCOUNTER_MAX_FALLING_EDGE: "	& INTEGER'image(CLOCKCOUNTER_MAX_FALLING_EDGE)	SEVERITY NOTE;
		ASSERT FALSE REPORT "CLOCKCOUNTER_MAX_RISING_EDGE: "	& INTEGER'image(CLOCKCOUNTER_MAX_RISING_EDGE)		SEVERITY NOTE;
		ASSERT FALSE REPORT "CLOCKCOUNTER_BITS: "							& INTEGER'image(CLOCKCOUNTER_BITS)							SEVERITY NOTE;

		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF ((Reset OR ClockCounter_rst) = '1') THEN
					ClockCounter_us				<= (OTHERS => '0');
				ELSE
					ClockCounter_us				<= ClockCounter_us + 1;
				END IF;
			END IF;
		END PROCESS;

		MD_Clock_fe				<= to_sl(ClockCounter_us = CLOCKCOUNTER_MAX_FALLING_EDGE - 1);
		MD_Clock_i				<= to_sl(ClockCounter_us = (CLOCKCOUNTER_MAX_FALLING_EDGE + CLOCKCOUNTER_MAX_RISING_EDGE - 2));
		MD_Clock_re				<= MD_Clock_i WHEN rising_edge(Clock);
		ClockCounter_rst	<= MD_Clock_re;

		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF ((Reset OR MD_Clock_fe) = '1') THEN
					MD_Clock_r						<= '0';
				ELSIF (MD_Clock_re = '1') THEN
					MD_Clock_r						<= '1';
				END IF;
			END IF;
		END PROCESS;

		MD_Clock_o		<= MD_Clock_r;
		MD_Clock_t		<= '0';

		genCSP : IF (DEBUG = TRUE) GENERATE
			CONSTANT OFFSET											: POSITIVE						:= 1;
			SIGNAL CSP_RisingEdge								: STD_LOGIC;
			SIGNAL CSP_FallingEdge							: STD_LOGIC;
			ATTRIBUTE KEEP OF CSP_RisingEdge		: SIGNAL IS TRUE;
			ATTRIBUTE KEEP OF CSP_FallingEdge		: SIGNAL IS TRUE;
		BEGIN
			CSP_RisingEdge		<= to_sl(((CLOCKCOUNTER_MAX_RISING_EDGE + CLOCKCOUNTER_MAX_FALLING_EDGE - OFFSET - 1) <= ClockCounter_us) OR (ClockCounter_us <= OFFSET + 1));
			CSP_FallingEdge		<= to_sl(((CLOCKCOUNTER_MAX_RISING_EDGE - OFFSET + 2) <= ClockCounter_us) AND (ClockCounter_us < (CLOCKCOUNTER_MAX_RISING_EDGE + OFFSET + 2)));
		END GENERATE;
	END BLOCK;

	-- ==========================================================================================================================================================
	-- Management Data Input/Output
	-- ==========================================================================================================================================================
	blkMDData : BLOCK
		SIGNAL MD_Data_i_d1			: STD_LOGIC				:= '0';
		SIGNAL MD_Data_i_d2			: STD_LOGIC				:= '0';
		SIGNAL MD_Data_o_d			: STD_LOGIC				:= '0';
		SIGNAL MD_Data_t_d			: STD_LOGIC				:= '1';

	BEGIN
		MD_Data_i_d1		<= MD_Data_i		WHEN rising_edge(Clock);
		MD_Data_i_d2		<= MD_Data_i_d1 WHEN rising_edge(Clock);
		MD_DataIn				<= MD_Data_i_d2;

		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Reset = '1') THEN
					MD_Data_o_d							<= '0';
					MD_Data_t_d							<= '1';
				ELSE
					IF (MD_Data_en	= '1') THEN
						MD_Data_o_d						<= MD_Data_o_nxt;
						MD_Data_t_d						<= MD_Data_t_nxt;
					END IF;
				END IF;
			END IF;
		END PROCESS;

		MD_Data_o		<= MD_Data_o_d;
		MD_Data_t		<= MD_Data_t_d;
	END BLOCK;
END;
