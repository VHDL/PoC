LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_SATAController;


ENTITY TX_CRC32 IS
	PORT (
		Clock				: IN	STD_LOGIC;
		Reset				: IN	STD_LOGIC;

		Valid				: IN	STD_LOGIC;		
		DataIn			: IN	T_SLV_32;
		DataOut			: OUT	T_SLV_32
	);
END;

ARCHITECTURE rtl OF TX_CRC32 IS
	CONSTANT CRC32_POLYNOMIAL		: BIT_VECTOR(35 DOWNTO 0) := x"104C11DB7";
	CONSTANT CRC32_INIT					: T_SLV_32								:= x"52325032";

BEGIN
	CRC : ENTITY PoC.comm_crc
		GENERIC MAP (
			GEN							=> CRC32_POLYNOMIAL(32 DOWNTO 0),		-- Generator Polynom
			BITS						=> 32																-- Number of Bits to be processed in parallel
		)
		PORT MAP (
			clk							=> Clock,														-- Clock
			
			set							=> Reset,														-- Parallel Preload of Remainder
			init						=> CRC32_INIT,											
			step						=> Valid,														-- Process Input Data (MSB first)
			din							=> DataIn,

			rmd							=> DataOut,													-- Remainder
			zero						=> OPEN															-- Remainder is Zero
		);
END;
