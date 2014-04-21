LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;


ENTITY ARP_IPPool IS
	GENERIC (
		IPPOOL_SIZE										: POSITIVE;
		INITIAL_IPV4ADDRESSES					: T_NET_IPV4_ADDRESS_VECTOR			:= (OTHERS => C_NET_IPV4_ADDRESS_EMPTY)
	);
	PORT (
		Clock													: IN	STD_LOGIC;																	-- 
		Reset													: IN	STD_LOGIC;																	-- 

--		Command												: IN	T_ETHERNET_ARP_IPPOOL_COMMAND;
--		IPv4Address										: IN	T_NET_IPV4_ADDRESS;
--		MACAddress										: IN	T_ETHERNET_MAC_ADDRESS;
		
		Lookup												: IN	STD_LOGIC;
		IPv4Address_rst								: OUT	STD_LOGIC;
		IPv4Address_nxt								: OUT	STD_LOGIC;
		IPv4Address_Data							: IN	T_SLV_8;

		PoolResult										: OUT	T_CACHE_RESULT
	);
END;

ARCHITECTURE rtl OF ARP_IPPool IS
	ATTRIBUTE KEEP										: BOOLEAN;

	CONSTANT CACHE_LINES							: POSITIVE			:= imax(IPPOOL_SIZE, INITIAL_IPV4ADDRESSES'length);
	CONSTANT TAG_BITS									: POSITIVE			:= 32;
	CONSTANT TAGCHUNK_BITS						: POSITIVE			:= 8;
	
--	CONSTANT TAGCHUNKS										: POSITIVE	:= div_ceil(TAG_BITS, CHUNK_BITS);
--	CONSTANT CHUNK_INDEX_BITS					: POSITIVE	:= log2ceilnz(CHUNKS);
	CONSTANT CACHEMEMORY_INDEX_BITS		: POSITIVE	:= log2ceilnz(CACHE_LINES);
	
	FUNCTION to_TagData(CacheContent : T_NET_IPV4_ADDRESS_VECTOR) RETURN T_SLM IS
		VARIABLE slvv		: T_SLVV_32(CACHE_LINES - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => '0'));
	BEGIN
		FOR I IN CacheContent'range LOOP
			slvv(I)	:= to_slv(CacheContent(I));
		END LOOP;
		RETURN to_slm(slvv);
	END FUNCTION;
	
	CONSTANT INITIAL_TAGS						: T_SLM			:= to_TagData(INITIAL_IPV4ADDRESSES);
	
	SIGNAL ReadWrite								: STD_LOGIC;
	
	SIGNAL Insert										: STD_LOGIC;
	SIGNAL TU_NewTag_rst						: STD_LOGIC;
	SIGNAL TU_NewTag_nxt						: STD_LOGIC;
	SIGNAL NewTag_Data							: T_SLV_8;
	SIGNAL TU_Tag_rst								: STD_LOGIC;
	SIGNAL TU_Tag_nxt								: STD_LOGIC;
	SIGNAL TU_Tag_Data							: T_SLV_8;
	SIGNAL CacheHit									: STD_LOGIC;
	SIGNAL CacheMiss								: STD_LOGIC;
	
	SIGNAL TU_Index									: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_Index_d								: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_Index_us							: UNSIGNED(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_NewIndex							: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_Replace								: STD_LOGIC;
	
	SIGNAL TU_TagHit								: STD_LOGIC;
	SIGNAL TU_TagMiss								: STD_LOGIC;
	
BEGIN
--	PROCESS(Command)
--	BEGIN
--		Insert		<= '0';
--		
--		CASE Command IS
--			WHEN NET_NDP_NeighborCache_CMD_NONE =>		NULL;
--			WHEN NET_NDP_NeighborCache_CMD_ADD =>		Insert <= '1';
--			
--		END CASE;
--	END PROCESS;

	-- FIXME: add correct assignment
	Insert							<= '0';

	ReadWrite						<= '0';
	NewTag_Data					<= (OTHERS => '0');
	
	TU_Tag_Data					<= IPv4Address_Data;
	IPv4Address_rst			<= TU_Tag_rst;
	IPv4Address_nxt			<= TU_Tag_nxt;

	PoolResult					<= to_cache_result(CacheHit, CacheMiss);

	-- Cache TagUnit
--	TU : ENTITY L_Global.Cache_TagUnit_seq
	TU : ENTITY PoC.Cache_TagUnit_seq
		GENERIC MAP (
			REPLACEMENT_POLICY				=> "LRU",
			CACHE_LINES								=> CACHE_LINES,
			ASSOCIATIVITY							=> CACHE_LINES,
			TAG_BITS									=> TAG_BITS,
			CHUNK_BITS								=> TAGCHUNK_BITS,
			TAG_BYTE_ORDER						=> BIG_ENDIAN,
			INITIAL_TAGS							=> INITIAL_TAGS
		)
		PORT MAP (
			Clock											=> Clock,
			Reset											=> Reset,
			
			Replace										=> Insert,
			Replace_NewTag_rst				=> TU_NewTag_rst,
			Replace_NewTag_nxt				=> TU_NewTag_nxt,
			Replace_NewTag_Data				=> NewTag_Data,
			Replace_NewIndex					=> TU_NewIndex,
			Replaced									=> TU_Replace,
			
			Request										=> Lookup,
			Request_ReadWrite					=> '0',
			Request_Invalidate				=> '0',--Invalidate,
			Request_Tag_rst						=> TU_Tag_rst,
			Request_Tag_nxt						=> TU_Tag_nxt,
			Request_Tag_Data					=> TU_Tag_Data,
			Request_Index							=> OPEN,--TU_Index,
			Request_TagHit						=> TU_TagHit,
			Request_TagMiss						=> TU_TagMiss
		);

	-- latch TU_Index on TagHit
--	TU_Index_us		<= unsigned(TU_Index) WHEN rising_edge(Clock) AND (TU_TagHit = '1');

	CacheHit			<= TU_TagHit;
	CacheMiss			<= TU_TagMiss;
END ARCHITECTURE;