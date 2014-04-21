LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;


ENTITY cache_replacement_policy IS
	GENERIC (
		REPLACEMENT_POLICY				: STRING													:= "LRU";
		CACHE_LINES								: POSITIVE												:= 32;
		INITIAL_VALIDS						: STD_LOGIC_VECTOR								:= (0 => '0')
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		-- replacement interface
		Replace										: IN	STD_LOGIC;
		ReplaceIndex							: OUT	STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);
		
		-- cacheline usage update interface
		TagAccess									: IN	STD_LOGIC;
		ReadWrite									: IN	STD_LOGIC;
		Invalidate								: IN	STD_LOGIC;
		Index											: IN	STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0)
	);
END;

-- Policies														|	supported
-- ===================================#====================
--	RR			round robin								|	not yet
--	RAND		random										|	not yet
--	CLOCK		clock algorithm						|	not yet
--	LRU			least recently used				| YES
--	LFU			least frequently used			| not yet
-- ===================================#====================

ARCHITECTURE rtl OF cache_replacement_policy IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	CONSTANT KEY_BITS									: POSITIVE									:= log2ceilnz(CACHE_LINES);

BEGIN
	ASSERT (str_equal(REPLACEMENT_POLICY, "RR") OR
					str_equal(REPLACEMENT_POLICY, "LRU"))
		REPORT "Unsupported replacement strategy"
		SEVERITY ERROR;
	ASSERT (INITIAL_VALIDS'length = CACHE_LINES)
		REPORT "INITIAL_VALIDS'length is unequal to CACHE_LINES: INITIAL_VALIDS=" & INTEGER'image(INITIAL_VALIDS'length) &
																													"  CACHE_LINES="		& INTEGER'image(CACHE_LINES)
		SEVERITY FAILURE;


	-- ==========================================================================================================================================================
	-- policy: RR - round robin
	-- ==========================================================================================================================================================
	genRR : IF (str_equal(REPLACEMENT_POLICY, "RR") = TRUE) GENERATE
		CONSTANT VALID_BIT								: NATURAL			:= 0;

		SUBTYPE	T_OPTION_LINE							IS STD_LOGIC_VECTOR(0 DOWNTO 0);
		TYPE		T_OPTION_LINE_VECTOR			IS ARRAY (NATURAL RANGE <>)		OF T_OPTION_LINE;
		
		SIGNAL OptionMemory								: T_OPTION_LINE_VECTOR(CACHE_LINES - 1 DOWNTO 0)	:= (OTHERS => (
			VALID_BIT			=> '0')
			);

		SIGNAL ValidHit										: STD_LOGIC;
		SIGNAL Pointer_us									: UNSIGNED(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0)	:= (OTHERS => '0');
		
	BEGIN
--		ValidHit		<= OptionMemory(to_integer(unsigned(Index)))(VALID_BIT);
--		IsValid			<= ValidHit;
--
--		PROCESS(Clock)
--		BEGIN
--			IF rising_edge(Clock) THEN
--				IF (Reset = '1') THEN
--					FOR I IN 0 TO CACHE_LINES - 1 LOOP
--						OptionMemory(I)(VALID_BIT)	<= '0';
--					END LOOP;
--				ELSE
--					IF (Insert = '1') THEN
--						OptionMemory(to_integer(Pointer_us))(VALID_BIT)	<= '1';
--					END IF;
--					
--					IF (Invalidate = '1') THEN
--						OptionMemory(to_integer(unsigned(Index)))(VALID_BIT)			<= '0';
--					END IF;
--				END IF;
--			END IF;
--		END PROCESS;
--
--		Replace				<= Insert;
--		ReplaceIndex	<= std_logic_vector(Pointer_us);
--		
--		PROCESS(Clock)
--		BEGIN
--			IF rising_edge(Clock) THEN
--				IF (Reset = '1') THEN
--					Pointer_us		<= (OTHERS => '0');
--				ELSE
--					IF (Insert = '1') THEN
--						Pointer_us	<= Pointer_us + 1;
--					END IF;
--				END IF;
--			END IF;
--		END PROCESS;
	END GENERATE;

	-- ==========================================================================================================================================================
	-- policy: LRU - least recently used
	-- ==========================================================================================================================================================
	genLRU : IF (str_equal(REPLACEMENT_POLICY, "LRU") = TRUE) GENERATE
		FUNCTION create_keys RETURN T_SLM IS
			VARIABLE slm		: T_SLM(CACHE_LINES - 1 DOWNTO 0, KEY_BITS - 1 DOWNTO 0);
			VARIABLE row		: STD_LOGIC_VECTOR(KEY_BITS - 1 DOWNTO 0);
		BEGIN
			FOR I IN slm'range(1) LOOP
				row					:= to_slv((slm'high(1) - I), row'length);
				FOR J IN row'range LOOP
					slm(I, J)	:= row(J);
				END LOOP;
			END LOOP;
			RETURN slm;
		END FUNCTION;

		CONSTANT INITIAL_KEYS				: T_SLM(CACHE_LINES - 1 DOWNTO 0, KEY_BITS - 1 DOWNTO 0)		:= create_keys;
		
		SIGNAL Pointer_us						: UNSIGNED(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0)	:= (OTHERS => '0');

		SIGNAL LRU_Insert						: STD_LOGIC;
		SIGNAL LRU_Invalidate				: STD_LOGIC;
		SIGNAL KeyIn								: STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);
		SIGNAL LRU_Valid						: STD_LOGIC;
		SIGNAL LRU_Key							: STD_LOGIC_VECTOR(log2ceilnz(CACHE_LINES) - 1 DOWNTO 0);
		
	BEGIN
		-- Priority		Command
		-- ======================
		--	0					invalidate
		--	1					replace
		--	2					access
		-- ======================
		-- list_lru_systolic supports only one update per cycle
		PROCESS(TagAccess, ReadWrite, Invalidate, Replace, Index, LRU_Key)
		BEGIN
			LRU_Insert			<= '0';
			LRU_Invalidate	<= '0';
			KeyIn						<= Index;
			
			IF (Invalidate = '1') THEN
				LRU_Invalidate		<= '1';
				KeyIn							<= Index;
			ELSIF (Replace = '1') THEN
				LRU_Insert				<= '1';
				KeyIn							<= LRU_Key;
			ELSIF (TagAccess = '1') THEN
				LRU_Insert				<= '1';
				KeyIn							<= Index;
			END IF;
		END PROCESS;

		ReplaceIndex		<= LRU_Key;
			
--		LRU : ENTITY L_Global.list_lru_systolic
		LRU : ENTITY PoC.list_lru_systolic
			GENERIC MAP (
				ELEMENTS								=> CACHE_LINES,
				KEY_BITS								=> KEY_BITS,
				INITIAL_KEYS						=> INITIAL_KEYS,
				INITIAL_VALIDS					=> INITIAL_VALIDS
			)
			PORT MAP (
				Clock										=> Clock,
				Reset										=> Reset,
				
				Insert									=> LRU_Insert,
				Invalidate							=> LRU_Invalidate,
				KeyIn										=> KeyIn,
				
				Valid										=> LRU_Valid,
				LRU_Key									=> LRU_Key
			);
	END GENERATE;
END ARCHITECTURE;
