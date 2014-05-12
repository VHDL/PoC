-- EMACS settings:	-*-  tab-width:2  -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;

-- list_lru_systolic
--		lru = least recently used
--		systolic = array of self-ordering units

ENTITY list_lru_systolic IS
	GENERIC (
		ELEMENTS									: POSITIVE												:= 32;
		KEY_BITS									: POSITIVE												:= 5;
		INITIAL_KEYS							:	T_SLM														:= (0 TO 31 => (0 TO 4 => '0'));
		INITIAL_VALIDS						: STD_LOGIC_VECTOR								:= (0 TO 31 => '0')
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		Insert										: IN	STD_LOGIC;
		Invalidate								: IN	STD_LOGIC;
		KeyIn											: IN	STD_LOGIC_VECTOR(KEY_BITS - 1 DOWNTO 0);
		
		Valid											: OUT	STD_LOGIC;
		LRU_Key										: OUT	STD_LOGIC_VECTOR(KEY_BITS - 1 DOWNTO 0);
		
		DBG_Keys									: OUT	T_SLM(ELEMENTS - 1 DOWNTO 0, KEY_BITS - 1 DOWNTO 0);
		DBG_Valids								: OUT STD_LOGIC_VECTOR(ELEMENTS - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF list_lru_systolic IS
	ATTRIBUTE KEEP										: BOOLEAN;

	SUBTYPE T_KEY					IS STD_LOGIC_VECTOR(KEY_BITS - 1 DOWNTO 0);
	TYPE T_KEY_VECTOR			IS ARRAY (NATURAL RANGE <>) OF T_KEY;
	
	SIGNAL NewKeysUp			: T_KEY_VECTOR(ELEMENTS DOWNTO 0);
	
	SIGNAL KeysUp					: T_KEY_VECTOR(ELEMENTS DOWNTO 0);
	SIGNAL KeysDown				: T_KEY_VECTOR(ELEMENTS DOWNTO 0);
	SIGNAL ValidsUp				: STD_LOGIC_VECTOR(ELEMENTS DOWNTO 0);
	SIGNAL ValidsDown			: STD_LOGIC_VECTOR(ELEMENTS DOWNTO 0);
	
	SIGNAL MovesDown			: STD_LOGIC_VECTOR(ELEMENTS DOWNTO 0);
	SIGNAL MovesUp				: STD_LOGIC_VECTOR(ELEMENTS DOWNTO 0);
	
	SIGNAL DBG_Keys_i			: T_SLM(ELEMENTS - 1 DOWNTO 0, KEY_BITS - 1 DOWNTO 0)			:= (OTHERS => (OTHERS => 'Z'));
	
BEGIN
	-- next element (top)
	KeysDown(ELEMENTS)		<= NewKeysUp(ELEMENTS);
	ValidsDown(ELEMENTS)	<= '1';
	
	MovesDown(ELEMENTS)		<= Insert;
	
	-- current element
	genElements : FOR I IN ELEMENTS - 1 DOWNTO 0 GENERATE
		CONSTANT INITIAL_KEY			: STD_LOGIC_VECTOR(KEY_BITS - 1 DOWNTO 0)					:= get_row(INITIAL_KEYS, I);
		CONSTANT INITIAL_VALID		: STD_LOGIC																				:= INITIAL_VALIDS(I);

		SIGNAL Key_nxt						: STD_LOGIC_VECTOR(KEY_BITS - 1 DOWNTO 0);
		SIGNAL Key_d							: STD_LOGIC_VECTOR(KEY_BITS - 1 DOWNTO 0)					:= INITIAL_KEY;
		SIGNAL Valid_nxt					: STD_LOGIC;
		SIGNAL Valid_d						: STD_LOGIC																				:= INITIAL_VALID;
		
		SIGNAL Unequal							: STD_LOGIC;
		SIGNAL MoveDown						: STD_LOGIC;
		SIGNAL MoveUp							: STD_LOGIC;

		COMPONENT MUXCY
			PORT (
				O			: OUT	STD_ULOGIC;
				CI		: IN	STD_ULOGIC;
				DI		: IN	STD_ULOGIC;
				S			: IN	STD_ULOGIC
			);
		END COMPONENT;
		
	BEGIN
		-- local movements
		Unequal				<= to_sl(Key_d /= NewKeysUp(I));
		
		genXilinx : IF (VENDOR = VENDOR_XILINX) GENERATE
			a : MUXCY
				PORT MAP (
					S		=> Unequal,
					CI	=> MovesDown(I + 1),
					DI	=> '0',
					O		=> MovesDown(I)
				);

			b : MUXCY
				PORT MAP (
					S		=> Unequal,
					CI	=> MovesUp(I),
					DI	=> '0',
					O		=> MovesUp(I + 1)
				);
		END GENERATE;
		
		-- movements for the current element	
		MoveDown		<= MovesDown(I + 1);
		MoveUp			<= MovesUp(I);
		
		-- passthrought all new
		NewKeysUp(I + 1)	<= NewKeysUp(I);
		
		KeysUp(I + 1)			<= Key_d;
		ValidsUp(I + 1)		<= Valid_d;
		
		-- multiplexer
		Key_nxt						<= ite((MoveDown = '1'), KeysDown(I + 1),		ite((MoveUp = '1'), KeysUp(I),		Key_d));
		Valid_nxt					<= ite((MoveDown = '1'), ValidsDown(I + 1),	ite((MoveUp = '1'), ValidsUp(I), Valid_d));
			
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Reset = '1') THEN
					Key_d				<= INITIAL_KEY;
					Valid_d			<= INITIAL_VALID;
				ELSE
					Key_d				<= Key_nxt;
					Valid_d			<= Valid_nxt;
				END IF;
			END IF;
		END PROCESS;

		KeysDown(I)				<= Key_d;
		ValidsDown(I)			<= Valid_d;
		
		assign_row(DBG_Keys_i, Key_d, I);
		
		DBG_Keys					<= DBG_Keys_i;
		DBG_Valids(I)			<= Valid_d;
	END GENERATE;

	-- previous element (buttom)
	NewKeysUp(0)				<= KeyIn;
	MovesUp(0)					<= Invalidate;
	KeysUp(0)						<= KeyIn;
	ValidsUp(0)					<= '0';
	
	LRU_Key							<= KeysDown(0);
	Valid								<= ValidsDown(0);
END ARCHITECTURE;
