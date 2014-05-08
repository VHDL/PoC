LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

-- ============================================================================
-- asynchronous active-high reset, synchronous release
-- placement is constrained by RLOCs
-- ============================================================================

ENTITY xil_ResetSync IS
	PORT (
		Clock					: IN	STD_LOGIC;					-- clock to be sync'ed to
		ResetIn				: IN	STD_LOGIC;					-- Active high asynchronous reset
		ResetOut			: OUT	STD_LOGIC						-- "Synchronised" reset signal ()
	);
END;


ARCHITECTURE rtl OF xil_ResetSync IS
	SIGNAL ResetSync_r		: STD_LOGIC;

	-- Mark register "ResetSync_r" and "ResetOut" as asynchronous
	ATTRIBUTE ASYNC_REG											: STRING;
	ATTRIBUTE ASYNC_REG OF ResetSync_r			: SIGNAL IS "TRUE";
	ATTRIBUTE ASYNC_REG OF ResetOut					: SIGNAL IS "TRUE";

	-- Prevent XST from translating two FFs into SRL plus FF
	ATTRIBUTE SHREG_EXTRACT									: STRING;
	ATTRIBUTE SHREG_EXTRACT OF ResetSync_r	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF ResetOut			: SIGNAL IS "NO";

BEGIN

	FF1 : FDP
		GENERIC MAP (
			INIT		=> '1'
		)
		PORT MAP (
			C				=> Clock,
			PRE			=> ResetIn,
			D				=> '0',
			Q				=> ResetSync_r
	);

	FF2 : FDP
		GENERIC MAP (
			INIT		=> '1'
		)
		PORT MAP (
			C				=> Clock,
			PRE			=> ResetIn,
			D				=> ResetSync_r,
			Q				=> ResetOut
	);

	END;
