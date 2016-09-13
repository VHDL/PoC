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
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;
use			PoC.io.all;
--USE			PoC.net.ALL;


entity mdio_Controller is
	generic (
		DEBUG											: boolean							:= TRUE;
		CLOCK_FREQ								: FREQ								:= 125 MHz;				-- 125 MHz
--		PREAMBLE_SUPRESSION				: BOOLEAN							:= FALSE;					-- TODO: supported by Marvel 88E1111's, minimum preamble length = 1 bit
		BAUDRATE									: BAUD								:= 1 MBd					-- 1.0 MBaud
	);
	port (
		Clock											: in	std_logic;
		Reset											: in	std_logic;

		-- MDIOController interface
		Command										: in	T_IO_MDIO_MDIOCONTROLLER_COMMAND;
		Status										: out	T_IO_MDIO_MDIOCONTROLLER_STATUS;
		Error											: out	T_IO_MDIO_MDIOCONTROLLER_ERROR;

		DeviceAddress							: in	std_logic_vector(4 downto 0);
		RegisterAddress						: in	std_logic_vector(4 downto 0);
		DataIn										: in	T_SLV_16;
		DataOut										: out	T_SLV_16;

		-- tri-state interface
		MD_Clock_i								: in	std_logic;			-- IEEE 802.3: MDC		-> Managament Data Clock I
		MD_Clock_o								: out	std_logic;			-- IEEE 802.3: MDC		-> Managament Data Clock O
		MD_Clock_t								: out	std_logic;			-- IEEE 802.3: MDC		-> Managament Data Clock tri-state
		MD_Data_i									: in	std_logic;			-- IEEE 802.3: MDIO		-> Managament Data I
		MD_Data_o									: out	std_logic;			-- IEEE 802.3: MDIO		-> Managament Data O
		MD_Data_t									: out	std_logic				-- IEEE 802.3: MDIO		-> Managament Data tri-state
	);
end entity;

-- TODO: preamble suppression, e.g. Marvel E1111 requires only 1 idle-bit between operations

architecture rtl of mdio_Controller is
	attribute KEEP											: boolean;
	attribute FSM_ENCODING							: string;

	type T_STATE is (
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

	signal State												: T_STATE																:= ST_IDLE;
	signal NextState										: T_STATE;
	attribute FSM_ENCODING of State			: signal is ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	signal RegPhysicalAddress_en				: std_logic;
	signal RegPhysicalAddress_sh				: std_logic;
	signal RegPhysicalAddress_d					: std_logic_vector(4 downto 0)					:= (others => '0');

	signal RegRegisterAddress_en				: std_logic;
	signal RegRegisterAddress_sh				: std_logic;
	signal RegRegisterAddress_d					: std_logic_vector(4 downto 0)					:= (others => '0');

	signal RegRegisterData_en						: std_logic;
	signal RegRegisterData_shi					: std_logic;
	signal RegRegisterData_sho					: std_logic;
	signal RegRegisterData_d						: T_SLV_16															:= (others => '0');

	signal RegRegisterData_Valid_set		: std_logic;
	signal RegRegisterData_Valid_r			: std_logic															:= '0';

	signal BitCounter_rst								: std_logic;
	signal BitCounter_en								: std_logic;
	signal BitCounter_us								: unsigned(4 downto 0)									:= (others => '0');

	signal MD_DataIn										: std_logic;
	signal MD_Data_en										: std_logic;
	signal MD_Data_o_nxt								: std_logic;
	signal MD_Data_t_nxt								: std_logic;

	signal MD_Clock_re									: std_logic;
	signal MD_Clock_fe									: std_logic;

	attribute KEEP of MD_DataIn					: signal is DEBUG;

begin

--	assert FALSE report "BAUDRATE: " & to_string(BAUDRATE) severity NOTE;


	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State				<= ST_IDLE;
			else
				State				<= NextState;
			end if;
		end if;
	end process;

	process(State, Command, MD_Clock_re, MD_Clock_fe, MD_DataIn, BitCounter_us, RegPhysicalAddress_d, RegRegisterAddress_d, RegRegisterData_d)
	begin
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

		case State is
			when ST_IDLE =>
				BitCounter_rst							<= '1';

				case Command is
					when IO_MDIO_MDIOC_CMD_NONE =>
						null;

					when IO_MDIO_MDIOC_CMD_CHECK_ADDRESS =>
						RegPhysicalAddress_en		<= '1';
						RegRegisterAddress_en		<= '1';

						NextState								<= ST_CHECK_ADR_WAIT_FOR_CLOCK;

					when IO_MDIO_MDIOC_CMD_READ =>
						RegPhysicalAddress_en		<= '1';
						RegRegisterAddress_en		<= '1';

						NextState								<= ST_READ_WAIT_FOR_CLOCK;

					when IO_MDIO_MDIOC_CMD_WRITE =>
						RegPhysicalAddress_en		<= '1';
						RegRegisterAddress_en		<= '1';
						RegRegisterData_en			<= '1';

						NextState								<= ST_WRITE_WAIT_FOR_CLOCK;

					when others =>
						NextState								<= ST_ERROR;

				end case;

			-- Command_ CHECK_ADDRESS
			-- ======================================================================================================================================================
			when ST_CHECK_ADR_WAIT_FOR_CLOCK =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_re = '1') then
					NextState									<= ST_CHECK_ADR_SEND_PREAMBLE;
				end if;

			when ST_CHECK_ADR_SEND_PREAMBLE =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 31 then
						NextState								<= ST_CHECK_ADR_SEND_START_0;
					end if;
				end if;

			when ST_CHECK_ADR_SEND_START_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_CHECK_ADR_SEND_START_1;
				end if;

			when ST_CHECK_ADR_SEND_START_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_CHECK_ADR_SEND_OPERATION_0;
				end if;

			when ST_CHECK_ADR_SEND_OPERATION_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';				-- OpCode Bit 1 = 1 (read)
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_CHECK_ADR_SEND_OPERATION_1;
				end if;

			when ST_CHECK_ADR_SEND_OPERATION_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';				-- OpCode Bit 0 = 0 (read)
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_CHECK_ADR_SEND_DeviceAddress;
				end if;

			when ST_CHECK_ADR_SEND_DeviceAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegPhysicalAddress_d(RegPhysicalAddress_d'high);
					RegPhysicalAddress_sh			<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 4 then
						BitCounter_rst					<= '1';
						NextState								<= ST_CHECK_ADR_SEND_RegisterAddress;
					end if;
				end if;

			when ST_CHECK_ADR_SEND_RegisterAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegRegisterAddress_d(RegRegisterAddress_d'high);
					RegRegisterAddress_sh			<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 4 then
						BitCounter_rst					<= '1';
						NextState								<= ST_CHECK_ADR_TURNAROUND_CYCLE_0;
					end if;
				end if;

			when ST_CHECK_ADR_TURNAROUND_CYCLE_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = read -> bus turnaround
					MD_Data_t_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_CHECK_ADR_TURNAROUND_CYCLE_1;
				end if;

			when ST_CHECK_ADR_TURNAROUND_CYCLE_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_CHECKING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = read -> bus turnaround
					MD_Data_t_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					if (MD_DataIn = '0') then
						NextState							<= ST_CHECK_OK;
					else
						NextState							<= ST_CHECK_FAILED;	-- MD_DataIn = 1 (pullup is active; no response from device -> unknown physical address)
					end if;
				end if;

			when ST_CHECK_OK =>
				Status										<= IO_MDIO_MDIOC_STATUS_CHECK_OK;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;

			when ST_CHECK_FAILED =>
				Status										<= IO_MDIO_MDIOC_STATUS_CHECK_FAILED;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;

			-- Command: READ
			-- ======================================================================================================================================================
			when ST_READ_WAIT_FOR_CLOCK =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_re = '1') then
					NextState									<= ST_READ_SEND_PREAMBLE;
				end if;

			when ST_READ_SEND_PREAMBLE =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 31 then
						NextState								<= ST_READ_SEND_START_0;
					end if;
				end if;

			when ST_READ_SEND_START_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_READ_SEND_START_1;
				end if;

			when ST_READ_SEND_START_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_READ_SEND_OPERATION_0;
				end if;

			when ST_READ_SEND_OPERATION_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';				-- OpCode Bit 1 = 1 (read)
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_READ_SEND_OPERATION_1;
				end if;

			when ST_READ_SEND_OPERATION_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';				-- OpCode Bit 0 = 0 (read)
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_READ_SEND_DeviceAddress;
				end if;

			when ST_READ_SEND_DeviceAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegPhysicalAddress_d(RegPhysicalAddress_d'high);
					RegPhysicalAddress_sh			<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 4 then
						BitCounter_rst					<= '1';
						NextState								<= ST_READ_SEND_RegisterAddress;
					end if;
				end if;

			when ST_READ_SEND_RegisterAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegRegisterAddress_d(RegRegisterAddress_d'high);
					RegRegisterAddress_sh			<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 4 then
						BitCounter_rst					<= '1';
						NextState								<= ST_READ_TURNAROUND_CYCLE_0;
					end if;
				end if;

			when ST_READ_TURNAROUND_CYCLE_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = read -> bus turnaround
					MD_Data_t_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_READ_TURNAROUND_CYCLE_1;
				end if;

			when ST_READ_TURNAROUND_CYCLE_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = read -> bus turnaround
					MD_Data_t_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					if (MD_DataIn = '0') then
						NextState								<= ST_READ_RECEIVE_REGISTER_DATA;
					else
						NextState								<= ST_ADDRESS_ERROR;						-- MD_DataIn = 1 (pullup is active; no response from device -> unknown physical address)
					end if;
				end if;

			when ST_READ_RECEIVE_REGISTER_DATA =>
				Status											<= IO_MDIO_MDIOC_STATUS_READING;

				if (MD_Clock_re = '1') then
					RegRegisterData_shi				<= '1';
					BitCounter_en							<= '1';

					if BitCounter_us = 15 then
						RegRegisterData_Valid_set		<= '1';
						NextState										<= ST_READ_COMPLETE;
					end if;
				end if;

			when ST_READ_COMPLETE =>
				Status										<= IO_MDIO_MDIOC_STATUS_READ_COMPLETE;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;


			-- Command: WRITE
			-- ======================================================================================================================================================
			when ST_WRITE_WAIT_FOR_CLOCK =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_re = '1') then
					NextState									<= ST_WRITE_SEND_PREAMBLE;
				end if;

			when ST_WRITE_SEND_PREAMBLE =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 31 then
						NextState								<= ST_WRITE_SEND_START_0;
					end if;
				end if;

			when ST_WRITE_SEND_START_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_WRITE_SEND_START_1;
				end if;

			when ST_WRITE_SEND_START_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_WRITE_SEND_OPERATION_0;
				end if;

			when ST_WRITE_SEND_OPERATION_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';				-- OpCode Bit 1 = 0 (write)
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_WRITE_SEND_OPERATION_1;
				end if;

			when ST_WRITE_SEND_OPERATION_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';				-- OpCode Bit 0 = 1 (write)
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_WRITE_SEND_DeviceAddress;
				end if;

			when ST_WRITE_SEND_DeviceAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegPhysicalAddress_d(RegPhysicalAddress_d'high);
					RegPhysicalAddress_sh			<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 4 then
						BitCounter_rst					<= '1';
						NextState								<= ST_WRITE_SEND_RegisterAddress;
					end if;
				end if;

			when ST_WRITE_SEND_RegisterAddress =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegRegisterAddress_d(RegRegisterAddress_d'high);
					RegRegisterAddress_sh			<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 4 then
						BitCounter_rst					<= '1';
						NextState								<= ST_WRITE_TURNAROUND_CYCLE_0;
					end if;
				end if;

			when ST_WRITE_TURNAROUND_CYCLE_0 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '1';						-- Operation = write -> send "10"
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_WRITE_TURNAROUND_CYCLE_1;
				end if;

			when ST_WRITE_TURNAROUND_CYCLE_1 =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';						-- Operation = write -> send "10"
				end if;

				if (MD_Clock_re = '1') then
					NextState									<= ST_WRITE_SEND_REGISTER_DATA;
				end if;

			when ST_WRITE_SEND_REGISTER_DATA =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITING;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= RegRegisterData_d(RegRegisterData_d'high);
					RegRegisterData_sho				<= '1';
				end if;

				if (MD_Clock_re = '1') then
					BitCounter_en							<= '1';

					if BitCounter_us = 15 then
						NextState								<= ST_WRITE_COMPLETE;
					end if;
				end if;

			when ST_WRITE_COMPLETE =>
				Status											<= IO_MDIO_MDIOC_STATUS_WRITE_COMPLETE;

				if (MD_Clock_fe = '1') then
					MD_Data_en								<= '1';
					MD_Data_o_nxt							<= '0';
					MD_Data_t_nxt							<= '1';

					RegRegisterData_Valid_set	<= '1';

					NextState									<= ST_IDLE;
				end if;

			when ST_ADDRESS_ERROR =>
				Status										<= IO_MDIO_MDIOC_STATUS_ERROR;
				Error											<= IO_MDIO_MDIOC_ERROR_ADDRESS_NOT_FOUND;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;

			when ST_ERROR =>
				Status										<= IO_MDIO_MDIOC_STATUS_ERROR;
				Error											<= IO_MDIO_MDIOC_ERROR_FSM;

				MD_Data_en								<= '1';
				MD_Data_o_nxt							<= '0';
				MD_Data_t_nxt							<= '1';

				NextState									<= ST_IDLE;

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

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				RegPhysicalAddress_d		<= (others => '0');
				RegRegisterAddress_d		<= (others => '0');
				RegRegisterData_d				<= (others => '0');
				RegRegisterData_Valid_r	<= '0';
			else
				if (RegPhysicalAddress_en	= '1') then
					RegPhysicalAddress_d	<= DeviceAddress;
				elsif (RegPhysicalAddress_sh = '1') then
					RegPhysicalAddress_d	<= RegPhysicalAddress_d(RegPhysicalAddress_d'high - 1 downto 0) & RegPhysicalAddress_d(RegPhysicalAddress_d'high);
				end if;

				if (RegRegisterAddress_en	= '1') then
					RegRegisterAddress_d	<= RegisterAddress;
				elsif (RegRegisterAddress_sh = '1') then
					RegRegisterAddress_d	<= RegRegisterAddress_d(RegRegisterAddress_d'high - 1 downto 0) & RegRegisterAddress_d(RegRegisterAddress_d'high);
				end if;

				if (RegRegisterData_en	= '1') then
					RegRegisterData_d			<= DataIn;
				elsif (RegRegisterData_sho = '1') then
					RegRegisterData_d			<= RegRegisterData_d(RegRegisterData_d'high - 1 downto 0) & RegRegisterData_d(RegRegisterData_d'high);
				elsif (RegRegisterData_shi = '1') then
					RegRegisterData_d			<= RegRegisterData_d(RegRegisterData_d'high - 1 downto 0) & MD_DataIn;
				end if;
			end if;
		end if;
	end process;

	DataOut	<= RegRegisterData_d;

	-- ==========================================================================================================================================================
	-- Management Data Clock
	-- ==========================================================================================================================================================
	blkMDClock : block
		constant CLOCKCOUNTER_MAX_FALLING_EDGE	: natural		:= TimingToCycles(to_time(to_freq(BAUDRATE) / 2.0), CLOCK_FREQ);
		constant CLOCKCOUNTER_MAX_RISING_EDGE		: natural		:= TimingToCycles(to_time(to_freq(BAUDRATE) / 2.0), CLOCK_FREQ);
		constant CLOCKCOUNTER_BITS							: positive	:= log2ceilnz(CLOCKCOUNTER_MAX_RISING_EDGE + CLOCKCOUNTER_MAX_FALLING_EDGE);

		signal ClockCounter_rst			: std_logic;
		signal ClockCounter_us			: unsigned(CLOCKCOUNTER_BITS - 1 downto 0)	:= (others => '0');

		signal MD_Clock_i						: std_logic																	:= '0';
		signal MD_Clock_r						: std_logic																	:= '0';
		signal MD_Clock_d1					: std_logic																	:= '0';
		signal MD_Clock_d2					: std_logic																	:= '0';
	begin
		assert FALSE report "CLOCKCOUNTER_MAX_FALLING_EDGE: "	& integer'image(CLOCKCOUNTER_MAX_FALLING_EDGE)	severity NOTE;
		assert FALSE report "CLOCKCOUNTER_MAX_RISING_EDGE: "	& integer'image(CLOCKCOUNTER_MAX_RISING_EDGE)		severity NOTE;
		assert FALSE report "CLOCKCOUNTER_BITS: "							& integer'image(CLOCKCOUNTER_BITS)							severity NOTE;

		process(Clock)
		begin
			if rising_edge(Clock) then
				if ((Reset or ClockCounter_rst) = '1') then
					ClockCounter_us				<= (others => '0');
				else
					ClockCounter_us				<= ClockCounter_us + 1;
				end if;
			end if;
		end process;

		MD_Clock_fe				<= to_sl(ClockCounter_us = CLOCKCOUNTER_MAX_FALLING_EDGE - 1);
		MD_Clock_i				<= to_sl(ClockCounter_us = (CLOCKCOUNTER_MAX_FALLING_EDGE + CLOCKCOUNTER_MAX_RISING_EDGE - 2));
		MD_Clock_re				<= MD_Clock_i when rising_edge(Clock);
		ClockCounter_rst	<= MD_Clock_re;

		process(Clock)
		begin
			if rising_edge(Clock) then
				if ((Reset or MD_Clock_fe) = '1') then
					MD_Clock_r						<= '0';
				elsif (MD_Clock_re = '1') then
					MD_Clock_r						<= '1';
				end if;
			end if;
		end process;

		MD_Clock_o		<= MD_Clock_r;
		MD_Clock_t		<= '0';

		genCSP : if DEBUG generate
			constant OFFSET											: positive						:= 1;
			signal CSP_RisingEdge								: std_logic;
			signal CSP_FallingEdge							: std_logic;
			attribute KEEP of CSP_RisingEdge		: signal is TRUE;
			attribute KEEP of CSP_FallingEdge		: signal is TRUE;
		begin
			CSP_RisingEdge		<= to_sl(((CLOCKCOUNTER_MAX_RISING_EDGE + CLOCKCOUNTER_MAX_FALLING_EDGE - OFFSET - 1) <= ClockCounter_us) or (ClockCounter_us <= OFFSET + 1));
			CSP_FallingEdge		<= to_sl(((CLOCKCOUNTER_MAX_RISING_EDGE - OFFSET + 2) <= ClockCounter_us) and (ClockCounter_us < (CLOCKCOUNTER_MAX_RISING_EDGE + OFFSET + 2)));
		end generate;
	end block;

	-- ==========================================================================================================================================================
	-- Management Data Input/Output
	-- ==========================================================================================================================================================
	blkMDData : block
		signal MD_Data_i_d1			: std_logic				:= '0';
		signal MD_Data_i_d2			: std_logic				:= '0';
		signal MD_Data_o_d			: std_logic				:= '0';
		signal MD_Data_t_d			: std_logic				:= '1';

	begin
		MD_Data_i_d1		<= MD_Data_i		when rising_edge(Clock);
		MD_Data_i_d2		<= MD_Data_i_d1 when rising_edge(Clock);
		MD_DataIn				<= MD_Data_i_d2;

		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Reset = '1') then
					MD_Data_o_d							<= '0';
					MD_Data_t_d							<= '1';
				else
					if (MD_Data_en	= '1') then
						MD_Data_o_d						<= MD_Data_o_nxt;
						MD_Data_t_d						<= MD_Data_t_nxt;
					end if;
				end if;
			end if;
		end process;

		MD_Data_o		<= MD_Data_o_d;
		MD_Data_t		<= MD_Data_t_d;
	end block;
end;
