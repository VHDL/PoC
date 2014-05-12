-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Package:					VHDL package for component declarations, types and
--									functions assoziated to the PoC.io namespace
--
-- Authors:					Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		For detailed documentation see below.
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


PACKAGE io IS
	-- not yet supported by Xilinx Synthese Tools (XST) - Version 13.2 (O.61xd 2011)
--	TYPE FREQ IS RANGE 0 TO 2147483647
--		UNITS
--			Hz;
--			kHz = 1000 Hz;
--			MHz = 1000 kHz;
--			GHz = 1000 MHz;
--		END UNITS;
	
	TYPE T_IO_TRISTATE IS RECORD
		I			: STD_LOGIC;					-- input / from device to FPGA
		O			: STD_LOGIC;					-- output / from FPGA to device
		T			: STD_LOGIC;					-- output disable / tristate enable
	END RECORD;

	TYPE T_IO_TRISTATE_VECTOR	IS ARRAY(NATURAL RANGE <>) OF T_IO_TRISTATE;
	
	-- IICBusController
	-- ==========================================================================================================================================================
	TYPE T_IO_IIC_BUSMODE IS (
		IO_IIC_BUSMODE_SMBUS,							--   100 kHz; additional timing restrictions
		IO_IIC_BUSMODE_STANDARDMODE,			--   100 kHz
		IO_IIC_BUSMODE_FASTMODE,					--   400 kHz
		IO_IIC_BUSMODE_FASTMODEPLUS,			-- 1.000 kHz
		IO_IIC_BUSMODE_HIGHSPEEDMODE,			-- 3.400 kHz
		IO_IIC_BUSMODE_ULTRAFASTMODE			-- 5.000 kHz; unidirectional
	);

	TYPE T_IO_IICBUS_COMMAND IS (
		IO_IICBUS_CMD_NONE,
		IO_IICBUS_CMD_SEND_START_CONDITION,
		IO_IICBUS_CMD_SEND_RESTART_CONDITION,
		IO_IICBUS_CMD_SEND_STOP_CONDITION,
		IO_IICBUS_CMD_SEND_LOW,
		IO_IICBUS_CMD_SEND_HIGH,
		IO_IICBUS_CMD_RECEIVE
	);
	
	TYPE T_IO_IICBUS_STATUS IS (
		IO_IICBUS_STATUS_RESETING,
		IO_IICBUS_STATUS_IDLE,
		IO_IICBUS_STATUS_SENDING,
		IO_IICBUS_STATUS_SEND_COMPLETE,
		IO_IICBUS_STATUS_RECEIVING,
		IO_IICBUS_STATUS_RECEIVED_START_CONDITION,
		IO_IICBUS_STATUS_RECEIVED_STOP_CONDITION,
		IO_IICBUS_STATUS_RECEIVED_LOW,
		IO_IICBUS_STATUS_RECEIVED_HIGH,
		IO_IICBUS_STATUS_ERROR,
		IO_IICBUS_STATUS_ARBITRATION_LOSS
	);
	
	-- IICController
	-- ==========================================================================================================================================================
	TYPE T_IO_IIC_COMMAND IS (
		IO_IIC_CMD_NONE,
		IO_IIC_CMD_QUICKCOMMAND_READ,	-- use this to check for an device address
		IO_IIC_CMD_QUICKCOMMAND_WRITE,
		IO_IIC_CMD_SEND_BYTES,
		IO_IIC_CMD_RECEIVE_BYTES,
		IO_IIC_CMD_PROCESS_CALL
	);
	
	TYPE T_IO_IIC_STATUS IS (
		IO_IIC_STATUS_IDLE,
		IO_IIC_STATUS_EXECUTING,
		IO_IIC_STATUS_EXECUTE_OK,
		IO_IIC_STATUS_EXECUTE_FAILED,
		IO_IIC_STATUS_SENDING,
		IO_IIC_STATUS_SEND_COMPLETE,
		IO_IIC_STATUS_RECEIVING,
		IO_IIC_STATUS_RECEIVE_COMPLETE,
		IO_IIC_STATUS_CALLING,
		IO_IIC_STATUS_CALL_COMPLETE,
		IO_IIC_STATUS_ERROR
	);

	TYPE T_IO_IIC_ERROR IS (
		IO_IIC_ERROR_NONE,
		IO_IIC_ERROR_ADDRESS_ERROR,
		IO_IIC_ERROR_ACK_ERROR,
		IO_IIC_ERROR_BUS_ERROR,
		IO_IIC_ERROR_FSM
	);
	
	TYPE T_IO_IIC_COMMAND_VECTOR	IS ARRAY(NATURAL RANGE <>) OF T_IO_IIC_COMMAND;
	TYPE T_IO_IIC_STATUS_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_IO_IIC_STATUS;
	TYPE T_IO_IIC_ERROR_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_IO_IIC_ERROR;
	
	
	
	-- MDIOController
	-- ==========================================================================================================================================================
	TYPE T_IO_MDIO_MDIOCONTROLLER_COMMAND IS (
		IO_MDIO_MDIOC_CMD_NONE,
		IO_MDIO_MDIOC_CMD_CHECK_ADDRESS,
		IO_MDIO_MDIOC_CMD_READ,
		IO_MDIO_MDIOC_CMD_WRITE,
		IO_MDIO_MDIOC_CMD_ABORT
	);
	
	TYPE T_IO_MDIO_MDIOCONTROLLER_STATUS IS (
		IO_MDIO_MDIOC_STATUS_IDLE,
		IO_MDIO_MDIOC_STATUS_CHECKING,
		IO_MDIO_MDIOC_STATUS_CHECK_OK,
		IO_MDIO_MDIOC_STATUS_CHECK_FAILED,
		IO_MDIO_MDIOC_STATUS_READING,
		IO_MDIO_MDIOC_STATUS_READ_COMPLETE,
		IO_MDIO_MDIOC_STATUS_WRITING,
		IO_MDIO_MDIOC_STATUS_WRITE_COMPLETE,
		IO_MDIO_MDIOC_STATUS_ERROR
	);
	
	TYPE T_IO_MDIO_MDIOCONTROLLER_ERROR IS (
		IO_MDIO_MDIOC_ERROR_NONE,
		IO_MDIO_MDIOC_ERROR_ADDRESS_NOT_FOUND,
		IO_MDIO_MDIOC_ERROR_FSM
	);
	
	-- TimingToCycles_***
	FUNCTION TimingToCycles_ns(Timing_NS : POSITIVE;	CLOCKSPEED_NS : REAL) RETURN NATURAL;
	FUNCTION TimingToCycles_ns(Timing_NS : REAL;			CLOCKSPEED_NS : REAL) RETURN NATURAL;
	
	FUNCTION TimingToCycles_us(Timing_US : POSITIVE;	CLOCKSPEED_NS : REAL) RETURN NATURAL;
	FUNCTION TimingToCycles_us(Timing_US : REAL;			CLOCKSPEED_NS : REAL) RETURN NATURAL;
	
	FUNCTION TimingToCycles_ms(Timing_MS : POSITIVE;	CLOCKSPEED_NS : REAL) RETURN NATURAL;
	FUNCTION TimingToCycles_ms(Timing_MS : REAL;			CLOCKSPEED_NS : REAL) RETURN NATURAL;
	
	FUNCTION TimingToCycles_s(Timing_S	 : POSITIVE;	CLOCKSPEED_NS : REAL) RETURN NATURAL;
	FUNCTION TimingToCycles_s(Timing_S	 : REAL;			CLOCKSPEED_NS : REAL) RETURN NATURAL;
	
	-- Freq_***Hz2Real_ns
	FUNCTION Freq_kHz2Real_ns(Freq_kHz : POSITIVE) RETURN REAL;
	FUNCTION Freq_kHz2Real_ns(Freq_kHz : REAL) RETURN REAL;
	FUNCTION Freq_MHz2Real_ns(Freq_MHz : POSITIVE) RETURN REAL;
	FUNCTION Freq_MHz2Real_ns(Freq_MHz : REAL) RETURN REAL;
	
	-- Baud2***Hz
	FUNCTION Baud2kHz(BaudRate : POSITIVE) RETURN REAL;
	FUNCTION Baud2kHz(BaudRate : REAL) RETURN REAL;
	FUNCTION Baud2MHz(BaudRate : POSITIVE) RETURN REAL;
	FUNCTION Baud2MHz(BaudRate : REAL) RETURN REAL;
	
END io;


PACKAGE BODY io IS
	-- TimingToCycles
	-- ================================================================
	-- nanoseconds
	FUNCTION TimingToCycles_ns(Timing_NS : REAL; CLOCKSPEED_NS : REAL) RETURN NATURAL IS
	BEGIN
		RETURN natural(Timing_NS / CLOCKSPEED_NS);
	END;

	FUNCTION TimingToCycles_ns(Timing_NS : POSITIVE; CLOCKSPEED_NS : REAL) RETURN NATURAL IS
	BEGIN
		RETURN TimingToCycles_ns(real(Timing_NS), CLOCKSPEED_NS);
	END;

	-- microseconds
	FUNCTION TimingToCycles_us(Timing_US : REAL; CLOCKSPEED_NS : REAL) RETURN NATURAL IS
	BEGIN
		RETURN natural((Timing_US * 1000.0) / CLOCKSPEED_NS);
	END;

	FUNCTION TimingToCycles_us(Timing_US : POSITIVE; CLOCKSPEED_NS : REAL) RETURN NATURAL IS
	BEGIN
		RETURN TimingToCycles_us(real(Timing_US), CLOCKSPEED_NS);
	END;
	
	-- milliseconds
	FUNCTION TimingToCycles_ms(Timing_MS : REAL; CLOCKSPEED_NS : REAL) RETURN NATURAL IS
	BEGIN
		RETURN natural((Timing_MS * 1000.0 * 1000.0) / CLOCKSPEED_NS);
	END;

	FUNCTION TimingToCycles_ms(Timing_MS : POSITIVE; CLOCKSPEED_NS : REAL) RETURN NATURAL IS
	BEGIN
		RETURN TimingToCycles_ms(real(Timing_MS), CLOCKSPEED_NS);
	END;
	
	-- seconds
	FUNCTION TimingToCycles_s(Timing_S : REAL; CLOCKSPEED_NS : REAL) RETURN NATURAL IS
	BEGIN
		RETURN natural((Timing_S * 1000.0 * 1000.0 * 1000.0) / CLOCKSPEED_NS);
	END;

	FUNCTION TimingToCycles_s(Timing_S : POSITIVE; CLOCKSPEED_NS : REAL) RETURN NATURAL IS
	BEGIN
		RETURN TimingToCycles_s(real(Timing_S), CLOCKSPEED_NS);
	END;
	
	-- Freq_***Hz2Real_ns
	-- ================================================================
	-- kHz
	FUNCTION Freq_kHz2Real_ns(Freq_kHz : POSITIVE) RETURN REAL IS
	BEGIN
		RETURN 1000000.0 / real(Freq_kHz);
	END;

	FUNCTION Freq_kHz2Real_ns(Freq_kHz : REAL) RETURN REAL IS
	BEGIN
		RETURN 1000000.0 / Freq_kHz;
	END;

	-- MHz
	FUNCTION Freq_MHz2Real_ns(Freq_MHz : POSITIVE) RETURN REAL IS
	BEGIN
		RETURN 1000.0 / real(Freq_MHz);
	END;

	FUNCTION Freq_MHz2Real_ns(Freq_MHz : REAL) RETURN REAL IS
	BEGIN
		RETURN 1000.0 / Freq_MHz;
	END;

	-- Baud2***Hz
	-- ================================================================
	-- kHz
	FUNCTION Baud2kHz(BaudRate : POSITIVE) RETURN REAL IS
	BEGIN
		RETURN real(BaudRate) / 1000.0;
	END;
	
	FUNCTION Baud2kHz(BaudRate : REAL) RETURN REAL IS
	BEGIN
		RETURN BaudRate / 1000.0;
	END;
	
	-- ================================================================
	-- MHz
	FUNCTION Baud2MHz(BaudRate : POSITIVE) RETURN REAL IS
	BEGIN
		RETURN real(BaudRate) / (1000.0 * 1000.0);
	END;
	
	FUNCTION Baud2MHz(BaudRate : REAL) RETURN REAL IS
	BEGIN
		RETURN BaudRate / (1000.0 * 1000.0);
	END;

	-- type TIME not supported in Xilinx Synthese Tools (XST) - Version O.61xd 2011
	--	declaration of constants with type TIME		=> ERROR
	--	usage of type TIME in functions						=> ERROR

--	FUNCTION kHz2Time(Freq_kHz : POSITIVE) RETURN TIME IS
--	BEGIN
--		RETURN 1.0 ms / real(Freq_kHz);
--	END;

--	FUNCTION MHz2Time(Freq_MHz : POSITIVE) RETURN TIME IS
--	BEGIN
--		RETURN 1.0 us / real(Freq_MHz);
--	END;
	
	-- has no static result in Xilinx Synthese Tools (XST) - Version O.61xd 2011
--	FUNCTION kHz2Time(Freq_kHz : REAL) RETURN TIME IS
--	BEGIN
--		RETURN 1.0 ms / Freq_kHz;
--	END;
	
	-- has no static result in Xilinx Synthese Tools (XST) - Version O.61xd 2011
--	FUNCTION MHz2Time(Freq_MHz : REAL) RETURN TIME IS
--		CONSTANT result : TIME := 1.0 us / Freq_MHz;
--	BEGIN
--		RETURN result;
--	END;


--	FUNCTION Time2Real_ps(t : TIME) RETURN REAL IS
--	BEGIN
--		RETURN real(t / 1 ps);
--	END;

--	FUNCTION Time2Real_ns(t : TIME) RETURN REAL IS
--	BEGIN
--		RETURN real(t / 1 ns);
--	END;

--	FUNCTION Time2Real_us(t : TIME) RETURN REAL IS
--	BEGIN
--		RETURN real(t / 1 us);
--	END;

--	FUNCTION Time2Real_ms(t : TIME) RETURN REAL IS
--	BEGIN
--		RETURN real(t / 1 ms);
--	END;

--	FUNCTION TimingToCycles(Timing : TIME; CLOCKSPEED : TIME) RETURN NATURAL IS
--	BEGIN
--		RETURN natural(real(Timing / CLOCKSPEED));
--	END;
	
--	FUNCTION TimingToCycles_us(Timing : TIME; CLOCKSPEED : TIME) RETURN UNSIGNED IS
--		CONSTANT CYCLES : NATURAL := TimingToCycles(Timing, CLOCKSPEED);
--	BEGIN
--		RETURN to_unsigned(CYCLES, log2ceilnz(CYCLES));
--	END;

END PACKAGE BODY;
