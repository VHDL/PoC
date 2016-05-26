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
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
--USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.io.ALL;				-- TODO: move MDIO types to a MDIO package
USE			PoC.iic.ALL;
USE			PoC.net.ALL;


ENTITY mdio_IIC_Adapter IS
	GENERIC (
		DEBUG													: BOOLEAN												:= TRUE
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;

		-- MDIO interface
		Command												: IN	T_IO_MDIO_MDIOCONTROLLER_COMMAND;
		Status												: OUT	T_IO_MDIO_MDIOCONTROLLER_STATUS;
		Error													: OUT	T_IO_MDIO_MDIOCONTROLLER_ERROR;

		DeviceAddress									: IN	STD_LOGIC_VECTOR(6 DOWNTO 0);
		RegisterAddress								: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
		DataIn												: IN	T_SLV_16;
		DataOut												: OUT	T_SLV_16;

		-- IICController master interface
		IICC_Request									: OUT	STD_LOGIC;
		IICC_Grant										: IN	STD_LOGIC;
		IICC_Command									: OUT	T_IO_IIC_COMMAND;
		IICC_Status										: IN	T_IO_IIC_STATUS;
		IICC_Error										: IN	T_IO_IIC_ERROR;

		IICC_Address									: OUT	T_SLV_8;

		IICC_WP_Valid									: OUT	STD_LOGIC;
		IICC_WP_Data									: OUT	T_SLV_8;
		IICC_WP_Last									: OUT	STD_LOGIC;
		IICC_WP_Ack										: IN	STD_LOGIC;
		IICC_RP_Valid									: IN	STD_LOGIC;
		IICC_RP_Data									: IN	T_SLV_8;
		IICC_RP_Last									: IN	STD_LOGIC;
		IICC_RP_Ack										: OUT	STD_LOGIC
	);
END ENTITY;

-- TODOs
--	add Status := IO_MDIO_MDIOC_STATUS_ADDRESS_ERROR if IICC.Status = ACK_ERROR

ARCHITECTURE rtl OF mdio_IIC_Adapter IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	TYPE T_STATE IS (
		ST_IDLE,
		ST_READ_REQUEST_BUS,
			ST_READ_SEND_COMMAND,
			ST_READ_BYTE_0,
			ST_READ_BYTE_1,
			ST_READ_WAIT_FOR_COMPLETION,
			ST_READ_BYTES_COMPLETE,
		ST_WRITE_REQUEST_BUS,
			ST_WRITE_SEND_COMMAND,
			ST_WRITE_BYTE_0,
			ST_WRITE_BYTE_1,
			ST_WRITE_WAIT_FOR_COMPLETION,
			ST_WRITE_BYTES_COMPLETE,
		ST_ADDRESS_ERROR, ST_ERROR
	);

	SIGNAL State												: T_STATE										:= ST_IDLE;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS "gray";

	SIGNAL DeviceAddressRegister_Load		: STD_LOGIC;
	SIGNAL DeviceAddressRegister_d			: STD_LOGIC_VECTOR(DeviceAddress'range)		:= (OTHERS => '0');

	SIGNAL RegisterAddressRegister_Load	: STD_LOGIC;
	SIGNAL RegisterAddressRegister_d		: STD_LOGIC_VECTOR(RegisterAddress'range)	:= (OTHERS => '0');

	SUBTYPE T_BYTE_INDEX IS NATURAL  RANGE 0 TO 1;
	SIGNAL DataRegister_Load						: STD_LOGIC;
	SIGNAL DataRegister_we							: STD_LOGIC;
	SIGNAL DataRegister_d								: T_SLVV_8(1 DOWNTO 0)										:= (OTHERS => (OTHERS => '0'));
	SIGNAL DataRegister_idx							: T_BYTE_INDEX;

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

	PROCESS(State, Command, IICC_Grant, IICC_Status, IICC_Error, IICC_WP_Ack, IICC_RP_Valid, IICC_RP_Data, IICC_RP_Last)
	BEGIN
		NextState											<= State;

		Status												<= IO_MDIO_MDIOC_STATUS_IDLE;
		Error													<= IO_MDIO_MDIOC_ERROR_NONE;

		IICC_Command									<= IO_IIC_CMD_NONE;

		IICC_WP_Valid									<= '0';
		IICC_WP_Data									<= (OTHERS => '0');
		IICC_WP_Last									<= '0';

		IICC_RP_Ack										<= '0';

		DeviceAddressRegister_Load		<= '0';
		RegisterAddressRegister_Load	<= '0';
		DataRegister_Load							<= '0';
		DataRegister_we								<= '0';
		DataRegister_idx							<= 0;

		CASE State IS
			WHEN ST_IDLE =>
				Status														<= IO_MDIO_MDIOC_STATUS_IDLE;

				CASE Command IS
					WHEN IO_MDIO_MDIOC_CMD_NONE =>
						NULL;

					WHEN IO_MDIO_MDIOC_CMD_READ =>
						DeviceAddressRegister_Load		<= '1';
						RegisterAddressRegister_Load	<= '1';

						NextState											<= ST_READ_REQUEST_BUS;

					WHEN IO_MDIO_MDIOC_CMD_WRITE =>
						DeviceAddressRegister_Load		<= '1';
						RegisterAddressRegister_Load	<= '1';
						DataRegister_Load							<= '1';

						NextState											<= ST_WRITE_REQUEST_BUS;

					WHEN OTHERS =>
						NextState											<= ST_ERROR;

				END CASE;

			WHEN ST_READ_REQUEST_BUS =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';

				IF (IICC_Grant = '1') THEN
					NextState								<= ST_READ_SEND_COMMAND;
				END IF;

			WHEN ST_READ_SEND_COMMAND =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';
				IICC_Command 							<= IO_IIC_CMD_PROCESS_CALL;
				IICC_Address							<= resize(DeviceAddressRegister_d, IICC_Address'length);
				IICC_WP_Valid							<= '1';
				IICC_WP_Data							<= resize(RegisterAddressRegister_d, IICC_WP_Data'length);
				IICC_WP_Last							<= '1';

				NextState									<= ST_READ_BYTE_0;

			WHEN ST_READ_BYTE_0 =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';

				DataRegister_idx					<= 0;

				CASE IICC_Status IS
					WHEN IO_IIC_STATUS_CALLING =>
						IF (IICC_RP_Valid = '1') THEN
							DataRegister_we			<= '1';
							NextState						<= ST_READ_BYTE_1;
						END IF;
					WHEN IO_IIC_STATUS_CALL_COMPLETE =>			NextState		<= ST_ERROR;
					WHEN IO_IIC_STATUS_ERROR =>
						CASE IICC_Error IS
							WHEN IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>											NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>													NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_READ_BYTE_1 =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';
				DataRegister_idx					<= 1;

				CASE IICC_Status IS
					WHEN IO_IIC_STATUS_CALLING =>
						IF (IICC_RP_Valid = '1') THEN
							DataRegister_we			<= '1';
							NextState						<= ST_READ_WAIT_FOR_COMPLETION;
						END IF;
					WHEN IO_IIC_STATUS_CALL_COMPLETE =>			NextState		<= ST_ERROR;
					WHEN IO_IIC_STATUS_ERROR =>
						CASE IICC_Error IS
							WHEN IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>											NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>													NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_READ_WAIT_FOR_COMPLETION =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';

				CASE IICC_Status IS
					WHEN IO_IIC_STATUS_CALLING =>						NULL;
					WHEN IO_IIC_STATUS_CALL_COMPLETE =>			NextState		<= ST_READ_BYTES_COMPLETE;
					WHEN IO_IIC_STATUS_ERROR =>
						CASE IICC_Error IS
							WHEN IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>											NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>													NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_READ_BYTES_COMPLETE =>
				Status										<= IO_MDIO_MDIOC_STATUS_READ_COMPLETE;
				NextState									<= ST_IDLE;

			-- ======================================================================================================================================================
			WHEN ST_WRITE_REQUEST_BUS =>
				IICC_Request							<= '1';

				IF (IICC_Grant = '1') THEN
					NextState								<= ST_WRITE_SEND_COMMAND;
				END IF;

			WHEN ST_WRITE_SEND_COMMAND =>
				Status										<= IO_MDIO_MDIOC_STATUS_WRITING;
				IICC_Request							<= '1';
				IICC_Command 							<= IO_IIC_CMD_SEND_BYTES;
				IICC_Address							<= resize(DeviceAddressRegister_d, IICC_Address'length);
				IICC_WP_Valid							<= '1';
				IICC_WP_Data							<= resize(RegisterAddressRegister_d, IICC_WP_Data'length);

				NextState									<= ST_WRITE_BYTE_0;

			WHEN ST_WRITE_BYTE_0 =>
				Status										<= IO_MDIO_MDIOC_STATUS_WRITING;
				IICC_Request							<= '1';
				IICC_WP_Valid							<= '1';
				IICC_WP_Data							<= DataRegister_d(0);

				CASE IICC_Status IS
					WHEN IO_IIC_STATUS_SENDING =>
						IF (IICC_WP_Ack = '1') THEN
							NextState						<= ST_WRITE_BYTE_1;
						END IF;
					WHEN IO_IIC_STATUS_SEND_COMPLETE =>			NextState		<= ST_ERROR;
					WHEN IO_IIC_STATUS_ERROR =>
						CASE IICC_Error IS
							WHEN IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>											NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>													NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_WRITE_BYTE_1 =>
				Status										<= IO_MDIO_MDIOC_STATUS_WRITING;
				IICC_Request							<= '1';
				IICC_WP_Valid							<= '1';
				IICC_WP_Data							<= DataRegister_d(1);
				IICC_WP_Last							<= '1';

				CASE IICC_Status IS
					WHEN IO_IIC_STATUS_SENDING =>
						IF (IICC_WP_Ack = '1') THEN
							NextState						<= ST_WRITE_WAIT_FOR_COMPLETION;
						END IF;
					WHEN IO_IIC_STATUS_SEND_COMPLETE =>			NextState		<= ST_ERROR;
					WHEN IO_IIC_STATUS_ERROR =>
						CASE IICC_Error IS
							WHEN IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>											NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>													NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_WRITE_WAIT_FOR_COMPLETION =>
				Status										<= IO_MDIO_MDIOC_STATUS_WRITING;
				IICC_Request							<= '1';

				CASE IICC_Status IS
					WHEN IO_IIC_STATUS_SENDING =>						NULL;
					WHEN IO_IIC_STATUS_SEND_COMPLETE =>			NextState		<= ST_WRITE_BYTES_COMPLETE;
					WHEN IO_IIC_STATUS_ERROR =>
						CASE IICC_Error IS
							WHEN IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							WHEN IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							WHEN IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							WHEN OTHERS =>											NextState		<= ST_ERROR;
						END CASE;
					WHEN OTHERS =>													NextState		<= ST_ERROR;
				END CASE;

			WHEN ST_WRITE_BYTES_COMPLETE =>
				Status									<= IO_MDIO_MDIOC_STATUS_WRITE_COMPLETE;
				NextState								<= ST_IDLE;

			WHEN ST_ADDRESS_ERROR =>
				Status									<= IO_MDIO_MDIOC_STATUS_ERROR;
				Error										<= IO_MDIO_MDIOC_ERROR_ADDRESS_NOT_FOUND;
				NextState								<= ST_IDLE;

			WHEN ST_ERROR =>
				Status									<= IO_MDIO_MDIOC_STATUS_ERROR;
				Error										<= IO_MDIO_MDIOC_ERROR_FSM;
				NextState								<= ST_IDLE;

		END CASE;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				DeviceAddressRegister_d							<= (OTHERS => '0');
				RegisterAddressRegister_d						<= (OTHERS => '0');
				DataRegister_d											<= (OTHERS => (OTHERS => '0'));
			ELSE
				IF (DeviceAddressRegister_Load	= '1') THEN
					DeviceAddressRegister_d						<= DeviceAddress;
				END IF;

				IF (RegisterAddressRegister_Load	= '1') THEN
					RegisterAddressRegister_d					<= RegisterAddress;
				END IF;

				IF (DataRegister_Load	= '1') THEN
					DataRegister_d										<= to_slvv_8(DataIn);
--					DataRegister_d(1)									<= DataIn(15 DOWNTO 8);
				ELSIF (DataRegister_we	= '1') THEN
					DataRegister_d(DataRegister_idx)	<= IICC_RP_Data;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	DataOut			<= to_slv(DataRegister_d);
END;
