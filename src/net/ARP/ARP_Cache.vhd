LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;

--LIBRARY L_IO;
--USE			L_IO.IOTypes.ALL;


ENTITY ARP_Cache IS
	GENERIC (
		CLOCK_FREQ_MHZ						: REAL																	:= 125.0;					-- 125 MHz
		REPLACEMENT_POLICY				: STRING																:= "LRU";
		TAG_BYTE_ORDER						: T_BYTE_ORDER													:= BIG_ENDIAN;
		DATA_BYTE_ORDER						: T_BYTE_ORDER													:= BIG_ENDIAN;
		INITIAL_CACHE_CONTENT			: T_NET_ARP_ARPCACHE_VECTOR
	);
	PORT (
		Clock											: IN	STD_LOGIC;																	-- 
		Reset											: IN	STD_LOGIC;																	-- 

		Command										: IN	T_NET_ARP_ARPCACHE_COMMAND;
		Status										: OUT	T_NET_ARP_ARPCACHE_STATUS;
		NewIPv4Address_rst				: OUT	STD_LOGIC;
		NewIPv4Address_nxt				: OUT	STD_LOGIC;
		NewIPv4Address_Data				: IN	T_SLV_8;
		NewMACAddress_rst					: OUT	STD_LOGIC;
		NewMACAddress_nxt					: OUT	STD_LOGIC;
		NewMACAddress_Data				: IN	T_SLV_8;
		
		Lookup										: IN	STD_LOGIC;
		IPv4Address_rst						: OUT	STD_LOGIC;
		IPv4Address_nxt						: OUT	STD_LOGIC;
		IPv4Address_Data					: IN	T_SLV_8;
		
		CacheResult								: OUT	T_CACHE_RESULT;
		MACAddress_rst						: IN	STD_LOGIC;
		MACAddress_nxt						: IN	STD_LOGIC;
		MACAddress_Data						: OUT	T_SLV_8
	);
END;


ARCHITECTURE rtl OF ARP_Cache IS
	ATTRIBUTE KEEP										: BOOLEAN;

	CONSTANT CACHE_LINES							: POSITIVE	:= 8;
	CONSTANT TAG_BITS									: POSITIVE	:= 32;		-- IPv4 address
	CONSTANT DATA_BITS								:	POSITIVE	:= 48;		-- MAC address
	CONSTANT TAGCHUNK_BITS						: POSITIVE	:= 8;
	CONSTANT DATACHUNK_BITS						: POSITIVE	:= 8;
	
	CONSTANT DATACHUNKS								: POSITIVE	:= div_ceil(DATA_BITS, DATACHUNK_BITS);
	CONSTANT DATACHUNK_INDEX_BITS			: POSITIVE	:= log2ceilnz(DATACHUNKS);
	CONSTANT CACHEMEMORY_INDEX_BITS		: POSITIVE	:= log2ceilnz(CACHE_LINES);
	
	FUNCTION to_TagData(CacheContent : T_NET_ARP_ARPCACHE_VECTOR) RETURN T_SLM IS
--		VARIABLE slvv		: T_SLVV_32(CACHE_LINES - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => '0'));
		VARIABLE slvv		: T_SLVV_32(CacheContent'high DOWNTO CacheContent'low)	:= (OTHERS => (OTHERS => '0'));
	BEGIN
		FOR I IN CacheContent'range LOOP
			slvv(I)	:= to_slv(CacheContent(I).Tag);
		END LOOP;
		RETURN to_slm(slvv);
	END FUNCTION;
	
	FUNCTION to_CacheData_slvv_48(CacheContent : T_NET_ARP_ARPCACHE_VECTOR) RETURN T_SLVV_48 IS
		VARIABLE slvv		: T_SLVV_48(CACHE_LINES - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => '0'));
	BEGIN
		FOR I IN CacheContent'range LOOP
			slvv(I)	:= to_slv(CacheContent(I).MAC);
		END LOOP;
		RETURN slvv;
	END FUNCTION;
	
	FUNCTION to_CacheMemory(CacheContent : T_NET_ARP_ARPCACHE_VECTOR) RETURN T_SLVV_8 IS
		CONSTANT BYTES_PER_LINE	: POSITIVE																				:= 6;
		CONSTANT slvv						: T_SLVV_48(CACHE_LINES - 1 DOWNTO 0)							:= to_CacheData_slvv_48(CacheContent);
		VARIABLE result					: T_SLVV_8((CACHE_LINES * BYTES_PER_LINE) - 1 DOWNTO 0);
	BEGIN
		FOR I IN slvv'range LOOP
			FOR J IN 0 TO BYTES_PER_LINE - 1 LOOP
				result((I * BYTES_PER_LINE) + J)	:= slvv(I)((J * 8) + 7 DOWNTO J * 8);
			END LOOP;
		END LOOP;
		RETURN result;
	END FUNCTION;
	
	CONSTANT INITIAL_TAGS					: T_SLM			:= to_TagData(INITIAL_CACHE_CONTENT);
	CONSTANT INITIAL_DATALINES		: T_SLVV_8	:= to_CacheMemory(INITIAL_CACHE_CONTENT);
	
	
	SIGNAL ReadWrite							: STD_LOGIC;
	
	TYPE T_FSMREPLACE_STATE IS (ST_IDLE, ST_REPLACE);
	
	SIGNAL FSMReplace_State				: T_FSMREPLACE_STATE						:= ST_IDLE;
	SIGNAL FSMReplace_NextState		: T_FSMREPLACE_STATE;
	
	SIGNAL Insert									: STD_LOGIC;
		
	SIGNAL TU_NewTag_rst					: STD_LOGIC;
	SIGNAL TU_NewTag_nxt					: STD_LOGIC;
	SIGNAL NewTag_Data						: T_SLV_8;
	
	SIGNAL NewCacheLine_Data			: T_SLV_8;
		
	SIGNAL TU_Tag_rst							: STD_LOGIC;
	SIGNAL TU_Tag_nxt							: STD_LOGIC;
	SIGNAL TU_Tag_Data						: T_SLV_8;
	SIGNAL CacheHit								: STD_LOGIC;
	SIGNAL CacheMiss							: STD_LOGIC;
	
	SIGNAL TU_Index								: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_Index_d							: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
--	SIGNAL TU_Index_us						: UNSIGNED(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	
	SIGNAL TU_NewIndex						: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);
	SIGNAL TU_Replaced						: STD_LOGIC;
	
	SIGNAL TU_TagHit							: STD_LOGIC;
	SIGNAL TU_TagMiss							: STD_LOGIC;

	CONSTANT TICKCOUNTER_RES_MS		: REAL																																			:= 10.0;
	CONSTANT TICKCOUNTER_MAX			: POSITIVE																																	:= TimingToCycles_ms(TICKCOUNTER_RES_MS, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ));
	CONSTANT TICKCOUNTER_BITS			: POSITIVE																																	:= log2ceilnz(TICKCOUNTER_MAX);
	
	SIGNAL TickCounter_s					: SIGNED(TICKCOUNTER_BITS DOWNTO 0)																					:= to_signed(TICKCOUNTER_MAX, TICKCOUNTER_BITS + 1);
	SIGNAL Tick										: STD_LOGIC;

	SIGNAL Exp_Expired						: STD_LOGIC;
	SIGNAL Exp_KeyOut							: STD_LOGIC_VECTOR(CACHEMEMORY_INDEX_BITS - 1 DOWNTO 0);

	SIGNAL DataChunkIndex_us					: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL DataChunkIndex_l_us				: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL NewDataChunkIndex_en				: STD_LOGIC;
	SIGNAL NewDataChunkIndex_us				: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL NewDataChunkIndex_max_us		: UNSIGNED((CACHEMEMORY_INDEX_BITS + DATACHUNK_INDEX_BITS) - 1 DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL CacheMemory_we							: STD_LOGIC;
	SIGNAL CacheMemory								: T_SLVV_8((CACHE_LINES * T_NET_MAC_ADDRESS'length) - 1 DOWNTO 0)						:= INITIAL_DATALINES;
	SIGNAL Memory_ReadWrite						: STD_LOGIC;
	
BEGIN
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				FSMReplace_State			<= ST_IDLE;
			ELSE
				FSMReplace_State			<= FSMReplace_NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(FSMReplace_State, Command, TU_Replaced, TU_NewTag_rst, TU_NewTag_nxt, NewDataChunkIndex_us, NewDataChunkIndex_max_us)
	BEGIN
		FSMReplace_NextState							<= FSMReplace_State;
		
		Status														<= NET_ARP_ARPCACHE_STATUS_IDLE;
		
		NewMACAddress_rst									<= '0';
		NewMACAddress_nxt									<= '0';
		NewIPv4Address_rst								<= TU_NewTag_rst;
		NewIPv4Address_nxt								<= TU_NewTag_nxt;
		
		CacheMemory_we										<= '0';
		NewDataChunkIndex_en							<= '0';
		
		Insert														<= '0';
	
		CASE FSMReplace_State IS
			WHEN ST_IDLE =>
				NewMACAddress_rst							<= '1';
			
				CASE Command IS
					WHEN NET_ARP_ARPCACHE_CMD_NONE =>
						NULL;
						
					WHEN NET_ARP_ARPCACHE_CMD_ADD =>
						Status										<= NET_ARP_ARPCACHE_STATUS_UPDATING;
					
						Insert										<= '1';
						CacheMemory_we						<= '1';
						NewMACAddress_rst					<= '0';
						NewMACAddress_nxt					<= '1';
						NewDataChunkIndex_en			<= '1';
						
						FSMReplace_NextState			<= ST_REPLACE;
						
					WHEN OTHERS =>
						NULL;
				END CASE;
			
			WHEN ST_REPLACE =>
				Status												<= NET_ARP_ARPCACHE_STATUS_UPDATING;
			
				CacheMemory_we								<= '1';
				NewMACAddress_nxt							<= '1';
				NewDataChunkIndex_en					<= '1';
				
				IF (NewDataChunkIndex_us = NewDataChunkIndex_max_us) THEN
					Status											<= NET_ARP_ARPCACHE_STATUS_UPDATE_COMPLETE;
					FSMReplace_NextState				<= ST_IDLE;
				END IF;
				
		END CASE;
	END PROCESS;

	ReadWrite						<= '0';
	NewTag_Data					<= NewIPv4Address_Data;
	NewCacheLine_Data		<= NewMACAddress_Data;
	
	IPv4Address_rst			<= TU_Tag_rst;
	IPv4Address_nxt			<= TU_Tag_nxt;
	TU_Tag_Data					<= IPv4Address_Data;

	CacheResult					<= to_cache_result(CacheHit, CacheMiss);

	-- Cache TagUnit
--	TU : ENTITY L_Global.Cache_TagUnit_seq
	TU : ENTITY PoC.Cache_TagUnit_seq
		GENERIC MAP (
			REPLACEMENT_POLICY				=> REPLACEMENT_POLICY,
			CACHE_LINES								=> CACHE_LINES,
			ASSOCIATIVITY							=> CACHE_LINES,
			TAG_BITS									=> TAG_BITS,
			CHUNK_BITS								=> TAGCHUNK_BITS,
			TAG_BYTE_ORDER						=> TAG_BYTE_ORDER,
			INITIAL_TAGS							=> INITIAL_TAGS
		)
		PORT MAP (
			Clock											=> Clock,
			Reset											=> Reset,
			
			Replace										=> Insert,
			Replaced									=> TU_Replaced,
			Replace_NewTag_rst				=> TU_NewTag_rst,
			Replace_NewTag_rev				=> OPEN,
			Replace_NewTag_nxt				=> TU_NewTag_nxt,
			Replace_NewTag_Data				=> NewTag_Data,
			Replace_NewIndex					=> TU_NewIndex,
			
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

	-- expiration time tick generator
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Tick = '1') THEN
				TickCounter_s		<= to_signed(TICKCOUNTER_MAX, TickCounter_s'length);
			ELSE
				TickCounter_s	<= TickCounter_s - 1;
			END IF;
		END IF;
	END PROCESS;
	
	Tick			<= TickCounter_s(TickCounter_s'high);

--	Exp : ENTITY L_Global.list_expire
	Exp : ENTITY PoC.list_expire
		GENERIC MAP (
			CLOCK_CYCLE_TICKS				=> 65536,
			EXPIRATION_TIME_TICKS		=> 8192,
			ELEMENTS								=> CACHE_LINES,
			KEY_BITS								=> CACHEMEMORY_INDEX_BITS
		)
		PORT MAP (
			Clock										=> Clock,
			Reset										=> Reset,
			
			Tick										=> Tick,
			
			Insert									=> Insert,
			KeyIn										=> TU_NewIndex,
			
			Expired									=> Exp_Expired,
			KeyOut									=> Exp_KeyOut
		);
	
	
	
	-- latch TU_Index on TagHit
--	TU_Index_us		<= unsigned(TU_Index) WHEN rising_edge(Clock) AND (TU_TagHit = '1');

	-- NewDataChunkIndex counter
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (NewDataChunkIndex_en = '0') THEN
				IF (DATA_BYTE_ORDER = LITTLE_ENDIAN) THEN
					NewDataChunkIndex_us			<= resize(unsigned(TU_NewIndex) * 6, NewDataChunkIndex_us'length);
					NewDataChunkIndex_max_us	<= resize(unsigned(TU_NewIndex) * 6, NewDataChunkIndex_us'length) + to_unsigned((DATACHUNKS - 1), NewDataChunkIndex_us'length);
				ELSE
					NewDataChunkIndex_us			<= resize(unsigned(TU_NewIndex) * 6, NewDataChunkIndex_us'length) + to_unsigned((DATACHUNKS - 1), NewDataChunkIndex_us'length);
					NewDataChunkIndex_max_us	<= resize(unsigned(TU_NewIndex) * 6, NewDataChunkIndex_us'length);
				END IF;
			ELSE
				IF (DATA_BYTE_ORDER = LITTLE_ENDIAN) THEN
					NewDataChunkIndex_us	<= NewDataChunkIndex_us + 1;
				ELSE
					NewDataChunkIndex_us	<= NewDataChunkIndex_us - 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	-- DataChunkIndex counter
	PROCESS(Clock, TU_Index)
		VARIABLE temp		: UNSIGNED(DataChunkIndex_us'range);
	BEGIN
		IF (DATA_BYTE_ORDER = LITTLE_ENDIAN) THEN
			temp	:= resize(unsigned(TU_Index) * 6, DataChunkIndex_us'length);
		ELSE
			temp	:= resize(unsigned(TU_Index) * 6, DataChunkIndex_us'length) + to_unsigned((DATACHUNKS - 1), DataChunkIndex_us'length);
		END IF;
	
		IF rising_edge(Clock) THEN
			IF (TU_TagHit = '1') THEN
				DataChunkIndex_us				<= temp;
				DataChunkIndex_l_us			<= temp;
			ELSIF (MACAddress_rst = '1') THEN
				DataChunkIndex_us				<= DataChunkIndex_l_us;
			ELSE
				IF (MACAddress_nxt = '1') THEN
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

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (CacheMemory_we = '1') THEN
				CacheMemory(to_integer(NewDataChunkIndex_us))	<= NewCacheLine_Data;
			END IF;
		END IF;
	END PROCESS;

	CacheHit					<= TU_TagHit;
	CacheMiss					<= TU_TagMiss;
	MACAddress_Data		<= CacheMemory(to_integer(DataChunkIndex_us, CacheMemory'high));
END ARCHITECTURE;