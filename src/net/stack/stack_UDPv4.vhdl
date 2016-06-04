-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- ============================================================================
-- Entity:				 	TODO
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
USE			PoC.strings.ALL;
USE			PoC.physical.ALL;
USE			PoC.net.ALL;


ENTITY stack_UDPv4 IS
	GENERIC (
		DEBUG															: BOOLEAN															:= FALSE;																																									--
		CLOCK_FREQ												: FREQ																:= 125 MHz;																																								--
		ETHERNET_IPSTYLE									: T_IPSTYLE														:= to_IPStyle(												MY_BOARD_STRUCT.Ethernet.IPStyle);									--
		ETHERNET_RS_DATA_INTERFACE				: T_NET_ETH_RS_DATA_INTERFACE					:= to_net_eth_RSDataInterface(				MY_BOARD_STRUCT.Ethernet.RS_DataInterface);					--
		ETHERNET_PHY_DEVICE								: T_NET_ETH_PHY_DEVICE								:= to_net_eth_PHYDevice(							MY_BOARD_STRUCT.Ethernet.PHY_Device);								--
		ETHERNET_PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS				:= 																		MY_BOARD_STRUCT.Ethernet.PHY_DeviceAddress;					--
		ETHERNET_PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE				:= to_net_eth_PHYDataInterface(				MY_BOARD_STRUCT.Ethernet.PHY_DataInterface);				--
		ETHERNET_PHY_MANAGEMENT_INTERFACE	: T_NET_ETH_PHY_MANAGEMENT_INTERFACE	:= to_net_eth_PHYManagementInterface(	MY_BOARD_STRUCT.Ethernet.PHY_ManagementInterface);	--

		MAC_ADDRESS												: T_NET_MAC_ADDRESS;
		IP_ADDRESS												: T_NET_IPV4_ADDRESS;
		UDP_PORTS													: T_NET_UDP_PORTPAIR_VECTOR;

		MAC_ENABLE_LOOPBACK								: BOOLEAN															:= FALSE;
		IPV4_ENABLE_LOOPBACK							: BOOLEAN															:= FALSE;
		UDP_ENABLE_LOOPBACK								: BOOLEAN															:= FALSE;
		ICMP_ENABLE_ECHO									: BOOLEAN															:= FALSE;
		PING															: BOOLEAN															:= FALSE
	);
	PORT (
		Ethernet_Clock										: IN		STD_LOGIC;
		Ethernet_Reset										: IN		STD_LOGIC;

		Ethernet_Command									: IN		T_NET_ETH_COMMAND;
		Ethernet_Status										: OUT		T_NET_ETH_STATUS;

		PHY_Interface											:	INOUT	T_NET_ETH_PHY_INTERFACES;

		-- UDP ports
		TX_Valid													: IN	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Data														: IN	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
		TX_SOF														: IN	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		TX_EOF														: IN	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Ack														: OUT	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Meta_rst												: OUT	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Meta_SrcIPv4Address_nxt				: OUT	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Meta_SrcIPv4Address_Data				: IN	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Meta_DestIPv4Address_nxt				: OUT	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Meta_DestIPv4Address_Data			: IN	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Meta_SrcPort										: IN	T_SLVV_16(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Meta_DestPort									: IN	T_SLVV_16(UDP_PORTS'length - 1 DOWNTO 0);
		TX_Meta_Length										: IN	T_SLVV_16(UDP_PORTS'length - 1 DOWNTO 0);

		RX_Valid													: OUT	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Data														: OUT	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
		RX_SOF														: OUT	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		RX_EOF														: OUT	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Ack														: IN	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_rst												: IN	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_SrcMACAddress_nxt					: IN	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_SrcMACAddress_Data				: OUT	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_DestMACAddress_nxt				: IN	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_DestMACAddress_Data				: OUT	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_EthType										: OUT	T_SLVV_16(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_SrcIPv4Address_nxt				: IN	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_SrcIPv4Address_Data				: OUT	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_DestIPv4Address_nxt				: IN	STD_LOGIC_VECTOR(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_DestIPv4Address_Data			: OUT	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
--		RX_Meta_TrafficClass							: OUT	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
--		RX_Meta_FlowLabel									: OUT	T_SLVV_24(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_Length										: OUT	T_SLVV_16(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_Protocol									: OUT	T_SLVV_8(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_SrcPort										: OUT	T_SLVV_16(UDP_PORTS'length - 1 DOWNTO 0);
		RX_Meta_DestPort									: OUT	T_SLVV_16(UDP_PORTS'length - 1 DOWNTO 0)
	);
end entity;


ARCHITECTURE rtl OF stack_UDPv4 IS
	ATTRIBUTE KEEP											: BOOLEAN;
	ATTRIBUTE KEEP_HIERARCHY						: STRING;

	ATTRIBUTE KEEP OF Ethernet_Clock		: SIGNAL IS TRUE;

	FUNCTION if_append(cond : BOOLEAN; vector : T_NET_IPV4_PROTOCOL_VECTOR; item : T_NET_IPV4_PROTOCOL) RETURN T_NET_IPV4_PROTOCOL_VECTOR IS
	BEGIN
		IF cond THEN
			RETURN item & vector;
		ELSE
			RETURN vector;
		END IF;
	END FUNCTION;

	FUNCTION if_append(cond : BOOLEAN; vector : T_NET_UDP_PORTPAIR_VECTOR; item : T_NET_UDP_PORTPAIR) RETURN T_NET_UDP_PORTPAIR_VECTOR IS
	BEGIN
		IF cond THEN
			RETURN item & vector;
		ELSE
			RETURN vector;
		END IF;
	END FUNCTION;

	FUNCTION get_MAC_Configuration RETURN T_NET_MAC_CONFIGURATION_VECTOR IS
	BEGIN
		IF NOT MAC_ENABLE_LOOPBACK THEN
			RETURN (
				-- network interface 0 - MAC_ADDRESS
				0 => (
					Interface => 		(Address => MAC_ADDRESS,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(OTHERS =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						1 =>					C_NET_MAC_ETHERNETTYPE_IPV4,
						OTHERS =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
				1 => (
					Interface => 		(Address => MAC_ADDRESS,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(OTHERS =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						1 =>					C_NET_MAC_ETHERNETTYPE_IPV4,
						OTHERS =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
				2 => (
					Interface => 		(Address => C_NET_MAC_ADDRESS_BROADCAST,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(OTHERS =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						OTHERS =>			C_NET_MAC_ETHERNETTYPE_EMPTY))
			);
		ELSE
			RETURN (
				-- network interface 0 - MAC_ADDRESS
				0 => (
					Interface => 		(Address => MAC_ADDRESS,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(OTHERS =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						1 =>					C_NET_MAC_ETHERNETTYPE_IPV4,
						2 =>					C_NET_MAC_ETHERNETTYPE_LOOPBACK,
						OTHERS =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
				1 => (
					Interface => 		(Address => MAC_ADDRESS,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(OTHERS =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						1 =>					C_NET_MAC_ETHERNETTYPE_IPV4,
						2 =>					C_NET_MAC_ETHERNETTYPE_LOOPBACK,
						OTHERS =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
				2 => (
					Interface => 		(Address => C_NET_MAC_ADDRESS_BROADCAST,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(OTHERS =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						OTHERS =>			C_NET_MAC_ETHERNETTYPE_EMPTY))
			);
		END IF;
	END FUNCTION;

	-- define ethernet configuration
	CONSTANT MAC_CONFIGURATION			: T_NET_MAC_CONFIGURATION_VECTOR	:= get_MAC_Configuration;
	CONSTANT ETHERNET_PORTS					: POSITIVE												:= getPortCount(MAC_CONFIGURATION);

	-- define ethernet port numbers for unicast addresses
	-- --------------------------------------------------------------------------
	-- eth0
	CONSTANT ARP_MAC_UC_PORT_NUMBER		: NATURAL					:= 0;
	CONSTANT IPV4_MAC_PORT_NUMBER			: NATURAL					:= 1;
	CONSTANT MAC_LOOP_MAC_PORT_NUMBER		: NATURAL					:= 2;

	-- define ethernet port numbers for multicast address
	-- --------------------------------------------------------------------------
	-- eth1 - broadcast
	CONSTANT ARP_MAC_BC_PORT_NUMBER		: NATURAL					:= ETHERNET_PORTS - 1;	-- ite(NOT MAC_ENABLE_LOOPBACK, 2, 3);


	-- ARP configuration
	-- ==========================================================================================================================================================
--	CONSTANT INITIAL_IPV4ADDRESSES_ETH0									: T_NET_IPV4_ADDRESS_VECTOR		:= (
--		0 => to_net_ipv4_address(string'("192.168.10.10")),																				-- 192.168.10.10
--		1 => to_net_ipv4_address(string'("192.168.20.10")),																				-- 192.168.20.10
--		2 => to_net_ipv4_address(string'("192.168.90.10"))																				-- 192.168.90.10
--	);
--
--	CONSTANT INITIAL_ARPCACHE_CONTENT_ETH0							: T_NET_ARP_ARPCACHE_VECTOR		:= (
--		0 => (Tag => to_net_ipv4_address("192.168.10.1"),		MAC => to_net_mac_address("50:E5:49:52:F1:C8")),
--		1 => (Tag => to_net_ipv4_address("192.168.20.1"),		MAC => to_net_mac_address("64:70:02:01:DB:45")),
--		2 => (Tag => to_net_ipv4_address("192.168.30.1"),		MAC => to_net_mac_address("1A:1B:1C:1D:1E:1F")),
--		3 => (Tag => to_net_ipv4_address("192.168.40.1"),		MAC => to_net_mac_address("2A:2B:2C:2D:2E:2F"))
--	);

	-- IPv4 configuration
	-- ==========================================================================================================================================================
	CONSTANT ICMPV4_IPV4_PORT_NUMBER				: NATURAL				:= 0;
	CONSTANT UDPV4_IPV4_PORT_NUMBER					: NATURAL				:= 1;

	CONSTANT IPV4_PACKET_TYPES							: T_NET_IPV4_PROTOCOL_VECTOR		:= if_append(IPV4_ENABLE_LOOPBACK, (
		ICMPV4_IPV4_PORT_NUMBER =>	C_NET_IP_PROTOCOL_ICMP,
		UDPV4_IPV4_PORT_NUMBER =>		C_NET_IP_PROTOCOL_UDP),
		C_NET_IP_PROTOCOL_LOOPBACK
	);

	CONSTANT IPV4_PORTS											: POSITIVE			:= IPV4_PACKET_TYPES'length;
	CONSTANT IPV4_LOOP_IPV4_PORT_NUMBER			: NATURAL				:= IPV4_PORTS - 1;


	-- UDPv4 configuration
	-- ==========================================================================================================================================================
	CONSTANT UDPV4_PORTPAIRS								: T_NET_UDP_PORTPAIR_VECTOR			:= if_append(UDP_ENABLE_LOOPBACK, UDP_PORTS, (C_NET_TCP_PORTNUMBER_LOOPBACK, C_NET_TCP_PORTNUMBER_LOOPBACK));

	CONSTANT UDPV4_PORTS										: POSITIVE		:= UDPV4_PORTPAIRS'length;
	CONSTANT UDP_LOOP_UDPV4_PORT_NUMBER			: NATURAL			:= UDPV4_PORTS - 1;


	-- Ethernet layer signals
	SIGNAL Eth_Command											: T_NET_ETH_COMMAND;
	SIGNAL Eth_Status												: T_NET_ETH_STATUS;
	SIGNAL Eth_Error												: T_NET_ETH_ERROR;

	SIGNAL Eth_TX_Ack												: STD_LOGIC;																										--ATTRIBUTE KEEP OF Eth_TX_Ack			: SIGNAL IS TRUE;

	SIGNAL Eth_RX_Valid											: STD_LOGIC;																										--ATTRIBUTE KEEP OF Eth_RX_Valid		: SIGNAL IS TRUE;
	SIGNAL Eth_RX_Data											: T_SLV_8;																											--ATTRIBUTE KEEP OF Eth_RX_Data			: SIGNAL IS TRUE;
	SIGNAL Eth_RX_SOF												: STD_LOGIC;																										--ATTRIBUTE KEEP OF Eth_RX_SOF			: SIGNAL IS TRUE;
	SIGNAL Eth_RX_EOF												: STD_LOGIC;																										--ATTRIBUTE KEEP OF Eth_RX_EOF			: SIGNAL IS TRUE;

	-- Ethernet MAC layer signals
	SIGNAL MAC_TX_Valid											: STD_LOGIC;																										--ATTRIBUTE KEEP OF MAC_TX_Valid		: SIGNAL IS TRUE;
	SIGNAL MAC_TX_Data											: T_SLV_8;																											--ATTRIBUTE KEEP OF MAC_TX_Data			: SIGNAL IS TRUE;
	SIGNAL MAC_TX_SOF												: STD_LOGIC;																										--ATTRIBUTE KEEP OF MAC_TX_SOF			: SIGNAL IS TRUE;
	SIGNAL MAC_TX_EOF												: STD_LOGIC;																										--ATTRIBUTE KEEP OF MAC_TX_EOF			: SIGNAL IS TRUE;

	SIGNAL MAC_RX_Ack												: STD_LOGIC;																										--ATTRIBUTE KEEP OF MAC_RX_Ack			: SIGNAL IS TRUE;

	SIGNAL MAC_TX_Ack												: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_TX_Ack											: SIGNAL IS TRUE;
	SIGNAL MAC_TX_Meta_rst									: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_TX_Meta_rst									: SIGNAL IS TRUE;
	SIGNAL MAC_TX_Meta_DestMACAddress_nxt		: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_TX_Meta_DestMACAddress_nxt	: SIGNAL IS TRUE;

	SIGNAL MAC_RX_Valid											: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_RX_Valid										: SIGNAL IS TRUE;
	SIGNAL MAC_RX_Data											: T_SLVV_8(ETHERNET_PORTS - 1 DOWNTO 0);												--ATTRIBUTE KEEP OF MAC_RX_Data											: SIGNAL IS TRUE;
	SIGNAL MAC_RX_SOF												: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_RX_SOF											: SIGNAL IS TRUE;
	SIGNAL MAC_RX_EOF												: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_RX_EOF											: SIGNAL IS TRUE;
	SIGNAL MAC_RX_Meta_DestMACAddress_Data	: T_SLVV_8(ETHERNET_PORTS - 1 DOWNTO 0);												--ATTRIBUTE KEEP OF MAC_RX_Meta_DestMACAddress_Data	: SIGNAL IS TRUE;
	SIGNAL MAC_RX_Meta_SrcMACAddress_Data		: T_SLVV_8(ETHERNET_PORTS - 1 DOWNTO 0);												--ATTRIBUTE KEEP OF MAC_RX_Meta_SrcMACAddress_Data	: SIGNAL IS TRUE;
	SIGNAL MAC_RX_Meta_EthType							: T_NET_MAC_ETHERNETTYPE_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);		--ATTRIBUTE KEEP OF MAC_RX_Meta_EthType							: SIGNAL IS TRUE;

	-- Address Resolution Protocol layer signals
	SIGNAL ARP_UC_TX_Valid												: STD_LOGIC;
	SIGNAL ARP_UC_TX_Data													: T_SLV_8;
	SIGNAL ARP_UC_TX_SOF													: STD_LOGIC;
	SIGNAL ARP_UC_TX_EOF													: STD_LOGIC;
	SIGNAL ARP_UC_TX_Meta_DestMACAddress_Data			: T_SLV_8;

	SIGNAL ARP_UC_RX_Ack													: STD_LOGIC;
	SIGNAL ARP_UC_RX_Meta_rst											: STD_LOGIC;
	SIGNAL ARP_UC_RX_Meta_SrcMACAddress_nxt				: STD_LOGIC;
	SIGNAL ARP_UC_RX_Meta_DestMACAddress_nxt			: STD_LOGIC;

	SIGNAL ARP_IPCache_IPv4Address_rst						: STD_LOGIC;
	SIGNAL ARP_IPCache_IPv4Address_nxt						: STD_LOGIC;
	SIGNAL ARP_IPCache_Valid											: STD_LOGIC;
	SIGNAL ARP_IPCache_MACAddress_Data						: T_SLV_8;

	SIGNAL ARP_BC_RX_Ack													: STD_LOGIC;
	SIGNAL ARP_BC_RX_Meta_rst											: STD_LOGIC;
	SIGNAL ARP_BC_RX_Meta_SrcMACAddress_nxt				: STD_LOGIC;
	SIGNAL ARP_BC_RX_Meta_DestMACAddress_nxt			: STD_LOGIC;

	-- Internet Protocol Version 4 layer signals
	SIGNAL IPv4_TX_Valid													: STD_LOGIC;
	SIGNAL IPv4_TX_Data														: T_SLV_8;
	SIGNAL IPv4_TX_SOF														: STD_LOGIC;
	SIGNAL IPv4_TX_EOF														: STD_LOGIC;
	SIGNAL IPv4_TX_Meta_DestMACAddress_Data				: T_SLV_8;

	SIGNAL IPv4_RX_Ack														: STD_LOGIC;
	SIGNAL IPv4_RX_Meta_rst												: STD_LOGIC;
	SIGNAL IPv4_RX_Meta_SrcMACAddress_nxt					: STD_LOGIC;
	SIGNAL IPv4_RX_Meta_DestMACAddress_nxt				: STD_LOGIC;

	SIGNAL IPv4_ARP_Query													: STD_LOGIC;
	SIGNAL IPv4_ARP_IPv4Address_Data							: T_SLV_8;
	SIGNAL IPv4_ARP_MACAddress_rst								: STD_LOGIC;
	SIGNAL IPv4_ARP_MACAddress_nxt								: STD_LOGIC;

	SIGNAL IPv4_TX_Ack														: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_TX_Meta_rst												: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_TX_Meta_SrcIPv4Address_nxt				: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_TX_Meta_DestIPv4Address_nxt				: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);

	SIGNAL IPv4_RX_Valid													: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_Data														: T_SLVV_8(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_SOF														: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_EOF														: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_Meta_SrcMACAddress_Data				: T_SLVV_8(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_Meta_DestMACAddress_Data				: T_SLVV_8(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_Meta_EthType										: T_SLVV_16(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_Meta_SrcIPv4Address_Data				: T_SLVV_8(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_Meta_DestIPv4Address_Data			: T_SLVV_8(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_Meta_Length										: T_SLVV_16(IPV4_PORTS - 1 DOWNTO 0);
	SIGNAL IPv4_RX_Meta_Protocol									: T_SLVV_8(IPV4_PORTS - 1 DOWNTO 0);

	SIGNAL UDPv4_TX_Valid													: STD_LOGIC;
	SIGNAL UDPv4_TX_Data													: T_SLV_8;
	SIGNAL UDPv4_TX_SOF														: STD_LOGIC;
	SIGNAL UDPv4_TX_EOF														: STD_LOGIC;
	SIGNAL UDPv4_TX_Meta_SrcIPv4Address_Data			: T_SLV_8;
	SIGNAL UDPv4_TX_Meta_DestIPv4Address_Data			: T_SLV_8;
	SIGNAL UDPv4_TX_Meta_Length										: T_SLV_16;

	SIGNAL UDPv4_RX_Ack														: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_rst											: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_SrcMACAddress_nxt				: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_DestMACAddress_nxt				: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_SrcIPv4Address_nxt				: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_DestIPv4Address_nxt			: STD_LOGIC;

	SIGNAL UDPv4_TX_Ack														: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_TX_Meta_rst											: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_TX_Meta_SrcIPv4Address_nxt				: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_TX_Meta_DestIPv4Address_nxt			: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);

	SIGNAL UDPv4_RX_Valid													: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Data													: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_SOF														: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_EOF														: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Meta_SrcMACAddress_Data				: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Meta_DestMACAddress_Data			: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Meta_EthType									: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Meta_SrcIPv4Address_Data			: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Meta_DestIPv4Address_Data			: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Meta_Length										: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Meta_Protocol									: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Meta_SrcPort									: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);
	SIGNAL UDPv4_RX_Meta_DestPort									: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);

BEGIN

	blkEth : BLOCK
		SIGNAL TX_Clock							: STD_LOGIC;
		SIGNAL RX_Clock							: STD_LOGIC;
		SIGNAL Eth_TX_Clock					: STD_LOGIC;
		SIGNAL Eth_RX_Clock					: STD_LOGIC;
		SIGNAL RS_TX_Clock					: STD_LOGIC;
		SIGNAL RS_RX_Clock					: STD_LOGIC;

	BEGIN
		Eth_Command						<= Ethernet_Command;

		Ethernet_Status				<= Eth_Status;

		genGMIIClocking : IF (ETHERNET_PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_GMII) GENERATE
			TX_Clock						<= Ethernet_Clock;
			RX_Clock						<= Ethernet_Clock;
			Eth_TX_Clock				<= Ethernet_Clock;
			Eth_RX_Clock				<= PHY_Interface.GMII.RX_RefClock;
			RS_TX_Clock					<= Ethernet_Clock;
			RS_RX_Clock					<= PHY_Interface.GMII.RX_RefClock;
		END GENERATE;
		genSGMIIClocking : IF (ETHERNET_PHY_DATA_INTERFACE	= NET_ETH_PHY_DATA_INTERFACE_SGMII) GENERATE
			TX_Clock						<= Ethernet_Clock;
			RX_Clock						<= Ethernet_Clock;
			Eth_TX_Clock				<= PHY_Interface.SGMII.SGMII_TXRefClock_Out;
			Eth_RX_Clock				<= PHY_Interface.SGMII.SGMII_RXRefClock_Out;
			RS_TX_Clock					<= PHY_Interface.SGMII.SGMII_TXRefClock_Out;
			RS_RX_Clock					<= PHY_Interface.SGMII.SGMII_RXRefClock_Out;
		END GENERATE;

		Eth : ENTITY PoC.Eth_Wrapper
			GENERIC MAP (
				DEBUG											=> FALSE,	--DEBUG,
				CLOCKIN_FREQ							=> CLOCK_FREQ,
				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
				RS_DATA_INTERFACE					=> ETHERNET_RS_DATA_INTERFACE,
				PHY_DEVICE								=> ETHERNET_PHY_DEVICE,
				PHY_DEVICE_ADDRESS				=> ETHERNET_PHY_DEVICE_ADDRESS,
				PHY_DATA_INTERFACE				=> ETHERNET_PHY_DATA_INTERFACE,
				PHY_MANAGEMENT_INTERFACE	=> ETHERNET_PHY_MANAGEMENT_INTERFACE
			)
			PORT MAP (
				TX_Clock									=> TX_Clock,
				RX_Clock									=> RX_Clock,
				Eth_TX_Clock							=> Eth_TX_Clock,
				Eth_RX_Clock							=> Eth_RX_Clock,
				RS_TX_Clock								=> RS_TX_Clock,
				RS_RX_Clock								=> RS_RX_Clock,

				Ethernet_Reset						=> Ethernet_Reset,

				Command										=> Eth_Command,
				Status										=> Eth_Status,
				Error											=> Eth_Error,

				-- LocalLink interface
				TX_Valid									=> MAC_TX_Valid,
				TX_Data										=> MAC_TX_Data,
				TX_SOF										=> MAC_TX_SOF,
				TX_EOF										=> MAC_TX_EOF,
				TX_Ack										=> Eth_TX_Ack,

				RX_Valid									=> Eth_RX_Valid,
				RX_Data										=> Eth_RX_Data,
				RX_SOF										=> Eth_RX_SOF,
				RX_EOF										=> Eth_RX_EOF,
				RX_Ack										=> MAC_RX_Ack,

				-- FPGA <=> PHY interface
				PHY_Interface							=> PHY_Interface
			);
	END BLOCK;

	blkMAC : BLOCK
		ATTRIBUTE KEEP_HIERARCHY OF MAC : LABEL IS "FALSE";

		SIGNAL blkMAC_TX_Valid										: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_TX_Data											: T_SLVV_8(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_TX_SOF											: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_TX_EOF											: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_TX_Meta_DestMACAddress_Data	: T_SLVV_8(ETHERNET_PORTS - 1 DOWNTO 0);

		SIGNAL blkMAC_RX_Ack											: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_RX_Meta_rst									: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_RX_Meta_DestMACAddress_nxt	: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_RX_Meta_SrcMACAddress_nxt		: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);

	BEGIN
		MAC : ENTITY PoC.mac_Wrapper
			GENERIC MAP (
				DEBUG								=> DEBUG,
				MAC_CONFIG										=> MAC_CONFIGURATION
			)
			PORT MAP (
				Clock													=> Ethernet_Clock,
				Reset													=> Ethernet_Reset,

				Eth_TX_Valid									=> MAC_TX_Valid,
				Eth_TX_Data										=> MAC_TX_Data,
				Eth_TX_SOF										=> MAC_TX_SOF,
				Eth_TX_EOF										=> MAC_TX_EOF,
				Eth_TX_Ack										=> Eth_TX_Ack,

				Eth_RX_Valid									=> Eth_RX_Valid,
				Eth_RX_Data										=> Eth_RX_Data,
				Eth_RX_SOF										=> Eth_RX_SOF,
				Eth_RX_EOF										=> Eth_RX_EOF,
				Eth_RX_Ack										=> MAC_RX_Ack,

				TX_Valid											=> blkMAC_TX_Valid,
				TX_Data												=> blkMAC_TX_Data,
				TX_SOF												=> blkMAC_TX_SOF,
				TX_EOF												=> blkMAC_TX_EOF,
				TX_Ack												=> MAC_TX_Ack,
				TX_Meta_rst										=> MAC_TX_Meta_rst,
				TX_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt,
				TX_Meta_DestMACAddress_Data		=> blkMAC_TX_Meta_DestMACAddress_Data,

				RX_Valid											=> MAC_RX_Valid,
				RX_Data												=> MAC_RX_Data,
				RX_SOF												=> MAC_RX_SOF,
				RX_EOF												=> MAC_RX_EOF,
				RX_Ack												=> blkMAC_RX_Ack,
				RX_Meta_rst										=> blkMAC_RX_Meta_rst,
				RX_Meta_SrcMACAddress_nxt			=> blkMAC_RX_Meta_SrcMACAddress_nxt,
				RX_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data,
				RX_Meta_DestMACAddress_nxt		=> blkMAC_RX_Meta_DestMACAddress_nxt,
				RX_Meta_DestMACAddress_Data		=> MAC_RX_Meta_DestMACAddress_Data,
				RX_Meta_EthType								=> MAC_RX_Meta_EthType
			);

		-- Ethernet Port 0 -> ARP UC
		-- ========================================================================
		blkMAC_TX_Valid(ARP_MAC_UC_PORT_NUMBER)											<= ARP_UC_TX_Valid;
		blkMAC_TX_Data(ARP_MAC_UC_PORT_NUMBER)											<= ARP_UC_TX_Data;
		blkMAC_TX_SOF(ARP_MAC_UC_PORT_NUMBER)												<= ARP_UC_TX_SOF;
		blkMAC_TX_EOF(ARP_MAC_UC_PORT_NUMBER)												<= ARP_UC_TX_EOF;
		blkMAC_TX_Meta_DestMACAddress_Data(ARP_MAC_UC_PORT_NUMBER)	<= ARP_UC_TX_Meta_DestMACAddress_Data;

		blkMAC_RX_Ack	(ARP_MAC_UC_PORT_NUMBER)											<= ARP_UC_RX_Ack;
		blkMAC_RX_Meta_rst(ARP_MAC_UC_PORT_NUMBER)									<= ARP_UC_RX_Meta_rst;
		blkMAC_RX_Meta_SrcMACAddress_nxt(ARP_MAC_UC_PORT_NUMBER)		<= ARP_UC_RX_Meta_SrcMACAddress_nxt;
		blkMAC_RX_Meta_DestMACAddress_nxt(ARP_MAC_UC_PORT_NUMBER)		<= ARP_UC_RX_Meta_DestMACAddress_nxt;

		-- Ethernet Port 1 -> IPv4
		-- ========================================================================
		blkMAC_TX_Valid(IPV4_MAC_PORT_NUMBER)												<= IPv4_TX_Valid;
		blkMAC_TX_Data(IPV4_MAC_PORT_NUMBER)												<= IPv4_TX_Data;
		blkMAC_TX_SOF(IPV4_MAC_PORT_NUMBER)													<= IPv4_TX_SOF;
		blkMAC_TX_EOF(IPV4_MAC_PORT_NUMBER)													<= IPv4_TX_EOF;
		blkMAC_TX_Meta_DestMACAddress_Data(IPV4_MAC_PORT_NUMBER)		<= IPv4_TX_Meta_DestMACAddress_Data;

		blkMAC_RX_Ack	(IPV4_MAC_PORT_NUMBER)												<= IPv4_RX_Ack;
		blkMAC_RX_Meta_rst(IPV4_MAC_PORT_NUMBER)										<= '0';	--IPv4_RX_Meta_rst;
		blkMAC_RX_Meta_SrcMACAddress_nxt(IPV4_MAC_PORT_NUMBER)			<= '0';	--IPv4_RX_Meta_SrcMACAddress_nxt;
		blkMAC_RX_Meta_DestMACAddress_nxt(IPV4_MAC_PORT_NUMBER)			<= '0';	--IPv4_RX_Meta_DestMACAddress_nxt;

		genLB0 : IF (MAC_ENABLE_LOOPBACK = FALSE) GENERATE
			-- Ethernet Port 2 -> ARP Broadcast
			-- ========================================================================
			blkMAC_TX_Valid(ARP_MAC_BC_PORT_NUMBER)											<= '0';
			blkMAC_TX_Data(ARP_MAC_BC_PORT_NUMBER)											<= (OTHERS => '0');
			blkMAC_TX_SOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
			blkMAC_TX_EOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
			blkMAC_TX_Meta_DestMACAddress_Data(ARP_MAC_BC_PORT_NUMBER)	<= (OTHERS => '0');

			blkMAC_RX_Ack	(ARP_MAC_BC_PORT_NUMBER)											<= ARP_BC_RX_Ack;
			blkMAC_RX_Meta_rst(ARP_MAC_BC_PORT_NUMBER)									<= ARP_BC_RX_Meta_rst;
			blkMAC_RX_Meta_SrcMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_SrcMACAddress_nxt;
			blkMAC_RX_Meta_DestMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_DestMACAddress_nxt;
		END GENERATE;

		genLB1 : IF (MAC_ENABLE_LOOPBACK = TRUE) GENERATE
			-- LoopBack layer signals
			SIGNAL MAC_LOOP_TX_Valid											: STD_LOGIC;
			SIGNAL MAC_LOOP_TX_Data												: T_SLV_8;
			SIGNAL MAC_LOOP_TX_SOF												: STD_LOGIC;
			SIGNAL MAC_LOOP_TX_EOF												: STD_LOGIC;
			SIGNAL MAC_LOOP_TX_Meta_DestMACAddress_Data		: T_SLV_8;
			SIGNAL MAC_LOOP_TX_Meta_SrcMACAddress_Data		: T_SLV_8;
			SIGNAL MAC_LOOP_TX_Meta_EthType								: T_NET_MAC_ETHERNETTYPE;

			SIGNAL MAC_LOOP_RX_Ack												: STD_LOGIC;
			SIGNAL MAC_LOOP_RX_Meta_rst										: STD_LOGIC;
			SIGNAL MAC_LOOP_RX_Meta_DestMACAddress_nxt		: STD_LOGIC;
			SIGNAL MAC_LOOP_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
		BEGIN
			-- Ethernet Port 2 -> LoopBack
			-- ========================================================================
			blkMAC_TX_Valid(MAC_LOOP_MAC_PORT_NUMBER)											<= MAC_LOOP_TX_Valid;
			blkMAC_TX_Data(MAC_LOOP_MAC_PORT_NUMBER)											<= MAC_LOOP_TX_Data;
			blkMAC_TX_SOF(MAC_LOOP_MAC_PORT_NUMBER)												<= MAC_LOOP_TX_SOF;
			blkMAC_TX_EOF(MAC_LOOP_MAC_PORT_NUMBER)												<= MAC_LOOP_TX_EOF;
			blkMAC_TX_Meta_DestMACAddress_Data(MAC_LOOP_MAC_PORT_NUMBER)	<= MAC_LOOP_TX_Meta_DestMACAddress_Data;

			blkMAC_RX_Ack	(MAC_LOOP_MAC_PORT_NUMBER)											<= MAC_LOOP_RX_Ack;
			blkMAC_RX_Meta_rst(MAC_LOOP_MAC_PORT_NUMBER)									<= MAC_LOOP_RX_Meta_rst;
			blkMAC_RX_Meta_SrcMACAddress_nxt(MAC_LOOP_MAC_PORT_NUMBER)		<= MAC_LOOP_RX_Meta_SrcMACAddress_nxt;
			blkMAC_RX_Meta_DestMACAddress_nxt(MAC_LOOP_MAC_PORT_NUMBER)		<= '0';	--MAC_LOOP_RX_Meta_DestMACAddress_nxt;

			-- Ethernet Port 3 -> ARP Broadcast
			-- ========================================================================
			blkMAC_TX_Valid(ARP_MAC_BC_PORT_NUMBER)											<= '0';
			blkMAC_TX_Data(ARP_MAC_BC_PORT_NUMBER)											<= (OTHERS => '0');
			blkMAC_TX_SOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
			blkMAC_TX_EOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
			blkMAC_TX_Meta_DestMACAddress_Data(ARP_MAC_BC_PORT_NUMBER)	<= (OTHERS => '0');

			blkMAC_RX_Ack	(ARP_MAC_BC_PORT_NUMBER)											<= ARP_BC_RX_Ack;
			blkMAC_RX_Meta_rst(ARP_MAC_BC_PORT_NUMBER)									<= ARP_BC_RX_Meta_rst;
			blkMAC_RX_Meta_SrcMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_SrcMACAddress_nxt;
			blkMAC_RX_Meta_DestMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_DestMACAddress_nxt;

			MAC_LOOP : ENTITY PoC.mac_FrameLoopback
				GENERIC MAP (
					MAX_FRAMES										=> 4
				)
				PORT MAP (
					Clock													=> Ethernet_Clock,
					Reset													=> Ethernet_Reset,

					In_Valid											=> MAC_RX_Valid(MAC_LOOP_MAC_PORT_NUMBER),
					In_Data												=> MAC_RX_Data(MAC_LOOP_MAC_PORT_NUMBER),
					In_SOF												=> MAC_RX_SOF(MAC_LOOP_MAC_PORT_NUMBER),
					In_EOF												=> MAC_RX_EOF(MAC_LOOP_MAC_PORT_NUMBER),
					In_Ack												=> MAC_LOOP_RX_Ack,
					In_Meta_rst										=> MAC_LOOP_RX_Meta_rst,
					In_Meta_DestMACAddress_nxt		=> MAC_LOOP_RX_Meta_DestMACAddress_nxt,
					In_Meta_DestMACAddress_Data		=> MAC_RX_Meta_DestMACAddress_Data(MAC_LOOP_MAC_PORT_NUMBER),
					In_Meta_SrcMACAddress_nxt			=> MAC_LOOP_RX_Meta_SrcMACAddress_nxt,
					In_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(MAC_LOOP_MAC_PORT_NUMBER),
	--				In_Meta_EthType								=> MAC_RX_Meta_EthType(MAC_LOOP_MAC_PORT_NUMBER),

					Out_Valid											=> MAC_LOOP_TX_Valid,
					Out_Data											=> MAC_LOOP_TX_Data,
					Out_SOF												=> MAC_LOOP_TX_SOF,
					Out_EOF												=> MAC_LOOP_TX_EOF,
					Out_Ack												=> MAC_TX_Ack	(MAC_LOOP_MAC_PORT_NUMBER),
					Out_Meta_rst									=> MAC_TX_Meta_rst(MAC_LOOP_MAC_PORT_NUMBER),
					Out_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt(MAC_LOOP_MAC_PORT_NUMBER),
					Out_Meta_DestMACAddress_Data	=> MAC_LOOP_TX_Meta_DestMACAddress_Data,
					Out_Meta_SrcMACAddress_nxt		=> '0',		--MAC_TX_Meta_SrcMACAddress_nxt(MAC_LOOP_MAC_PORT_NUMBER),
					Out_Meta_SrcMACAddress_Data		=> OPEN		--MAC_LOOP_TX_Meta_SrcMACAddress_Data,
	--				Out_Meta_EthType							=> OPEN		--MAC_LOOP_TX_Meta_EthType
				);
		END GENERATE;
	END BLOCK;

	blkARP : BLOCK
		ATTRIBUTE KEEP_HIERARCHY OF ARP 					: LABEL IS "FALSE";

	BEGIN
		--
		ARP : ENTITY PoC.arp_Wrapper
			GENERIC MAP (
				CLOCK_FREQ													=> CLOCK_FREQ,
				INTERFACE_MACADDRESS								=> MAC_CONFIGURATION(0).Interface.Address,
--				INITIAL_IPV4ADDRESSES								=> INITIAL_IPV4ADDRESSES_ETH0,
--				INITIAL_ARPCACHE_CONTENT						=> INITIAL_ARPCACHE_CONTENT_ETH0,
				APR_REQUEST_TIMEOUT									=> 2000.0 ms
			)
			PORT MAP (
				Clock																=> Ethernet_Clock,
				Reset																=> Ethernet_Reset,

				IPPool_Announce											=> '0',

				IPCache_Lookup											=> IPv4_ARP_Query,
--				IPCache_Delayed
				IPCache_IPv4Address_rst							=> ARP_IPCache_IPv4Address_rst,
				IPCache_IPv4Address_nxt							=> ARP_IPCache_IPv4Address_nxt,
				IPCache_IPv4Address_Data						=> IPv4_ARP_IPv4Address_Data,

				IPCache_Valid												=> ARP_IPCache_Valid,
--				IPCache_HostUnknown
				IPCache_MACAddress_rst							=> IPv4_ARP_MACAddress_rst,
				IPCache_MACAddress_nxt							=> IPv4_ARP_MACAddress_nxt,
				IPCache_MACAddress_Data							=> ARP_IPCache_MACAddress_Data,

				Eth_UC_TX_Valid											=> ARP_UC_TX_Valid,
				Eth_UC_TX_Data											=> ARP_UC_TX_Data,
				Eth_UC_TX_SOF												=> ARP_UC_TX_SOF,
				Eth_UC_TX_EOF												=> ARP_UC_TX_EOF,
				Eth_UC_TX_Ack												=> MAC_TX_Ack	(ARP_MAC_UC_PORT_NUMBER),
				Eth_UC_TX_Meta_rst									=> MAC_TX_Meta_rst(ARP_MAC_UC_PORT_NUMBER),
				Eth_UC_TX_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt(ARP_MAC_UC_PORT_NUMBER),
				Eth_UC_TX_Meta_DestMACAddress_Data	=> ARP_UC_TX_Meta_DestMACAddress_Data,

				Eth_UC_RX_Valid											=> MAC_RX_Valid(ARP_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_Data											=> MAC_RX_Data(ARP_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_SOF												=> MAC_RX_SOF(ARP_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_EOF												=> MAC_RX_EOF(ARP_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_Ack												=> ARP_UC_RX_Ack,
				Eth_UC_RX_Meta_rst									=> ARP_UC_RX_Meta_rst,
				Eth_UC_RX_Meta_SrcMACAddress_nxt		=> ARP_UC_RX_Meta_SrcMACAddress_nxt,
				Eth_UC_RX_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(ARP_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_Meta_DestMACAddress_nxt		=> ARP_UC_RX_Meta_DestMACAddress_nxt,
				Eth_UC_RX_Meta_DestMACAddress_Data	=> MAC_RX_Meta_DestMACAddress_Data(ARP_MAC_UC_PORT_NUMBER),

				Eth_BC_RX_Valid											=> MAC_RX_Valid(ARP_MAC_BC_PORT_NUMBER),
				Eth_BC_RX_Data											=> MAC_RX_Data(ARP_MAC_BC_PORT_NUMBER),
				Eth_BC_RX_SOF												=> MAC_RX_SOF(ARP_MAC_BC_PORT_NUMBER),
				Eth_BC_RX_EOF												=> MAC_RX_EOF(ARP_MAC_BC_PORT_NUMBER),
				Eth_BC_RX_Ack												=> ARP_BC_RX_Ack,
				Eth_BC_RX_Meta_rst									=> ARP_BC_RX_Meta_rst,
				Eth_BC_RX_Meta_SrcMACAddress_nxt		=> ARP_BC_RX_Meta_SrcMACAddress_nxt,
				Eth_BC_RX_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(ARP_MAC_BC_PORT_NUMBER),
				Eth_BC_RX_Meta_DestMACAddress_nxt		=> ARP_BC_RX_Meta_DestMACAddress_nxt,
				Eth_BC_RX_Meta_DestMACAddress_Data	=> MAC_RX_Meta_DestMACAddress_Data(ARP_MAC_BC_PORT_NUMBER)
			);
	END BLOCK;

	blkIPv4 : BLOCK
		ATTRIBUTE KEEP_HIERARCHY OF IPv4						: LABEL IS "FALSE";
		ATTRIBUTE KEEP_HIERARCHY OF ICMPv4					: LABEL IS "FALSE";

		SIGNAL blk_TX_Valid													: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Data													: T_SLVV_8(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_SOF														: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_EOF														: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_rst											: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_SrcIPv4Address_Data			: T_SLVV_8(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_DestIPv4Address_Data			: T_SLVV_8(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_Length										: T_SLVV_16(IPV4_PORTS - 1 DOWNTO 0);

		SIGNAL blk_RX_Ack														: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_rst											: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcMACAddress_nxt				: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestMACAddress_nxt				: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcIPv4Address_nxt				: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestIPv4Address_nxt			: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);

		SIGNAL blk_IPCache_Query										: STD_LOGIC;
		SIGNAL blk_IPCache_IPv4Address_Data					: T_SLV_8;
		SIGNAL blk_IPCache_IPv4Address_rst					: STD_LOGIC;
		SIGNAL blk_IPCache_IPv4Address_nxt					: STD_LOGIC;
		SIGNAL blk_IPCache_Valid										: STD_LOGIC;
		SIGNAL blk_IPCache_MACAddress_Data					: T_SLV_8;
		SIGNAL blk_IPCache_MACAddress_rst						: STD_LOGIC;
		SIGNAL blk_IPCache_MACAddress_nxt						: STD_LOGIC;

		SIGNAL ICMPv4_Command												: T_NET_ICMPV4_COMMAND		:= NET_ICMPV4_CMD_NONE;
		SIGNAL ICMPv4_Status												: T_NET_ICMPV4_STATUS;
		SIGNAL ICMPv4_Error													: T_NET_ICMPV4_ERROR;

		SIGNAL ICMPv4_TX_Valid											: STD_LOGIC;
		SIGNAL ICMPv4_TX_Data												: T_SLV_8;
		SIGNAL ICMPv4_TX_SOF												: STD_LOGIC;
		SIGNAL ICMPv4_TX_EOF												: STD_LOGIC;
		SIGNAL ICMPv4_TX_Meta_SrcIPv4Address_Data		: T_SLV_8;
		SIGNAL ICMPv4_TX_Meta_DestIPv4Address_Data	: T_SLV_8;
		SIGNAL ICMPv4_TX_Meta_Length								: T_SLV_16;

		SIGNAL ICMPv4_RX_Ack												: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_rst										: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_DestMACAddress_nxt		: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_SrcIPv4Address_nxt		: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_DestIPv4Address_nxt		: STD_LOGIC;

--		SIGNAL ICMPv4_IPv4Address_rst								: STD_LOGIC;
--		SIGNAL ICMPv4_IPv4Address_nxt								: STD_LOGIC;
--		SIGNAL EchoReqIPv4Seq_IPv4Address_Data			: T_SLV_8;
	BEGIN
		IPv4 : ENTITY PoC.ipv4_Wrapper
			GENERIC MAP (
				PACKET_TYPES											=> IPV4_PACKET_TYPES
			)
			PORT MAP (
				Clock															=> Ethernet_Clock,
				Reset															=> Ethernet_Reset,

				MAC_TX_Valid											=> IPv4_TX_Valid,
				MAC_TX_Data												=> IPv4_TX_Data,
				MAC_TX_SOF												=> IPv4_TX_SOF,
				MAC_TX_EOF												=> IPv4_TX_EOF,
				MAC_TX_Ack												=> MAC_TX_Ack	(IPV4_MAC_PORT_NUMBER),
				MAC_TX_Meta_rst										=> MAC_TX_Meta_rst(IPV4_MAC_PORT_NUMBER),
				MAC_TX_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt(IPV4_MAC_PORT_NUMBER),
				MAC_TX_Meta_DestMACAddress_Data		=> IPv4_TX_Meta_DestMACAddress_Data,

				MAC_RX_Valid											=> MAC_RX_Valid(IPV4_MAC_PORT_NUMBER),
				MAC_RX_Data												=> MAC_RX_Data(IPV4_MAC_PORT_NUMBER),
				MAC_RX_SOF												=> MAC_RX_SOF(IPV4_MAC_PORT_NUMBER),
				MAC_RX_EOF												=> MAC_RX_EOF(IPV4_MAC_PORT_NUMBER),
				MAC_RX_Ack												=> IPv4_RX_Ack,
				MAC_RX_Meta_rst										=> IPv4_RX_Meta_rst,
				MAC_RX_Meta_SrcMACAddress_nxt			=> IPv4_RX_Meta_SrcMACAddress_nxt,
				MAC_RX_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(IPV4_MAC_PORT_NUMBER),
				MAC_RX_Meta_DestMACAddress_nxt		=> IPv4_RX_Meta_DestMACAddress_nxt,
				MAC_RX_Meta_DestMACAddress_Data		=> MAC_RX_Meta_DestMACAddress_Data(IPV4_MAC_PORT_NUMBER),
				MAC_RX_Meta_EthType								=> to_slv(MAC_RX_Meta_EthType(IPV4_MAC_PORT_NUMBER)),

				ARP_IPCache_Query									=> IPv4_ARP_Query,
				ARP_IPCache_IPv4Address_rst				=> ARP_IPCache_IPv4Address_rst,
				ARP_IPCache_IPv4Address_nxt				=> ARP_IPCache_IPv4Address_nxt,
				ARP_IPCache_IPv4Address_Data			=> IPv4_ARP_IPv4Address_Data,

				ARP_IPCache_Valid									=> ARP_IPCache_Valid,
				ARP_IPCache_MACAddress_rst				=> IPv4_ARP_MACAddress_rst,
				ARP_IPCache_MACAddress_nxt				=> IPv4_ARP_MACAddress_nxt,
				ARP_IPCache_MACAddress_Data				=> ARP_IPCache_MACAddress_Data,

				TX_Valid													=> blk_TX_Valid,
				TX_Data														=> blk_TX_Data,
				TX_SOF														=> blk_TX_SOF,
				TX_EOF														=> blk_TX_EOF,
				TX_Ack														=> IPv4_TX_Ack,
				TX_Meta_rst												=> IPv4_TX_Meta_rst,
				TX_Meta_SrcIPv4Address_nxt				=> IPv4_TX_Meta_SrcIPv4Address_nxt,
				TX_Meta_SrcIPv4Address_Data				=> blk_TX_Meta_SrcIPv4Address_Data,
				TX_Meta_DestIPv4Address_nxt				=> IPv4_TX_Meta_DestIPv4Address_nxt,
				TX_Meta_DestIPv4Address_Data			=> blk_TX_Meta_DestIPv4Address_Data,
				TX_Meta_Length										=> blk_TX_Meta_Length,

				RX_Valid													=> IPv4_RX_Valid,
				RX_Data														=> IPv4_RX_Data,
				RX_SOF														=> IPv4_RX_SOF,
				RX_EOF														=> IPv4_RX_EOF,
				RX_Ack														=> blk_RX_Ack,
				RX_Meta_rst												=> blk_RX_Meta_rst,
				RX_Meta_SrcMACAddress_nxt					=> blk_RX_Meta_SrcMACAddress_nxt,
				RX_Meta_SrcMACAddress_Data				=> IPv4_RX_Meta_SrcMACAddress_Data,
				RX_Meta_DestMACAddress_nxt				=> blk_RX_Meta_DestMACAddress_nxt,
				RX_Meta_DestMACAddress_Data				=> IPv4_RX_Meta_DestMACAddress_Data,
				RX_Meta_EthType										=> IPv4_RX_Meta_EthType,
				RX_Meta_SrcIPv4Address_nxt				=> blk_RX_Meta_SrcIPv4Address_nxt,
				RX_Meta_SrcIPv4Address_Data				=> IPv4_RX_Meta_SrcIPv4Address_Data,
				RX_Meta_DestIPv4Address_nxt				=> blk_RX_Meta_DestIPv4Address_nxt,
				RX_Meta_DestIPv4Address_Data			=> IPv4_RX_Meta_DestIPv4Address_Data,
				RX_Meta_Length										=> IPv4_RX_Meta_Length,
				RX_Meta_Protocol									=> IPv4_RX_Meta_Protocol
			);

		-- IPv4 Port 0 - ICMPv4
		blk_TX_Valid(ICMPV4_IPV4_PORT_NUMBER)														<= ICMPv4_TX_Valid;
		blk_TX_Data(ICMPV4_IPV4_PORT_NUMBER)														<= ICMPv4_TX_Data;
		blk_TX_SOF(ICMPV4_IPV4_PORT_NUMBER)															<= ICMPv4_TX_SOF;
		blk_TX_EOF(ICMPV4_IPV4_PORT_NUMBER)															<= ICMPv4_TX_EOF;
		blk_TX_Meta_SrcIPv4Address_Data(ICMPV4_IPV4_PORT_NUMBER)				<= ICMPv4_TX_Meta_SrcIPv4Address_Data;
		blk_TX_Meta_DestIPv4Address_Data(ICMPV4_IPV4_PORT_NUMBER)				<= ICMPv4_TX_Meta_DestIPv4Address_Data;
		blk_TX_Meta_Length(ICMPV4_IPV4_PORT_NUMBER)											<= ICMPv4_TX_Meta_Length;

		blk_RX_Ack	(ICMPV4_IPV4_PORT_NUMBER)														<= ICMPv4_RX_Ack;
		blk_RX_Meta_rst(ICMPV4_IPV4_PORT_NUMBER)												<= ICMPv4_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(ICMPV4_IPV4_PORT_NUMBER)					<= ICMPv4_RX_Meta_SrcMACAddress_nxt;
		blk_RX_Meta_DestMACAddress_nxt(ICMPV4_IPV4_PORT_NUMBER)					<= ICMPv4_RX_Meta_DestMACAddress_nxt;
		blk_RX_Meta_SrcIPv4Address_nxt(ICMPV4_IPV4_PORT_NUMBER)					<= ICMPv4_RX_Meta_SrcIPv4Address_nxt;
		blk_RX_Meta_DestIPv4Address_nxt(ICMPV4_IPV4_PORT_NUMBER)				<= ICMPv4_RX_Meta_DestIPv4Address_nxt;

		-- IPv4 Port 1 - UDPv4
		blk_TX_Valid(UDPV4_IPV4_PORT_NUMBER)														<= UDPv4_TX_Valid;
		blk_TX_Data(UDPV4_IPV4_PORT_NUMBER)															<= UDPv4_TX_Data;
		blk_TX_SOF(UDPV4_IPV4_PORT_NUMBER)															<= UDPv4_TX_SOF;
		blk_TX_EOF(UDPV4_IPV4_PORT_NUMBER)															<= UDPv4_TX_EOF;
		blk_TX_Meta_SrcIPv4Address_Data(UDPV4_IPV4_PORT_NUMBER)					<= UDPv4_TX_Meta_SrcIPv4Address_Data;
		blk_TX_Meta_DestIPv4Address_Data(UDPV4_IPV4_PORT_NUMBER)				<= UDPv4_TX_Meta_DestIPv4Address_Data;
		blk_TX_Meta_Length(UDPV4_IPV4_PORT_NUMBER)											<= UDPv4_TX_Meta_Length;

		blk_RX_Ack	(UDPV4_IPV4_PORT_NUMBER)														<= UDPv4_RX_Ack;
		blk_RX_Meta_rst(UDPV4_IPV4_PORT_NUMBER)													<= UDPv4_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(UDPV4_IPV4_PORT_NUMBER)						<= UDPv4_RX_Meta_SrcMACAddress_nxt;
		blk_RX_Meta_DestMACAddress_nxt(UDPV4_IPV4_PORT_NUMBER)					<= UDPv4_RX_Meta_DestMACAddress_nxt;
		blk_RX_Meta_SrcIPv4Address_nxt(UDPV4_IPV4_PORT_NUMBER)					<= UDPv4_RX_Meta_SrcIPv4Address_nxt;
		blk_RX_Meta_DestIPv4Address_nxt(UDPV4_IPV4_PORT_NUMBER)					<= UDPv4_RX_Meta_DestIPv4Address_nxt;

--		genLB0 : IF (IPV4_ENABLE_LOOPBACK = FALSE) GENERATE
--
--		END GENERATE;
		genLB1 : IF (IPV4_ENABLE_LOOPBACK = TRUE) GENERATE
			SIGNAL IPV4_LOOP_TX_Valid											: STD_LOGIC;
			SIGNAL IPV4_LOOP_TX_Data											: T_SLV_8;
			SIGNAL IPV4_LOOP_TX_SOF												: STD_LOGIC;
			SIGNAL IPV4_LOOP_TX_EOF												: STD_LOGIC;
			SIGNAL IPV4_LOOP_TX_Meta_SrcIPv4Address_Data	: T_SLV_8;
			SIGNAL IPV4_LOOP_TX_Meta_DestIPv4Address_Data	: T_SLV_8;
			SIGNAL IPV4_LOOP_TX_Meta_Length								: T_SLV_16;

			SIGNAL IPV4_LOOP_TX_Meta_rst									: STD_LOGIC;
			SIGNAL IPV4_LOOP_TX_Meta_SrcIPv4Address_nxt		: STD_LOGIC;
			SIGNAL IPV4_LOOP_TX_Meta_DestIPv4Address_nxt	: STD_LOGIC;

			SIGNAL IPV4_LOOP_RX_Ack												: STD_LOGIC;
			SIGNAL IPV4_LOOP_RX_Meta_rst									: STD_LOGIC;
			SIGNAL IPV4_LOOP_RX_Meta_SrcIPv4Address_nxt		: STD_LOGIC;
			SIGNAL IPV4_LOOP_RX_Meta_DestIPv4Address_nxt	: STD_LOGIC;
		BEGIN
			-- IPv4 Port 2 - Loopback
			blk_TX_Valid(IPV4_LOOP_IPV4_PORT_NUMBER)											<= IPV4_LOOP_TX_Valid;
			blk_TX_Data(IPV4_LOOP_IPV4_PORT_NUMBER)												<= IPV4_LOOP_TX_Data;
			blk_TX_SOF(IPV4_LOOP_IPV4_PORT_NUMBER)												<= IPV4_LOOP_TX_SOF;
			blk_TX_EOF(IPV4_LOOP_IPV4_PORT_NUMBER)												<= IPV4_LOOP_TX_EOF;
			blk_TX_Meta_SrcIPv4Address_Data(IPV4_LOOP_IPV4_PORT_NUMBER)		<= IPV4_LOOP_TX_Meta_SrcIPv4Address_Data;
			blk_TX_Meta_DestIPv4Address_Data(IPV4_LOOP_IPV4_PORT_NUMBER)	<= IPV4_LOOP_TX_Meta_DestIPv4Address_Data;
			blk_TX_Meta_Length(IPV4_LOOP_IPV4_PORT_NUMBER)								<= IPV4_LOOP_TX_Meta_Length;

			blk_RX_Ack	(IPV4_LOOP_IPV4_PORT_NUMBER)											<= IPV4_LOOP_RX_Ack;
			blk_RX_Meta_rst(IPV4_LOOP_IPV4_PORT_NUMBER)										<= IPV4_LOOP_RX_Meta_rst;
			blk_RX_Meta_SrcMACAddress_nxt(IPV4_LOOP_IPV4_PORT_NUMBER)			<= '0';
			blk_RX_Meta_DestMACAddress_nxt(IPV4_LOOP_IPV4_PORT_NUMBER)		<= '0';
			blk_RX_Meta_SrcIPv4Address_nxt(IPV4_LOOP_IPV4_PORT_NUMBER)		<= IPV4_LOOP_RX_Meta_SrcIPv4Address_nxt;
			blk_RX_Meta_DestIPv4Address_nxt(IPV4_LOOP_IPV4_PORT_NUMBER)		<= IPV4_LOOP_RX_Meta_DestIPv4Address_nxt;

			IPV4_LOOP : ENTITY PoC.ipv4_FrameLoopback
				GENERIC MAP (
					MAX_FRAMES										=> 4
				)
				PORT MAP (
					Clock													=> Ethernet_Clock,
					Reset													=> Ethernet_Reset,

					In_Valid											=> IPv4_RX_Valid(IPV4_LOOP_IPV4_PORT_NUMBER),
					In_Data												=> IPv4_RX_Data(IPV4_LOOP_IPV4_PORT_NUMBER),
					In_SOF												=> IPv4_RX_SOF(IPV4_LOOP_IPV4_PORT_NUMBER),
					In_EOF												=> IPv4_RX_EOF(IPV4_LOOP_IPV4_PORT_NUMBER),
					In_Ack												=> IPV4_LOOP_RX_Ack,
					In_Meta_rst										=> IPV4_LOOP_RX_Meta_rst,
					In_Meta_SrcIPv4Address_nxt		=> IPV4_LOOP_RX_Meta_SrcIPv4Address_nxt,
					In_Meta_SrcIPv4Address_Data		=> IPv4_RX_Meta_SrcIPv4Address_Data(IPV4_LOOP_IPV4_PORT_NUMBER),
					In_Meta_DestIPv4Address_nxt		=> IPV4_LOOP_RX_Meta_DestIPv4Address_nxt,
					In_Meta_DestIPv4Address_Data	=> IPv4_RX_Meta_DestIPv4Address_Data(IPV4_LOOP_IPV4_PORT_NUMBER),
					In_Meta_Length								=> IPv4_RX_Meta_Length(IPV4_LOOP_IPV4_PORT_NUMBER),

					Out_Valid											=> IPV4_LOOP_TX_Valid,
					Out_Data											=> IPV4_LOOP_TX_Data,
					Out_SOF												=> IPV4_LOOP_TX_SOF,
					Out_EOF												=> IPV4_LOOP_TX_EOF,
					Out_Ack												=> IPv4_TX_Ack	(IPV4_LOOP_IPV4_PORT_NUMBER),
					Out_Meta_rst									=> IPv4_TX_Meta_rst(IPV4_LOOP_IPV4_PORT_NUMBER),
					Out_Meta_SrcIPv4Address_nxt		=> IPv4_TX_Meta_SrcIPv4Address_nxt(IPV4_LOOP_IPV4_PORT_NUMBER),
					Out_Meta_SrcIPv4Address_Data	=> IPV4_LOOP_TX_Meta_SrcIPv4Address_Data,
					Out_Meta_DestIPv4Address_nxt	=> IPv4_TX_Meta_DestIPv4Address_nxt(IPV4_LOOP_IPV4_PORT_NUMBER),
					Out_Meta_DestIPv4Address_Data	=> IPV4_LOOP_TX_Meta_DestIPv4Address_Data,
					Out_Meta_Length								=> IPV4_LOOP_TX_Meta_Length
				);
		END GENERATE;


		ICMPv4 : ENTITY PoC.icmpv4_Wrapper
			GENERIC MAP (
				DEBUG															=> DEBUG,
				SOURCE_IPV4ADDRESS								=> IP_ADDRESS
			)
			PORT MAP (
				Clock															=> Ethernet_Clock,
				Reset															=> Ethernet_Reset,

				Command														=> ICMPv4_Command,
				Status														=> ICMPv4_Status,
				Error															=> ICMPv4_Error,

				IP_TX_Valid												=> ICMPv4_TX_Valid,
				IP_TX_Data												=> ICMPv4_TX_Data,
				IP_TX_SOF													=> ICMPv4_TX_SOF,
				IP_TX_EOF													=> ICMPv4_TX_EOF,
				IP_TX_Ack													=> IPv4_TX_Ack	(ICMPV4_IPV4_PORT_NUMBER),
				IP_TX_Meta_rst										=> IPv4_TX_Meta_rst(ICMPV4_IPV4_PORT_NUMBER),
				IP_TX_Meta_SrcIPv4Address_nxt			=> IPv4_TX_Meta_SrcIPv4Address_nxt(ICMPV4_IPV4_PORT_NUMBER),
				IP_TX_Meta_SrcIPv4Address_Data		=> ICMPv4_TX_Meta_SrcIPv4Address_Data,
				IP_TX_Meta_DestIPv4Address_nxt		=> IPv4_TX_Meta_DestIPv4Address_nxt(ICMPV4_IPV4_PORT_NUMBER),
				IP_TX_Meta_DestIPv4Address_Data		=> ICMPv4_TX_Meta_DestIPv4Address_Data,
				IP_TX_Meta_Length									=> ICMPv4_TX_Meta_Length,

				IP_RX_Valid												=> IPv4_RX_Valid(ICMPV4_IPV4_PORT_NUMBER),
				IP_RX_Data												=> IPv4_RX_Data(ICMPV4_IPV4_PORT_NUMBER),
				IP_RX_SOF													=> IPv4_RX_SOF(ICMPV4_IPV4_PORT_NUMBER),
				IP_RX_EOF													=> IPv4_RX_EOF(ICMPV4_IPV4_PORT_NUMBER),
				IP_RX_Ack													=> ICMPv4_RX_Ack,
				IP_RX_Meta_rst										=> ICMPv4_RX_Meta_rst,
				IP_RX_Meta_SrcMACAddress_nxt			=> ICMPv4_RX_Meta_SrcMACAddress_nxt,
				IP_RX_Meta_SrcMACAddress_Data			=> IPv4_RX_Meta_SrcMACAddress_Data(ICMPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_DestMACAddress_nxt			=> ICMPv4_RX_Meta_DestMACAddress_nxt,
				IP_RX_Meta_DestMACAddress_Data		=> IPv4_RX_Meta_DestMACAddress_Data(ICMPV4_IPV4_PORT_NUMBER),
--				IP_RX_Meta_EthType								=> IPv4_RX_Meta_EthType(ICMPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_SrcIPv4Address_nxt			=> ICMPv4_RX_Meta_SrcIPv4Address_nxt,
				IP_RX_Meta_SrcIPv4Address_Data		=> IPv4_RX_Meta_SrcIPv4Address_Data(ICMPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_DestIPv4Address_nxt		=> ICMPv4_RX_Meta_DestIPv4Address_nxt,
				IP_RX_Meta_DestIPv4Address_Data		=> IPv4_RX_Meta_DestIPv4Address_Data(ICMPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_Length									=> IPv4_RX_Meta_Length(ICMPV4_IPV4_PORT_NUMBER),
--				IP_RX_Meta_Protocol								=> IPv4_RX_Meta_Protocol(ICMPV4_IPV4_PORT_NUMBER),

				IPv4Address_rst										=> OPEN,	--ICMPv4_IPv4Address_rst,
				IPv4Address_nxt										=> OPEN,	--ICMPv4_IPv4Address_nxt,
				IPv4Address_Data									=> x"00"	--EchoReqIPv4Seq_IPv4Address_Data
			);
	END BLOCK;

	blkUDPv4 : BLOCK
		SIGNAL blk_TX_Valid														: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Data														: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_SOF															: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_EOF															: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_rst												: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_SrcIPv4Address_Data				: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_DestIPv4Address_Data				: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_Length											: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_SrcPort										: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_DestPort										: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);

		SIGNAL blk_RX_Ack															: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_rst												: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcMACAddress_nxt					: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestMACAddress_nxt					: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcIPv4Address_nxt					: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestIPv4Address_nxt				: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);

	BEGIN
		UDP : ENTITY PoC.udp_Wrapper
			GENERIC MAP (
				IP_VERSION												=> 4,
				PORTPAIRS													=> UDPV4_PORTPAIRS
			)
			PORT MAP (
				Clock															=> Ethernet_Clock,
				Reset															=> Ethernet_Reset,

				IP_TX_Valid												=> UDPv4_TX_Valid,
				IP_TX_Data												=> UDPv4_TX_Data,
				IP_TX_SOF													=> UDPv4_TX_SOF,
				IP_TX_EOF													=> UDPv4_TX_EOF,
				IP_TX_Ack													=> IPv4_TX_Ack	(UDPV4_IPV4_PORT_NUMBER),
				IP_TX_Meta_rst										=> IPv4_TX_Meta_rst(UDPV4_IPV4_PORT_NUMBER),
				IP_TX_Meta_SrcIPAddress_nxt				=> IPv4_TX_Meta_SrcIPv4Address_nxt(UDPV4_IPV4_PORT_NUMBER),
				IP_TX_Meta_SrcIPAddress_Data			=> UDPv4_TX_Meta_SrcIPv4Address_Data,
				IP_TX_Meta_DestIPAddress_nxt			=> IPv4_TX_Meta_DestIPv4Address_nxt(UDPV4_IPV4_PORT_NUMBER),
				IP_TX_Meta_DestIPAddress_Data			=> UDPv4_TX_Meta_DestIPv4Address_Data,
				IP_TX_Meta_Length									=> UDPv4_TX_Meta_Length,

				IP_RX_Valid												=> IPv4_RX_Valid(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_Data												=> IPv4_RX_Data(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_SOF													=> IPv4_RX_SOF(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_EOF													=> IPv4_RX_EOF(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_Ack													=> UDPv4_RX_Ack,
				IP_RX_Meta_rst										=> UDPv4_RX_Meta_rst,
				IP_RX_Meta_SrcMACAddress_nxt			=> UDPv4_RX_Meta_SrcMACAddress_nxt,
				IP_RX_Meta_SrcMACAddress_Data			=> IPv4_RX_Meta_SrcMACAddress_Data(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_DestMACAddress_nxt			=> UDPv4_RX_Meta_DestMACAddress_nxt,
				IP_RX_Meta_DestMACAddress_Data		=> IPv4_RX_Meta_DestMACAddress_Data(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_EthType								=> IPv4_RX_Meta_EthType(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_SrcIPAddress_nxt				=> UDPv4_RX_Meta_SrcIPv4Address_nxt,
				IP_RX_Meta_SrcIPAddress_Data			=> IPv4_RX_Meta_SrcIPv4Address_Data(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_DestIPAddress_nxt			=> UDPv4_RX_Meta_DestIPv4Address_nxt,
				IP_RX_Meta_DestIPAddress_Data			=> IPv4_RX_Meta_DestIPv4Address_Data(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_Length									=> IPv4_RX_Meta_Length(UDPV4_IPV4_PORT_NUMBER),
				IP_RX_Meta_Protocol								=> IPv4_RX_Meta_Protocol(UDPV4_IPV4_PORT_NUMBER),

				TX_Valid													=> blk_TX_Valid,
				TX_Data														=> blk_TX_Data,
				TX_SOF														=> blk_TX_SOF,
				TX_EOF														=> blk_TX_EOF,
				TX_Ack														=> UDPv4_TX_Ack,
				TX_Meta_rst												=> UDPv4_TX_Meta_rst,
				TX_Meta_SrcIPAddress_nxt					=> UDPv4_TX_Meta_SrcIPv4Address_nxt,
				TX_Meta_SrcIPAddress_Data					=> blk_TX_Meta_SrcIPv4Address_Data,
				TX_Meta_DestIPAddress_nxt					=> UDPv4_TX_Meta_DestIPv4Address_nxt,
				TX_Meta_DestIPAddress_Data				=> blk_TX_Meta_DestIPv4Address_Data,
				TX_Meta_Length										=> blk_TX_Meta_Length,
				TX_Meta_SrcPort										=> blk_TX_Meta_SrcPort,
				TX_Meta_DestPort									=> blk_TX_Meta_DestPort,

				RX_Valid													=> UDPv4_RX_Valid,
				RX_Data														=> UDPv4_RX_Data,
				RX_SOF														=> UDPv4_RX_SOF,
				RX_EOF														=> UDPv4_RX_EOF,
				RX_Ack														=> blk_RX_Ack,
				RX_Meta_rst												=> blk_RX_Meta_rst,
				RX_Meta_SrcMACAddress_nxt					=> blk_RX_Meta_SrcMACAddress_nxt,
				RX_Meta_SrcMACAddress_Data				=> UDPv4_RX_Meta_SrcMACAddress_Data,
				RX_Meta_DestMACAddress_nxt				=> blk_RX_Meta_DestMACAddress_nxt,
				RX_Meta_DestMACAddress_Data				=> UDPv4_RX_Meta_DestMACAddress_Data,
				RX_Meta_EthType										=> UDPv4_RX_Meta_EthType,
				RX_Meta_SrcIPAddress_nxt					=> blk_RX_Meta_SrcIPv4Address_nxt,
				RX_Meta_SrcIPAddress_Data					=> UDPv4_RX_Meta_SrcIPv4Address_Data,
				RX_Meta_DestIPAddress_nxt					=> blk_RX_Meta_DestIPv4Address_nxt,
				RX_Meta_DestIPAddress_Data				=> UDPv4_RX_Meta_DestIPv4Address_Data,
				RX_Meta_Length										=> UDPv4_RX_Meta_Length,
				RX_Meta_Protocol									=> UDPv4_RX_Meta_Protocol,
				RX_Meta_SrcPort										=> UDPv4_RX_Meta_SrcPort,
				RX_Meta_DestPort									=> UDPv4_RX_Meta_DestPort
			);

			-- UDPv4 Port 0..n - passthrough to port map
			blk_TX_Valid(UDP_PORTS'length - 1 DOWNTO 0)											<= TX_Valid;
			blk_TX_Data(UDP_PORTS'length - 1 DOWNTO 0)											<= TX_Data;
			blk_TX_SOF(UDP_PORTS'length - 1 DOWNTO 0)												<= TX_SOF;
			blk_TX_EOF(UDP_PORTS'length - 1 DOWNTO 0)												<= TX_EOF;
			blk_TX_Meta_SrcIPv4Address_Data(UDP_PORTS'length - 1 DOWNTO 0)	<= TX_Meta_SrcIPv4Address_Data;
			blk_TX_Meta_DestIPv4Address_Data(UDP_PORTS'length - 1 DOWNTO 0)	<= TX_Meta_DestIPv4Address_Data;
	--		blk_TX_Meta_TrafficClass(UDP_PORTS'length - 1 DOWNTO 0)					<= (OTHERS => '0');
	--		blk_TX_Meta_FlowLabel(UDP_PORTS'length - 1 DOWNTO 0)						<= (OTHERS => '0');
			blk_TX_Meta_Length(UDP_PORTS'length - 1 DOWNTO 0)								<= TX_Meta_Length;
			blk_TX_Meta_SrcPort(UDP_PORTS'length - 1 DOWNTO 0)							<= TX_Meta_SrcPort;
			blk_TX_Meta_DestPort(UDP_PORTS'length - 1 DOWNTO 0)							<= TX_Meta_DestPort;

			blk_RX_Ack	(UDP_PORTS'length - 1 DOWNTO 0)											<= RX_Ack;
			blk_RX_Meta_rst(UDP_PORTS'length - 1 DOWNTO 0)									<= RX_Meta_rst;
			blk_RX_Meta_SrcMACAddress_nxt(UDP_PORTS'length - 1 DOWNTO 0)		<= RX_Meta_SrcMACAddress_nxt;
			blk_RX_Meta_DestMACAddress_nxt(UDP_PORTS'length - 1 DOWNTO 0)		<= RX_Meta_DestMACAddress_nxt;
			blk_RX_Meta_SrcIPv4Address_nxt(UDP_PORTS'length - 1 DOWNTO 0)		<= RX_Meta_SrcIPv4Address_nxt;
			blk_RX_Meta_DestIPv4Address_nxt(UDP_PORTS'length - 1 DOWNTO 0)	<= RX_Meta_DestIPv4Address_nxt;

--		genLB0 : IF (UDP_ENABLE_LOOPBACK = FALSE) GENERATE
--
--		END GENERATE;

		genLB1 : IF (UDP_ENABLE_LOOPBACK = TRUE) GENERATE
			SIGNAL UDP_LOOP_TX_Valid											: STD_LOGIC;
			SIGNAL UDP_LOOP_TX_Data												: T_SLV_8;
			SIGNAL UDP_LOOP_TX_SOF												: STD_LOGIC;
			SIGNAL UDP_LOOP_TX_EOF												: STD_LOGIC;
			SIGNAL UDP_LOOP_TX_Meta_SrcIPv4Address_Data		: T_SLV_8;
			SIGNAL UDP_LOOP_TX_Meta_DestIPv4Address_Data	: T_SLV_8;
			SIGNAL UDP_LOOP_TX_Meta_Length								: T_SLV_16;
			SIGNAL UDP_LOOP_TX_Meta_SrcPort								: T_SLV_16;
			SIGNAL UDP_LOOP_TX_Meta_DestPort							: T_SLV_16;

			SIGNAL UDP_LOOP_TX_Meta_rst										: STD_LOGIC;
			SIGNAL UDP_LOOP_TX_Meta_SrcIPv4Address_nxt		: STD_LOGIC;
			SIGNAL UDP_LOOP_TX_Meta_DestIPv4Address_nxt		: STD_LOGIC;

			SIGNAL UDP_LOOP_RX_Ack												: STD_LOGIC;
			SIGNAL UDP_LOOP_RX_Meta_rst										: STD_LOGIC;
			SIGNAL UDP_LOOP_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
			SIGNAL UDP_LOOP_RX_Meta_DestMACAddress_nxt		: STD_LOGIC;
			SIGNAL UDP_LOOP_RX_Meta_SrcIPv4Address_nxt		: STD_LOGIC;
			SIGNAL UDP_LOOP_RX_Meta_DestIPv4Address_nxt		: STD_LOGIC;
		BEGIN
			-- UDPv4 Port n+1 - LoopBack
			blk_TX_Valid(UDP_LOOP_UDPV4_PORT_NUMBER)												<= UDP_LOOP_TX_Valid;
			blk_TX_Data(UDP_LOOP_UDPV4_PORT_NUMBER)													<= UDP_LOOP_TX_Data;
			blk_TX_SOF(UDP_LOOP_UDPV4_PORT_NUMBER)													<= UDP_LOOP_TX_SOF;
			blk_TX_EOF(UDP_LOOP_UDPV4_PORT_NUMBER)													<= UDP_LOOP_TX_EOF;
			blk_TX_Meta_SrcIPv4Address_Data(UDP_LOOP_UDPV4_PORT_NUMBER)			<= UDP_LOOP_TX_Meta_SrcIPv4Address_Data;
			blk_TX_Meta_DestIPv4Address_Data(UDP_LOOP_UDPV4_PORT_NUMBER)		<= UDP_LOOP_TX_Meta_DestIPv4Address_Data;
	--		blk_TX_Meta_TrafficClass(UDP_LOOP_UDPV4_PORT_NUMBER)						<= (OTHERS => '0');
	--		blk_TX_Meta_FlowLabel(UDP_LOOP_UDPV4_PORT_NUMBER)								<= (OTHERS => '0');
			blk_TX_Meta_Length(UDP_LOOP_UDPV4_PORT_NUMBER)									<= UDP_LOOP_TX_Meta_Length;
			blk_TX_Meta_SrcPort(UDP_LOOP_UDPV4_PORT_NUMBER)									<= UDP_LOOP_TX_Meta_SrcPort;
			blk_TX_Meta_DestPort(UDP_LOOP_UDPV4_PORT_NUMBER)								<= UDP_LOOP_TX_Meta_DestPort;

			blk_RX_Ack	(UDP_LOOP_UDPV4_PORT_NUMBER)												<= UDP_LOOP_RX_Ack;
			blk_RX_Meta_rst(UDP_LOOP_UDPV4_PORT_NUMBER)											<= UDP_LOOP_RX_Meta_rst;
			blk_RX_Meta_SrcMACAddress_nxt(UDP_LOOP_UDPV4_PORT_NUMBER)				<= '0';
			blk_RX_Meta_DestMACAddress_nxt(UDP_LOOP_UDPV4_PORT_NUMBER)			<= '0';
			blk_RX_Meta_SrcIPv4Address_nxt(UDP_LOOP_UDPV4_PORT_NUMBER)			<= UDP_LOOP_RX_Meta_SrcIPv4Address_nxt;
			blk_RX_Meta_DestIPv4Address_nxt(UDP_LOOP_UDPV4_PORT_NUMBER)			<= UDP_LOOP_RX_Meta_DestIPv4Address_nxt;

			UDP_LOOP : ENTITY PoC.udp_FrameLoopback
				GENERIC MAP (
					IP_VERSION										=> 4,
					MAX_FRAMES										=> 4
				)
				PORT MAP (
					Clock													=> Ethernet_Clock,
					Reset													=> Ethernet_Reset,

					In_Valid											=> UDPv4_RX_Valid(UDP_LOOP_UDPV4_PORT_NUMBER),
					In_Data												=> UDPv4_RX_Data(UDP_LOOP_UDPV4_PORT_NUMBER),
					In_SOF												=> UDPv4_RX_SOF(UDP_LOOP_UDPV4_PORT_NUMBER),
					In_EOF												=> UDPv4_RX_EOF(UDP_LOOP_UDPV4_PORT_NUMBER),
					In_Ack												=> UDP_LOOP_RX_Ack,
					In_Meta_rst										=> UDP_LOOP_RX_Meta_rst,
					In_Meta_SrcIPAddress_nxt			=> UDP_LOOP_RX_Meta_SrcIPv4Address_nxt,
					In_Meta_SrcIPAddress_Data			=> UDPv4_RX_Meta_SrcIPv4Address_Data(UDP_LOOP_UDPV4_PORT_NUMBER),
					In_Meta_DestIPAddress_nxt			=> UDP_LOOP_RX_Meta_DestIPv4Address_nxt,
					In_Meta_DestIPAddress_Data		=> UDPv4_RX_Meta_DestIPv4Address_Data(UDP_LOOP_UDPV4_PORT_NUMBER),
	--				In_Meta_Length								=> UDPv4_RX_Meta_Length(UDP_LOOP_UDPV4_PORT_NUMBER),
					In_Meta_SrcPort								=> UDPv4_RX_Meta_SrcPort(UDP_LOOP_UDPV4_PORT_NUMBER),
					In_Meta_DestPort							=> UDPv4_RX_Meta_DestPort(UDP_LOOP_UDPV4_PORT_NUMBER),

					Out_Valid											=> UDP_LOOP_TX_Valid,
					Out_Data											=> UDP_LOOP_TX_Data,
					Out_SOF												=> UDP_LOOP_TX_SOF,
					Out_EOF												=> UDP_LOOP_TX_EOF,
					Out_Ack												=> UDPv4_TX_Ack	(UDP_LOOP_UDPV4_PORT_NUMBER),
					Out_Meta_rst									=> UDPv4_TX_Meta_rst(UDP_LOOP_UDPV4_PORT_NUMBER),
					Out_Meta_SrcIPAddress_nxt			=> UDPv4_TX_Meta_SrcIPv4Address_nxt(UDP_LOOP_UDPV4_PORT_NUMBER),
					Out_Meta_SrcIPAddress_Data		=> UDP_LOOP_TX_Meta_SrcIPv4Address_Data,
					Out_Meta_DestIPAddress_nxt		=> UDPv4_TX_Meta_DestIPv4Address_nxt(UDP_LOOP_UDPV4_PORT_NUMBER),
					Out_Meta_DestIPAddress_Data		=> UDP_LOOP_TX_Meta_DestIPv4Address_Data,
	--				Out_Meta_Length								=> UDP_LOOP_TX_Meta_Length,
					Out_Meta_SrcPort							=> UDP_LOOP_TX_Meta_SrcPort,
					Out_Meta_DestPort							=> UDP_LOOP_TX_Meta_DestPort
				);
		END GENERATE;
	END BLOCK;

	genCSP : IF (DEBUG = TRUE) GENERATE
		SIGNAL Eth_Status_d										: T_NET_ETH_STATUS;

		SIGNAL CSP_Ethernet_Clock							: STD_LOGIC;
		SIGNAL CSP_NewConnection							: STD_LOGIC;

		ATTRIBUTE KEEP OF CSP_Ethernet_Clock	: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_NewConnection		: SIGNAL IS TRUE;

	BEGIN
		CSP_Ethernet_Clock	<= Ethernet_Clock;

		Eth_Status_d				<= Eth_Status WHEN rising_edge(Ethernet_Clock);
		CSP_NewConnection		<= to_sl((Eth_Status_d /= NET_ETH_STATUS_CONNECTED) AND (Eth_Status = NET_ETH_STATUS_CONNECTED));

	END GENERATE;
END ARCHITECTURE;
