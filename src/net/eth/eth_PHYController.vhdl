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
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;
use			PoC.io.all;				-- TODO: move MDIO types and constants to a MDIO package
use			PoC.iic.all;
use			PoC.net.all;


entity Eth_PHYController is
	generic (
		DEBUG											: boolean																	:= FALSE;																			--
		CLOCK_FREQ								: FREQ																		:= 125 MHz;																		-- 125 MHz
		PCSCORE										: T_NET_ETH_PCSCORE												:= NET_ETH_PCSCORE_GENERIC_GMII;							--
		PHY_DEVICE								: T_NET_ETH_PHY_DEVICE										:= NET_ETH_PHY_DEVICE_MARVEL_88E1111;					--
		PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS						:= x"00";																			--
		PHY_MANAGEMENT_INTERFACE	: T_NET_ETH_PHY_MANAGEMENT_INTERFACE			:= NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO;			--
		BAUDRATE									: BAUD																		:= 1 MBd;																			-- 1.0 MBit/s+
		IS_SIM										: boolean 																:= false
	);
	port (
		Clock											: in		std_logic;
		Reset											: in		std_logic;
		
		-- PHYController interface
		Command										: in		T_NET_ETH_PHYCONTROLLER_COMMAND;
		Status										: out		T_NET_ETH_PHYCONTROLLER_STATUS;
		Error											: out		T_NET_ETH_PHYCONTROLLER_ERROR;
		
		MDIO_Read_Register				: in std_logic_vector(4 downto 0);
		MDIO_Register_Data				: out	T_SLV_16;
		
		PHY_Reset									: out		std_logic := 'Z';															--
		PHY_Interrupt							: in		std_logic;															--
		PHY_MDIO									: inout T_NET_ETH_PHY_INTERFACE_MDIO	:= C_NET_ETH_PHY_INTERFACE_MDIO_INIT					-- Management Data Input/Output
	);
end entity;


architecture rtl of Eth_PHYController is
	attribute KEEP											: boolean;
	attribute FSM_ENCODING							: string;
	
	signal PHYC_MDIO_Command						: T_IO_MDIO_MDIOCONTROLLER_COMMAND;
	signal MDIO_Status									: T_IO_MDIO_MDIOCONTROLLER_STATUS;
	signal MDIO_Error										: T_IO_MDIO_MDIOCONTROLLER_ERROR;
	
--	signal Strobe												: STD_LOGIC;
	signal PHYC_MDIO_Physical_Address		: std_logic_vector(6 downto 0);
	signal PHYC_MDIO_Register_Address		: std_logic_vector(4 downto 0);
	signal MDIOC_Register_DataIn				: T_SLV_16;
	signal PHYC_MDIO_Register_DataOut		: T_SLV_16;
	
	-- PCS_ADDRESS								: T_SLV_8																	:= x"00";
begin

--	assert FALSE report "BAUDRATE = " & BAUD'image(BAUDRATE) severity NOTE;
--	assert FALSE report "MD_CLOCK_FREQUENCY_KHZ = " & REAL'image(MD_CLOCK_FREQUENCY_KHZ)	& " kHz" severity NOTE;
	phy_device_gen0 : if IS_SIM = FALSE generate
		genMarvel88E1111 : if (PHY_DEVICE = NET_ETH_PHY_DEVICE_MARVEL_88E1111) generate
		
		begin
			PHYC : entity PoC.Eth_PHYController_Marvell_88E1111
				generic map (
					DEBUG										=> DEBUG,
					CLOCK_FREQ							=> CLOCK_FREQ,
					PHY_DEVICE_ADDRESS			=> PHY_DEVICE_ADDRESS
				)
				port map (
					Clock										=> Clock,
					Reset										=> Reset,
					
					-- PHYController interface
					Command									=> Command,
					Status									=> Status,
					Error										=> Error,
					
					PHY_Reset								=> PHY_Reset,
					PHY_Interrupt						=> PHY_Interrupt,
					
					MDIO_Command						=> PHYC_MDIO_Command,
					MDIO_Status							=> MDIO_Status,
					MDIO_Error							=> MDIO_Error,
					
					MDIO_Physical_Address		=> PHYC_MDIO_Physical_Address,
					MDIO_Register_Address		=> PHYC_MDIO_Register_Address,
					MDIO_Register_DataIn		=> MDIOC_Register_DataIn,
					MDIO_Register_DataOut		=> PHYC_MDIO_Register_DataOut,
					
					MDIO_Read_Register			=> MDIO_Read_Register,
					MDIO_Register_Data			=> MDIO_Register_Data
				);
		end generate;
	end generate;
	
	phy_device_gen1 : if IS_SIM = TRUE generate
		Status <= NET_ETH_PHYC_STATUS_CONNECTED;
		Error <= NET_ETH_PHYC_ERROR_NONE;
	end generate;
	
	genMDIOC0 : if (PHY_MANAGEMENT_INTERFACE = NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO) generate
		-- Management Data Input/Output Controller
		MDIOC : entity PoC.mdio_Controller
			generic map (
				DEBUG											=> DEBUG,
				CLOCK_FREQ								=> CLOCK_FREQ
			)
			port map (
				Clock											=> Clock,
				Reset											=> Reset,
				
				-- MDIO interface
				Command										=> PHYC_MDIO_Command,
				Status										=> MDIO_Status,
				Error											=> MDIO_Error,
				
				DeviceAddress							=> PHYC_MDIO_Physical_Address(4 downto 0),
				RegisterAddress						=> PHYC_MDIO_Register_Address,
				DataIn										=> PHYC_MDIO_Register_DataOut,
				DataOut										=> MDIOC_Register_DataIn,
				
				-- tristate interface
				MD_Clock_i								=> PHY_MDIO.Clock_ts.I,		-- IEEE 802.3: MDC		-> Managament Clock I
				MD_Clock_o								=> PHY_MDIO.Clock_ts.O,		-- IEEE 802.3: MDC		-> Managament Clock O
				MD_Clock_t								=> PHY_MDIO.Clock_ts.T,		-- IEEE 802.3: MDC		-> Managament Clock tri-state
				MD_Data_i									=> PHY_MDIO.Data_ts.I,		-- IEEE 802.3: MDIO		-> Managament Data I
				MD_Data_o									=> PHY_MDIO.Data_ts.O,		-- IEEE 802.3: MDIO		-> Managament Data O
				MD_Data_t									=> PHY_MDIO.Data_ts.T			-- IEEE 802.3: MDIO		-> Managament Data tri-state
			);
	end generate;
	
	genMDIOC1 : if (PHY_MANAGEMENT_INTERFACE = NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO_OVER_IIC) generate
		signal Adapter_IICC_Request			: std_logic;
		signal Adapter_IICC_Command			: T_IO_IIC_COMMAND;
		signal Adapter_IICC_Address			: T_SLV_8;
		signal Adapter_IICC_WP_Valid		: std_logic;
		signal Adapter_IICC_WP_Data			: T_SLV_8;
		signal Adapter_IICC_WP_Last			: std_logic;
		signal Adapter_IICC_RP_Ack			: std_logic;
		
		signal IICC_Grant								: std_logic;
		signal IICC_Status							: T_IO_IIC_STATUS;
		signal IICC_Error								: T_IO_IIC_ERROR;
		signal IICC_WP_Ack							: std_logic;
		signal IICC_RP_Valid						: std_logic;
		signal IICC_RP_Data							: T_SLV_8;
		signal IICC_RP_Last							: std_logic;
		
	begin
		Adapter : entity PoC.mdio_IIC_Adapter
			generic map (
				DEBUG											=> DEBUG
			)
			port map (
				Clock											=> Clock,
				Reset											=> Reset,
				
				-- MDIO interface
				Command										=> PHYC_MDIO_Command,
				Status										=> MDIO_Status,
				Error											=> MDIO_Error,
				
				DeviceAddress							=> PHYC_MDIO_Physical_Address,
				RegisterAddress						=> PHYC_MDIO_Register_Address,
				DataIn										=> PHYC_MDIO_Register_DataOut,
				DataOut										=> MDIOC_Register_DataIn,
				
				-- IICController interface
				IICC_Request							=> Adapter_IICC_Request,
				IICC_Grant								=> IICC_Grant,
				
				IICC_Command							=> Adapter_IICC_Command,
				IICC_Status								=> IICC_Status,
				IICC_Error								=> IICC_Error,
				
				IICC_Address							=> Adapter_IICC_Address,
				IICC_WP_Valid							=> Adapter_IICC_WP_Valid,
				IICC_WP_Data							=> Adapter_IICC_WP_Data,
				IICC_WP_Last							=> Adapter_IICC_WP_Last,
				IICC_WP_Ack								=> IICC_WP_Ack,
				IICC_RP_Valid							=> IICC_RP_Valid,
				IICC_RP_Data							=> IICC_RP_Data,
				IICC_RP_Last							=> IICC_RP_Last,
				IICC_RP_Ack								=> Adapter_IICC_RP_Ack
			);
			
		IICC : entity PoC.iic_Controller
			generic map (
				DEBUG											=> DEBUG,
				ALLOW_MEALY_TRANSITION		=> FALSE,
				CLOCK_FREQ								=> CLOCK_FREQ,
				IIC_BUSMODE								=> IO_IIC_BUSMODE_STANDARDMODE,
				IIC_ADDRESS								=> x"01",
				ADDRESS_BITS							=> 7,
				DATA_BITS									=> 8
			)
			port map (
				Clock											=> Clock,
				Reset											=> Reset,
				
				-- IICController master interface
				Master_Request						=> Adapter_IICC_Request,
				Master_Grant							=> IICC_Grant,
				Master_Command						=> Adapter_IICC_Command,
				Master_Status							=> IICC_Status,
				Master_Error							=> IICC_Error,
				
				Master_Address						=> Adapter_IICC_Address,
				
				Master_WP_Valid						=> Adapter_IICC_WP_Valid,
				Master_WP_Data						=> Adapter_IICC_WP_Data,
				Master_WP_Last						=> Adapter_IICC_WP_Last,
				Master_WP_Ack							=> IICC_WP_Ack,
				Master_RP_Valid						=> IICC_RP_Valid,
				Master_RP_Data						=> IICC_RP_Data,
				Master_RP_Last						=> IICC_RP_Last,
				Master_RP_Ack							=> Adapter_IICC_RP_Ack,
				
				-- tristate interface
				SerialClock_i							=> PHY_MDIO.Clock_ts.I,
				SerialClock_o							=> PHY_MDIO.Clock_ts.O,
				SerialClock_t							=> PHY_MDIO.Clock_ts.T,
				SerialData_i							=> PHY_MDIO.Data_ts.I,
				SerialData_o							=> PHY_MDIO.Data_ts.O,
				SerialData_t							=> PHY_MDIO.Data_ts.T
			);
	end generate;
--	end block;
end;
