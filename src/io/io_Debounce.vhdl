-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
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
USE			PoC.utils.ALL;
USE			PoC.io.ALL;


ENTITY io_Debounce IS
  GENERIC (
		CLOCK_FREQ_MHZ			: REAL				:= 50.0;
		DEBOUNCE_TIME_MS		: REAL				:= 5.0;
		BITS								: POSITIVE		:= 1
	);
  PORT (
		Clock		: IN STD_LOGIC;
		I				: IN STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
		O				: OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF io_Debounce IS
	ATTRIBUTE KEEP														: BOOLEAN;
	ATTRIBUTE ASYNC_REG												: STRING;
	ATTRIBUTE SHREG_EXTRACT										: STRING;

  -- Debounce Clock Cycles
	CONSTANT COUNTER_CYCLES		: POSITIVE			:= TimingToCycles_ms(DEBOUNCE_TIME_MS, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)) - 1;
	CONSTANT COUNTER_BITS			: POSITIVE			:= log2ceil(COUNTER_CYCLES);

BEGIN

	gen : FOR J IN 0 TO BITS - 1 GENERATE
		SIGNAL I_async			: STD_LOGIC			:= '0';
		SIGNAL I_sync				: STD_LOGIC			:= '0';
		
		-- Mark register "I_async" as asynchronous
		ATTRIBUTE ASYNC_REG OF I_async			: SIGNAL IS "TRUE";

		-- Prevent XST from translating two FFs into SRL plus FF
		ATTRIBUTE SHREG_EXTRACT OF I_async	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF I_sync		: SIGNAL IS "NO";
		
	BEGIN
		I_async	<= I(J)			WHEN rising_edge(Clock);
		I_sync	<= I_async	WHEN rising_edge(Clock);
	
		GF : ENTITY PoC.io_GlitchFilter
			GENERIC MAP (
				CLOCK_FREQ_MHZ										=> CLOCK_FREQ_MHZ,
				HIGH_SPIKE_SUPPRESSION_TIME_NS		=> DEBOUNCE_TIME_MS * 1000.0 * 1000.0,
				LOW_SPIKE_SUPPRESSION_TIME_NS			=> DEBOUNCE_TIME_MS * 1000.0 * 1000.0
			)
			PORT MAP (
				Clock		=> Clock,
				I				=> I_sync,
				O				=> O(J)
			);
	END GENERATE;
END;