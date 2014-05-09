-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================================================================================================
-- Module:					I²C Switch Controller for a TI PCA9548A
-- 
-- Authors:					Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO TODO
--
-- License:
-- ============================================================================================================================================================
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
-- ============================================================================================================================================================


LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.io.ALL;

--LIBRARY L_Global;


ENTITY IICSwitch_PCA9548A IS
	GENERIC (
		DEBUG											: BOOLEAN						:= FALSE;
		ALLOW_MEALY_TRANSITION		: BOOLEAN						:= TRUE;
		SWITCH_ADDRESS						: T_SLV_8						:= x"00";
		ADD_BYPASS_PORT						: BOOLEAN						:= FALSE;
		ADDRESS_BITS							: POSITIVE					:= 7;
		DATA_BITS									: POSITIVE					:= 8
	);
	PORT (
		Clock							: IN	STD_LOGIC;
		Reset							: IN	STD_LOGIC;
		
		-- IICSwitch interface ports
		Request						: IN	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		Grant							: OUT	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		Command						: IN	T_IO_IIC_COMMAND_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		Status						: OUT	T_IO_IIC_STATUS_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		Error							: OUT	T_IO_IIC_ERROR_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		Address						: IN	T_SLM(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0, ADDRESS_BITS DOWNTO 1);

		WP_Valid					: IN	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		WP_Data						: IN	T_SLM(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0, DATA_BITS - 1 DOWNTO 0);
		WP_Last						: IN	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		WP_Ack						: OUT	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		RP_Valid					: OUT	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		RP_Data						: OUT	T_SLM(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0, DATA_BITS - 1 DOWNTO 0);
		RP_Last						: OUT	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		RP_Ack						: IN	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 DOWNTO 0);
		
		-- IICController master interface
		IICC_Request			: OUT	STD_LOGIC;
		IICC_Grant				: IN	STD_LOGIC;
		IICC_Command			: OUT	T_IO_IIC_COMMAND;
		IICC_Status				: IN	T_IO_IIC_STATUS;
		IICC_Error				: IN	T_IO_IIC_ERROR;
		IICC_Address			: OUT	STD_LOGIC_VECTOR(ADDRESS_BITS DOWNTO 1);
		IICC_WP_Valid			: OUT	STD_LOGIC;
		IICC_WP_Data			: OUT	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		IICC_WP_Last			: OUT	STD_LOGIC;
		IICC_WP_Ack				: IN	STD_LOGIC;
		IICC_RP_Valid			: IN	STD_LOGIC;
		IICC_RP_Data			: IN	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		IICC_RP_Last			: IN	STD_LOGIC;
		IICC_RP_Ack				: OUT	STD_LOGIC;
		
		IICSwitch_Reset		: OUT	STD_LOGIC
	);
END ENTITY;


ARCHITECTURE rtl OF IICSwitch_PCA9548A IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	ATTRIBUTE ENUM_ENCODING						: STRING;
	
	CONSTANT PORTS										: POSITIVE						:= ite(ADD_BYPASS_PORT, 9, 8);
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_REQUEST,
		ST_WRITE_SWITCH_DEVICE_ADDRESS, ST_WRITE_WAIT,
		ST_TRANSACTION,
		ST_ERROR
	);
	
	SIGNAL State												: T_STATE						:= ST_IDLE;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	SIGNAL Request_or							: STD_LOGIC;
	SIGNAL FSM_Arbitrate					: STD_LOGIC;
	
--	SIGNAL Arb_Arbitrated					: STD_LOGIC;
	SIGNAL Arb_Grant							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Arb_Grant_bin					: STD_LOGIC_VECTOR(log2ceilnz(PORTS) - 1 DOWNTO 0);
	
BEGIN

	Request_or		<= slv_or(Request);
	
	Arb : ENTITY PoC.bus_Arbiter
		GENERIC MAP (
			STRATEGY									=> "RR",			-- RR, LOT
			PORTS											=> PORTS,
			WEIGHTS										=> (0 TO PORTS - 1 => 1),
			OUTPUT_REG								=> FALSE
		)
		PORT MAP (
			Clock											=> Clock,
			Reset											=> Reset,
			
			Arbitrate									=> FSM_Arbitrate,
			Request_Vector						=> Request,
			
			Arbitrated								=> OPEN,	--Arb_Arbitrated,
			Grant_Vector							=> Arb_Grant,
			Grant_Index								=> Arb_Grant_bin
		);
	

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

	PROCESS(State,
		Request_or, Arb_Grant, Arb_Grant_bin,
		Command, Address, WP_Valid, WP_Data, WP_Last, RP_Ack,
		IICC_Grant, IICC_Status, IICC_WP_Ack, IICC_RP_Valid, IICC_RP_Data, IICC_RP_Last)
	BEGIN
		NextState									<= State;

		Grant											<= (OTHERS => '0');
		Status										<= (OTHERS => IO_IIC_STATUS_IDLE);
		Error											<= (OTHERS => IO_IIC_ERROR_NONE);
		WP_Ack										<= (OTHERS => '0');
		RP_Valid									<= (OTHERS => '0');
		RP_Data										<= (OTHERS => (OTHERS => '0'));
		RP_Last										<= (OTHERS => '0');

		IICC_Request							<= '0';
		IICC_Command							<= IO_IIC_CMD_NONE;
		IICC_Address							<= SWITCH_ADDRESS(IICC_Address'range);
		IICC_WP_Valid							<= '0';
		IICC_WP_Data							<= (OTHERS => '0');
		IICC_WP_Last							<= '0';
		
		FSM_Arbitrate							<= '0';
		
		CASE State IS
			WHEN ST_IDLE =>
				IF (Request_or = '1') THEN
					FSM_Arbitrate				<= '1';
					NextState						<= ST_REQUEST;
					
					IF ALLOW_MEALY_TRANSITION THEN
						IICC_Request			<= '1';
						
						IF (IICC_Grant = '1') THEN
							IF (ADD_BYPASS_PORT AND (Arb_Grant(Arb_Grant'high) = '1')) THEN
								NextState			<= ST_TRANSACTION;
							ELSE
								NextState			<= ST_WRITE_SWITCH_DEVICE_ADDRESS;
							END IF;
						END IF;
					END IF;
				END IF;
			
			WHEN ST_REQUEST =>
				IICC_Request					<= '1';
				
				IF (IICC_Grant = '1') THEN
					IF (ADD_BYPASS_PORT AND (Arb_Grant(Arb_Grant'high) = '1')) THEN
						NextState					<= ST_TRANSACTION;
					ELSE
						NextState					<= ST_WRITE_SWITCH_DEVICE_ADDRESS;
					END IF;
				END IF;
	
			WHEN ST_WRITE_SWITCH_DEVICE_ADDRESS =>
				IICC_Request					<= '1';
			
				IICC_Command					<= IO_IIC_CMD_SEND_BYTES;
				IICC_Address					<= SWITCH_ADDRESS(IICC_Address'range);
			
				IICC_WP_Valid					<= '1';
				IICC_WP_Data					<= Arb_Grant(IICC_WP_Data'range);
				IICC_WP_Last					<= '1';
				
				IF (IICC_WP_Ack = '1') THEN
					NextState						<= ST_WRITE_WAIT;
				END IF;
				
			WHEN ST_WRITE_WAIT =>
				IICC_Request					<= '1';
				
				CASE IICC_Status IS
					WHEN IO_IIC_STATUS_SENDING =>						NULL;
					WHEN IO_IIC_STATUS_SEND_COMPLETE =>			NextState <= ST_TRANSACTION;
					WHEN IO_IIC_STATUS_ERROR =>
						CASE IICC_Error  IS
							WHEN IO_IIC_ERROR_ADDRESS_ERROR =>	NextState <= ST_ERROR;
							WHEN IO_IIC_ERROR_ACK_ERROR =>			NextState <= ST_ERROR;
							WHEN IO_IIC_ERROR_BUS_ERROR =>			NextState <= ST_ERROR;
							WHEN IO_IIC_ERROR_FSM =>						NextState <= ST_ERROR;
							WHEN OTHERS =>											NextState <= ST_ERROR;
						END CASE;
					WHEN OTHERS =>													NextState <= ST_ERROR;
				END CASE;
	
			WHEN ST_TRANSACTION =>
				Grant									<= Arb_Grant;
				
				IICC_Request					<= '1';
				IICC_Command					<= Command(					to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_Address					<= get_row(Address, to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_WP_Valid					<= WP_Valid(				to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_WP_Data					<= get_row(WP_Data, to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_WP_Last					<= WP_Last(					to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_RP_Ack						<= RP_Ack(					to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				
				FOR I IN 0 TO PORTS - 1 LOOP
					IF (I = to_index(Arb_Grant_bin, Arb_Grant'length - 1)) THEN
						Status(I)					<= IICC_Status;
						Error(I)					<= IICC_Error;
					ELSE
						Status(I)					<= IO_IIC_STATUS_IDLE;
						Error(I)					<= IO_IIC_ERROR_NONE;
					END IF;
				END LOOP;
	
				WP_Ack								<= Arb_Grant AND (Arb_Grant'range => IICC_WP_Ack);
				RP_Valid							<= Arb_Grant AND (Arb_Grant'range => IICC_RP_Valid);
--				RP_Data								<= Arb_Grant AND (Arb_Grant'range => IICC_RP_Data);
				RP_Last								<= Arb_Grant AND (Arb_Grant'range => IICC_RP_Last);
	
				IF (Request(to_index(Arb_Grant_bin, Arb_Grant'length - 1)) = '0') THEN
					NextState						<= ST_IDLE;
				END IF;
	
			WHEN ST_ERROR =>
				Status								<= (OTHERS => IO_IIC_STATUS_ERROR);
				Error									<= (OTHERS => IO_IIC_ERROR_FSM);
				
				NextState							<= ST_IDLE;
			
		END CASE;
	END PROCESS;

END;
