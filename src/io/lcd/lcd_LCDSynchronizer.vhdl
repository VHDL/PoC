-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
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
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;
use			PoC.lcd.all;


entity lcd_LCDSynchronizer is
	generic (
		CLOCK_FREQ					: FREQ		:= 100 MHz
	);
	port (
		Clock								: in	STD_LOGIC;
		Reset								: in	STD_LOGIC;

		Synchronize					: in	STD_LOGIC;
		Synchronized				: out	STD_LOGIC;

		Column							: out	T_LCD_COLUMN_INDEX;
		Row									:	out	T_LCD_ROW_INDEX;
		Char								: in	T_LCD_CHAR;

		-- LCD interface
		LCD_en							:	out	STD_LOGIC;
		LCD_rw							: out	STD_LOGIC;
		LCD_rs							: out	STD_LOGIC;								-- LCD Register Select
		LCD_Data_o					: out	T_SLV_4;
    LCD_Data_i    			: in  T_SLV_4
	);
end entity;


ARCHITECTURE rtl OF lcd_LCDSynchronizer IS
	ATTRIBUTE KEEP		: STRING;

	TYPE T_STATE IS (
		ST_RESET,
		ST_INIT_SET_FUNCTION, ST_INIT_SET_FUNCTION_WAIT,
		ST_INIT_DISPLAY_ON, ST_INIT_DISPLAY_ON_WAIT,
		ST_INIT_DISPLAY_CLEAR, ST_INIT_DISPLAY_CLEAR_WAIT,
		ST_INIT_ENTRY_MODE, ST_INIT_ENTRY_MODE_WAIT,
		ST_IDLE,
		ST_GO_HOME, ST_GO_HOME_WAIT,
		ST_WRITE_CHAR, ST_WRITE_CHAR_WAIT,
		ST_FINISHED
	);

	SIGNAL State			: T_STATE			:= ST_RESET;
	SIGNAL NextState	: T_STATE;

	CONSTANT COLAC_BITS			: POSITIVE																			:= T_LCD_COLUMN_INDEX_BW;
	CONSTANT ROWAC_BITS			: POSITIVE																			:= T_LCD_ROW_INDEX_BW;

	SIGNAL ColAC_inc				: STD_LOGIC;
	SIGNAL ColAC_Load				: STD_LOGIC;
	SIGNAL ColAC_Address		: STD_LOGIC_VECTOR(COLAC_BITS - 1 DOWNTO 0);
	SIGNAL ColAC_Address_us	: UNSIGNED(COLAC_BITS - 1 DOWNTO 0);
	SIGNAL ColAC_Finished		: STD_LOGIC;

	SIGNAL RowAC_inc				: STD_LOGIC;
	SIGNAL RowAC_Load				: STD_LOGIC;
	SIGNAL RowAC_Address		: STD_LOGIC_VECTOR(ROWAC_BITS - 1 DOWNTO 0);
	SIGNAL RowAC_Address_us	: UNSIGNED(ROWAC_BITS - 1 DOWNTO 0);
	SIGNAL RowAC_Finished		: STD_LOGIC;

	SIGNAL LCDI_Strobe			: STD_LOGIC;
	SIGNAL LCDI_Address			: STD_LOGIC;
	SIGNAL LCDI_Data				: T_SLV_8;
	SIGNAL LCDI_Ready				: STD_LOGIC;

	SIGNAL LCD_Data_tt			: STD_LOGIC;

	SIGNAL CSP_Trigger_1		: STD_LOGIC;
	ATTRIBUTE KEEP OF CSP_Trigger_1 : SIGNAL IS "TRUE";

BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State		<= ST_RESET;
			ELSE
				State		<= NextState;
			END IF;
		END IF;
	END PROCESS;


	PROCESS(State, LCDI_Ready, Synchronize, Char, RowAC_Address, ColAC_Finished, RowAC_Finished)
	BEGIN
		NextState					<= State;

		Synchronized			<= '0';

		ColAC_inc					<= '0';
		ColAC_Load				<= '0';
		RowAC_inc					<= '0';
		RowAC_Load				<= '0';

		LCDI_Strobe				<= '0';
		LCDI_Address			<= '0';
		LCDI_Data					<= KS0066U_CMD_NONE;

		CSP_Trigger_1			<= '0';

		CASE State IS
			WHEN ST_RESET =>
				IF (LCDI_Ready = '1') THEN
					CSP_Trigger_1	<= '1';

					NextState			<= ST_INIT_SET_FUNCTION;
				END IF;

			WHEN ST_INIT_SET_FUNCTION =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= KS0066U_CMD_SET_FUNCTION;

				NextState				<= ST_INIT_SET_FUNCTION_WAIT;

			WHEN ST_INIT_SET_FUNCTION_WAIT =>
				IF (LCDI_Ready = '1') THEN
					NextState			<= ST_INIT_DISPLAY_ON;
				END IF;

			WHEN ST_INIT_DISPLAY_ON =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= lcd_display_on(FALSE, FALSE);

				NextState				<= ST_INIT_DISPLAY_ON_WAIT;

			WHEN ST_INIT_DISPLAY_ON_WAIT =>
				IF (LCDI_Ready = '1') THEN
					NextState			<= ST_INIT_DISPLAY_CLEAR;
				END IF;

			WHEN ST_INIT_DISPLAY_CLEAR =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= KS0066U_CMD_DISPLAY_CLEAR;

				NextState				<= ST_INIT_DISPLAY_CLEAR_WAIT;

			WHEN ST_INIT_DISPLAY_CLEAR_WAIT =>
				IF (LCDI_Ready = '1') THEN
					NextState			<= ST_INIT_ENTRY_MODE;
				END IF;

			WHEN ST_INIT_ENTRY_MODE =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= KS0066U_CMD_ENTRY_MODE;

				NextState				<= ST_INIT_ENTRY_MODE_WAIT;

			WHEN ST_INIT_ENTRY_MODE_WAIT =>
				IF (LCDI_Ready = '1') THEN
					NextState			<= ST_IDLE;
				END IF;

			WHEN ST_IDLE =>
				IF (Synchronize = '1') THEN
					ColAC_Load			<= '1';
					RowAC_Load			<= '1';

					NextState			<= ST_GO_HOME;
				END IF;

			WHEN ST_GO_HOME =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= lcd_go_home(RowAC_Address);

				NextState				<= ST_GO_HOME_WAIT;

			WHEN ST_GO_HOME_WAIT =>
				IF (LCDI_Ready = '1') THEN
					NextState			<= ST_WRITE_CHAR;
				END IF;

			WHEN ST_WRITE_CHAR =>
				ColAC_inc				<= '1';

				LCDI_Strobe			<= '1';
				LCDI_Address		<= '1';
				LCDI_Data				<= LCD_Char2Bin(Char);

				NextState				<= ST_WRITE_CHAR_WAIT;

			WHEN ST_WRITE_CHAR_WAIT =>
				IF (LCDI_Ready = '1') THEN
					IF (ColAC_Finished = '1') THEN
						IF (RowAC_Finished = '1') THEN
							ColAC_Load	<= '1';
							RowAC_Load	<= '1';

							NextState		<= ST_FINISHED;
						ELSE
							ColAC_Load	<= '1';
							RowAC_inc		<= '1';

							NextState		<= ST_GO_HOME;
						END IF;
					ELSE
						NextState			<= ST_WRITE_CHAR;
					END IF;
				END IF;

			WHEN ST_FINISHED =>
				Synchronized			<= '1';

				NextState					<= ST_IDLE;

		END CASE;
	END PROCESS;

	blkColAC : BLOCK
		SIGNAL Counter_us				: UNSIGNED(COLAC_BITS - 1 DOWNTO 0)		:= to_unsigned(0, COLAC_BITS);
	BEGIN
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (ColAC_Load = '1') THEN
					Counter_us				<= to_unsigned(0, COLAC_BITS);
				ELSE
					IF (ColAC_inc = '1') THEN
						Counter_us			<= Counter_us + 1;
					END IF;
				END IF;
			END IF;
		END PROCESS;

		-- address output
		ColAC_Address		<= std_logic_vector(Counter_us);
		ColAC_Finished	<= to_sl(Counter_us = to_unsigned(MAX_LCD_COLUMN_COUNT, COLAC_BITS));
	END BLOCK;

	blkRowAC : BLOCK
		SIGNAL Counter_us				: UNSIGNED(ROWAC_BITS - 1 DOWNTO 0)		:= to_unsigned(0, ROWAC_BITS);
	BEGIN
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (RowAC_Load = '1') THEN
					Counter_us				<= to_unsigned(0, ROWAC_BITS);
				ELSE
					IF (RowAC_inc = '1') THEN
						Counter_us			<= Counter_us + 1;
					END IF;
				END IF;
			END IF;
		END PROCESS;

		-- address output
		RowAC_Address		<= std_logic_vector(Counter_us);
		RowAC_Finished	<= to_sl(Counter_us = to_unsigned(MAX_LCD_COLUMN_COUNT, COLAC_BITS));
	END BLOCK;

	ColAC_Address_us	<= unsigned(ColAC_Address);
	RowAC_Address_us	<= unsigned(RowAC_Address);

	Column	<= to_integer(ColAC_Address_us);
	Row			<= to_integer(RowAC_Address_us);

	LCDInterface : lcd_dotmatrix
    generic map (
      CLOCK_FREQ => CLOCK_FREQ,
      DATA_WIDTH => 4
		)
		port map (
			-- Global Reset and Clock
			clk					=> Clock,
			rst					=> Reset,

			-- Upper Layer Interface
			stb      		=> LCDI_Strobe,
		  cmd     		=> LCDI_Address,
			dat      		=> LCDI_Data,
			rdy      		=> LCDI_Ready,

			-- LCD Connections
			lcd_e   		=> LCD_en,
			lcd_rs  		=> LCD_rs,
			lcd_rw  		=> LCD_rw,
			lcd_dat_o 	=> LCD_Data_o,
			lcd_dat_i	  => LCD_Data_i
		);
END;
