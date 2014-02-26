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
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

ENTITY TimingCounter IS
  GENERIC (
	  TIMING_TABLE				: T_NATVEC																		-- timing table
	);
  PORT (
	  Clock								: IN	STD_LOGIC;															-- clock
		Enable							: IN	STD_LOGIC;															-- enable counter
		Load								: IN	STD_LOGIC;															-- load Timing Value from TIMING_TABLE selected by slot
		Slot								: IN	INTEGER;																-- 
		Timeout							: OUT STD_LOGIC																-- timing reached
	);
END;

ARCHITECTURE rtl OF TimingCounter IS
	FUNCTION transform(NatVector : T_NATVEC) RETURN T_NATVEC IS
    VARIABLE Result : T_NATVEC(NatVector'range);
  BEGIN
    FOR I IN NatVector'range LOOP
			Result(I)	 := NatVector(I) - 1;
		END LOOP;
		
		RETURN Result;
  END;

	FUNCTION NATVEC_max(NatVector : T_NATVEC) RETURN NATURAL IS
    VARIABLE max : NATURAL := 1;
  BEGIN
    FOR I IN NatVector'range LOOP
			IF (NatVector(I) > max) THEN
				max := NatVector(I);
			END IF;
		END LOOP;
		
		RETURN max;
  END;

	CONSTANT TIMING_TABLE2	: T_NATVEC		:= transform(TIMING_TABLE);
	CONSTANT TIMING_MAX			: NATURAL			:= NATVEC_max(TIMING_TABLE2);
	CONSTANT COUNTER_BW			: NATURAL			:= log2ceilnz(TIMING_MAX);

	SIGNAL Counter_s				: SIGNED(COUNTER_BW DOWNTO 0)		:= to_signed(TIMING_TABLE(0), COUNTER_BW + 1);
	
BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Load = '1') THEN
				Counter_s		<= to_signed(TIMING_TABLE(Slot), Counter_s'length);
			ELSE
				IF (Enable = '1') THEN
					Counter_s	<= Counter_s - 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	timeout <= Counter_s(Counter_s'high);
END;