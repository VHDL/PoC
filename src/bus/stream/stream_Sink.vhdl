LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;
USE			L_Global.GlobalSimulation.ALL;


ENTITY Stream_Sink IS
	GENERIC (
		TESTCASES												: T_SIM_STREAM_FRAMEGROUP_VECTOR_8
	);
	PORT (
		Clock														: IN	STD_LOGIC;
		Reset														: IN	STD_LOGIC;
		-- Control interface
		Enable													: IN	STD_LOGIC;
		Error														: OUT	STD_LOGIC;
		-- IN Port
		In_Valid												: IN	STD_LOGIC;
		In_Data													: IN	T_SLV_8;
		In_SOF													: IN	STD_LOGIC;
		In_EOF													: IN	STD_LOGIC;
		In_Ready												: OUT	STD_LOGIC
	);
END ENTITY;


ARCHITECTURE rtl OF Stream_Sink IS

BEGIN

	In_Ready		<= '1';-- RX_Valid;

END ARCHITECTURE;
