LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

-- ============================================================================
-- clock-domain crossing with two FFs
-- use only for:
--	o long time signals
--	o between clock domains with the same frequency
-- 
-- placement is constrained by RLOCs
-- ============================================================================

ENTITY xil_SyncBlock IS
	PORT (
		Clock					: IN	STD_LOGIC;					-- Clock to be synchronized to
		DataIn				: IN	STD_LOGIC;					-- Data to be synchronized
		DataOut				: OUT	STD_LOGIC						-- synchronised data
	);
END;


ARCHITECTURE rtl OF xil_SyncBlock IS
	SIGNAL DataSync_r		: STD_LOGIC;

	-- Mark register "DataSync_r" as asynchronous
	ATTRIBUTE ASYNC_REG											: STRING;
	ATTRIBUTE ASYNC_REG OF DataSync_r				: SIGNAL IS "TRUE";

	-- Prevent XST from translating two FFs into SRL plus FF
	ATTRIBUTE SHREG_EXTRACT									: STRING;
	ATTRIBUTE SHREG_EXTRACT OF DataSync_r		: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF DataOut			: SIGNAL IS "NO";

BEGIN

	FF1 : FD
		GENERIC MAP (
			INIT		=> '0'
		)
		PORT MAP (
			C				=> Clock,
			D				=> DataIn,
			Q				=> DataSync_r
	);

	FF2 : FD
		GENERIC MAP (
			INIT		=> '0'
		)
		PORT MAP (
			C				=> Clock,
			D				=> DataSync_r,
			Q				=> DataOut
	);

	END;
