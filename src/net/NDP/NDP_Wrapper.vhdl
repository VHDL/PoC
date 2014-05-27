LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;

ENTITY NDP_Wrapper IS
	GENERIC (
		CLOCK_FREQ_MHZ											: REAL																	:= 125.0;
		INTERFACE_MACADDRESS								: T_NET_MAC_ADDRESS											:= C_NET_MAC_ADDRESS_EMPTY;
		INITIAL_IPV6ADDRESSES								: T_NET_IPV6_ADDRESS_VECTOR							:= (OTHERS => C_NET_IPV6_ADDRESS_EMPTY);
		INITIAL_DESTINATIONCACHE_CONTENT		: T_NET_NDP_DESTINATIONCACHE_VECTOR;
		INITIAL_NEIGHBORCACHE_CONTENT				: T_NET_NDP_NEIGHBORCACHE_VECTOR
	);
	PORT (
		Clock																: IN	STD_LOGIC;
		Reset																: IN	STD_LOGIC;
		
		NextHop_Query												: IN	STD_LOGIC;
		NextHop_IPv6Address_rst							: OUT	STD_LOGIC;
		NextHop_IPv6Address_nxt							: OUT	STD_LOGIC;
		NextHop_IPv6Address_Data						: IN	T_SLV_8;
		
		NextHop_Valid												: OUT	STD_LOGIC;
		NextHop_MACAddress_rst							: IN	STD_LOGIC;
		NextHop_MACAddress_nxt							: IN	STD_LOGIC;
		NextHop_MACAddress_Data							: OUT	T_SLV_8
	);
END;

-- translations
-- ------------------------------------
--								|		german
-- Solicitation		|	Aufforderung
-- Advertisement	|	Ankndigung
-- ------------------------------------


ARCHITECTURE rtl OF NDP_Wrapper IS

	SIGNAL FSMQuery_DCache_Lookup										: STD_LOGIC;
	SIGNAL FSMQuery_DCache_IPv6Address_Data					: T_SLV_8;
	SIGNAL FSMQuery_DCache_NextHopIPv6Address_rst		: STD_LOGIC;
	SIGNAL FSMQuery_DCache_NextHopIPv6Address_nxt		: STD_LOGIC;
	
	SIGNAL FSMQuery_NCache_Lookup										: STD_LOGIC;
	SIGNAL FSMQuery_NCache_IPv6Address_Data					: T_SLV_8;
	SIGNAL FSMQuery_NCache_MACAddress_rst						: STD_LOGIC;
	SIGNAL FSMQuery_NCache_MACAddress_nxt						: STD_LOGIC;

--	SIGNAL FSMCache_NewIPv4Address						: T_NDPIPV4_ADDRESS;
--	SIGNAL FSMCache_NewMACAddress							: T_NDPMAC_ADDRESS;
	SIGNAL FSMCache_Lookup													: STD_LOGIC;
	SIGNAL FSMCache_IPv6Address											: T_NET_IPV6_ADDRESS;

	-- NDP IPPool
	SIGNAL IPPool_PoolResult												: T_CACHE_RESULT;

	-- NDP NeighborCache
	SIGNAL NCache_CacheResult												: T_CACHE_RESULT;
	SIGNAL NCache_IPv6Address_rst										: STD_LOGIC;
	SIGNAL NCache_IPv6Address_nxt										: STD_LOGIC;
	SIGNAL NCache_MACAddress_Data										: T_SLV_8;
	SIGNAL NCache_Reachability											: T_NET_NDP_REACHABILITY_STATE;
	
	-- NDP DestinationCache
	SIGNAL DCache_IPv6Address_rst										: STD_LOGIC;
	SIGNAL DCache_IPv6Address_nxt										: STD_LOGIC;
	SIGNAL DCache_CacheResult												: T_CACHE_RESULT;
	SIGNAL DCache_NextHopIPv6Address_Data						: T_SLV_8;
	SIGNAL DCache_PathMUT														: T_SLV_16;
	
	SIGNAL FSMPrefix_Lookup													: STD_LOGIC;
	SIGNAL FSMPrefix_IPv6Address										: T_NET_IPV6_ADDRESS;
	
	-- NDP PrefixList
	SIGNAL PList_CacheHit														: STD_LOGIC;
	SIGNAL PList_CacheMiss													: STD_LOGIC;
	SIGNAL PList_MACAddress													: T_NET_MAC_ADDRESS;
BEGIN

	FSMQuery : ENTITY L_Ethernet.NDP_FSMQuery
		PORT MAP (
			Clock															=> Clock,
			Reset															=> Reset,
			
			NextHop_Query											=> NextHop_Query,
			NextHop_IPv6Address_rst						=> NextHop_IPv6Address_rst,
			NextHop_IPv6Address_nxt						=> NextHop_IPv6Address_nxt,
			NextHop_IPv6Address_Data					=> NextHop_IPv6Address_Data,
			
			NextHop_Valid											=> NextHop_Valid,
			NextHop_MACAddress_rst						=> NextHop_MACAddress_rst,
			NextHop_MACAddress_nxt						=> NextHop_MACAddress_nxt,
			NextHop_MACAddress_Data						=> NextHop_MACAddress_Data,
					
			DCache_Lookup											=> FSMQuery_DCache_Lookup,
			DCache_IPv6Address_rst						=> DCache_IPv6Address_rst,
			DCache_IPv6Address_nxt						=> DCache_IPv6Address_nxt,
			DCache_IPv6Address_Data						=> FSMQuery_DCache_IPv6Address_Data,
			
			DCache_CacheResult								=> DCache_CacheResult,
			DCache_NextHopIPv6Address_rst			=> FSMQuery_DCache_NextHopIPv6Address_rst,
			DCache_NextHopIPv6Address_nxt			=> FSMQuery_DCache_NextHopIPv6Address_nxt,
			DCache_NextHopIPv6Address_Data		=> DCache_NextHopIPv6Address_Data,
			DCache_PathMUT										=> DCache_PathMUT,
			
			NCache_Lookup											=> FSMQuery_NCache_Lookup,
			NCache_IPv6Address_rst						=> NCache_IPv6Address_rst,
			NCache_IPv6Address_nxt						=> NCache_IPv6Address_nxt,
			NCache_IPv6Address_Data						=> FSMQuery_NCache_IPv6Address_Data,
			
			NCache_CacheResult								=> NCache_CacheResult,
			NCache_MACAddress_rst							=> FSMQuery_NCache_MACAddress_rst,
			NCache_MACAddress_nxt							=> FSMQuery_NCache_MACAddress_nxt,
			NCache_MACAddress_Data						=> NCache_MACAddress_Data,
			NCache_Reachability								=> NCache_Reachability
		);

	IPPool : ENTITY L_Ethernet.NDP_IPPool
		GENERIC MAP (
			IPPOOL_SIZE												=> 8,
			INITIAL_IPV6ADDRESSES							=> INITIAL_IPV6ADDRESSES
		)
		PORT MAP (
			Clock															=> Clock,
			Reset															=> Reset,

--			Command														=> IPPool_Command,
--			IPv4Address												=> (OTHERS => '0'),
--			MACAddress												=> (OTHERS => '0'),
			
			Lookup														=> '0',--FSMPool_IPPool_Lookup,
			IPv6Address_rst										=> OPEN,--IPPool_IPv6Address_rst,
			IPv6Address_nxt										=> OPEN,--IPPool_IPv6Address_nxt,
			IPv6Address_Data									=> x"00",--FSMPool_IPPool_IPv6Address_Data,
			
			PoolResult												=> IPPool_PoolResult
		);


	-- ==========================================================================================================================================================
	-- DestinationCache
	-- ==========================================================================================================================================================
	DCache : ENTITY L_Ethernet.NDP_DestinationCache
		GENERIC MAP (
			CLOCK_FREQ_MHZ						=> CLOCK_FREQ_MHZ,
			REPLACEMENT_POLICY				=> "LRU",
			TAG_BYTE_ORDER						=> BIG_ENDIAN,
			DATA_BYTE_ORDER						=> LITTLE_ENDIAN,
			INITIAL_CACHE_CONTENT			=> INITIAL_DESTINATIONCACHE_CONTENT
		)
		PORT MAP (
			Clock											=> Clock,
			Reset											=> Reset,
			
			Lookup										=> FSMQuery_DCache_Lookup,
			IPv6Address_rst						=> DCache_IPv6Address_rst,
			IPv6Address_nxt						=> DCache_IPv6Address_nxt,
			IPv6Address_Data					=> FSMQuery_DCache_IPv6Address_Data,
			
			CacheResult								=> DCache_CacheResult,
			NextHopIPv6Address_rst		=> FSMQuery_DCache_NextHopIPv6Address_rst,
			NextHopIPv6Address_nxt		=> FSMQuery_DCache_NextHopIPv6Address_nxt,
			NextHopIPv6Address_Data		=> DCache_NextHopIPv6Address_Data,
			PathMTU										=> DCache_PathMUT
		);
		
	-- ==========================================================================================================================================================
	-- NeighborCache
	-- ==========================================================================================================================================================
	NCache : ENTITY L_Ethernet.NDP_NeighborCache
		GENERIC MAP (
			REPLACEMENT_POLICY				=> "LRU",
			TAG_BYTE_ORDER						=> LITTLE_ENDIAN,
			DATA_BYTE_ORDER						=> BIG_ENDIAN,
			INITIAL_CACHE_CONTENT			=> INITIAL_NEIGHBORCACHE_CONTENT
		)
		PORT MAP (
			Clock											=> Clock,
			Reset											=> Reset,
			
			Lookup										=> FSMQuery_NCache_Lookup,
			IPv6Address_rst						=> NCache_IPv6Address_rst,
			IPv6Address_nxt						=> NCache_IPv6Address_nxt,
			IPv6Address_Data					=> FSMQuery_NCache_IPv6Address_Data,
			
			CacheResult								=> NCache_CacheResult,
			MACAddress_rst						=> FSMQuery_NCache_MACAddress_rst,
			MACAddress_nxt						=> FSMQuery_NCache_MACAddress_nxt,
			MACAddress_Data						=> NCache_MACAddress_Data,
			Reachability							=> NCache_Reachability
		);
	

	-- ============================================================================================================================================================
	-- PrefixList
	-- ============================================================================================================================================================
	FSMPrefix_Lookup				<= '0';--NextHop_Query;
	FSMPrefix_IPv6Address		<= (OTHERS => (OTHERS => '0'));--NextHop_IPv6Address;

	PList : ENTITY L_Ethernet.NDP_PrefixList
		PORT MAP (
			Clock											=> Clock,
			Reset											=> Reset,

			Insert										=> '0',
			NewIPv6Prefix							=> C_NET_IPV6_ADDRESS_EMPTY,
			NewIPv6Mask								=> C_NET_IPV6_ADDRESS_EMPTY,
			
			Lookup										=> FSMPrefix_Lookup,
			IPv6Address								=> FSMPrefix_IPv6Address,
			
			CacheHit									=> PList_CacheHit,
			CacheMiss									=> PList_CacheMiss,
			MACAddress								=> PList_MACAddress
		);
END ARCHITECTURE;
