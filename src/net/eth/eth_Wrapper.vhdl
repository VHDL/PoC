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
		DEBUG											: BOOLEAN															:= FALSE;
		CLOCKIN_FREQ							: FREQ																:= 125 MHz;																	-- 125 MHz
		ETHERNET_IPSTYLE					: T_IPSTYLE														:= IPSTYLE_SOFT;														--
		RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE					:= NET_ETH_RS_DATA_INTERFACE_GMII;					--
		PHY_DEVICE								: T_NET_ETH_PHY_DEVICE								:= NET_ETH_PHY_DEVICE_MARVEL_88E1111;				--
		PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS				:= x"00";																		--
		PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE				:= NET_ETH_PHY_DATA_INTERFACE_GMII;					--
		PHY_MANAGEMENT_INTERFACE	: T_NET_ETH_PHY_MANAGEMENT_INTERFACE	:= NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO		--
	);
	port (
		Ethernet_Reset						: in	STD_LOGIC;				-- TODO: replace this signal by 6 aligned reset for each clock-domain

		RS_TX_Clock								: in	STD_LOGIC;
		RS_RX_Clock								: in	STD_LOGIC;
		Eth_TX_Clock							: in	STD_LOGIC;
		Eth_RX_Clock							: in	STD_LOGIC;
		TX_Clock									: in	STD_LOGIC;
		RX_Clock									: in	STD_LOGIC;

		Command										: in	T_NET_ETH_COMMAND;
		Status										: out	T_NET_ETH_STATUS;
		Error											: out	T_NET_ETH_ERROR;

		-- LocalLink interface
		TX_Valid									: in	STD_LOGIC;
		TX_Data										: in	T_SLV_8;
		TX_SOF										: in	STD_LOGIC;
		TX_EOF										: in	STD_LOGIC;
		TX_Ack										: out	STD_LOGIC;

		RX_Valid									: out	STD_LOGIC;
		RX_Data										: out	T_SLV_8;
		RX_SOF										: out	STD_LOGIC;
		RX_EOF										: out	STD_LOGIC;
		RX_Ack										: in	STD_LOGIC;

		-- GMII PHY interface
-- TODO:		GMII_Reset								: out	STD_LOGIC;				-- 						 RST		-> PHY Reset
-- TODO:		GMII_Interrupt						: in	STD_LOGIC;				--						 INT		-> Interrupt

		PHY_Interface							:	INOUT	T_NET_ETH_PHY_INTERFACES
	);
end entity;


architecture rtl of Eth_Wrapper is

	-- Bus interface
	signal Strobe											: STD_LOGIC;
	signal PHY_Address								: STD_LOGIC_VECTOR(4 downto 0);
	signal Register_we								: STD_LOGIC;
	signal Register_Address						: STD_LOGIC_VECTOR(4 downto 0);
	signal Register_DataIn						: T_SLV_16;
	signal Register_DataOut						: T_SLV_16;
	signal Register_Valid							: STD_LOGIC;

	signal ManagementData_Clock				: STD_LOGIC;
	signal ManagementData_Data_i			: STD_LOGIC;
	signal ManagementData_Data_o			: STD_LOGIC;
	signal ManagementData_Data_t			: STD_LOGIC;

begin

	genVirtex5 : if (DEVICE = DEVICE_VIRTEX5) generate

	begin
		Eth : eth_Wrapper_Virtex5
			generic map (
				DEBUG											=> DEBUG,
				CLOCKIN_FREQ							=> CLOCKIN_FREQ,
				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
				RS_DATA_INTERFACE					=> RS_DATA_INTERFACE,
				PHY_DATA_INTERFACE				=> PHY_DATA_INTERFACE
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

	end generate;
	genVirtex6 : if (DEVICE = DEVICE_VIRTEX6) generate

	begin
		Eth : eth_Wrapper_Virtex6
			generic map (
				DEBUG											=> DEBUG,
				CLOCKIN_FREQ							=> CLOCKIN_FREQ,
				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
				RS_DATA_INTERFACE					=> RS_DATA_INTERFACE,
				PHY_DATA_INTERFACE				=> PHY_DATA_INTERFACE
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

	end generate;
	genSeries7 : if (DEVICE = DEVICE_VIRTEX7) generate

	begin
		Eth : eth_Wrapper_Series7
			generic map (
				DEBUG											=> DEBUG,
				CLOCKIN_FREQ							=> CLOCKIN_FREQ,
				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
				RS_DATA_INTERFACE					=> RS_DATA_INTERFACE,
				PHY_DATA_INTERFACE				=> PHY_DATA_INTERFACE
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
				when NET_ETH_CMD_HARD_RESET =>		PHYC_Command		<= NET_ETH_PHYC_CMD_HARD_RESET;
				when NET_ETH_CMD_SOFT_RESET =>		PHYC_Command		<= NET_ETH_PHYC_CMD_SOFT_RESET;
				when others =>										PHYC_Command		<= NET_ETH_PHYC_CMD_NONE;
			end case;
		end process;

		process(PHYC_Status, PHYC_Error)
		begin
			case PHYC_Status is
				when NET_ETH_PHYC_STATUS_POWER_DOWN =>			Status	<= NET_ETH_STATUS_POWER_DOWN;
				when NET_ETH_PHYC_STATUS_RESETING =>				Status	<= NET_ETH_STATUS_RESETING;
				when NET_ETH_PHYC_STATUS_CONNECTING =>			Status	<= NET_ETH_STATUS_CONNECTING;
				when NET_ETH_PHYC_STATUS_CONNECTED =>				Status	<= NET_ETH_STATUS_CONNECTED;
				when NET_ETH_PHYC_STATUS_DISCONNECTING =>		Status	<= NET_ETH_STATUS_DISCONNECTING;
				when NET_ETH_PHYC_STATUS_DISCONNECTED =>		Status	<= NET_ETH_STATUS_DISCONNECTED;
				when NET_ETH_PHYC_STATUS_ERROR =>						Status	<= NET_ETH_STATUS_ERROR;

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
				PHY_MANAGEMENT_INTERFACE				=> PHY_MANAGEMENT_INTERFACE,																--			MDIO = 1 MBaud	IIC = 100 kBaud
				BAUDRATE												=> ite((PHY_MANAGEMENT_INTERFACE = NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO), 1 MBd, 100 kBd)
			)
			port map (
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
	end block;
end architecture;
