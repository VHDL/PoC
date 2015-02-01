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
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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
USE			PoC.net.ALL;
USE			PoC.net_comp.ALL;

LIBRARY work;

-- configuration possibilities
-- +----------------+-----------+---------------+---------------+---------------------------------------+
-- | DEVICE		(grp)	|	IP-Style	|	RS-Interface	|	PHY-Interface	|	status / comment											|
-- +----------------+-----------+---------------+---------------+---------------------------------------+
-- | Virtex 5				|	HardIP		|			GMII			|			GMII			|	OK	tested; working as expected				|
-- |					(LXT)	|		"				|			GMII			|			SGMII			|			under development									|
-- |					(LXT)	|		"				|			TRANS			|			SGMII			|			not implemented, yet							|
-- |								+-----------+---------------+---------------+---------------------------------------+
-- |								|	SoftIP		|			GMII			|			GMII			|	OK	tested; working as expected				|
-- |					(LXT)	|		"				|			GMII			|			SGMII			|			not implemented, yet							|
-- +----------------+-----------+---------------+---------------+---------------------------------------+
-- | Virtex 6				|	HardIP		|			GMII			|			GMII			|			under development									|
-- |					(LXT)	|		"				|			GMII			|			SGMII			|			not implemented, yet							|
-- |					(LXT)	|		"				|			TRANS			|			SGMII			|			not implemented, yet							|
-- |								+-----------+---------------+---------------+---------------------------------------+
-- |								|	SoftIP		|			GMII			|			GMII			|			under development									|
-- |					(LXT)	|		"				|			GMII			|			SGMII			|			not implemented, yet							|
-- +----------------+-----------+---------------+---------------+---------------------------------------+
-- | Virtex 7	(XT)	|	SoftIP		|			GMII			|			SGMII			|			not implemented, yet							|
-- +----------------+-----------+---------------+---------------+---------------------------------------+
-- | Stratix 2 GX		|	SoftIP		|								|								|			not supported, yet								|
-- +----------------+-----------+---------------+---------------+---------------------------------------+

ENTITY Eth_Wrapper IS
	GENERIC (
		DEBUG											: BOOLEAN															:= FALSE;
		CLOCKIN_FREQ							: FREQ																:= 125.0 MHz;																-- 125 MHz
		ETHERNET_IPSTYLE					: T_IPSTYLE														:= IPSTYLE_SOFT;														-- 
		RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE					:= NET_ETH_RS_DATA_INTERFACE_GMII;					-- 
		PHY_DEVICE								: T_NET_ETH_PHY_DEVICE								:= NET_ETH_PHY_DEVICE_MARVEL_88E1111;				-- 
		PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS				:= x"00";																		-- 
		PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE				:= NET_ETH_PHY_DATA_INTERFACE_GMII;					-- 
		PHY_MANAGEMENT_INTERFACE	: T_NET_ETH_PHY_MANAGEMENT_INTERFACE	:= NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO		-- 
	);
	PORT (
		Ethernet_Reset						: IN	STD_LOGIC;				-- TODO: replace this signal by 6 aligned reset for each clock-domain
		
		RS_TX_Clock								: IN	STD_LOGIC;
		RS_RX_Clock								: IN	STD_LOGIC;
		Eth_TX_Clock							: IN	STD_LOGIC;
		Eth_RX_Clock							: IN	STD_LOGIC;
		TX_Clock									: IN	STD_LOGIC;
		RX_Clock									: IN	STD_LOGIC;
		
		Command										: IN	T_NET_ETH_COMMAND;
		Status										: OUT	T_NET_ETH_STATUS;
		Error											: OUT	T_NET_ETH_ERROR;
		
		-- LocalLink interface
		TX_Valid									: IN	STD_LOGIC;
		TX_Data										: IN	T_SLV_8;
		TX_SOF										: IN	STD_LOGIC;
		TX_EOF										: IN	STD_LOGIC;
		TX_Ack										: OUT	STD_LOGIC;
	
		RX_Valid									: OUT	STD_LOGIC;
		RX_Data										: OUT	T_SLV_8;
		RX_SOF										: OUT	STD_LOGIC;
		RX_EOF										: OUT	STD_LOGIC;
		RX_Ack										: IN	STD_LOGIC;
		
		-- GMII PHY interface
-- TODO:		GMII_Reset								: OUT	STD_LOGIC;				-- 						 RST		-> PHY Reset
-- TODO:		GMII_Interrupt						: IN	STD_LOGIC;				--						 INT		-> Interrupt

		PHY_Interface							:	INOUT	T_NET_ETH_PHY_INTERFACES
	);
END;


ARCHITECTURE rtl OF Eth_Wrapper IS

	-- Bus interface
	SIGNAL Strobe											: STD_LOGIC;
	SIGNAL PHY_Address								: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL Register_we								: STD_LOGIC;
	SIGNAL Register_Address						: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL Register_DataIn						: T_SLV_16;
	SIGNAL Register_DataOut						: T_SLV_16;
	SIGNAL Register_Valid							: STD_LOGIC;
			
	SIGNAL ManagementData_Clock				: STD_LOGIC;
	SIGNAL ManagementData_Data_i			: STD_LOGIC;
	SIGNAL ManagementData_Data_o			: STD_LOGIC;
	SIGNAL ManagementData_Data_t			: STD_LOGIC;
	
BEGIN

	genVirtex5 : IF (DEVICE = DEVICE_VIRTEX5) GENERATE
	
	BEGIN
		Eth : Eth_Wrapper_Virtex5
			GENERIC MAP (
				DEBUG											=> DEBUG,
				CLOCKIN_FREQ							=> CLOCKIN_FREQ,
				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
				RS_DATA_INTERFACE					=> RS_DATA_INTERFACE,
				PHY_DATA_INTERFACE				=> PHY_DATA_INTERFACE
			)
			PORT MAP (
				-- clock interface
				RS_TX_Clock								=> RS_TX_Clock,
				RS_RX_Clock								=> RS_RX_Clock,
				Eth_TX_Clock							=> Eth_TX_Clock,
				Eth_RX_Clock							=> Eth_RX_Clock,
				TX_Clock									=> TX_Clock,
				RX_Clock									=> RX_Clock,

				-- reset interface
				Reset											=> Ethernet_Reset,
				-- Command-Status-Error interface
				
				-- MAC LocalLink interface
				TX_Valid									=> TX_Valid,
				TX_Data										=> TX_Data,
				TX_SOF										=> TX_SOF,
				TX_EOF										=> TX_EOF,
				TX_Ack										=> TX_Ack,

				RX_Valid									=> RX_Valid,
				RX_Data										=> RX_Data,
				RX_SOF										=> RX_SOF,
				RX_EOF										=> RX_EOF,
				RX_Ack										=> RX_Ack,
				
				PHY_Interface							=> PHY_Interface
			);
	
	END GENERATE;
	genVirtex6 : IF (DEVICE = DEVICE_VIRTEX6) GENERATE
	
	BEGIN
		Eth : Eth_Wrapper_Virtex6
			GENERIC MAP (
				DEBUG											=> DEBUG,
				CLOCKIN_FREQ							=> CLOCKIN_FREQ,
				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
				RS_DATA_INTERFACE					=> RS_DATA_INTERFACE,
				PHY_DATA_INTERFACE				=> PHY_DATA_INTERFACE
			)
			PORT MAP (
				-- clock interface
				RS_TX_Clock								=> RS_TX_Clock,
				RS_RX_Clock								=> RS_RX_Clock,
				Eth_TX_Clock							=> Eth_TX_Clock,
				Eth_RX_Clock							=> Eth_RX_Clock,
				TX_Clock									=> TX_Clock,
				RX_Clock									=> RX_Clock,
				
				-- reset interface
				Reset											=> Ethernet_Reset,
				
				-- Command-Status-Error interface
				
				-- MAC LocalLink interface
				TX_Valid									=> TX_Valid,
				TX_Data										=> TX_Data,
				TX_SOF										=> TX_SOF,
				TX_EOF										=> TX_EOF,
				TX_Ack										=> TX_Ack,

				RX_Valid									=> RX_Valid,
				RX_Data										=> RX_Data,
				RX_SOF										=> RX_SOF,
				RX_EOF										=> RX_EOF,
				RX_Ack										=> RX_Ack,
				
				PHY_Interface							=> PHY_Interface
			);
	
	END GENERATE;
	genSeries7 : IF (DEVICE = DEVICE_VIRTEX7) GENERATE
	
	BEGIN
		Eth : Eth_Wrapper_Series7
			GENERIC MAP (
				DEBUG											=> DEBUG,
				CLOCKIN_FREQ							=> CLOCKIN_FREQ,
				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
				RS_DATA_INTERFACE					=> RS_DATA_INTERFACE,
				PHY_DATA_INTERFACE				=> PHY_DATA_INTERFACE
			)
			PORT MAP (
				-- clock interface
				RS_TX_Clock								=> RS_TX_Clock,
				RS_RX_Clock								=> RS_RX_Clock,
				Eth_TX_Clock							=> Eth_TX_Clock,
				Eth_RX_Clock							=> Eth_RX_Clock,
				TX_Clock									=> TX_Clock,
				RX_Clock									=> RX_Clock,
				
				-- reset interface
				Reset											=> Ethernet_Reset,
				
				-- Command-Status-Error interface
				
				-- MAC LocalLink interface
				TX_Valid									=> TX_Valid,
				TX_Data										=> TX_Data,
				TX_SOF										=> TX_SOF,
				TX_EOF										=> TX_EOF,
				TX_Ack										=> TX_Ack,

				RX_Valid									=> RX_Valid,
				RX_Data										=> RX_Data,
				RX_SOF										=> RX_SOF,
				RX_EOF										=> RX_EOF,
				RX_Ack										=> RX_Ack,
				
				PHY_Interface							=> PHY_Interface
			);
	
	END GENERATE;
	
	blkPHYC : BLOCK
		SIGNAL PHYC_Command			: T_NET_ETH_PHYCONTROLLER_COMMAND;
		SIGNAL PHYC_Status			: T_NET_ETH_PHYCONTROLLER_STATUS;
		SIGNAL PHYC_Error				: T_NET_ETH_PHYCONTROLLER_ERROR;
		
	BEGIN
		PROCESS(Command)
		BEGIN
			CASE Command IS
				WHEN NET_ETH_CMD_NONE =>					PHYC_Command		<= NET_ETH_PHYC_CMD_NONE;
				WHEN NET_ETH_CMD_HARD_RESET =>		PHYC_Command		<= NET_ETH_PHYC_CMD_HARD_RESET;
				WHEN NET_ETH_CMD_SOFT_RESET =>		PHYC_Command		<= NET_ETH_PHYC_CMD_SOFT_RESET;
				WHEN OTHERS =>										PHYC_Command		<= NET_ETH_PHYC_CMD_NONE;
			END CASE;
		END PROCESS;

		PROCESS(PHYC_Status, PHYC_Error)
		BEGIN
			CASE PHYC_Status IS
				WHEN NET_ETH_PHYC_STATUS_POWER_DOWN =>			Status	<= NET_ETH_STATUS_POWER_DOWN;
				WHEN NET_ETH_PHYC_STATUS_RESETING =>				Status	<= NET_ETH_STATUS_RESETING;
				WHEN NET_ETH_PHYC_STATUS_CONNECTING =>			Status	<= NET_ETH_STATUS_CONNECTING;
				WHEN NET_ETH_PHYC_STATUS_CONNECTED =>				Status	<= NET_ETH_STATUS_CONNECTED;
				WHEN NET_ETH_PHYC_STATUS_DISCONNECTING =>		Status	<= NET_ETH_STATUS_DISCONNECTING;
				WHEN NET_ETH_PHYC_STATUS_DISCONNECTED =>		Status	<= NET_ETH_STATUS_DISCONNECTED;
				WHEN NET_ETH_PHYC_STATUS_ERROR =>						Status	<= NET_ETH_STATUS_ERROR;
		
			END CASE;
			
			CASE PHYC_Error IS
				WHEN NET_ETH_PHYC_ERROR_NONE =>							Error		<= NET_ETH_ERROR_NONE;
				WHEN OTHERS =>															Error		<= NET_ETH_ERROR_NONE;
			END CASE;
			
	--		MAC_ERROR_MAC_ERROR,
	--		MAC_ERROR_PHY_ERROR,
	--		MAC_ERROR_PCS_ERROR,
	--		MAC_ERROR_NO_CABLE
		END PROCESS;
		
		PHYC : ENTITY PoC.Eth_PHYController
			GENERIC MAP (
				DEBUG														=> DEBUG,
				CLOCK_FREQ											=> CLOCKIN_FREQ,
				PHY_DEVICE											=> PHY_DEVICE,
				PHY_DEVICE_ADDRESS							=> PHY_DEVICE_ADDRESS,
				PHY_MANAGEMENT_INTERFACE				=> PHY_MANAGEMENT_INTERFACE,																--			MDIO = 1 MBaud	IIC = 100 kBaud
				BAUDRATE												=> ite((PHY_MANAGEMENT_INTERFACE = NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO), 1.0 MBd, 100.0 kBd)
			)
			PORT MAP (
				Clock														=> TX_Clock,
				Reset														=> Ethernet_Reset,
							
				-- PHYController interface			
				Command													=> PHYC_Command,
				Status													=> PHYC_Status,
				Error														=> PHYC_Error,
				
				PHY_Reset												=> PHY_Interface.Common.Reset,				-- 
				PHY_Interrupt										=> PHY_Interface.Common.Interrupt,		-- 
				PHY_MDIO												=> PHY_Interface.MDIO									-- Management Data Input/Output
			);
	END BLOCK;
END ARCHITECTURE;
