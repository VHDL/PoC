-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================================================================================================
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
-- ============================================================================================================================================================
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
-- ============================================================================================================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
--USE			PoC.strings.ALL;
--USE			PoC.vectors.ALL;
USE			PoC.io.ALL;


ENTITY IICBusController IS
	GENERIC (
		CLOCK_FREQ_MHZ								: REAL															:= 100.0;												-- 100 MHz
		IIC_FREQ_KHZ									: REAL															:= 100.0												-- 100 kHz
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		BusMaster											: IN	STD_LOGIC;				-- 0 = Slave/inactive; 1 = Master/active Clock
		BusMode												: IN	STD_LOGIC;				-- 0 = passive/receive; 1 = active/send data
		
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
--	value read back and compare with written data => raise error?
--	multi-master support
--	receive START, RESTART, STOP
--	"clock stretching"

ARCHITECTURE rtl OF IICBusController IS
	ATTRIBUTE KEEP														: BOOLEAN;
	ATTRIBUTE FSM_ENCODING										: STRING;
	
	CONSTANT TIME_SPIKE_SUPPRESSION_NS				: REAL			:= 50.0;
	CONSTANT TIME_BUS_FREE_NS									: REAL			:= 5000.0;
	CONSTANT TIME_CLOCK_HIGH_NS								: REAL			:= 5000.0;
	CONSTANT TIME_CLOCK_LOW_NS								: REAL			:= 5000.0;
	CONSTANT TIME_SETUP_REPEAT_START_NS				: REAL			:= 5000.0;
	CONSTANT TIME_SETUP_DATA_NS								: REAL			:= 250.0;
	CONSTANT TIME_HOLD_DATA_NS								: REAL			:= 0.0;
	CONSTANT TIME_HOLD_CLOCK_AFTER_START_NS		: REAL			:= 5000.0;
	
	CONSTANT TTID_BUS_FREE_TIME								: NATURAL		:= 0;
	CONSTANT TTID_HOLD_CLOCK_AFTER_START			: NATURAL		:= 1;
	CONSTANT TTID_CLOCK_LOW										: NATURAL		:= 2;
	CONSTANT TTID_CLOCK_HIGH									: NATURAL		:= 3;
	CONSTANT TTID_SETUP_REPEAT_START					: NATURAL		:= 4;
	
	CONSTANT TIMING_TABLE											: T_NATVEC	:= (
		TTID_BUS_FREE_TIME						=> TimingToCycles_ns(TIME_BUS_FREE_NS,								Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_HOLD_CLOCK_AFTER_START		=> TimingToCycles_ns(TIME_HOLD_CLOCK_AFTER_START_NS,	Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_CLOCK_LOW								=> TimingToCycles_ns(TIME_CLOCK_LOW_NS,								Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_CLOCK_HIGH								=> TimingToCycles_ns(TIME_CLOCK_HIGH_NS,							Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_SETUP_REPEAT_START				=> TimingToCycles_ns(TIME_SETUP_REPEAT_START_NS,			Freq_MHz2Real_ns(CLOCK_FREQ_MHZ))
	);
	
	SUBTYPE T_BUSTC_SLOT_INDEX								IS INTEGER RANGE 0 TO TIMING_TABLE'length - 1;
	
	SIGNAL BusTC_en														: STD_LOGIC;
	SIGNAL BusTC_Load													: STD_LOGIC;
	SIGNAL BusTC_Slot													: T_BUSTC_SLOT_INDEX;
	SIGNAL BusTC_Timeout											: STD_LOGIC;
	
	TYPE T_STATE IS (
		ST_IDLE,
			ST_SEND_START_0,		ST_SEND_START_1,		ST_SEND_START_2,
			ST_SEND_RESTART_0,	ST_SEND_RESTART_1,	ST_SEND_RESTART_2,	ST_SEND_RESTART_3,	ST_SEND_RESTART_4,	ST_SEND_RESTART_5,
			ST_SEND_STOP_0,			ST_SEND_STOP_1,			ST_SEND_STOP_2,			ST_SEND_STOP_3,			ST_SEND_STOP_4,			ST_SEND_STOP_5,
			ST_SEND_HIGH_0,			ST_SEND_HIGH_1,			ST_SEND_HIGH_2,			ST_SEND_HIGH_3,
			ST_SEND_LOW_0,			ST_SEND_LOW_1,			ST_SEND_LOW_2,			ST_SEND_LOW_3,
		ST_SEND_COMPLETE,
			ST_RECEIVE_0,				ST_RECEIVE_1,				ST_RECEIVE_2,				ST_RECEIVE_3,
		ST_RECEIVE_COMPLETE,
		ST_ERROR
	);
	
	SIGNAL State												: T_STATE										:= ST_IDLE;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS "gray";
	
	SIGNAL Clock_FilterIn								: STD_LOGIC;
	SIGNAL Clock_FilterOut							: STD_LOGIC;
	SIGNAL Data_FilterIn								: STD_LOGIC;
	SIGNAL Data_FilterOut								: STD_LOGIC;
	
	SIGNAL SerialClock_t_r_set					: STD_LOGIC;
	SIGNAL SerialClock_t_r_rst					: STD_LOGIC;
	SIGNAL SerialData_t_r_set						: STD_LOGIC;
	SIGNAL SerialData_t_r_rst						: STD_LOGIC;
	
	SIGNAL Status_en										: STD_LOGIC;
	SIGNAL Status_nxt										: T_IO_IICBUS_STATUS;
	SIGNAL Status_d											: T_IO_IICBUS_STATUS				:= IO_IICBUS_STATUS_ERROR;
	
	SIGNAL SerialClockIn								: STD_LOGIC									:= '0';
	SIGNAL SerialClock_o_r							: STD_LOGIC									:= '0';
	SIGNAL SerialClock_t_r							: STD_LOGIC									:= '1';
	
	SIGNAL SerialDataIn									: STD_LOGIC									:= '0';
	SIGNAL SerialData_o_r								: STD_LOGIC									:= '0';
	SIGNAL SerialData_t_r								: STD_LOGIC									:= '1';
	
	ATTRIBUTE KEEP OF SerialClockIn			: SIGNAL IS TRUE;
	ATTRIBUTE KEEP OF SerialDataIn			: SIGNAL IS TRUE;
BEGIN
	blkDataFilter : BLOCK
		CONSTANT FILTER_LENGTH				: POSITIVE		:= TimingToCycles_ns(TIME_SPIKE_SUPPRESSION_NS, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)) + 1;
		
--		SIGNAL Data_Filter						: STD_LOGIC_VECTOR(FILTER_LENGTH - 1 DOWNTO 0);
	BEGIN
--		PROCESS(Clock)
--		BEGIN
--			IF rising_edge(Clock) THEN
--				Data_Filter	<= Data_Filter(Data_Filter'high - 1 DOWNTO 0) & Data_FilterIn;
--			END IF;
--		END PROCESS;
		Data_FilterIn			<= SerialData_i;
		Data_FilterOut		<= Data_FilterIn;--NOT to_sl(Data_Filter = (Data_Filter'range => '0'));
	END BLOCK;

	SerialClockIn		<= SerialClock_i		WHEN rising_edge(Clock);
	SerialClock_o		<= '0';--SerialClock_o_r	WHEN rising_edge(Clock);
	SerialClock_t		<= SerialClock_t_r	WHEN rising_edge(Clock);
	
	SerialDataIn		<= SerialData_i			WHEN rising_edge(Clock);
	SerialData_o		<= '0';--SerialData_o_r		WHEN rising_edge(Clock);
	SerialData_t		<= SerialData_t_r		WHEN rising_edge(Clock);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_IDLE;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, BusMaster, BusMode, Command, Status_d, SerialClockIn, Data_FilterOut, BusTC_Timeout)
	BEGIN
		NextState						<= State;

		SerialClock_t_r_set	<= '0';
		SerialClock_t_r_rst	<= '0';
		SerialData_t_r_set	<= '0';
		SerialData_t_r_rst	<= '0';
		
		Status							<= IO_IICBUS_STATUS_IDLE;
		Status_nxt					<= IO_IICBUS_STATUS_ERROR;
		Status_en						<= '0';
		
		BusTC_en						<= '0';
		BusTC_Load					<= '0';
		BusTC_Slot					<= 0;
		
		CASE State IS
			WHEN ST_IDLE =>
				BusTC_en							<= '1';
			
				IF (BusMode = '1') THEN
					CASE Command IS
						WHEN IO_IICBUS_CMD_NONE =>											NULL;
						WHEN IO_IICBUS_CMD_SEND_START_CONDITION =>
							IF (BusTC_Timeout = '0') THEN
								NextState				<= ST_SEND_START_0;
							ELSE
								NextState				<= ST_SEND_START_1;
							END IF;
						WHEN IO_IICBUS_CMD_SEND_RESTART_CONDITION =>		NextState		<= ST_SEND_RESTART_0;
						WHEN IO_IICBUS_CMD_SEND_STOP_CONDITION =>				NextState		<= ST_SEND_STOP_0;
						WHEN IO_IICBUS_CMD_SEND_LOW =>									NextState		<= ST_SEND_LOW_0;
						WHEN IO_IICBUS_CMD_SEND_HIGH =>									NextState		<= ST_SEND_HIGH_0;
						WHEN IO_IICBUS_CMD_RECEIVE =>										NextState		<= ST_ERROR;
						WHEN OTHERS =>																	NextState		<= ST_ERROR;
					END CASE;
				ELSE
					CASE Command IS
						WHEN IO_IICBUS_CMD_NONE =>											NULL;
						WHEN IO_IICBUS_CMD_RECEIVE =>										NextState		<= ST_RECEIVE_0;
						WHEN OTHERS =>																	NextState		<= ST_ERROR;
					END CASE;
				END IF;
			
			WHEN ST_SEND_START_0 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_START_1;
				END IF;
			
			WHEN ST_SEND_START_1 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialData_t_r_rst		<= '1';													-- disable data-tristate => data = 0
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_HOLD_CLOCK_AFTER_START;
				
				NextState							<= ST_SEND_START_2;
			
			WHEN ST_SEND_START_2 =>
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
			
			WHEN ST_SEND_HIGH_0 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_rst		<= '1';													-- disable clock-tristate => clock = 0
				SerialData_t_r_set		<= '1';													-- enable data-tristate => data = 1
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_LOW;
				
				NextState							<= ST_SEND_HIGH_1;
			
			WHEN ST_SEND_HIGH_1 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_HIGH_2;
				END IF;
			
			WHEN ST_SEND_HIGH_2 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_set		<= '1';													-- enable clock-tristate => clock = 1
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_HIGH;
				
				NextState							<= ST_SEND_HIGH_3;
				
			WHEN ST_SEND_HIGH_3 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_COMPLETE;
				END IF;
			
			WHEN ST_SEND_LOW_0 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_rst		<= '1';													-- disable clock-tristate => clock = 0
				SerialData_t_r_rst		<= '1';													-- disable data-tristate => data = 0
				
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_LOW;
				
				NextState							<= ST_SEND_LOW_1;
			
			WHEN ST_SEND_LOW_1 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_LOW_2;
				END IF;
			
			WHEN ST_SEND_LOW_2 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				SerialClock_t_r_set		<= '1';													-- enable clock-tristate => clock = 1
			
				BusTC_Load						<= '1';													-- load timing counter
				BusTC_Slot						<= TTID_CLOCK_HIGH;
				
				NextState							<= ST_SEND_LOW_3;
				
			WHEN ST_SEND_LOW_3 =>
				Status								<= IO_IICBUS_STATUS_SENDING;
				BusTC_en							<= '1';
				
				IF (BusTC_Timeout = '1') THEN
					NextState						<= ST_SEND_COMPLETE;
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
			
				IF (Data_FilterOut = '0') THEN
					Status_nxt					<= IO_IICBUS_STATUS_RECEIVED_LOW;
				ELSIF (Data_FilterOut = ite(SIMULATION, 'H', '1')) THEN
					Status_nxt					<= IO_IICBUS_STATUS_RECEIVED_HIGH;
				ELSE
					Status_nxt					<= IO_IICBUS_STATUS_ERROR;
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
			
			WHEN OTHERS =>
				NULL;
		END CASE;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (SerialClock_t_r_rst = '1') THEN
				SerialClock_t_r		<= '0';
			ELSIF ((Reset OR SerialClock_t_r_set) = '1') THEN
				SerialClock_t_r		<= '1';
			END IF;

			IF (SerialData_t_r_rst = '1') THEN
				SerialData_t_r		<= '0';
			ELSIF ((Reset OR SerialData_t_r_set) = '1') THEN
				SerialData_t_r		<= '1';
			END IF;
		END IF;
	END PROCESS;
	
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
	
	BusTC : ENTITY PoC.TimingCounter
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
