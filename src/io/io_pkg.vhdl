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
	-- not yet supported by Xilinx Synthese Tools (XST) - Version 13.2 (O.61xd 2011)
	TYPE FREQ IS RANGE 0 TO INTEGER'high UNITS
		Hz;
		kHz = 1000 Hz;
		MHz = 1000 kHz;
		GHz = 1000 MHz;
		THz = 1000 GHz;
	END UNITS;

	TYPE BAUD IS RANGE 0 TO INTEGER'high UNITS
		Bd;
		kBd = 1000 Bd;
		MBd = 1000 kBd;
		GBd = 1000 MBd;
	END UNITS;

	TYPE MEMORY IS RANGE 0 TO INTEGER'high UNITS
		B;
		kiB = 1000 B;
		MiB = 1000 kiB;
		GiB = 1000 MiB;
		TiB = 1000 GiB;
	END UNITS;
	
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
	FUNCTION Freq_kHz2Real_ns(Freq_kHz : POSITIVE)	RETURN REAL;
	FUNCTION Freq_kHz2Real_ns(Freq_kHz : REAL)			RETURN REAL;
	FUNCTION Freq_MHz2Real_ns(Freq_MHz : POSITIVE)	RETURN REAL;
	FUNCTION Freq_MHz2Real_ns(Freq_MHz : REAL)			RETURN REAL;
	
	-- begin new
	function to_time(frequency : FREQ)	return TIME;
	function to_freq(Period : TIME)			return FREQ;
	
	FUNCTION kHz2Time(Freq_kHz : POSITIVE) RETURN TIME;
	FUNCTION MHz2Time(Freq_MHz : POSITIVE) RETURN TIME;
	FUNCTION GHz2Time(Freq_GHz : POSITIVE) RETURN TIME;

	FUNCTION kHz2Time(Freq_kHz : REAL) RETURN TIME;
	FUNCTION MHz2Time(Freq_MHz : REAL) RETURN TIME;
	FUNCTION GHz2Time(Freq_GHz : REAL) RETURN TIME;
	
	function ns2Time(Time_ns : REAL) return TIME;
	function us2Time(Time_us : REAL) return TIME;
	function ms2Time(Time_ms : REAL) return TIME;

	FUNCTION Time2Real_ps(t : TIME) RETURN REAL;
	FUNCTION Time2Real_ns(t : TIME) RETURN REAL;
	FUNCTION Time2Real_us(t : TIME) RETURN REAL;
	FUNCTION Time2Real_ms(t : TIME) RETURN REAL;

	FUNCTION Freq2Real_Hz(f : FREQ)  RETURN REAL;
	FUNCTION Freq2Real_kHz(f : FREQ) RETURN REAL;
	FUNCTION Freq2Real_MHz(f : FREQ) RETURN REAL;
	FUNCTION Freq2Real_GHz(f : FREQ) RETURN REAL;
	
	function TimingToCycles(Timing : TIME; Clock_Period			: TIME) return NATURAL;
	function TimingToCycles(Timing : TIME; Clock_Frequency	: FREQ) return NATURAL;
	-- end new
	
	-- Baud2***Hz
	FUNCTION Baud2kHz(BaudRate : POSITIVE)	RETURN REAL;
	FUNCTION Baud2MHz(BaudRate : POSITIVE)	RETURN REAL;
	FUNCTION Baud2kHz(BaudRate : REAL)			RETURN REAL;
	FUNCTION Baud2MHz(BaudRate : REAL)			RETURN REAL;

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

	function Freq2Real_Hz(f : FREQ)  return REAL is
	begin
		return real(f / 1.0 Hz);
	end function;
	
	function Freq2Real_kHz(f : FREQ) return REAL is
	begin
		return real(f / 1.0 kHz);
	end function;
	
	function Freq2Real_MHz(f : FREQ) return REAL is
	begin
		return real(f / 1.0 MHz);
	end function;
	
	function Freq2Real_GHz(f : FREQ) return REAL is
	begin
		return real(f / 1.0 GHz);
	end function;
	
	-- type TIME not supported in Xilinx Synthese Tools (XST) - Version O.61xd 2011
	--	declaration of constants with type TIME		=> ERROR
	--	usage of type TIME in functions						=> ERROR

	function to_time(Frequency : FREQ) return TIME is
		variable Result : TIME;
	begin
		assert MY_VERBOSE report "to_time: Frequency = " & FREQ'image(Frequency) severity note;
	
		if		(Frequency < 1.0 kHz) then	Result := (1.0 / real(Frequency / 1.0	 Hz)) * 1.0 sec;
		elsif (Frequency < 1.0 MHz) then	Result := (1.0 / real(Frequency / 1.0 kHz)) * 1.0 ms;
		elsif (Frequency < 1.0 GHz) then	Result := (1.0 / real(Frequency / 1.0 MHz)) * 1.0 us;
		elsif (Frequency < 1.0 THz) then	Result := (1.0 / real(Frequency / 1.0 GHz)) * 1.0 ns;
		else															Result := (1.0 / real(Frequency / 1.0 THz)) * 1.0 ps;
		end if;
		
		assert MY_VERBOSE report "  return " & TIME'image(Result) severity note;
		return Result;
	end function;

	function to_freq(Period : TIME) return FREQ is
		variable Result : FREQ;
	begin
		assert MY_VERBOSE report "to_freq: Period = " & TIME'image(Period) severity note;
	
		if		(Period < 1.0 ps) then	Result := (1.0 / real(Period / 1.0 fs)) * 1.0 THz;
		elsif (Period < 1.0 ns) then	Result := (1.0 / real(Period / 1.0 ps)) * 1.0 GHz;
		elsif (Period < 1.0 us) then	Result := (1.0 / real(Period / 1.0 ns)) * 1.0 MHz;
		elsif (Period < 1.0 ms)	then	Result := (1.0 / real(Period / 1.0 us)) * 1.0 kHz;
		elsif (Period < 1.0 sec) then	Result := (1.0 / real(Period / 1.0 ms)) * 1.0  Hz;
		else
			report "to_freq: input period exceeds output frquency scale." severity failure;
		end if;
		
		assert MY_VERBOSE report "  return " & FREQ'image(Result) severity note;
		return Result;
	end function;

	FUNCTION kHz2Time(Freq_kHz : POSITIVE) RETURN TIME IS
	BEGIN
		RETURN 1.0 ms / real(Freq_kHz);
	END;

	FUNCTION MHz2Time(Freq_MHz : POSITIVE) RETURN TIME IS
	BEGIN
		RETURN 1.0 us / real(Freq_MHz);
	END;
	
	FUNCTION GHz2Time(Freq_GHz : POSITIVE) RETURN TIME IS
	BEGIN
		RETURN 1.0 ns / real(Freq_GHz);
	END;
	
	-- has no static result in Xilinx Synthese Tools (XST) - Version O.61xd 2011
	FUNCTION kHz2Time(Freq_kHz : REAL) RETURN TIME IS
	BEGIN
		RETURN 1.0 ms / Freq_kHz;
	END;
	
	-- has no static result in Xilinx Synthese Tools (XST) - Version O.61xd 2011
	FUNCTION MHz2Time(Freq_MHz : REAL) RETURN TIME IS
	BEGIN
		RETURN 1.0 us / Freq_MHz;
	END;

	FUNCTION GHz2Time(Freq_GHz : REAL) RETURN TIME IS
	BEGIN
		RETURN 1.0 ns / Freq_GHz;
	END;

	function ns2Time(Time_ns : REAL) return TIME is
	begin
		return Time_ns * 1.0 ns;
	end function;

	function us2Time(Time_us : REAL) return TIME is
	begin
		return Time_us * 1.0 us;
	end function;
	
	function ms2Time(Time_ms : REAL) return TIME is
	begin
		return Time_ms * 1.0 ms;
	end function;

	FUNCTION Time2Real_ps(t : TIME) RETURN REAL IS
	BEGIN
		RETURN real(t / 1 ps);
	END;

	FUNCTION Time2Real_ns(t : TIME) RETURN REAL IS
	BEGIN
		RETURN real(t / 1 ns);
	END;

	FUNCTION Time2Real_us(t : TIME) RETURN REAL IS
	BEGIN
		RETURN real(t / 1 us);
	END;

	FUNCTION Time2Real_ms(t : TIME) RETURN REAL IS
	BEGIN
		RETURN real(t / 1 ms);
	END;

	function TimingToCycles(Timing : TIME; Clock_Period			: TIME) return NATURAL is
	begin
		return natural(real(Timing / Clock_Period));
	end;
	
	function TimingToCycles(Timing : TIME; Clock_Frequency	: FREQ) return NATURAL is
	begin
		return natural(real(Timing / to_time(Clock_Frequency)));
	end;
	


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
