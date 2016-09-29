-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
--
-- Entity:					TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.components.all;
use			PoC.sata.all;
use			PoC.satacomp.all;
use			PoC.satadbg.all;
use			PoC.sata_TransceiverTypes.all;
use			PoC.xil.all;


entity sata_StreamingStack is
	generic (
		DEBUG												: boolean;
		ENABLE_DEBUGPORT						: boolean;

		REFCLOCK_FREQ								: FREQ;
		REFCLOCK_SOURCE 						: T_SATA_TRANSCEIVER_REFCLOCK_SOURCE := SATA_TRANSCEIVER_REFCLOCK_INTERNAL;
		INITIAL_SATA_GENERATION			: T_SATA_GENERATION;
		ALLOW_SPEED_NEGOTIATION			: boolean;
		LOGICAL_BLOCK_SIZE					: MEMORY
	);
	port (
		-- SATA stack common interface
		PowerDown										: in		std_logic;
		ClockNetwork_Reset					: in		std_logic;
		ClockNetwork_ResetDone			: out		std_logic;
		SATA_Clock									: out		std_logic;
		SATA_Clock_Stable						: out		std_logic;
		Reset												: in		std_logic;
		ResetDone										: out		std_logic;

		-- Config interface
		SATAGenerationMin						: in		T_SATA_GENERATION;
		SATAGenerationMax						: in		T_SATA_GENERATION;
		SATAGeneration							: out		T_SATA_GENERATION;
		Config_BurstSize						: in		T_SLV_16;									-- for measurement purposes only
		DriveInformation						: out		T_SATA_DRIVE_INFORMATION;
		IDF_Bus											: out		T_SATA_IDF_BUS;

		-- ATA StreamingLayer interface
		Command											: in		T_SATA_STREAMING_COMMAND;
		Status											: out		T_SATA_STREAMINGSTACK_STATUS;
		Error												: out		T_SATA_STREAMINGSTACK_ERROR;
		-- address
		Address_LB									: in		T_SLV_48;
		BlockCount_LB								: in		T_SLV_48;
		-- TX path
		TX_Valid										: in		std_logic;
		TX_Data											: in		T_SLV_32;
		TX_SOR											: in		std_logic;
		TX_EOR											: in		std_logic;
		TX_Ack											: out		std_logic;
		-- RX path
		RX_Valid										: out		std_logic;
		RX_Data											: out		T_SLV_32;
		RX_SOR											: out		std_logic;
		RX_EOR											: out		std_logic;
		RX_Ack											: in		std_logic;

		-- Debug ports
		DebugPortIn									: in		T_SATADBG_STREAMINGSTACK_IN;
		DebugPortOut								: out		T_SATADBG_STREAMINGSTACK_OUT;

		-- vendor specific ports
		SATA_Common_In							: in		T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		SATA_Private_In							: in		T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS;
		SATA_Private_Out						: out		T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS
	);
end entity;


architecture rtl of sata_StreamingStack is
	attribute KEEP											: boolean;
	attribute ENUM_ENCODING							: string;

	-- ===========================================================================
	-- StreamDBStack configuration
	-- ===========================================================================
	constant PORTS											: positive							:= 1;
	constant CONTROLLER_TYPE						: T_SATA_DEVICE_TYPE		:= SATA_DEVICE_TYPE_HOST;
	constant ENABLE_TRANS_GLUE_FIFOS		: boolean								:= FALSE;

	-- ===========================================================================
	-- signal declarations
	-- ===========================================================================
	signal ClockNetwork_ResetDone_i 		: std_logic;

	-- SATAController signals
	-- ===========================================================================
--	signal SATAGeneration_i							: T_SATA_GENERATION;

	-- StreamingLayer
	-- ================================================================
	-- clock and reset signals
	signal SATASC_ResetDone 						: std_logic;

	-- CSE signals
	signal SATASC_Status								: T_SATA_STREAMING_STATUS;
	signal SATASC_Error									: T_SATA_STREAMING_ERROR;
	signal SATASC_SATAC_Command					: T_SATA_TRANS_COMMAND;
	signal SATASC_ATAHostRegisters 			: T_SATA_ATA_HOST_REGISTERS;

	-- signals to lower layer
	signal SATASC_TX_Valid							: std_logic;
	signal SATASC_TX_Data								: T_SLV_32;
	signal SATASC_TX_SOT								: std_logic;
	signal SATASC_TX_EOT								: std_logic;
	signal SATASC_RX_Ack								: std_logic;

	-- SATA Controller
	-- ================================================================
	-- clock and reset signals
	signal SATAC_Clock									: std_logic;
	signal SATAC_Clock_Stable						: std_logic;
	signal SATAC_ResetDone							: std_logic;

	-- CSE signals
	signal SATAC_Status									: T_SATA_SATACONTROLLER_STATUS;
	signal SATAC_Error									: T_SATA_SATACONTROLLER_ERROR;
	signal SATAC_ATADeviceRegisters 		: T_SATA_ATA_DEVICE_REGISTERS;

	signal SATAC_SATAGeneration					: T_SATA_GENERATION;

	-- signals to upper layer
	signal SATAC_TX_Ack									: std_logic;
	signal SATAC_RX_SOT									: std_logic;
	signal SATAC_RX_EOT									: std_logic;
	signal SATAC_RX_Valid								: std_logic;
	signal SATAC_RX_Data								: T_SLV_32;

	-- DebugPort
	-- ================================================================
	signal SATAC_DebugPortIn		: T_SATADBG_SATACONTROLLER_IN;
	signal SATAC_DebugPortOut		: T_SATADBG_SATACONTROLLER_OUT;
--	signal SATASC_DebugPortIn		: T_SATADBG_SATASC_IN;
	signal SATASC_DebugPortOut	: T_SATADBG_STREAMING_OUT;

begin
	assert FALSE report "sata_StreamingStack configuration:"																					severity NOTE;
	assert FALSE report "  Ports:                  " & integer'image(PORTS)														severity NOTE;
	assert FALSE report "  Debug:                  " & to_string(DEBUG)																severity NOTE;
	assert FALSE report "  Enable DebugPort:       " & to_string(ENABLE_DEBUGPORT)										severity NOTE;
	assert FALSE report "  ClockIn Frequency:      " & to_string(REFCLOCK_FREQ, 3)										severity NOTE;
	assert FALSE report "  ControllerType:         " & T_SATA_DEVICE_TYPE'image(CONTROLLER_TYPE)			severity NOTE;
	assert FALSE report "  Init. SATA Generation:  Gen" & integer'image(INITIAL_SATA_GENERATION + 1)	severity NOTE;
	assert FALSE report "  AllowSpeedNegotiation:  " & to_string(ALLOW_SPEED_NEGOTIATION)							severity NOTE;
	assert FALSE report "  LogicalBlockSize (App): " & to_string(LOGICAL_BLOCK_SIZE, 3)								severity NOTE;
	assert FALSE report "  Enable TransGlueFIFOs:  " & to_string(ENABLE_TRANS_GLUE_FIFOS)							severity NOTE;

	-- Main interface outputs
	-- ===========================================================================
	SATA_Clock							<= SATAC_Clock;
	SATA_Clock_Stable				<= SATAC_Clock_Stable;
	ClockNetwork_ResetDone	<= ClockNetwork_ResetDone_i;
	ResetDone 							<= SATASC_ResetDone;
	SATAGeneration					<= SATAC_SATAGeneration;

	-- assign status record
	Status.StreamingLayer 	<= SATASC_Status;
	Status.TransportLayer		<= SATAC_Status.TransportLayer;
	Status.LinkLayer				<= SATAC_Status.LinkLayer;
	Status.PhysicalLayer		<= SATAC_Status.PhysicalLayer;
	Status.TransceiverLayer	<= SATAC_Status.TransceiverLayer;

	-- assign error record
	Error.StreamingLayer 		<= SATASC_Error;
	Error.TransportLayer		<= SATAC_Error.TransportLayer;
	Error.LinkLayer					<= SATAC_Error.LinkLayer;
	Error.PhysicalLayer			<= SATAC_Error.PhysicalLayer;
	Error.TransceiverLayer	<= SATAC_Error.TransceiverLayer;

	Stream : entity PoC.sata_StreamingLayer
		generic map (
			DEBUG											=> DEBUG,
			ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
			LOGICAL_BLOCK_SIZE				=> LOGICAL_BLOCK_SIZE
		)
		port map (
			Clock											=> SATAC_Clock,
			ClockEnable 							=> SATAC_Clock_Stable,
			Reset											=> Reset,

			-- for measurement purposes only
			Config_BurstSize					=> Config_BurstSize,

			-- StreamingLayer interface
			Command										=> Command,
			Status										=> SATASC_Status,
			Error											=> SATASC_Error,
			Address_AppLB							=> Address_LB,
			BlockCount_AppLB					=> BlockCount_LB,

			-- debug ports
			DebugPortOut							=> SATASC_DebugPortOut,
			DriveInformation					=> DriveInformation,
			IDF_Bus										=> IDF_Bus,

			-- TX path
			TX_Valid									=> TX_Valid,
			TX_Data										=> TX_Data,
			TX_SOR										=> TX_SOR,
			TX_EOR										=> TX_EOR,
			TX_Ack										=> TX_Ack,
			-- RX path
			RX_Valid									=> RX_Valid,
			RX_Data										=> RX_Data,
			RX_SOR										=> RX_SOR,
			RX_EOR										=> RX_EOR,
			RX_Ack										=> RX_Ack,

			-- SATAController interface
			Trans_ResetDone 					=> SATAC_ResetDone, -- input from lower layer
			Trans_Command							=> SATASC_SATAC_Command,
			Trans_Status							=> SATAC_Status.TransportLayer,
			Trans_Error								=> SATAC_Error.TransportLayer,

			Trans_ATAHostRegisters 		=> SATASC_ATAHostRegisters,
			Trans_ATADeviceRegisters 	=> SATAC_ATADeviceRegisters,

			-- TX data port
			Trans_TX_SOT							=> SATASC_TX_SOT,
			Trans_TX_EOT							=> SATASC_TX_EOT,
			Trans_TX_Valid						=> SATASC_TX_Valid,
			Trans_TX_Data							=> SATASC_TX_Data,
			Trans_TX_Ack							=> SATAC_TX_Ack,
			-- RX port
			Trans_RX_SOT							=> SATAC_RX_SOT,
			Trans_RX_EOT							=> SATAC_RX_EOT,
			Trans_RX_Valid						=> SATAC_RX_Valid,
			Trans_RX_Data							=> SATAC_RX_Data,
			Trans_RX_Ack							=> SATASC_RX_Ack
		);

	-- The interface of the SATASC is ready when the SATAC-interface is ready.
	SATASC_ResetDone <= SATAC_ResetDone;

	SATAC : entity PoC.sata_SATAController
		generic map (
			DEBUG													=> DEBUG,
			ENABLE_DEBUGPORT							=> ENABLE_DEBUGPORT,
			REFCLOCK_FREQ									=> REFCLOCK_FREQ,
			REFCLOCK_SOURCE								=> REFCLOCK_SOURCE,
			PORTS													=> 1,
			CONTROLLER_TYPES(0)						=> SATA_DEVICE_TYPE_HOST,
			INITIAL_SATA_GENERATIONS(0)		=> INITIAL_SATA_GENERATION,
			ALLOW_SPEED_NEGOTIATION(0)		=> ALLOW_SPEED_NEGOTIATION,
			ALLOW_STANDARD_VIOLATION(0)		=> TRUE,
			AHEAD_CYCLES_FOR_INSERT_EOF(0)=> 1,	-- requirement from StreamingLayer
			ENABLE_GLUE_FIFOS(0)					=> ENABLE_TRANS_GLUE_FIFOS
		)
		port map (
			ClockNetwork_Reset(0)					=> ClockNetwork_Reset,
			ClockNetwork_ResetDone(0)			=> ClockNetwork_ResetDone_i,
			PowerDown(0)									=> PowerDown,
			Reset(0)											=> Reset,
			ResetDone(0)									=> SATAC_ResetDone,

			SATA_Clock(0)									=> SATAC_Clock,
			SATA_Clock_Stable(0)					=> SATAC_Clock_Stable,
			-- CSE interface
			Command(0)										=> SATASC_SATAC_Command,
			Status(0)											=> SATAC_Status,
			Error(0)											=> SATAC_Error,
			ATAHostRegisters(0) 					=> SATASC_ATAHostRegisters,
			ATADeviceRegisters(0) 				=> SATAC_ATADeviceRegisters,

			-- Config interface
			SATAGenerationMin(0)					=> SATAGenerationMin,
			SATAGenerationMax(0)					=> SATAGenerationMax,
			SATAGeneration(0)							=> SATAC_SATAGeneration,

			-- debug ports
			DebugPortIn(0)								=> SATAC_DebugPortIn,
			DebugPortOut(0)								=> SATAC_DebugPortOut,

			-- TX port
			TX_Valid(0)										=> SATASC_TX_Valid,
			TX_SOT(0)											=> SATASC_TX_SOT,
			TX_EOT(0)											=> SATASC_TX_EOT,
			TX_Data(0)										=> SATASC_TX_Data,
			TX_Ack(0)											=> SATAC_TX_Ack,
			-- RX port
			RX_Valid(0)										=> SATAC_RX_Valid,
			RX_SOT(0)											=> SATAC_RX_SOT,
			RX_EOT(0)											=> SATAC_RX_EOT,
			RX_Data(0)										=> SATAC_RX_Data,
			RX_Ack(0)											=> SATASC_RX_Ack,

			-- vendor specific signals
			VSS_Common_In									=> SATA_Common_In,
			VSS_Private_In(0)							=> SATA_Private_In,
			VSS_Private_Out(0)						=> SATA_Private_Out
		);

	-- ===========================================================================
	-- DebugPorts
	-- ===========================================================================
	genNoDebug : if (ENABLE_DEBUGPORT = FALSE) generate
	begin
		-- assign default values to debugport (empty)
		SATAC_DebugPortIn.TransceiverLayer			<= C_SATADBG_TRANSCEIVER_IN_EMPTY;
		SATAC_DebugPortIn.LinkLayer							<= C_SATADBG_LINK_IN_EMPTY;

		DebugPortOut 														<= C_SATADBG_STREAMINGSTACK_OUT_EMPTY;
	end generate;
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
	begin
		-- assign debug ports
		SATAC_DebugPortIn.TransceiverLayer			<= DebugPortIn.TransceiverLayer;
		SATAC_DebugPortIn.LinkLayer							<= DebugPortIn.LinkLayer;

		DebugPortOut.TransceiverLayer						<= SATAC_DebugPortOut.TransceiverLayer;
		DebugPortOut.Transceiver_Command				<= SATAC_DebugPortOut.Transceiver_Command;
		DebugPortOut.Transceiver_Status					<= SATAC_DebugPortOut.Transceiver_Status;
		DebugPortOut.Transceiver_Error					<= SATAC_DebugPortOut.Transceiver_Error;

		DebugPortOut.PhysicalLayer							<= SATAC_DebugPortOut.PhysicalLayer;
		DebugPortOut.Physical_Command						<= SATAC_DebugPortOut.Physical_Command;
		DebugPortOut.Physical_Status						<= SATAC_DebugPortOut.Physical_Status;
		DebugPortOut.Physical_Error							<= SATAC_DebugPortOut.Physical_Error;

		DebugPortOut.LinkLayer									<= SATAC_DebugPortOut.LinkLayer;
		DebugPortOut.Link_Command								<= SATAC_DebugPortOut.Link_Command;
		DebugPortOut.Link_Status								<= SATAC_DebugPortOut.Link_Status;
		DebugPortOut.Link_Error									<= SATAC_DebugPortOut.Link_Error;

		DebugPortOut.TransportLayer							<= SATAC_DebugPortOut.TransportLayer;
		DebugPortOut.Transport_Command					<= SATAC_DebugPortOut.Transport_Command;
		DebugPortOut.Transport_Status						<= SATAC_DebugPortOut.Transport_Status;
		DebugPortOut.Transport_Error						<= SATAC_DebugPortOut.Transport_Error;

		DebugPortOut.StreamingLayer							<= SATASC_DebugPortOut;
		DebugPortOut.Streaming_Command					<= SATASC_DebugPortOut.Command;
		DebugPortOut.Streaming_Status						<= SATASC_DebugPortOut.Status;
		DebugPortOut.Streaming_Error						<= SATASC_DebugPortOut.Error;
	end generate;
end architecture;
