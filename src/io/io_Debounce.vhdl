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
USE			PoC.physical.ALL;


ENTITY io_Debounce IS
  GENERIC (
		CLOCK_FREQ							: FREQ				:= 100.0 MHz;
		DEBOUNCE_TIME						: TIME				:= 5.0 ms;
		BITS										: POSITIVE		:= 1;
		ADD_INPUT_SYNCHRONIZER	: BOOLEAN			:= TRUE
	);
  PORT (
		Clock		: IN STD_LOGIC;
		Input		: IN STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
		Output	: OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF io_Debounce IS
	SIGNAL Input_sync					: STD_LOGIC_VECTOR(Input'range);

BEGIN
	-- input synchronization
	genSync0 : IF (ADD_INPUT_SYNCHRONIZER = FALSE) GENERATE
		Input_sync	<= Input;
	END GENERATE;	
	genSync1 : IF (ADD_INPUT_SYNCHRONIZER = TRUE) GENERATE
		sync : ENTITY PoC.sync_Flag
			GENERIC MAP (
				BITS		=> BITS
			)
			PORT MAP (
				Clock		=> Clock,				-- Clock to be synchronized to
				Input		=> Input,				-- Data to be synchronized
				Output	=> Input_sync		-- synchronised data
			);
	END GENERATE;

	-- glitch filter
	genGF : FOR I IN 0 TO BITS - 1 GENERATE
		CONSTANT SPIKE_SUPPRESSION_CYCLES		: NATURAL		:= TimingToCycles(DEBOUNCE_TIME, CLOCK_FREQ);
	BEGIN
		GF : ENTITY PoC.io_GlitchFilter
			GENERIC MAP (
				HIGH_SPIKE_SUPPRESSION_CYCLES		=> SPIKE_SUPPRESSION_CYCLES,
				LOW_SPIKE_SUPPRESSION_CYCLES		=> SPIKE_SUPPRESSION_CYCLES
			)
			PORT MAP (
				Clock		=> Clock,
				Input		=> Input_sync(I),
				Output	=> Output(I)
			);
	END GENERATE;
END;