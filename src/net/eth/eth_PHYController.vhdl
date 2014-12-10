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
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.physical.ALL;
USE			PoC.io.ALL;
USE			PoC.net.ALL;


ENTITY Eth_PHYController IS
	GENERIC (
		DEBUG						: BOOLEAN																	:= FALSE;																			-- 
		CLOCK_FREQ						: FREQ																		:= 125.0 Mhz;																			-- 125 MHz
		PCSCORE										: T_NET_ETH_PCSCORE												:= NET_ETH_PCSCORE_GENERIC_GMII;							-- 
		PHY_DEVICE								: T_NET_ETH_PHY_DEVICE										:= NET_ETH_PHY_DEVICE_MARVEL_88E1111;					-- 
		PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS						:= x"00";																			-- 
		PHY_MANAGEMENT_INTERFACE	: T_NET_ETH_PHY_MANAGEMENT_INTERFACE			:= NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO;			-- 
		BAUDRATE_BAUD							: REAL																		:= 1.0 * 1000.0 * 1000.0											-- 1.0 MBit/s
	);
	PORT (
		Clock											: IN		STD_LOGIC;
		Reset											: IN		STD_LOGIC;
		
		-- PHYController interface
		Command										: IN		T_NET_ETH_PHYCONTROLLER_COMMAND;
		Status										: OUT		T_NET_ETH_PHYCONTROLLER_STATUS;
		Error											: OUT		T_NET_ETH_PHYCONTROLLER_ERROR;

		PHY_Reset									: OUT		STD_LOGIC;															-- 
		PHY_Interrupt							: IN		STD_LOGIC;															-- 
		PHY_MDIO									: INOUT T_NET_ETH_PHY_INTERFACE_MDIO						-- Management Data Input/Output
	);
END;


ARCHITECTURE rtl OF Eth_PHYController IS
	ATTRIBUTE KEEP											: BOOLEAN;
	ATTRIBUTE FSM_ENCODING							: STRING;

	SIGNAL PHYC_MDIO_Command						: T_IO_MDIO_MDIOCONTROLLER_COMMAND;
	SIGNAL MDIO_Status									: T_IO_MDIO_MDIOCONTROLLER_STATUS;
	SIGNAL MDIO_Error										: T_IO_MDIO_MDIOCONTROLLER_ERROR;
	
--	SIGNAL Strobe												: STD_LOGIC;
	SIGNAL PHYC_MDIO_Physical_Address		: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL PHYC_MDIO_Register_Address		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL MDIOC_Register_DataIn				: T_SLV_16;
	SIGNAL PHYC_MDIO_Register_DataOut		: T_SLV_16;

	-- PCS_ADDRESS								: T_SLV_8																	:= x"00";
BEGIN

	ASSERT FALSE REPORT "BAUDRATE_BAUD =          " & REAL'image(BAUDRATE_BAUD)						& " Baud" SEVERITY NOTE;
--	ASSERT FALSE REPORT "MD_CLOCK_FREQUENCY_KHZ = " & REAL'image(MD_CLOCK_FREQUENCY_KHZ)	& " kHz" SEVERITY NOTE;

	genMarvel88E1111 : IF (PHY_DEVICE = NET_ETH_PHY_DEVICE_MARVEL_88E1111) GENERATE
	
	BEGIN
		PHYC : ENTITY PoC.Eth_PHYController_Marvell_88E1111
			GENERIC MAP (
				DEBUG										=> DEBUG,
				CLOCK_FREQ					=> CLOCK_FREQ,
				PHY_DEVICE_ADDRESS			=> PHY_DEVICE_ADDRESS
			)
			PORT MAP (
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
				MDIO_Register_DataOut		=> PHYC_MDIO_Register_DataOut
			);
	END GENERATE;
	
	genMDIOC0 : IF (PHY_MANAGEMENT_INTERFACE = NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO) GENERATE
		-- Management Data Input/Output Controller
		MDIOC : ENTITY PoC.Eth_MDIOController
			GENERIC MAP (
				DEBUG						=> DEBUG,
				CLOCK_FREQ						=> CLOCK_FREQ
			)
			PORT MAP (
				Clock											=> Clock,
				Reset											=> Reset,
				
				-- MDIO interface
				Command										=> PHYC_MDIO_Command,
				Status										=> MDIO_Status,
				Error											=> MDIO_Error,
				
				DeviceAddress							=> PHYC_MDIO_Physical_Address(4 DOWNTO 0),
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
	END GENERATE;

	genMDIOC1 : IF (PHY_MANAGEMENT_INTERFACE = NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO_OVER_IIC) GENERATE
		SIGNAL Adapter_IICC_Request			: STD_LOGIC;
		SIGNAL Adapter_IICC_Command			: T_IO_IIC_COMMAND;
		SIGNAL Adapter_IICC_Address			: STD_LOGIC_VECTOR(6 DOWNTO 0);
		SIGNAL Adapter_IICC_WP_Valid		: STD_LOGIC;
		SIGNAL Adapter_IICC_WP_Data			: T_SLV_8;
		SIGNAL Adapter_IICC_WP_Last			: STD_LOGIC;
		SIGNAL Adapter_IICC_RP_Ack			: STD_LOGIC;
		
		SIGNAL IICC_Grant								: STD_LOGIC;
		SIGNAL IICC_Status							: T_IO_IIC_STATUS;
		SIGNAL IICC_Error								: T_IO_IIC_ERROR;
		SIGNAL IICC_WP_Ack							: STD_LOGIC;
		SIGNAL IICC_RP_Valid						: STD_LOGIC;
		SIGNAL IICC_RP_Data							: T_SLV_8;
		SIGNAL IICC_RP_Last							: STD_LOGIC;
		
	BEGIN
		Adapter : ENTITY PoC.mdio_MDIO_IIC_Adapter
			GENERIC MAP (
				DEBUG						=> DEBUG
			)
			PORT MAP (
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
		
		IICC : ENTITY PoC.iic_IICController
			GENERIC MAP (
				DEBUG											=> DEBUG,
				ALLOW_MEALY_TRANSITION		=> FALSE,
				CLOCK_FREQ						=> CLOCK_FREQ,
				IIC_BUSMODE								=> IO_IIC_BUSMODE_STANDARDMODE,
				IIC_ADDRESS								=> x"01",
				ADDRESS_BITS							=> 7,
				DATA_BITS									=> 8
			)
			PORT MAP (
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
	END GENERATE;
--	END BLOCK;
END;
