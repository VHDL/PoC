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

library	PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.io.all;
use			PoC.lcd.all;


entity lcd_LCDBusController is
	generic (
		SPEEDUP_SIMULATION				: boolean												:= TRUE;
		CLOCK_FREQ								: FREQ													:= 100 MHz;
		LCD_BUS_BITS							: positive											:= 4
	);
	port (
		Clock											: in	std_logic;
		Reset											: in	std_logic;

		Command										: in	T_IO_LCDBUS_COMMAND;
		Status										: out	T_IO_LCDBUS_STATUS;
		RegisterAddress						: in	std_logic;

		DataIn										: in	T_SLV_8;
		DataOut										: out	T_SLV_8;

		LCD_BusEnable							: out	std_logic;
		LCD_ReadWrite							: out	std_logic;
		LCD_RegisterSelect				: out	std_logic;
		LCD_Data_i								: in	std_logic_vector(7 downto (8 - LCD_BUS_BITS));
		LCD_Data_o								: out	std_logic_vector(7 downto (8 - LCD_BUS_BITS));
		LCD_Data_t								: out	std_logic_vector(7 downto (8 - LCD_BUS_BITS))
	);
end entity;


architecture rtl of lcd_LCDBusController is
	attribute KEEP														: boolean;
	attribute FSM_ENCODING										: string;

--	constant CLOCK_DUTY_CYCLE									: REAL			:= 0.50;		-- 50% high time
	constant TIME_BUSENABLE_HIGH							: time			:= 250 ns;		--Freq_kHz2Real_ns(LCD_BUS_FREQ_KHZ * 			CLOCK_DUTY_CYCLE);
	constant TIME_BUSENABLE_LOW								: time			:= 250 ns;		--Freq_kHz2Real_ns(LCD_BUS_FREQ_KHZ * (1 - CLOCK_DUTY_CYCLE));

	constant TIME_SETUP_REGSEL								: time			:= 40 ns;
	constant TIME_SETUP_DATA									: time			:= 80 ns;
	constant TIME_HOLD_REGSEL									: time			:= 10 ns;
	constant TIME_HOLD_DATA										: time			:= 10 ns;
	constant TIME_VALID_DATA									: time			:= 5 ns;
	constant TIME_DELAY_DATA									: time			:= 120 ns;

	-- Timing table ID
	constant TTID_BUSENABLE_LOW								: natural		:= 0;
	constant TTID_BUSENABLE_HIGH							: natural		:= 1;
	constant TTID_SETUP_REGSEL								: natural		:= 2;
	constant TTID_SETUP_DATA									: natural		:= 3;
	constant TTID_HOLD_REGSEL									: natural		:= 4;
	constant TTID_HOLD_DATA										: natural		:= 5;
	constant TTID_VALID_DATA									: natural		:= 6;
	constant TTID_DELAY_DATA									: natural		:= 7;

	-- Timing table
	constant TIMING_TABLE											: T_NATVEC	:= (
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
	subtype T_BUSTC_SLOT_INDEX								is integer range 0 to TIMING_TABLE'length - 1;

	signal BusTC_en														: std_logic;
	signal BusTC_Load													: std_logic;
	signal BusTC_Slot													: T_BUSTC_SLOT_INDEX;
	signal BusTC_Timeout											: std_logic;

	type T_STATE is (
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

	signal State								: T_STATE						:= ST_IDLE;
	signal NextState						: T_STATE;

	signal Reg_RegisterAddress_en		: std_logic;
	signal Reg_RegisterAddress			: std_logic					:= '0';
	signal Reg_Data_Load						: std_logic;
	signal Reg_Data_en0							: std_logic;
	signal Reg_Data_en1							: std_logic;
	signal Reg_Data									: T_SLV_8						:= (others => '0');

begin
	assert ((LCD_BUS_BITS = 4) or (LCD_BUS_BITS = 8)) report "LCD_BUS_WIDTH is out of range {4,8}" severity FAILURE;


	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State			<= ST_RESET;
			else
				State			<= NextState;
			end if;
		end if;
	end process;

	process(State, Command)
	begin
		NextState								<= State;

		Status									<= IO_LCDBUS_STATUS_IDLE;

		Reg_RegisterAddress_en	<= '0';
		Reg_Data_Load						<= '0';
		Reg_Data_en0						<= '0';
		Reg_Data_en1						<= '0';

		LCD_BusEnable						<= '0';
		LCD_ReadWrite						<= '0';
		LCD_RegisterSelect			<= '0';
		LCD_Data_o							<= (others => '0');
		LCD_Data_t							<= (others => '1');

		case State is
			when ST_RESET =>
				Status							<= IO_LCDBUS_STATUS_RESETTING;

				NextState						<= ST_IDLE;

			when ST_IDLE =>
				case Command is
					when IO_LCDBUS_CMD_NONE =>
						null;

					when IO_LCDBUS_CMD_WRITE =>
						Reg_RegisterAddress_en	<= '1';
						Reg_Data_Load						<= '1';

						BusTC_Load							<= '1';
						BusTC_Slot							<= TTID_SETUP_REGSEL;

						NextState								<= ST_WRITE_SETUP_REGSEL;

					when IO_LCDBUS_CMD_READ =>
						Reg_RegisterAddress_en	<= '1';

						BusTC_Load							<= '1';
						BusTC_Slot							<= TTID_SETUP_REGSEL;

						NextState								<= ST_READ_SETUP_REGSEL;

					when others =>
						NextState								<= ST_ERROR;
				end case;

			-- =======================================================================
			when ST_WRITE_UPPER_NIBBLE_SETUP_REGSEL =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				if (BusTC_Timeout = '1') then
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_WRITE_UPPER_NIBBLE_ENABLE_BUS;
				end if;

			when ST_WRITE_UPPER_NIBBLE_ENABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_BusEnable				<= '1';
				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				if (BusTC_Timeout = '1') then
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_WRITE_UPPER_NIBBLE_DISABLE_BUS;
				end if;

			when ST_WRITE_UPPER_NIBBLE_DISABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				if (BusTC_Timeout = '1') then
					if (LCD_BUS_BITS = 4) then
						NextState				<= ST_WRITE_LOWER_NIBBLE_SETUP_REGSEL;
					elsif (LCD_BUS_BITS = 8) then
						Status					<= IO_LCDBUS_STATUS_WRITE_COMPLETE;

						NextState				<= ST_IDLE;
					else
						NextState				<= ST_ERROR;
					end if;
				end if;

			when ST_WRITE_LOWER_NIBBLE_SETUP_REGSEL =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_BUS_BITS - 1 downto 0);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				if (BusTC_Timeout = '1') then
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_WRITE_LOWER_NIBBLE_ENABLE_BUS;
				end if;

			when ST_WRITE_LOWER_NIBBLE_ENABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_BusEnable				<= '1';
				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_BUS_BITS - 1 downto 0);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				if (BusTC_Timeout = '1') then
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_WRITE_LOWER_NIBBLE_DISABLE_BUS;
				end if;

			when ST_WRITE_LOWER_NIBBLE_DISABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_WRITING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '0';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_BUS_BITS - 1 downto 0);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				if (BusTC_Timeout = '1') then
					Status						<= IO_LCDBUS_STATUS_WRITE_COMPLETE;

					NextState					<= ST_IDLE;
				end if;

			-- =======================================================================
			when ST_READ_UPPER_NIBBLE_SETUP_REGSEL =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_t					<= (LCD_Data_t'range => '1');

				if (BusTC_Timeout = '1') then
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_READ_UPPER_NIBBLE_ENABLE_BUS;
				end if;

			when ST_READ_UPPER_NIBBLE_ENABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_BusEnable				<= '1';
				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_t					<= (LCD_Data_t'range => '1');

				if (BusTC_Timeout = '1') then
					Reg_Data_en1			<= '1';

					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_READ_UPPER_NIBBLE_DISABLE_BUS;
				end if;

			when ST_READ_UPPER_NIBBLE_DISABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_t					<= (LCD_Data_t'range => '1');

				if (BusTC_Timeout = '1') then
					if (LCD_BUS_BITS = 4) then
						NextState				<= ST_READ_LOWER_NIBBLE_SETUP_REGSEL;
					elsif (LCD_BUS_BITS = 8) then
						Status					<= IO_LCDBUS_STATUS_READ_COMPLETE;

						NextState				<= ST_IDLE;
					else
						NextState				<= ST_ERROR;
					end if;
				end if;

			when ST_READ_LOWER_NIBBLE_SETUP_REGSEL =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				if (BusTC_Timeout = '1') then
					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_READ_LOWER_NIBBLE_ENABLE_BUS;
				end if;

			when ST_READ_LOWER_NIBBLE_ENABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_BusEnable				<= '1';
				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				if (BusTC_Timeout = '1') then
					Reg_Data_en0			<= '1';

					BusTC_Load				<= '1';
					BusTC_Slot				<= TTID_BUSENABLE_HIGH;

					NextState					<= ST_READ_LOWER_NIBBLE_DISABLE_BUS;
				end if;

			when ST_READ_LOWER_NIBBLE_DISABLE_BUS =>
				Status							<= IO_LCDBUS_STATUS_READING;
				BusTC_en						<= '1';

				LCD_ReadWrite				<= '1';
				LCD_RegisterSelect	<= Reg_RegisterAddress;
				LCD_Data_o					<= Reg_Data(LCD_Data_o'range);
				LCD_Data_t					<= (LCD_Data_t'range => '0');

				if (BusTC_Timeout = '1') then
					Status						<= IO_LCDBUS_STATUS_READ_COMPLETE;

					NextState					<= ST_IDLE;
				end if;

			when ST_ERROR =>
				Status							<= IO_LCDBUS_STATUS_ERROR;

		end case;
	end process;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Reg_RegisterAddress										<= '0';
				Reg_Data															<= (others => '0');
			else
				if (Reg_RegisterAddress_en = '1') then
					Reg_RegisterAddress									<= RegisterAddress;
				end if;

				if (Reg_Data_Load = '1') then
					Reg_Data														<= DataIn;
				elsif (Reg_Data_en1 = '1') then
					Reg_Data(7 downto 8 - LCD_BUS_BITS)	<= LCD_Data_i;
				elsif (Reg_Data_en0 = '1') then
					Reg_Data(LCD_BUS_BITS downto 0)			<= LCD_Data_i;
				end if;
			end if;
		end if;
	end process;

	DataOut		<= Reg_Data;

	BusTC : entity PoC.io_TimingCounter
		generic map (
			TIMING_TABLE				=> TIMING_TABLE												-- timing table
		)
		port map (
			Clock								=> Clock,															-- clock
			Enable							=> BusTC_en,													-- enable counter
			Load								=> BusTC_Load,												-- load Timing Value from TIMING_TABLE selected by slot
			Slot								=> BusTC_Slot,												--
			Timeout							=> BusTC_Timeout											-- timing reached
		);
end;
