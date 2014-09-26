-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	Timing Counter
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.my_config.ALL;
USE			PoC.utils.ALL;


ENTITY io_TimingCounter IS
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


ARCHITECTURE rtl OF io_TimingCounter IS
	FUNCTION transform(vec : T_NATVEC) RETURN T_INTVEC IS
    VARIABLE Result : T_INTVEC(vec'range);
  BEGIN
		ASSERT (not MY_VERBOSE) REPORT "TIMING_TABLE (transformed):" SEVERITY NOTE;
    FOR I IN vec'range LOOP
			Result(I)	 := vec(I) - 1;
			ASSERT (not MY_VERBOSE) REPORT "  " & INTEGER'image(I) & " - " & INTEGER'image(Result(I)) SEVERITY NOTE;
		END LOOP;
		RETURN Result;
  END;

	CONSTANT TIMING_TABLE2	: T_INTVEC		:= transform(TIMING_TABLE);
	CONSTANT TIMING_MAX			: NATURAL			:= imax(TIMING_TABLE2);
	CONSTANT COUNTER_BITS		: NATURAL			:= log2ceilnz(TIMING_MAX + 1);

	SIGNAL Counter_s				: SIGNED(COUNTER_BITS DOWNTO 0)		:= to_signed(TIMING_TABLE2(0), COUNTER_BITS + 1);
	
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