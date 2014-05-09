LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

--LIBRARY UNISIM;
--USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.io.ALL;
USE			PoC.net.ALL;

--LIBRARY L_Global;

--LIBRARY L_RemoteControl;
--USE			L_RemoteControl.RCTypes.ALL;

--LIBRARY	work;
--USE			work.FrameGenerator_Frames.GenUDPFrameGenerator_Frames;


ENTITY stack_UDPv4 IS
	GENERIC (
		DEBUG															: BOOLEAN															:= FALSE;																			-- 
		CLOCK_FREQ_MHZ										: REAL																:= 125.0;																			-- 125 MHz
		ETHERNET_IPSTYLE									: T_IPSTYLE														:= IPSTYLE_SOFT;															-- 
		ETHERNET_RS_DATA_INTERFACE				: T_NET_ETH_RS_DATA_INTERFACE					:= NET_ETH_RS_DATA_INTERFACE_GMII;						-- 
		ETHERNET_PHY_DEVICE								: T_NET_ETH_PHY_DEVICE								:= NET_ETH_PHY_DEVICE_MARVEL_88E1111;					-- 
		ETHERNET_PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS				:= x"00";																			-- 
		ETHERNET_PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE				:= NET_ETH_PHY_DATA_INTERFACE_GMII;						-- 
		ETHERNET_PHY_MANAGEMENT_INTERFACE	: T_NET_ETH_PHY_MANAGEMENT_INTERFACE	:= NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO;			-- 
		
		MAC_ADDRESS												: T_NET_MAC_ADDRESS;
		IP_ADDRESS												: T_NET_IPV4_ADDRESS;
		UDP_PORTS													: T_NET_UDP_PORT_VECTOR;
		
		MAC_ENABLE_LOOPBACK								: BOOLEAN															:= FALSE;
		IP_ENABLE_LOOPBACK								: BOOLEAN															:= FALSE;
		UDP_ENABLE_LOOPBACK								: BOOLEAN															:= FALSE;
		ICMP_ENABLE_ECHO									: BOOLEAN															:= FALSE;
		PING															: BOOLEAN															:= FALSE
	);
	PORT (
		Ethernet_Clock										: IN		STD_LOGIC;
		Ethernet_Reset										: IN		STD_LOGIC;
		
		Ethernet_Status										: OUT		T_NET_ETH_STATUS;
		
		PHY_Interface											:	INOUT	T_NET_ETH_PHY_INTERFACES
		
		-- UDP ports
	);
END;

ARCHITECTURE rtl OF stack_UDPv4 IS
	ATTRIBUTE KEEP											: BOOLEAN;
	ATTRIBUTE KEEP_HIERARCHY						: STRING;

	-- define ethernet configuration
	CONSTANT MAC_CONFIGURATION : T_NET_MAC_CONFIGURATION_VECTOR := (
		-- network interface 0 - AA:BB:CC:DD:EE:FF
		0 => (
			Interface => 		(Address => to_net_mac_address(string'("AA:BB:CC:DD:EE:FF")),	Mask => C_NET_MAC_MASK_DEFAULT),
			SourceFilter =>	(																																																	-- accept Ethernet-Frames from:
				0	=> 					(Address => to_net_mac_address(string'("50:E5:49:52:F1:C8")),	Mask => C_NET_MAC_MASK_DEFAULT),		--	50:E5:49:52:F1:C8
				OTHERS =>			(Address => C_NET_MAC_ADDRESS_EMPTY,													Mask => C_NET_MAC_MASK_EMPTY)),
			TypeSwitch =>		(
				0 =>					C_NET_MAC_ETHERNETTYPE_LOOPBACK,
				1 =>					C_NET_MAC_ETHERNETTYPE_ARP,
				2 =>					C_NET_MAC_ETHERNETTYPE_IPV4,
				OTHERS =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
		-- network interface 1 - A0:B0:C0:D0:E0:F0
		1 => (
			Interface => 		(Address => to_net_mac_address(string'("A0:B0:C0:D0:E0:F0")),	Mask => C_NET_MAC_MASK_DEFAULT),
			SourceFilter =>	(																																																	-- accept Ethernet-Frames from:
				0	=> 					(Address => to_net_mac_address(string'("50:E5:49:52:F1:C8")),	Mask => C_NET_MAC_MASK_DEFAULT),		--	50:E5:49:52:F1:C8
				OTHERS =>			(Address => C_NET_MAC_ADDRESS_EMPTY,													Mask => C_NET_MAC_MASK_EMPTY)),
			TypeSwitch =>		(
				0 =>					C_NET_MAC_ETHERNETTYPE_LOOPBACK,
				1 =>					C_NET_MAC_ETHERNETTYPE_ARP,
				2 =>					C_NET_MAC_ETHERNETTYPE_IPV6,
				OTHERS =>			C_NET_MAC_ETHERNETTYPE_EMPTY)),
		2 => (
			Interface => 		(Address => C_NET_MAC_ADDRESS_BROADCAST,											Mask => C_NET_MAC_MASK_DEFAULT),
			SourceFilter =>	(																																																	-- accept Ethernet-Frames from:
				0	=> 					(Address => to_net_mac_address(string'("00:00:00:00:00:01")),	Mask => C_NET_MAC_MASK_EMPTY),			--	EVERYWHERE
				OTHERS =>			(Address => C_NET_MAC_ADDRESS_EMPTY,													Mask => C_NET_MAC_MASK_EMPTY)),
			TypeSwitch =>		(
				0 =>					C_NET_MAC_ETHERNETTYPE_ARP,
				1 =>					C_NET_MAC_ETHERNETTYPE_IPV6,
				OTHERS =>			C_NET_MAC_ETHERNETTYPE_EMPTY))
	);

	CONSTANT ETHERNET_PORTS					: POSITIVE					:= getPortCount(MAC_CONFIGURATION);
	
	-- define ethernet port numbers for unicast addresses
	-- --------------------------------------------------------------------------
	-- eth0
	CONSTANT LOOP1_MAC_PORT_NUMBER		: NATURAL						:= 0;
	CONSTANT ARP1_MAC_UC_PORT_NUMBER	: NATURAL						:= 1;
	CONSTANT IPV4_MAC_PORT_NUMBER			: NATURAL						:= 2;

	-- eth1
	CONSTANT LOOP2_MAC_PORT_NUMBER		: NATURAL						:= 3;
	CONSTANT ARP2_MAC_UC_PORT_NUMBER	: NATURAL						:= 4;
	CONSTANT IPV6_MAC_PORT_NUMBER			: NATURAL						:= 5;

	-- define ethernet port numbers for multicast address
	-- --------------------------------------------------------------------------
	-- eth2 - broadcast
	CONSTANT ARP_MAC_BC_PORT_NUMBER		: NATURAL						:= 6;
	CONSTANT ARP1_MIRROR_PORT_NUMBER	: NATURAL						:= 0;
	CONSTANT ARP2_MIRROR_PORT_NUMBER	: NATURAL						:= 1;

	-- ARP configuration
	-- ==========================================================================================================================================================
	CONSTANT INITIAL_IPV4ADDRESSES_ETH0						: T_NET_IPV4_ADDRESS_VECTOR				:= (
		0 => to_net_ipv4_address(string'("192.168.10.10")),																				-- 192.168.10.10
		1 => to_net_ipv4_address(string'("192.168.20.10")),																				-- 192.168.20.10
		2 => to_net_ipv4_address(string'("192.168.90.10"))																				-- 192.168.90.10
	);

	CONSTANT INITIAL_ARPCACHE_CONTENT_ETH0				: T_NET_ARP_ARPCACHE_VECTOR				:= (
		0 => (Tag => to_net_ipv4_address("192.168.10.1"),		MAC => to_net_mac_address("50:E5:49:52:F1:C8")),
		1 => (Tag => to_net_ipv4_address("192.168.20.1"),		MAC => to_net_mac_address("64:70:02:01:DB:45")),
		2 => (Tag => to_net_ipv4_address("192.168.30.1"),		MAC => to_net_mac_address("1A:1B:1C:1D:1E:1F")),
		3 => (Tag => to_net_ipv4_address("192.168.40.1"),		MAC => to_net_mac_address("2A:2B:2C:2D:2E:2F"))
	);

	-- IPv4 configuration
	-- ==========================================================================================================================================================
	CONSTANT IPV4_PACKET_TYPES								: T_NET_IPV4_PROTOCOL_VECTOR			:= (
		0 => C_NET_IP_PROTOCOL_ICMP,
		1 => C_NET_IP_PROTOCOL_UDP,
		2 => C_NET_IP_PROTOCOL_LOOPBACK
	);

	CONSTANT IPV4_PORTS												: POSITIVE			:= IPV4_PACKET_TYPES'length;
	CONSTANT LOOP3_IPV4_PORT_NUMBER						: NATURAL				:= 0;
	CONSTANT ICMPV4_IPV4_PORT_NUMBER					: NATURAL				:= 1;
	CONSTANT UDPV4_IPV4_PORT_NUMBER						: NATURAL				:= 2;


	-- UDPv4 configuration
	-- ==========================================================================================================================================================
	CONSTANT UDPV4_PORTPAIRS								: T_NET_UDP_PORTPAIR_VECTOR	:= (
		0 => (x"C0FE",	x"C0FE"),		-- FrameGenerator
		1 => (x"FFFF",	x"FFFF")		-- LoopBack
	);

	CONSTANT UDPV4_PORTS										: POSITIVE		:= UDPV4_PORTPAIRS'length;
	CONSTANT LOOP6_UDPV4_PORT_NUMBER				: NATURAL			:= 0;
	CONSTANT UDPGENV4_UDPV4_PORT_NUMBER			: NATURAL			:= 1;


	-- Ethernet layer signals
	SIGNAL Eth_Command											: T_NET_ETH_COMMAND;
	SIGNAL Eth_Status												: T_NET_ETH_STATUS;
	SIGNAL Eth_Error												: T_NET_ETH_ERROR;
	
	SIGNAL Eth_TX_Ready											: STD_LOGIC;																										--ATTRIBUTE KEEP OF Eth_TX_Ready		: SIGNAL IS TRUE;
			
	SIGNAL Eth_RX_Valid											: STD_LOGIC;																										--ATTRIBUTE KEEP OF Eth_RX_Valid		: SIGNAL IS TRUE;
	SIGNAL Eth_RX_Data											: T_SLV_8;																											--ATTRIBUTE KEEP OF Eth_RX_Data			: SIGNAL IS TRUE;
	SIGNAL Eth_RX_SOF												: STD_LOGIC;																										--ATTRIBUTE KEEP OF Eth_RX_SOF			: SIGNAL IS TRUE;
	SIGNAL Eth_RX_EOF												: STD_LOGIC;																										--ATTRIBUTE KEEP OF Eth_RX_EOF			: SIGNAL IS TRUE;
		
	-- Ethernet MAC layer signals		
	SIGNAL MAC_TX_Valid											: STD_LOGIC;																										--ATTRIBUTE KEEP OF MAC_TX_Valid		: SIGNAL IS TRUE;
	SIGNAL MAC_TX_Data											: T_SLV_8;																											--ATTRIBUTE KEEP OF MAC_TX_Data			: SIGNAL IS TRUE;
	SIGNAL MAC_TX_SOF												: STD_LOGIC;																										--ATTRIBUTE KEEP OF MAC_TX_SOF			: SIGNAL IS TRUE;
	SIGNAL MAC_TX_EOF												: STD_LOGIC;																										--ATTRIBUTE KEEP OF MAC_TX_EOF			: SIGNAL IS TRUE;
								
	SIGNAL MAC_RX_Ready											: STD_LOGIC;																										--ATTRIBUTE KEEP OF MAC_RX_Ready		: SIGNAL IS TRUE;
								
	SIGNAL MAC_TX_Ready											: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_TX_Ready										: SIGNAL IS TRUE;
	SIGNAL MAC_TX_Meta_rst									: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_TX_Meta_rst									: SIGNAL IS TRUE;
	SIGNAL MAC_TX_Meta_DestMACAddress_nxt		: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_TX_Meta_DestMACAddress_nxt	: SIGNAL IS TRUE;
									
	SIGNAL MAC_RX_Valid											: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_RX_Valid										: SIGNAL IS TRUE;
	SIGNAL MAC_RX_Data											: T_SLVV_8(ETHERNET_PORTS - 1 DOWNTO 0);												--ATTRIBUTE KEEP OF MAC_RX_Data											: SIGNAL IS TRUE;
	SIGNAL MAC_RX_SOF												: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_RX_SOF											: SIGNAL IS TRUE;
	SIGNAL MAC_RX_EOF												: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);								--ATTRIBUTE KEEP OF MAC_RX_EOF											: SIGNAL IS TRUE;
	SIGNAL MAC_RX_Meta_DestMACAddress_Data	: T_SLVV_8(ETHERNET_PORTS - 1 DOWNTO 0);												--ATTRIBUTE KEEP OF MAC_RX_Meta_DestMACAddress_Data	: SIGNAL IS TRUE;
	SIGNAL MAC_RX_Meta_SrcMACAddress_Data		: T_SLVV_8(ETHERNET_PORTS - 1 DOWNTO 0);												--ATTRIBUTE KEEP OF MAC_RX_Meta_SrcMACAddress_Data	: SIGNAL IS TRUE;
	SIGNAL MAC_RX_Meta_EthType							: T_NET_MAC_ETHERNETTYPE_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);		--ATTRIBUTE KEEP OF MAC_RX_Meta_EthType							: SIGNAL IS TRUE;
	
	-- LoopBack layer signals
	SIGNAL Loop1_TX_Valid											: STD_LOGIC;
	SIGNAL Loop1_TX_Data											: T_SLV_8;
	SIGNAL Loop1_TX_SOF												: STD_LOGIC;
	SIGNAL Loop1_TX_EOF												: STD_LOGIC;
	SIGNAL Loop1_TX_Meta_DestMACAddress_Data	: T_SLV_8;
	SIGNAL Loop1_TX_Meta_SrcMACAddress_Data		: T_SLV_8;
	SIGNAL Loop1_TX_Meta_EthType							: T_NET_MAC_ETHERNETTYPE;
	
	SIGNAL Loop1_RX_Ready											: STD_LOGIC;
	SIGNAL Loop1_RX_Meta_rst									: STD_LOGIC;
	SIGNAL Loop1_RX_Meta_DestMACAddress_nxt		: STD_LOGIC;
	SIGNAL Loop1_RX_Meta_SrcMACAddress_nxt		: STD_LOGIC;
	
	SIGNAL Loop2_TX_Valid											: STD_LOGIC;
	SIGNAL Loop2_TX_Data											: T_SLV_8;
	SIGNAL Loop2_TX_SOF												: STD_LOGIC;
	SIGNAL Loop2_TX_EOF												: STD_LOGIC;
	SIGNAL Loop2_TX_Meta_DestMACAddress_Data	: T_SLV_8;
	SIGNAL Loop2_TX_Meta_SrcMACAddress_Data		: T_SLV_8;
	SIGNAL Loop2_TX_Meta_EthType							: T_NET_MAC_ETHERNETTYPE;
	
	SIGNAL Loop2_RX_Ready											: STD_LOGIC;
	SIGNAL Loop2_RX_Meta_rst									: STD_LOGIC;
	SIGNAL Loop2_RX_Meta_DestMACAddress_nxt		: STD_LOGIC;
	SIGNAL Loop2_RX_Meta_SrcMACAddress_nxt		: STD_LOGIC;
	
	-- Address Resolution Protocol layer signals
	SIGNAL ARP1_UC_TX_Valid												: STD_LOGIC;
	SIGNAL ARP1_UC_TX_Data												: T_SLV_8;
	SIGNAL ARP1_UC_TX_SOF													: STD_LOGIC;
	SIGNAL ARP1_UC_TX_EOF													: STD_LOGIC;
	SIGNAL ARP1_UC_TX_Meta_DestMACAddress_Data		: T_SLV_8;
	
	SIGNAL ARP1_UC_RX_Ready												: STD_LOGIC;
	SIGNAL ARP1_UC_RX_Meta_rst										: STD_LOGIC;
	SIGNAL ARP1_UC_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
	SIGNAL ARP1_UC_RX_Meta_DestMACAddress_nxt			: STD_LOGIC;
	
	SIGNAL ARP1_IPCache_IPv4Address_rst						: STD_LOGIC;
	SIGNAL ARP1_IPCache_IPv4Address_nxt						: STD_LOGIC;
	SIGNAL ARP1_IPCache_Valid											: STD_LOGIC;
	SIGNAL ARP1_IPCache_MACAddress_Data						: T_SLV_8;
	
	SIGNAL ARP2_UC_TX_Valid												: STD_LOGIC;
	SIGNAL ARP2_UC_TX_Data												: T_SLV_8;
	SIGNAL ARP2_UC_TX_SOF													: STD_LOGIC;
	SIGNAL ARP2_UC_TX_EOF													: STD_LOGIC;
	SIGNAL ARP2_UC_TX_Meta_DestMACAddress_Data		: T_SLV_8;
	
	SIGNAL ARP2_UC_RX_Ready												: STD_LOGIC;
	SIGNAL ARP2_UC_RX_Meta_rst										: STD_LOGIC;
	SIGNAL ARP2_UC_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
	SIGNAL ARP2_UC_RX_Meta_DestMACAddress_nxt			: STD_LOGIC;
	
	SIGNAL ARP_BC_RX_Ready												: STD_LOGIC;
	SIGNAL ARP_BC_RX_Meta_rst											: STD_LOGIC;
	SIGNAL ARP_BC_RX_Meta_SrcMACAddress_nxt				: STD_LOGIC;
	SIGNAL ARP_BC_RX_Meta_DestMACAddress_nxt			: STD_LOGIC;
	
	-- Internet Protocol Version 4 layer signals	
	SIGNAL IPv4_TX_Valid													: STD_LOGIC;
	SIGNAL IPv4_TX_Data														: T_SLV_8;
	SIGNAL IPv4_TX_SOF														: STD_LOGIC;
	SIGNAL IPv4_TX_EOF														: STD_LOGIC;
	SIGNAL IPv4_TX_Meta_DestMACAddress_Data				: T_SLV_8;
	
	SIGNAL IPv4_RX_Ready													: STD_LOGIC;
	SIGNAL IPv4_RX_Meta_rst												: STD_LOGIC;
	SIGNAL IPv4_RX_Meta_SrcMACAddress_nxt					: STD_LOGIC;
	SIGNAL IPv4_RX_Meta_DestMACAddress_nxt				: STD_LOGIC;
	
	SIGNAL IPv4_ARP_Query											: STD_LOGIC;
	SIGNAL IPv4_ARP_IPv4Address_Data					: T_SLV_8;
	SIGNAL IPv4_ARP_MACAddress_rst						: STD_LOGIC;
	SIGNAL IPv4_ARP_MACAddress_nxt						: STD_LOGIC;
	
	SIGNAL IPv4_TX_Ready													: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
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
	
	SIGNAL UDPv4_RX_Ready													: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_rst											: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_SrcMACAddress_nxt				: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_DestMACAddress_nxt				: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_SrcIPv4Address_nxt				: STD_LOGIC;
	SIGNAL UDPv4_RX_Meta_DestIPv4Address_nxt			: STD_LOGIC;
	
	SIGNAL UDPv4_TX_Ready													: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
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
		Eth_Command						<= NET_ETH_CMD_NONE;
	
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
	
		Eth : ENTITY L_Ethernet.Eth_Wrapper
			GENERIC MAP (
				DEBUG						=> FALSE,	--DEBUG,
				CLOCKIN_FREQ_MHZ					=> CLOCKIN_FREQ_MHZ,
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
				TX_Ready									=> Eth_TX_Ready,
				
				RX_Valid									=> Eth_RX_Valid,
				RX_Data										=> Eth_RX_Data,
				RX_SOF										=> Eth_RX_SOF,
				RX_EOF										=> Eth_RX_EOF,
				RX_Ready									=> MAC_RX_Ready,
			
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
		
		SIGNAL blkMAC_RX_Ready										: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_RX_Meta_rst									: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_RX_Meta_DestMACAddress_nxt	: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		SIGNAL blkMAC_RX_Meta_SrcMACAddress_nxt		: STD_LOGIC_VECTOR(ETHERNET_PORTS - 1 DOWNTO 0);
		
	BEGIN
		MAC : ENTITY L_Ethernet.MAC_Wrapper
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
				Eth_TX_Ready									=> Eth_TX_Ready,
				
				Eth_RX_Valid									=> Eth_RX_Valid,
				Eth_RX_Data										=> Eth_RX_Data,
				Eth_RX_SOF										=> Eth_RX_SOF,
				Eth_RX_EOF										=> Eth_RX_EOF,
				Eth_RX_Ready									=> MAC_RX_Ready,
				
				TX_Valid											=> blkMAC_TX_Valid,
				TX_Data												=> blkMAC_TX_Data,
				TX_SOF												=> blkMAC_TX_SOF,
				TX_EOF												=> blkMAC_TX_EOF,
				TX_Ready											=> MAC_TX_Ready,
				TX_Meta_rst										=> MAC_TX_Meta_rst,
				TX_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt,
				TX_Meta_DestMACAddress_Data		=> blkMAC_TX_Meta_DestMACAddress_Data,
					
				RX_Valid											=> MAC_RX_Valid,
				RX_Data												=> MAC_RX_Data,
				RX_SOF												=> MAC_RX_SOF,
				RX_EOF												=> MAC_RX_EOF,
				RX_Ready											=> blkMAC_RX_Ready,
				RX_Meta_rst										=> blkMAC_RX_Meta_rst,
				RX_Meta_SrcMACAddress_nxt			=> blkMAC_RX_Meta_SrcMACAddress_nxt,
				RX_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data,
				RX_Meta_DestMACAddress_nxt		=> blkMAC_RX_Meta_DestMACAddress_nxt,
				RX_Meta_DestMACAddress_Data		=> MAC_RX_Meta_DestMACAddress_Data,
				RX_Meta_EthType								=> MAC_RX_Meta_EthType
			);
		
		-- Ethernet Port 0 -> LoopBack
		-- ========================================================================
		blkMAC_TX_Valid(LOOP1_MAC_PORT_NUMBER)											<= Loop1_TX_Valid;
		blkMAC_TX_Data(LOOP1_MAC_PORT_NUMBER)												<= Loop1_TX_Data;
		blkMAC_TX_SOF(LOOP1_MAC_PORT_NUMBER)												<= Loop1_TX_SOF;
		blkMAC_TX_EOF(LOOP1_MAC_PORT_NUMBER)												<= Loop1_TX_EOF;
		blkMAC_TX_Meta_DestMACAddress_Data(LOOP1_MAC_PORT_NUMBER)		<= Loop1_TX_Meta_DestMACAddress_Data;
		
		blkMAC_RX_Ready(LOOP1_MAC_PORT_NUMBER)											<= Loop1_RX_Ready;
		blkMAC_RX_Meta_rst(LOOP1_MAC_PORT_NUMBER)										<= Loop1_RX_Meta_rst;
		blkMAC_RX_Meta_SrcMACAddress_nxt(LOOP1_MAC_PORT_NUMBER)			<= Loop1_RX_Meta_SrcMACAddress_nxt;
		blkMAC_RX_Meta_DestMACAddress_nxt(LOOP1_MAC_PORT_NUMBER)		<= '0';	--Loop1_RX_Meta_DestMACAddress_nxt;
		
		-- Ethernet Port 1 -> ARP UC
		-- ========================================================================
		blkMAC_TX_Valid(ARP1_MAC_UC_PORT_NUMBER)										<= ARP1_UC_TX_Valid;
		blkMAC_TX_Data(ARP1_MAC_UC_PORT_NUMBER)											<= ARP1_UC_TX_Data;
		blkMAC_TX_SOF(ARP1_MAC_UC_PORT_NUMBER)											<= ARP1_UC_TX_SOF;
		blkMAC_TX_EOF(ARP1_MAC_UC_PORT_NUMBER)											<= ARP1_UC_TX_EOF;
		blkMAC_TX_Meta_DestMACAddress_Data(ARP1_MAC_UC_PORT_NUMBER)	<= ARP1_UC_TX_Meta_DestMACAddress_Data;
		
		blkMAC_RX_Ready(ARP1_MAC_UC_PORT_NUMBER)										<= ARP1_UC_RX_Ready;
		blkMAC_RX_Meta_rst(ARP1_MAC_UC_PORT_NUMBER)									<= ARP1_UC_RX_Meta_rst;
		blkMAC_RX_Meta_SrcMACAddress_nxt(ARP1_MAC_UC_PORT_NUMBER)		<= ARP1_UC_RX_Meta_SrcMACAddress_nxt;
		blkMAC_RX_Meta_DestMACAddress_nxt(ARP1_MAC_UC_PORT_NUMBER)	<= ARP1_UC_RX_Meta_DestMACAddress_nxt;
		
		-- Ethernet Port 2 -> IPv4
		-- ========================================================================
		blkMAC_TX_Valid(IPV4_MAC_PORT_NUMBER)												<= IPv4_TX_Valid;
		blkMAC_TX_Data(IPV4_MAC_PORT_NUMBER)												<= IPv4_TX_Data;
		blkMAC_TX_SOF(IPV4_MAC_PORT_NUMBER)													<= IPv4_TX_SOF;
		blkMAC_TX_EOF(IPV4_MAC_PORT_NUMBER)													<= IPv4_TX_EOF;
		blkMAC_TX_Meta_DestMACAddress_Data(IPV4_MAC_PORT_NUMBER)		<= IPv4_TX_Meta_DestMACAddress_Data;
		
		blkMAC_RX_Ready(IPV4_MAC_PORT_NUMBER)												<= IPv4_RX_Ready;
		blkMAC_RX_Meta_rst(IPV4_MAC_PORT_NUMBER)										<= '0';	--IPv4_RX_Meta_rst;
		blkMAC_RX_Meta_SrcMACAddress_nxt(IPV4_MAC_PORT_NUMBER)			<= '0';	--IPv4_RX_Meta_SrcMACAddress_nxt;
		blkMAC_RX_Meta_DestMACAddress_nxt(IPV4_MAC_PORT_NUMBER)			<= '0';	--IPv4_RX_Meta_DestMACAddress_nxt;

		-- Ethernet Port 3 -> LoopBack
		-- ========================================================================
		blkMAC_TX_Valid(LOOP2_MAC_PORT_NUMBER)											<= Loop2_TX_Valid;
		blkMAC_TX_Data(LOOP2_MAC_PORT_NUMBER)												<= Loop2_TX_Data;
		blkMAC_TX_SOF(LOOP2_MAC_PORT_NUMBER)												<= Loop2_TX_SOF;
		blkMAC_TX_EOF(LOOP2_MAC_PORT_NUMBER)												<= Loop2_TX_EOF;
		blkMAC_TX_Meta_DestMACAddress_Data(LOOP2_MAC_PORT_NUMBER)		<= Loop2_TX_Meta_DestMACAddress_Data;
		
		blkMAC_RX_Ready(LOOP2_MAC_PORT_NUMBER)											<= Loop2_RX_Ready;
		blkMAC_RX_Meta_rst(LOOP2_MAC_PORT_NUMBER)										<= Loop2_RX_Meta_rst;
		blkMAC_RX_Meta_SrcMACAddress_nxt(LOOP2_MAC_PORT_NUMBER)			<= Loop2_RX_Meta_SrcMACAddress_nxt;
		blkMAC_RX_Meta_DestMACAddress_nxt(LOOP2_MAC_PORT_NUMBER)		<= '0';	--Loop2_RX_Meta_DestMACAddress_nxt;

		-- Ethernet Port 4 -> ARP UC
		-- ========================================================================
		blkMAC_TX_Valid(ARP2_MAC_UC_PORT_NUMBER)										<= ARP2_UC_TX_Valid;
		blkMAC_TX_Data(ARP2_MAC_UC_PORT_NUMBER)											<= ARP2_UC_TX_Data;
		blkMAC_TX_SOF(ARP2_MAC_UC_PORT_NUMBER)											<= ARP2_UC_TX_SOF;
		blkMAC_TX_EOF(ARP2_MAC_UC_PORT_NUMBER)											<= ARP2_UC_TX_EOF;
		blkMAC_TX_Meta_DestMACAddress_Data(ARP2_MAC_UC_PORT_NUMBER)	<= ARP2_UC_TX_Meta_DestMACAddress_Data;
		
		blkMAC_RX_Ready(ARP2_MAC_UC_PORT_NUMBER)										<= ARP2_UC_RX_Ready;
		blkMAC_RX_Meta_rst(ARP2_MAC_UC_PORT_NUMBER)									<= ARP2_UC_RX_Meta_rst;
		blkMAC_RX_Meta_SrcMACAddress_nxt(ARP2_MAC_UC_PORT_NUMBER)		<= ARP2_UC_RX_Meta_SrcMACAddress_nxt;
		blkMAC_RX_Meta_DestMACAddress_nxt(ARP2_MAC_UC_PORT_NUMBER)	<= ARP2_UC_RX_Meta_DestMACAddress_nxt;

		-- Ethernet Port 5 -> IPv6
		-- ========================================================================
		blkMAC_TX_Valid(IPV6_MAC_PORT_NUMBER)												<= IPv6_TX_Valid;
		blkMAC_TX_Data(IPV6_MAC_PORT_NUMBER)												<= IPv6_TX_Data;
		blkMAC_TX_SOF(IPV6_MAC_PORT_NUMBER)													<= IPv6_TX_SOF;
		blkMAC_TX_EOF(IPV6_MAC_PORT_NUMBER)													<= IPv6_TX_EOF;
		blkMAC_TX_Meta_DestMACAddress_Data(IPV6_MAC_PORT_NUMBER)		<= IPv6_TX_Meta_DestMACAddress_Data;
		
		blkMAC_RX_Ready(IPV6_MAC_PORT_NUMBER)												<= IPv6_RX_Ready;
		blkMAC_RX_Meta_rst(IPV6_MAC_PORT_NUMBER)										<= IPv6_RX_Meta_rst;
		blkMAC_RX_Meta_SrcMACAddress_nxt(IPV6_MAC_PORT_NUMBER)			<= IPv6_RX_Meta_SrcMACAddress_nxt;
		blkMAC_RX_Meta_DestMACAddress_nxt(IPV6_MAC_PORT_NUMBER)			<= IPv6_RX_Meta_DestMACAddress_nxt;
		
		-- Ethernet Port 6 -> ARP Broadcast
		-- ========================================================================
		blkMAC_TX_Valid(ARP_MAC_BC_PORT_NUMBER)											<= '0';
		blkMAC_TX_Data(ARP_MAC_BC_PORT_NUMBER)											<= (OTHERS => '0');
		blkMAC_TX_SOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
		blkMAC_TX_EOF(ARP_MAC_BC_PORT_NUMBER)												<= '0';
		blkMAC_TX_Meta_DestMACAddress_Data(ARP_MAC_BC_PORT_NUMBER)	<= (OTHERS => '0');
		
		blkMAC_RX_Ready(ARP_MAC_BC_PORT_NUMBER)											<= ARP_BC_RX_Ready;
		blkMAC_RX_Meta_rst(ARP_MAC_BC_PORT_NUMBER)									<= ARP_BC_RX_Meta_rst;
		blkMAC_RX_Meta_SrcMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_SrcMACAddress_nxt;
		blkMAC_RX_Meta_DestMACAddress_nxt(ARP_MAC_BC_PORT_NUMBER)		<= ARP_BC_RX_Meta_DestMACAddress_nxt;
		
		-- Ethernet Port 7 -> IPv6 Broadcast
		-- ========================================================================
		blkMAC_TX_Valid(IPV6_MAC_BC_PORT_NUMBER)										<= '0';
		blkMAC_TX_Data(IPV6_MAC_BC_PORT_NUMBER)											<= (OTHERS => '0');
		blkMAC_TX_SOF(IPV6_MAC_BC_PORT_NUMBER)											<= '0';
		blkMAC_TX_EOF(IPV6_MAC_BC_PORT_NUMBER)											<= '0';
		blkMAC_TX_Meta_DestMACAddress_Data(IPV6_MAC_BC_PORT_NUMBER)	<= (OTHERS => '0');
		
		blkMAC_RX_Ready(IPV6_MAC_BC_PORT_NUMBER)										<= '0';
		blkMAC_RX_Meta_rst(IPV6_MAC_BC_PORT_NUMBER)									<= '0';
		blkMAC_RX_Meta_SrcMACAddress_nxt(IPV6_MAC_BC_PORT_NUMBER)		<= '0';
		blkMAC_RX_Meta_DestMACAddress_nxt(IPV6_MAC_BC_PORT_NUMBER)	<= '0';
	END BLOCK;
	
	blkLoopback : BLOCK
	BEGIN
		Loop1 : ENTITY L_Ethernet.MAC_FrameLoopback
			GENERIC MAP (
				MAX_FRAMES										=> 4
			)
			PORT MAP (
				Clock													=> Ethernet_Clock,
				Reset													=> Ethernet_Reset,
				
				In_Valid											=> MAC_RX_Valid(LOOP1_MAC_PORT_NUMBER),
				In_Data												=> MAC_RX_Data(LOOP1_MAC_PORT_NUMBER),
				In_SOF												=> MAC_RX_SOF(LOOP1_MAC_PORT_NUMBER),
				In_EOF												=> MAC_RX_EOF(LOOP1_MAC_PORT_NUMBER),
				In_Ready											=> Loop1_RX_Ready,
				In_Meta_rst										=> Loop1_RX_Meta_rst,
--				In_Meta_DestMACAddress_nxt		=> Loop1_RX_Meta_DestMACAddress_nxt,
--				In_Meta_DestMACAddress_Data		=> MAC_RX_Meta_DestMACAddress_Data(LOOP1_MAC_PORT_NUMBER),
				In_Meta_SrcMACAddress_nxt			=> Loop1_RX_Meta_SrcMACAddress_nxt,
				In_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(LOOP1_MAC_PORT_NUMBER),
--				In_Meta_EthType								=> MAC_RX_Meta_EthType(LOOP1_MAC_PORT_NUMBER),

				Out_Valid											=> Loop1_TX_Valid,
				Out_Data											=> Loop1_TX_Data,
				Out_SOF												=> Loop1_TX_SOF,
				Out_EOF												=> Loop1_TX_EOF,
				Out_Ready											=> MAC_TX_Ready(LOOP1_MAC_PORT_NUMBER),
				Out_Meta_rst									=> MAC_TX_Meta_rst(LOOP1_MAC_PORT_NUMBER),
				Out_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt(LOOP1_MAC_PORT_NUMBER),
				Out_Meta_DestMACAddress_Data	=> Loop1_TX_Meta_DestMACAddress_Data--,
--				Out_Meta_SrcMACAddress_nxt		=> '0',		--MAC_TX_Meta_SrcMACAddress_nxt(LOOP1_MAC_PORT_NUMBER),
--				Out_Meta_SrcMACAddress_Data		=> OPEN,	--Loop1_TX_Meta_SrcMACAddress_Data,
--				Out_Meta_EthType							=> OPEN		--Loop1_TX_Meta_EthType
			);
		
		Loop2 : ENTITY L_Ethernet.MAC_FrameLoopback
			GENERIC MAP (
				MAX_FRAMES										=> 4
			)
			PORT MAP (
				Clock													=> Ethernet_Clock,
				Reset													=> Ethernet_Reset,
				
				In_Valid											=> MAC_RX_Valid(LOOP2_MAC_PORT_NUMBER),
				In_Data												=> MAC_RX_Data(LOOP2_MAC_PORT_NUMBER),
				In_SOF												=> MAC_RX_SOF(LOOP2_MAC_PORT_NUMBER),
				In_EOF												=> MAC_RX_EOF(LOOP2_MAC_PORT_NUMBER),
				In_Ready											=> Loop2_RX_Ready,
				In_Meta_rst										=> Loop2_RX_Meta_rst,
--				In_Meta_DestMACAddress_nxt		=> Loop2_RX_Meta_DestMACAddress_nxt,
--				In_Meta_DestMACAddress_Data		=> MAC_RX_Meta_DestMACAddress_Data(LOOP2_MAC_PORT_NUMBER),
				In_Meta_SrcMACAddress_nxt			=> Loop2_RX_Meta_SrcMACAddress_nxt,
				In_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(LOOP2_MAC_PORT_NUMBER),
--				In_Meta_EthType								=> MAC_RX_Meta_EthType(LOOP2_MAC_PORT_NUMBER),

				Out_Valid											=> Loop2_TX_Valid,
				Out_Data											=> Loop2_TX_Data,
				Out_SOF												=> Loop2_TX_SOF,
				Out_EOF												=> Loop2_TX_EOF,
				Out_Ready											=> MAC_TX_Ready(LOOP2_MAC_PORT_NUMBER),
				Out_Meta_rst									=> MAC_TX_Meta_rst(LOOP2_MAC_PORT_NUMBER),
				Out_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt(LOOP2_MAC_PORT_NUMBER),
				Out_Meta_DestMACAddress_Data	=> Loop2_TX_Meta_DestMACAddress_Data--,
--				Out_Meta_SrcMACAddress_nxt		=> '0',		--MAC_TX_Meta_SrcMACAddress_nxt(LOOP2_MAC_PORT_NUMBER),
--				Out_Meta_SrcMACAddress_Data		=> OPEN,	--Loop2_TX_Meta_SrcMACAddress_Data,
--				Out_Meta_EthType							=> OPEN		--Loop2_TX_Meta_EthType
			);
	END BLOCK;

	blkARP : BLOCK
		ATTRIBUTE KEEP_HIERARCHY OF ARP1 					: LABEL IS "FALSE";
		ATTRIBUTE KEEP_HIERARCHY OF ARP2 					: LABEL IS "FALSE";
		
		CONSTANT MIRROR_PORTS											: POSITIVE						:= 2;
		CONSTANT MIRROR_DATA_BITS									: POSITIVE						:= 8;

		-- 2 byte interfaces; each of 6 bytes in length
		CONSTANT MIRROR_META_STREAMID_SRCMAC			: NATURAL							:= 0;
		CONSTANT MIRROR_META_STREAMID_DESTMAC			: NATURAL							:= 1;
		CONSTANT MIRROR_META_BITS									: T_POSVEC						:= (MIRROR_META_STREAMID_SRCMAC => 8, MIRROR_META_STREAMID_DESTMAC => 8);
		CONSTANT MIRROR_META_LENGTH								: T_POSVEC						:= (MIRROR_META_STREAMID_SRCMAC => 6, MIRROR_META_STREAMID_DESTMAC => 6);
		CONSTANT MIRROR_META_STREAMS							: POSITIVE						:= MIRROR_META_BITS'length;
		
		SIGNAL Mirror_Valid												: STD_LOGIC_VECTOR(MIRROR_PORTS - 1 DOWNTO 0);
		SIGNAL Mirror_DataOut											: T_SLM(MIRROR_PORTS - 1 DOWNTO 0, MIRROR_DATA_BITS - 1 DOWNTO 0);
		SIGNAL Mirror_SOF													: STD_LOGIC_VECTOR(MIRROR_PORTS - 1 DOWNTO 0);
		SIGNAL Mirror_EOF													: STD_LOGIC_VECTOR(MIRROR_PORTS - 1 DOWNTO 0);
		SIGNAL Mirror_Ready												: STD_LOGIC_VECTOR(MIRROR_PORTS - 1 DOWNTO 0);
		SIGNAL Mirror_MetaIn_nxt									: STD_LOGIC_VECTOR(MIRROR_META_STREAMS - 1 DOWNTO 0);
		SIGNAL Mirror_MetaIn_Data									: STD_LOGIC_VECTOR(isum(MIRROR_META_BITS) - 1 DOWNTO 0);
		SIGNAL Mirror_MetaOut_rst									: STD_LOGIC_VECTOR(MIRROR_PORTS - 1 DOWNTO 0);
		SIGNAL Mirror_MetaOut_nxt									: T_SLM(MIRROR_PORTS - 1 DOWNTO 0, MIRROR_META_STREAMS - 1 DOWNTO 0);
		SIGNAL Mirror_MetaOut_Data								: T_SLM(MIRROR_PORTS - 1 DOWNTO 0, isum(MIRROR_META_BITS) - 1 DOWNTO 0);

		SIGNAL Mirror_Data												: T_SLVV_8(MIRROR_PORTS - 1 DOWNTO 0);
		SIGNAL Mirror_Meta_SrcMACAddress_Data			: T_SLVV_8(MIRROR_PORTS - 1 DOWNTO 0);
		SIGNAL Mirror_Meta_DestMACAddress_Data		: T_SLVV_8(MIRROR_PORTS - 1 DOWNTO 0);
		
		SIGNAL ARP1_BC_RX_Ready										: STD_LOGIC;
		SIGNAL ARP1_BC_RX_Meta_rst								: STD_LOGIC;
		SIGNAL ARP1_BC_RX_Meta_SrcMACAddress_nxt	: STD_LOGIC;
		SIGNAL ARP1_BC_RX_Meta_DestMACAddress_nxt	: STD_LOGIC;
		
		SIGNAL ARP2_BC_RX_Ready										: STD_LOGIC;
		SIGNAL ARP2_BC_RX_Meta_rst								: STD_LOGIC;
		SIGNAL ARP2_BC_RX_Meta_SrcMACAddress_nxt	: STD_LOGIC;
		SIGNAL ARP2_BC_RX_Meta_DestMACAddress_nxt	: STD_LOGIC;
	
		SIGNAL ARP2_Tester_Lookup									: STD_LOGIC;
		SIGNAL ARP2_IPv4Address_rst								: STD_LOGIC;
		SIGNAL ARP2_IPv4Address_nxt								: STD_LOGIC;
		SIGNAL ARP2_Tester_IPv4Address_Data				: T_SLV_8;
		SIGNAL ARP2_Valid													: STD_LOGIC;
		SIGNAL ARP2_Tester_MACAddress_rst					: STD_LOGIC;
		SIGNAL ARP2_Tester_MACAddress_nxt					: STD_LOGIC;
		SIGNAL ARP2_MACAddress_Data								: T_SLV_8;
		
	BEGIN
	
		ARP_BC_RX_Meta_SrcMACAddress_nxt	<= Mirror_MetaIn_nxt(MIRROR_META_STREAMID_SRCMAC);
		ARP_BC_RX_Meta_DestMACAddress_nxt	<= Mirror_MetaIn_nxt(MIRROR_META_STREAMID_DESTMAC);
		
		Mirror_MetaIn_Data(high(MIRROR_META_BITS, MIRROR_META_STREAMID_SRCMAC)	DOWNTO low(MIRROR_META_BITS, MIRROR_META_STREAMID_SRCMAC))		<= MAC_RX_Meta_SrcMACAddress_Data(ARP_MAC_BC_PORT_NUMBER);
		Mirror_MetaIn_Data(high(MIRROR_META_BITS, MIRROR_META_STREAMID_DESTMAC) DOWNTO low(MIRROR_META_BITS, MIRROR_META_STREAMID_DESTMAC))		<= MAC_RX_Meta_DestMACAddress_Data(ARP_MAC_BC_PORT_NUMBER);
	
		mirror : ENTITY L_Global.LocalLink_Mirror
			GENERIC MAP (
				PORTS														=> MIRROR_PORTS,
				DATA_BITS												=> MIRROR_DATA_BITS,
				META_BITS												=> MIRROR_META_BITS,
				META_LENGTH											=> MIRROR_META_LENGTH
			)			
			PORT MAP (			
				Clock														=> Ethernet_Clock,
				Reset														=> Ethernet_Reset,
							
				In_Valid												=> MAC_RX_Valid(ARP_MAC_BC_PORT_NUMBER),
				In_Data													=> MAC_RX_Data(ARP_MAC_BC_PORT_NUMBER),
				In_SOF													=> MAC_RX_SOF(ARP_MAC_BC_PORT_NUMBER),
				In_EOF													=> MAC_RX_EOF(ARP_MAC_BC_PORT_NUMBER),
				In_Ready												=> ARP_BC_RX_Ready,
				In_Meta_rst											=> ARP_BC_RX_Meta_rst,
				In_Meta_nxt											=> Mirror_MetaIn_nxt,
				In_Meta_Data										=> Mirror_MetaIn_Data,
							
				Out_Valid												=> Mirror_Valid,
				Out_Data												=> Mirror_DataOut,
				Out_SOF													=> Mirror_SOF,
				Out_EOF													=> Mirror_EOF,
				Out_Ready												=> Mirror_Ready,
				Out_Meta_rst										=> Mirror_MetaOut_rst,
				Out_Meta_nxt										=> Mirror_MetaOut_nxt,
				Out_Meta_Data										=> Mirror_MetaOut_Data
			);

		Mirror_Data																	<= to_slvv_8(Mirror_DataOut);
		Mirror_Ready(ARP1_MIRROR_PORT_NUMBER)				<= ARP1_BC_RX_Ready;
		Mirror_Ready(ARP2_MIRROR_PORT_NUMBER)				<= ARP2_BC_RX_Ready;
		
		Mirror_MetaOut_rst(ARP1_MIRROR_PORT_NUMBER)	<= ARP1_BC_RX_Meta_rst;
		Mirror_MetaOut_rst(ARP2_MIRROR_PORT_NUMBER)	<= ARP2_BC_RX_Meta_rst;
		
		Mirror_MetaOut_nxt(ARP1_MIRROR_PORT_NUMBER, MIRROR_META_STREAMID_SRCMAC)	<= ARP1_BC_RX_Meta_SrcMACAddress_nxt;
		Mirror_MetaOut_nxt(ARP1_MIRROR_PORT_NUMBER, MIRROR_META_STREAMID_DESTMAC)	<= ARP1_BC_RX_Meta_DestMACAddress_nxt;
		Mirror_MetaOut_nxt(ARP2_MIRROR_PORT_NUMBER, MIRROR_META_STREAMID_SRCMAC)	<= ARP2_BC_RX_Meta_SrcMACAddress_nxt;
		Mirror_MetaOut_nxt(ARP2_MIRROR_PORT_NUMBER, MIRROR_META_STREAMID_DESTMAC)	<= ARP2_BC_RX_Meta_DestMACAddress_nxt;
		
		Mirror_Meta_SrcMACAddress_Data					<= to_slvv_8(slm_slice_cols(Mirror_MetaOut_Data, low(MIRROR_META_BITS, MIRROR_META_STREAMID_SRCMAC),	high(MIRROR_META_BITS, MIRROR_META_STREAMID_SRCMAC)));
		Mirror_Meta_DestMACAddress_Data					<= to_slvv_8(slm_slice_cols(Mirror_MetaOut_Data, low(MIRROR_META_BITS, MIRROR_META_STREAMID_DESTMAC), high(MIRROR_META_BITS, MIRROR_META_STREAMID_DESTMAC)));

		-- 
		ARP1 : ENTITY L_Ethernet.ARP_Wrapper
			GENERIC MAP (
				CLOCK_FREQ_MHZ											=> CLOCKIN_FREQ_MHZ,
				INTERFACE_MACADDRESS								=> MAC_CONFIGURATION(0).Interface.Address,
				INITIAL_IPV4ADDRESSES								=> INITIAL_IPV4ADDRESSES_ETH0,
				INITIAL_ARPCACHE_CONTENT						=> INITIAL_ARPCACHE_CONTENT_ETH0,
				APR_REQUEST_TIMEOUT_MS							=> 2000.0
			)
			PORT MAP (					
				Clock																=> Ethernet_Clock,
				Reset																=> Ethernet_Reset,
				
				IPPool_Announce											=> '0',
				
				IPCache_Lookup											=> IPv4_ARP_Query,
--				IPCache_Delayed
				IPCache_IPv4Address_rst							=> ARP1_IPCache_IPv4Address_rst,
				IPCache_IPv4Address_nxt							=> ARP1_IPCache_IPv4Address_nxt,
				IPCache_IPv4Address_Data						=> IPv4_ARP_IPv4Address_Data,
				
				IPCache_Valid												=> ARP1_IPCache_Valid,
--				IPCache_HostUnknown
				IPCache_MACAddress_rst							=> IPv4_ARP_MACAddress_rst,
				IPCache_MACAddress_nxt							=> IPv4_ARP_MACAddress_nxt,
				IPCache_MACAddress_Data							=> ARP1_IPCache_MACAddress_Data,
				
				Eth_UC_TX_Valid											=> ARP1_UC_TX_Valid,
				Eth_UC_TX_Data											=> ARP1_UC_TX_Data,
				Eth_UC_TX_SOF												=> ARP1_UC_TX_SOF,
				Eth_UC_TX_EOF												=> ARP1_UC_TX_EOF,
				Eth_UC_TX_Ready											=> MAC_TX_Ready(ARP1_MAC_UC_PORT_NUMBER),
				Eth_UC_TX_Meta_rst									=> MAC_TX_Meta_rst(ARP1_MAC_UC_PORT_NUMBER),
				Eth_UC_TX_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt(ARP1_MAC_UC_PORT_NUMBER),
				Eth_UC_TX_Meta_DestMACAddress_Data	=> ARP1_UC_TX_Meta_DestMACAddress_Data,
				
				Eth_UC_RX_Valid											=> MAC_RX_Valid(ARP1_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_Data											=> MAC_RX_Data(ARP1_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_SOF												=> MAC_RX_SOF(ARP1_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_EOF												=> MAC_RX_EOF(ARP1_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_Ready											=> ARP1_UC_RX_Ready,
				Eth_UC_RX_Meta_rst									=> ARP1_UC_RX_Meta_rst,
				Eth_UC_RX_Meta_SrcMACAddress_nxt		=> ARP1_UC_RX_Meta_SrcMACAddress_nxt,
				Eth_UC_RX_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(ARP1_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_Meta_DestMACAddress_nxt		=> ARP1_UC_RX_Meta_DestMACAddress_nxt,
				Eth_UC_RX_Meta_DestMACAddress_Data	=> MAC_RX_Meta_DestMACAddress_Data(ARP1_MAC_UC_PORT_NUMBER),
				
				Eth_BC_RX_Valid											=> Mirror_Valid(ARP1_MIRROR_PORT_NUMBER),
				Eth_BC_RX_Data											=> Mirror_Data(ARP1_MIRROR_PORT_NUMBER),
				Eth_BC_RX_SOF												=> Mirror_SOF(ARP1_MIRROR_PORT_NUMBER),
				Eth_BC_RX_EOF												=> Mirror_EOF(ARP1_MIRROR_PORT_NUMBER),
				Eth_BC_RX_Ready											=> ARP1_BC_RX_Ready,
				Eth_BC_RX_Meta_rst									=> ARP1_BC_RX_Meta_rst,
				Eth_BC_RX_Meta_SrcMACAddress_nxt		=> ARP1_BC_RX_Meta_SrcMACAddress_nxt,
				Eth_BC_RX_Meta_SrcMACAddress_Data		=> Mirror_Meta_SrcMACAddress_Data(ARP1_MIRROR_PORT_NUMBER),
				Eth_BC_RX_Meta_DestMACAddress_nxt		=> ARP1_BC_RX_Meta_DestMACAddress_nxt,
				Eth_BC_RX_Meta_DestMACAddress_Data	=> Mirror_Meta_DestMACAddress_Data(ARP1_MIRROR_PORT_NUMBER)
			);
		
		ARP2 : ENTITY L_Ethernet.ARP_Wrapper
			GENERIC MAP (
				CLOCK_FREQ_MHZ											=> CLOCKIN_FREQ_MHZ,
				INTERFACE_MACADDRESS								=> MAC_CONFIGURATION(1).Interface.Address,
				INITIAL_IPV4ADDRESSES								=> INITIAL_IPV4ADDRESSES_ETH1,
				INITIAL_ARPCACHE_CONTENT						=> INITIAL_ARPCACHE_CONTENT_ETH1,
				APR_REQUEST_TIMEOUT_MS							=> 2000.0
			)
			PORT MAP (			
				Clock																=> Ethernet_Clock,
				Reset																=> Ethernet_Reset,
				
				IPPool_Announce											=> '0',
				
				IPCache_Lookup											=> ARP2_Tester_Lookup,
				IPCache_IPv4Address_rst							=> ARP2_IPv4Address_rst,
				IPCache_IPv4Address_nxt							=> ARP2_IPv4Address_nxt,
				IPCache_IPv4Address_Data						=> ARP2_Tester_IPv4Address_Data,
				
				IPCache_Valid												=> ARP2_Valid,
				IPCache_MACAddress_rst							=> ARP2_Tester_MACAddress_rst,
				IPCache_MACAddress_nxt							=> ARP2_Tester_MACAddress_nxt,
				IPCache_MACAddress_Data							=> ARP2_MACAddress_Data,
				
				Eth_UC_TX_Valid											=> ARP2_UC_TX_Valid,
				Eth_UC_TX_Data											=> ARP2_UC_TX_Data,
				Eth_UC_TX_SOF												=> ARP2_UC_TX_SOF,
				Eth_UC_TX_EOF												=> ARP2_UC_TX_EOF,
				Eth_UC_TX_Ready											=> MAC_TX_Ready(ARP2_MAC_UC_PORT_NUMBER),
				Eth_UC_TX_Meta_rst									=> MAC_TX_Meta_rst(ARP2_MAC_UC_PORT_NUMBER),
				Eth_UC_TX_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt(ARP2_MAC_UC_PORT_NUMBER),
				Eth_UC_TX_Meta_DestMACAddress_Data	=> ARP2_UC_TX_Meta_DestMACAddress_Data,
				
				Eth_UC_RX_Valid											=> MAC_RX_Valid(ARP2_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_Data											=> MAC_RX_Data(ARP2_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_SOF												=> MAC_RX_SOF(ARP2_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_EOF												=> MAC_RX_EOF(ARP2_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_Ready											=> ARP2_UC_RX_Ready,
				Eth_UC_RX_Meta_rst									=> ARP2_UC_RX_Meta_rst,
				Eth_UC_RX_Meta_SrcMACAddress_nxt		=> ARP2_UC_RX_Meta_SrcMACAddress_nxt,
				Eth_UC_RX_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(ARP2_MAC_UC_PORT_NUMBER),
				Eth_UC_RX_Meta_DestMACAddress_nxt		=> ARP2_UC_RX_Meta_DestMACAddress_nxt,
				Eth_UC_RX_Meta_DestMACAddress_Data	=> MAC_RX_Meta_DestMACAddress_Data(ARP2_MAC_UC_PORT_NUMBER),
				
				Eth_BC_RX_Valid											=> Mirror_Valid(ARP2_MIRROR_PORT_NUMBER),
				Eth_BC_RX_Data											=> Mirror_Data(ARP2_MIRROR_PORT_NUMBER),
				Eth_BC_RX_SOF												=> Mirror_SOF(ARP2_MIRROR_PORT_NUMBER),
				Eth_BC_RX_EOF												=> Mirror_EOF(ARP2_MIRROR_PORT_NUMBER),
				Eth_BC_RX_Ready											=> ARP2_BC_RX_Ready,
				Eth_BC_RX_Meta_rst									=> ARP2_BC_RX_Meta_rst,
				Eth_BC_RX_Meta_SrcMACAddress_nxt		=> ARP2_BC_RX_Meta_SrcMACAddress_nxt,
				Eth_BC_RX_Meta_SrcMACAddress_Data		=> Mirror_Meta_SrcMACAddress_Data(ARP2_MIRROR_PORT_NUMBER),
				Eth_BC_RX_Meta_DestMACAddress_nxt		=> ARP2_BC_RX_Meta_DestMACAddress_nxt,
				Eth_BC_RX_Meta_DestMACAddress_Data	=> Mirror_Meta_DestMACAddress_Data(ARP2_MIRROR_PORT_NUMBER)
			);

		ARP2_Tester : ENTITY L_Ethernet.ARP_Tester
			GENERIC MAP (
				CLOCK_FREQ_MHZ											=> CLOCKIN_FREQ_MHZ,
				ARP_LOOKUP_INTERVAL_MS							=> 8100.0				-- 100 ms
			)
			PORT MAP (					
				Clock																=> Ethernet_Clock,
				Reset																=> Ethernet_Reset,
				
				Command															=> NET_ARP_TESTER_CMD_LOOP,
				Status															=> OPEN,
				
				IPCache_Lookup											=> ARP2_Tester_Lookup,
				IPCache_IPv4Address_rst							=> ARP2_IPv4Address_rst,
				IPCache_IPv4Address_nxt							=> ARP2_IPv4Address_nxt,
				IPCache_IPv4Address_Data						=> ARP2_Tester_IPv4Address_Data,
				
				IPCache_Valid												=> ARP2_Valid,
				IPCache_MACAddress_rst							=> ARP2_Tester_MACAddress_rst,
				IPCache_MACAddress_nxt							=> ARP2_Tester_MACAddress_nxt,
				IPCache_MACAddress_Data							=> ARP2_MACAddress_Data
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
		
		SIGNAL blk_RX_Ready													: STD_LOGIC_VECTOR(IPV4_PORTS - 1 DOWNTO 0);
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
		
		SIGNAL ICMPv4_Command												: T_NET_ICMPV4_COMMAND;
		SIGNAL ICMPv4_Status												: T_NET_ICMPV4_STATUS;
		SIGNAL ICMPv4_Error													: T_NET_ICMPV4_ERROR;
		
		SIGNAL ICMPv4_TX_Valid											: STD_LOGIC;
		SIGNAL ICMPv4_TX_Data												: T_SLV_8;
		SIGNAL ICMPv4_TX_SOF												: STD_LOGIC;
		SIGNAL ICMPv4_TX_EOF												: STD_LOGIC;
		SIGNAL ICMPv4_TX_Meta_SrcIPv4Address_Data		: T_SLV_8;
		SIGNAL ICMPv4_TX_Meta_DestIPv4Address_Data	: T_SLV_8;
		SIGNAL ICMPv4_TX_Meta_Length								: T_SLV_16;
		
		SIGNAL ICMPv4_RX_Ready											: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_rst										: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_DestMACAddress_nxt		: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_SrcIPv4Address_nxt		: STD_LOGIC;
		SIGNAL ICMPv4_RX_Meta_DestIPv4Address_nxt		: STD_LOGIC;
		
		SIGNAL ICMPv4_IPv4Address_rst								: STD_LOGIC;
		SIGNAL ICMPv4_IPv4Address_nxt								: STD_LOGIC;
		SIGNAL EchoReqIPv4Seq_IPv4Address_Data			: T_SLV_8;
		
		SIGNAL Loop3_TX_Valid												: STD_LOGIC;
		SIGNAL Loop3_TX_Data												: T_SLV_8;
		SIGNAL Loop3_TX_SOF													: STD_LOGIC;
		SIGNAL Loop3_TX_EOF													: STD_LOGIC;
		SIGNAL Loop3_TX_Meta_SrcIPv4Address_Data		: T_SLV_8;
		SIGNAL Loop3_TX_Meta_DestIPv4Address_Data		: T_SLV_8;
		SIGNAL Loop3_TX_Meta_Length									: T_SLV_16;
		
		SIGNAL Loop3_TX_Meta_rst										: STD_LOGIC;
		SIGNAL Loop3_TX_Meta_SrcIPv4Address_nxt			: STD_LOGIC;
		SIGNAL Loop3_TX_Meta_DestIPv4Address_nxt		: STD_LOGIC;
		
		SIGNAL Loop3_RX_Ready												: STD_LOGIC;
		SIGNAL Loop3_RX_Meta_rst										: STD_LOGIC;
		SIGNAL Loop3_RX_Meta_SrcIPv4Address_nxt			: STD_LOGIC;
		SIGNAL Loop3_RX_Meta_DestIPv4Address_nxt		: STD_LOGIC;
		
	BEGIN
		IPv4 : ENTITY L_Ethernet.IPv4_Wrapper
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
				MAC_TX_Ready											=> MAC_TX_Ready(IPV4_MAC_PORT_NUMBER),
				MAC_TX_Meta_rst										=> MAC_TX_Meta_rst(IPV4_MAC_PORT_NUMBER),
				MAC_TX_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt(IPV4_MAC_PORT_NUMBER),
				MAC_TX_Meta_DestMACAddress_Data		=> IPv4_TX_Meta_DestMACAddress_Data,
				
				MAC_RX_Valid											=> MAC_RX_Valid(IPV4_MAC_PORT_NUMBER),
				MAC_RX_Data												=> MAC_RX_Data(IPV4_MAC_PORT_NUMBER),
				MAC_RX_SOF												=> MAC_RX_SOF(IPV4_MAC_PORT_NUMBER),
				MAC_RX_EOF												=> MAC_RX_EOF(IPV4_MAC_PORT_NUMBER),
				MAC_RX_Ready											=> IPv4_RX_Ready,
				MAC_RX_Meta_rst										=> IPv4_RX_Meta_rst,
				MAC_RX_Meta_SrcMACAddress_nxt			=> IPv4_RX_Meta_SrcMACAddress_nxt,
				MAC_RX_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(IPV4_MAC_PORT_NUMBER),
				MAC_RX_Meta_DestMACAddress_nxt		=> IPv4_RX_Meta_DestMACAddress_nxt,
				MAC_RX_Meta_DestMACAddress_Data		=> MAC_RX_Meta_DestMACAddress_Data(IPV4_MAC_PORT_NUMBER),
				MAC_RX_Meta_EthType								=> to_slv(MAC_RX_Meta_EthType(IPV4_MAC_PORT_NUMBER)),
				
				ARP_IPCache_Query									=> IPv4_ARP_Query,
				ARP_IPCache_IPv4Address_rst				=> ARP1_IPCache_IPv4Address_rst,
				ARP_IPCache_IPv4Address_nxt				=> ARP1_IPCache_IPv4Address_nxt,
				ARP_IPCache_IPv4Address_Data			=> IPv4_ARP_IPv4Address_Data,
				
				ARP_IPCache_Valid									=> ARP1_IPCache_Valid,
				ARP_IPCache_MACAddress_rst				=> IPv4_ARP_MACAddress_rst,
				ARP_IPCache_MACAddress_nxt				=> IPv4_ARP_MACAddress_nxt,
				ARP_IPCache_MACAddress_Data				=> ARP1_IPCache_MACAddress_Data,
				
				TX_Valid													=> blk_TX_Valid,
				TX_Data														=> blk_TX_Data,
				TX_SOF														=> blk_TX_SOF,
				TX_EOF														=> blk_TX_EOF,
				TX_Ready													=> IPv4_TX_Ready,
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
				RX_Ready													=> blk_RX_Ready,
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
		blk_TX_Valid(ICMPV4_IPV4_PORT_NUMBER)											<= ICMPv4_TX_Valid;
		blk_TX_Data(ICMPV4_IPV4_PORT_NUMBER)											<= ICMPv4_TX_Data;
		blk_TX_SOF(ICMPV4_IPV4_PORT_NUMBER)												<= ICMPv4_TX_SOF;
		blk_TX_EOF(ICMPV4_IPV4_PORT_NUMBER)												<= ICMPv4_TX_EOF;
		blk_TX_Meta_SrcIPv4Address_Data(ICMPV4_IPV4_PORT_NUMBER)	<= ICMPv4_TX_Meta_SrcIPv4Address_Data;
		blk_TX_Meta_DestIPv4Address_Data(ICMPV4_IPV4_PORT_NUMBER)	<= ICMPv4_TX_Meta_DestIPv4Address_Data;
		blk_TX_Meta_Length(ICMPV4_IPV4_PORT_NUMBER)								<= ICMPv4_TX_Meta_Length;
		
		blk_RX_Ready(ICMPV4_IPV4_PORT_NUMBER)											<= ICMPv4_RX_Ready;
		blk_RX_Meta_rst(ICMPV4_IPV4_PORT_NUMBER)									<= ICMPv4_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(ICMPV4_IPV4_PORT_NUMBER)		<= ICMPv4_RX_Meta_SrcMACAddress_nxt;
		blk_RX_Meta_DestMACAddress_nxt(ICMPV4_IPV4_PORT_NUMBER)		<= ICMPv4_RX_Meta_DestMACAddress_nxt;
		blk_RX_Meta_SrcIPv4Address_nxt(ICMPV4_IPV4_PORT_NUMBER)		<= ICMPv4_RX_Meta_SrcIPv4Address_nxt;
		blk_RX_Meta_DestIPv4Address_nxt(ICMPV4_IPV4_PORT_NUMBER)	<= ICMPv4_RX_Meta_DestIPv4Address_nxt;
		
		-- IPv4 Port 1 - UDPv4
		blk_TX_Valid(UDPV4_IPV4_PORT_NUMBER)											<= UDPv4_TX_Valid;
		blk_TX_Data(UDPV4_IPV4_PORT_NUMBER)												<= UDPv4_TX_Data;
		blk_TX_SOF(UDPV4_IPV4_PORT_NUMBER)												<= UDPv4_TX_SOF;
		blk_TX_EOF(UDPV4_IPV4_PORT_NUMBER)												<= UDPv4_TX_EOF;
		blk_TX_Meta_SrcIPv4Address_Data(UDPV4_IPV4_PORT_NUMBER)		<= UDPv4_TX_Meta_SrcIPv4Address_Data;
		blk_TX_Meta_DestIPv4Address_Data(UDPV4_IPV4_PORT_NUMBER)	<= UDPv4_TX_Meta_DestIPv4Address_Data;
		blk_TX_Meta_Length(UDPV4_IPV4_PORT_NUMBER)								<= UDPv4_TX_Meta_Length;
		
		blk_RX_Ready(UDPV4_IPV4_PORT_NUMBER)											<= UDPv4_RX_Ready;
		blk_RX_Meta_rst(UDPV4_IPV4_PORT_NUMBER)										<= UDPv4_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(UDPV4_IPV4_PORT_NUMBER)			<= UDPv4_RX_Meta_SrcMACAddress_nxt;
		blk_RX_Meta_DestMACAddress_nxt(UDPV4_IPV4_PORT_NUMBER)		<= UDPv4_RX_Meta_DestMACAddress_nxt;
		blk_RX_Meta_SrcIPv4Address_nxt(UDPV4_IPV4_PORT_NUMBER)		<= UDPv4_RX_Meta_SrcIPv4Address_nxt;
		blk_RX_Meta_DestIPv4Address_nxt(UDPV4_IPV4_PORT_NUMBER)		<= UDPv4_RX_Meta_DestIPv4Address_nxt;

		-- IPv4 Port 2 - Loopback
		blk_TX_Valid(LOOP3_IPV4_PORT_NUMBER)											<= Loop3_TX_Valid;
		blk_TX_Data(LOOP3_IPV4_PORT_NUMBER)												<= Loop3_TX_Data;
		blk_TX_SOF(LOOP3_IPV4_PORT_NUMBER)												<= Loop3_TX_SOF;
		blk_TX_EOF(LOOP3_IPV4_PORT_NUMBER)												<= Loop3_TX_EOF;
		blk_TX_Meta_SrcIPv4Address_Data(LOOP3_IPV4_PORT_NUMBER)		<= Loop3_TX_Meta_SrcIPv4Address_Data;
		blk_TX_Meta_DestIPv4Address_Data(LOOP3_IPV4_PORT_NUMBER)	<= Loop3_TX_Meta_DestIPv4Address_Data;
		blk_TX_Meta_Length(LOOP3_IPV4_PORT_NUMBER)								<= Loop3_TX_Meta_Length;
		
		blk_RX_Ready(LOOP3_IPV4_PORT_NUMBER)											<= Loop3_RX_Ready;
		blk_RX_Meta_rst(LOOP3_IPV4_PORT_NUMBER)										<= Loop3_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(LOOP3_IPV4_PORT_NUMBER)			<= '0';
		blk_RX_Meta_DestMACAddress_nxt(LOOP3_IPV4_PORT_NUMBER)		<= '0';
		blk_RX_Meta_SrcIPv4Address_nxt(LOOP3_IPV4_PORT_NUMBER)		<= Loop3_RX_Meta_SrcIPv4Address_nxt;
		blk_RX_Meta_DestIPv4Address_nxt(LOOP3_IPV4_PORT_NUMBER)		<= Loop3_RX_Meta_DestIPv4Address_nxt;
	
		ICMPv4 : ENTITY L_Ethernet.ICMPv4_Wrapper
			GENERIC MAP (
				DEBUG										=> DEBUG,
				SOURCE_IPV4ADDRESS								=> INITIAL_IPV4ADDRESSES_ETH0(0)
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
				IP_TX_Ready												=> IPv4_TX_Ready(ICMPV4_IPV4_PORT_NUMBER),
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
				IP_RX_Ready												=> ICMPv4_RX_Ready,
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

				IPv4Address_rst										=> ICMPv4_IPv4Address_rst,
				IPv4Address_nxt										=> ICMPv4_IPv4Address_nxt,
				IPv4Address_Data									=> EchoReqIPv4Seq_IPv4Address_Data
			);
		
		EchoReqIPv4Seq : ENTITY L_Global.Sequenzer
			GENERIC MAP (
				INPUT_BITS						=> 32,
				OUTPUT_BITS						=> 8,
				REGISTERED						=> FALSE
			)
			PORT MAP (
				Clock									=> Ethernet_Clock,
				Reset									=> Ethernet_Reset,
				
				Input									=> to_slv(to_net_ipv4_address("192.168.10.1")),
				rst										=> ICMPv4_IPv4Address_rst,
				rev										=> '1',
				nxt										=> ICMPv4_IPv4Address_nxt,
				Output								=> EchoReqIPv4Seq_IPv4Address_Data
			);
		
		blkTick : BLOCk
			SIGNAL Tick																: STD_LOGIC;
			ATTRIBUTE KEEP OF Tick										: SIGNAL IS TRUE;
			
			CONSTANT ICMPV4_ECHO_REQUEST_INTERVAL_MS	: REAL							:= 2000.0;
		BEGIN
			ASSERT FALSE REPORT "TICKCOUNTER_MAX: " & INTEGER'image(TimingToCycles_ms(ICMPV4_ECHO_REQUEST_INTERVAL_MS, Freq_MHz2Real_ns(CLOCKIN_FREQ_MHZ))) & "    ICMPV4_ECHO_REQUEST_INTERVAL_MS: " & REAL'image(ICMPV4_ECHO_REQUEST_INTERVAL_MS) & " ms" SEVERITY NOTE;
		
				-- lookup interval tick generator
			PROCESS(Ethernet_Clock)
				CONSTANT TICKCOUNTER_RES_MS							: REAL																								:= ICMPV4_ECHO_REQUEST_INTERVAL_MS;
				CONSTANT TICKCOUNTER_MAX								: POSITIVE																						:= TimingToCycles_ms(TICKCOUNTER_RES_MS, Freq_MHz2Real_ns(CLOCKIN_FREQ_MHZ));
				CONSTANT TICKCOUNTER_BITS								: POSITIVE																						:= log2ceilnz(TICKCOUNTER_MAX);
			
				VARIABLE TickCounter_s									: SIGNED(TICKCOUNTER_BITS DOWNTO 0)										:= to_signed(TICKCOUNTER_MAX, TICKCOUNTER_BITS + 1);
			BEGIN
				IF rising_edge(Ethernet_Clock) THEN
					IF (Tick = '1') THEN
						TickCounter_s		:= to_signed(TICKCOUNTER_MAX, TickCounter_s'length);
					ELSE
						TickCounter_s		:= TickCounter_s - 1;
					END IF;
				END IF;
				
				Tick						<= TickCounter_s(TickCounter_s'high);
			END PROCESS;
			
			ICMPv4_Command		<= NET_ICMPV4_CMD_ECHO_REQUEST WHEN (Tick = '1') ELSE NET_ICMPV4_CMD_NONE;
		END BLOCK;
		
		Loop3 : ENTITY L_Ethernet.IPv4_FrameLoopback
			GENERIC MAP (
				MAX_FRAMES										=> 4
			)
			PORT MAP (
				Clock													=> Ethernet_Clock,
				Reset													=> Ethernet_Reset,
				
				In_Valid											=> IPv4_RX_Valid(LOOP3_IPV4_PORT_NUMBER),
				In_Data												=> IPv4_RX_Data(LOOP3_IPV4_PORT_NUMBER),
				In_SOF												=> IPv4_RX_SOF(LOOP3_IPV4_PORT_NUMBER),
				In_EOF												=> IPv4_RX_EOF(LOOP3_IPV4_PORT_NUMBER),
				In_Ready											=> Loop3_RX_Ready,
				In_Meta_rst										=> Loop3_RX_Meta_rst,
				In_Meta_SrcIPv4Address_nxt		=> Loop3_RX_Meta_SrcIPv4Address_nxt,
				In_Meta_SrcIPv4Address_Data		=> IPv4_RX_Meta_SrcIPv4Address_Data(LOOP3_IPV4_PORT_NUMBER),
				In_Meta_DestIPv4Address_nxt		=> Loop3_RX_Meta_DestIPv4Address_nxt,
				In_Meta_DestIPv4Address_Data	=> IPv4_RX_Meta_DestIPv4Address_Data(LOOP3_IPV4_PORT_NUMBER),
				In_Meta_Length								=> IPv4_RX_Meta_Length(LOOP3_IPV4_PORT_NUMBER),

				Out_Valid											=> Loop3_TX_Valid,
				Out_Data											=> Loop3_TX_Data,
				Out_SOF												=> Loop3_TX_SOF,
				Out_EOF												=> Loop3_TX_EOF,
				Out_Ready											=> IPv4_TX_Ready(LOOP3_IPV4_PORT_NUMBER),
				Out_Meta_rst									=> IPv4_TX_Meta_rst(LOOP3_IPV4_PORT_NUMBER),
				Out_Meta_SrcIPv4Address_nxt		=> IPv4_TX_Meta_SrcIPv4Address_nxt(LOOP3_IPV4_PORT_NUMBER),
				Out_Meta_SrcIPv4Address_Data	=> Loop3_TX_Meta_SrcIPv4Address_Data,
				Out_Meta_DestIPv4Address_nxt	=> IPv4_TX_Meta_DestIPv4Address_nxt(LOOP3_IPV4_PORT_NUMBER),
				Out_Meta_DestIPv4Address_Data	=> Loop3_TX_Meta_DestIPv4Address_Data,
				Out_Meta_Length								=> Loop3_TX_Meta_Length
			);
	END BLOCK;
	
	blkUDPv4 : BLOCK
		SIGNAL blk_TX_Valid													: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Data													: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_SOF														: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_EOF														: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_rst											: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_SrcIPv4Address_Data			: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_DestIPv4Address_Data			: T_SLVV_8(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_Length										: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_SrcPort									: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_DestPort									: T_SLVV_16(UDPV4_PORTS - 1 DOWNTO 0);
		
		SIGNAL blk_RX_Ready													: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_rst											: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcMACAddress_nxt				: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestMACAddress_nxt				: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcIPv4Address_nxt				: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestIPv4Address_nxt			: STD_LOGIC_VECTOR(UDPV4_PORTS - 1 DOWNTO 0);
		
		SIGNAL Loop6_TX_Valid												: STD_LOGIC;
		SIGNAL Loop6_TX_Data												: T_SLV_8;
		SIGNAL Loop6_TX_SOF													: STD_LOGIC;
		SIGNAL Loop6_TX_EOF													: STD_LOGIC;
		SIGNAL Loop6_TX_Meta_SrcIPv4Address_Data		: T_SLV_8;
		SIGNAL Loop6_TX_Meta_DestIPv4Address_Data		: T_SLV_8;
		SIGNAL Loop6_TX_Meta_Length									: T_SLV_16;
		SIGNAL Loop6_TX_Meta_SrcPort								: T_SLV_16;
		SIGNAL Loop6_TX_Meta_DestPort								: T_SLV_16;
		
		SIGNAL Loop6_TX_Meta_rst										: STD_LOGIC;
		SIGNAL Loop6_TX_Meta_SrcIPv4Address_nxt			: STD_LOGIC;
		SIGNAL Loop6_TX_Meta_DestIPv4Address_nxt		: STD_LOGIC;
		
		SIGNAL Loop6_RX_Ready												: STD_LOGIC;
		SIGNAL Loop6_RX_Meta_rst										: STD_LOGIC;
		SIGNAL Loop6_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
		SIGNAL Loop6_RX_Meta_DestMACAddress_nxt			: STD_LOGIC;
		SIGNAL Loop6_RX_Meta_SrcIPv4Address_nxt			: STD_LOGIC;
		SIGNAL Loop6_RX_Meta_DestIPv4Address_nxt		: STD_LOGIC;
		
	BEGIN
		UDP : ENTITY L_Ethernet.UDP_Wrapper
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
				IP_TX_Ready												=> IPv4_TX_Ready(UDPV4_IPV4_PORT_NUMBER),
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
				IP_RX_Ready												=> UDPv4_RX_Ready,
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
				TX_Ready													=> UDPv4_TX_Ready,
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
				RX_Ready													=> blk_RX_Ready,
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
		
		-- UDPv4 Port 0 - LoopBack
		blk_TX_Valid(LOOP6_UDPV4_PORT_NUMBER)													<= Loop6_TX_Valid;
		blk_TX_Data(LOOP6_UDPV4_PORT_NUMBER)													<= Loop6_TX_Data;
		blk_TX_SOF(LOOP6_UDPV4_PORT_NUMBER)														<= Loop6_TX_SOF;
		blk_TX_EOF(LOOP6_UDPV4_PORT_NUMBER)														<= Loop6_TX_EOF;
		blk_TX_Meta_SrcIPv4Address_Data(LOOP6_UDPV4_PORT_NUMBER)			<= Loop6_TX_Meta_SrcIPv4Address_Data;
		blk_TX_Meta_DestIPv4Address_Data(LOOP6_UDPV4_PORT_NUMBER)			<= Loop6_TX_Meta_DestIPv4Address_Data;
--		blk_TX_Meta_TrafficClass(LOOP6_UDPV4_PORT_NUMBER)							<= (OTHERS => '0');
--		blk_TX_Meta_FlowLabel(LOOP6_UDPV4_PORT_NUMBER)								<= (OTHERS => '0');
		blk_TX_Meta_Length(LOOP6_UDPV4_PORT_NUMBER)										<= Loop6_TX_Meta_Length;
		blk_TX_Meta_SrcPort(LOOP6_UDPV4_PORT_NUMBER)									<= Loop6_TX_Meta_SrcPort;
		blk_TX_Meta_DestPort(LOOP6_UDPV4_PORT_NUMBER)									<= Loop6_TX_Meta_DestPort;
				
		blk_RX_Ready(LOOP6_UDPV4_PORT_NUMBER)													<= Loop6_RX_Ready;
		blk_RX_Meta_rst(LOOP6_UDPV4_PORT_NUMBER)											<= Loop6_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(LOOP6_UDPV4_PORT_NUMBER)				<= '0';
		blk_RX_Meta_DestMACAddress_nxt(LOOP6_UDPV4_PORT_NUMBER)				<= '0';
		blk_RX_Meta_SrcIPv4Address_nxt(LOOP6_UDPV4_PORT_NUMBER)				<= Loop6_RX_Meta_SrcIPv4Address_nxt;
		blk_RX_Meta_DestIPv4Address_nxt(LOOP6_UDPV4_PORT_NUMBER)			<= Loop6_RX_Meta_DestIPv4Address_nxt;
		
		-- UDPv4 Port 1 - UDPGen
		blk_TX_Valid(UDPGENV4_UDPV4_PORT_NUMBER)											<= UDPGENv4_TX_Valid;
		blk_TX_Data(UDPGENV4_UDPV4_PORT_NUMBER)												<= UDPGENv4_TX_Data;
		blk_TX_SOF(UDPGENV4_UDPV4_PORT_NUMBER)												<= UDPGENv4_TX_SOF;
		blk_TX_EOF(UDPGENV4_UDPV4_PORT_NUMBER)												<= UDPGENv4_TX_EOF;
		blk_TX_Meta_SrcIPv4Address_Data(UDPGENV4_UDPV4_PORT_NUMBER)		<= UDPGENv4_TX_Meta_SrcIPv4Address_Data;
		blk_TX_Meta_DestIPv4Address_Data(UDPGENV4_UDPV4_PORT_NUMBER)	<= UDPGENv4_TX_Meta_DestIPv4Address_Data;
--		blk_TX_Meta_TrafficClass(UDPGENV4_UDPV4_PORT_NUMBER)					<= (OTHERS => '0');
--		blk_TX_Meta_FlowLabel(UDPGENV4_UDPV4_PORT_NUMBER)							<= (OTHERS => '0');
		blk_TX_Meta_Length(UDPGENV4_UDPV4_PORT_NUMBER)								<= UDPGENv4_TX_Meta_Length;
		blk_TX_Meta_SrcPort(UDPGENV4_UDPV4_PORT_NUMBER)								<= UDPGENv4_TX_Meta_SrcPort;
		blk_TX_Meta_DestPort(UDPGENV4_UDPV4_PORT_NUMBER)							<= UDPGENv4_TX_Meta_DestPort;
		
		blk_RX_Ready(UDPGENV4_UDPV4_PORT_NUMBER)											<= UDPGENv4_RX_Ready;
		blk_RX_Meta_rst(UDPGENV4_UDPV4_PORT_NUMBER)										<= UDPGENv4_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(UDPGENV4_UDPV4_PORT_NUMBER)			<= UDPGENv4_RX_Meta_SrcMACAddress_nxt;
		blk_RX_Meta_DestMACAddress_nxt(UDPGENV4_UDPV4_PORT_NUMBER)		<= UDPGENv4_RX_Meta_DestMACAddress_nxt;
		blk_RX_Meta_SrcIPv4Address_nxt(UDPGENV4_UDPV4_PORT_NUMBER)		<= UDPGENv4_RX_Meta_SrcIPv4Address_nxt;
		blk_RX_Meta_DestIPv4Address_nxt(UDPGENV4_UDPV4_PORT_NUMBER)		<= UDPGENv4_RX_Meta_DestIPv4Address_nxt;
		
		Loop6 : ENTITY L_Ethernet.UDP_FrameLoopback
			GENERIC MAP (
				IP_VERSION										=> 4,
				MAX_FRAMES										=> 4
			)
			PORT MAP (
				Clock													=> Ethernet_Clock,
				Reset													=> Ethernet_Reset,
				
				In_Valid											=> UDPv4_RX_Valid(LOOP6_UDPV4_PORT_NUMBER),
				In_Data												=> UDPv4_RX_Data(LOOP6_UDPV4_PORT_NUMBER),
				In_SOF												=> UDPv4_RX_SOF(LOOP6_UDPV4_PORT_NUMBER),
				In_EOF												=> UDPv4_RX_EOF(LOOP6_UDPV4_PORT_NUMBER),
				In_Ready											=> Loop6_RX_Ready,
				In_Meta_rst										=> Loop6_RX_Meta_rst,
				In_Meta_SrcIPAddress_nxt			=> Loop6_RX_Meta_SrcIPv4Address_nxt,
				In_Meta_SrcIPAddress_Data			=> UDPv4_RX_Meta_SrcIPv4Address_Data(LOOP6_UDPV4_PORT_NUMBER),
				In_Meta_DestIPAddress_nxt			=> Loop6_RX_Meta_DestIPv4Address_nxt,
				In_Meta_DestIPAddress_Data		=> UDPv4_RX_Meta_DestIPv4Address_Data(LOOP6_UDPV4_PORT_NUMBER),
--				In_Meta_Length								=> UDPv4_RX_Meta_Length(LOOP6_UDPV4_PORT_NUMBER),
				In_Meta_SrcPort								=> UDPv4_RX_Meta_SrcPort(LOOP6_UDPV4_PORT_NUMBER),
				In_Meta_DestPort							=> UDPv4_RX_Meta_DestPort(LOOP6_UDPV4_PORT_NUMBER),

				Out_Valid											=> Loop6_TX_Valid,
				Out_Data											=> Loop6_TX_Data,
				Out_SOF												=> Loop6_TX_SOF,
				Out_EOF												=> Loop6_TX_EOF,
				Out_Ready											=> UDPv4_TX_Ready(LOOP6_UDPV4_PORT_NUMBER),
				Out_Meta_rst									=> UDPv4_TX_Meta_rst(LOOP6_UDPV4_PORT_NUMBER),
				Out_Meta_SrcIPAddress_nxt			=> UDPv4_TX_Meta_SrcIPv4Address_nxt(LOOP6_UDPV4_PORT_NUMBER),
				Out_Meta_SrcIPAddress_Data		=> Loop6_TX_Meta_SrcIPv4Address_Data,
				Out_Meta_DestIPAddress_nxt		=> UDPv4_TX_Meta_DestIPv4Address_nxt(LOOP6_UDPV4_PORT_NUMBER),
				Out_Meta_DestIPAddress_Data		=> Loop6_TX_Meta_DestIPv4Address_Data,
--				Out_Meta_Length								=> Loop6_TX_Meta_Length,
				Out_Meta_SrcPort							=> Loop6_TX_Meta_SrcPort,
				Out_Meta_DestPort							=> Loop6_TX_Meta_DestPort
			);
	END BLOCK;
	
	blkUDPGENv4 : BLOCK
		CONSTANT FRAMEGROUPS										: T_FRAMEGEN_FRAMEGROUP_VECTOR_8										:= GenUDPFrameGenerator_Frames;
		
		SIGNAL Eth_Status_d											: T_NET_ETH_STATUS																	:= NET_ETH_STATUS_RESETING;
		SIGNAL NewConnection										: STD_LOGIC;
		
		SIGNAL UDPGen_Command										: T_FRAMEGEN_COMMAND;
		SIGNAL UDPGen_Status										: T_FRAMEGEN_STATUS;
		
		SIGNAL UDPGen_TX_Valid									: STD_LOGIC;
		SIGNAL UDPGen_TX_Data										: T_SLV_8;
		SIGNAL UDPGen_TX_SOF										: STD_LOGIC;
		SIGNAL UDPGen_TX_EOF										: STD_LOGIC;
		
	BEGIN
		
		Eth_Status_d	<= Eth_Status WHEN rising_edge(Ethernet_Clock);
		NewConnection	<= to_sl((Eth_Status_d /= NET_ETH_STATUS_CONNECTED) AND (Eth_Status = NET_ETH_STATUS_CONNECTED));
	
		PROCESS(NewConnection)
		BEGIN
			IF (NewConnection = '1') THEN
				UDPGen_Command			<= FRAMEGEN_CMD_SEQUENCE;
			ELSE
				UDPGen_Command			<= FRAMEGEN_CMD_NONE;
			END IF;
		END PROCESS;
	
		UDPGen : ENTITY L_Global.LocalLink_FrameGenerator
			GENERIC MAP (
				DATA_BITS							=> 8,
				WORD_BITS							=> 8,
				APPEND								=> FRAMEGEN_APP_NONE,
				FRAMEGROUPS						=> FRAMEGROUPS
			)
			PORT MAP (
				Clock									=> Ethernet_Clock,
				Reset									=> Ethernet_Reset,
				
				Command								=> UDPGen_Command,
				Status								=> UDPGen_Status,
				
				Pause									=> to_slv( 0, 16),
				
				FrameGroupIndex				=> (OTHERS => '0'),
				FrameIndex						=> (OTHERS => '0'),
				
				Sequences							=> to_slv(16, 16),
				FrameLength						=> to_slv(UDPGENV4_PACKET_LENGTH, 16),
				
				Out_Valid							=> UDPGENv4_TX_Valid,
				Out_Data							=> UDPGENv4_TX_Data,
				Out_SOF								=> UDPGENv4_TX_SOF,
				Out_EOF								=> UDPGENv4_TX_EOF,
				Out_Ready							=> UDPv4_TX_Ready(UDPGENV4_UDPV4_PORT_NUMBER)
			);

		UDPGENv4_TX_Meta_Length								<= x"0000";		-- 0 means unknown length => calculate in FCS
		UDPGENv4_TX_Meta_SrcPort							<= UDPV4_PORTPAIRS(UDPGENV4_UDPV4_PORT_NUMBER).Egress;
		UDPGENv4_TX_Meta_DestPort							<= UDPV4_PORTPAIRS(UDPGENV4_UDPV4_PORT_NUMBER).Ingress;
	
		UDPGENv4_RX_Ready											<= '1';
		UDPGENv4_RX_Meta_rst									<= '0';
		UDPGENv4_RX_Meta_SrcMACAddress_nxt		<= '0';
		UDPGENv4_RX_Meta_DestMACAddress_nxt		<= '0';
		UDPGENv4_RX_Meta_SrcIPv4Address_nxt		<= '0';
		UDPGENv4_RX_Meta_DestIPv4Address_nxt	<= '0';

		SrcIPv4Seq : ENTITY L_Global.Sequenzer
			GENERIC MAP (
				INPUT_BITS						=> 32,
				OUTPUT_BITS						=> 8,
				REGISTERED						=> FALSE
			)
			PORT MAP (
				Clock									=> Ethernet_Clock,
				Reset									=> Ethernet_Reset,
				
				Input									=> to_slv(to_net_ipv4_address("192.168.10.10")),
				rst										=> UDPv4_TX_Meta_rst(UDPGENV4_UDPV4_PORT_NUMBER),
				rev										=> '1',
				nxt										=> UDPv4_TX_Meta_SrcIPv4Address_nxt(UDPGENV4_UDPV4_PORT_NUMBER),
				Output								=> UDPGENv4_TX_Meta_SrcIPv4Address_Data
			);

		DestIPv4Seq : ENTITY L_Global.Sequenzer
			GENERIC MAP (
				INPUT_BITS						=> 32,
				OUTPUT_BITS						=> 8,
				REGISTERED						=> FALSE
			)
			PORT MAP (
				Clock									=> Ethernet_Clock,
				Reset									=> Ethernet_Reset,
				
				Input									=> to_slv(to_net_ipv4_address("192.168.10.1")),
				rst										=> UDPv4_TX_Meta_rst(UDPGENV4_UDPV4_PORT_NUMBER),
				rev										=> '1',
				nxt										=> UDPv4_TX_Meta_DestIPv4Address_nxt(UDPGENV4_UDPV4_PORT_NUMBER),
				Output								=> UDPGENv4_TX_Meta_DestIPv4Address_Data
			);

	END BLOCK;	-- blkUDPGENv4
	
	blkIPv6 : BLOCK
		ATTRIBUTE KEEP_HIERARCHY OF IPv6						: LABEL IS "FALSE";	
		ATTRIBUTE KEEP_HIERARCHY OF ICMPv6					: LABEL IS "FALSE";	
		ATTRIBUTE KEEP_HIERARCHY OF NDP							: LABEL IS "FALSE";	
		
		SIGNAL blk_TX_Valid													: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Data													: T_SLVV_8(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_SOF														: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_EOF														: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_rst											: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_SrcIPv6Address_Data			: T_SLVV_8(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_DestIPv6Address_Data			: T_SLVV_8(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_TrafficClass							: T_SLVV_8(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_FlowLabel								: T_SLVV_24(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_Length										: T_SLVV_16(IPV6_PORTS - 1 DOWNTO 0);
		
		SIGNAL blk_RX_Ready													: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_rst											: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcMACAddress_nxt				: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestMACAddress_nxt				: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcIPv6Address_nxt				: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestIPv6Address_nxt			: STD_LOGIC_VECTOR(IPV6_PORTS - 1 DOWNTO 0);
		
		SIGNAL blk_NextHop_Query										: STD_LOGIC;
		SIGNAL blk_NextHop_IPv6Address_Data					: T_SLV_8;
		SIGNAL blk_NextHop_IPv6Address_rst					: STD_LOGIC;
		SIGNAL blk_NextHop_IPv6Address_nxt					: STD_LOGIC;
		SIGNAL blk_NextHop_Valid										: STD_LOGIC;
		SIGNAL blk_NextHop_MACAddress_Data					: T_SLV_8;
		SIGNAL blk_NextHop_MACAddress_rst						: STD_LOGIC;
		SIGNAL blk_NextHop_MACAddress_nxt						: STD_LOGIC;
		
		SIGNAL ICMPv6_TX_Valid											: STD_LOGIC;
		SIGNAL ICMPv6_TX_Data												: T_SLV_8;
		SIGNAL ICMPv6_TX_SOF												: STD_LOGIC;
		SIGNAL ICMPv6_TX_EOF												: STD_LOGIC;
		SIGNAL ICMPv6_TX_Meta_SrcIPv6Address_Data		: T_SLV_8;
		SIGNAL ICMPv6_TX_Meta_DestIPv6Address_Data	: T_SLV_8;
		SIGNAL ICMPv6_TX_Meta_Length								: T_SLV_16;
		
		SIGNAL ICMPv6_RX_Ready											: STD_LOGIC;
		SIGNAL ICMPv6_RX_Meta_rst										: STD_LOGIC;
		SIGNAL ICMPv6_RX_Meta_SrcMACAddress_nxt			: STD_LOGIC;
		SIGNAL ICMPv6_RX_Meta_DestMACAddress_nxt		: STD_LOGIC;
		SIGNAL ICMPv6_RX_Meta_SrcIPv6Address_nxt		: STD_LOGIC;
		SIGNAL ICMPv6_RX_Meta_DestIPv6Address_nxt		: STD_LOGIC;
		
		SIGNAL Loop4_TX_Valid												: STD_LOGIC;
		SIGNAL Loop4_TX_Data												: T_SLV_8;
		SIGNAL Loop4_TX_SOF													: STD_LOGIC;
		SIGNAL Loop4_TX_EOF													: STD_LOGIC;
		SIGNAL Loop4_TX_Meta_SrcIPv6Address_Data		: T_SLV_8;
		SIGNAL Loop4_TX_Meta_DestIPv6Address_Data		: T_SLV_8;
		SIGNAL Loop4_TX_Meta_Length									: T_SLV_16;
		
		SIGNAL Loop4_TX_Meta_rst										: STD_LOGIC;
		SIGNAL Loop4_TX_Meta_SrcIPv6Address_nxt			: STD_LOGIC;
		SIGNAL Loop4_TX_Meta_DestIPv6Address_nxt		: STD_LOGIC;
		
		SIGNAL Loop4_RX_Ready												: STD_LOGIC;
		SIGNAL Loop4_RX_Meta_rst										: STD_LOGIC;
		SIGNAL Loop4_RX_Meta_SrcIPv6Address_nxt			: STD_LOGIC;
		SIGNAL Loop4_RX_Meta_DestIPv6Address_nxt		: STD_LOGIC;
		
	BEGIN
		IPv6 : ENTITY L_Ethernet.IPv6_Wrapper
			GENERIC MAP (
				PACKET_TYPES											=> IPV6_PACKET_TYPES
			)
			PORT MAP (
				Clock															=> Ethernet_Clock,
				Reset															=> Ethernet_Reset,
				
				MAC_TX_Valid											=> IPv6_TX_Valid,
				MAC_TX_Data												=> IPv6_TX_Data,
				MAC_TX_SOF												=> IPv6_TX_SOF,
				MAC_TX_EOF												=> IPv6_TX_EOF,
				MAC_TX_Ready											=> MAC_TX_Ready(IPV6_MAC_PORT_NUMBER),
				MAC_TX_Meta_rst										=> MAC_TX_Meta_rst(IPV6_MAC_PORT_NUMBER),
				MAC_TX_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt(IPV6_MAC_PORT_NUMBER),
				MAC_TX_Meta_DestMACAddress_Data		=> IPv6_TX_Meta_DestMACAddress_Data,
				
				MAC_RX_Valid											=> MAC_RX_Valid(IPV6_MAC_PORT_NUMBER),
				MAC_RX_Data												=> MAC_RX_Data(IPV6_MAC_PORT_NUMBER),
				MAC_RX_SOF												=> MAC_RX_SOF(IPV6_MAC_PORT_NUMBER),
				MAC_RX_EOF												=> MAC_RX_EOF(IPV6_MAC_PORT_NUMBER),
				MAC_RX_Ready											=> IPv6_RX_Ready,
				MAC_RX_Meta_rst										=> IPv6_RX_Meta_rst,
				MAC_RX_Meta_SrcMACAddress_nxt			=> IPv6_RX_Meta_SrcMACAddress_nxt,
				MAC_RX_Meta_SrcMACAddress_Data		=> MAC_RX_Meta_SrcMACAddress_Data(IPV6_MAC_PORT_NUMBER),
				MAC_RX_Meta_DestMACAddress_nxt		=> IPv6_RX_Meta_DestMACAddress_nxt,
				MAC_RX_Meta_DestMACAddress_Data		=> MAC_RX_Meta_DestMACAddress_Data(IPV6_MAC_PORT_NUMBER),
				MAC_RX_Meta_EthType								=> to_slv(MAC_RX_Meta_EthType(IPV6_MAC_PORT_NUMBER)),
				
				NDP_NextHop_Query									=> blk_NextHop_Query,
				NDP_NextHop_IPv6Address_rst				=> blk_NextHop_IPv6Address_rst,
				NDP_NextHop_IPv6Address_nxt				=> blk_NextHop_IPv6Address_nxt,
				NDP_NextHop_IPv6Address_Data			=> blk_NextHop_IPv6Address_Data,
				
				NDP_NextHop_Valid									=> blk_NextHop_Valid,
				NDP_NextHop_MACAddress_rst				=> blk_NextHop_MACAddress_rst,
				NDP_NextHop_MACAddress_nxt				=> blk_NextHop_MACAddress_nxt,
				NDP_NextHop_MACAddress_Data				=> blk_NextHop_MACAddress_Data,
				
				TX_Valid													=> blk_TX_Valid,
				TX_Data														=> blk_TX_Data,
				TX_SOF														=> blk_TX_SOF,
				TX_EOF														=> blk_TX_EOF,
				TX_Ready													=> IPv6_TX_Ready,
				TX_Meta_rst												=> IPv6_TX_Meta_rst,
				TX_Meta_SrcIPv6Address_nxt				=> IPv6_TX_Meta_SrcIPv6Address_nxt,
				TX_Meta_SrcIPv6Address_Data				=> blk_TX_Meta_SrcIPv6Address_Data,
				TX_Meta_DestIPv6Address_nxt				=> IPv6_TX_Meta_DestIPv6Address_nxt,
				TX_Meta_DestIPv6Address_Data			=> blk_TX_Meta_DestIPv6Address_Data,
				TX_Meta_TrafficClass							=> blk_TX_Meta_TrafficClass,
				TX_Meta_FlowLabel									=> blk_TX_Meta_FlowLabel,
				TX_Meta_Length										=> blk_TX_Meta_Length,
				
				RX_Valid													=> IPv6_RX_Valid,
				RX_Data														=> IPv6_RX_Data,
				RX_SOF														=> IPv6_RX_SOF,
				RX_EOF														=> IPv6_RX_EOF,
				RX_Ready													=> blk_RX_Ready,
				RX_Meta_rst												=> blk_RX_Meta_rst,
				RX_Meta_SrcMACAddress_nxt					=> blk_RX_Meta_SrcMACAddress_nxt,
				RX_Meta_SrcMACAddress_Data				=> IPv6_RX_Meta_SrcMACAddress_Data,
				RX_Meta_DestMACAddress_nxt				=> blk_RX_Meta_DestMACAddress_nxt,
				RX_Meta_DestMACAddress_Data				=> IPv6_RX_Meta_DestMACAddress_Data,
				RX_Meta_EthType										=> IPv6_RX_Meta_EthType,
				RX_Meta_SrcIPv6Address_nxt				=> blk_RX_Meta_SrcIPv6Address_nxt,
				RX_Meta_SrcIPv6Address_Data				=> IPv6_RX_Meta_SrcIPv6Address_Data,
				RX_Meta_DestIPv6Address_nxt				=> blk_RX_Meta_DestIPv6Address_nxt,
				RX_Meta_DestIPv6Address_Data			=> IPv6_RX_Meta_DestIPv6Address_Data,
				RX_Meta_TrafficClass							=> OPEN,
				RX_Meta_FlowLabel									=> OPEN,
				RX_Meta_Length										=> IPv6_RX_Meta_Length,
				RX_Meta_NextHeader								=> IPv6_RX_Meta_NextHeader
			);
		
		-- IPv6 Port 0 - ICMPv6
		blk_TX_Valid(ICMPV6_IPV6_PORT_NUMBER)											<= '0';	--ICMPv6_TX_Valid;
		blk_TX_Data(ICMPV6_IPV6_PORT_NUMBER)											<= (OTHERS => '0');	--ICMPv6_TX_Data;
		blk_TX_SOF(ICMPV6_IPV6_PORT_NUMBER)												<= '0';	--ICMPv6_TX_SOF;
		blk_TX_EOF(ICMPV6_IPV6_PORT_NUMBER)												<= '0';	--ICMPv6_TX_EOF;
		blk_TX_Meta_SrcIPv6Address_Data(ICMPV6_IPV6_PORT_NUMBER)	<= (OTHERS => '0');	--ICMPv6_TX_Meta_SrcIPv6Address_Data;
		blk_TX_Meta_DestIPv6Address_Data(ICMPV6_IPV6_PORT_NUMBER)	<= (OTHERS => '0');	--ICMPv6_TX_Meta_DestIPv6Address_Data;
		blk_TX_Meta_TrafficClass(ICMPV6_IPV6_PORT_NUMBER)					<= (OTHERS => '0');
		blk_TX_Meta_FlowLabel(ICMPV6_IPV6_PORT_NUMBER)						<= (OTHERS => '0');
		blk_TX_Meta_Length(ICMPV6_IPV6_PORT_NUMBER)								<= (OTHERS => '0');	--ICMPv6_TX_Meta_Length;
		
		blk_RX_Ready(ICMPV6_IPV6_PORT_NUMBER)											<= '1';	--ICMPv6_RX_Ready;
		blk_RX_Meta_rst(ICMPV6_IPV6_PORT_NUMBER)									<= '0';	--ICMPv6_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(ICMPV6_IPV6_PORT_NUMBER)		<= '0';	--ICMPv6_RX_Meta_SrcMACAddress_nxt;
		blk_RX_Meta_DestMACAddress_nxt(ICMPV6_IPV6_PORT_NUMBER)		<= '0';	--ICMPv6_RX_Meta_DestMACAddress_nxt;
		blk_RX_Meta_SrcIPv6Address_nxt(ICMPV6_IPV6_PORT_NUMBER)		<= '0';	--ICMPv6_RX_Meta_SrcIPv6Address_nxt;
		blk_RX_Meta_DestIPv6Address_nxt(ICMPV6_IPV6_PORT_NUMBER)	<= '0';	--ICMPv6_RX_Meta_DestIPv6Address_nxt;
		
		-- IPv6 Port 1 - UDPv6
		blk_TX_Valid(UDPV6_IPV6_PORT_NUMBER)											<= UDPv6_TX_Valid;
		blk_TX_Data(UDPV6_IPV6_PORT_NUMBER)												<= UDPv6_TX_Data;
		blk_TX_SOF(UDPV6_IPV6_PORT_NUMBER)												<= UDPv6_TX_SOF;
		blk_TX_EOF(UDPV6_IPV6_PORT_NUMBER)												<= UDPv6_TX_EOF;
		blk_TX_Meta_SrcIPv6Address_Data(UDPV6_IPV6_PORT_NUMBER)		<= UDPv6_TX_Meta_SrcIPv6Address_Data;
		blk_TX_Meta_DestIPv6Address_Data(UDPV6_IPV6_PORT_NUMBER)	<= UDPv6_TX_Meta_DestIPv6Address_Data;
		blk_TX_Meta_TrafficClass(UDPV6_IPV6_PORT_NUMBER)					<= (OTHERS => '0');
		blk_TX_Meta_FlowLabel(UDPV6_IPV6_PORT_NUMBER)							<= (OTHERS => '0');
		blk_TX_Meta_Length(UDPV6_IPV6_PORT_NUMBER)								<= UDPv6_TX_Meta_Length;
		
		blk_RX_Ready(UDPV6_IPV6_PORT_NUMBER)											<= UDPv6_RX_Ready;
		blk_RX_Meta_rst(UDPV6_IPV6_PORT_NUMBER)										<= UDPv6_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(UDPV6_IPV6_PORT_NUMBER)			<= UDPv6_RX_Meta_SrcMACAddress_nxt;
		blk_RX_Meta_DestMACAddress_nxt(UDPV6_IPV6_PORT_NUMBER)		<= UDPv6_RX_Meta_DestMACAddress_nxt;
		blk_RX_Meta_SrcIPv6Address_nxt(UDPV6_IPV6_PORT_NUMBER)		<= UDPv6_RX_Meta_SrcIPv6Address_nxt;
		blk_RX_Meta_DestIPv6Address_nxt(UDPV6_IPV6_PORT_NUMBER)		<= UDPv6_RX_Meta_DestIPv6Address_nxt;

		-- IPv6 Port 2 - Loopback
		blk_TX_Valid(LOOP4_IPV6_PORT_NUMBER)											<= Loop4_TX_Valid;
		blk_TX_Data(LOOP4_IPV6_PORT_NUMBER)												<= Loop4_TX_Data;
		blk_TX_SOF(LOOP4_IPV6_PORT_NUMBER)												<= Loop4_TX_SOF;
		blk_TX_EOF(LOOP4_IPV6_PORT_NUMBER)												<= Loop4_TX_EOF;
		blk_TX_Meta_SrcIPv6Address_Data(LOOP4_IPV6_PORT_NUMBER)		<= Loop4_TX_Meta_SrcIPv6Address_Data;
		blk_TX_Meta_DestIPv6Address_Data(LOOP4_IPV6_PORT_NUMBER)	<= Loop4_TX_Meta_DestIPv6Address_Data;
		blk_TX_Meta_TrafficClass(LOOP4_IPV6_PORT_NUMBER)					<= (OTHERS => '0');
		blk_TX_Meta_FlowLabel(LOOP4_IPV6_PORT_NUMBER)							<= (OTHERS => '0');
		blk_TX_Meta_Length(LOOP4_IPV6_PORT_NUMBER)								<= Loop4_TX_Meta_Length;
		
		blk_RX_Ready(LOOP4_IPV6_PORT_NUMBER)											<= Loop4_RX_Ready;
		blk_RX_Meta_rst(LOOP4_IPV6_PORT_NUMBER)										<= Loop4_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(LOOP4_IPV6_PORT_NUMBER)			<= '0';
		blk_RX_Meta_DestMACAddress_nxt(LOOP4_IPV6_PORT_NUMBER)		<= '0';
		blk_RX_Meta_SrcIPv6Address_nxt(LOOP4_IPV6_PORT_NUMBER)		<= Loop4_RX_Meta_SrcIPv6Address_nxt;
		blk_RX_Meta_DestIPv6Address_nxt(LOOP4_IPV6_PORT_NUMBER)		<= Loop4_RX_Meta_DestIPv6Address_nxt;

		NDP : ENTITY L_Ethernet.NDP_Wrapper
			GENERIC MAP (
				CLOCK_FREQ_MHZ										=> CLOCKIN_FREQ_MHZ,
				INTERFACE_MACADDRESS							=> MAC_CONFIGURATION(1).Interface.Address,
				INITIAL_IPV6ADDRESSES							=> INITIAL_IPV6ADDRESSES_ETH1,
				INITIAL_DESTINATIONCACHE_CONTENT	=> INITIAL_DESTINATIONCACHE_CONTENT,
				INITIAL_NEIGHBORCACHE_CONTENT			=> INITIAL_NEIGHBORCACHE_CONTENT
			)			
			PORT MAP (			
				Clock															=> Ethernet_Clock,
				Reset															=> Ethernet_Reset,
				
				NextHop_Query											=> blk_NextHop_Query,
				NextHop_IPv6Address_rst						=> blk_NextHop_IPv6Address_rst,
				NextHop_IPv6Address_nxt						=> blk_NextHop_IPv6Address_nxt,
				NextHop_IPv6Address_Data					=> blk_NextHop_IPv6Address_Data,
				
				NextHop_Valid											=> blk_NextHop_Valid,
				NextHop_MACAddress_rst						=> blk_NextHop_MACAddress_rst,
				NextHop_MACAddress_nxt						=> blk_NextHop_MACAddress_nxt,
				NextHop_MACAddress_Data						=> blk_NextHop_MACAddress_Data
			);
		
		ICMPv6 : ENTITY L_Ethernet.ICMPv6_Wrapper
			PORT MAP (
				Clock															=> Ethernet_Clock,
				Reset															=> Ethernet_Reset,
			
				IP_TX_Valid												=> ICMPv6_TX_Valid,
				IP_TX_Data												=> ICMPv6_TX_Data,
				IP_TX_SOF													=> ICMPv6_TX_SOF,
				IP_TX_EOF													=> ICMPv6_TX_EOF,
				IP_TX_Ready												=> IPv6_TX_Ready(ICMPV6_IPV6_PORT_NUMBER),
				IP_TX_Meta_rst										=> IPv6_TX_Meta_rst(ICMPV6_IPV6_PORT_NUMBER),
				IP_TX_Meta_DestIPv6Address_nxt		=> IPv6_TX_Meta_DestIPv6Address_nxt(ICMPV6_IPV6_PORT_NUMBER),
				IP_TX_Meta_DestIPv6Address_Data		=> ICMPv6_TX_Meta_DestIPv6Address_Data,
			
				IP_RX_Valid												=> IPv6_RX_Valid(ICMPV6_IPV6_PORT_NUMBER),
				IP_RX_Data												=> IPv6_RX_Data(ICMPV6_IPV6_PORT_NUMBER),
				IP_RX_SOF													=> IPv6_RX_SOF(ICMPV6_IPV6_PORT_NUMBER),
				IP_RX_EOF													=> IPv6_RX_EOF(ICMPV6_IPV6_PORT_NUMBER),
				IP_RX_Ready												=> ICMPv6_RX_Ready
			);
		
		Loop4 : ENTITY L_Ethernet.IPv6_FrameLoopback
			GENERIC MAP (
				MAX_FRAMES										=> 4
			)
			PORT MAP (
				Clock													=> Ethernet_Clock,
				Reset													=> Ethernet_Reset,
				
				In_Valid											=> IPv6_RX_Valid(LOOP4_IPV6_PORT_NUMBER),
				In_Data												=> IPv6_RX_Data(LOOP4_IPV6_PORT_NUMBER),
				In_SOF												=> IPv6_RX_SOF(LOOP4_IPV6_PORT_NUMBER),
				In_EOF												=> IPv6_RX_EOF(LOOP4_IPV6_PORT_NUMBER),
				In_Ready											=> Loop4_RX_Ready,
				In_Meta_rst										=> Loop4_RX_Meta_rst,
				In_Meta_SrcIPv6Address_nxt		=> Loop4_RX_Meta_SrcIPv6Address_nxt,
				In_Meta_SrcIPv6Address_Data		=> IPv6_RX_Meta_SrcIPv6Address_Data(LOOP4_IPV6_PORT_NUMBER),
				In_Meta_DestIPv6Address_nxt		=> Loop4_RX_Meta_DestIPv6Address_nxt,
				In_Meta_DestIPv6Address_Data	=> IPv6_RX_Meta_DestIPv6Address_Data(LOOP4_IPV6_PORT_NUMBER),
				In_Meta_Length								=> IPv6_RX_Meta_Length(LOOP4_IPV6_PORT_NUMBER),

				Out_Valid											=> Loop4_TX_Valid,
				Out_Data											=> Loop4_TX_Data,
				Out_SOF												=> Loop4_TX_SOF,
				Out_EOF												=> Loop4_TX_EOF,
				Out_Ready											=> IPv6_TX_Ready(LOOP4_IPV6_PORT_NUMBER),
				Out_Meta_rst									=> IPv6_TX_Meta_rst(LOOP4_IPV6_PORT_NUMBER),
				Out_Meta_SrcIPv6Address_nxt		=> IPv6_TX_Meta_SrcIPv6Address_nxt(LOOP4_IPV6_PORT_NUMBER),
				Out_Meta_SrcIPv6Address_Data	=> Loop4_TX_Meta_SrcIPv6Address_Data,
				Out_Meta_DestIPv6Address_nxt	=> IPv6_TX_Meta_DestIPv6Address_nxt(LOOP4_IPV6_PORT_NUMBER),
				Out_Meta_DestIPv6Address_Data	=> Loop4_TX_Meta_DestIPv6Address_Data,
				Out_Meta_Length								=> Loop4_TX_Meta_Length
			);
	END BLOCK;
	
	blkUDPv6 : BLOCK
		SIGNAL blk_TX_Valid													: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Data													: T_SLVV_8(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_SOF														: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_EOF														: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_rst											: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_SrcIPv6Address_Data			: T_SLVV_8(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_DestIPv6Address_Data			: T_SLVV_8(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_Length										: T_SLVV_16(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_SrcPort									: T_SLVV_16(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_TX_Meta_DestPort									: T_SLVV_16(UDPV6_PORTS - 1 DOWNTO 0);
		
		SIGNAL blk_RX_Ready													: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_rst											: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcMACAddress_nxt				: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestMACAddress_nxt				: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_SrcIPv6Address_nxt				: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		SIGNAL blk_RX_Meta_DestIPv6Address_nxt			: STD_LOGIC_VECTOR(UDPV6_PORTS - 1 DOWNTO 0);
		
		SIGNAL Loop5_TX_Valid												: STD_LOGIC;
		SIGNAL Loop5_TX_Data												: T_SLV_8;
		SIGNAL Loop5_TX_SOF													: STD_LOGIC;
		SIGNAL Loop5_TX_EOF													: STD_LOGIC;
		SIGNAL Loop5_TX_Meta_SrcIPv6Address_Data		: T_SLV_8;
		SIGNAL Loop5_TX_Meta_DestIPv6Address_Data		: T_SLV_8;
		SIGNAL Loop5_TX_Meta_Length									: T_SLV_16;
		SIGNAL Loop5_TX_Meta_SrcPort								: T_SLV_16;
		SIGNAL Loop5_TX_Meta_DestPort								: T_SLV_16;
		
		SIGNAL Loop5_TX_Meta_rst										: STD_LOGIC;
		SIGNAL Loop5_TX_Meta_SrcIPv6Address_nxt			: STD_LOGIC;
		SIGNAL Loop5_TX_Meta_DestIPv6Address_nxt		: STD_LOGIC;
		
		SIGNAL Loop5_RX_Ready												: STD_LOGIC;
		SIGNAL Loop5_RX_Meta_rst										: STD_LOGIC;
		SIGNAL Loop5_RX_Meta_SrcIPv6Address_nxt			: STD_LOGIC;
		SIGNAL Loop5_RX_Meta_DestIPv6Address_nxt		: STD_LOGIC;
		
	BEGIN
		UDP : ENTITY L_Ethernet.UDP_Wrapper
			GENERIC MAP (
				IP_VERSION												=> 6,
				PORTPAIRS													=> UDPV6_PORTPAIRS
			)
			PORT MAP (
				Clock															=> Ethernet_Clock,
				Reset															=> Ethernet_Reset,

				IP_TX_Valid												=> UDPv6_TX_Valid,
				IP_TX_Data												=> UDPv6_TX_Data,
				IP_TX_SOF													=> UDPv6_TX_SOF,
				IP_TX_EOF													=> UDPv6_TX_EOF,
				IP_TX_Ready												=> IPv6_TX_Ready(UDPV6_IPV6_PORT_NUMBER),
				IP_TX_Meta_rst										=> IPv6_TX_Meta_rst(UDPV6_IPV6_PORT_NUMBER),
				IP_TX_Meta_SrcIPAddress_nxt				=> IPv6_TX_Meta_SrcIPv6Address_nxt(UDPV6_IPV6_PORT_NUMBER),
				IP_TX_Meta_SrcIPAddress_Data			=> UDPv6_TX_Meta_SrcIPv6Address_Data,
				IP_TX_Meta_DestIPAddress_nxt			=> IPv6_TX_Meta_DestIPv6Address_nxt(UDPV6_IPV6_PORT_NUMBER),
				IP_TX_Meta_DestIPAddress_Data			=> UDPv6_TX_Meta_DestIPv6Address_Data,
				IP_TX_Meta_Length									=> UDPv6_TX_Meta_Length,
				
				IP_RX_Valid												=> IPv6_RX_Valid(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_Data												=> IPv6_RX_Data(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_SOF													=> IPv6_RX_SOF(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_EOF													=> IPv6_RX_EOF(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_Ready												=> UDPv6_RX_Ready,
				IP_RX_Meta_rst										=> UDPv6_RX_Meta_rst,
				IP_RX_Meta_SrcMACAddress_nxt			=> UDPv6_RX_Meta_SrcMACAddress_nxt,
				IP_RX_Meta_SrcMACAddress_Data			=> IPv6_RX_Meta_SrcMACAddress_Data(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_Meta_DestMACAddress_nxt			=> UDPv6_RX_Meta_DestMACAddress_nxt,
				IP_RX_Meta_DestMACAddress_Data		=> IPv6_RX_Meta_DestMACAddress_Data(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_Meta_EthType								=> IPv6_RX_Meta_EthType(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_Meta_SrcIPAddress_nxt				=> UDPv6_RX_Meta_SrcIPv6Address_nxt,
				IP_RX_Meta_SrcIPAddress_Data			=> IPv6_RX_Meta_SrcIPv6Address_Data(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_Meta_DestIPAddress_nxt			=> UDPv6_RX_Meta_DestIPv6Address_nxt,
				IP_RX_Meta_DestIPAddress_Data			=> IPv6_RX_Meta_DestIPv6Address_Data(UDPV6_IPV6_PORT_NUMBER),
--				IP_RX_Meta_TrafficClass						=> IPv6_RX_Meta_TrafficClass(UDPV6_IPV6_PORT_NUMBER),
--				IP_RX_Meta_FlowLabel							=> IPv6_RX_Meta_FlowLabel(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_Meta_Length									=> IPv6_RX_Meta_Length(UDPV6_IPV6_PORT_NUMBER),
				IP_RX_Meta_Protocol								=> IPv6_RX_Meta_NextHeader(UDPV6_IPV6_PORT_NUMBER),
				
				TX_Valid													=> blk_TX_Valid,
				TX_Data														=> blk_TX_Data,
				TX_SOF														=> blk_TX_SOF,
				TX_EOF														=> blk_TX_EOF,
				TX_Ready													=> UDPv6_TX_Ready,
				TX_Meta_rst												=> UDPv6_TX_Meta_rst,
				TX_Meta_SrcIPAddress_nxt					=> UDPv6_TX_Meta_SrcIPv6Address_nxt,
				TX_Meta_SrcIPAddress_Data					=> blk_TX_Meta_SrcIPv6Address_Data,
				TX_Meta_DestIPAddress_nxt					=> UDPv6_TX_Meta_DestIPv6Address_nxt,
				TX_Meta_DestIPAddress_Data				=> blk_TX_Meta_DestIPv6Address_Data,
				TX_Meta_Length										=> blk_TX_Meta_Length,
				TX_Meta_SrcPort										=> blk_TX_Meta_SrcPort,
				TX_Meta_DestPort									=> blk_TX_Meta_DestPort,
				
				RX_Valid													=> UDPv6_RX_Valid,
				RX_Data														=> UDPv6_RX_Data,
				RX_SOF														=> UDPv6_RX_SOF,
				RX_EOF														=> UDPv6_RX_EOF,
				RX_Ready													=> blk_RX_Ready,
				RX_Meta_rst												=> blk_RX_Meta_rst,
				RX_Meta_SrcMACAddress_nxt					=> blk_RX_Meta_SrcMACAddress_nxt,
				RX_Meta_SrcMACAddress_Data				=> UDPv6_RX_Meta_SrcMACAddress_Data,
				RX_Meta_DestMACAddress_nxt				=> blk_RX_Meta_DestMACAddress_nxt,
				RX_Meta_DestMACAddress_Data				=> UDPv6_RX_Meta_DestMACAddress_Data,
				RX_Meta_EthType										=> UDPv6_RX_Meta_EthType,
				RX_Meta_SrcIPAddress_nxt					=> blk_RX_Meta_SrcIPv6Address_nxt,
				RX_Meta_SrcIPAddress_Data					=> UDPv6_RX_Meta_SrcIPv6Address_Data,
				RX_Meta_DestIPAddress_nxt					=> blk_RX_Meta_DestIPv6Address_nxt,
				RX_Meta_DestIPAddress_Data				=> UDPv6_RX_Meta_DestIPv6Address_Data,
--				RX_Meta_TrafficClass							=> UDPv6_RX_Meta_TrafficClass,
--				RX_Meta_FlowLabel									=> UDPv6_RX_Meta_FlowLabel,
				RX_Meta_Length										=> UDPv6_RX_Meta_Length,
				RX_Meta_Protocol									=> UDPv6_RX_Meta_NextHeader,
				RX_Meta_SrcPort										=> UDPv6_RX_Meta_SrcPort,
				RX_Meta_DestPort									=> UDPv6_RX_Meta_DestPort
			);
		
		-- UDPv6 Port 0 - LoopBack
		blk_TX_Valid(LOOP5_UDPV6_PORT_NUMBER)													<= Loop5_TX_Valid;
		blk_TX_Data(LOOP5_UDPV6_PORT_NUMBER)													<= Loop5_TX_Data;
		blk_TX_SOF(LOOP5_UDPV6_PORT_NUMBER)														<= Loop5_TX_SOF;
		blk_TX_EOF(LOOP5_UDPV6_PORT_NUMBER)														<= Loop5_TX_EOF;
		blk_TX_Meta_SrcIPv6Address_Data(LOOP5_UDPV6_PORT_NUMBER)			<= Loop5_TX_Meta_SrcIPv6Address_Data;
		blk_TX_Meta_DestIPv6Address_Data(LOOP5_UDPV6_PORT_NUMBER)			<= Loop5_TX_Meta_DestIPv6Address_Data;
--		blk_TX_Meta_TrafficClass(LOOP5_UDPV6_PORT_NUMBER)							<= (OTHERS => '0');
--		blk_TX_Meta_FlowLabel(LOOP5_UDPV6_PORT_NUMBER)								<= (OTHERS => '0');
		blk_TX_Meta_Length(LOOP5_UDPV6_PORT_NUMBER)										<= Loop5_TX_Meta_Length;
		blk_TX_Meta_SrcPort(LOOP5_UDPV6_PORT_NUMBER)									<= Loop5_TX_Meta_SrcPort;
		blk_TX_Meta_DestPort(LOOP5_UDPV6_PORT_NUMBER)									<= Loop5_TX_Meta_DestPort;
				
		blk_RX_Ready(LOOP5_UDPV6_PORT_NUMBER)													<= Loop5_RX_Ready;
		blk_RX_Meta_rst(LOOP5_UDPV6_PORT_NUMBER)											<= Loop5_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(LOOP5_UDPV6_PORT_NUMBER)				<= '0';
		blk_RX_Meta_DestMACAddress_nxt(LOOP5_UDPV6_PORT_NUMBER)				<= '0';
		blk_RX_Meta_SrcIPv6Address_nxt(LOOP5_UDPV6_PORT_NUMBER)				<= Loop5_RX_Meta_SrcIPv6Address_nxt;
		blk_RX_Meta_DestIPv6Address_nxt(LOOP5_UDPV6_PORT_NUMBER)			<= Loop5_RX_Meta_DestIPv6Address_nxt;
		
		-- UDPv6 Port 1 - UDPGen
		blk_TX_Valid(UDPGENV6_UDPV6_PORT_NUMBER)											<= UDPGENv6_TX_Valid;
		blk_TX_Data(UDPGENV6_UDPV6_PORT_NUMBER)												<= UDPGENv6_TX_Data;
		blk_TX_SOF(UDPGENV6_UDPV6_PORT_NUMBER)												<= UDPGENv6_TX_SOF;
		blk_TX_EOF(UDPGENV6_UDPV6_PORT_NUMBER)												<= UDPGENv6_TX_EOF;
		blk_TX_Meta_SrcIPv6Address_Data(UDPGENV6_UDPV6_PORT_NUMBER)		<= UDPGENv6_TX_Meta_SrcIPv6Address_Data;
		blk_TX_Meta_DestIPv6Address_Data(UDPGENV6_UDPV6_PORT_NUMBER)	<= UDPGENv6_TX_Meta_DestIPv6Address_Data;
--		blk_TX_Meta_TrafficClass(UDPGENV6_UDPV6_PORT_NUMBER)					<= (OTHERS => '0');
--		blk_TX_Meta_FlowLabel(UDPGENV6_UDPV6_PORT_NUMBER)							<= (OTHERS => '0');
		blk_TX_Meta_Length(UDPGENV6_UDPV6_PORT_NUMBER)								<= UDPGENv6_TX_Meta_Length;
		blk_TX_Meta_SrcPort(UDPGENV6_UDPV6_PORT_NUMBER)								<= UDPGENv6_TX_Meta_SrcPort;
		blk_TX_Meta_DestPort(UDPGENV6_UDPV6_PORT_NUMBER)							<= UDPGENv6_TX_Meta_DestPort;
		
		blk_RX_Ready(UDPGENV6_UDPV6_PORT_NUMBER)											<= UDPGENv6_RX_Ready;
		blk_RX_Meta_rst(UDPGENV6_UDPV6_PORT_NUMBER)										<= UDPGENv6_RX_Meta_rst;
		blk_RX_Meta_SrcMACAddress_nxt(UDPGENV6_UDPV6_PORT_NUMBER)			<= UDPGENv6_RX_Meta_SrcMACAddress_nxt;
		blk_RX_Meta_DestMACAddress_nxt(UDPGENV6_UDPV6_PORT_NUMBER)		<= UDPGENv6_RX_Meta_DestMACAddress_nxt;
		blk_RX_Meta_SrcIPv6Address_nxt(UDPGENV6_UDPV6_PORT_NUMBER)		<= UDPGENv6_RX_Meta_SrcIPv6Address_nxt;
		blk_RX_Meta_DestIPv6Address_nxt(UDPGENV6_UDPV6_PORT_NUMBER)		<= UDPGENv6_RX_Meta_DestIPv6Address_nxt;
		
		Loop5 : ENTITY L_Ethernet.UDP_FrameLoopback
			GENERIC MAP (
				IP_VERSION										=> 6,
				MAX_FRAMES										=> 4
			)
			PORT MAP (
				Clock													=> Ethernet_Clock,
				Reset													=> Ethernet_Reset,
				
				In_Valid											=> UDPv6_RX_Valid(LOOP5_UDPV6_PORT_NUMBER),
				In_Data												=> UDPv6_RX_Data(LOOP5_UDPV6_PORT_NUMBER),
				In_SOF												=> UDPv6_RX_SOF(LOOP5_UDPV6_PORT_NUMBER),
				In_EOF												=> UDPv6_RX_EOF(LOOP5_UDPV6_PORT_NUMBER),
				In_Ready											=> Loop5_RX_Ready,
				In_Meta_rst										=> Loop5_RX_Meta_rst,
				In_Meta_SrcIPAddress_nxt			=> Loop5_RX_Meta_SrcIPv6Address_nxt,
				In_Meta_SrcIPAddress_Data			=> UDPv6_RX_Meta_SrcIPv6Address_Data(LOOP5_UDPV6_PORT_NUMBER),
				In_Meta_DestIPAddress_nxt			=> Loop5_RX_Meta_DestIPv6Address_nxt,
				In_Meta_DestIPAddress_Data		=> UDPv6_RX_Meta_DestIPv6Address_Data(LOOP5_UDPV6_PORT_NUMBER),
--				In_Meta_Length								=> UDPv6_RX_Meta_Length(LOOP5_UDPV6_PORT_NUMBER),
				In_Meta_SrcPort								=> UDPv6_RX_Meta_SrcPort(LOOP5_UDPV6_PORT_NUMBER),
				In_Meta_DestPort							=> UDPv6_RX_Meta_DestPort(LOOP5_UDPV6_PORT_NUMBER),

				Out_Valid											=> Loop5_TX_Valid,
				Out_Data											=> Loop5_TX_Data,
				Out_SOF												=> Loop5_TX_SOF,
				Out_EOF												=> Loop5_TX_EOF,
				Out_Ready											=> UDPv6_TX_Ready(LOOP5_UDPV6_PORT_NUMBER),
				Out_Meta_rst									=> UDPv6_TX_Meta_rst(LOOP5_UDPV6_PORT_NUMBER),
				Out_Meta_SrcIPAddress_nxt			=> UDPv6_TX_Meta_SrcIPv6Address_nxt(LOOP5_UDPV6_PORT_NUMBER),
				Out_Meta_SrcIPAddress_Data		=> Loop5_TX_Meta_SrcIPv6Address_Data,
				Out_Meta_DestIPAddress_nxt		=> UDPv6_TX_Meta_DestIPv6Address_nxt(LOOP5_UDPV6_PORT_NUMBER),
				Out_Meta_DestIPAddress_Data		=> Loop5_TX_Meta_DestIPv6Address_Data,
--				Out_Meta_Length								=> Loop5_TX_Meta_Length,
				Out_Meta_SrcPort							=> Loop5_TX_Meta_SrcPort,
				Out_Meta_DestPort							=> Loop5_TX_Meta_DestPort
			);
	END BLOCK;	-- blkUDPv6

	blkUDPGENv6 : BLOCK
		CONSTANT FRAMEGROUPS										: T_FRAMEGEN_FRAMEGROUP_VECTOR_8										:= GenUDPFrameGenerator_Frames;
		
		SIGNAL Eth_Status_d											: T_NET_ETH_STATUS																	:= NET_ETH_STATUS_RESETING;
		SIGNAL NewConnection										: STD_LOGIC;
		
		SIGNAL UDPGen_Command										: T_FRAMEGEN_COMMAND;
		SIGNAL UDPGen_Status										: T_FRAMEGEN_STATUS;
		
		SIGNAL UDPGen_TX_Valid									: STD_LOGIC;
		SIGNAL UDPGen_TX_Data										: T_SLV_8;
		SIGNAL UDPGen_TX_SOF										: STD_LOGIC;
		SIGNAL UDPGen_TX_EOF										: STD_LOGIC;
		
	BEGIN
		
		Eth_Status_d	<= Eth_Status WHEN rising_edge(Ethernet_Clock);
		NewConnection	<= to_sl((Eth_Status_d /= NET_ETH_STATUS_CONNECTED) AND (Eth_Status = NET_ETH_STATUS_CONNECTED));
	
		PROCESS(NewConnection)
		BEGIN
			IF (NewConnection = '1') THEN
				UDPGen_Command			<= FRAMEGEN_CMD_SEQUENCE;
			ELSE
				UDPGen_Command			<= FRAMEGEN_CMD_NONE;
			END IF;
		END PROCESS;
	
		UDPGen : ENTITY L_Global.LocalLink_FrameGenerator
			GENERIC MAP (
				DATA_BITS							=> 8,
				WORD_BITS							=> 8,
				APPEND								=> FRAMEGEN_APP_NONE,
				FRAMEGROUPS						=> FRAMEGROUPS
			)
			PORT MAP (
				Clock									=> Ethernet_Clock,
				Reset									=> Ethernet_Reset,
				
				Command								=> UDPGen_Command,
				Status								=> UDPGen_Status,
				
				Pause									=> to_slv( 0, 16),
				
				FrameGroupIndex				=> (OTHERS => '0'),
				FrameIndex						=> (OTHERS => '0'),
				
				Sequences							=> to_slv(16, 16),
				FrameLength						=> to_slv(UDPGENV6_PACKET_LENGTH, 16),
				
				Out_Valid							=> UDPGENv6_TX_Valid,
				Out_Data							=> UDPGENv6_TX_Data,
				Out_SOF								=> UDPGENv6_TX_SOF,
				Out_EOF								=> UDPGENv6_TX_EOF,
				Out_Ready							=> UDPv6_TX_Ready(UDPGENV6_UDPV6_PORT_NUMBER)
			);

		UDPGENv6_TX_Meta_Length								<= x"0000";		-- 0 means unknown length => calculate in FCS
		UDPGENv6_TX_Meta_SrcPort							<= UDPV6_PORTPAIRS(UDPGENV6_UDPV6_PORT_NUMBER).Egress;
		UDPGENv6_TX_Meta_DestPort							<= UDPV6_PORTPAIRS(UDPGENV6_UDPV6_PORT_NUMBER).Ingress;
	
		UDPGENv6_RX_Ready											<= '1';
		UDPGENv6_RX_Meta_rst									<= '0';
		UDPGENv6_RX_Meta_SrcMACAddress_nxt		<= '0';
		UDPGENv6_RX_Meta_DestMACAddress_nxt		<= '0';
		UDPGENv6_RX_Meta_SrcIPv6Address_nxt		<= '0';
		UDPGENv6_RX_Meta_DestIPv6Address_nxt	<= '0';

		SrcIPv6Seq : ENTITY L_Global.Sequenzer
			GENERIC MAP (
				INPUT_BITS						=> 128,
				OUTPUT_BITS						=> 8,
				REGISTERED						=> FALSE
			)
			PORT MAP (
				Clock									=> Ethernet_Clock,
				Reset									=> Ethernet_Reset,
				
				Input									=> to_slv(to_net_ipv6_address("1234::192:168:10:10")),
				rst										=> UDPv6_TX_Meta_rst(UDPGENV6_UDPV6_PORT_NUMBER),
				rev										=> '1',
				nxt										=> UDPv6_TX_Meta_SrcIPv6Address_nxt(UDPGENV6_UDPV6_PORT_NUMBER),
				Output								=> UDPGENv6_TX_Meta_SrcIPv6Address_Data
			);

		DestIPv6Seq : ENTITY L_Global.Sequenzer
			GENERIC MAP (
				INPUT_BITS						=> 128,
				OUTPUT_BITS						=> 8,
				REGISTERED						=> FALSE
			)
			PORT MAP (
				Clock									=> Ethernet_Clock,
				Reset									=> Ethernet_Reset,
				
				Input									=> to_slv(to_net_ipv6_address("1234::192:168:10:1")),
				rst										=> UDPv6_TX_Meta_rst(UDPGENV6_UDPV6_PORT_NUMBER),
				rev										=> '1',
				nxt										=> UDPv6_TX_Meta_DestIPv6Address_nxt(UDPGENV6_UDPV6_PORT_NUMBER),
				Output								=> UDPGENv6_TX_Meta_DestIPv6Address_Data
			);

	END BLOCK;	-- blkUDPGENv6


--	RC : ENTITY L_RemoteControl.RemoteControl_Wrapper
--		GENERIC MAP (
--			CLOCKIN_FREQ_MHZ					=> CLOCKIN_FREQ_MHZ
--		)
--		PORT MAP (
--			Clock											=> Ethernet_Clock,
--			Reset											=> Ethernet_Reset,
--			
--			TX_Valid									=> RC_TX_Valid,
--			TX_Data										=> RC_TX_Data,
--			TX_Length									=> RC_TX_Length,
--			TX_SOF										=> RC_TX_SOF,
--			TX_EOF										=> RC_TX_EOF,
--			TX_Ready									=> SFC_TX_Ready(RC_SFC_PORT_NUMBER),
--			
--			RX_Valid									=> SFC_RX_Valid(RC_SFC_PORT_NUMBER),
--			RX_Data										=> SFC_RX_Data(RC_SFC_PORT_NUMBER),
--			RX_SOF										=> SFC_RX_SOF(RC_SFC_PORT_NUMBER),
--			RX_EOF										=> SFC_RX_EOF(RC_SFC_PORT_NUMBER),
--			RX_Ready									=> RC_RX_Ready,
--			
--			-- Port 0
--			HardReset									=> HardReset,
--			-- Port 1
--			Display										=> Display,
--			-- Port 2
--			InputVector								=> InputVector,
--			-- Port 3
--			OutputVector							=> OutputVector,
--			-- Port 4
--			Address										=> Address,
--			DataIn										=> DataIn,
--			DataOut										=> DataOut
--		);


--		blkKEEP : BLOCK
--			SIGNAL CSP_UDP_Valid		: STD_LOGIC;
--			SIGNAL CSP_UDP_Data			: T_SLV_8;
--			SIGNAL CSP_UDP_SOF			: STD_LOGIC;
--			SIGNAL CSP_UDP_EOF			: STD_LOGIC;
--			
--			ATTRIBUTE KEEP OF CSP_UDP_Valid		: SIGNAL IS TRUE;
--			ATTRIBUTE KEEP OF CSP_UDP_Data		: SIGNAL IS TRUE;
--			ATTRIBUTE KEEP OF CSP_UDP_SOF			: SIGNAL IS TRUE;
--			ATTRIBUTE KEEP OF CSP_UDP_EOF			: SIGNAL IS TRUE;
--		BEGIN
--			CSP_UDP_Valid		<=	UDP_RX_Valid;
--			CSP_UDP_Data		<=	UDP_RX_Data;
--			CSP_UDP_SOF			<=	UDP_RX_SOF		AND UDP_RX_Valid;
--			CSP_UDP_EOF			<=	UDP_RX_EOF		AND UDP_RX_Valid;
--		END BLOCK;

	genCSP : IF (DEBUG = TRUE) GENERATE
		SIGNAL Eth_Status_d										: T_NET_ETH_STATUS;
		
		SIGNAL CSP_Ethernet_Clock							: STD_LOGIC;
		SIGNAL CSP_NewConnection							: STD_LOGIC;
		
		ATTRIBUTE KEEP OF CSP_Ethernet_Clock	: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_NewConnection		: SIGNAL IS TRUE;
		
	BEGIN
		BUFG_CSPClock_125MHz : BUFG
			PORT MAP (
				I		=> Ethernet_Clock,
				O		=> CSP_Ethernet_Clock
			);
		
		Eth_Status_d				<= Eth_Status WHEN rising_edge(Ethernet_Clock);
		CSP_NewConnection		<= to_sl((Eth_Status_d /= NET_ETH_STATUS_CONNECTED) AND (Eth_Status = NET_ETH_STATUS_CONNECTED));
	
	END GENERATE;
END ARCHITECTURE;
