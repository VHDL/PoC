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
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
--use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.io.all;				-- TODO: move MDIO types to a MDIO package
use			PoC.iic.all;
use			PoC.net.all;


entity mdio_IIC_Adapter is
	generic (
		DEBUG													: boolean												:= TRUE
	);
	port (
		Clock													: in	std_logic;
		Reset													: in	std_logic;
		
		-- MDIO interface
		Command												: in	T_IO_MDIO_MDIOCONTROLLER_COMMAND;
		Status												: out	T_IO_MDIO_MDIOCONTROLLER_STATUS;
		Error													: out	T_IO_MDIO_MDIOCONTROLLER_ERROR;
		
		DeviceAddress									: in	std_logic_vector(6 downto 0);
		RegisterAddress								: in	std_logic_vector(4 downto 0);
		DataIn												: in	T_SLV_16;
		DataOut												: out	T_SLV_16;
		
		-- IICController master interface
		IICC_Request									: out	std_logic;
		IICC_Grant										: in	std_logic;
		IICC_Command									: out	T_IO_IIC_COMMAND;
		IICC_Status										: in	T_IO_IIC_STATUS;
		IICC_Error										: in	T_IO_IIC_ERROR;
		
		IICC_Address									: out	T_SLV_8;
		
		IICC_WP_Valid									: out	std_logic;
		IICC_WP_Data									: out	T_SLV_8;
		IICC_WP_Last									: out	std_logic;
		IICC_WP_Ack										: in	std_logic;
		IICC_RP_Valid									: in	std_logic;
		IICC_RP_Data									: in	T_SLV_8;
		IICC_RP_Last									: in	std_logic;
		IICC_RP_Ack										: out	std_logic
	);
end entity;

-- TODOs
--	add Status := IO_MDIO_MDIOC_STATUS_ADDRESS_ERROR if IICC.Status = ACK_ERROR

architecture rtl of mdio_IIC_Adapter is
	attribute KEEP										: boolean;
	attribute FSM_ENCODING						: string;
	
	type T_STATE is (
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
	
	signal State												: T_STATE										:= ST_IDLE;
	signal NextState										: T_STATE;
	attribute FSM_ENCODING of State			: signal is "gray";
	
	signal DeviceAddressRegister_Load		: std_logic;
	signal DeviceAddressRegister_d			: std_logic_vector(DeviceAddress'range)		:= (others => '0');
	
	signal RegisterAddressRegister_Load	: std_logic;
	signal RegisterAddressRegister_d		: std_logic_vector(RegisterAddress'range)	:= (others => '0');
	
	subtype T_BYTE_INDEX is natural  range 0 to 1;
	signal DataRegister_Load						: std_logic;
	signal DataRegister_we							: std_logic;
	signal DataRegister_d								: T_SLVV_8(1 downto 0)										:= (others => (others => '0'));
	signal DataRegister_idx							: T_BYTE_INDEX;
	
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
	
	process(State, Command, IICC_Grant, IICC_Status, IICC_Error, IICC_WP_Ack, IICC_RP_Valid, IICC_RP_Data, IICC_RP_Last)
	begin
		NextState											<= State;
		
		Status												<= IO_MDIO_MDIOC_STATUS_IDLE;
		Error													<= IO_MDIO_MDIOC_ERROR_NONE;
		
		IICC_Command									<= IO_IIC_CMD_NONE;
		
		IICC_WP_Valid									<= '0';
		IICC_WP_Data									<= (others => '0');
		IICC_WP_Last									<= '0';
		
		IICC_RP_Ack										<= '0';
		
		DeviceAddressRegister_Load		<= '0';
		RegisterAddressRegister_Load	<= '0';
		DataRegister_Load							<= '0';
		DataRegister_we								<= '0';
		DataRegister_idx							<= 0;
		
		case State is
			when ST_IDLE =>
				Status														<= IO_MDIO_MDIOC_STATUS_IDLE;
				
				case Command is
					when IO_MDIO_MDIOC_CMD_NONE =>
						null;
						
					when IO_MDIO_MDIOC_CMD_READ =>
						DeviceAddressRegister_Load		<= '1';
						RegisterAddressRegister_Load	<= '1';
						
						NextState											<= ST_READ_REQUEST_BUS;
						
					when IO_MDIO_MDIOC_CMD_WRITE =>
						DeviceAddressRegister_Load		<= '1';
						RegisterAddressRegister_Load	<= '1';
						DataRegister_Load							<= '1';
						
						NextState											<= ST_WRITE_REQUEST_BUS;
						
					when others =>
						NextState											<= ST_ERROR;
						
				end case;
				
			when ST_READ_REQUEST_BUS =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';
				
				if (IICC_Grant = '1') then
					NextState								<= ST_READ_SEND_COMMAND;
				end if;
				
			when ST_READ_SEND_COMMAND =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';
				IICC_Command 							<= IO_IIC_CMD_PROCESS_CALL;
				IICC_Address							<= resize(DeviceAddressRegister_d, IICC_Address'length);
				IICC_WP_Valid							<= '1';
				IICC_WP_Data							<= resize(RegisterAddressRegister_d, IICC_WP_Data'length);
				IICC_WP_Last							<= '1';
				
				NextState									<= ST_READ_BYTE_0;
				
			when ST_READ_BYTE_0 =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';
				
				DataRegister_idx					<= 0;
				
				case IICC_Status is
					when IO_IIC_STATUS_CALLING =>
						if (IICC_RP_Valid = '1') then
							DataRegister_we			<= '1';
							NextState						<= ST_READ_BYTE_1;
						end if;
					when IO_IIC_STATUS_CALL_COMPLETE =>			NextState		<= ST_ERROR;
					when IO_IIC_STATUS_ERROR =>
						case IICC_Error is
							when IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							when IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							when IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							when others =>											NextState		<= ST_ERROR;
						end case;
					when others =>													NextState		<= ST_ERROR;
				end case;
				
			when ST_READ_BYTE_1 =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';
				DataRegister_idx					<= 1;
				
				case IICC_Status is
					when IO_IIC_STATUS_CALLING =>
						if (IICC_RP_Valid = '1') then
							DataRegister_we			<= '1';
							NextState						<= ST_READ_WAIT_FOR_COMPLETION;
						end if;
					when IO_IIC_STATUS_CALL_COMPLETE =>			NextState		<= ST_ERROR;
					when IO_IIC_STATUS_ERROR =>
						case IICC_Error is
							when IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							when IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							when IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							when others =>											NextState		<= ST_ERROR;
						end case;
					when others =>													NextState		<= ST_ERROR;
				end case;
				
			when ST_READ_WAIT_FOR_COMPLETION =>
				Status										<= IO_MDIO_MDIOC_STATUS_READING;
				IICC_Request							<= '1';
				
				case IICC_Status is
					when IO_IIC_STATUS_CALLING =>						null;
					when IO_IIC_STATUS_CALL_COMPLETE =>			NextState		<= ST_READ_BYTES_COMPLETE;
					when IO_IIC_STATUS_ERROR =>
						case IICC_Error is
							when IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							when IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							when IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							when others =>											NextState		<= ST_ERROR;
						end case;
					when others =>													NextState		<= ST_ERROR;
				end case;
				
			when ST_READ_BYTES_COMPLETE =>
				Status										<= IO_MDIO_MDIOC_STATUS_READ_COMPLETE;
				NextState									<= ST_IDLE;
				
			-- ======================================================================================================================================================
			when ST_WRITE_REQUEST_BUS =>
				IICC_Request							<= '1';
				
				if (IICC_Grant = '1') then
					NextState								<= ST_WRITE_SEND_COMMAND;
				end if;
				
			when ST_WRITE_SEND_COMMAND =>
				Status										<= IO_MDIO_MDIOC_STATUS_WRITING;
				IICC_Request							<= '1';
				IICC_Command 							<= IO_IIC_CMD_SEND_BYTES;
				IICC_Address							<= resize(DeviceAddressRegister_d, IICC_Address'length);
				IICC_WP_Valid							<= '1';
				IICC_WP_Data							<= resize(RegisterAddressRegister_d, IICC_WP_Data'length);
				
				NextState									<= ST_WRITE_BYTE_0;
				
			when ST_WRITE_BYTE_0 =>
				Status										<= IO_MDIO_MDIOC_STATUS_WRITING;
				IICC_Request							<= '1';
				IICC_WP_Valid							<= '1';
				IICC_WP_Data							<= DataRegister_d(0);
				
				case IICC_Status is
					when IO_IIC_STATUS_SENDING =>
						if (IICC_WP_Ack = '1') then
							NextState						<= ST_WRITE_BYTE_1;
						end if;
					when IO_IIC_STATUS_SEND_COMPLETE =>			NextState		<= ST_ERROR;
					when IO_IIC_STATUS_ERROR =>
						case IICC_Error is
							when IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							when IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							when IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							when others =>											NextState		<= ST_ERROR;
						end case;
					when others =>													NextState		<= ST_ERROR;
				end case;
				
			when ST_WRITE_BYTE_1 =>
				Status										<= IO_MDIO_MDIOC_STATUS_WRITING;
				IICC_Request							<= '1';
				IICC_WP_Valid							<= '1';
				IICC_WP_Data							<= DataRegister_d(1);
				IICC_WP_Last							<= '1';
				
				case IICC_Status is
					when IO_IIC_STATUS_SENDING =>
						if (IICC_WP_Ack = '1') then
							NextState						<= ST_WRITE_WAIT_FOR_COMPLETION;
						end if;
					when IO_IIC_STATUS_SEND_COMPLETE =>			NextState		<= ST_ERROR;
					when IO_IIC_STATUS_ERROR =>
						case IICC_Error is
							when IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							when IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							when IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							when others =>											NextState		<= ST_ERROR;
						end case;
					when others =>													NextState		<= ST_ERROR;
				end case;
				
			when ST_WRITE_WAIT_FOR_COMPLETION =>
				Status										<= IO_MDIO_MDIOC_STATUS_WRITING;
				IICC_Request							<= '1';
				
				case IICC_Status is
					when IO_IIC_STATUS_SENDING =>						null;
					when IO_IIC_STATUS_SEND_COMPLETE =>			NextState		<= ST_WRITE_BYTES_COMPLETE;
					when IO_IIC_STATUS_ERROR =>
						case IICC_Error is
							when IO_IIC_ERROR_BUS_ERROR =>			NextState		<= ST_ERROR;
							when IO_IIC_ERROR_ADDRESS_ERROR =>	NextState		<= ST_ADDRESS_ERROR;
							when IO_IIC_ERROR_ACK_ERROR =>			NextState		<= ST_ERROR;
							when others =>											NextState		<= ST_ERROR;
						end case;
					when others =>													NextState		<= ST_ERROR;
				end case;
				
			when ST_WRITE_BYTES_COMPLETE =>
				Status									<= IO_MDIO_MDIOC_STATUS_WRITE_COMPLETE;
				NextState								<= ST_IDLE;
				
			when ST_ADDRESS_ERROR =>
				Status									<= IO_MDIO_MDIOC_STATUS_ERROR;
				Error										<= IO_MDIO_MDIOC_ERROR_ADDRESS_NOT_FOUND;
				NextState								<= ST_IDLE;
				
			when ST_ERROR =>
				Status									<= IO_MDIO_MDIOC_STATUS_ERROR;
				Error										<= IO_MDIO_MDIOC_ERROR_FSM;
				NextState								<= ST_IDLE;
				
		end case;
	end process;
	
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				DeviceAddressRegister_d							<= (others => '0');
				RegisterAddressRegister_d						<= (others => '0');
				DataRegister_d											<= (others => (others => '0'));
			else
				if (DeviceAddressRegister_Load	= '1') then
					DeviceAddressRegister_d						<= DeviceAddress;
				end if;
				
				if (RegisterAddressRegister_Load	= '1') then
					RegisterAddressRegister_d					<= RegisterAddress;
				end if;
				
				if (DataRegister_Load	= '1') then
					DataRegister_d										<= to_slvv_8(DataIn);
--					DataRegister_d(1)									<= DataIn(15 downto 8);
				elsif (DataRegister_we	= '1') then
					DataRegister_d(DataRegister_idx)	<= IICC_RP_Data;
				end if;
			end if;
		end if;
	end process;
	
	DataOut			<= to_slv(DataRegister_d);
end;
