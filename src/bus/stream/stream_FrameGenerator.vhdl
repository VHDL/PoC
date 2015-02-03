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
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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
USE			IEEE.STD_LOGIC_1164.all;
USE			ieee.numeric_std.all;

LIBRARY	PoC;
USE			PoC.utils.all;
USE			PoC.vectors.all;
USE			PoC.arith_prng;


ENTITY Stream_FrameGenerator IS
  GENERIC (
    DATA_BITS							: POSITIVE														:= 8;
		WORD_BITS							: POSITIVE														:= 16;
		APPEND								: T_FRAMEGEN_APPEND										:= FRAMEGEN_APP_NONE;
		FRAMEGROUPS						: T_FRAMEGEN_FRAMEGROUP_VECTOR_8			:= (0 => C_FRAMEGEN_FRAMEGROUP_EMPTY)
  );
	PORT (
		Clock									: IN	STD_LOGIC;
		Reset									: IN	STD_LOGIC;

		-- CSE interface
		Command								: IN	T_FRAMEGEN_COMMAND;
		Status								: OUT	T_FRAMEGEN_STATUS;

		-- Control interface
		Pause									: IN	T_SLV_16;
		FrameGroupIndex				: IN	T_SLV_8;
		FrameIndex						: IN	T_SLV_8;
		Sequences							: IN	T_SLV_16;
		FrameLength						: IN	T_SLV_16;
		
		-- OUT Port
		Out_Valid							: OUT	STD_LOGIC;
		Out_Data							: OUT	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		Out_SOF								: OUT	STD_LOGIC;
		Out_EOF								: OUT	STD_LOGIC;
		Out_Ack								: IN	STD_LOGIC
	);
END;


ARCHITECTURE rtl OF Stream_FrameGenerator IS

	TYPE T_STATE IS (
		ST_IDLE,
			ST_SEQUENCE_SOF,	ST_SEQUENCE_DATA,	ST_SEQUENCE_EOF,
			ST_RANDOM_SOF,		ST_RANDOM_DATA,		ST_RANDOM_EOF,
		ST_ERROR
	);
	
	SIGNAL State											: T_STATE														:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	
	SIGNAL FrameLengthCounter_rst			: STD_LOGIC;
	SIGNAL FrameLengthCounter_en			: STD_LOGIC;
	SIGNAL FrameLengthCounter_us			: UNSIGNED(15 DOWNTO 0)							:= (OTHERS => '0');
	
	SIGNAL SequencesCounter_rst				: STD_LOGIC;
	SIGNAL SequencesCounter_en				: STD_LOGIC;
	SIGNAL SequencesCounter_us				: UNSIGNED(15 DOWNTO 0)							:= (OTHERS => '0');
	SIGNAL ContentCounter_rst					: STD_LOGIC;
	SIGNAL ContentCounter_en					: STD_LOGIC;
	SIGNAL ContentCounter_us					: UNSIGNED(WORD_BITS - 1 DOWNTO 0)	:= (OTHERS => '0');
	
	SIGNAL PRNG_rst										: STD_LOGIC;
	SIGNAL PRNG_got										: STD_LOGIC;
	SIGNAL PRNG_Data									: STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State		<= ST_IDLE;
			ELSE
				State		<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Command, Out_Ack,
					Sequences, FrameLength,
					FrameLengthCounter_us,
					SequencesCounter_us, ContentCounter_us,
					PRNG_Data)
	BEGIN
		NextState													<= State;
		
		Status														<= FRAMEGEN_STATUS_GENERATING;
		
		Out_Valid													<= '0';
		Out_Data													<= (OTHERS => '0');
		Out_SOF														<= '0';
		Out_EOF														<= '0';
		
		FrameLengthCounter_rst						<= '0';
		FrameLengthCounter_en							<= '0';
		SequencesCounter_rst							<= '0';
		SequencesCounter_en								<= '0';
		ContentCounter_rst								<= '0';
		ContentCounter_en									<= '0';
		
		PRNG_rst													<= '0';
		PRNG_got													<= '0';
		
		CASE State IS
			WHEN ST_IDLE =>
				Status												<= FRAMEGEN_STATUS_IDLE;
				
				FrameLengthCounter_rst				<= '1';
				SequencesCounter_rst					<= '1';
				ContentCounter_rst						<= '1';
				PRNG_rst											<= '1';
			
				CASE Command IS
					WHEN FRAMEGEN_CMD_NONE =>
						NULL;
					
					WHEN FRAMEGEN_CMD_SEQUENCE =>
						NextState									<= ST_SEQUENCE_SOF;
						
					WHEN FRAMEGEN_CMD_RANDOM =>
						NextState									<= ST_RANDOM_SOF;
					
					WHEN FRAMEGEN_CMD_SINGLE_FRAME =>
						NextState									<= ST_ERROR;
						
					WHEN FRAMEGEN_CMD_SINGLE_FRAMEGROUP =>
						NextState									<= ST_ERROR;
						
					WHEN FRAMEGEN_CMD_ALL_FRAMES =>
						NextState									<= ST_ERROR;
						
					WHEN OTHERS =>
						NextState									<= ST_ERROR;
				END CASE;
			
			-- generate sequential numbers
			-- ----------------------------------------------------------------------
			WHEN ST_SEQUENCE_SOF =>
				Out_Valid											<= '1';
				Out_Data											<= std_logic_vector(ContentCounter_us);
				Out_SOF												<= '1';
				
				IF (Out_Ack	 = '1') THEN
					FrameLengthCounter_en				<= '1';
					ContentCounter_en						<= '1';
					
					NextState										<= ST_SEQUENCE_DATA;
				END IF;
			
			WHEN ST_SEQUENCE_DATA =>
				Out_Valid											<= '1';
				Out_Data											<= std_logic_vector(ContentCounter_us);
				
				IF (Out_Ack	 = '1') THEN
					FrameLengthCounter_en				<= '1';
					ContentCounter_en						<= '1';
					
					IF (FrameLengthCounter_us = (unsigned(FrameLength) - 2)) THEN
						NextState									<= ST_SEQUENCE_EOF;
					END IF;
				END IF;
				
			WHEN ST_SEQUENCE_EOF =>
				Out_Valid											<= '1';
				Out_Data											<= std_logic_vector(ContentCounter_us);
				Out_EOF												<= '1';
				
				IF (Out_Ack	 = '1') THEN
					FrameLengthCounter_rst			<= '1';
					ContentCounter_en						<= '1';
					SequencesCounter_en					<= '1';
					
--					IF (Pause = (Pause'range => '0')) THEN
					IF (SequencesCounter_us = (unsigned(Sequences) - 1)) THEN
						Status										<= FRAMEGEN_STATUS_COMPLETE;
						NextState									<= ST_IDLE;
					ELSE
						NextState									<= ST_SEQUENCE_SOF;
					END IF;
--					END IF;
				END IF;
			
			-- generate random numbers
			-- ----------------------------------------------------------------------
			WHEN ST_RANDOM_SOF =>
				Out_Valid									<= '1';
				Out_Data									<= PRNG_Data;
				Out_SOF										<= '1';
				
				IF (Out_Ack	 = '1') THEN
					FrameLengthCounter_en		<= '1';
					PRNG_got								<= '1';
					NextState								<= ST_RANDOM_DATA;
				END IF;
	
			WHEN ST_RANDOM_DATA =>
				Out_Valid									<= '1';
				Out_Data									<= PRNG_Data;

				IF (Out_Ack	 = '1') THEN
					FrameLengthCounter_en		<= '1';
					PRNG_got								<= '1';
					
					IF (FrameLengthCounter_us = (unsigned(FrameLength) - 2)) THEN
						NextState							<= ST_RANDOM_EOF;
					END IF;
				END IF;
			
			WHEN ST_RANDOM_EOF =>
				Out_Valid									<= '1';
				Out_Data									<= PRNG_Data;
				Out_EOF										<= '1';
				
				FrameLengthCounter_rst		<= '1';
				
				IF (Out_Ack	 = '1') THEN
					PRNG_rst								<= '1';
					NextState								<= ST_IDLE;
				END IF;
			
			WHEN ST_ERROR =>
				Status										<= FRAMEGEN_STATUS_ERROR;
				NextState									<= ST_IDLE;
				
		END CASE;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR FrameLengthCounter_rst) = '1') THEN
				FrameLengthCounter_us			<= (OTHERS => '0');
			ELSE
				IF (FrameLengthCounter_en = '1') THEN
					FrameLengthCounter_us		<= FrameLengthCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR SequencesCounter_rst) = '1') THEN
				SequencesCounter_us			<= (OTHERS => '0');
			ELSE
				IF (SequencesCounter_en = '1') THEN
					SequencesCounter_us		<= SequencesCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR ContentCounter_rst) = '1') THEN
				ContentCounter_us				<= (OTHERS => '0');
			ELSE
				IF (ContentCounter_en = '1') THEN
					ContentCounter_us			<= ContentCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	PRNG : ENTITY Poc.alu_prng
    GENERIC MAP (
      BITS		=> DATA_BITS
		)
    PORT MAP (
      clk			=> Clock,
      rst			=> PRNG_rst,
      got			=> PRNG_got,
      val			=> PRNG_Data
     );
END;