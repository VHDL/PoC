LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

PACKAGE EthTypes IS

	-- ==========================================================================================================================================================
	-- Ethernet: physical layer (PHY)
	-- ==========================================================================================================================================================
	TYPE T_NET_ETH_PHY_DATA_INTERFACE IS (
		NET_ETH_PHY_DATA_INTERFACE_MII,
		NET_ETH_PHY_DATA_INTERFACE_GMII,
		NET_ETH_PHY_DATA_INTERFACE_RGMII,
		NET_ETH_PHY_DATA_INTERFACE_SGMII
	);

	TYPE T_NET_ETH_PHY_MANAGEMENT_INTERFACE IS (
		NET_ETH_PHY_MANAGEMENT_INTERFACE_NONE,
		NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO,
		NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO_OVER_IIC
	);
	
	TYPE T_NET_ETH_PCSCORE IS (
		NET_ETH_PCSCORE_GENERIC_GMII,
		NET_ETH_PCSCORE_XILINX_HARDCORE,
		NET_ETH_PCSCORE_XILINX_PCSCORE
	);
	
	TYPE T_NET_ETH_PHY_DEVICE IS (
		NET_ETH_PHY_DEVICE_MARVEL_88E1111
	);

	SUBTYPE T_NET_ETH_PHY_DEVICE_ADDRESS		IS STD_LOGIC_VECTOR(4 DOWNTO 0);

	TYPE T_NET_ETH_PHYCONTROLLER_COMMAND IS (
		NET_ETH_PHYC_CMD_NONE,
		NET_ETH_PHYC_CMD_HARD_RESET,
		NET_ETH_PHYC_CMD_SOFT_RESET
	);
	
	TYPE T_NET_ETH_PHYCONTROLLER_STATUS IS (
		NET_ETH_PHYC_STATUS_POWER_DOWN,
		NET_ETH_PHYC_STATUS_RESETING,
		NET_ETH_PHYC_STATUS_CONNECTING,
		NET_ETH_PHYC_STATUS_CONNECTED,
		NET_ETH_PHYC_STATUS_DISCONNECTING,
		NET_ETH_PHYC_STATUS_DISCONNECTED,
		NET_ETH_PHYC_STATUS_ERROR
	);
	
	TYPE T_NET_ETH_PHYCONTROLLER_ERROR IS (
		NET_ETH_PHYC_ERROR_NONE,
		NET_ETH_PHYC_ERROR_NO_CABLE
	);

	-- FPGA <=> PHY physical interface: GMII (Gigabit Media Independant Interface)
	TYPE T_NET_ETH_PHY_INTERFACE_GMII IS RECORD
		RX_RefClock						: STD_LOGIC;
	
		TX_Clock							: STD_LOGIC;
		TX_Valid							: STD_LOGIC;
		TX_Data								: T_SLV_8;
		TX_Error							: STD_LOGIC;
		
		RX_Clock							: STD_LOGIC;
		RX_Valid							: STD_LOGIC;
		RX_Data								: T_SLV_8;
		RX_Error							: STD_LOGIC;
	END RECORD;

	-- FPGA <=> PHY physical interface: SGMII (Serial GMII)
	TYPE T_NET_ETH_PHY_INTERFACE_SGMII IS RECORD
		DGB_SystemClock_In		: STD_LOGIC;
		DGB_AutoNeg_Restart		: STD_LOGIC;
		
		SGMII_RefClock_In			: STD_LOGIC;
		SGMII_TXRefClock_Out	: STD_LOGIC;
		SGMII_RXRefClock_Out	: STD_LOGIC;
	
		TX_n									: STD_LOGIC;
		TX_p									: STD_LOGIC;
		
		RX_n									: STD_LOGIC;
		RX_p									: STD_LOGIC;
	END RECORD;

	-- FPGA <=> PHY management interface: MDIO (Management Data Input/Output)
	TYPE T_NET_ETH_PHY_INTERFACE_MDIO IS RECORD
		Clock_i								: STD_LOGIC;			-- clock (MDC) - input
		Clock_o								: STD_LOGIC;			-- clock (MDC) - output
		Clock_t								: STD_LOGIC;			-- clock (MDC) - tri-state enable
		Data_i								: STD_LOGIC;			-- data (MDIO) - input
		Data_o								: STD_LOGIC;			-- data (MDIO) - output
		Data_t								: STD_LOGIC;			-- data (MDIO) - tri-state enable
	END RECORD;

	TYPE T_NET_ETH_PHY_INTERFACE_COMMON IS RECORD
		Reset									: STD_LOGIC;
		Interrupt							: STD_LOGIC;
	END RECORD;

	-- combined interface definition - union-types are still not supported in VHDL
	TYPE T_NET_ETH_PHY_INTERFACES IS RECORD
		GMII									: T_NET_ETH_PHY_INTERFACE_GMII;
		SGMII									: T_NET_ETH_PHY_INTERFACE_SGMII;
		MDIO									: T_NET_ETH_PHY_INTERFACE_MDIO;
		Common								: T_NET_ETH_PHY_INTERFACE_COMMON;
	END RECORD;

	-- ==========================================================================================================================================================
	-- Ethernet: physical coding sublayer (PCS)
	-- ==========================================================================================================================================================
	-- 1000BASE-X - synchronization
	TYPE T_NET_ETH_PCS_1000BASE_X_SYNC_STATUS IS (
		NET_ETH_PCS_1000BASE_X_SYNC_STATUS_FAIL,
		NET_ETH_PCS_1000BASE_X_SYNC_STATUS_OK
	);

	-- 1000BASE-X - autonegotiation
	TYPE T_NET_ETH_PCS_1000BASE_X_AUTONEG_STATUS IS (
		NET_ETH_PCS_1000BASE_X_AUTONEG_STATUS_IDLE,
		NET_ETH_PCS_1000BASE_X_AUTONEG_STATUS_CONFIG,
		NET_ETH_PCS_1000BASE_X_AUTONEG_STATUS_DATA
	);

	-- ==========================================================================================================================================================
	-- Ethernet: reconcilation sublayer (RS)
	-- ==========================================================================================================================================================
	TYPE T_NET_ETH_RS_DATA_INTERFACE IS (
		NET_ETH_RS_DATA_INTERFACE_MII,
		NET_ETH_RS_DATA_INTERFACE_GMII,
		NET_ETH_RS_DATA_INTERFACE_TRANSCEIVER
	);

	-- ==========================================================================================================================================================
	-- Ethernet: MAC Control-Layer
	-- ==========================================================================================================================================================
	TYPE T_NET_ETH_COMMAND IS (
		NET_ETH_CMD_NONE,
		NET_ETH_CMD_HARD_RESET,
		NET_ETH_CMD_SOFT_RESET--,
--		NET_ETH_CMD_POWER_DOWN,
--		NET_ETH_CMD_POWER_UP
	);
	
	TYPE T_NET_ETH_STATUS IS (
		NET_ETH_STATUS_POWER_DOWN,
		NET_ETH_STATUS_RESETING,
		NET_ETH_STATUS_CONNECTING,
		NET_ETH_STATUS_CONNECTED,
		NET_ETH_STATUS_DISCONNECTING,
		NET_ETH_STATUS_DISCONNECTED,
		NET_ETH_STATUS_ERROR
	);
	
	TYPE T_NET_ETH_ERROR IS (
		NET_ETH_ERROR_NONE,
		NET_ETH_ERROR_MAC_ERROR,
		NET_ETH_ERROR_PHY_ERROR,
		NET_ETH_ERROR_PCS_ERROR,
		NET_ETH_ERROR_NO_CABLE
	);
	
	-- ==========================================================================================================================================================
	-- Ethernet: ????????????????????
	-- ==========================================================================================================================================================
	
	-- MDIOController
	-- ==========================================================================================================================================================
	TYPE T_NET_ETH_MDIOCONTROLLER_COMMAND IS (
		NET_ETH_MDIOC_CMD_NONE,
		NET_ETH_MDIOC_CMD_CHECK_ADDRESS,
		NET_ETH_MDIOC_CMD_READ,
		NET_ETH_MDIOC_CMD_WRITE,
		NET_ETH_MDIOC_CMD_ABORT
	);
	
	TYPE T_NET_ETH_MDIOCONTROLLER_STATUS IS (
		NET_ETH_MDIOC_STATUS_IDLE,
		NET_ETH_MDIOC_STATUS_CHECKING,
		NET_ETH_MDIOC_STATUS_CHECK_OK,
		NET_ETH_MDIOC_STATUS_CHECK_FAILED,
		NET_ETH_MDIOC_STATUS_READING,
		NET_ETH_MDIOC_STATUS_READ_COMPLETE,
		NET_ETH_MDIOC_STATUS_WRITING,
		NET_ETH_MDIOC_STATUS_WRITE_COMPLETE,
		NET_ETH_MDIOC_STATUS_ERROR
	);
	
	TYPE T_NET_ETH_MDIOCONTROLLER_ERROR IS (
		NET_ETH_MDIOC_ERROR_NONE,
		NET_ETH_MDIOC_ERROR_ADDRESS_NOT_FOUND,
		NET_ETH_MDIOC_ERROR_FSM
	);
	
	-- limitations
	CONSTANT C_NET_ETH_PREMABLE_LENGTH					: POSITIVE						:= 7;
	CONSTANT C_NET_ETH_INTER_FRAME_GAP_LENGTH		: POSITIVE						:= 12;
	CONSTANT C_NET_ETH_MIN_FRAME_LENGTH					: POSITIVE						:= 64;
	CONSTANT C_NET_ETH_MAX_NORMALFRAME_LENGTH		: POSITIVE						:= 1518;
	CONSTANT C_NET_ETH_MAX_TAGGEDFRAME_LENGTH		: POSITIVE						:= 1522;
	CONSTANT C_NET_ETH_MAX_JUMBOFRAME_LENGTH		: POSITIVE						:= 9018;
	
	-- ==========================================================================================================================================================
	-- Ethernet: MAC Data-Link-Layer
	-- ==========================================================================================================================================================
	-- types
	TYPE T_NET_MAC_ADDRESS								IS ARRAY (5 DOWNTO 0)				OF T_SLV_8;
	TYPE T_NET_MAC_ETHERNETTYPE						IS ARRAY (1 DOWNTO 0)				OF T_SLV_8;

	-- arrays
	TYPE T_NET_MAC_ADDRESS_VECTOR					IS ARRAY (NATURAL RANGE <>) OF T_NET_MAC_ADDRESS;
	TYPE T_NET_MAC_ETHERNETTYPE_VECTOR		IS ARRAY (NATURAL RANGE <>)	OF T_NET_MAC_ETHERNETTYPE;
	
	-- predefined constants
	CONSTANT C_NET_MAC_ADDRESS_EMPTY				: T_NET_MAC_ADDRESS				:= (OTHERS => (OTHERS => '0'));
	CONSTANT C_NET_MAC_ADDRESS_BROADCAST		: T_NET_MAC_ADDRESS				:= (OTHERS => (OTHERS => '1'));
	CONSTANT C_NET_MAC_MASK_EMPTY						: T_NET_MAC_ADDRESS				:= (OTHERS => (OTHERS => '0'));
	CONSTANT C_NET_MAC_MASK_DEFAULT					: T_NET_MAC_ADDRESS				:= (OTHERS => (OTHERS => '1'));
	CONSTANT C_NET_MAC_ETHERNETTYPE_EMPTY						: T_NET_MAC_ETHERNETTYPE	:= (OTHERS => (OTHERS => '0'));

	-- type conversion functions
	FUNCTION to_net_mac_address(slv : T_SLV_48)						RETURN T_NET_MAC_ADDRESS;
	FUNCTION to_net_mac_address(slvv : T_SLVV_8)					RETURN T_NET_MAC_ADDRESS;
	FUNCTION to_net_mac_address(str : STRING)							RETURN T_NET_MAC_ADDRESS;
	FUNCTION to_net_mac_ethernettype(slv : T_SLV_16)			RETURN T_NET_MAC_ETHERNETTYPE;

	FUNCTION to_slv(mac : T_NET_MAC_ADDRESS) 							RETURN STD_LOGIC_VECTOR;
	FUNCTION to_slv(EthType : T_NET_MAC_ETHERNETTYPE)			RETURN STD_LOGIC_VECTOR;

	FUNCTION to_slvv_8(mac : T_NET_MAC_ADDRESS)						RETURN T_SLVV_8;
	FUNCTION to_slvv_8(EthType : T_NET_MAC_ETHERNETTYPE)	RETURN T_SLVV_8;

	FUNCTION to_string(mac : T_NET_MAC_ADDRESS)						RETURN STRING;
	FUNCTION to_string(EthType : T_NET_MAC_ETHERNETTYPE)	RETURN STRING;

	-- ==========================================================================================================================================================
	-- ETH_Wrapper: configuration data structures
	-- ==========================================================================================================================================================
	TYPE T_NET_MAC_INTERFACE IS RECORD
		Address							: T_NET_MAC_ADDRESS;
		Mask								: T_NET_MAC_ADDRESS;
	END RECORD;
	
	TYPE T_NET_MAC_INTERFACE_VECTOR IS ARRAY(NATURAL RANGE <>) OF T_NET_MAC_INTERFACE;
	
	TYPE T_NET_MAC_CONFIGURATION IS RECORD
		Interface						: T_NET_MAC_INTERFACE;
		SourceFilter				: T_NET_MAC_INTERFACE_VECTOR(0 TO 7);
		TypeSwitch					: T_NET_MAC_ETHERNETTYPE_VECTOR(0 to 7);
	END RECORD;
	
	-- arrays
	TYPE T_NET_MAC_CONFIGURATION_VECTOR IS ARRAY(NATURAL RANGE <>)	OF T_NET_MAC_CONFIGURATION;
	
	-- functions
	FUNCTION getPortCount(MACConfiguration : T_NET_MAC_CONFIGURATION_VECTOR) RETURN POSITIVE;
	
	-- ==========================================================================================================================================================
	-- local network: sequence and flow control protocol (SFC)
	-- ==========================================================================================================================================================
	-- types
	SUBTYPE T_NET_MAC_SFC_TYPE										IS T_SLV_16;
	
	-- arrays
	TYPE		T_ETH_SFC_TYPE_VECTOR									IS ARRAY (NATURAL RANGE <>) OF T_NET_MAC_SFC_TYPE;
	
	-- predefined constants
	CONSTANT C_NET_MAC_SFC_TYPE_EMPTY							: T_NET_MAC_SFC_TYPE			:= (OTHERS => '0');
	
	-- ==========================================================================================================================================================
	-- internet layer: Internet Protocol - common
	-- ==========================================================================================================================================================
	SUBTYPE T_NET_IP_PROTOCOL											IS T_SLV_8;

	
	-- ==========================================================================================================================================================
	-- internet layer: Internet Protocol Version 4 (IPv4)
	-- ==========================================================================================================================================================
	-- types
	TYPE		T_NET_IPV4_ADDRESS										IS ARRAY (3 DOWNTO 0)				OF T_SLV_8;
	SUBTYPE T_NET_IPV4_PROTOCOL										IS T_NET_IP_PROTOCOL;
	SUBTYPE T_NET_IPV4_TOS_PRECEDENCE							IS STD_LOGIC_VECTOR(2 DOWNTO 0);
		
	TYPE T_NET_IPV4_TYPE_OF_SERVICE IS RECORD
		Precedence					: T_NET_IPV4_TOS_PRECEDENCE;
		Delay								: STD_LOGIC;
		Throughput					: STD_LOGIC;
		Relibility					: STD_LOGIC;
	END RECORD;
	
	-- arrays
	TYPE		T_NET_IPV4_ADDRESS_VECTOR							IS ARRAY (NATURAL RANGE <>) OF T_NET_IPV4_ADDRESS;
	TYPE		T_NET_IPV4_PROTOCOL_VECTOR						IS ARRAY (NATURAL RANGE <>) OF T_NET_IPV4_PROTOCOL;
	TYPE		T_NET_IPV4_TYPE_OF_SERVICE_VECTOR			IS ARRAY (NATURAL RANGE <>) OF T_NET_IPV4_TYPE_OF_SERVICE;
	
	-- predefined constants
	CONSTANT C_NET_IPV4_ADDRESS_EMPTY							: T_NET_IPV4_ADDRESS					:= (OTHERS => (OTHERS => '0'));
	CONSTANT C_NET_IPV4_PROTOCOL_EMPTY						: T_NET_IPV4_PROTOCOL					:= (OTHERS => '0');

	CONSTANT C_NET_IPV4_TOS_PRECEDENCE_ROUTINE								: T_NET_IPV4_TOS_PRECEDENCE			:= "000";
	CONSTANT C_NET_IPV4_TOS_PRECEDENCE_PRIORITY								: T_NET_IPV4_TOS_PRECEDENCE			:= "001";
	CONSTANT C_NET_IPV4_TOS_PRECEDENCE_IMMEDIATE							: T_NET_IPV4_TOS_PRECEDENCE			:= "010";
	CONSTANT C_NET_IPV4_TOS_PRECEDENCE_FLASH									: T_NET_IPV4_TOS_PRECEDENCE			:= "011";
	CONSTANT C_NET_IPV4_TOS_PRECEDENCE_FLASH_OVERRIDE					: T_NET_IPV4_TOS_PRECEDENCE			:= "100";
	CONSTANT C_NET_IPV4_TOS_PRECEDENCE_CRITIC_ECP							: T_NET_IPV4_TOS_PRECEDENCE			:= "101";
	CONSTANT C_NET_IPV4_TOS_PRECEDENCE_INTERNETWORK_CONTROL		: T_NET_IPV4_TOS_PRECEDENCE			:= "110";
	CONSTANT C_NET_IPV4_TOS_PRECEDENCE_NETWORK_CONTROL				: T_NET_IPV4_TOS_PRECEDENCE			:= "111";

	CONSTANT C_NET_IPV4_TOS_DEFAULT								: T_NET_IPV4_TYPE_OF_SERVICE		:= (Precedence => C_NET_IPV4_TOS_PRECEDENCE_ROUTINE, Delay => '0', Throughput => '0', Relibility => '0');

	-- type conversion functions
	FUNCTION to_net_ipv4_address(slv : T_SLV_32)				RETURN T_NET_IPV4_ADDRESS;
	FUNCTION to_net_ipv4_address(str : STRING)					RETURN T_NET_IPV4_ADDRESS;
	FUNCTION to_net_ipv4_type_of_service(slv : T_SLV_8)	RETURN T_NET_IPV4_TYPE_OF_SERVICE;

	FUNCTION to_slv(ip : T_NET_IPV4_ADDRESS)						RETURN STD_LOGIC_VECTOR;
--	FUNCTION to_slv(proto : T_NET_IPV4_PROTOCOL)				RETURN STD_LOGIC_VECTOR;
	FUNCTION to_slv(tos : T_NET_IPV4_TYPE_OF_SERVICE)		RETURN STD_LOGIC_VECTOR;
	
	FUNCTION to_slvv_8(ip : T_NET_IPV4_ADDRESS)		RETURN T_SLVV_8;

	FUNCTION to_string(ip : T_NET_IPV4_ADDRESS)		RETURN STRING;

	-- ==========================================================================================================================================================
	-- internet layer: Internet Protocol Version 6 (IPv6)
	-- ==========================================================================================================================================================
	-- types
	TYPE		T_NET_IPV6_ADDRESS								IS ARRAY (15 DOWNTO 0)				OF T_SLV_8;
	TYPE		T_NET_IPV6_PREFIX									IS RECORD
		Prefix				: T_NET_IPV6_ADDRESS;
		PrefixLength	: STD_LOGIC_VECTOR(6 DOWNTO 0);
	END RECORD;
	SUBTYPE T_NET_IPV6_NEXT_HEADER						IS T_NET_IP_PROTOCOL;
	
	-- arrays
	TYPE		T_NET_IPV6_ADDRESS_VECTOR					IS ARRAY (NATURAL RANGE <>) OF T_NET_IPV6_ADDRESS;
	TYPE		T_NET_IPV6_PREFIX_VECTOR					IS ARRAY (NATURAL RANGE <>) OF T_NET_IPV6_PREFIX;
	TYPE		T_NET_IPV6_NEXT_HEADER_VECTOR			IS ARRAY (NATURAL RANGE <>) OF T_NET_IPV6_NEXT_HEADER;
	
	-- predefined constants
	CONSTANT C_NET_IPV6_ADDRESS_EMPTY					: T_NET_IPV6_ADDRESS				:= (OTHERS => (OTHERS => '0'));
	CONSTANT C_NET_IPV6_NEXT_HEADER_EMPTY			: T_NET_IPV6_NEXT_HEADER		:= (OTHERS => '0');

	-- type conversion functions
	FUNCTION to_net_ipv6_address(slv : T_SLV_128) 	RETURN T_NET_IPV6_ADDRESS;
	FUNCTION to_net_ipv6_address(str : STRING)			RETURN T_NET_IPV6_ADDRESS;
	FUNCTION to_net_ipv6_prefix(str : STRING)				RETURN T_NET_IPV6_PREFIX;

	FUNCTION to_slv(ip : T_NET_IPV6_ADDRESS)				RETURN STD_LOGIC_VECTOR;
	FUNCTION to_slvv_8(ip : T_NET_IPV6_ADDRESS)			RETURN T_SLVV_8;

	FUNCTION to_string(IP : T_NET_IPV6_ADDRESS)			RETURN STRING;
	FUNCTION to_string(Prefix : T_NET_IPV6_PREFIX)	RETURN STRING;

	-- ==========================================================================================================================================================
	-- internet layer: Address Resolution Protocol (ARP)
	-- ==========================================================================================================================================================

	-- commands
	TYPE T_NET_ARP_ARPCACHE_COMMAND IS (
		NET_ARP_ARPCACHE_CMD_NONE,
--		NET_ARP_ARPCACHE_CMD_CLEAR,
		NET_ARP_ARPCACHE_CMD_ADD
--		NET_ARP_ARPCACHE_CMD_INVALIDATE
	);

	-- status
	TYPE T_NET_ARP_ARPCACHE_STATUS IS (
		NET_ARP_ARPCACHE_STATUS_IDLE,
		NET_ARP_ARPCACHE_STATUS_UPDATING,
		NET_ARP_ARPCACHE_STATUS_UPDATE_COMPLETE
	);
	
	TYPE T_NET_ARP_IPPOOL_COMMAND IS (
		NET_ARP_IPPOOL_CMD_NONE,
		NET_ARP_IPPOOL_CMD_ADD,
		NET_ARP_IPPOOL_CMD_EDIT,
		NET_ARP_IPPOOL_CMD_REMOVE
	);
	
	TYPE T_NET_ARP_ARPCACHE_LINE IS RECORD
		Tag				: T_NET_IPV4_ADDRESS;
		MAC				: T_NET_MAC_ADDRESS;
	END RECORD;

	TYPE T_NET_ARP_ARPCACHE_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_NET_ARP_ARPCACHE_LINE;
	
	-- commands
	TYPE T_NET_ARP_TESTER_COMMAND IS (
		NET_ARP_TESTER_CMD_NONE,
		NET_ARP_TESTER_CMD_LOOP
	);

	-- status
	TYPE T_NET_ARP_TESTER_STATUS IS (
		NET_ARP_TESTER_STATUS_IDLE,
		NET_ARP_TESTER_STATUS_TESTING,
		NET_ARP_TESTER_STATUS_TEST_COMPLETE
	);
	
	-- ==========================================================================================================================================================
	-- internet layer: Internet Control Message Protocol (ICMP)
	-- ==========================================================================================================================================================
	SUBTYPE T_NET_ICMPV4_TYPE						IS T_SLV_8;
	SUBTYPE T_NET_ICMPV4_CODE						IS T_SLV_8;

	-- commands
	TYPE T_NET_ICMPV4_COMMAND IS (
		NET_ICMPV4_CMD_NONE,
		NET_ICMPV4_CMD_ECHO_REQUEST
	);
	
	TYPE T_NET_ICMPV4_TX_COMMAND IS (
		NET_ICMPV4_TX_CMD_NONE,
		NET_ICMPV4_TX_CMD_ECHO_REQUEST,
		NET_ICMPV4_TX_CMD_ECHO_REPLY
	);
	
	TYPE T_NET_ICMPV4_RX_COMMAND IS (
		NET_ICMPV4_RX_CMD_NONE,
		NET_ICMPV4_RX_CMD_CLEAR
	);

	-- status
	TYPE T_NET_ICMPV4_STATUS IS (
		NET_ICMPV4_STATUS_IDLE,
		NET_ICMPV4_STATUS_SENDING,
		NET_ICMPV4_STATUS_SEND_COMPLETE,
		NET_ICMPV4_STATUS_ERROR
	);

	TYPE T_NET_ICMPV4_TX_STATUS IS (
		NET_ICMPV4_TX_STATUS_IDLE,
		NET_ICMPV4_TX_STATUS_SENDING,
		NET_ICMPV4_TX_STATUS_SEND_COMPLETE,
		NET_ICMPV4_TX_STATUS_ERROR
	);

	TYPE T_NET_ICMPV4_RX_STATUS IS (
		NET_ICMPV4_RX_STATUS_IDLE,
		NET_ICMPV4_RX_STATUS_RECEIVING,
		NET_ICMPV4_RX_STATUS_RECEIVED_ECHO_REQUEST,
		NET_ICMPV4_RX_STATUS_RECEIVED_ECHO_REPLY,
		NET_ICMPV4_RX_STATUS_ERROR
	);

	-- errors
	TYPE T_NET_ICMPV4_ERROR IS (
		NET_ICMPV4_ERROR_NONE,
		NET_ICMPV4_ERROR_TIMEOUT,
		NET_ICMPV4_ERROR_RECEIVED_CORRUPT_MESSAGE,
		NET_ICMPV4_ERROR_MESSAGE_NOT_SUPPORTED,
		NET_ICMPV4_ERROR_FSM
	);

	TYPE T_NET_ICMPV4_TX_ERROR IS (
		NET_ICMPV4_TX_ERROR_NONE,
		NET_ICMPV4_TX_ERROR_FSM
	);

	TYPE T_NET_ICMPV4_RX_ERROR IS (
		NET_ICMPV4_RX_ERROR_NONE,
		NET_ICMPV4_RX_ERROR_UNKNOWN_CODE,
		NET_ICMPV4_RX_ERROR_UNKNOWN_TYPE,
		NET_ICMPV4_RX_ERROR_CHECKSUM_ERROR,
		NET_ICMPV4_RX_ERROR_FSM
	);

	-- ==========================================================================================================================================================
	-- internet layer: Internet Control Message Protocol for IPv6 (ICMPv6)
	-- ==========================================================================================================================================================
	SUBTYPE T_NET_ICMPV6_TYPE						IS T_SLV_8;
	SUBTYPE T_NET_ICMPV6_CODE						IS T_SLV_8;

	-- ==========================================================================================================================================================
	-- internet layer: Neighbor Discovery Protocol (NDP)
	-- ==========================================================================================================================================================
	TYPE T_NET_NDP_DESTINATIONCACHE_LINE IS RECORD
		Tag				: T_NET_IPV6_ADDRESS;
		NextHop		: T_NET_IPV6_ADDRESS;
	END RECORD;
	
	TYPE T_NET_NDP_NEIGHBORCACHE_LINE IS RECORD
		Tag				: T_NET_IPV6_ADDRESS;
		MAC				: T_NET_MAC_ADDRESS;
	END RECORD;

	TYPE T_NET_NDP_DESTINATIONCACHE_VECTOR	IS ARRAY (NATURAL RANGE <>)	OF T_NET_NDP_DESTINATIONCACHE_LINE;
	TYPE T_NET_NDP_NEIGHBORCACHE_VECTOR			IS ARRAY (NATURAL RANGE <>)	OF T_NET_NDP_NEIGHBORCACHE_LINE;

	TYPE T_NET_NDP_REACHABILITY_STATE IS (
		NET_NDP_REACHABILITY_STATE_UNKNOWN,
		NET_NDP_REACHABILITY_STATE_INCOMPLETE,
		NET_NDP_REACHABILITY_STATE_REACHABLE,
		NET_NDP_REACHABILITY_STATE_STALE,
		NET_NDP_REACHABILITY_STATE_DELAY,
		NET_NDP_REACHABILITY_STATE_PROBE
	);

	-- ==========================================================================================================================================================
	-- transport layer: User Datagram Protocol (UDP)
	-- ==========================================================================================================================================================
	SUBTYPE T_NET_UDP_PORT								IS T_SLV_16;
	
	
	TYPE		T_NET_UDP_PORTPAIR IS RECORD
		Ingress			: T_NET_UDP_PORT;				-- incoming port number
		Egress			: T_NET_UDP_PORT;				-- outgoing port number
	END RECORD;
	
	TYPE		T_NET_UDP_PORTPAIR_VECTOR			IS ARRAY(NATURAL RANGE <>) OF T_NET_UDP_PORTPAIR;


	-- ==========================================================================================================================================================
	-- Ethernet: known Ethernet Types
	-- ==========================================================================================================================================================
	--	add user defined ethernet types here:
	CONSTANT C_NET_MAC_ETHERNETTYPE_SSFC						: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"A987");		-- Andreas Hoeer - SFC Protocol - simple version (length-field, type-field)
	CONSTANT C_NET_MAC_ETHERNETTYPE_SWAP						: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"FFFE");		-- Xilinx Ethernet Frame Swap Module
	CONSTANT C_NET_MAC_ETHERNETTYPE_LOOPBACK				: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"FFFF");		-- Frame Loopback module

-- Ethernet Types, see:			http://en.wikipedia.org/wiki/EtherType
-- for complete liste see:	http://standards.ieee.org/develop/regauth/ethertype/eth.txt
-- see also:								http://www.iana.org/assignments/ieee-802-numbers/ieee-802-numbers.xml
	CONSTANT C_NET_MAC_ETHERNETTYPE_IPV4						: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"0800");		-- Internet Protocol, Version 4 (IPv4)
	CONSTANT C_NET_MAC_ETHERNETTYPE_ARP							: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"0806");		-- Address Resolution Protocol (ARP)
	CONSTANT C_NET_MAC_ETHERNETTYPE_WOL							: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"0842");		-- Wake-on-LAN Magic Packet, as used by ether-wake and Sleep Proxy Service
	CONSTANT C_NET_MAC_ETHERNETTYPE_VLAN						: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"8100");		-- VLAN-tagged frame (IEEE 802.1Q) & Shortest Path Bridging IEEE 802.1aq[3]
	CONSTANT C_NET_MAC_ETHERNETTYPE_SNMP						: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"814C");		-- Simple Network Management Protocol (SNMP)[4]
	CONSTANT C_NET_MAC_ETHERNETTYPE_IPV6						: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"86DD");		-- Internet Protocol, Version 6 (IPv6)
	CONSTANT C_NET_MAC_ETHERNETTYPE_MACCONTROL			: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"8808");		-- MAC Control
	CONSTANT C_NET_MAC_ETHERNETTYPE_JUMBOFRAMES			: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"8870");		-- Jumbo Frames
	CONSTANT C_NET_MAC_ETHERNETTYPE_QINQ						: T_NET_MAC_ETHERNETTYPE		:= to_net_mac_ethernettype(x"9100");		-- Q-in-Q

	-- ==========================================================================================================================================================
	-- Internet Layer: known Upper-Layer Protocols for Internet Protocol
	-- ==========================================================================================================================================================
	CONSTANT C_NET_IP_PROTOCOL_LOOPBACK							: T_NET_IP_PROTOCOL					:= x"FF";		-- 					(255) - IANA reserved (used for loopback)						
	
	CONSTANT C_NET_IP_PROTOCOL_IPV4									: T_NET_IP_PROTOCOL					:= x"04";		-- 					(	 4) - IPv4 Header																	RFC 2003
	CONSTANT C_NET_IP_PROTOCOL_IPv6									: T_NET_IP_PROTOCOL					:= x"29";		-- 					(	41) - IPv6 Header - IPv6 Encapsulation						RFC 2473
	CONSTANT C_NET_IP_PROTOCOL_IPV6_HOP_BY_HOP			: T_NET_IP_PROTOCOL					:= x"00";		-- 					(	 0) - IPv6 Ext. Header - Hop-by-Hop Option				RFC 2460
	CONSTANT C_NET_IP_PROTOCOL_IPV6_ROUTING					: T_NET_IP_PROTOCOL					:= x"2B";		-- 					(	43) - IPv6 Ext. Header - Routing Header						RFC 2460
	CONSTANT C_NET_IP_PROTOCOL_IPV6_FRAGMENTATION		: T_NET_IP_PROTOCOL					:= x"2C";		-- 					(	44) - IPv6 Ext. Header - Fragmentation Header			RFC 2460
	CONSTANT C_NET_IP_PROTOCOL_IPV6_ICMP						: T_NET_IP_PROTOCOL					:= x"3A";		-- ICMPv6		(	58) - Internet Control Message Protocol for IPv6	RFC ----
	CONSTANT C_NET_IP_PROTOCOL_IPV6_NO_NEXT_HEADER	: T_NET_IP_PROTOCOL					:= x"3B";		-- 					(	59) - IPv6 Ext. Header - No Next Header						RFC 2460
	CONSTANT C_NET_IP_PROTOCOL_IPV6_DEST_OPTIONS		: T_NET_IP_PROTOCOL					:= x"3C";		-- 					(	60) - IPv6 Ext. Header - Destination Options			RFC 2460
																											
	CONSTANT C_NET_IP_PROTOCOL_ICMP									: T_NET_IP_PROTOCOL					:= x"01";		-- ICMP			(	 1)	- Internet Control Message Protocol						RFC	 792
	CONSTANT C_NET_IP_PROTOCOL_IGMP									: T_NET_IP_PROTOCOL					:= x"02";		-- IGMP			(	 2)	- Internet Group Management Protocol					RFC	1112
																											
	CONSTANT C_NET_IP_PROTOCOL_TCP									: T_NET_IP_PROTOCOL					:= x"06";		-- TCP			(	 6)	- Transmission Control Protocol								RFC	 793
	CONSTANT C_NET_IP_PROTOCOL_SCTP									: T_NET_IP_PROTOCOL					:= x"84";		-- SCTP 		(132) - Stream Control Transmission Protocol				RFC	----
	CONSTANT C_NET_IP_PROTOCOL_UDP									: T_NET_IP_PROTOCOL					:= x"11";		-- UDP			(	17)	- User Datagram Protocol											RFC	 768
	CONSTANT C_NET_IP_PROTOCOL_UDP_LITE							: T_NET_IP_PROTOCOL					:= x"88";		-- UDPLite	(136) - UDP Lite																		RFC	3828
																											
	CONSTANT C_NET_IP_PROTOCOL_L2TP									: T_NET_IP_PROTOCOL					:= x"73";		-- L2TP			(115) - Layer Two Tunneling Protocol								RFC	3931

	-- ==========================================================================================================================================================
	-- Internet Layer: known Internet Control Message Protocol Types and Codes
	-- ==========================================================================================================================================================
	-- ICMPv4 Types
	CONSTANT C_NET_ICMPV4_TYPE_EMPTY										: T_NET_ICMPV4_TYPE	:= x"00";		-- empty type field
	CONSTANT C_NET_ICMPV4_TYPE_ECHO_REPLY								: T_NET_ICMPV4_TYPE	:= x"00";		-- Echo-Reply
	CONSTANT C_NET_ICMPV4_TYPE_DEST_UNREACHABLE					: T_NET_ICMPV4_TYPE	:= x"03";		-- Destination unreachable
	CONSTANT C_NET_ICMPV4_TYPE_SOURCE_QUENCH						: T_NET_ICMPV4_TYPE	:= x"04";		-- Source Quench
	CONSTANT C_NET_ICMPV4_TYPE_REDIRECT									: T_NET_ICMPV4_TYPE	:= x"05";		-- Redirect
	CONSTANT C_NET_ICMPV4_TYPE_ECHO_REQUEST							: T_NET_ICMPV4_TYPE	:= x"08";		-- Echo-Request
	CONSTANT C_NET_ICMPV4_TYPE_TIME_EXCEEDED						: T_NET_ICMPV4_TYPE	:= x"0B";		-- Time Exceeded
	CONSTANT C_NET_ICMPV4_TYPE_PARAMETER_PROBLEM				: T_NET_ICMPV4_TYPE	:= x"0C";		-- Parameter Problem

	-- ICMPv4 Codes
	CONSTANT C_NET_ICMPV4_CODE_EMPTY										: T_NET_ICMPV4_CODE	:= x"00";		-- empty code field

	-- ICMPv4 Codes for Type Destination Unreachable
	CONSTANT C_NET_ICMPV4_CODE_NET_UNREACHABLE					: T_NET_ICMPV4_CODE	:= x"00";		-- Network unreachable
	CONSTANT C_NET_ICMPV4_CODE_HOST_UNREACHABLE					: T_NET_ICMPV4_CODE	:= x"01";		-- Host unreachable
	CONSTANT C_NET_ICMPV4_CODE_PROTOCOL_UNREACHABLE			: T_NET_ICMPV4_CODE	:= x"02";		-- Protocol unreachable
	CONSTANT C_NET_ICMPV4_CODE_PORT_UNREACHABLE					: T_NET_ICMPV4_CODE	:= x"03";		-- Port unreachable
	CONSTANT C_NET_ICMPV4_CODE_FRAGMENTATION_NEEDED			: T_NET_ICMPV4_CODE	:= x"04";		-- Fragmentation needed, but DF set
	CONSTANT C_NET_ICMPV4_CODE_SOURCE_ROUTE_FAILED			: T_NET_ICMPV4_CODE	:= x"05";		-- Source route failed

	-- ICMPv4 Codes for Type Time Exceeded
	CONSTANT C_NET_ICMPV4_CODE_TIME_TO_LIVE_EXCEEDED		: T_NET_ICMPV4_CODE	:= x"00";		-- Hop limit exceeded in transit
	CONSTANT C_NET_ICMPV4_CODE_FRAG_REASS_TIME_EXCEEDED	: T_NET_ICMPV4_CODE	:= x"01";		-- Fragment reassembly time exceeded
	
	-- ICMPv4 Codes for Type Echo Request
	CONSTANT C_NET_ICMPV4_CODE_ECHO_REQUEST							: T_NET_ICMPV4_CODE	:= x"00";		-- Echo Request
	
	-- ICMPv4 Codes for Type Echo Reply
	CONSTANT C_NET_ICMPV4_CODE_ECHO_REPLY								: T_NET_ICMPV4_CODE	:= x"00";		-- Echo Reply


	-- ==========================================================================================================================================================
	-- Internet Layer: known Internet Control Message Protocol (for IPv6) Types and Codes
	-- ==========================================================================================================================================================
	-- ICMPv6 Types - Errors
	CONSTANT C_NET_ICMPV6_TYPE_DEST_UNREACHABLE				: T_NET_ICMPV6_TYPE	:= x"01";		-- Destination unreachable
	CONSTANT C_NET_ICMPV6_TYPE_PACKET_TOO_BIG					: T_NET_ICMPV6_TYPE	:= x"02";		-- Packet Too Big
	CONSTANT C_NET_ICMPV6_TYPE_TIME_EXCEEDED					: T_NET_ICMPV6_TYPE	:= x"03";		-- Time Exceeded
	CONSTANT C_NET_ICMPV6_TYPE_PARAMETER_PROBLEM			: T_NET_ICMPV6_TYPE	:= x"04";		-- Parameter Problem
	CONSTANT C_NET_ICMPV6_TYPE_ERROR_EXP							: T_NET_ICMPV6_TYPE	:= x"7F";		-- 
	-- ICMPv6 Types - Information
	CONSTANT C_NET_ICMPV6_TYPE_ECHO_REQUEST						: T_NET_ICMPV6_TYPE	:= x"80";		-- Echo Request
	CONSTANT C_NET_ICMPV6_TYPE_ECHO_REPLY							: T_NET_ICMPV6_TYPE	:= x"81";		-- Echo Reply
	CONSTANT C_NET_ICMPV6_TYPE_INFORMANTION_EXP				: T_NET_ICMPV6_TYPE	:= x"FF";		-- 

	-- ICMPv6 Codes
	CONSTANT C_NET_ICMPV6_CODE_EMPTY									: T_NET_ICMPV6_CODE	:= x"00";		-- empty code field

	-- ICMPv6 Codes for Type Destination Unreachable
	CONSTANT C_NET_ICMPV6_CODE_NO_ROUTE_TO_DEST				: T_NET_ICMPV6_CODE	:= x"00";		-- No route to destination
	CONSTANT C_NET_ICMPV6_CODE_COM_PROHIBITED					: T_NET_ICMPV6_CODE	:= x"01";		-- Communication with destination administratively prohibited
	CONSTANT C_NET_ICMPV6_CODE_BEYOND_SCOPE						: T_NET_ICMPV6_CODE	:= x"02";		-- Beyond scope of source address
	CONSTANT C_NET_ICMPV6_CODE_ADDRESS_UNREACHABLE		: T_NET_ICMPV6_CODE	:= x"03";		-- Address unreachable
	CONSTANT C_NET_ICMPV6_CODE_PORT_UNREACHABLE				: T_NET_ICMPV6_CODE	:= x"04";		-- Port unreachable
	CONSTANT C_NET_ICMPV6_CODE_ADDRESS_FAILED_POLICY	: T_NET_ICMPV6_CODE	:= x"05";		-- Source address failed ingress/egress policy
	CONSTANT C_NET_ICMPV6_CODE_REJECT_ROUTE_TO_DEST		: T_NET_ICMPV6_CODE	:= x"06";		-- Reject route to destination
	
	-- ICMPv6 Codes for Type Packet Too Big
	CONSTANT C_NET_ICMPV6_CODE_PACKET_TOO_BIG					: T_NET_ICMPV6_CODE	:= x"00";		-- Packet Too Big

	-- ICMPv6 Codes for Type Time Exceeded
	CONSTANT C_NET_ICMPV6_CODE_HOP_LIMIT_EXCEEDED			: T_NET_ICMPV6_CODE	:= x"00";		-- Hop limit exceeded in transit
	CONSTANT C_NET_ICMPV6_CODE_REASS_TIME_EXCEEDED		: T_NET_ICMPV6_CODE	:= x"01";		-- Fragment reassembly time exceeded
	
	-- ICMPv6 Codes for Type Parameter Problem
	CONSTANT C_NET_ICMPV6_CODE_HEADER_FIELD_ERROR			: T_NET_ICMPV6_CODE	:= x"00";		-- Erroneous header field encountered
	CONSTANT C_NET_ICMPV6_CODE_NEXT_HEADER_ERROR			: T_NET_ICMPV6_CODE	:= x"01";		-- Unrecognized Next Header type encountered
	CONSTANT C_NET_ICMPV6_CODE_IPV6_OPTION_ERROR			: T_NET_ICMPV6_CODE	:= x"02";		-- Unrecognized IPv6 option encountered
	
	-- ICMPv6 Codes for Type Echo Request
	CONSTANT C_NET_ICMPV6_CODE_ECHO_REQUEST						: T_NET_ICMPV6_CODE	:= x"00";		-- Echo Request
	
	-- ICMPv6 Codes for Type Echo Reply
	CONSTANT C_NET_ICMPV6_CODE_ECHO_REPLY							: T_NET_ICMPV6_CODE	:= x"00";		-- Echo Reply
	
END;

PACKAGE BODY EthTypes IS

	FUNCTION getPortCount(MACConfiguration : T_NET_MAC_CONFIGURATION_VECTOR) RETURN POSITIVE IS
		VARIABLE count : NATURAL := 0;
	BEGIN
		FOR I IN MACConfiguration'range LOOP
			FOR J IN MACConfiguration(I).TypeSwitch'range LOOP
				IF (MACConfiguration(I).TypeSwitch(J) /= C_NET_MAC_ETHERNETTYPE_EMPTY) THEN
					count := count + 1;
				END IF;
			END LOOP;
		END LOOP;
	
		RETURN count;
	END FUNCTION;

	-- ==========================================================================================================================================================
	-- Ethernet: MAC Data-Link-Layer
	-- ==========================================================================================================================================================
	FUNCTION to_net_mac_address(slv : T_SLV_48) RETURN T_NET_MAC_ADDRESS IS
		VARIABLE mac					: T_NET_MAC_ADDRESS;
	BEGIN
		FOR I IN 0 TO 5 LOOP
			mac(I)	:=	slv(((I * 8) + 7) DOWNTO (I * 8));
		END LOOP;
		RETURN mac;
	END FUNCTION;

	FUNCTION to_net_mac_address(slvv : T_SLVV_8) RETURN T_NET_MAC_ADDRESS IS
		VARIABLE mac					: T_NET_MAC_ADDRESS;
	BEGIN
		IF (slvv'length /= 6) THEN REPORT "to_net_mac_address: vector-length mismatch - slvv'length=" & INTEGER'image(slvv'length) SEVERITY ERROR; END IF;
		FOR I IN slvv'range LOOP
			mac(I)	:=	slvv(I);
		END LOOP;
		RETURN mac;
	END FUNCTION;

	SUBTYPE MAC_ADDRESS_SEGMENT					IS STRING(1 TO 2);
	TYPE		MAC_ADDRESS_SEGMENT_VECTOR	IS ARRAY (NATURAL RANGE <>) OF MAC_ADDRESS_SEGMENT;
	
	FUNCTION mac_split(str : STRING) RETURN MAC_ADDRESS_SEGMENT_VECTOR IS
		VARIABLE input								: STRING(str'range)											:= str_to_upper(str);
		VARIABLE Segments							: MAC_ADDRESS_SEGMENT_VECTOR(0 TO 5)		:= (OTHERS => (OTHERS => '0'));
		VARIABLE SegmentPointer				: NATURAL																:= 0;
		VARIABLE CharPointer					: NATURAL																:= 2;
	BEGIN
--		REPORT "mac_split of " & str SEVERITY NOTE;
		FOR I IN str'reverse_range LOOP
--			REPORT "  char=" & input(I) SEVERITY NOTE;
			IF (to_digit(input(I), 'h') /= -1) THEN
				Segments(SegmentPointer)(CharPointer)	:= input(I);
--				REPORT "    copy to seg=" & INTEGER'image(SegmentPointer) & "  pos=" & INTEGER'image(CharPointer) SEVERITY NOTE;
				CharPointer					:= Charpointer - 1;
			ELSIF ((input(I) = ':') OR (input(I) = '-')) THEN
				SegmentPointer		:= SegmentPointer + 1;
				CharPointer				:= 2;
			ELSE
				REPORT "ERROR - unknown char [" & input(I) & "]" SEVERITY ERROR;
			END IF;
		END LOOP;
	
		RETURN Segments;
	END FUNCTION;
	
	-- converts MAC address strings to T_NET_MAC_ADDRESS
	-- allowed delimiter signs: ':' or '-'
	FUNCTION to_net_mac_address(str : STRING) RETURN T_NET_MAC_ADDRESS IS
		VARIABLE Segments				: MAC_ADDRESS_SEGMENT_VECTOR(0 TO 5)	:= mac_split(str);
		VARIABLE MAC						: T_NET_MAC_ADDRESS;
	BEGIN
		FOR I IN Segments'range LOOP
			MAC(I)	:= to_slv(to_nat(Segments(I), 'h'), 8);
		END LOOP;
		RETURN MAC;
	END FUNCTION;

	FUNCTION to_net_mac_ethernettype(slv : T_SLV_16) RETURN T_NET_MAC_ETHERNETTYPE IS
		VARIABLE EthType					: T_NET_MAC_ETHERNETTYPE;
	BEGIN
		FOR I IN 0 TO 1 LOOP
			EthType(I)	:=	slv(((I * 8) + 7) DOWNTO (I * 8));
		END LOOP;
		RETURN EthType;
	END FUNCTION;

	FUNCTION to_slv(mac : T_NET_MAC_ADDRESS) RETURN STD_LOGIC_VECTOR IS
		VARIABLE slv		: T_SLV_48;
	BEGIN
		FOR I IN 0 TO 5 LOOP
			slv(((I * 8) + 7) DOWNTO (I * 8))		:= mac(I);
		END LOOP;
		RETURN slv;
	END FUNCTION;

	FUNCTION to_slv(EthType : T_NET_MAC_ETHERNETTYPE) RETURN STD_LOGIC_VECTOR IS
		VARIABLE slv		: T_SLV_16;
	BEGIN
		FOR I IN 0 TO 1 LOOP
			slv(((I * 8) + 7) DOWNTO (I * 8))		:= EthType(I);
		END LOOP;
		RETURN slv;
	END FUNCTION;

	FUNCTION to_slvv_8(mac : T_NET_MAC_ADDRESS) RETURN T_SLVV_8 IS
		VARIABLE slvv : T_SLVV_8(mac'range);
	BEGIN
		FOR I IN mac'range LOOP
			slvv(I)	:= mac(I);
		END LOOP;
		RETURN slvv;
	END FUNCTION;
	
	FUNCTION to_slvv_8(EthType : T_NET_MAC_ETHERNETTYPE) RETURN T_SLVV_8 IS
		VARIABLE slvv : T_SLVV_8(EthType'range);
	BEGIN
		FOR I IN EthType'range LOOP
			slvv(I)	:= EthType(I);
		END LOOP;
		RETURN slvv;
	END FUNCTION;

	FUNCTION to_string(mac : T_NET_MAC_ADDRESS) RETURN STRING IS
		VARIABLE str		: STRING(1 TO 18)		:= (OTHERS => ':');
	BEGIN
		FOR I IN 0 TO 5 LOOP
			str((I * 3) + 1 TO (I * 3) + 2)	:= to_string(mac(5 - I), 'h');
		END LOOP;
		RETURN str(1 TO 17);
	END FUNCTION;

	FUNCTION to_string(EthType : T_NET_MAC_ETHERNETTYPE) RETURN STRING IS
	BEGIN
		CASE to_slv(EthType) IS
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_EMPTY) =>				RETURN "Empty";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_ARP) =>					RETURN "ARP";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_IPV4) =>					RETURN "IPv4";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_IPV6) =>					RETURN "IPv6";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_JUMBOFRAMES) =>	RETURN "Jumbo";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_MACCONTROL) =>		RETURN "MACControl";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_QINQ) =>					RETURN "QinQ";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_SNMP) =>					RETURN "SNMP";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_VLAN) =>					RETURN "VLAN";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_WOL) =>					RETURN "WOL";
			
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_SWAP) =>					RETURN "Swap";
			WHEN to_slv(C_NET_MAC_ETHERNETTYPE_LOOPBACK) =>			RETURN "LoopBack";
			WHEN OTHERS =>																			RETURN "0x" & to_string(to_slv(EthType), 'h');
		END CASE;
	END FUNCTION;

	-- ==========================================================================================================================================================
	-- internet layer: Internet Protocol Version 4 (IPv4)
	-- ==========================================================================================================================================================
	FUNCTION to_net_ipv4_address(slv : T_SLV_32) RETURN T_NET_IPV4_ADDRESS IS
		VARIABLE ip					: T_NET_IPV4_ADDRESS;
	BEGIN
		FOR I IN 0 TO 3 LOOP
			ip(I)	:=	slv(((I * 8) + 7) DOWNTO (I * 8));
		END LOOP;
		RETURN ip;
	END FUNCTION;
	
	SUBTYPE IPV4_ADDRESS_SEGMENT					IS STRING(1 TO 3);
	TYPE		IPV4_ADDRESS_SEGMENT_VECTOR		IS ARRAY (NATURAL RANGE <>) OF IPV4_ADDRESS_SEGMENT;
	
	FUNCTION ipv4_split(str : STRING) RETURN IPV4_ADDRESS_SEGMENT_VECTOR IS
		VARIABLE input								: STRING(str'range)											:= str_to_upper(str);
		VARIABLE Segments							: IPV4_ADDRESS_SEGMENT_VECTOR(0 TO 3)		:= (OTHERS => (OTHERS => '0'));
		VARIABLE SegmentPointer				: NATURAL																:= 0;
		VARIABLE CharPointer					: NATURAL																:= 3;
	BEGIN
--		REPORT "ipv4_split of " & str SEVERITY NOTE;
		FOR I IN str'reverse_range LOOP
--			REPORT "  char=" & input(I) SEVERITY NOTE;
			IF (to_digit(input(I), 'd') /= -1) THEN
				Segments(SegmentPointer)(CharPointer)	:= input(I);
--				REPORT "    copy to seg=" & INTEGER'image(SegmentPointer) & "  pos=" & INTEGER'image(CharPointer) SEVERITY NOTE;
				CharPointer					:= Charpointer - 1;
			ELSIF (input(I) = '.') THEN
				SegmentPointer		:= SegmentPointer + 1;
				CharPointer				:= 3;
			ELSE
				REPORT "ERROR - unknown char" SEVERITY ERROR;
			END IF;
		END LOOP;
	
		RETURN Segments;
	END FUNCTION;
	
	-- converts MAC address strings to T_NET_MAC_ADDRESS
	--	allowed delimiter sign: '.'
	FUNCTION to_net_ipv4_address(str : STRING) RETURN T_NET_IPV4_ADDRESS IS
		VARIABLE Segments				: IPV4_ADDRESS_SEGMENT_VECTOR(0 TO 3)	:= ipv4_split(str);
		VARIABLE Segment				: T_SLV_8;
		VARIABLE IP							: T_NET_IPV4_ADDRESS;
	BEGIN
		FOR I IN Segments'range LOOP
			IP(I) := to_slv(to_nat(Segments(I), 'd'), 8);
		END LOOP;
		RETURN IP;
	END FUNCTION;

	FUNCTION to_net_ipv4_type_of_service(slv : T_SLV_8)	RETURN T_NET_IPV4_TYPE_OF_SERVICE IS
		VARIABLE tos			: T_NET_IPV4_TYPE_OF_SERVICE;
	BEGIN
		tos.Precedence		:= slv(2 DOWNTO 0);
		tos.Delay					:= slv(3);
		tos.Throughput		:= slv(4);
		tos.Relibility		:= slv(5);
		RETURN tos;
	END FUNCTION;

	FUNCTION to_slv(ip : T_NET_IPV4_ADDRESS) RETURN STD_LOGIC_VECTOR IS
		VARIABLE slv						: T_SLV_32;
	BEGIN
		FOR I IN 0 TO 3 LOOP
			slv(((I * 8) + 7) DOWNTO (I * 8))		:= ip(I);
		END LOOP;
		RETURN slv;
	END FUNCTION;
--
--	FUNCTION to_slv(proto : T_NET_IPV4_PROTOCOL) RETURN STD_LOGIC_VECTOR IS
--		VARIABLE slv						: T_SLV_8;
--	BEGIN
--		slv := proto;
--		RETURN slv;
--	END FUNCTION;

	FUNCTION to_slv(tos : T_NET_IPV4_TYPE_OF_SERVICE)	RETURN STD_LOGIC_VECTOR IS
		VARIABLE slv						: T_SLV_8;
	BEGIN
		slv(2 DOWNTO 0)		:= tos.Precedence;
		slv(3)						:= tos.Delay;
		slv(4)						:= tos.Throughput;
		slv(5)						:= tos.Relibility;
		slv(7 DOWNTO 6)		:= "00";
		RETURN slv;
	END FUNCTION;

	FUNCTION to_slvv_8(ip : T_NET_IPV4_ADDRESS) RETURN T_SLVV_8 IS
		VARIABLE slvv						: T_SLVV_8(ip'range);
	BEGIN
		FOR I IN ip'range LOOP
			slvv(I)	:= ip(I);
		END LOOP;
		RETURN slvv;
	END FUNCTION;

	FUNCTION to_string(IP : T_NET_IPV4_ADDRESS) RETURN STRING IS
		VARIABLE temp						: STRING(1 TO 16)			:= (OTHERS => '.');
		VARIABLE str						: STRING(1 TO 3);
		VARIABLE len						: POSITIVE;
		VARIABLE CharPointer		: NATURAL							:= 1;

	BEGIN
--		REPORT "converting IPv4 address" SEVERITY NOTE;
		FOR I IN 3 DOWNTO 0 LOOP
--			REPORT "  I=" & INTEGER'image(I) & "  IP(I)=" & INTEGER'image(to_integer(unsigned(IP(I)))) & "  CP=" & INTEGER'image(CharPointer) SEVERITY NOTE;

			str := resize(INTEGER'image(to_integer(unsigned(IP(I)))), str'length);
			len	:= str_length(str);
			temp(CharPointer TO CharPointer + len - 1)	:= str(1 TO len);
			CharPointer := CharPointer + len + 1;
		END LOOP;
	
		RETURN temp(1 TO CharPointer - 2);
	END FUNCTION;

	-- ==========================================================================================================================================================
	-- internet layer: Internet Protocol Version 6 (IPv6)
	-- ==========================================================================================================================================================
	FUNCTION to_net_ipv6_address(slv : T_SLV_128) RETURN T_NET_IPV6_ADDRESS IS
		VARIABLE ip					: T_NET_IPV6_ADDRESS;
	BEGIN
		FOR I IN 0 TO 15 LOOP
			ip(I)	:=	slv(((I * 8) + 7) DOWNTO (I * 8));
		END LOOP;
	
		RETURN ip;
	END FUNCTION;
	
	SUBTYPE IPV6_ADDRESS_SEGMENT					IS STRING(1 TO 4);
	TYPE		IPV6_ADDRESS_SEGMENT_VECTOR		IS ARRAY (NATURAL RANGE <>) OF IPV6_ADDRESS_SEGMENT;
	
	FUNCTION ipv6_split(str : STRING) RETURN IPV6_ADDRESS_SEGMENT_VECTOR IS
		VARIABLE input								: STRING(str'range)											:= str_to_upper(str);
		VARIABLE Segments							: IPV6_ADDRESS_SEGMENT_VECTOR(0 TO 7)		:= (OTHERS => (OTHERS => '0'));
		VARIABLE DelimiterPointer			: NATURAL																:= 0;
		VARIABLE SegmentPointer				: NATURAL																:= 0;
		VARIABLE CharPointer					: NATURAL																:= 4;
		VARIABLE RemainingDelimiters	: NATURAL																:= 0;
	BEGIN
--		REPORT "ipv6_split of " & str SEVERITY NOTE;
		
		FOR I IN str'reverse_range LOOP
--			REPORT "  char=" & input(I) SEVERITY NOTE;
			IF (to_digit(input(I), 'h') /= -1) THEN
				Segments(SegmentPointer)(CharPointer)	:= input(I);
--				REPORT "    copy to seg=" & INTEGER'image(SegmentPointer) & "  pos=" & INTEGER'image(CharPointer) SEVERITY NOTE;
				CharPointer					:= Charpointer - 1;
				DelimiterPointer		:= 0;
			ELSIF (input(I) = ':') THEN
				IF (DelimiterPointer = 0) THEN
					SegmentPointer		:= SegmentPointer + 1;
					CharPointer				:= 4;
					DelimiterPointer	:= I;
				ELSE
					-- count remaining segments-delimiters
					FOR J IN I - 1 DOWNTO input'low LOOP
						IF (input(J) = ':') THEN
							RemainingDelimiters	:= RemainingDelimiters + 1;
						END IF;
					END LOOP;
--					REPORT "    lookahead rem-del=" & INTEGER'image(RemainingDelimiters) SEVERITY NOTE;
					SegmentPointer		:= 7 - RemainingDelimiters;
					CharPointer				:= 4;
					DelimiterPointer	:= 0;
				END IF;
			ELSE
				REPORT "    ERROR - unknown char" SEVERITY ERROR;
			END IF;
		END LOOP;
	
		RETURN Segments;
	END FUNCTION;
	
	FUNCTION to_net_ipv6_address(str : STRING) RETURN T_NET_IPV6_ADDRESS IS
		VARIABLE Segments				: IPV6_ADDRESS_SEGMENT_VECTOR(0 TO 7)	:= ipv6_split(str);
		VARIABLE Segment				: T_SLV_16;
		VARIABLE IP							: T_NET_IPV6_ADDRESS;
	BEGIN
		FOR I IN Segments'range LOOP
			Segment								:= to_slv(to_nat(Segments(I), 'h'), 16);
			IP(I * 2)							:= Segment(7 DOWNTO 0);
			IP((I * 2) + 1)				:= Segment(15 DOWNTO 8);
		END LOOP;
		RETURN IP;
	END FUNCTION;
	
	FUNCTION to_net_ipv6_prefix(str : STRING) RETURN T_NET_IPV6_PREFIX IS
		VARIABLE Pos						: POSITIVE;
		VARIABLE Prefix					: T_NET_IPV6_PREFIX;
		VARIABLE IPv6Address		: T_NET_IPV6_ADDRESS;
		VARIABLE Len						: NATURAL;
	BEGIN
		FOR I IN str'reverse_range LOOP
			IF (str(I) = '/') THEN
				Pos := I;
				EXIT;
			END IF;
		END LOOP;
	
		IF (Pos = str'high) THEN REPORT "syntax error in IPv6 prefix: " & str SEVERITY ERROR;		END IF;
	
		IPv6Address							:= to_net_ipv6_address(str(str'low TO Pos - 1));
		Len											:= INTEGER'value(str(Pos + 1 TO str'high));
		
		IF (NOT ((0 < Len) AND (Len < 128))) THEN																								REPORT "IPv6 prefix length is out of range: IPv6=" & str & " Length=" & INTEGER'image(Len) SEVERITY ERROR;	END IF;
		IF ((to_slv(IPv6Address) AND to_lowmask(128 - Len, 128)) /= (127 DOWNTO 0 => '0')) THEN REPORT "IPv6 prefix is longer then it's mask: IPv6=" & str SEVERITY ERROR;																	END IF;
	
		Prefix.Prefix						:= IPv6Address;
		Prefix.PrefixLength			:= to_slv(Len, Prefix.PrefixLength'length);
		RETURN Prefix;
	END FUNCTION;
	
	FUNCTION to_slv(ip : T_NET_IPV6_ADDRESS) RETURN STD_LOGIC_VECTOR IS
		VARIABLE slv						: T_SLV_128;
	BEGIN
		FOR I IN 0 TO 15 LOOP
			slv(((I * 8) + 7) DOWNTO (I * 8))		:= ip(I);
		END LOOP;
		RETURN slv;
	END FUNCTION;
	
	FUNCTION to_slvv_8(ip : T_NET_IPV6_ADDRESS) RETURN T_SLVV_8 IS
		VARIABLE slvv						: T_SLVV_8(ip'range);
	BEGIN
		FOR I IN ip'range LOOP
			slvv(I)	:= ip(I);
		END LOOP;
		RETURN slvv;
	END FUNCTION;
	
	FUNCTION to_string(IP : T_NET_IPV6_ADDRESS) RETURN STRING IS
		VARIABLE temp						: STRING(1 TO 40)			:= (OTHERS => ':');
		VARIABLE CharPointer		: NATURAL							:= 1;
		VARIABLE Char						: CHARACTER;
		
		VARIABLE copy						: BOOLEAN							:= FALSE;
	BEGIN
		FOR I IN 7 DOWNTO 0 LOOP
			temp(CharPointer + 0 TO CharPointer + 1)	:= to_string(IP((I * 2) + 1), 'h');
			temp(CharPointer + 2 TO CharPointer + 3)	:= to_string(IP( I * 2), 'h');
			CharPointer																:= CharPointer + 5;
		END LOOP;
	
		-- compress string - remove leading zeros
--		REPORT "compressing IPv6 address" SEVERITY NOTE;
		CharPointer			:= 1;
		FOR I IN temp'range LOOP
--			REPORT "  I=" & INTEGER'image(I) & "  char=" & temp(I) & "  CP=" & INTEGER'image(CharPointer) & "  copy=" & to_string(copy) SEVERITY NOTE;
		
			IF (copy = FALSE) THEN
				IF ((temp(I) = '0') AND (temp(I + 1) /= ':')) THEN
					NULL;
				ELSE
					temp(CharPointer)	:= temp(I);
					CharPointer				:= CharPointer + 1;
					copy							:= TRUE;
				END IF;
			ELSE
				IF (temp(I) = ':') THEN
					copy							:= FALSE;
				END IF;
				temp(CharPointer)		:= temp(I);
				CharPointer					:= CharPointer + 1;
			END IF;
		END LOOP;
	
		RETURN temp(1 TO CharPointer - 2);
	END FUNCTION;
	
	FUNCTION to_string(Prefix : T_NET_IPV6_PREFIX)	RETURN STRING IS
	BEGIN
		RETURN to_string(Prefix.Prefix) & "/" & to_string(Prefix.PrefixLength, 'd');
	END FUNCTION;
END PACKAGE BODY;