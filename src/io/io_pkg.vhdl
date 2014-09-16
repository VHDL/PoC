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

library PoC;
use			PoC.my_config.all;


PACKAGE io IS
	-- not yet supported by Xilinx ISE Simulator - the subsignal I (with reverse direction) is always 'U'
	-- so use this record only in pure synthesis environments
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
		IO_IICBUS_STATUS_BUS_ERROR
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
	
	TYPE T_IO_LCDBUS_COMMAND IS (
		IO_LCDBUS_CMD_NONE,
		IO_LCDBUS_CMD_READ,
		IO_LCDBUS_CMD_WRITE
	);
	
	TYPE T_IO_LCDBUS_STATUS IS (
		IO_LCDBUS_STATUS_IDLE,
		IO_LCDBUS_STATUS_READING,
		IO_LCDBUS_STATUS_WRITING,
		IO_LCDBUS_STATUS_ERROR
	);
	
	
	function io_7SegmentDisplayEncoding(hex	: STD_LOGIC_VECTOR(3 downto 0); dot : STD_LOGIC := '0') return STD_LOGIC_VECTOR;

  -- Component Declarations
  -- =========================================================================
  component io_FanControl
    generic (
      CLOCK_FREQ_MHZ	: real
    );
    port (
      Clock						: in	STD_LOGIC;
      Reset						: in	STD_LOGIC;

      Fan_PWM					: out	STD_LOGIC;
      Fan_Tacho				: in	STD_LOGIC;

      TachoFrequency	: out	STD_LOGIC_VECTOR(15 downto 0)
    );
	end component;

END io;


PACKAGE BODY io IS
	function io_7SegmentDisplayEncoding(hex	: STD_LOGIC_VECTOR(3 downto 0); dot : STD_LOGIC := '0') return STD_LOGIC_VECTOR is
		variable Result		: STD_LOGIC_VECTOR(7 downto 0);
	begin
		Result(7)		:= dot;
		case hex is							-- segments:			GFEDCBA
			when x"0" =>		Result(6 downto 0)	:= "1000000";
			when x"1" =>		Result(6 downto 0)	:= "1111001";
			when x"2" =>		Result(6 downto 0)	:= "0100100";
			when x"3" =>		Result(6 downto 0)	:= "0110000";
			when x"4" =>		Result(6 downto 0)	:= "0011001";
			when x"5" =>		Result(6 downto 0)	:= "0010010";
			when x"6" =>		Result(6 downto 0)	:= "0000010";
			when x"7" =>		Result(6 downto 0)	:= "1111000";
			when x"8" =>		Result(6 downto 0)	:= "0000000";
			when x"9" =>		Result(6 downto 0)	:= "0010000";
			when x"A" =>		Result(6 downto 0)	:= "0001000";
			when x"B" =>		Result(6 downto 0)	:= "0000011";
			when x"C" =>		Result(6 downto 0)	:= "1000110";
			when x"D" =>		Result(6 downto 0)	:= "0100001";
			when x"E" =>		Result(6 downto 0)	:= "0000110";
			when x"F" =>		Result(6 downto 0)	:= "0001110";
			when others =>	Result(6 downto 0)	:= "XXXXXXX";
		end case;
		return Result;
	end function;

END PACKAGE BODY;
