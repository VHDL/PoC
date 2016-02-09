
-- word alignment for dependent clocks

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;


ENTITY WordAligner IS
  GENERIC (
	  REGISTERED		: BOOLEAN			:= FALSE;																					-- add output register @Clock
		INPUT_BITS		: POSITIVE		:= 32;																						-- input/output bitwidth
		WORD_BITS			: POSITIVE		:= 8																							-- word bitwidth
	);
  PORT (
		Clock					: IN	STD_LOGIC;																								-- clock
		Align					: IN	STD_LOGIC_VECTOR((INPUT_BITS / WORD_BITS) - 1 DOWNTO 0);	-- align word (one-hot code)
		I							: IN	STD_LOGIC_VECTOR(INPUT_BITS - 1 DOWNTO 0);								-- input word
		O							: OUT STD_LOGIC_VECTOR(INPUT_BITS - 1 DOWNTO 0);								-- output word
		Valid					: OUT	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF WordAligner IS
	CONSTANT SEGMENT_COUNT	: POSITIVE																	:= INPUT_BITS / WORD_BITS;
	
	TYPE T_SEGMENTS IS ARRAY(NATURAL RANGE <>) OF STD_LOGIC_VECTOR(WORD_BITS - 1 DOWNTO 0);
	
	SIGNAL I_d						: STD_LOGIC_VECTOR(I'high DOWNTO WORD_BITS)		:= (OTHERS => '0');
	
	SIGNAL O_i						: STD_LOGIC_VECTOR(I'range);
	SIGNAL Align_d				: STD_LOGIC_VECTOR(Align'range)								:= (0 => '1', others => '0');
	SIGNAL Align_i				: STD_LOGIC_VECTOR(Align'range);
	SIGNAL Hold						: STD_LOGIC;
	SIGNAL Changed				: STD_LOGIC;
	SIGNAL Valid_i				: STD_LOGIC;
	
	SIGNAL MuxCtrl				: STD_LOGIC_VECTOR(Align'range);
	SIGNAL bin						: INTEGER;
	
	
	FUNCTION onehot2bin(slv : STD_LOGIC_VECTOR) RETURN NATURAL IS
	BEGIN
		FOR I IN 0 TO slv'length - 1 LOOP
			IF (slv(I) = '1') THEN
				RETURN I + 1;
			END IF;
		END LOOP;
		
		RETURN 1;
	END;
	
	FUNCTION onehot2muxctrl(slv : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result		: STD_LOGIC_VECTOR(slv'range);
		VARIABLE Flag			: STD_LOGIC													:= '0';
	BEGIN
		FOR I IN 0 TO slv'length - 2 LOOP
			Flag						:= Flag OR slv(I);
			Result(I)				:= Flag;
		END LOOP;
		
		Result(slv'high)	:= '1';
		
		RETURN Result;
	END;
BEGIN

		I_d				<= I(I_d'range)	WHEN rising_edge(Clock);
		Align_d		<= Align				WHEN rising_edge(Clock) AND (Hold = '0') AND (Changed = '1');

		Hold			<= slv_nor(Align);
		Changed		<= to_sl(Align /= Align_d);
		Valid_i		<= Hold OR Align(Align'low);
		Align_i		<= Align WHEN (Hold = '0') ELSE Align_d;
	
		O_i		<= I WHEN (Align_i = "01") ELSE I(WORD_BITS - 1 DOWNTO 0) & I_d;
	
	-- add output register @Clock2
	gen11 : IF (REGISTERED = TRUE) GENERATE
		O				<= O_i			WHEN rising_edge(Clock);
		Valid		<= Valid_i	WHEN rising_edge(Clock);
	END GENERATE;
	gen12 : IF (REGISTERED = FALSE) GENERATE
		O				<= O_i;
		Valid		<= Valid_i;
	END GENERATE;	
END;

--	 0 1	0 0
--	4ABC 7B4A 4ABC 7B4A
--			 7B4A 4ABC
--						7B4A 4ABC


