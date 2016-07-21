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
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.net.all;


entity stack_UDPv4 is
	generic (
		DEBUG															: boolean															:= FALSE;																																									--
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

		MAC_ENABLE_LOOPBACK								: boolean															:= FALSE;
		IPV4_ENABLE_LOOPBACK							: boolean															:= FALSE;
		UDP_ENABLE_LOOPBACK								: boolean															:= FALSE;
		ICMP_ENABLE_ECHO									: boolean															:= FALSE;
		PING															: boolean															:= FALSE
	);
	port (
		Ethernet_Clock										: in		std_logic;
		Ethernet_Reset										: in		std_logic;

		Ethernet_Command									: in		T_NET_ETH_COMMAND;
		Ethernet_Status										: out		T_NET_ETH_STATUS;

		PHY_Interface											:	inout	T_NET_ETH_PHY_INTERFACES;

		-- UDP ports
		TX_Valid													: in	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		TX_Data														: in	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
		TX_SOF														: in	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		TX_EOF														: in	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		TX_Ack														: out	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		TX_Meta_rst												: out	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		TX_Meta_SrcIPv4Address_nxt				: out	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		TX_Meta_SrcIPv4Address_Data				: in	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
		TX_Meta_DestIPv4Address_nxt				: out	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		TX_Meta_DestIPv4Address_Data			: in	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
		TX_Meta_SrcPort										: in	T_SLVV_16(UDP_PORTS'length - 1 downto 0);
		TX_Meta_DestPort									: in	T_SLVV_16(UDP_PORTS'length - 1 downto 0);
		TX_Meta_Length										: in	T_SLVV_16(UDP_PORTS'length - 1 downto 0);

		RX_Valid													: out	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		RX_Data														: out	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
		RX_SOF														: out	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		RX_EOF														: out	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		RX_Ack														: in	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		RX_Meta_rst												: in	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		RX_Meta_SrcMACAddress_nxt					: in	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		RX_Meta_SrcMACAddress_Data				: out	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
		RX_Meta_DestMACAddress_nxt				: in	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		RX_Meta_DestMACAddress_Data				: out	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
		RX_Meta_EthType										: out	T_SLVV_16(UDP_PORTS'length - 1 downto 0);
		RX_Meta_SrcIPv4Address_nxt				: in	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		RX_Meta_SrcIPv4Address_Data				: out	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
		RX_Meta_DestIPv4Address_nxt				: in	std_logic_vector(UDP_PORTS'length - 1 downto 0);
		RX_Meta_DestIPv4Address_Data			: out	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
--		RX_Meta_TrafficClass							: out	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
--		RX_Meta_FlowLabel									: out	T_SLVV_24(UDP_PORTS'length - 1 downto 0);
		RX_Meta_Length										: out	T_SLVV_16(UDP_PORTS'length - 1 downto 0);
		RX_Meta_Protocol									: out	T_SLVV_8(UDP_PORTS'length - 1 downto 0);
		RX_Meta_SrcPort										: out	T_SLVV_16(UDP_PORTS'length - 1 downto 0);
		RX_Meta_DestPort									: out	T_SLVV_16(UDP_PORTS'length - 1 downto 0)
	);
end entity;


architecture rtl of stack_UDPv4 is
	attribute KEEP											: boolean;
	attribute KEEP_HIERARCHY						: string;

	attribute KEEP of Ethernet_Clock		: signal is TRUE;

	function if_append(cond : boolean; vector : T_NET_IPV4_PROTOCOL_VECTOR; item : T_NET_IPV4_PROTOCOL) return T_NET_IPV4_PROTOCOL_VECTOR is
	begin
		if cond then
			return item & vector;
		else
			return vector;
		end if;
	end function;

	function if_append(cond : boolean; vector : T_NET_UDP_PORTPAIR_VECTOR; item : T_NET_UDP_PORTPAIR) return T_NET_UDP_PORTPAIR_VECTOR is
	begin
		if cond then
			return item & vector;
		else
			return vector;
		end if;
	end function;

	function get_MAC_Configuration return T_NET_MAC_CONFIGURATION_VECTOR is
	begin
		if not MAC_ENABLE_LOOPBACK then
			return (
				-- network interface 0 - MAC_ADDRESS
				0 => (
					Interface => 		(Address => MAC_ADDRESS,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(others =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						1 =>					C_NET_MAC_ETHERNETTYPE_IPV4,
						others =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
				1 => (
					Interface => 		(Address => MAC_ADDRESS,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(others =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						1 =>					C_NET_MAC_ETHERNETTYPE_IPV4,
						others =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
				2 => (
					Interface => 		(Address => C_NET_MAC_ADDRESS_BROADCAST,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(others =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						others =>			C_NET_MAC_ETHERNETTYPE_EMPTY))
			);
		else
			return (
				-- network interface 0 - MAC_ADDRESS
				0 => (
					Interface => 		(Address => MAC_ADDRESS,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(others =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						1 =>					C_NET_MAC_ETHERNETTYPE_IPV4,
						2 =>					C_NET_MAC_ETHERNETTYPE_LOOPBACK,
						others =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
				1 => (
					Interface => 		(Address => MAC_ADDRESS,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(others =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						1 =>					C_NET_MAC_ETHERNETTYPE_IPV4,
						2 =>					C_NET_MAC_ETHERNETTYPE_LOOPBACK,
						others =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
				2 => (
					Interface => 		(Address => C_NET_MAC_ADDRESS_BROADCAST,	Mask => C_NET_MAC_MASK_DEFAULT),
					SourceFilter =>	(others =>	C_NET_MAC_SOURCEFILTER_NONE),			-- accept MAC packets from everywhere
					TypeSwitch =>		(
						0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
						others =>			C_NET_MAC_ETHERNETTYPE_EMPTY))
			);
		end if;
	end function;

	-- define ethernet configuration
	constant MAC_CONFIGURATION			: T_NET_MAC_CONFIGURATION_VECTOR	:= get_MAC_Configuration;
	constant ETHERNET_PORTS					: positive												:= getPortCount(MAC_CONFIGURATION);

	-- define ethernet port numbers for unicast addresses
	-- --------------------------------------------------------------------------
	-- eth0
	constant ARP_MAC_UC_PORT_NUMBER		: natural					:= 0;
	constant IPV4_MAC_PORT_NUMBER			: natural					:= 1;
	constant MAC_LOOP_MAC_PORT_NUMBER		: natural					:= 2;

	-- define ethernet port numbers for multicast address
	-- --------------------------------------------------------------------------
	-- eth1 - broadcast
	constant ARP_MAC_BC_PORT_NUMBER		: natural					:= ETHERNET_PORTS - 1;	-- ite(NOT MAC_ENABLE_LOOPBACK, 2, 3);


	-- ARP configuration
	-- ==========================================================================================================================================================
--	constant INITIAL_IPV4ADDRESSES_ETH0									: T_NET_IPV4_ADDRESS_VECTOR		:= (
--		0 => to_net_ipv4_address(string'("192.168.10.10")),																				-- 192.168.10.10
--		1 => to_net_ipv4_address(string'("192.168.20.10")),																				-- 192.168.20.10
--		2 => to_net_ipv4_address(string'("192.168.90.10"))																				-- 192.168.90.10
--	);
--
--	constant INITIAL_ARPCACHE_CONTENT_ETH0							: T_NET_ARP_ARPCACHE_VECTOR		:= (
--		0 => (Tag => to_net_ipv4_address("192.168.10.1"),		MAC => to_net_mac_address("50:E5:49:52:F1:C8")),
--		1 => (Tag => to_net_ipv4_address("192.168.20.1"),		MAC => to_net_mac_address("64:70:02:01:DB:45")),
--		2 => (Tag => to_net_ipv4_address("192.168.30.1"),		MAC => to_net_mac_address("1A:1B:1C:1D:1E:1F")),
--		3 => (Tag => to_net_ipv4_address("192.168.40.1"),		MAC => to_net_mac_address("2A:2B:2C:2D:2E:2F"))
--	);

	-- IPv4 configuration
	-- ==========================================================================================================================================================
	constant ICMPV4_IPV4_PORT_NUMBER				: natural				:= 0;
	constant UDPV4_IPV4_PORT_NUMBER					: natural				:= 1;

	constant IPV4_PACKET_TYPES							: T_NET_IPV4_PROTOCOL_VECTOR		:= if_append(IPV4_ENABLE_LOOPBACK, (
		ICMPV4_IPV4_PORT_NUMBER =>	C_NET_IP_PROTOCOL_ICMP,
		UDPV4_IPV4_PORT_NUMBER =>		C_NET_IP_PROTOCOL_UDP),
		C_NET_IP_PROTOCOL_LOOPBACK
	);

	constant IPV4_PORTS											: positive			:= IPV4_PACKET_TYPES'length;
	constant IPV4_LOOP_IPV4_PORT_NUMBER			: natural				:= IPV4_PORTS - 1;


	-- UDPv4 configuration
	-- ==========================================================================================================================================================
	constant UDPV4_PORTPAIRS								: T_NET_UDP_PORTPAIR_VECTOR			:= if_append(UDP_ENABLE_LOOPBACK, UDP_PORTS, (C_NET_TCP_PORTNUMBER_LOOPBACK, C_NET_TCP_PORTNUMBER_LOOPBACK));

	constant UDPV4_PORTS										: positive		:= UDPV4_PORTPAIRS'length;
	constant UDP_LOOP_UDPV4_PORT_NUMBER			: natural			:= UDPV4_PORTS - 1;


	-- Ethernet layer signals
	signal Eth_Command											: T_NET_ETH_COMMAND;
	signal Eth_Status												: T_NET_ETH_STATUS;
	signal Eth_Error												: T_NET_ETH_ERROR;

	signal Eth_TX_Ack												: std_logic;																										--attribute KEEP OF Eth_TX_Ack			: signal IS TRUE;

	signal Eth_RX_Valid											: std_logic;																										--attribute KEEP OF Eth_RX_Valid		: signal IS TRUE;
	signal Eth_RX_Data											: T_SLV_8;																											--attribute KEEP OF Eth_RX_Data			: signal IS TRUE;
	signal Eth_RX_SOF												: std_logic;																										--attribute KEEP OF Eth_RX_SOF			: signal IS TRUE;
	signal Eth_RX_EOF												: std_logic;																										--attribute KEEP OF Eth_RX_EOF			: signal IS TRUE;

	-- Ethernet MAC layer signals
	signal MAC_TX_Valid											: std_logic;																										--attribute KEEP OF MAC_TX_Valid		: signal IS TRUE;
	signal MAC_TX_Data											: T_SLV_8;																											--attribute KEEP OF MAC_TX_Data			: signal IS TRUE;
	signal MAC_TX_SOF												: std_logic;																										--attribute KEEP OF MAC_TX_SOF			: signal IS TRUE;
	signal MAC_TX_EOF												: std_logic;																										--attribute KEEP OF MAC_TX_EOF			: signal IS TRUE;

	signal MAC_RX_Ack												: std_logic;																										--attribute KEEP OF MAC_RX_Ack			: signal IS TRUE;

	signal MAC_TX_Ack												: std_logic_vector(ETHERNET_PORTS - 1 downto 0);								--attribute KEEP OF MAC_TX_Ack											: signal IS TRUE;
	signal MAC_TX_Meta_rst									: std_logic_vector(ETHERNET_PORTS - 1 downto 0);								--attribute KEEP OF MAC_TX_Meta_rst									: signal IS TRUE;
	signal MAC_TX_Meta_DestMACAddress_nxt		: std_logic_vector(ETHERNET_PORTS - 1 downto 0);								--attribute KEEP OF MAC_TX_Meta_DestMACAddress_nxt	: signal IS TRUE;

	signal MAC_RX_Valid											: std_logic_vector(ETHERNET_PORTS - 1 downto 0);								--attribute KEEP OF MAC_RX_Valid										: signal IS TRUE;
	signal MAC_RX_Data											: T_SLVV_8(ETHERNET_PORTS - 1 downto 0);												--attribute KEEP OF MAC_RX_Data											: signal IS TRUE;
	signal MAC_RX_SOF												: std_logic_vector(ETHERNET_PORTS - 1 downto 0);								--attribute KEEP OF MAC_RX_SOF											: signal IS TRUE;
	signal MAC_RX_EOF												: std_logic_vector(ETHERNET_PORTS - 1 downto 0);								--attribute KEEP OF MAC_RX_EOF											: signal IS TRUE;
	signal MAC_RX_Meta_DestMACAddress_Data	: T_SLVV_8(ETHERNET_PORTS - 1 downto 0);												--attribute KEEP OF MAC_RX_Meta_DestMACAddress_Data	: signal IS TRUE;
	signal MAC_RX_Meta_SrcMACAddress_Data		: T_SLVV_8(ETHERNET_PORTS - 1 downto 0);												--attribute KEEP OF MAC_RX_Meta_SrcMACAddress_Data	: signal IS TRUE;
	signal MAC_RX_Meta_EthType							: T_NET_MAC_ETHERNETTYPE_VECTOR(ETHERNET_PORTS - 1 downto 0);		--attribute KEEP OF MAC_RX_Meta_EthType							: signal IS TRUE;

	-- Address Resolution Protocol layer signals
	signal ARP_UC_TX_Valid												: std_logic;
	signal ARP_UC_TX_Data													: T_SLV_8;
	signal ARP_UC_TX_SOF													: std_logic;
	signal ARP_UC_TX_EOF													: std_logic;
	signal ARP_UC_TX_Meta_DestMACAddress_Data			: T_SLV_8;

	signal ARP_UC_RX_Ack													: std_logic;
	signal ARP_UC_RX_Meta_rst											: std_logic;
	signal ARP_UC_RX_Meta_SrcMACAddress_nxt				: std_logic;
	signal ARP_UC_RX_Meta_DestMACAddress_nxt			: std_logic;

	signal ARP_IPCache_IPv4Address_rst						: std_logic;
	signal ARP_IPCache_IPv4Address_nxt						: std_logic;
	signal ARP_IPCache_Valid											: std_logic;
	signal ARP_IPCache_MACAddress_Data						: T_SLV_8;

	signal ARP_BC_RX_Ack													: std_logic;
	signal ARP_BC_RX_Meta_rst											: std_logic;
	signal ARP_BC_RX_Meta_SrcMACAddress_nxt				: std_logic;
	signal ARP_BC_RX_Meta_DestMACAddress_nxt			: std_logic;

	-- Internet Protocol Version 4 layer signals
	signal IPv4_TX_Valid													: std_logic;
	signal IPv4_TX_Data														: T_SLV_8;
	signal IPv4_TX_SOF														: std_logic;
	signal IPv4_TX_EOF														: std_logic;
	signal IPv4_TX_Meta_DestMACAddress_Data				: T_SLV_8;

	signal IPv4_RX_Ack														: std_logic;
	signal IPv4_RX_Meta_rst												: std_logic;
	signal IPv4_RX_Meta_SrcMACAddress_nxt					: std_logic;
	signal IPv4_RX_Meta_DestMACAddress_nxt				: std_logic;

	signal IPv4_ARP_Query													: std_logic;
	signal IPv4_ARP_IPv4Address_Data							: T_SLV_8;
	signal IPv4_ARP_MACAddress_rst								: std_logic;
	signal IPv4_ARP_MACAddress_nxt								: std_logic;

	signal IPv4_TX_Ack														: std_logic_vector(IPV4_PORTS - 1 downto 0);
	signal IPv4_TX_Meta_rst												: std_logic_vector(IPV4_PORTS - 1 downto 0);
	signal IPv4_TX_Meta_SrcIPv4Address_nxt				: std_logic_vector(IPV4_PORTS - 1 downto 0);
	signal IPv4_TX_Meta_DestIPv4Address_nxt				: std_logic_vector(IPV4_PORTS - 1 downto 0);

	signal IPv4_RX_Valid													: std_logic_vector(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_Data														: T_SLVV_8(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_SOF														: std_logic_vector(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_EOF														: std_logic_vector(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_Meta_SrcMACAddress_Data				: T_SLVV_8(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_Meta_DestMACAddress_Data				: T_SLVV_8(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_Meta_EthType										: T_SLVV_16(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_Meta_SrcIPv4Address_Data				: T_SLVV_8(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_Meta_DestIPv4Address_Data			: T_SLVV_8(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_Meta_Length										: T_SLVV_16(IPV4_PORTS - 1 downto 0);
	signal IPv4_RX_Meta_Protocol									: T_SLVV_8(IPV4_PORTS - 1 downto 0);

	signal UDPv4_TX_Valid													: std_logic;
	signal UDPv4_TX_Data													: T_SLV_8;
	signal UDPv4_TX_SOF														: std_logic;
	signal UDPv4_TX_EOF														: std_logic;
	signal UDPv4_TX_Meta_SrcIPv4Address_Data			: T_SLV_8;
	signal UDPv4_TX_Meta_DestIPv4Address_Data			: T_SLV_8;
	signal UDPv4_TX_Meta_Length										: T_SLV_16;

	signal UDPv4_RX_Ack														: std_logic;
	signal UDPv4_RX_Meta_rst											: std_logic;
	signal UDPv4_RX_Meta_SrcMACAddress_nxt				: std_logic;
	signal UDPv4_RX_Meta_DestMACAddress_nxt				: std_logic;
	signal UDPv4_RX_Meta_SrcIPv4Address_nxt				: std_logic;
	signal UDPv4_RX_Meta_DestIPv4Address_nxt			: std_logic;

	signal UDPv4_TX_Ack														: std_logic_vector(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_TX_Meta_rst											: std_logic_vector(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_TX_Meta_SrcIPv4Address_nxt				: std_logic_vector(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_TX_Meta_DestIPv4Address_nxt			: std_logic_vector(UDPV4_PORTS - 1 downto 0);

	signal UDPv4_RX_Valid													: std_logic_vector(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Data													: T_SLVV_8(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_SOF														: std_logic_vector(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_EOF														: std_logic_vector(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Meta_SrcMACAddress_Data				: T_SLVV_8(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Meta_DestMACAddress_Data			: T_SLVV_8(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Meta_EthType									: T_SLVV_16(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Meta_SrcIPv4Address_Data			: T_SLVV_8(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Meta_DestIPv4Address_Data			: T_SLVV_8(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Meta_Length										: T_SLVV_16(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Meta_Protocol									: T_SLVV_8(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Meta_SrcPort									: T_SLVV_16(UDPV4_PORTS - 1 downto 0);
	signal UDPv4_RX_Meta_DestPort									: T_SLVV_16(UDPV4_PORTS - 1 downto 0);

begin

	blkEth : block
		signal TX_Clock							: std_logic;
		signal RX_Clock							: std_logic;
		signal Eth_TX_Clock					: std_logic;
		signal Eth_RX_Clock					: std_logic;
		signal RS_TX_Clock					: std_logic;
		signal RS_RX_Clock					: std_logic;

	begin
		Eth_Command						<= Ethernet_Command;

		Ethernet_Status				<= Eth_Status;

		genGMIIClocking : if (ETHERNET_PHY_DATA_INTERFACE = NET_ETH_PHY_DATA_INTERFACE_GMII) generate
			TX_Clock						<= Ethernet_Clock;
			RX_Clock						<= Ethernet_Clock;
			Eth_TX_Clock				<= Ethernet_Clock;
			Eth_RX_Clock				<= PHY_Interface.GMII.RX_RefClock;
			RS_TX_Clock					<= Ethernet_Clock;
			RS_RX_Clock					<= PHY_Interface.GMII.RX_RefClock;
		end generate;
		genSGMIIClocking : if (ETHERNET_PHY_DATA_INTERFACE	= NET_ETH_PHY_DATA_INTERFACE_SGMII) generate
			TX_Clock						<= Ethernet_Clock;
			RX_Clock						<= Ethernet_Clock;
			Eth_TX_Clock				<= PHY_Interface.SGMII.SGMII_TXRefClock_Out;
			Eth_RX_Clock				<= PHY_Interface.SGMII.SGMII_RXRefClock_Out;
			RS_TX_Clock					<= PHY_Interface.SGMII.SGMII_TXRefClock_Out;
			RS_RX_Clock					<= PHY_Interface.SGMII.SGMII_RXRefClock_Out;
		end generate;

		Eth : entity PoC.Eth_Wrapper
			generic map (
				DEBUG											=> FALSE,	--DEBUG,
				CLOCKIN_FREQ							=> CLOCK_FREQ,
				ETHERNET_IPSTYLE					=> ETHERNET_IPSTYLE,
				RS_DATA_INTERFACE					=> ETHERNET_RS_DATA_INTERFACE,
				PHY_DEVICE								=> ETHERNET_PHY_DEVICE,
				PHY_DEVICE_ADDRESS				=> ETHERNET_PHY_DEVICE_ADDRESS,
				PHY_DATA_INTERFACE				=> ETHERNET_PHY_DATA_INTERFACE,
				PHY_MANAGEMENT_INTERFACE	=> ETHERNET_PHY_MANAGEMENT_INTERFACE
			)
			port map (
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
	end block;

	blkMAC : block
		attribute KEEP_HIERARCHY of MAC : label is "FALSE";

		signal blkMAC_TX_Valid										: std_logic_vector(ETHERNET_PORTS - 1 downto 0);
		signal blkMAC_TX_Data											: T_SLVV_8(ETHERNET_PORTS - 1 downto 0);
		signal blkMAC_TX_SOF											: std_logic_vector(ETHERNET_PORTS - 1 downto 0);
		signal blkMAC_TX_EOF											: std_logic_vector(ETHERNET_PORTS - 1 downto 0);
		signal blkMAC_TX_Meta_DestMACAddress_Data	: T_SLVV_8(ETHERNET_PORTS - 1 downto 0);

		signal blkMAC_RX_Ack											: std_logic_vector(ETHERNET_PORTS - 1 downto 0);
		signal blkMAC_RX_Meta_rst									: std_logic_vector(ETHERNET_PORTS - 1 downto 0);
		signal blkMAC_RX_Meta_DestMACAddress_nxt	: std_logic_vector(ETHERNET_PORTS - 1 downto 0);
		signal blkMAC_RX_Meta_SrcMACAddress_nxt		: std_logic_vector(ETHERNET_PORTS - 1 downto 0);

	begin
		MAC : entity PoC.mac_Wrapper
			generic map (
				DEBUG								=> DEBUG,
				MAC_CONFIG										=> MAC_CONFIGURATION
			)
			port map (
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

		genLB0 : if (MAC_ENABLE_LOOPBACK = FALSE) generate
			-- Ethernet Port 2 -> ARP Broadcast
			-- ========================================================================
			blkMAC_TX_Valid(ARP_MAC_BC_PORT_NUMBER)											<= '0';
			blkMAC_TX_Data(ARP_MAC_BC_PORT_NUMBER)											<= (others => '0');
			blkMAC_TX_SOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
			blkMAC_TX_EOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
			blkMAC_TX_Meta_DestMACAddress_Data(ARP_MAC_BC_PORT_NUMBER)	<= (others => '0');

			blkMAC_RX_Ack	(ARP_MAC_BC_PORT_NUMBER)											<= ARP_BC_RX_Ack;
			blkMAC_RX_Meta_rst(ARP_MAC_BC_PORT_NUMBER)									<= ARP_BC_RX_Meta_rst;
			blkMAC_RX_Meta_SrcMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_SrcMACAddress_nxt;
			blkMAC_RX_Meta_DestMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_DestMACAddress_nxt;
		end generate;

		genLB1 : if (MAC_ENABLE_LOOPBACK = TRUE) generate
			-- LoopBack layer signals
			signal MAC_LOOP_TX_Valid											: std_logic;
			signal MAC_LOOP_TX_Data												: T_SLV_8;
			signal MAC_LOOP_TX_SOF												: std_logic;
			signal MAC_LOOP_TX_EOF												: std_logic;
			signal MAC_LOOP_TX_Meta_DestMACAddress_Data		: T_SLV_8;
			signal MAC_LOOP_TX_Meta_SrcMACAddress_Data		: T_SLV_8;
			signal MAC_LOOP_TX_Meta_EthType								: T_NET_MAC_ETHERNETTYPE;

			signal MAC_LOOP_RX_Ack												: std_logic;
			signal MAC_LOOP_RX_Meta_rst										: std_logic;
			signal MAC_LOOP_RX_Meta_DestMACAddress_nxt		: std_logic;
			signal MAC_LOOP_RX_Meta_SrcMACAddress_nxt			: std_logic;
		begin
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
			blkMAC_TX_Data(ARP_MAC_BC_PORT_NUMBER)											<= (others => '0');
			blkMAC_TX_SOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
			blkMAC_TX_EOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
			blkMAC_TX_Meta_DestMACAddress_Data(ARP_MAC_BC_PORT_NUMBER)	<= (others => '0');

			blkMAC_RX_Ack	(ARP_MAC_BC_PORT_NUMBER)											<= ARP_BC_RX_Ack;
			blkMAC_RX_Meta_rst(ARP_MAC_BC_PORT_NUMBER)									<= ARP_BC_RX_Meta_rst;
			blkMAC_RX_Meta_SrcMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_SrcMACAddress_nxt;
			blkMAC_RX_Meta_DestMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_DestMACAddress_nxt;

			MAC_LOOP : entity PoC.mac_FrameLoopback
				generic map (
					MAX_FRAMES										=> 4
				)
				port map (
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
					Out_Meta_SrcMACAddress_Data		=> open		--MAC_LOOP_TX_Meta_SrcMACAddress_Data,
	--				Out_Meta_EthType							=> open		--MAC_LOOP_TX_Meta_EthType
				);
		end generate;
	end block;

	blkARP : block
		attribute KEEP_HIERARCHY of ARP 					: label is "FALSE";

	begin
		--
		ARP : entity PoC.arp_Wrapper
			generic map (
				CLOCK_FREQ													=> CLOCK_FREQ,
				INTERFACE_MACADDRESS								=> MAC_CONFIGURATION(0).Interface.Address,
--				INITIAL_IPV4ADDRESSES								=> INITIAL_IPV4ADDRESSES_ETH0,
--				INITIAL_ARPCACHE_CONTENT						=> INITIAL_ARPCACHE_CONTENT_ETH0,
				APR_REQUEST_TIMEOUT									=> 2000.0 ms
			)
			port map (
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
	end block;

	blkIPv4 : block
		attribute KEEP_HIERARCHY of IPv4						: label is "FALSE";
		attribute KEEP_HIERARCHY of ICMPv4					: label is "FALSE";

		signal blk_TX_Valid													: std_logic_vector(IPV4_PORTS - 1 downto 0);
		signal blk_TX_Data													: T_SLVV_8(IPV4_PORTS - 1 downto 0);
		signal blk_TX_SOF														: std_logic_vector(IPV4_PORTS - 1 downto 0);
		signal blk_TX_EOF														: std_logic_vector(IPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_rst											: std_logic_vector(IPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_SrcIPv4Address_Data			: T_SLVV_8(IPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_DestIPv4Address_Data			: T_SLVV_8(IPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_Length										: T_SLVV_16(IPV4_PORTS - 1 downto 0);

		signal blk_RX_Ack														: std_logic_vector(IPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_rst											: std_logic_vector(IPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_SrcMACAddress_nxt				: std_logic_vector(IPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_DestMACAddress_nxt				: std_logic_vector(IPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_SrcIPv4Address_nxt				: std_logic_vector(IPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_DestIPv4Address_nxt			: std_logic_vector(IPV4_PORTS - 1 downto 0);

		signal blk_IPCache_Query										: std_logic;
		signal blk_IPCache_IPv4Address_Data					: T_SLV_8;
		signal blk_IPCache_IPv4Address_rst					: std_logic;
		signal blk_IPCache_IPv4Address_nxt					: std_logic;
		signal blk_IPCache_Valid										: std_logic;
		signal blk_IPCache_MACAddress_Data					: T_SLV_8;
		signal blk_IPCache_MACAddress_rst						: std_logic;
		signal blk_IPCache_MACAddress_nxt						: std_logic;

		signal ICMPv4_Command												: T_NET_ICMPV4_COMMAND		:= NET_ICMPV4_CMD_NONE;
		signal ICMPv4_Status												: T_NET_ICMPV4_STATUS;
		signal ICMPv4_Error													: T_NET_ICMPV4_ERROR;

		signal ICMPv4_TX_Valid											: std_logic;
		signal ICMPv4_TX_Data												: T_SLV_8;
		signal ICMPv4_TX_SOF												: std_logic;
		signal ICMPv4_TX_EOF												: std_logic;
		signal ICMPv4_TX_Meta_SrcIPv4Address_Data		: T_SLV_8;
		signal ICMPv4_TX_Meta_DestIPv4Address_Data	: T_SLV_8;
		signal ICMPv4_TX_Meta_Length								: T_SLV_16;

		signal ICMPv4_RX_Ack												: std_logic;
		signal ICMPv4_RX_Meta_rst										: std_logic;
		signal ICMPv4_RX_Meta_SrcMACAddress_nxt			: std_logic;
		signal ICMPv4_RX_Meta_DestMACAddress_nxt		: std_logic;
		signal ICMPv4_RX_Meta_SrcIPv4Address_nxt		: std_logic;
		signal ICMPv4_RX_Meta_DestIPv4Address_nxt		: std_logic;

--		signal ICMPv4_IPv4Address_rst								: STD_LOGIC;
--		signal ICMPv4_IPv4Address_nxt								: STD_LOGIC;
--		signal EchoReqIPv4Seq_IPv4Address_Data			: T_SLV_8;
	begin
		IPv4 : entity PoC.ipv4_Wrapper
			generic map (
				PACKET_TYPES											=> IPV4_PACKET_TYPES
			)
			port map (
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

--		genLB0 : if (IPV4_ENABLE_LOOPBACK = FALSE) generate
--
--		end generate;
		genLB1 : if (IPV4_ENABLE_LOOPBACK = TRUE) generate
			signal IPV4_LOOP_TX_Valid											: std_logic;
			signal IPV4_LOOP_TX_Data											: T_SLV_8;
			signal IPV4_LOOP_TX_SOF												: std_logic;
			signal IPV4_LOOP_TX_EOF												: std_logic;
			signal IPV4_LOOP_TX_Meta_SrcIPv4Address_Data	: T_SLV_8;
			signal IPV4_LOOP_TX_Meta_DestIPv4Address_Data	: T_SLV_8;
			signal IPV4_LOOP_TX_Meta_Length								: T_SLV_16;

			signal IPV4_LOOP_TX_Meta_rst									: std_logic;
			signal IPV4_LOOP_TX_Meta_SrcIPv4Address_nxt		: std_logic;
			signal IPV4_LOOP_TX_Meta_DestIPv4Address_nxt	: std_logic;

			signal IPV4_LOOP_RX_Ack												: std_logic;
			signal IPV4_LOOP_RX_Meta_rst									: std_logic;
			signal IPV4_LOOP_RX_Meta_SrcIPv4Address_nxt		: std_logic;
			signal IPV4_LOOP_RX_Meta_DestIPv4Address_nxt	: std_logic;
		begin
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

			IPV4_LOOP : entity PoC.ipv4_FrameLoopback
				generic map (
					MAX_FRAMES										=> 4
				)
				port map (
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
		end generate;


		ICMPv4 : entity PoC.icmpv4_Wrapper
			generic map (
				DEBUG															=> DEBUG,
				SOURCE_IPV4ADDRESS								=> IP_ADDRESS
			)
			port map (
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

				IPv4Address_rst										=> open,	--ICMPv4_IPv4Address_rst,
				IPv4Address_nxt										=> open,	--ICMPv4_IPv4Address_nxt,
				IPv4Address_Data									=> x"00"	--EchoReqIPv4Seq_IPv4Address_Data
			);
	end block;

	blkUDPv4 : block
		signal blk_TX_Valid														: std_logic_vector(UDPV4_PORTS - 1 downto 0);
		signal blk_TX_Data														: T_SLVV_8(UDPV4_PORTS - 1 downto 0);
		signal blk_TX_SOF															: std_logic_vector(UDPV4_PORTS - 1 downto 0);
		signal blk_TX_EOF															: std_logic_vector(UDPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_rst												: std_logic_vector(UDPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_SrcIPv4Address_Data				: T_SLVV_8(UDPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_DestIPv4Address_Data				: T_SLVV_8(UDPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_Length											: T_SLVV_16(UDPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_SrcPort										: T_SLVV_16(UDPV4_PORTS - 1 downto 0);
		signal blk_TX_Meta_DestPort										: T_SLVV_16(UDPV4_PORTS - 1 downto 0);

		signal blk_RX_Ack															: std_logic_vector(UDPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_rst												: std_logic_vector(UDPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_SrcMACAddress_nxt					: std_logic_vector(UDPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_DestMACAddress_nxt					: std_logic_vector(UDPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_SrcIPv4Address_nxt					: std_logic_vector(UDPV4_PORTS - 1 downto 0);
		signal blk_RX_Meta_DestIPv4Address_nxt				: std_logic_vector(UDPV4_PORTS - 1 downto 0);

	begin
		UDP : entity PoC.udp_Wrapper
			generic map (
				IP_VERSION												=> 4,
				PORTPAIRS													=> UDPV4_PORTPAIRS
			)
			port map (
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
			blk_TX_Valid(UDP_PORTS'length - 1 downto 0)											<= TX_Valid;
			blk_TX_Data(UDP_PORTS'length - 1 downto 0)											<= TX_Data;
			blk_TX_SOF(UDP_PORTS'length - 1 downto 0)												<= TX_SOF;
			blk_TX_EOF(UDP_PORTS'length - 1 downto 0)												<= TX_EOF;
			blk_TX_Meta_SrcIPv4Address_Data(UDP_PORTS'length - 1 downto 0)	<= TX_Meta_SrcIPv4Address_Data;
			blk_TX_Meta_DestIPv4Address_Data(UDP_PORTS'length - 1 downto 0)	<= TX_Meta_DestIPv4Address_Data;
	--		blk_TX_Meta_TrafficClass(UDP_PORTS'length - 1 downto 0)					<= (others => '0');
	--		blk_TX_Meta_FlowLabel(UDP_PORTS'length - 1 downto 0)						<= (others => '0');
			blk_TX_Meta_Length(UDP_PORTS'length - 1 downto 0)								<= TX_Meta_Length;
			blk_TX_Meta_SrcPort(UDP_PORTS'length - 1 downto 0)							<= TX_Meta_SrcPort;
			blk_TX_Meta_DestPort(UDP_PORTS'length - 1 downto 0)							<= TX_Meta_DestPort;

			blk_RX_Ack	(UDP_PORTS'length - 1 downto 0)											<= RX_Ack;
			blk_RX_Meta_rst(UDP_PORTS'length - 1 downto 0)									<= RX_Meta_rst;
			blk_RX_Meta_SrcMACAddress_nxt(UDP_PORTS'length - 1 downto 0)		<= RX_Meta_SrcMACAddress_nxt;
			blk_RX_Meta_DestMACAddress_nxt(UDP_PORTS'length - 1 downto 0)		<= RX_Meta_DestMACAddress_nxt;
			blk_RX_Meta_SrcIPv4Address_nxt(UDP_PORTS'length - 1 downto 0)		<= RX_Meta_SrcIPv4Address_nxt;
			blk_RX_Meta_DestIPv4Address_nxt(UDP_PORTS'length - 1 downto 0)	<= RX_Meta_DestIPv4Address_nxt;

--		genLB0 : if (UDP_ENABLE_LOOPBACK = FALSE) generate
--
--		end generate;

		genLB1 : if (UDP_ENABLE_LOOPBACK = TRUE) generate
			signal UDP_LOOP_TX_Valid											: std_logic;
			signal UDP_LOOP_TX_Data												: T_SLV_8;
			signal UDP_LOOP_TX_SOF												: std_logic;
			signal UDP_LOOP_TX_EOF												: std_logic;
			signal UDP_LOOP_TX_Meta_SrcIPv4Address_Data		: T_SLV_8;
			signal UDP_LOOP_TX_Meta_DestIPv4Address_Data	: T_SLV_8;
			signal UDP_LOOP_TX_Meta_Length								: T_SLV_16;
			signal UDP_LOOP_TX_Meta_SrcPort								: T_SLV_16;
			signal UDP_LOOP_TX_Meta_DestPort							: T_SLV_16;

			signal UDP_LOOP_TX_Meta_rst										: std_logic;
			signal UDP_LOOP_TX_Meta_SrcIPv4Address_nxt		: std_logic;
			signal UDP_LOOP_TX_Meta_DestIPv4Address_nxt		: std_logic;

			signal UDP_LOOP_RX_Ack												: std_logic;
			signal UDP_LOOP_RX_Meta_rst										: std_logic;
			signal UDP_LOOP_RX_Meta_SrcMACAddress_nxt			: std_logic;
			signal UDP_LOOP_RX_Meta_DestMACAddress_nxt		: std_logic;
			signal UDP_LOOP_RX_Meta_SrcIPv4Address_nxt		: std_logic;
			signal UDP_LOOP_RX_Meta_DestIPv4Address_nxt		: std_logic;
		begin
			-- UDPv4 Port n+1 - LoopBack
			blk_TX_Valid(UDP_LOOP_UDPV4_PORT_NUMBER)												<= UDP_LOOP_TX_Valid;
			blk_TX_Data(UDP_LOOP_UDPV4_PORT_NUMBER)													<= UDP_LOOP_TX_Data;
			blk_TX_SOF(UDP_LOOP_UDPV4_PORT_NUMBER)													<= UDP_LOOP_TX_SOF;
			blk_TX_EOF(UDP_LOOP_UDPV4_PORT_NUMBER)													<= UDP_LOOP_TX_EOF;
			blk_TX_Meta_SrcIPv4Address_Data(UDP_LOOP_UDPV4_PORT_NUMBER)			<= UDP_LOOP_TX_Meta_SrcIPv4Address_Data;
			blk_TX_Meta_DestIPv4Address_Data(UDP_LOOP_UDPV4_PORT_NUMBER)		<= UDP_LOOP_TX_Meta_DestIPv4Address_Data;
	--		blk_TX_Meta_TrafficClass(UDP_LOOP_UDPV4_PORT_NUMBER)						<= (others => '0');
	--		blk_TX_Meta_FlowLabel(UDP_LOOP_UDPV4_PORT_NUMBER)								<= (others => '0');
			blk_TX_Meta_Length(UDP_LOOP_UDPV4_PORT_NUMBER)									<= UDP_LOOP_TX_Meta_Length;
			blk_TX_Meta_SrcPort(UDP_LOOP_UDPV4_PORT_NUMBER)									<= UDP_LOOP_TX_Meta_SrcPort;
			blk_TX_Meta_DestPort(UDP_LOOP_UDPV4_PORT_NUMBER)								<= UDP_LOOP_TX_Meta_DestPort;

			blk_RX_Ack	(UDP_LOOP_UDPV4_PORT_NUMBER)												<= UDP_LOOP_RX_Ack;
			blk_RX_Meta_rst(UDP_LOOP_UDPV4_PORT_NUMBER)											<= UDP_LOOP_RX_Meta_rst;
			blk_RX_Meta_SrcMACAddress_nxt(UDP_LOOP_UDPV4_PORT_NUMBER)				<= '0';
			blk_RX_Meta_DestMACAddress_nxt(UDP_LOOP_UDPV4_PORT_NUMBER)			<= '0';
			blk_RX_Meta_SrcIPv4Address_nxt(UDP_LOOP_UDPV4_PORT_NUMBER)			<= UDP_LOOP_RX_Meta_SrcIPv4Address_nxt;
			blk_RX_Meta_DestIPv4Address_nxt(UDP_LOOP_UDPV4_PORT_NUMBER)			<= UDP_LOOP_RX_Meta_DestIPv4Address_nxt;

			UDP_LOOP : entity PoC.udp_FrameLoopback
				generic map (
					IP_VERSION										=> 4,
					MAX_FRAMES										=> 4
				)
				port map (
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
		end generate;
	end block;

	genCSP : if (DEBUG = TRUE) generate
		signal Eth_Status_d										: T_NET_ETH_STATUS;

		signal CSP_Ethernet_Clock							: std_logic;
		signal CSP_NewConnection							: std_logic;

		attribute KEEP of CSP_Ethernet_Clock	: signal is TRUE;
		attribute KEEP of CSP_NewConnection		: signal is TRUE;

	begin
		CSP_Ethernet_Clock	<= Ethernet_Clock;

		Eth_Status_d				<= Eth_Status when rising_edge(Ethernet_Clock);
		CSP_NewConnection		<= to_sl((Eth_Status_d /= NET_ETH_STATUS_CONNECTED) and (Eth_Status = NET_ETH_STATUS_CONNECTED));

	end generate;
end architecture;
