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
use			PoC.net.all;
use			PoC.net_comp.all;

library work;

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

entity Eth_Wrapper is
	generic (
		DEBUG											: boolean															:= FALSE;
		CLOCKIN_FREQ							: FREQ																:= 125 MHz;																	-- 125 MHz
		ETHERNET_IPSTYLE					: T_IPSTYLE														:= IPSTYLE_SOFT;														--
		RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE					:= NET_ETH_RS_DATA_INTERFACE_GMII;					--
		PHY_DEVICE								: T_NET_ETH_PHY_DEVICE								:= NET_ETH_PHY_DEVICE_MARVEL_88E1111;				--
		PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS				:= x"00";																		--
		PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE				:= NET_ETH_PHY_DATA_INTERFACE_GMII;					--
		PHY_MANAGEMENT_INTERFACE	: T_NET_ETH_PHY_MANAGEMENT_INTERFACE	:= NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO;
		IS_SIM										: boolean 														:= false
	);
	port (
		Ethernet_Reset						: in	std_logic;				-- TODO: replace this signal by 6 aligned reset for each clock-domain
		
		RS_TX_Clock								: in	std_logic;
		RS_RX_Clock								: in	std_logic;
		Eth_TX_Clock							: in	std_logic;
		Eth_RX_Clock							: in	std_logic;
		TX_Clock									: in	std_logic;
		RX_Clock									: in	std_logic;
		
		Command										: in	T_NET_ETH_COMMAND;
		Status										: out	T_NET_ETH_STATUS;
		Error											: out	T_NET_ETH_ERROR;
		Core_Status								: out std_logic_vector(15 downto 0);
		
		-- LocalLink interface
		TX_Valid									: in	std_logic;
		TX_Data										: in	T_SLV_8;
		TX_SOF										: in	std_logic;
		TX_EOF										: in	std_logic;
		TX_Ack										: out	std_logic;
		
		RX_Valid									: out	std_logic;
		RX_Data										: out	T_SLV_8;
		RX_SOF										: out	std_logic;
		RX_EOF										: out	std_logic;
		RX_Ack										: in	std_logic;
		
		MDIO_Read_Register				: in std_logic_vector(4 downto 0);
		MDIO_Register_Data				: out	T_SLV_16;
		
		-- GMII PHY interface
-- TODO:		GMII_Reset								: out	STD_LOGIC;				-- 						 RST		-> PHY Reset
-- TODO:		GMII_Interrupt						: in	STD_LOGIC;				--						 INT		-> Interrupt

		PHY_Interface							:	inout	T_NET_ETH_PHY_INTERFACES := C_NET_ETH_PHY_INTERFACES_INIT
	);
end entity;


architecture rtl of Eth_Wrapper is

	-- Bus interface
	signal Strobe											: std_logic;
	signal PHY_Address								: std_logic_vector(4 downto 0);
	signal Register_we								: std_logic;
	signal Register_Address						: std_logic_vector(4 downto 0);
	signal Register_DataIn						: T_SLV_16;
	signal Register_DataOut						: T_SLV_16;
	signal Register_Valid							: std_logic;
	
	signal ManagementData_Clock				: std_logic;
	signal ManagementData_Data_i			: std_logic;
	signal ManagementData_Data_o			: std_logic;
	signal ManagementData_Data_t			: std_logic;
	
	signal eth_wrapper_rx_valid				: std_logic;
	signal eth_wrapper_rx_SoF					: std_logic;
	signal eth_wrapper_rx_EoF					: std_logic;
	signal eth_wrapper_rx_ACK					: std_logic;
	signal eth_wrapper_rx_Data				: T_SLV_8;
	
begin

--	genVirtex5 : if (DEVICE = DEVICE_VIRTEX5) generate

--	begin
--		assert DEBUG report "DEVICE = DEVICE_VIRTEX5" severity note;
--		Eth : eth_Wrapper_Virtex5
--			generic map (
--				DEBUG											=> DEBUG,
--				CLOCKIN_FREQ							=> CLOCKIN_FREQ,
--				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
--				RS_DATA_INTERFACE					=> RS_DATA_INTERFACE,
--				PHY_DATA_INTERFACE				=> PHY_DATA_INTERFACE
--			)
--			port map (
--				-- clock interface
--				RS_TX_Clock								=> RS_TX_Clock,
--				RS_RX_Clock								=> RS_RX_Clock,
--				Eth_TX_Clock							=> Eth_TX_Clock,
--				Eth_RX_Clock							=> Eth_RX_Clock,
--				TX_Clock									=> TX_Clock,
--				RX_Clock									=> RX_Clock,
				
--				-- reset interface
--				Reset											=> Ethernet_Reset,
--				-- Command-Status-Error interface
				
--				-- MAC LocalLink interface
--				TX_Valid									=> TX_Valid,
--				TX_Data										=> TX_Data,
--				TX_SOF										=> TX_SOF,
--				TX_EOF										=> TX_EOF,
--				TX_Ack										=> TX_Ack,
				
--				RX_Valid									=> RX_Valid,
--				RX_Data										=> RX_Data,
--				RX_SOF										=> RX_SOF,
--				RX_EOF										=> RX_EOF,
--				RX_Ack										=> RX_Ack,
				
--				PHY_Interface							=> PHY_Interface
--			);
			
--	end generate;
--	genVirtex6 : if (DEVICE = DEVICE_VIRTEX6) generate

--	begin
--		assert DEBUG report "DEVICE = DEVICE_VIRTEX6" severity note;
--		Eth : eth_Wrapper_Virtex6
--			generic map (
--				DEBUG											=> DEBUG,
--				CLOCKIN_FREQ							=> CLOCKIN_FREQ,
--				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
--				RS_DATA_INTERFACE					=> RS_DATA_INTERFACE,
--				PHY_DATA_INTERFACE				=> PHY_DATA_INTERFACE
--			)
--			port map (
--				-- clock interface
--				RS_TX_Clock								=> RS_TX_Clock,
--				RS_RX_Clock								=> RS_RX_Clock,
--				Eth_TX_Clock							=> Eth_TX_Clock,
--				Eth_RX_Clock							=> Eth_RX_Clock,
--				TX_Clock									=> TX_Clock,
--				RX_Clock									=> RX_Clock,
				
--				-- reset interface
--				Reset											=> Ethernet_Reset,
				
--				-- Command-Status-Error interface
				
--				-- MAC LocalLink interface
--				TX_Valid									=> TX_Valid,
--				TX_Data										=> TX_Data,
--				TX_SOF										=> TX_SOF,
--				TX_EOF										=> TX_EOF,
--				TX_Ack										=> TX_Ack,
				
--				RX_Valid									=> RX_Valid,
--				RX_Data										=> RX_Data,
--				RX_SOF										=> RX_SOF,
--				RX_EOF										=> RX_EOF,
--				RX_Ack										=> RX_Ack,
				
--				PHY_Interface							=> PHY_Interface
--			);
			
--	end generate;
	
	
	genSeries7 : if (DEVICE = DEVICE_VIRTEX7 or DEVICE = DEVICE_KINTEX7) generate
	begin
	
		assert not DEBUG report "DEVICE = DEVICE_Series7" severity note;
		
		Eth : eth_Wrapper_Series7
			generic map (
				DEBUG											=> DEBUG,
				CLOCKIN_FREQ							=> CLOCKIN_FREQ,
				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
				RS_DATA_INTERFACE					=> RS_DATA_INTERFACE,
				PHY_DATA_INTERFACE				=> PHY_DATA_INTERFACE,
				IS_SIM										=> IS_SIM
			)
			port map (
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
				Core_Status								=> Core_Status,
				
				-- MAC LocalLink interface
				TX_Valid									=> TX_Valid,
				TX_Data										=> TX_Data,
				TX_SOF										=> TX_SOF,
				TX_EOF										=> TX_EOF,
				TX_Ack										=> TX_Ack,
				
				RX_Valid									=> eth_wrapper_rx_valid,--RX_Valid,
				RX_Data										=> eth_wrapper_rx_data,--RX_Data,
				RX_SOF										=> eth_wrapper_rx_SoF,--RX_SOF,
				RX_EOF										=> eth_wrapper_rx_EoF,--RX_EOF,
				RX_Ack										=> eth_wrapper_rx_ack,--RX_Ack,
				
				PHY_Interface							=> PHY_Interface
			);
			
			RX_Valid <= eth_wrapper_rx_valid;
			RX_Data <= eth_wrapper_rx_data;
			RX_SOF <= eth_wrapper_rx_SoF;
			RX_EOF <= eth_wrapper_rx_EoF;
			eth_wrapper_rx_ack <= RX_Ack;  
			
	end generate;
	
	blkPHYC : block
		signal PHYC_Command			: T_NET_ETH_PHYCONTROLLER_COMMAND;
		signal PHYC_Status			: T_NET_ETH_PHYCONTROLLER_STATUS;
		signal PHYC_Error				: T_NET_ETH_PHYCONTROLLER_ERROR;
		
		
	begin
		process(Command)
		begin
			case Command is
				when NET_ETH_CMD_NONE =>					PHYC_Command		<= NET_ETH_PHYC_CMD_NONE;
				when NET_ETH_CMD_READ =>					PHYC_Command		<= NET_ETH_PHYC_CMD_READ;
				when NET_ETH_CMD_HARD_RESET =>		PHYC_Command		<= NET_ETH_PHYC_CMD_HARD_RESET;
				when NET_ETH_CMD_SOFT_RESET =>		PHYC_Command		<= NET_ETH_PHYC_CMD_SOFT_RESET;
				when others =>										PHYC_Command		<= NET_ETH_PHYC_CMD_NONE;
			end case;
		end process;
		
		process(PHYC_Status, PHYC_Error, Tx_Valid, eth_wrapper_rx_valid)
		begin
			case PHYC_Status is
				when NET_ETH_PHYC_STATUS_POWER_DOWN 			=>	Status	<= NET_ETH_STATUS_POWER_DOWN;
				when NET_ETH_PHYC_STATUS_RESETING 				=>	Status	<= NET_ETH_STATUS_RESETING;
				when NET_ETH_PHYC_STATUS_CONNECTING 			=>	Status	<= NET_ETH_STATUS_CONNECTING;
				when NET_ETH_PHYC_STATUS_CONNECTED 				=>	Status	<= NET_ETH_STATUS_CONNECTED;
				when NET_ETH_PHYC_STATUS_READING 					=>	Status	<= NET_ETH_STATUS_READING;
					if Tx_Valid = '1' then
						Status	<= NET_ETH_STATUS_CONNECTED;
					else
						Status	<= NET_ETH_STATUS_Error;
					end if;
				when NET_ETH_PHYC_STATUS_DISCONNECTING 		=>	Status	<= NET_ETH_STATUS_DISCONNECTING;
				when NET_ETH_PHYC_STATUS_DISCONNECTED 		=>	Status	<= NET_ETH_STATUS_DISCONNECTED;
				when NET_ETH_PHYC_STATUS_ERROR 						=>	Status	<= NET_ETH_STATUS_ERROR;
				when others 														 	=>	Status	<= NET_ETH_STATUS_POWER_DOWN;
				
			end case;
			
			case PHYC_Error is
				when NET_ETH_PHYC_ERROR_NONE =>							Error		<= NET_ETH_ERROR_NONE;
				when others =>															Error		<= NET_ETH_ERROR_NONE;
			end case;
			
	--		MAC_ERROR_MAC_ERROR,
	--		MAC_ERROR_PHY_ERROR,
	--		MAC_ERROR_PCS_ERROR,
	--		MAC_ERROR_NO_CABLE
		end process;
		
		PHYC : entity PoC.Eth_PHYController
			generic map (
				DEBUG														=> DEBUG,
				CLOCK_FREQ											=> CLOCKIN_FREQ,
				PHY_DEVICE											=> PHY_DEVICE,
				PHY_DEVICE_ADDRESS							=> PHY_DEVICE_ADDRESS,
				PHY_MANAGEMENT_INTERFACE				=> PHY_MANAGEMENT_INTERFACE,
				BAUDRATE												=> ite((PHY_MANAGEMENT_INTERFACE = NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO), 1 MBd, 100 kBd),
				IS_SIM													=> IS_SIM
			)
			port map (
				Clock														=> TX_Clock,
				Reset														=> Ethernet_Reset,
				
				-- PHYController interface
				Command													=> PHYC_Command,
				Status													=> PHYC_Status,
				Error														=> PHYC_Error,
				
				MDIO_Read_Register				=> MDIO_Read_Register,
				MDIO_Register_Data				=> MDIO_Register_Data,
				
				PHY_Reset												=> PHY_Interface.Common.Reset,				--
				PHY_Interrupt										=> PHY_Interface.Common.Interrupt,		--
				PHY_MDIO												=> PHY_Interface.MDIO									-- Management Data Input/Output
			);
	end block;
end architecture;
