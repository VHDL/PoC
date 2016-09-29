-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Package:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use 		PoC.vectors.all;
use 		PoC.sata.all;
use 		PoC.xil.all;

package sata_TransceiverTypes is
	type T_SATA_TRANSCEIVER_REFCLOCK_SOURCE is (
		SATA_TRANSCEIVER_REFCLOCK_INTERNAL,
		SATA_TRANSCEIVER_REFCLOCK_GTREFCLK0,
		SATA_TRANSCEIVER_REFCLOCK_GTREFCLK1
	);

	function to_bv (source : T_SATA_TRANSCEIVER_REFCLOCK_SOURCE) return bit_vector;
	function to_slv(source : T_SATA_TRANSCEIVER_REFCLOCK_SOURCE) return std_logic_vector;

	type T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS is record
		RefClockIn_IBUFDS			: std_logic_vector(1 downto 0);
		RefClockIn_BUFG				: std_logic;
		DRP_Clock							: std_logic;
	end record;

	type T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS is record
		RX_n									: std_logic;
		RX_p									: std_logic;
	end record;

	type T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS is record
		TX_n									: std_logic;
		TX_p									: std_logic;
	end record;

	type T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS_VECTOR		is array(natural range <>) of T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
	type T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR		is array(natural range <>) of T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS;
	type T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR	is array(natural range <>) of T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS;

	-- Debug Types and Constants
	------------------------------------------------------------------------------
	type T_SATADBG_TRANSCEIVER_OUT is record
		PowerDown									: std_logic;
		ClockNetwork_Reset				: std_logic;
		ClockNetwork_ResetDone		: std_logic;
		Reset											: std_logic;
		ResetDone									: std_logic;

		UserClock									: std_logic;
		UserClock_Stable					: std_logic;

		GTX_CPLL_PowerDown				: std_logic;
		GTX_TX_PowerDown					: std_logic;
		GTX_RX_PowerDown					: std_logic;

		GTX_CPLL_Reset						: std_logic;
		GTX_CPLL_Locked						: std_logic;

		GTX_TX_Reset							: std_logic;
		GTX_RX_Reset							: std_logic;
		GTX_RX_PMAReset						: std_logic;
		GTX_TX_ResetDone					: std_logic;
		GTX_RX_ResetDone					: std_logic;
		GTX_RX_PMAResetDone				: std_logic;

		FSM												: std_logic_vector(3 downto 0);

		OOB_Clock									: std_logic;
		RP_SATAGeneration					: T_SATA_GENERATION;
		RP_Reconfig								: std_logic;
		RP_ReconfigComplete				: std_logic;
		RP_ConfigRealoaded				: std_logic;
		DD_NoDevice								: std_logic;
		DD_NewDevice							: std_logic;
		TX_RateSelection					: std_logic_vector(2 downto 0);
		RX_RateSelection					: std_logic_vector(2 downto 0);
		TX_RateSelectionDone			: std_logic;
		RX_RateSelectionDone			: std_logic;
		RX_CDR_Locked							: std_logic;
		RX_CDR_Hold								: std_logic;

		TX_Data										: T_SLV_32;
		TX_CharIsK								: T_SLV_4;
		TX_BufferStatus						: std_logic_vector(1 downto 0);
		TX_ComInit								: std_logic;
		TX_ComWake								: std_logic;
		TX_ComFinish							: std_logic;
		TX_ElectricalIDLE					: std_logic;

		RX_Data										: T_SLV_32;
		RX_CharIsK								: T_SLV_4;
		RX_CharIsComma						: T_SLV_4;
		RX_CommaDetected					: std_logic;
		RX_ByteIsAligned					: std_logic;
		RX_DisparityError					: T_SLV_4;
		RX_NotInTableError				: T_SLV_4;
		RX_ElectricalIDLE					: std_logic;
		RX_ComInitDetected				: std_logic;
		RX_ComWakeDetected				: std_logic;
		RX_Valid									: std_logic;
		RX_BufferStatus						: std_logic_vector(2 downto 0);
		RX_ClockCorrectionStatus	: std_logic_vector(1 downto 0);

		DRP												: T_XIL_DRP_BUS_OUT;
		DigitalMonitor						: T_SLV_16;
		RX_Monitor_Data						: T_SLV_8;
	end record;

	constant C_SATADBG_TRANSCEIVER_OUT_EMPTY : T_SATADBG_TRANSCEIVER_OUT := (
		FSM											 => (others => '0'),
		RP_SATAGeneration				 => SATA_GENERATION_1,
		TX_RateSelection				 => (others => '0'),
		RX_RateSelection				 => (others => '0'),
		TX_Data									 => (others => '0'),
		TX_CharIsK							 => (others => '0'),
		TX_BufferStatus					 => (others => '0'),
		RX_Data									 => (others => '0'),
		RX_CharIsK							 => (others => '0'),
		RX_CharIsComma					 => (others => '0'),
		RX_DisparityError				 => (others => '0'),
		RX_NotInTableError			 => (others => '0'),
		RX_BufferStatus					 => (others => '0'),
		RX_ClockCorrectionStatus => (others => '0'),
		DRP											 => C_XIL_DRP_BUS_OUT_EMPTY,
		DigitalMonitor					 => (others => '0'),
		RX_Monitor_Data					 => (others => '0'),
		others									 => '0');

	type T_SATADBG_TRANSCEIVER_IN is record
		ForceOOBCommand						: T_SATA_OOB;
		ForceTXElectricalIdle			: std_logic;
		InsertBitErrorTX 					: std_logic;
		InsertBitErrorRX 					: std_logic;
		DRP												: T_XIL_DRP_BUS_IN;
		RX_Monitor_sel						: T_SLV_2;
	end record;

	constant C_SATADBG_TRANSCEIVER_IN_EMPTY : T_SATADBG_TRANSCEIVER_IN := (
		ForceOOBCommand => SATA_OOB_NONE,
		DRP							=> C_XIL_DRP_BUS_IN_EMPTY,
		RX_Monitor_sel	=> "00",
		others					=> '0');
end;


package body sata_TransceiverTypes is
	function to_bv(source : T_SATA_TRANSCEIVER_REFCLOCK_SOURCE) return bit_vector is
	begin
		case source is
			when SATA_TRANSCEIVER_REFCLOCK_GTREFCLK0 => return "001";
			when SATA_TRANSCEIVER_REFCLOCK_GTREFCLK1 => return "010";
			when SATA_TRANSCEIVER_REFCLOCK_INTERNAL  => return "111";
		end case;
	end function;

	function to_slv(source : T_SATA_TRANSCEIVER_REFCLOCK_SOURCE) return std_logic_vector is
	begin
		return to_stdlogicvector(to_bv(source));
	end function;
end;
