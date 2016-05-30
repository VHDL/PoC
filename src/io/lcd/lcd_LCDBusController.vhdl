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

LIBRARY	PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
use			PoC.physical.all;
USE			PoC.io.ALL;
USE			PoC.lcd.ALL;


ENTITY lcd_LCDBusController IS
	GENERIC (
		SPEEDUP_SIMULATION				: BOOLEAN												:= TRUE;
		CLOCK_FREQ								: FREQ													:= 100 MHz;
		LCD_BUS_BITS							: POSITIVE											:= 4
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;

		Command										: IN	T_IO_LCDBUS_COMMAND;
		Status										: OUT	T_IO_LCDBUS_STATUS;
		RegisterAddress						: IN	STD_LOGIC;

		DataIn										: IN	T_SLV_8;
		DataOut										: OUT	T_SLV_8;

		LCD_BusEnable							: OUT	STD_LOGIC;
		LCD_ReadWrite							: OUT	STD_LOGIC;
		LCD_RegisterSelect				: OUT	STD_LOGIC;
		LCD_Data_i								: IN	STD_LOGIC_VECTOR(7 DOWNTO (8 - LCD_BUS_BITS));
		LCD_Data_o								: OUT	STD_LOGIC_VECTOR(7 DOWNTO (8 - LCD_BUS_BITS));
		LCD_Data_t								: OUT	STD_LOGIC_VECTOR(7 DOWNTO (8 - LCD_BUS_BITS))
	);
END;

ARCHITECTURE rtl OF lcd_LCDBusController IS
	ATTRIBUTE KEEP														: BOOLEAN;
	ATTRIBUTE FSM_ENCODING										: STRING;

--	CONSTANT CLOCK_DUTY_CYCLE									: REAL			:= 0.50;		-- 50% high time
	CONSTANT TIME_BUSENABLE_HIGH							: TIME			:= 250 ns;		--Freq_kHz2Real_ns(LCD_BUS_FREQ_KHZ * 			CLOCK_DUTY_CYCLE);
	CONSTANT TIME_BUSENABLE_LOW								: TIME			:= 250 ns;		--Freq_kHz2Real_ns(LCD_BUS_FREQ_KHZ * (1 - CLOCK_DUTY_CYCLE));

	CONSTANT TIME_SETUP_REGSEL								: TIME			:= 40 ns;
	CONSTANT TIME_SETUP_DATA									: TIME			:= 80 ns;
	CONSTANT TIME_HOLD_REGSEL									: TIME			:= 10 ns;
	CONSTANT TIME_HOLD_DATA										: TIME			:= 10 ns;
	CONSTANT TIME_VALID_DATA									: TIME			:= 5 ns;
	CONSTANT TIME_DELAY_DATA									: TIME			:= 120 ns;

	-- Timing table ID
	CONSTANT TTID_BUSENABLE_LOW								: NATURAL		:= 0;
	CONSTANT TTID_BUSENABLE_HIGH							: NATURAL		:= 1;
	CONSTANT TTID_SETUP_REGSEL								: NATURAL		:= 2;
	CONSTANT TTID_SETUP_DATA									: NATURAL		:= 3;
	CONSTANT TTID_HOLD_REGSEL									: NATURAL		:= 4;
	CONSTANT TTID_HOLD_DATA										: NATURAL		:= 5;
	CONSTANT TTID_VALID_DATA									: NATURAL		:= 6;
	CONSTANT TTID_DELAY_DATA									: NATURAL		:= 7;

	-- Timing table
	CONSTANT TIMING_TABLE											: T_NATVEC	:= (
		TTID_BUSENABLE_LOW	=> TimingToCycles(TIME_BUSENABLE_LOW,		CLOCK_FREQ),
		TTID_BUSENABLE_HIGH	=> TimingToCycles(TIME_BUSENABLE_HIGH,	CLOCK_FREQ),
		TTID_SETUP_REGSEL		=> TimingToCycles(TIME_SETUP_REGSEL,		CLOCK_FREQ),
		TTID_SETUP_DATA			=> TimingToCycles(TIME_SETUP_DATA,			CLOCK_FREQ),
		TTID_HOLD_REGSEL		=> TimingToCycles(TIME_HOLD_REGSEL,			CLOCK_FREQ),
		TTID_HOLD_DATA			=> TimingToCycles(TIME_HOLD_DATA,				CLOCK_FREQ),
		TTID_VALID_DATA			=> TimingToCycles(TIME_VALID_DATA,			CLOCK_FREQ),
		TTID_DELAY_DATA			=> TimingToCycles(TIME_DELAY_DATA,			CLOCK_FREQ)
	);

	-- Bus TimingCounter (BusTC)
	SUBTYPE T_BUSTC_SLOT_INDEX								IS INTEGER RANGE 0 TO TIMING_TABLE'length - 1;

	SIGNAL BusTC_en														: STD_LOGIC;
	SIGNAL BusTC_Load													: STD_LOGIC;
	SIGNAL BusTC_Slot													: T_BUSTC_SLOT_INDEX;
	SIGNAL BusTC_Timeout											: STD_LOGIC;

	TYPE T_STATE IS (
		ST_RESET,
		ST_IDLE,
		ST_WRITE_UPPER_NIBBLE_SETUP_REGSEL,
			ST_WRITE_UPPER_NIBBLE_ENABLE_BUS,
			ST_WRITE_UPPER_NIBBLE_DISABLE_BUS,
			ST_WRITE_LOWER_NIBBLE_SETUP_REGSEL,
				ST_WRITE_LOWER_NIBBLE_ENABLE_BUS,
				ST_WRITE_LOWER_NIBBLE_DISABLE_BUS,
		ST_READ_UPPER_NIBBLE_SETUP_REGSEL,
			ST_READ_UPPER_NIBBLE_ENABLE_BUS,
			ST_READ_UPPER_NIBBLE_DISABLE_BUS,
			ST_READ_LOWER_NIBBLE_SETUP_REGSEL,
				ST_READ_LOWER_NIBBLE_ENABLE_BUS,
				ST_READ_LOWER_NIBBLE_DISABLE_BUS,
		ST_ERROR
	);

	SIGNAL State								: T_STATE						:= ST_IDLE;
	SIGNAL NextState						: T_STATE;

	SIGNAL Reg_RegisterAddress_en		: STD_LOGIC;
	SIGNAL Reg_RegisterAddress			: STD_LOGIC					:= '0';
	SIGNAL Reg_Data_Load						: STD_LOGIC;
	SIGNAL Reg_Data_en0							: STD_LOGIC;
	SIGNAL Reg_Data_en1							: STD_LOGIC;
	SIGNAL Reg_Data									: T_SLV_8						:= (OTHERS => '0');

BEGIN
	ASSERT ((LCD_BUS_BITS = 4) OR (LCD_BUS_BITS = 8)) REPORT "LCD_BUS_WIDTH is out of range {4,8}" SEVERITY FAILURE;


	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_RESET;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Command)
	BEGIN
		NextState								<= State;

		Status									<= IO_LCDBUS_STATUS_IDLE;

		Reg_RegisterAddress_en	<= '0';
		Reg_Data_Load						<= '0';
		Reg_Data_en0						<= '0';
		Reg_Data_en1						<= '0';

		LCD_BusEnable						<= '0';
		LCD_ReadWrite						<= '0';
		LCD_RegisterSelect			<= '0';
		LCD_Data_o							<= (OTHERS => '0');
		LCD_Data_t							<= (OTHERS => '1');

		CASE State IS
			WHEN ST_RESET =>
				Status							<= IO_LCDBUS_STATUS_RESETTING;

				NextState						<= ST_IDLE;

			WHEN ST_IDLE =>
				CASE Command IS
					WHEN IO_LCDBUS_CMD_NONE =>
						NULL;

					WHEN IO_LCDBUS_CMD_WRITE =>
						Reg_RegisterAddress_en	<= '1';
						Reg_Data_Load						<= '1';

						BusTC_Load							<= '1';
						BusTC_Slot							<= TTID_SETUP_REGSEL;

						NextState								<= ST_WRITE_SETUP_REGSEL;

					WHEN IO_LCDBUS_CMD_READ =>
						Reg_RegisterAddress_en	<= '1';

						BusTC_Load							<= '1';
						BusTC_Slot							<= TTID_SETUP_REGSEL;

						NextState								<= ST_READ_SETUP_REGSEL;

					WHEN OTHERS =>
						NextState								<= ST_ERROR;
				END CASE;

			-- =======================================================================
			WHEN ST_WRITE_UPPER_NIBBLE_SETUP_REGSEL =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				IF (BusTC_Timeout = '1') THEN
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_WRITE_UPPER_NIBBLE_ENABLE_BUS;
				END IF;

			WHEN ST_WRITE_UPPER_NIBBLE_ENABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_BusEnable				<= '1';
				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				IF (BusTC_Timeout = '1') THEN
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_WRITE_UPPER_NIBBLE_DISABLE_BUS;
				END IF;

			WHEN ST_WRITE_UPPER_NIBBLE_DISABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				IF (BusTC_Timeout = '1') THEN
					IF (LCD_BUS_BITS = 4) THEN
						NextState				<= ST_WRITE_LOWER_NIBBLE_SETUP_REGSEL;
					ELSIF (LCD_BUS_BITS = 8) THEN
						Status					<= IO_LCDBUS_STATUS_WRITE_COMPLETE;

						NextState				<= ST_IDLE;
					ELSE
						NextState				<= ST_ERROR;
					END IF;
				END IF;

			WHEN ST_WRITE_LOWER_NIBBLE_SETUP_REGSEL =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_BUS_BITS - 1 DOWNTO 0);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				IF (BusTC_Timeout = '1') THEN
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_WRITE_LOWER_NIBBLE_ENABLE_BUS;
				END IF;

			WHEN ST_WRITE_LOWER_NIBBLE_ENABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_BusEnable				<= '1';
				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_BUS_BITS - 1 DOWNTO 0);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				IF (BusTC_Timeout = '1') THEN
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_WRITE_LOWER_NIBBLE_DISABLE_BUS;
				END IF;

			WHEN ST_WRITE_LOWER_NIBBLE_DISABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_BUS_BITS - 1 DOWNTO 0);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				IF (BusTC_Timeout = '1') THEN
					Status						<= IO_LCDBUS_STATUS_WRITE_COMPLETE;

					NextState					<= ST_IDLE;
				END IF;

			-- =======================================================================
			WHEN ST_READ_UPPER_NIBBLE_SETUP_REGSEL =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_t					<= (LCD_Data_t'range => '1');

				IF (BusTC_Timeout = '1') THEN
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_READ_UPPER_NIBBLE_ENABLE_BUS;
				END IF;

			WHEN ST_READ_UPPER_NIBBLE_ENABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_BusEnable				<= '1';
				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_t					<= (LCD_Data_t'range => '1');

				IF (BusTC_Timeout = '1') THEN
					Reg_Data_en1			<= '1';

					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_READ_UPPER_NIBBLE_DISABLE_BUS;
				END IF;

			WHEN ST_READ_UPPER_NIBBLE_DISABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_t					<= (LCD_Data_t'range => '1');

				IF (BusTC_Timeout = '1') THEN
					IF (LCD_BUS_BITS = 4) THEN
						NextState				<= ST_READ_LOWER_NIBBLE_SETUP_REGSEL;
					ELSIF (LCD_BUS_BITS = 8) THEN
						Status					<= IO_LCDBUS_STATUS_READ_COMPLETE;

						NextState				<= ST_IDLE;
					ELSE
						NextState				<= ST_ERROR;
					END IF;
				END IF;

			WHEN ST_READ_LOWER_NIBBLE_SETUP_REGSEL =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				IF (BusTC_Timeout = '1') THEN
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_READ_LOWER_NIBBLE_ENABLE_BUS;
				END IF;

			WHEN ST_READ_LOWER_NIBBLE_ENABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_BusEnable				<= '1';
				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				IF (BusTC_Timeout = '1') THEN
					Reg_Data_en0			<= '1';

					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_READ_LOWER_NIBBLE_DISABLE_BUS;
				END IF;

			WHEN ST_READ_LOWER_NIBBLE_DISABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				IF (BusTC_Timeout = '1') THEN
					Status						<= IO_LCDBUS_STATUS_READ_COMPLETE;

					NextState					<= ST_IDLE;
				END IF;

			WHEN ST_ERROR =>
				Status							<= IO_LCDBUS_STATUS_ERROR;

		END CASE;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				Reg_RegisterAddress										<= '0';
				Reg_Data															<= (OTHERS => '0');
			ELSE
				IF (Reg_RegisterAddress_en = '1') THEN
					Reg_RegisterAddress									<= RegisterAddress;
				END IF;

				IF (Reg_Data_Load = '1') THEN
					Reg_Data														<= DataIn;
				ELSIF (Reg_Data_en1 = '1') THEN
					Reg_Data(7 DOWNTO 8 - LCD_BUS_BITS)	<= LCD_Data_i;
				ELSIF (Reg_Data_en0 = '1') THEN
					Reg_Data(LCD_BUS_BITS DOWNTO 0)			<= LCD_Data_i;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	DataOut		<= Reg_Data;

	BusTC : ENTITY PoC.io_TimingCounter
		GENERIC MAP (
			TIMING_TABLE				=> TIMING_TABLE												-- timing table
		)
		PORT MAP (
			Clock								=> Clock,															-- clock
			Enable							=> BusTC_en,													-- enable counter
			Load								=> BusTC_Load,												-- load Timing Value from TIMING_TABLE selected by slot
			Slot								=> BusTC_Slot,												--
			Timeout							=> BusTC_Timeout											-- timing reached
		);
END;
