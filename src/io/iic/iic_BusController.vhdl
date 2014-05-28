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
USE			PoC.components.ALL;
USE			PoC.io.ALL;


ENTITY iic_IICBusController IS
	GENERIC (
		CLOCK_FREQ_MHZ								: REAL													:= 100.0;														-- 100 MHz
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
	ATTRIBUTE ASYNC_REG												: STRING;
	ATTRIBUTE SHREG_EXTRACT										: STRING;
	ATTRIBUTE FSM_ENCODING										: STRING;
	
	FUNCTION getSpikeSupressionTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 50.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 50.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 50.0;		-- Changed to 50 ns; original value from NXP UM 10204: 0.0 ns
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 50.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 50.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 50.0;
			WHEN OTHERS =>												RETURN 50.0;
		END CASE;
	END FUNCTION;
	
	FUNCTION getBusFreeTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 500.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4700.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4700.0;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 1300.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 500.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0;
			WHEN OTHERS =>												RETURN 0.0;
		END CASE;
	END FUNCTION;
	
	FUNCTION getClockHighTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 260.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4000.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4000.0;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 600.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 260.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0;
			WHEN OTHERS =>												RETURN 0.0;
		END CASE;
	END FUNCTION;
	
	FUNCTION getClockLowTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 500.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4700.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4700.0;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 1300.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 500.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0;
			WHEN OTHERS =>												RETURN 0.0;
		END CASE;
	END FUNCTION;
	
	FUNCTION getSetupRepeatedStartTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 260.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4700.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4700.0;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 600.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 260.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0;
			WHEN OTHERS =>												RETURN 0.0;
		END CASE;
	END FUNCTION;

	FUNCTION getSetupStopTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 260.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4000.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4000.0;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 600.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 260.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0;
			WHEN OTHERS =>												RETURN 0.0;
		END CASE;
	END FUNCTION;
	
	FUNCTION getSetupDataTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 50.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 250.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 250.0;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 100.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 50.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0;
			WHEN OTHERS =>												RETURN 0.0;
		END CASE;
	END FUNCTION;
	
	FUNCTION getHoldDataTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 0.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 300.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 0.0;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 0.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 0.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0;
			WHEN OTHERS =>												RETURN 0.0;
		END CASE;
	END FUNCTION;

	FUNCTION getValidDataTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 450.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 0.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 3450.0;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 900.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 450.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0;
			WHEN OTHERS =>												RETURN 0.0;
		END CASE;
	END FUNCTION;
	
	FUNCTION getHoldClockAfterStartTime_ns(IIC_BUSMODE : T_IO_IIC_BUSMODE) RETURN REAL IS
	BEGIN
		IF SIMULATION THEN											RETURN 260.0;	END IF;
		CASE IIC_BUSMODE IS
			WHEN IO_IIC_BUSMODE_SMBUS =>					RETURN 4000.0;
			WHEN IO_IIC_BUSMODE_STANDARDMODE =>		RETURN 4000.0;
			WHEN IO_IIC_BUSMODE_FASTMODE =>				RETURN 600.0;
			WHEN IO_IIC_BUSMODE_FASTMODEPLUS =>		RETURN 260.0;
			WHEN IO_IIC_BUSMODE_HIGHSPEEDMODE =>	RETURN 0.0;
			WHEN OTHERS =>												RETURN 0.0;
		END CASE;
	END FUNCTION;
	
	-- Timing definitions
	CONSTANT TIME_SPIKE_SUPPRESSION_NS				: REAL			:= getSpikeSupressionTime_ns(IIC_BUSMODE);
	CONSTANT TIME_BUS_FREE_NS									: REAL			:= getBusFreeTime_ns(IIC_BUSMODE);
	CONSTANT TIME_CLOCK_HIGH_NS								: REAL			:= getClockHighTime_ns(IIC_BUSMODE);
	CONSTANT TIME_CLOCK_LOW_NS								: REAL			:= getClockLowTime_ns(IIC_BUSMODE);
	CONSTANT TIME_SETUP_REPEAT_START_NS				: REAL			:= getSetupRepeatedStartTime_ns(IIC_BUSMODE);
	CONSTANT TIME_SETUP_STOP_NS								: REAL			:= getSetupStopTime_ns(IIC_BUSMODE);
	CONSTANT TIME_SETUP_DATA_NS								: REAL			:= getSetupDataTime_ns(IIC_BUSMODE);
	CONSTANT TIME_HOLD_CLOCK_AFTER_START_NS		: REAL			:= getHoldClockAfterStartTime_ns(IIC_BUSMODE);
	CONSTANT TIME_HOLD_DATA_NS								: REAL			:= getHoldDataTime_ns(IIC_BUSMODE);
	CONSTANT TIME_VALID_DATA_NS								: REAL			:= getValidDataTime_ns(IIC_BUSMODE);
	
	-- Timing table ID
	CONSTANT TTID_BUS_FREE_TIME								: NATURAL		:= 0;
	CONSTANT TTID_HOLD_CLOCK_AFTER_START			: NATURAL		:= 1;
	CONSTANT TTID_CLOCK_LOW										: NATURAL		:= 2;
	CONSTANT TTID_CLOCK_HIGH									: NATURAL		:= 3;
	CONSTANT TTID_SETUP_REPEAT_START					: NATURAL		:= 4;
	CONSTANT TTID_SETUP_STOP									: NATURAL		:= 5;
	
	-- Timing table
	CONSTANT TIMING_TABLE											: T_NATVEC	:= (
		TTID_BUS_FREE_TIME						=> TimingToCycles_ns(TIME_BUS_FREE_NS,								Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_HOLD_CLOCK_AFTER_START		=> TimingToCycles_ns(TIME_HOLD_CLOCK_AFTER_START_NS,	Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_CLOCK_LOW								=> TimingToCycles_ns(TIME_CLOCK_LOW_NS,								Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_CLOCK_HIGH								=> TimingToCycles_ns(TIME_CLOCK_HIGH_NS,							Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_SETUP_REPEAT_START				=> TimingToCycles_ns(TIME_SETUP_REPEAT_START_NS,			Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_SETUP_STOP								=> TimingToCycles_ns(TIME_SETUP_STOP_NS,							Freq_MHz2Real_ns(CLOCK_FREQ_MHZ))
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
			ST_SEND_START_WAIT_BUS_FREE,		ST_SEND_START,		ST_SEND_START_WAIT_HOLD_CLOCK_AFTER_START,
			ST_SEND_RESTART_0,	ST_SEND_RESTART_1,	ST_SEND_RESTART_2,	ST_SEND_RESTART_3,	ST_SEND_RESTART_4,	ST_SEND_RESTART_5,
			ST_SEND_STOP_0,			ST_SEND_STOP_1,			ST_SEND_STOP_2,			ST_SEND_STOP_3,			ST_SEND_STOP_4,			ST_SEND_STOP_5,
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
	
	SIGNAL SerialClock_async						: STD_LOGIC									:= '0';
	SIGNAL SerialClock_sync							: STD_LOGIC									:= '0';
	SIGNAL SerialClockIn								: STD_LOGIC									:= '0';
	SIGNAL SerialClock_o_r							: STD_LOGIC									:= '0';
	SIGNAL SerialClock_t_r							: STD_LOGIC									:= '1';
	
	SIGNAL SerialData_async							: STD_LOGIC									:= '0';
	SIGNAL SerialData_sync							: STD_LOGIC									:= '0';
	SIGNAL SerialDataIn									: STD_LOGIC									:= '0';
	SIGNAL SerialData_o_r								: STD_LOGIC									:= '0';
	SIGNAL SerialData_t_r								: STD_LOGIC									:= '1';

	-- Mark register "Serial***_async" as asynchronous
	ATTRIBUTE ASYNC_REG OF SerialClock_async			: SIGNAL IS "TRUE";
	ATTRIBUTE ASYNC_REG OF SerialData_async				: SIGNAL IS "TRUE";

	-- Prevent XST from translating two FFs into SRL plus FF
	ATTRIBUTE SHREG_EXTRACT OF SerialClock_async	: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF SerialClock_sync		: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF SerialData_async		: SIGNAL IS "NO";
	ATTRIBUTE SHREG_EXTRACT OF SerialData_sync		: SIGNAL IS "NO";
	
	ATTRIBUTE KEEP OF SerialClockIn								: SIGNAL IS TRUE;
	ATTRIBUTE KEEP OF SerialDataIn								: SIGNAL IS TRUE;
	
BEGIN
	SerialClock_async	<= SerialClock_i			WHEN rising_edge(Clock);
	SerialClock_sync	<= SerialClock_async	WHEN rising_edge(Clock);
	SerialClock_o			<= '0';
	SerialClock_t			<= SerialClock_t_r		WHEN rising_edge(Clock);
	
	SerialData_async	<= SerialData_i				WHEN rising_edge(Clock);
	SerialData_sync		<= SerialData_async		WHEN rising_edge(Clock);
	SerialData_o			<= '0';
	SerialData_t			<= SerialData_t_r			WHEN rising_edge(Clock);

	SerialClockGF : ENTITY PoC.io_GlitchFilter
		GENERIC MAP (
			CLOCK_FREQ_MHZ										=> CLOCK_FREQ_MHZ,
			HIGH_SPIKE_SUPPRESSION_TIME_NS		=> TIME_SPIKE_SUPPRESSION_NS,
			LOW_SPIKE_SUPPRESSION_TIME_NS			=> TIME_SPIKE_SUPPRESSION_NS
		)
		PORT MAP (
			Clock		=> Clock,
			I				=> SerialClock_sync,
			O				=> SerialClockIn
		);
		
	SerialDataGF : ENTITY PoC.io_GlitchFilter
		GENERIC MAP (
			CLOCK_FREQ_MHZ										=> CLOCK_FREQ_MHZ,
			HIGH_SPIKE_SUPPRESSION_TIME_NS		=> TIME_SPIKE_SUPPRESSION_NS,
			LOW_SPIKE_SUPPRESSION_TIME_NS			=> TIME_SPIKE_SUPPRESSION_NS
		)
		PORT MAP (
			Clock		=> Clock,
			I				=> SerialData_sync,
			O				=> SerialDataIn
		);

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
		Status										<= IO_IICBUS_STATUS_RESETING;

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
				
				CASE Command IS
					WHEN IO_IICBUS_CMD_NONE =>											NULL;
					WHEN IO_IICBUS_CMD_SEND_START_CONDITION =>			NextState		<= ST_SEND_START_WAIT_BUS_FREE;
					WHEN IO_IICBUS_CMD_SEND_RESTART_CONDITION =>		NextState		<= ST_SEND_RESTART_0;
					WHEN IO_IICBUS_CMD_SEND_STOP_CONDITION =>				NextState		<= ST_SEND_STOP_0;
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
					SerialClock_t_r_rst	<= '1';													-- disable clock-tristate => clock = 0
					
					NextState						<= ST_SEND_COMPLETE;
				END IF;
			
			WHEN ST_SEND_RESTART_0 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_rst		<= '1';													-- disable clock-tristate => clock = 0
				SerialData_t_r_set		<= '1';													-- enable data-tristate => data = 1
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_LOW;
				
				NextState							<= ST_SEND_RESTART_1;
			
			WHEN ST_SEND_RESTART_1 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_RESTART_2;
				END IF;
			
			WHEN ST_SEND_RESTART_2 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_set		<= '1';													-- enable clock-tristate => clock = 1
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_SETUP_REPEAT_START;
				
				NextState							<= ST_SEND_RESTART_3;
				
			WHEN ST_SEND_RESTART_3 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_RESTART_4;
				END IF;
			
			WHEN ST_SEND_RESTART_4 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialData_t_r_rst		<= '1';													-- disable data-tristate => data = 0
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_HOLD_CLOCK_AFTER_START;
				
				NextState							<= ST_SEND_RESTART_5;
				
			WHEN ST_SEND_RESTART_5 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
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
				BusTC_Slot						<= TTID_CLOCK_HIGH;
				
				NextState							<= ST_SEND_STOP_CLOCK_HIGH_WAIT;
				
			WHEN ST_SEND_STOP_CLOCK_HIGH_WAIT =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_STOP_READBACK_DATA;
				END IF;
			
			WHEN ST_SEND_STOP_READBACK_DATA =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				
				IF (SerialDataIn = '0') THEN
					NextState						<= ST_SEND_COMPLETE;
				ELSE
					NextState						<= ST_BUS_ERROR;
				END IF;
			
			
			
			
			
			
			
			
			
			
			
			
			
			WHEN ST_SEND_STOP_0 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_rst		<= '1';													-- disable clock-tristate => clock = 0
				SerialData_t_r_rst		<= '1';													-- disable data-tristate => data = 0
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_LOW;
				
				NextState							<= ST_SEND_STOP_1;
			
			WHEN ST_SEND_STOP_1 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_STOP_2;
				END IF;
			
			WHEN ST_SEND_STOP_2 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_set		<= '1';													-- enable clock-tristate => clock = 1
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_SETUP_REPEAT_START;
				
				NextState							<= ST_SEND_STOP_3;
				
			WHEN ST_SEND_STOP_3 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_STOP_4;
				END IF;
			
			WHEN ST_SEND_STOP_4 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialData_t_r_set		<= '1';													-- enable data-tristate => data = 1
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_HOLD_CLOCK_AFTER_START;
				
				NextState							<= ST_SEND_STOP_5;
				
			WHEN ST_SEND_STOP_5 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					BusTC_Load					<= '1';													-- load timing counter
					BusTC_Slot					<= TTID_BUS_FREE_TIME;
					
					NextState						<= ST_SEND_COMPLETE;
				END IF;
			
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
