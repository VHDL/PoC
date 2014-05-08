LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;

-- Usage
-- ====================================
-- LIBRARY	PoC;
-- USE			PoC.Xilinx.ALL;

PACKAGE xilinx IS
	-- ChipScope
	-- ==========================================================================
	SUBTYPE	T_CHIPSCOPE_CONTROL IS STD_LOGIC_VECTOR(35 DOWNTO 0);
	TYPE		T_CHIPSCOPE_CONTROL_VECTOR IS ARRAY (NATURAL RANGE <>) OF T_CHIPSCOPE_CONTROL;

	-- Dynamic Reconfiguration Port (DRP)
	-- ==========================================================================
	SUBTYPE T_XIL_DRP_ADDRESS						IS T_SLV_16;
	SUBTYPE T_XIL_DRP_DATA							IS T_SLV_16;

	TYPE		T_XIL_DRP_ADDRESS_VECTOR						IS ARRAY (NATURAL RANGE <>) OF T_XIL_DRP_ADDRESS;
	TYPE		T_XIL_DRP_DATA_VECTOR								IS ARRAY (NATURAL RANGE <>) OF T_XIL_DRP_DATA;

	TYPE T_XIL_DRP_CONFIG IS RECORD
		Address														: T_XIL_DRP_ADDRESS;
		Mask															: T_XIL_DRP_DATA;
		Data															: T_XIL_DRP_DATA;
	END RECORD;
	
	-- define array indices
	CONSTANT C_XIL_DRP_MAX_CONFIG_COUNT		: POSITIVE	:= 8;
	SUBTYPE T_XIL_DRP_CONFIG_INDEX			IS INTEGER RANGE 0 TO C_XIL_DRP_MAX_CONFIG_COUNT - 1;
	TYPE		T_XIL_DRP_CONFIG_VECTOR			IS ARRAY (NATURAL RANGE <>) OF T_XIL_DRP_CONFIG;
	
	TYPE T_XIL_DRP_CONFIG_SET IS RECORD
		Configs														: T_XIL_DRP_CONFIG_VECTOR(T_XIL_DRP_CONFIG_INDEX);
		LastIndex													: T_XIL_DRP_CONFIG_INDEX;
	END RECORD;
	
	TYPE T_XIL_DRP_CONFIG_ROM						IS ARRAY (NATURAL RANGE <>) OF T_XIL_DRP_CONFIG_SET;
	
	CONSTANT C_XIL_DRP_CONFIG_EMPTY			: T_XIL_DRP_CONFIG				:= (
		Address =>	(OTHERS => '0'),
		Data =>			(OTHERS => '0'),
		Mask =>			(OTHERS => '0')
	);

	CONSTANT C_XIL_DRP_CONFIG_SET_EMPTY	: T_XIL_DRP_CONFIG_SET		:= (
		Configs		=> (OTHERS => C_XIL_DRP_CONFIG_EMPTY),
		LastIndex	=> 0
	);

	
	COMPONENT xil_SystemMonitor_Virtex6 IS
		PORT (
			Reset								: IN	STD_LOGIC;				-- Reset signal for the System Monitor control logic
			
			Alarm_UserTemp			: OUT	STD_LOGIC;				-- Temperature-sensor alarm output
			Alarm_OverTemp			: OUT	STD_LOGIC;				-- Over-Temperature alarm output
			Alarm								: OUT	STD_LOGIC;				-- OR'ed output of all the Alarms
			VP									: IN	STD_LOGIC;				-- Dedicated Analog Input Pair
			VN									: IN	STD_LOGIC
		);
	END COMPONENT;

	COMPONENT xil_SystemMonitor_Series7 IS
		PORT (
			Reset								: IN	STD_LOGIC;				-- Reset signal for the System Monitor control logic
			
			Alarm_UserTemp			: OUT	STD_LOGIC;				-- Temperature-sensor alarm output
			Alarm_OverTemp			: OUT	STD_LOGIC;				-- Over-Temperature alarm output
			Alarm								: OUT	STD_LOGIC;				-- OR'ed output of all the Alarms
			VP									: IN	STD_LOGIC;				-- Dedicated Analog Input Pair
			VN									: IN	STD_LOGIC
		);
	END COMPONENT;
END xilinx;


PACKAGE BODY xilinx IS

END PACKAGE BODY;
