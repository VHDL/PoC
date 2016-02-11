-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================================================================================================
-- Authors:					Patrick Lehmann
-- 
-- Module:					I2C Switch Controller for a TI PCA9548A
-- 
-- Description:
-- ------------------------------------
--		TODO TODO
--
-- License:
-- ============================================================================================================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.iic.all;


entity iic_Switch_PCA9548A is
	generic (
		DEBUG											: BOOLEAN						:= FALSE;
		ALLOW_MEALY_TRANSITION		: BOOLEAN						:= TRUE;
		SWITCH_ADDRESS						: T_SLV_8						:= x"00";
		ADD_BYPASS_PORT						: BOOLEAN						:= FALSE;
		ADDRESS_BITS							: POSITIVE					:= 7;
		DATA_BITS									: POSITIVE					:= 8
	);
	port (
		Clock							: in	STD_LOGIC;
		Reset							: in	STD_LOGIC;
		
		-- IICSwitch interface ports
		Request						: in	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		Grant							: out	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		Command						: in	T_IO_IIC_COMMAND_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		Status						: out	T_IO_IIC_STATUS_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		Error							: out	T_IO_IIC_ERROR_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		Address						: in	T_SLM(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0, ADDRESS_BITS downto 1);

		WP_Valid					: in	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		WP_Data						: in	T_SLM(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0, DATA_BITS - 1 downto 0);
		WP_Last						: in	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		WP_Ack						: out	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		RP_Valid					: out	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		RP_Data						: out	T_SLM(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0, DATA_BITS - 1 downto 0);
		RP_Last						: out	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		RP_Ack						: in	STD_LOGIC_VECTOR(ite(ADD_BYPASS_PORT, 9, 8) - 1 downto 0);
		
		-- IICController master interface
		IICC_Request			: out	STD_LOGIC;
		IICC_Grant				: in	STD_LOGIC;
		IICC_Command			: out	T_IO_IIC_COMMAND;
		IICC_Status				: in	T_IO_IIC_STATUS;
		IICC_Error				: in	T_IO_IIC_ERROR;
		IICC_Address			: out	STD_LOGIC_VECTOR(ADDRESS_BITS downto 1);
		IICC_WP_Valid			: out	STD_LOGIC;
		IICC_WP_Data			: out	STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
		IICC_WP_Last			: out	STD_LOGIC;
		IICC_WP_Ack				: in	STD_LOGIC;
		IICC_RP_Valid			: in	STD_LOGIC;
		IICC_RP_Data			: in	STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
		IICC_RP_Last			: in	STD_LOGIC;
		IICC_RP_Ack				: out	STD_LOGIC;
		
		IICSwitch_Reset		: out	STD_LOGIC
	);
end entity;


architecture rtl of iic_Switch_PCA9548A is
	attribute KEEP										: BOOLEAN;
	attribute FSM_ENCODING						: STRING;
	attribute ENUM_ENCODING						: STRING;
	
	constant PORTS										: POSITIVE						:= ite(ADD_BYPASS_PORT, 9, 8);
	
	type T_STATE is (
		ST_IDLE,
		ST_REQUEST,
		ST_WRITE_SWITCH_DEVICE_ADDRESS, ST_WRITE_WAIT,
		ST_TRANSACTION,
		ST_ERROR
	);
	
	signal State												: T_STATE						:= ST_IDLE;
	signal NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING of State			: signal is ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	signal Request_or							: STD_LOGIC;
	signal FSM_Arbitrate					: STD_LOGIC;
	
--	SIGNAL Arb_Arbitrated					: STD_LOGIC;
	signal Arb_Grant							: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal Arb_Grant_bin					: STD_LOGIC_VECTOR(log2ceilnz(PORTS) - 1 downto 0);
	
begin

	Request_or		<= slv_or(Request);
	
	Arb : entity PoC.bus_Arbiter
		generic map (
			STRATEGY									=> "RR",			-- RR, LOT
			PORTS											=> PORTS,
			WEIGHTS										=> (0 to PORTS - 1 => 1),
			OUTPUT_REG								=> FALSE
		)
		port map (
			Clock											=> Clock,
			Reset											=> Reset,
			
			Arbitrate									=> FSM_Arbitrate,
			Request_Vector						=> Request,
			
			Arbitrated								=> open,	--Arb_Arbitrated,
			Grant_Vector							=> Arb_Grant,
			Grant_Index								=> Arb_Grant_bin
		);
	

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

	process(State,
		Request, Request_or, Arb_Grant, Arb_Grant_bin,
		Command, Address, WP_Valid, WP_Data, WP_Last, RP_Ack,
		IICC_Grant, IICC_Status, IICC_WP_Ack, IICC_RP_Valid, IICC_RP_Data, IICC_RP_Last, IICC_Error)
	begin
		NextState									<= State;

		Grant											<= (others => '0');
		Status										<= (others => IO_IIC_STATUS_IDLE);
		Error											<= (others => IO_IIC_ERROR_NONE);
		WP_Ack										<= (others => '0');
		RP_Valid									<= (others => '0');
		RP_Data										<= (others => (others => '0'));
		RP_Last										<= (others => '0');

		IICC_Request							<= '0';
		IICC_Command							<= IO_IIC_CMD_NONE;
		IICC_Address							<= SWITCH_ADDRESS(IICC_Address'range);
		IICC_WP_Valid							<= '0';
		IICC_WP_Data							<= (others => '0');
		IICC_WP_Last							<= '0';
		IICC_RP_Ack								<= '0';
		
		IICSwitch_Reset						<= '0';
		
		FSM_Arbitrate							<= '0';
		
		case State is
			when ST_IDLE =>
				if (Request_or = '1') then
					FSM_Arbitrate				<= '1';
					NextState						<= ST_REQUEST;
					
					if ALLOW_MEALY_TRANSITION then
						IICC_Request			<= '1';
						
						if (IICC_Grant = '1') then
							if (ADD_BYPASS_PORT and (Arb_Grant(Arb_Grant'high) = '1')) then
								NextState			<= ST_TRANSACTION;
							else
								NextState			<= ST_WRITE_SWITCH_DEVICE_ADDRESS;
							end if;
						end if;
					end if;
				end if;
			
			when ST_REQUEST =>
				IICC_Request					<= '1';
				
				if (IICC_Grant = '1') then
					if (ADD_BYPASS_PORT and (Arb_Grant(Arb_Grant'high) = '1')) then
						NextState					<= ST_TRANSACTION;
					else
						NextState					<= ST_WRITE_SWITCH_DEVICE_ADDRESS;
					end if;
				end if;
	
			when ST_WRITE_SWITCH_DEVICE_ADDRESS =>
				IICC_Request					<= '1';
			
				IICC_Command					<= IO_IIC_CMD_SEND_BYTES;
				IICC_Address					<= SWITCH_ADDRESS(IICC_Address'range);
			
				IICC_WP_Valid					<= '1';
				IICC_WP_Data					<= Arb_Grant(IICC_WP_Data'range);
				IICC_WP_Last					<= '1';
				
				if (IICC_WP_Ack = '1') then
					NextState						<= ST_WRITE_WAIT;
				end if;
				
			when ST_WRITE_WAIT =>
				IICC_Request					<= '1';
				
				case IICC_Status is
					when IO_IIC_STATUS_SENDING =>						null;
					when IO_IIC_STATUS_SEND_COMPLETE =>			NextState <= ST_TRANSACTION;
					when IO_IIC_STATUS_ERROR =>
						case IICC_Error  is
							when IO_IIC_ERROR_ADDRESS_ERROR =>	NextState <= ST_ERROR;
							when IO_IIC_ERROR_ACK_ERROR =>			NextState <= ST_ERROR;
							when IO_IIC_ERROR_BUS_ERROR =>			NextState <= ST_ERROR;
							when IO_IIC_ERROR_FSM =>						NextState <= ST_ERROR;
							when others =>											NextState <= ST_ERROR;
						end case;
					when others =>													NextState <= ST_ERROR;
				end case;
	
			when ST_TRANSACTION =>
				Grant									<= Arb_Grant;
				
				IICC_Request					<= '1';
				IICC_Command					<= Command(					to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_Address					<= get_row(Address, to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_WP_Valid					<= WP_Valid(				to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_WP_Data					<= get_row(WP_Data, to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_WP_Last					<= WP_Last(					to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				IICC_RP_Ack						<= RP_Ack(					to_index(Arb_Grant_bin, Arb_Grant'length - 1));
				
				for i in 0 to PORTS - 1 loop
					if (I = to_index(Arb_Grant_bin, Arb_Grant'length - 1)) then
						Status(I)					<= IICC_Status;
						Error(I)					<= IICC_Error;
					else
						Status(I)					<= IO_IIC_STATUS_IDLE;
						Error(I)					<= IO_IIC_ERROR_NONE;
					end if;
				end loop;
	
				WP_Ack								<= Arb_Grant AND (Arb_Grant'range => IICC_WP_Ack);
				RP_Valid							<= Arb_Grant AND (Arb_Grant'range => IICC_RP_Valid);
--				RP_Data								<= Arb_Grant AND (Arb_Grant'range => IICC_RP_Data);
				RP_Last								<= Arb_Grant AND (Arb_Grant'range => IICC_RP_Last);
	
				if (Request(to_index(Arb_Grant_bin, Arb_Grant'length - 1)) = '0') then
					NextState						<= ST_IDLE;
				end if;
	
			when ST_ERROR =>
				Status								<= (others => IO_IIC_STATUS_ERROR);
				Error									<= (others => IO_IIC_ERROR_FSM);
				
				NextState							<= ST_IDLE;
			
		end case;
	end process;

end architecture;
