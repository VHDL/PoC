--
-- Copyright (c) 2012
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
--
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: sim_value_change_dump
-- Author(s): Patrick Lehmann
--
-- Summary:
-- ============
--  This function package parses *.VCD files and drives simulation stimulies.
--
-- Description:
-- ============
--	"VCD_ReadHeader" reads the file header.
--	"VCD_ReadLine" reads a line from *.vcd file.
--	"VCD_Read_StdLogic" parses a vcd one bit value to std_logic.
--	"VCD_Read_StdLogicVector" parses a vcd N bit value to std_logic_vector with N bits.
--
--	See ../tb/Test_vcd_example_tb.vhd for example code.
--
-- Dependancies:
-- =============
--	-	IEEE.STD_LOGIC_1164.ALL
--	- IEEE.STD_LOGIC_TEXTIO.ALL
--	- IEEE.NUMERIC_STD.ALL
--	- STD.TEXTIO.ALL
--	- PoC.functions.ALL
--	- PoC.sim_value_change_dump.ALL
--
--	- ../tb/sim_vcd_example_tb.vcd
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2012-06-08 16:51:07 $
--

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.STD_LOGIC_TEXTIO.ALL;
USE			IEEE.NUMERIC_STD.ALL;
USE			STD.TEXTIO.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;
USE			PoC.sim_value_change_dump.ALL;

ENTITY Test_vcd_example_tb IS

END;


ARCHITECTURE test OF Test_vcd_example_tb IS
	CONSTANT CLOCK_50MHZ_PERIOD							: TIME								:= 20.0 ns;

	SIGNAL Clock														: STD_LOGIC						:= '1';
	SIGNAL Reset														: STD_LOGIC						:= '0';

	SIGNAL ready														: STD_LOGIC;
	SIGNAL sof															: STD_LOGIC;
	SIGNAL eof															: STD_LOGIC;
	SIGNAL data															: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL valid														: STD_LOGIC;

BEGIN

	ClockProcess50MHz : PROCESS(Clock)
  BEGIN
		Clock <= NOT Clock AFTER CLOCK_50MHZ_PERIOD / 2;
  END PROCESS;

	VCDProcess: PROCESS
		FILE			VCDFile				: TEXT;
		VARIABLE	VCDLine				: T_VCDLINE;

		VARIABLE	VCDTime				: INTEGER;
		VARIABLE	VCDTime_nx		: INTEGER;

	BEGIN
		Reset								<= '0';
		WAIT FOR 2	* CLOCK_50MHZ_PERIOD;

		Reset								<= '1';
		WAIT FOR 1	* CLOCK_50MHZ_PERIOD;

		Reset								<= '0';
		WAIT FOR 4	* CLOCK_50MHZ_PERIOD;

		-- open *.vcd file and read header
		file_open(VCDFile, "D:\VHDL\SATAController\lib\PoC\functions\tb\sim_vcd_example_tb.vcd", READ_MODE);
		VCD_ReadHeader(VCDFile, VCDLine);

		-- read initial stimuli values
		-- ==============================================================
		VCDTime		:= to_nat(VCDLine(2 TO VCDLine'high));
		IF (VCDTime = -1) THEN
			ASSERT (FALSE) REPORT "no positive after #-symbol!" SEVERITY FAILURE;
		ELSIF (VCDTime /= 0) THEN
			ASSERT (FALSE) REPORT  "no initial stimuli" SEVERITY FAILURE;
		END IF;

		-- read waveform stimuli
		-- ==============================================================
		loop0 : WHILE (NOT endfile(VCDFile)) LOOP
			loop1 : WHILE (NOT endfile(VCDFile)) LOOP
				VCD_ReadLine(VCDFile, VCDLine);

				IF (endfile(VCDFile)) THEN
					EXIT loop0;
				END IF;

				IF (VCDLine(1) = '#') THEN
					EXIT loop1;
				ELSIF (VCDLine(1) = 'b') THEN
					-- add binary vectors here
					VCD_Read_StdLogicVector(VCDLine(2 TO VCDLine'high), data, resize("n3", 4), '0');
				ELSE
					-- add single bit signals here
					VCD_Read_StdLogic(VCDLine, ready,		resize("n0", 4));
					VCD_Read_StdLogic(VCDLine, sof,			resize("n1", 4));
					VCD_Read_StdLogic(VCDLine, eof,			resize("n2", 4));
					VCD_Read_StdLogic(VCDLine, valid,		resize("n4", 4));
				END IF;
			END LOOP;

			VCDTime_nx	:= to_nat(VCDLine(2 TO VCDLine'high));
			WAIT FOR (VCDTime_nx - VCDTime) * CLOCK_50MHZ_PERIOD;
			VCDTime			:= VCDTime_nx;
		END LOOP;	-- WHILE TRUE

		-- ==============================================================
		-- close *.vcd-file
		file_close(VCDFile);

		ASSERT (FALSE) REPORT "end of VCD file" SEVERITY WARNING;

		WAIT;
	END PROCESS;


END;