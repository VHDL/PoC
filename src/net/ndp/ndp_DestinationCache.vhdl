LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
use			PoC.cache.all;
USE			PoC.net.ALL;


ENTITY ndp_DestinationCache IS
	GENERIC (
		CLOCK_FREQ_MHZ						: REAL																	:= 125.0;					-- 125 MHz
		REPLACEMENT_POLICY				: STRING																:= "LRU";
		TAG_BYTE_ORDER						: T_BYTE_ORDER													:= BIG_ENDIAN;
		DATA_BYTE_ORDER						: T_BYTE_ORDER													:= BIG_ENDIAN;
		INITIAL_CACHE_CONTENT			: T_NET_NDP_DESTINATIONCACHE_VECTOR
	);
	PORT (
		Clock											: IN	STD_LOGIC;																	-- 
		Reset											: IN	STD_LOGIC;																	-- 

		Lookup										: IN	STD_LOGIC;
		IPv6Address_rst						: OUT	STD_LOGIC;
		IPv6Address_nxt						: OUT	STD_LOGIC;
		IPv6Address_Data					: IN	T_SLV_8;
		
		CacheResult								: OUT	T_CACHE_RESULT;
		NextHopIPv6Address_rst		: IN	STD_LOGIC;
		NextHopIPv6Address_nxt		: IN	STD_LOGIC;
		NextHopIPv6Address_Data		: OUT	T_SLV_8;
		PathMTU										: OUT T_SLV_16
	);
END;

ARCHITECTURE rtl OF ndp_DestinationCache IS
	ATTRIBUTE KEEP										: BOOLEAN;

	CONSTANT CACHE_LINES							: POSITIVE			:= 8;
	CONSTANT TAG_BITS									: POSITIVE			:= 128;
	CONSTANT DATA_BITS								:	POSITIVE			:= 128;
	CONSTANT TAGCHUNK_BITS						: POSITIVE			:= 8;
	CONSTANT DATACHUNK_BITS						: POSITIVE			:= 8;
	
	CONSTANT DATACHUNKS								: POSITIVE	:= div_ceil(DATA_BITS, DATACHUNK_BITS);
	CONSTANT DATACHUNK_INDEX_BITS			: POSITIVE	:= log2ceilnz(DATACHUNKS);
	CONSTANT CACHEMEMORY_INDEX_BITS		: POSITIVE	:= log2ceilnz(CACHE_LINES);
	
	FUNCTION to_TagData(CacheContent : T_NET_NDP_DESTINATIONCACHE_VECTOR) RETURN T_SLM IS
		VARIABLE slvv		: T_SLVV_128(CACHE_LINES - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => '0'));
	BEGIN
		FOR I IN CacheContent'range LOOP
			slvv(I)	:= to_slv(CacheContent(I).Tag);
		END LOOP;
		RETURN to_slm(slvv);
	END FUNCTION;
	
	FUNCTION to_CacheData_slvv_128(CacheContent : T_NET_NDP_DESTINATIONCACHE_VECTOR) RETURN T_SLVV_128 IS
		VARIABLE slvv		: T_SLVV_128(CACHE_LINES - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => '0'));
	BEGIN
		FOR I IN CacheContent'range LOOP
			slvv(I)	:= to_slv(CacheContent(I).NextHop);
		END LOOP;
		RETURN slvv;
	END FUNCTION;
	
	FUNCTION to_CacheMemory(CacheContent : T_NET_NDP_DESTINATIONCACHE_VECTOR) RETURN T_SLVV_8 IS
		CONSTANT BYTES_PER_LINE	: POSITIVE																								:= 16;
		CONSTANT slvv						: T_SLVV_128(CACHE_LINES - 1 DOWNTO 0)										:= to_CacheData_slvv_128(CacheContent);
		VARIABLE result					: T_SLVV_8((CACHE_LINES * BYTES_PER_LINE) - 1 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			FOR J IN 0 TO BYTES_PER_LINE - 1 LOOP
				result((I * BYTES_PER_LINE) + J)	:= slvv(I)((J * 8) + 7 DOWNTO J * 8);
			END LOOP;
		END LOOP;
		RETURN result;
	END FUNCTION;
	
	CONSTANT INITIAL_TAGS						: T_SLM			:= to_TagData(INITIAL_CACHE_CONTENT);
	CONSTANT INITIAL_DATALINES			: T_SLVV_8	:= to_CacheMemory(INITIAL_CACHE_CONTENT);
	
	SIGNAL ReadWrite								: STD_LOGIC;
	
	SIGNAL Insert										: STD_LOGIC;
	SIGNAL TU_NewTag_rst						: STD_LOGIC;
	SIGNAL TU_NewTag_nxt						: STD_LOGIC;
	SIGNAL NewTag_Data							: T_SLV_8;
	SIGNAL NewCacheLine_rst					: STD_LOGIC;
	SIGNAL NewCacheLine_nxt					: STD_LOGIC;
	SIGNAL NewCacheLine_Data				: T_SLV_8;
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
	
	SIGNAL DataChunkIndex_us				: UNSIGNED(DATACHUNK_INDEX_BITS - 1 DOWNTO 0)													:= (OTHERS => '0');
	SIGNAL CacheMemory							: T_SLVV_8((CACHE_LINES * T_NET_IPV6_ADDRESS'length) - 1 DOWNTO 0)		:= INITIAL_DATALINES;
	SIGNAL Memory_ReadWrite					: STD_LOGIC;
	SIGNAL MemoryIndex_us						: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 DOWNTO 0);
	SIGNAL ReplaceIndex_us					: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 DOWNTO 0);
	SIGNAL ReplacedIndex_us					: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 DOWNTO 0);
		

BEGIN
--	PROCESS(Command)
--	BEGIN
--		Insert		<= '0';
--		
--		CASE Command IS
--			WHEN ETHERNET_NET_NDP_NeighborCache_CMD_NONE =>		NULL;
--			WHEN ETHERNET_NET_NDP_NeighborCache_CMD_ADD =>		Insert <= '1';
--			
--		END CASE;
--	END PROCESS;

	-- FIXME: add correct assignment
	Insert							<= '0';


	ReadWrite						<= '0';
	NewTag_Data					<= (OTHERS => '0');
	NewCacheLine_Data		<= (OTHERS => '0');
	
	TU_Tag_Data					<= IPv6Address_Data;
	IPv6Address_rst			<= TU_Tag_rst;
	IPv6Address_nxt			<= TU_Tag_nxt;

	CacheResult					<= to_Cache_Result(CacheHit, CacheMiss);

	-- Cache TagUnit
--	TU : ENTITY L_Global.Cache_TagUnit_seq
	TU : ENTITY PoC.cache_TagUnit_seq
		GENERIC MAP (
			REPLACEMENT_POLICY				=> REPLACEMENT_POLICY,
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
			Replace_NewTag_rev				=> OPEN,
			Replace_NewTag_nxt				=> TU_NewTag_nxt,
			Replace_NewTag_Data				=> NewTag_Data,
			Replace_NewIndex					=> TU_NewIndex,
			Replaced									=> TU_Replace,
			
			Request										=> Lookup,
			Request_ReadWrite					=> '0',
			Request_Invalidate				=> '0',--Invalidate,
			Request_Tag_rst						=> TU_Tag_rst,
			Request_Tag_rev						=> OPEN,
			Request_Tag_nxt						=> TU_Tag_nxt,
			Request_Tag_Data					=> TU_Tag_Data,
			Request_Index							=> TU_Index,
			Request_TagHit						=> TU_TagHit,
			Request_TagMiss						=> TU_TagMiss
		);

	-- latch TU_Index on TagHit
	TU_Index_us		<= unsigned(TU_Index) WHEN rising_edge(Clock) AND (TU_TagHit = '1');

	-- ChunkIndex counter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR NextHopIPv6Address_rst) = '1') THEN
				IF (DATA_BYTE_ORDER = LITTLE_ENDIAN) THEN
					DataChunkIndex_us			<= to_unsigned(0,									DataChunkIndex_us'length);
				ELSE
					DataChunkIndex_us			<= to_unsigned((DATACHUNKS - 1),	DataChunkIndex_us'length);
				END IF;
			ELSE
				IF (NextHopIPv6Address_nxt = '1') THEN
					IF (DATA_BYTE_ORDER = LITTLE_ENDIAN) THEN
						DataChunkIndex_us		<= DataChunkIndex_us + 1;
					ELSE
						DataChunkIndex_us		<= DataChunkIndex_us - 1;
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	-- Cache Memory - port 1
	Memory_ReadWrite	<= ReadWrite;
	MemoryIndex_us		<= TU_Index_us & DataChunkIndex_us;
	
	-- Cache Memory - port 2
	ReplaceIndex_us		<= unsigned(TU_NewIndex) & DataChunkIndex_us;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Memory_ReadWrite AND TU_TagHit) = '1') THEN
--					CacheMemory(to_integer(MemoryIndex_us))	<= CacheLineIn;
			END IF;
			
			IF (TU_Replace = '1') THEN
--					CacheMemory(to_integer(ReplaceIndex_us))	<= NewCacheLine_Data;
			END IF;
		END IF;
	END PROCESS;

	CacheHit									<= TU_TagHit;
	CacheMiss									<= TU_TagMiss;
	NextHopIPv6Address_Data		<= CacheMemory(to_integer(MemoryIndex_us));

--	CacheResult						<= to_cache_result(CacheHit, CacheMiss);
--	PathMTU								<= CacheLine(143 DOWNTO 128);

--		Replaced					<= TU_Replace;
END ARCHITECTURE;