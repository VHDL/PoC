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
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
		Clock								: in	std_logic;
		Reset								: in	std_logic;

		Synchronize					: in	std_logic;
		Synchronized				: out	std_logic;

		Column							: out	T_LCD_COLUMN_INDEX;
		Row									:	out	T_LCD_ROW_INDEX;
		Char								: in	T_LCD_CHAR;

		-- LCD interface
		LCD_en							:	out	std_logic;
		LCD_rw							: out	std_logic;
		LCD_rs							: out	std_logic;								-- LCD Register Select
		LCD_Data_o					: out	T_SLV_4;
    LCD_Data_i    			: in  T_SLV_4
	);
end entity;


architecture rtl of lcd_LCDSynchronizer is
	attribute KEEP		: string;

	type T_STATE is (
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

	signal State			: T_STATE			:= ST_RESET;
	signal NextState	: T_STATE;

	constant COLAC_BITS			: positive																			:= T_LCD_COLUMN_INDEX_BW;
	constant ROWAC_BITS			: positive																			:= T_LCD_ROW_INDEX_BW;

	signal ColAC_inc				: std_logic;
	signal ColAC_Load				: std_logic;
	signal ColAC_Address		: std_logic_vector(COLAC_BITS - 1 downto 0);
	signal ColAC_Address_us	: unsigned(COLAC_BITS - 1 downto 0);
	signal ColAC_Finished		: std_logic;

	signal RowAC_inc				: std_logic;
	signal RowAC_Load				: std_logic;
	signal RowAC_Address		: std_logic_vector(ROWAC_BITS - 1 downto 0);
	signal RowAC_Address_us	: unsigned(ROWAC_BITS - 1 downto 0);
	signal RowAC_Finished		: std_logic;

	signal LCDI_Strobe			: std_logic;
	signal LCDI_Address			: std_logic;
	signal LCDI_Data				: T_SLV_8;
	signal LCDI_Ready				: std_logic;

	signal LCD_Data_tt			: std_logic;

	signal CSP_Trigger_1		: std_logic;
	attribute KEEP of CSP_Trigger_1 : signal is "TRUE";

begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State		<= ST_RESET;
			else
				State		<= NextState;
			end if;
		end if;
	end process;


	process(State, LCDI_Ready, Synchronize, Char, RowAC_Address, ColAC_Finished, RowAC_Finished)
	begin
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

		case State is
			when ST_RESET =>
				if (LCDI_Ready = '1') then
					CSP_Trigger_1	<= '1';

					NextState			<= ST_INIT_SET_FUNCTION;
				end if;

			when ST_INIT_SET_FUNCTION =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= KS0066U_CMD_SET_FUNCTION;

				NextState				<= ST_INIT_SET_FUNCTION_WAIT;

			when ST_INIT_SET_FUNCTION_WAIT =>
				if (LCDI_Ready = '1') then
					NextState			<= ST_INIT_DISPLAY_ON;
				end if;

			when ST_INIT_DISPLAY_ON =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= lcd_display_on(FALSE, FALSE);

				NextState				<= ST_INIT_DISPLAY_ON_WAIT;

			when ST_INIT_DISPLAY_ON_WAIT =>
				if (LCDI_Ready = '1') then
					NextState			<= ST_INIT_DISPLAY_CLEAR;
				end if;

			when ST_INIT_DISPLAY_CLEAR =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= KS0066U_CMD_DISPLAY_CLEAR;

				NextState				<= ST_INIT_DISPLAY_CLEAR_WAIT;

			when ST_INIT_DISPLAY_CLEAR_WAIT =>
				if (LCDI_Ready = '1') then
					NextState			<= ST_INIT_ENTRY_MODE;
				end if;

			when ST_INIT_ENTRY_MODE =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= KS0066U_CMD_ENTRY_MODE;

				NextState				<= ST_INIT_ENTRY_MODE_WAIT;

			when ST_INIT_ENTRY_MODE_WAIT =>
				if (LCDI_Ready = '1') then
					NextState			<= ST_IDLE;
				end if;

			when ST_IDLE =>
				if (Synchronize = '1') then
					ColAC_Load			<= '1';
					RowAC_Load			<= '1';

					NextState			<= ST_GO_HOME;
				end if;

			when ST_GO_HOME =>
				LCDI_Strobe			<= '1';
				LCDI_Address		<= '0';
				LCDI_Data				<= lcd_go_home(RowAC_Address);

				NextState				<= ST_GO_HOME_WAIT;

			when ST_GO_HOME_WAIT =>
				if (LCDI_Ready = '1') then
					NextState			<= ST_WRITE_CHAR;
				end if;

			when ST_WRITE_CHAR =>
				ColAC_inc				<= '1';

				LCDI_Strobe			<= '1';
				LCDI_Address		<= '1';
				LCDI_Data				<= LCD_Char2Bin(Char);

				NextState				<= ST_WRITE_CHAR_WAIT;

			when ST_WRITE_CHAR_WAIT =>
				if (LCDI_Ready = '1') then
					if (ColAC_Finished = '1') then
						if (RowAC_Finished = '1') then
							ColAC_Load	<= '1';
							RowAC_Load	<= '1';

							NextState		<= ST_FINISHED;
						else
							ColAC_Load	<= '1';
							RowAC_inc		<= '1';

							NextState		<= ST_GO_HOME;
						end if;
					else
						NextState			<= ST_WRITE_CHAR;
					end if;
				end if;

			when ST_FINISHED =>
				Synchronized			<= '1';

				NextState					<= ST_IDLE;

		end case;
	end process;

	blkColAC : block
		signal Counter_us				: unsigned(COLAC_BITS - 1 downto 0)		:= to_unsigned(0, COLAC_BITS);
	begin
		process(Clock)
		begin
			if rising_edge(Clock) then
				if (ColAC_Load = '1') then
					Counter_us				<= to_unsigned(0, COLAC_BITS);
				else
					if (ColAC_inc = '1') then
						Counter_us			<= Counter_us + 1;
					end if;
				end if;
			end if;
		end process;

		-- address output
		ColAC_Address		<= std_logic_vector(Counter_us);
		ColAC_Finished	<= to_sl(Counter_us = to_unsigned(MAX_LCD_COLUMN_COUNT, COLAC_BITS));
	end block;

	blkRowAC : block
		signal Counter_us				: unsigned(ROWAC_BITS - 1 downto 0)		:= to_unsigned(0, ROWAC_BITS);
	begin
		process(Clock)
		begin
			if rising_edge(Clock) then
				if (RowAC_Load = '1') then
					Counter_us				<= to_unsigned(0, ROWAC_BITS);
				else
					if (RowAC_inc = '1') then
						Counter_us			<= Counter_us + 1;
					end if;
				end if;
			end if;
		end process;

		-- address output
		RowAC_Address		<= std_logic_vector(Counter_us);
		RowAC_Finished	<= to_sl(Counter_us = to_unsigned(MAX_LCD_COLUMN_COUNT, COLAC_BITS));
	end block;

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
end;
