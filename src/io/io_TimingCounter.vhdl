--
-- Package: 
-- Authors: Patrick Lehmann
-- 
-- timing counter for multiple timings
--
--
-- naming conversions:
-- =========================
-- *_s			signed signals
-- *_d      delayed/registered signals
-- *_BW			bitwidth
--
--

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;


ENTITY TimingCounter IS
  GENERIC (
	  TIMING_TABLE				: T_NATVEC																		-- timing table
	);
  PORT (
	  Clock								: IN	STD_LOGIC;															-- clock
		Enable							: IN	STD_LOGIC;															-- enable counter
		Load								: IN	STD_LOGIC;															-- load Timing Value from TIMING_TABLE selected by slot
		Slot								: IN	NATURAL;																-- 
		Timeout							: OUT STD_LOGIC																-- timing reached
	);
END;


ARCHITECTURE rtl OF TimingCounter IS
	FUNCTION transform(vec : T_NATVEC) RETURN T_INTVEC IS
    VARIABLE Result : T_INTVEC(vec'range);
  BEGIN
    FOR I IN vec'range LOOP
			Result(I)	 := vec(I) - 1;
		END LOOP;
		RETURN Result;
  END;

	CONSTANT TIMING_TABLE2	: T_INTVEC		:= transform(TIMING_TABLE);
	CONSTANT TIMING_MAX			: NATURAL			:= imax(TIMING_TABLE2);
	CONSTANT COUNTER_BW			: NATURAL			:= log2ceilnz(TIMING_MAX);

	SIGNAL Counter_s				: SIGNED(COUNTER_BW DOWNTO 0)		:= to_signed(TIMING_TABLE2(0), COUNTER_BW + 1);
	
BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Load = '1') THEN
				Counter_s		<= to_signed(TIMING_TABLE2(Slot), Counter_s'length);
			ELSE
				IF ((Enable = '1') AND (Counter_s(Counter_s'high) = '0')) THEN
					Counter_s	<= Counter_s - 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	timeout <= Counter_s(Counter_s'high);
END;