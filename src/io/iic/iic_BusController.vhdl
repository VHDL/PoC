-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:					I²C BusController (IICBusController)
-- 
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		The IICBusController transmitts bits over the I²C bus (SerialClock - SCL,
--		SerialData - SDA) and also receives them.	To send/receive words over the
--		I²C bus, use the IICController, which utilizes this controller. This
--		controller is compatible to the System Management Bus (SMBus).
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany,
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
--USE			PoC.strings.ALL;
--USE			PoC.vectors.ALL;
USE			PoC.physical.ALL;
USE			PoC.components.ALL;
USE			PoC.io.ALL;


ENTITY iic_IICBusController IS
	GENERIC (
		CLOCK_FREQ										: FREQ													:= 100.0 MHz;
--		CLOCK_FREQ_MHZ								: REAL													:= 100.0;														-- 100 MHz
		ADD_INPUT_SYNCHRONIZER				: BOOLEAN												:= FALSE;
		IIC_BUSMODE										: T_IO_IIC_BUSMODE							:= IO_IIC_BUSMODE_STANDARDMODE;			-- 100 kHz
		ALLOW_MEALY_TRANSITION				: BOOLEAN												:= TRUE
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		Request												: IN	STD_LOGIC;
		Grant													: OUT	STD_LOGIC;
		Command												: IN	T_IO_IICBUS_COMMAND;
		Status												: OUT	T_IO_IICBUS_STATUS;
	
		SerialClock_i									: IN	STD_LOGIC;
		SerialClock_o									: OUT	STD_LOGIC;
		SerialClock_t									: OUT	STD_LOGIC;
		SerialData_i									: IN	STD_LOGIC;
		SerialData_o									: OUT	STD_LOGIC;
		SerialData_t									: OUT	STD_LOGIC
	);
END ENTITY;

-- TODOs:
--	value read back and compare with written data => raise error, arbitration, multi-master?
--	multi-master support
--	receive START, RESTART, STOP
--	"clock stretching", clock synchronization
--	bus-state tracking / request/grant generation

ARCHITECTURE rtl OF iic_IICBusController IS
	ATTRIBUTE KEEP														: BOOLEAN;
	ATTRIBUTE FSM_ENCODING										: STRING;
	
	FUNCTION getSpikeSupressionTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 50.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 50.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 50.0 ns;		-- Changed to 50 ns; original value from NXP UM 10204: 0.0 ns
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 50.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 50.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 50.0 ns;
			WHEN OTHERS =>												RETURN 50.0 ns;
		END CASE;
	END FUNCTION;
	
	FUNCTION getBusFreeTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 500.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4700.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4700.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 1300.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 500.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0 ns;
			WHEN OTHERS =>												RETURN 0.0 ns;
		END CASE;
	END FUNCTION;
	
	FUNCTION getClockHighTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 260.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4000.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4000.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 600.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 260.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0 ns;
			WHEN OTHERS =>												RETURN 0.0 ns;
		END CASE;
	END FUNCTION;
	
	FUNCTION getClockLowTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 500.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4700.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4700.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 1300.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 500.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0 ns;
			WHEN OTHERS =>												RETURN 0.0 ns;
		END CASE;
	END FUNCTION;
	
	FUNCTION getSetupRepeatedStartTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 260.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4700.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4700.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 600.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 260.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0 ns;
			WHEN OTHERS =>												RETURN 0.0 ns;
		END CASE;
	END FUNCTION;

	FUNCTION getSetupStopTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 260.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4000.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4000.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 600.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 260.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0 ns;
			WHEN OTHERS =>												RETURN 0.0 ns;
		END CASE;
	END FUNCTION;
	
	FUNCTION getSetupDataTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 50.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 250.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 250.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 100.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 50.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0 ns;
			WHEN OTHERS =>												RETURN 0.0 ns;
		END CASE;
	END FUNCTION;
	
	FUNCTION getHoldDataTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 0.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 300.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 0.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 0.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 0.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0 ns;
			WHEN OTHERS =>												RETURN 0.0 ns;
		END CASE;
	END FUNCTION;

	FUNCTION getValidDataTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 450.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 0.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 3450.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 900.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 450.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0 ns;
			WHEN OTHERS =>												RETURN 0.0 ns;
		END CASE;
	END FUNCTION;
	
	FUNCTION getHoldClockAfterStartTime(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN TIME IS
	BEGIN
		IF SIMULATION THEN											RETURN 260.0 ns;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4000.0 ns;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4000.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 600.0 ns;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 260.0 ns;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0 ns;
			WHEN OTHERS =>												RETURN 0.0 ns;
		END CASE;
	END FUNCTION;
	
	-- Timing definitions
	CONSTANT TIME_SPIKE_SUPPRESSION						: TIME			:= getSpikeSupressionTime(IIC_BUSMODE);
	CONSTANT TIME_BUS_FREE										: TIME			:= getBusFreeTime(IIC_BUSMODE);
	CONSTANT TIME_CLOCK_HIGH									: TIME			:= getClockHighTime(IIC_BUSMODE);
	CONSTANT TIME_CLOCK_LOW										: TIME			:= getClockLowTime(IIC_BUSMODE);
	CONSTANT TIME_SETUP_REPEAT_START					: TIME			:= getSetupRepeatedStartTime(IIC_BUSMODE);
	CONSTANT TIME_SETUP_STOP									: TIME			:= getSetupStopTime(IIC_BUSMODE);
	CONSTANT TIME_SETUP_DATA									: TIME			:= getSetupDataTime(IIC_BUSMODE);
	CONSTANT TIME_HOLD_CLOCK_AFTER_START			: TIME			:= getHoldClockAfterStartTime(IIC_BUSMODE);
	CONSTANT TIME_HOLD_DATA										: TIME			:= getHoldDataTime(IIC_BUSMODE);
	CONSTANT TIME_VALID_DATA									: TIME			:= getValidDataTime(IIC_BUSMODE);

	-- Timing table ID
	CONSTANT TTID_BUS_FREE_TIME								: NATURAL		:= 0;
	CONSTANT TTID_HOLD_CLOCK_AFTER_START			: NATURAL		:= 1;
	CONSTANT TTID_CLOCK_LOW										: NATURAL		:= 2;
	CONSTANT TTID_CLOCK_HIGH									: NATURAL		:= 3;
	CONSTANT TTID_SETUP_REPEAT_START					: NATURAL		:= 4;
	CONSTANT TTID_SETUP_STOP									: NATURAL		:= 5;
	CONSTANT TTID_SETUP_DATA									: NATURAL		:= 6;
	
	-- Timing table
	CONSTANT TIMING_TABLE											: T_NATVEC	:= (
		TTID_BUS_FREE_TIME						=> TimingToCycles(TIME_BUS_FREE,								CLOCK_FREQ),
		TTID_HOLD_CLOCK_AFTER_START		=> TimingToCycles(TIME_HOLD_CLOCK_AFTER_START,	CLOCK_FREQ),
		TTID_CLOCK_LOW								=> TimingToCycles(TIME_CLOCK_LOW,								CLOCK_FREQ),
		TTID_CLOCK_HIGH								=> TimingToCycles(TIME_CLOCK_HIGH,							CLOCK_FREQ),
		TTID_SETUP_REPEAT_START				=> TimingToCycles(TIME_SETUP_REPEAT_START,			CLOCK_FREQ),
		TTID_SETUP_STOP								=> TimingToCycles(TIME_SETUP_STOP,							CLOCK_FREQ)
	);
	
	-- Bus TimingCounter (BusTC)
	SUBTYPE T_BUSTC_SLOT_INDEX								IS INTEGER RANGE 0 TO TIMING_TABLE'length - 1;
	
	CONSTANT SMBUS_COMPLIANCE									: BOOLEAN				:= (IIC_BUSMODE = IO_IIC_BUSMODE_SMBUS);
	
	SIGNAL BusTC_en														: STD_LOGIC;
	SIGNAL BusTC_Load													: STD_LOGIC;
	SIGNAL BusTC_Slot													: T_BUSTC_SLOT_INDEX;
	SIGNAL BusTC_Timeout											: STD_LOGIC;
	
	TYPE T_STATE IS (
		ST_RESET,
		ST_IDLE,
			ST_WAIT_BUS_FREE,
			ST_SEND_START_WAIT_BUS_FREE,
			ST_SEND_START,
				ST_SEND_START_WAIT_HOLD_CLOCK_AFTER_START,
			ST_SEND_RESTART_PULLDOWN_CLOCK,
				ST_SEND_RESTART_PULLDOWN_CLOCK_WAIT,
				ST_SEND_RESTART_RELEASE_CLOCK,
				ST_SEND_RESTART_CLOCK_RELEASED,
				ST_SEND_RESTART_CLOCK_HIGH_WAIT,
				ST_SEND_RESTART_PULLDOWN_DATA,
				ST_SEND_RESTART_WAIT_HOLD_CLOCK_AFTER_RESTART,
			ST_SEND_STOP_PULLDOWN_CLOCK,
				ST_SEND_STOP_PULLDOWN_CLOCK_WAIT,
				ST_SEND_STOP_RELEASE_CLOCK,
				ST_SEND_STOP_CLOCK_RELEASED,
				ST_SEND_STOP_CLOCK_HIGH_WAIT,
				ST_SEND_STOP_RELEASE_DATA,
			ST_SEND_HIGH_PULLDOWN_CLOCK,
				ST_SEND_HIGH_PULLDOWN_CLOCK_WAIT,
				ST_SEND_HIGH_RELEASE_CLOCK,
				ST_SEND_HIGH_CLOCK_RELEASED,
				ST_SEND_HIGH_CLOCK_HIGH_WAIT,
				ST_SEND_HIGH_READBACK_DATA,
			ST_SEND_LOW_PULLDOWN_CLOCK,
				ST_SEND_LOW_PULLDOWN_CLOCK_WAIT,
				ST_SEND_LOW_RELEASE_CLOCK,
				ST_SEND_LOW_CLOCK_RELEASED,
				ST_SEND_LOW_CLOCK_HIGH_WAIT,
				ST_SEND_LOW_READBACK_DATA,
		ST_SEND_COMPLETE,
			ST_RECEIVE_0,				ST_RECEIVE_1,				ST_RECEIVE_2,				ST_RECEIVE_3,
		ST_RECEIVE_COMPLETE,
		ST_ERROR,
			ST_BUS_ERROR
	);
	
	SIGNAL State												: T_STATE										:= ST_RESET;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS "gray";
	
	SIGNAL SerialClock_t_r_set					: STD_LOGIC;
	SIGNAL SerialClock_t_r_rst					: STD_LOGIC;
	SIGNAL SerialData_t_r_set						: STD_LOGIC;
	SIGNAL SerialData_t_r_rst						: STD_LOGIC;
	
	SIGNAL Status_en										: STD_LOGIC;
	SIGNAL Status_nxt										: T_IO_IICBUS_STATUS;
	SIGNAL Status_d											: T_IO_IICBUS_STATUS				:= IO_IICBUS_STATUS_ERROR;
	
	SIGNAL SerialClock_raw							: STD_LOGIC;
	SIGNAL SerialClockIn								: STD_LOGIC;
	SIGNAL SerialClock_o_r							: STD_LOGIC									:= '0';
	SIGNAL SerialClock_t_r							: STD_LOGIC									:= '1';

	SIGNAL SerialData_raw								: STD_LOGIC;
	SIGNAL SerialDataIn									: STD_LOGIC;
	SIGNAL SerialData_o_r								: STD_LOGIC									:= '0';
	SIGNAL SerialData_t_r								: STD_LOGIC									:= '1';

	ATTRIBUTE KEEP OF SerialClockIn								: SIGNAL IS TRUE;
	ATTRIBUTE KEEP OF SerialDataIn								: SIGNAL IS TRUE;
	
BEGIN

	genSync0 : IF (ADD_INPUT_SYNCHRONIZER = FALSE) GENERATE
		SerialClock_raw		<= SerialClock_i;
		SerialData_raw		<= SerialData_i;
	END GENERATE;
	genSync1 : IF (ADD_INPUT_SYNCHRONIZER = TRUE) GENERATE
		sync : ENTITY PoC.sync_Flag
			GENERIC MAP (
				BITS			=> 2
			)
			PORT MAP (
				Clock			=> Clock,							-- Clock to be synchronized to
				Input(0)	=> SerialClock_i,			-- Data to be synchronized
				Input(1)	=> SerialData_i,			-- Data to be synchronized
				Output(0)	=> SerialClock_raw,		-- synchronised data
				Output(1)	=> SerialData_raw			-- synchronised data
			);
	END GENERATE;

	-- Output D-FFs
	SerialClock_o			<= '0';
	SerialClock_t			<= SerialClock_t_r		WHEN rising_edge(Clock);
	
	SerialData_o			<= '0';
	SerialData_t			<= SerialData_t_r			WHEN rising_edge(Clock);

	genSpikeSupp0 : IF (TIME_SPIKE_SUPPRESSION <= to_time(CLOCK_FREQ)) GENERATE
		SerialClockIn	<= SerialClock_raw;
		SerialDataIn	<= SerialData_raw;
	END GENERATE;
	genSpikeSupp1 : IF (TIME_SPIKE_SUPPRESSION > to_time(CLOCK_FREQ)) GENERATE
		CONSTANT SPIKE_SUPPRESSION_CYCLES		: NATURAL := TimingToCycles(TIME_SPIKE_SUPPRESSION, CLOCK_FREQ);
	BEGIN
		SerialClockGF : ENTITY PoC.io_GlitchFilter
			GENERIC MAP (
				HIGH_SPIKE_SUPPRESSION_CYCLES		=> SPIKE_SUPPRESSION_CYCLES,
				LOW_SPIKE_SUPPRESSION_CYCLES		=> SPIKE_SUPPRESSION_CYCLES
			)
			PORT MAP (
				Clock		=> Clock,
				Input		=> SerialClock_raw,
				Output	=> SerialClockIn
			);
			
		SerialDataGF : ENTITY PoC.io_GlitchFilter
			GENERIC MAP (
				HIGH_SPIKE_SUPPRESSION_CYCLES		=> SPIKE_SUPPRESSION_CYCLES,
				LOW_SPIKE_SUPPRESSION_CYCLES		=> SPIKE_SUPPRESSION_CYCLES
			)
			PORT MAP (
				Clock		=> Clock,
				Input		=> SerialData_raw,
				Output	=> SerialDataIn
			);
	END GENERATE;
	
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

	PROCESS(State, Request, Command, Status_d, SerialClockIn, SerialDataIn, BusTC_Timeout)
	BEGIN
		NextState									<= State;

		Grant											<= '0';
		Status_en									<= '0';
		Status_nxt								<= IO_IICBUS_STATUS_IDLE;
		Status										<= IO_IICBUS_STATUS_IDLE;

		SerialClock_t_r_set				<= '0';
		SerialClock_t_r_rst				<= '0';
		SerialData_t_r_set				<= '0';
		SerialData_t_r_rst				<= '0';
				
		BusTC_en									<= '0';
		BusTC_Load								<= '0';
		BusTC_Slot								<= 0;
		
		CASE State IS
			WHEN ST_RESET =>
				Status								<= IO_IICBUS_STATUS_RESETING;
				BusTC_Load						<= '1';
				BusTC_Slot						<= TTID_BUS_FREE_TIME;
				
				NextState							<= ST_WAIT_BUS_FREE;
				
			WHEN ST_WAIT_BUS_FREE =>
				Status								<= IO_IICBUS_STATUS_RESETING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_IDLE;
				END IF;
			
			WHEN ST_IDLE =>
				Status								<= IO_IICBUS_STATUS_IDLE;
				Grant									<= Request;
				
				BusTC_en							<= '1';				-- run counter for BusFreeTime
				
				-- test for busmode
				--	idle			=> allow start condition
				--	notfree		=> wait until free => and start
				--	slave			=> receive
				--	master		=> low, high, restart, stop, receive
				
				CASE Command IS
					WHEN IO_IICBUS_CMD_NONE =>											NULL;
					WHEN IO_IICBUS_CMD_SEND_START_CONDITION =>			NextState		<= ST_SEND_START_WAIT_BUS_FREE;
					WHEN IO_IICBUS_CMD_SEND_RESTART_CONDITION =>		NextState		<= ST_SEND_RESTART_PULLDOWN_CLOCK;
					WHEN IO_IICBUS_CMD_SEND_STOP_CONDITION =>				NextState		<= ST_SEND_STOP_PULLDOWN_CLOCK;
					WHEN IO_IICBUS_CMD_SEND_LOW =>									NextState		<= ST_SEND_LOW_PULLDOWN_CLOCK;
					WHEN IO_IICBUS_CMD_SEND_HIGH =>									NextState		<= ST_SEND_HIGH_PULLDOWN_CLOCK;
					WHEN IO_IICBUS_CMD_RECEIVE =>										NextState		<= ST_RECEIVE_0;
					WHEN OTHERS =>																	NextState		<= ST_ERROR;
				END CASE;
			
			WHEN ST_SEND_START_WAIT_BUS_FREE =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_START;
				END IF;
			
			WHEN ST_SEND_START =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialData_t_r_rst		<= '1';													-- disable data-tristate => data = 0
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_HOLD_CLOCK_AFTER_START;
				
				NextState							<= ST_SEND_START_WAIT_HOLD_CLOCK_AFTER_START;
			
			WHEN ST_SEND_START_WAIT_HOLD_CLOCK_AFTER_START =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
--					SerialClock_t_r_rst	<= '1';													-- disable clock-tristate => clock = 0
					
					NextState						<= ST_SEND_COMPLETE;
				END IF;
			
			WHEN ST_SEND_RESTART_PULLDOWN_CLOCK =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_rst		<= '1';													-- disable clock-tristate => clock = 0
				SerialData_t_r_set		<= '1';													-- enable data-tristate => data = 1
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_LOW;
				
				NextState							<= ST_SEND_RESTART_PULLDOWN_CLOCK_WAIT;
			
			WHEN ST_SEND_RESTART_PULLDOWN_CLOCK_WAIT =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_RESTART_RELEASE_CLOCK;
				END IF;
			
			WHEN ST_SEND_RESTART_RELEASE_CLOCK =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_set		<= '1';													-- enable clock-tristate => clock = 1
				
				IF (SerialClockIn = '1') THEN
					NextState						<= ST_SEND_RESTART_CLOCK_RELEASED;
				END IF;
			
			WHEN ST_SEND_RESTART_CLOCK_RELEASED =>
				Status								<= IO_IICBUS_STATUS_SENDING;
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_SETUP_REPEAT_START;
				
				NextState							<= ST_SEND_RESTART_CLOCK_HIGH_WAIT;
				
			WHEN ST_SEND_RESTART_CLOCK_HIGH_WAIT =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_RESTART_PULLDOWN_DATA;
				END IF;
			
			WHEN ST_SEND_RESTART_PULLDOWN_DATA =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialData_t_r_rst		<= '1';													-- disable data-tristate => data = 0
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_HOLD_CLOCK_AFTER_START;
				
				NextState							<= ST_SEND_RESTART_WAIT_HOLD_CLOCK_AFTER_RESTART;
			
			WHEN ST_SEND_RESTART_WAIT_HOLD_CLOCK_AFTER_RESTART =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
--					SerialClock_t_r_rst	<= '1';													-- disable clock-tristate => clock = 0
					
					NextState						<= ST_SEND_COMPLETE;
				END IF;
			
			WHEN ST_SEND_STOP_PULLDOWN_CLOCK =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_rst		<= '1';													-- disable clock-tristate => clock = 0
				SerialData_t_r_rst		<= '1';													-- disable data-tristate => data = 0
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_LOW;
				
				NextState							<= ST_SEND_STOP_PULLDOWN_CLOCK_WAIT;
			
			WHEN ST_SEND_STOP_PULLDOWN_CLOCK_WAIT =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_STOP_RELEASE_CLOCK;
				END IF;
			
			WHEN ST_SEND_STOP_RELEASE_CLOCK =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_set		<= '1';													-- enable clock-tristate => clock = 1
				
				IF (SerialClockIn = '1') THEN
					NextState						<= ST_SEND_STOP_CLOCK_RELEASED;
				END IF;
			
			WHEN ST_SEND_STOP_CLOCK_RELEASED =>
				Status								<= IO_IICBUS_STATUS_SENDING;
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_SETUP_STOP;
				
				NextState							<= ST_SEND_STOP_CLOCK_HIGH_WAIT;
				
			WHEN ST_SEND_STOP_CLOCK_HIGH_WAIT =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_STOP_RELEASE_DATA;
				END IF;
			
			WHEN ST_SEND_STOP_RELEASE_DATA =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialData_t_r_set		<= '1';													-- enable data-tristate => data = 1
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_BUS_FREE_TIME;
				
				NextState							<= ST_SEND_COMPLETE;
			
			WHEN ST_SEND_HIGH_PULLDOWN_CLOCK =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_rst		<= '1';													-- disable clock-tristate => clock = 0
				SerialData_t_r_set		<= '1';													-- enable data-tristate => data = 1
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_LOW;
				
				NextState							<= ST_SEND_HIGH_PULLDOWN_CLOCK_WAIT;
			
			WHEN ST_SEND_HIGH_PULLDOWN_CLOCK_WAIT =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_HIGH_RELEASE_CLOCK;
				END IF;
			
			WHEN ST_SEND_HIGH_RELEASE_CLOCK =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_set		<= '1';													-- enable clock-tristate => clock = 1
				
				IF (SerialClockIn = '1') THEN
					NextState						<= ST_SEND_HIGH_CLOCK_RELEASED;
				END IF;
			
			WHEN ST_SEND_HIGH_CLOCK_RELEASED =>
				Status								<= IO_IICBUS_STATUS_SENDING;
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_HIGH;
				
				NextState							<= ST_SEND_HIGH_CLOCK_HIGH_WAIT;
				
			WHEN ST_SEND_HIGH_CLOCK_HIGH_WAIT =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_HIGH_READBACK_DATA;
				END IF;
			
			WHEN ST_SEND_HIGH_READBACK_DATA =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				
				IF (SerialDataIn = '1') THEN
					NextState						<= ST_SEND_COMPLETE;
				ELSE
					NextState						<= ST_BUS_ERROR;
				END IF;
			
			WHEN ST_SEND_LOW_PULLDOWN_CLOCK =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_rst		<= '1';													-- disable clock-tristate => clock = 0
				SerialData_t_r_rst		<= '1';													-- disable data-tristate => data = 0
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_LOW;
				
				NextState							<= ST_SEND_LOW_PULLDOWN_CLOCK_WAIT;
			
			WHEN ST_SEND_LOW_PULLDOWN_CLOCK_WAIT =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_LOW_RELEASE_CLOCK;
				END IF;
			
			WHEN ST_SEND_LOW_RELEASE_CLOCK =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_set		<= '1';													-- enable clock-tristate => clock = 1
				
				IF (SerialClockIn = '1') THEN
					NextState						<= ST_SEND_LOW_CLOCK_RELEASED;
				END IF;
			
			WHEN ST_SEND_LOW_CLOCK_RELEASED =>
				Status								<= IO_IICBUS_STATUS_SENDING;
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_HIGH;
				
				NextState							<= ST_SEND_LOW_CLOCK_HIGH_WAIT;
				
			WHEN ST_SEND_LOW_CLOCK_HIGH_WAIT =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_LOW_READBACK_DATA;
				END IF;
			
			WHEN ST_SEND_LOW_READBACK_DATA =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				
				IF (SerialDataIn = '0') THEN
					NextState						<= ST_SEND_COMPLETE;
				ELSE
					NextState						<= ST_BUS_ERROR;
				END IF;
			
			WHEN ST_SEND_COMPLETE =>
				Status								<= IO_IICBUS_STATUS_SEND_COMPLETE;
				BusTC_en							<= '1';
				
				NextState							<= ST_IDLE;
			
			WHEN ST_RECEIVE_0 =>
				Status								<= IO_IICBUS_STATUS_RECEIVING;
				SerialClock_t_r_rst		<= '1';													-- disable clock-tristate => clock = 0
				SerialData_t_r_set		<= '1';													-- enable data-tristate => data = Z
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_LOW;
				
				NextState							<= ST_RECEIVE_1;
				
			WHEN ST_RECEIVE_1 =>
				Status								<= IO_IICBUS_STATUS_RECEIVING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_RECEIVE_2;
				END IF;
			
			WHEN ST_RECEIVE_2 =>
				Status								<= IO_IICBUS_STATUS_RECEIVING;
				Status_en							<= '1';
				
				SerialClock_t_r_set		<= '1';													-- disable clock-tristate => clock = 1
			
				IF (SerialDataIn = '0') THEN
--					Status_nxt					<= IO_IICBUS_STATUS_RECEIVED_LOW;
				ELSIF (SerialDataIn = ite(SIMULATION, 'H', '1')) THEN
--					Status_nxt					<= IO_IICBUS_STATUS_RECEIVED_HIGH;
				ELSE
--					Status_nxt					<= IO_IICBUS_STATUS_ERROR;
				END IF;
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_HIGH;
				
				NextState							<= ST_RECEIVE_3;
			
			WHEN ST_RECEIVE_3 =>
				Status								<= IO_IICBUS_STATUS_RECEIVING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_RECEIVE_COMPLETE;
				END IF;
			
			WHEN ST_RECEIVE_COMPLETE =>
				Status								<= Status_d;
				NextState							<= ST_IDLE;
			
			WHEN ST_ERROR =>
				Status								<= IO_IICBUS_STATUS_ERROR;
				NextState							<= ST_IDLE;
			
			WHEN ST_BUS_ERROR =>
				Status								<= IO_IICBUS_STATUS_BUS_ERROR;
				NextState							<= ST_IDLE;
			
			WHEN OTHERS =>
				Status								<= IO_IICBUS_STATUS_ERROR;
				NextState							<= ST_IDLE;
				
		END CASE;
	END PROCESS;
	
	--										RS-FF			q							rst										set
	SerialClock_t_r		<= ffrs(SerialClock_t_r,	SerialClock_t_r_rst,	(Reset OR SerialClock_t_r_set))	WHEN rising_edge(Clock);
	SerialData_t_r		<= ffrs(SerialData_t_r,		SerialData_t_r_rst,		(Reset OR SerialData_t_r_set))	WHEN rising_edge(Clock);

	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				Status_d			<= IO_IICBUS_STATUS_ERROR;
			ELSE
				IF (Status_en = '1') THEN
					Status_d		<= Status_nxt;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
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
