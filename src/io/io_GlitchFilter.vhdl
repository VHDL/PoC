-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	Glitch Filter
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


ENTITY io_GlitchFilter IS
  GENERIC (
		HIGH_SPIKE_SUPPRESSION_CYCLES			: NATURAL				:= 5;
		LOW_SPIKE_SUPPRESSION_CYCLES			: NATURAL				:= 5
	);
  PORT (
		Clock		: IN	STD_LOGIC;
		Input		: IN	STD_LOGIC;
		Output	: OUT STD_LOGIC
	);
END;


ARCHITECTURE rtl OF io_GlitchFilter IS
	-- Timing table ID
	CONSTANT TTID_HIGH_SPIKE				: NATURAL		:= 0;
	CONSTANT TTID_LOW_SPIKE					: NATURAL		:= 1;
	
	-- Timing table
	CONSTANT TIMING_TABLE						: T_NATVEC	:= (
		TTID_HIGH_SPIKE			=> HIGH_SPIKE_SUPPRESSION_CYCLES,
		TTID_LOW_SPIKE			=> LOW_SPIKE_SUPPRESSION_CYCLES
	);

	SIGNAL State										: STD_LOGIC												:= '0';
	SIGNAL NextState								: STD_LOGIC;

	SIGNAL TC_en										: STD_LOGIC;
	SIGNAL TC_Load									: STD_LOGIC;
	SIGNAL TC_Slot									: NATURAL;
	SIGNAL TC_Timeout								: STD_LOGIC;

BEGIN
	ASSERT FALSE REPORT "GlitchFilter: " &
											"HighSpikeSuppressionCycles=" & INTEGER'image(TIMING_TABLE(TTID_HIGH_SPIKE)) & "  " &
											"LowSpikeSuppressionCycles=" & INTEGER'image(TIMING_TABLE(TTID_LOW_SPIKE)) & "  " SEVERITY NOTE;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			State		<= NextState;
		END IF;
	END PROCESS;

	PROCESS(State, Input, TC_Timeout)
	BEGIN
		NextState		<= State;
		
		TC_en				<= '0';
		TC_Load			<= '0';
		TC_Slot			<= 0;
		
		CASE State IS
			WHEN '0' =>
				TC_Slot			<= TTID_HIGH_SPIKE;
			
				IF (Input = '1') THEN
					TC_en			<= '1';
				ELSE
					TC_Load		<= '1';
				END IF;
				
				IF ((Input AND TC_Timeout) = '1') THEN
					NextState	<= '1';
				END IF;

			WHEN '1' =>
				TC_Slot			<= TTID_LOW_SPIKE;
			
				IF (Input = '0') THEN
					TC_en			<= '1';
				ELSE
					TC_Load		<= '1';
				END IF;
				
				IF ((NOT Input AND TC_Timeout) = '1') THEN
					NextState	<= '0';
				END IF;
			
			WHEN OTHERS =>
				NULL;
			
		END CASE;
	END PROCESS;

	TC : ENTITY PoC.io_TimingCounter
		GENERIC MAP (
			TIMING_TABLE				=> TIMING_TABLE										-- timing table
		)
		PORT MAP (
			Clock								=> Clock,													-- clock
			Enable							=> TC_en,													-- enable counter
			Load								=> TC_Load,												-- load Timing Value from TIMING_TABLE selected by slot
			Slot								=> TC_Slot,												-- 
			Timeout							=> TC_Timeout											-- timing reached
		);	

	Output <= State;
END;