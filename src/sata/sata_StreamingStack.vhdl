-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
--
-- Package:					TODO
--
-- Description:
-- ------------------------------------
--		TODO
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
use			PoC.satadbg.all;
use			PoC.sata_TransceiverTypes.all;
use			PoC.xil.all;


entity sata_StreamingStack is
	generic (
		DEBUG												: BOOLEAN;
		ENABLE_CHIPSCOPE						: BOOLEAN;
		ENABLE_DEBUGPORT						: BOOLEAN;

		REFCLOCK_FREQ								: FREQ;
		INITIAL_SATA_GENERATION			: T_SATA_GENERATION;
		ALLOW_SPEED_NEGOTIATION			: BOOLEAN;
		LOGICAL_BLOCK_SIZE					: MEMORY
	);
	port (
		-- SATA stack common interface
		PowerDown										: in		STD_LOGIC;
		ClockNetwork_Reset					: in		STD_LOGIC;
		ClockNetwork_ResetDone			: out		STD_LOGIC;
		SATA_Clock									: out		STD_LOGIC;
		SATA_Clock_Stable						: out		STD_LOGIC;
		Reset												: in		STD_LOGIC;
		ResetDone										: out		STD_LOGIC;
		
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
		TX_Valid										: in		STD_LOGIC;
		TX_Data											: in		T_SLV_32;
		TX_SOR											: in		STD_LOGIC;
		TX_EOR											: in		STD_LOGIC;
		TX_Ack											: out		STD_LOGIC;
		-- RX path
		RX_Valid										: out		STD_LOGIC;
		RX_Data											: out		T_SLV_32;
		RX_SOR											: out		STD_LOGIC;
		RX_EOR											: out		STD_LOGIC;
		RX_Ack											: in		STD_LOGIC;
			
		-- Debug ports	
		DebugPortIn									: in		T_SATADBG_STREAMINGSTACK_IN;
		DebugPortOut								: out		T_SATADBG_STREAMINGSTACK_OUT;

		-- ChipScope ports
		DebugClock											: in		STD_LOGIC;
--		TransMonitor_ILA_ControlBus			: inout	T_XIL_CHIPSCOPE_CONTROL;
		TransceiverLayer_ILA_ControlBus	: inout	T_XIL_CHIPSCOPE_CONTROL;
		PhyLayer_ILA_ControlBus					: inout	T_XIL_CHIPSCOPE_CONTROL;
		LinkLayer_ILA_ControlBus				: inout	T_XIL_CHIPSCOPE_CONTROL;
		TransportLayer_ILA_ControlBus		: inout	T_XIL_CHIPSCOPE_CONTROL;
		CommandLayer_ILA_ControlBus			: inout	T_XIL_CHIPSCOPE_CONTROL;
		SoFPGA_Tracer_TriggerEvent			: in		STD_LOGIC;
			
		-- vendor specific ports	
		SATA_Common_In							: in		T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		SATA_Private_In							: in		T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS;
		SATA_Private_Out						: out		T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS
	);
end entity;


architecture rtl of sata_StreamingStack is
	attribute KEEP											: BOOLEAN;
	attribute ENUM_ENCODING							: STRING;

	-- ===========================================================================
	-- StreamDBStack configuration
	-- ===========================================================================
	constant PORTS											: POSITIVE							:= 1;
	constant CONTROLLER_TYPE						: T_SATA_DEVICE_TYPE		:= SATA_DEVICE_TYPE_HOST;
	constant ENABLE_TRANS_GLUE_FIFOS		: BOOLEAN								:= FALSE;
	
	-- ===========================================================================
	-- signal declarations
	-- ===========================================================================
	signal ClockNetwork_ResetDone_i 		: STD_LOGIC;
	
	-- SATAController signals
	-- ===========================================================================
--	signal SATAGeneration_i							: T_SATA_GENERATION;
	
	-- StreamingLayer
	-- ================================================================
	-- clock and reset signals
	signal SATASC_ResetDone 						: STD_LOGIC;
	
	-- CSE signals
	signal SATASC_Status								: T_SATA_STREAMING_STATUS;
	signal SATASC_Error									: T_SATA_STREAMING_ERROR;
	signal SATASC_SATAC_Command					: T_SATA_TRANS_COMMAND;
	signal SATASC_ATAHostRegisters 			: T_SATA_ATA_HOST_REGISTERS;
	
	-- signals to lower layer
	signal SATASC_TX_Valid							: STD_LOGIC;
	signal SATASC_TX_Data								: T_SLV_32;
	signal SATASC_TX_SOT								: STD_LOGIC;
	signal SATASC_TX_EOT								: STD_LOGIC;
	signal SATASC_RX_Ack								: STD_LOGIC;

	-- SATA Controller
	-- ================================================================
	-- clock and reset signals
	signal SATAC_Clock									: STD_LOGIC;
	signal SATAC_Clock_Stable						: STD_LOGIC;
	signal SATAC_ResetDone							: STD_LOGIC;
	
	-- CSE signals	
	signal SATAC_Status									: T_SATA_SATACONTROLLER_STATUS;
	signal SATAC_Error									: T_SATA_SATACONTROLLER_ERROR;
	signal SATAC_ATADeviceRegisters 		: T_SATA_ATA_DEVICE_REGISTERS;
	
	signal SATAC_SATAGeneration					: T_SATA_GENERATION;
	
	-- signals to upper layer					
	signal SATAC_TX_Ack									: STD_LOGIC;
	signal SATAC_RX_SOT									: STD_LOGIC;
	signal SATAC_RX_EOT									: STD_LOGIC;
	signal SATAC_RX_Valid								: STD_LOGIC;
	signal SATAC_RX_Data								: T_SLV_32;
	
	-- DebugPort
	-- ================================================================
	signal SATAC_DebugPortIn		: T_SATADBG_SATACONTROLLER_IN;
	signal SATAC_DebugPortOut		: T_SATADBG_SATACONTROLLER_OUT;
--	signal SATASC_DebugPortIn		: T_SATADBG_SATASC_IN;
	signal SATASC_DebugPortOut	: T_SATADBG_STREAMING_OUT;
	signal SATAS_DebugPortOut		: T_SATADBG_STREAMINGSTACK_OUT;
	
begin
	assert FALSE report "sata_StreamingStack configuration:"																					severity NOTE;
	assert FALSE report "  Ports:                  " & INTEGER'image(PORTS)														severity NOTE;
	assert FALSE report "  Debug:                  " & to_string(DEBUG)																severity NOTE;
	assert FALSE report "  Enable ChipScope:       " & to_string(ENABLE_CHIPSCOPE)										severity NOTE;
	assert FALSE report "  Enable DebugPort:       " & to_string(ENABLE_DEBUGPORT)										severity NOTE;
	assert FALSE report "  ClockIn Frequency:      " & to_string(REFCLOCK_FREQ, 3)										severity NOTE;
	assert FALSE report "  ControllerType:         " & T_SATA_DEVICE_TYPE'image(CONTROLLER_TYPE)			severity NOTE;
	assert FALSE report "  Init. SATA Generation:  Gen" & INTEGER'image(INITIAL_SATA_GENERATION + 1)	severity NOTE;
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
	end generate;
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
	begin
		-- assign debug ports
		SATAC_DebugPortIn.TransceiverLayer			<= DebugPortIn.TransceiverLayer;
		SATAC_DebugPortIn.LinkLayer							<= DebugPortIn.LinkLayer;
	
		SATAS_DebugPortOut.TransceiverLayer			<= SATAC_DebugPortOut.TransceiverLayer;
		SATAS_DebugPortOut.Transceiver_Command	<= SATAC_DebugPortOut.Transceiver_Command;
		SATAS_DebugPortOut.Transceiver_Status		<= SATAC_DebugPortOut.Transceiver_Status;
		SATAS_DebugPortOut.Transceiver_Error		<= SATAC_DebugPortOut.Transceiver_Error;
		
		SATAS_DebugPortOut.PhysicalLayer				<= SATAC_DebugPortOut.PhysicalLayer;
		SATAS_DebugPortOut.Physical_Command			<= SATAC_DebugPortOut.Physical_Command;
		SATAS_DebugPortOut.Physical_Status			<= SATAC_DebugPortOut.Physical_Status;
		SATAS_DebugPortOut.Physical_Error				<= SATAC_DebugPortOut.Physical_Error;
		
		SATAS_DebugPortOut.LinkLayer						<= SATAC_DebugPortOut.LinkLayer;
		SATAS_DebugPortOut.Link_Command					<= SATAC_DebugPortOut.Link_Command;
		SATAS_DebugPortOut.Link_Status					<= SATAC_DebugPortOut.Link_Status;
		SATAS_DebugPortOut.Link_Error						<= SATAC_DebugPortOut.Link_Error;
		
		SATAS_DebugPortOut.TransportLayer				<= SATAC_DebugPortOut.TransportLayer;
		SATAS_DebugPortOut.Transport_Command		<= SATAC_DebugPortOut.Transport_Command;
		SATAS_DebugPortOut.Transport_Status			<= SATAC_DebugPortOut.Transport_Status;
		SATAS_DebugPortOut.Transport_Error			<= SATAC_DebugPortOut.Transport_Error;
		
		SATAS_DebugPortOut.StreamingLayer				<= SATASC_DebugPortOut;
		SATAS_DebugPortOut.Streaming_Command		<= SATASC_DebugPortOut.Command;
		SATAS_DebugPortOut.Streaming_Status			<= SATASC_DebugPortOut.Status;
		SATAS_DebugPortOut.Streaming_Error			<= SATASC_DebugPortOut.Error;

		DebugPortOut														<= SATAS_DebugPortOut;
	end generate;
	genChipScopeComplete : if (ENABLE_CHIPSCOPE = TRUE) generate
		signal DebugPortIn_TriggerEvent 		: STD_LOGIC;
		
		signal TransceiverILA_Trigger0			: STD_LOGIC_VECTOR(29 downto 0);
		signal TransceiverILA_TriggerEvent	: STD_LOGIC;

		signal PhyILA_Data						: STD_LOGIC_VECTOR(150 downto 0);
		signal PhyILA_Trigger0				: STD_LOGIC_VECTOR(7 downto 0);
		signal PhyILA_Trigger1				: STD_LOGIC_VECTOR(35 downto 0);
		signal PhyILA_Trigger2				: STD_LOGIC_VECTOR(35 downto 0);
		signal PhyILA_Trigger3				: STD_LOGIC_VECTOR(25 downto 0);
		signal PhyILA_Trigger4				: STD_LOGIC_VECTOR(12 downto 0);
		signal PhyILA_TriggerEvent		: STD_LOGIC;

		signal PhyILA_Data_d					: STD_LOGIC_VECTOR(150 downto 0)	:= (others => '0');
		signal PhyILA_Trigger0_d			: STD_LOGIC_VECTOR(7 downto 0)		:= (others => '0');
		signal PhyILA_Trigger1_d			: STD_LOGIC_VECTOR(35 downto 0)		:= (others => '0');
		signal PhyILA_Trigger2_d			: STD_LOGIC_VECTOR(35 downto 0)		:= (others => '0');
		signal PhyILA_Trigger3_d			: STD_LOGIC_VECTOR(25 downto 0)		:= (others => '0');
		signal PhyILA_Trigger4_d			: STD_LOGIC_VECTOR(12 downto 0)		:= (others => '0');

		signal LinkILA_Data						: STD_LOGIC_VECTOR(253 downto 0);
		signal LinkILA_Trigger0				: STD_LOGIC_VECTOR(7 downto 0);
		signal LinkILA_Trigger1				: STD_LOGIC_VECTOR(39 downto 0);
		signal LinkILA_Trigger2				: STD_LOGIC_VECTOR(35 downto 0);
		signal LinkILA_Trigger3				: STD_LOGIC_VECTOR(39 downto 0);
		signal LinkILA_Trigger4				: STD_LOGIC_VECTOR(35 downto 0);
		signal LinkILA_Trigger5				: STD_LOGIC_VECTOR(15 downto 0);
		signal LinkILA_Trigger6				: STD_LOGIC_VECTOR(15 downto 0);
		signal LinkILA_TriggerEvent		: STD_LOGIC;
		
		signal LinkILA_Data_d					: STD_LOGIC_VECTOR(253 downto 0)	:= (others => '0');
		signal LinkILA_Trigger0_d			: STD_LOGIC_VECTOR(7 downto 0)		:= (others => '0');
		signal LinkILA_Trigger1_d			: STD_LOGIC_VECTOR(39 downto 0)		:= (others => '0');
		signal LinkILA_Trigger2_d			: STD_LOGIC_VECTOR(35 downto 0)		:= (others => '0');
		signal LinkILA_Trigger3_d			: STD_LOGIC_VECTOR(39 downto 0)		:= (others => '0');
		signal LinkILA_Trigger4_d			: STD_LOGIC_VECTOR(35 downto 0)		:= (others => '0');
		signal LinkILA_Trigger5_d			: STD_LOGIC_VECTOR(15 downto 0)		:= (others => '0');
		signal LinkILA_Trigger6_d			: STD_LOGIC_VECTOR(15 downto 0)		:= (others => '0');

		signal TransILA_Data					: STD_LOGIC_VECTOR(180 downto 0);
		signal TransILA_Trigger0			: STD_LOGIC_VECTOR(7 downto 0);
		signal TransILA_Trigger1			: STD_LOGIC_VECTOR(35 downto 0);
		signal TransILA_Trigger2			: STD_LOGIC_VECTOR(13 downto 0);
		signal TransILA_Trigger3			: STD_LOGIC_VECTOR(13 downto 0);
		signal TransILA_Trigger4			: STD_LOGIC_VECTOR(25 downto 0);
		signal TransILA_Trigger5			: STD_LOGIC_VECTOR(19 downto 0);
		signal TransILA_TriggerEvent	: STD_LOGIC;
		
		signal TransILA_Data_d				: STD_LOGIC_VECTOR(180 downto 0)	:= (others => '0');
		signal TransILA_Trigger0_d		: STD_LOGIC_VECTOR(7 downto 0)		:= (others => '0');
		signal TransILA_Trigger1_d		: STD_LOGIC_VECTOR(35 downto 0)		:= (others => '0');
		signal TransILA_Trigger2_d		: STD_LOGIC_VECTOR(13 downto 0)		:= (others => '0');
		signal TransILA_Trigger3_d		: STD_LOGIC_VECTOR(13 downto 0)		:= (others => '0');
		signal TransILA_Trigger4_d		: STD_LOGIC_VECTOR(25 downto 0)		:= (others => '0');
		signal TransILA_Trigger5_d		: STD_LOGIC_VECTOR(19 downto 0)		:= (others => '0');

		signal Stream_Data						: STD_LOGIC_VECTOR(183 downto 0);
		signal Stream_Trigger0				: STD_LOGIC_VECTOR(7 downto 0);
		signal Stream_Trigger1				: STD_LOGIC_VECTOR(35 downto 0);
		signal Stream_Trigger2				: STD_LOGIC_VECTOR(8 downto 0);
		signal Stream_Trigger3				: STD_LOGIC_VECTOR(4 downto 0);
		signal Stream_Trigger4				: STD_LOGIC_VECTOR(7 downto 0);
		signal Stream_Trigger5				: STD_LOGIC_VECTOR(35 downto 0);
		signal Stream_Trigger6				: STD_LOGIC_VECTOR(37 downto 0);
		signal Stream_TriggerEvent		: STD_LOGIC;
		
		signal Stream_Data_d					: STD_LOGIC_VECTOR(183 downto 0)	:= (others => '0');
		signal Stream_Trigger0_d			: STD_LOGIC_VECTOR(7 downto 0)		:= (others => '0');
		signal Stream_Trigger1_d			: STD_LOGIC_VECTOR(35 downto 0)		:= (others => '0');
		signal Stream_Trigger2_d			: STD_LOGIC_VECTOR(8 downto 0)		:= (others => '0');
		signal Stream_Trigger3_d			: STD_LOGIC_VECTOR(4 downto 0)		:= (others => '0');
		signal Stream_Trigger4_d			: STD_LOGIC_VECTOR(7 downto 0)		:= (others => '0');
		signal Stream_Trigger5_d			: STD_LOGIC_VECTOR(35 downto 0)		:= (others => '0');
		signal Stream_Trigger6_d			: STD_LOGIC_VECTOR(37 downto 0)		:= (others => '0');

		function dbg_EncodePrimitive(Data : T_SLV_32; CharIsK : T_SLV_4) return T_SLV_2 is
		begin
			case to_sata_primitive(Data, CharIsK, DetectDialTone => TRUE) is
				when SATA_PRIMITIVE_NONE =>				return "00";
				when SATA_PRIMITIVE_ALIGN =>			return "01";
				when SATA_PRIMITIVE_SYNC =>				return "10";
				when SATA_PRIMITIVE_DIAL_TONE =>	return "11";
				when others =>										return "00";
			end case;
		end function;

		function dbg_EncodeOOB(oob : T_SATA_OOB) return T_SLV_2 is
		begin
			case oob is
				when SATA_OOB_NONE =>			return "00";
				when SATA_OOB_READY =>		return "01";
				when SATA_OOB_COMRESET =>	return "10";
				when SATA_OOB_COMWAKE =>	return "11";
				when others =>						return "00";
			end case;
		end function;

		function dbg_EncodeFISType(FISType : T_SATA_FISTYPE) return STD_LOGIC_VECTOR is
		begin
			return to_slv(T_SATA_FISTYPE'pos(FISType), log2ceilnz(T_SATA_FISTYPE'pos(T_SATA_FISTYPE'high) + 1));
		end function;

		signal LinkILA_RX_Data				: std_logic_vector(124 downto 0);
		signal LinkILA_RX_Trigger0		: std_logic_vector(7 downto 0);
		signal LinkILA_RX_Trigger1		: std_logic_vector(7 downto 0);
		signal LinkILA_RX_Trigger2		: std_logic_vector(7 downto 0);
		signal LinkILA_RX_Trigger3		: std_logic_vector(7 downto 0);

		signal clocktest												: STD_LOGIC			:= '0';
	begin
		DebugPortIn_TriggerEvent <= DebugPortIn.TransceiverLayer.InsertBitErrorTX or DebugPortIn.TransceiverLayer.InsertBitErrorRX or DebugPortIn.LinkLayer.InsertBitErrorHeaderTX;
		
		clocktest <= fftre(q => clocktest, t => '1') when rising_edge(SATAC_Clock);
		
		TransceiverILA_Trigger0(0)						<=				SATAS_DebugPortOut.TransceiverLayer.PowerDown;
		TransceiverILA_Trigger0(1)						<=				SATAS_DebugPortOut.TransceiverLayer.ClockNetwork_Reset;
		TransceiverILA_Trigger0(2)						<=				SATAS_DebugPortOut.TransceiverLayer.ClockNetwork_ResetDone;
		TransceiverILA_Trigger0(3)						<=				SATAS_DebugPortOut.TransceiverLayer.Reset;
		TransceiverILA_Trigger0(4)						<=				SATAS_DebugPortOut.TransceiverLayer.ResetDone;
		TransceiverILA_Trigger0(6 downto 5)		<= to_slv(SATAS_DebugPortOut.Transceiver_Command);
		TransceiverILA_Trigger0(10 downto 7)	<= '0' & to_slv(SATAS_DebugPortOut.Transceiver_Status);
		TransceiverILA_Trigger0(11)						<=				SATAS_DebugPortOut.TransceiverLayer.UserClock_Stable;
		TransceiverILA_Trigger0(12)						<=				clocktest;
		TransceiverILA_Trigger0(13)						<=				SATAS_DebugPortOut.TransceiverLayer.GTX_CPLL_PowerDown;
		TransceiverILA_Trigger0(14)						<=				SATAS_DebugPortOut.TransceiverLayer.GTX_TX_PowerDown;
		TransceiverILA_Trigger0(15)						<=				SATAS_DebugPortOut.TransceiverLayer.GTX_CPLL_Reset;
		TransceiverILA_Trigger0(16)						<=				SATAS_DebugPortOut.TransceiverLayer.GTX_CPLL_Locked;
		TransceiverILA_Trigger0(17)						<=				SATAS_DebugPortOut.TransceiverLayer.GTX_TX_Reset;
		TransceiverILA_Trigger0(18)						<=				SATAS_DebugPortOut.TransceiverLayer.GTX_RX_Reset;
		TransceiverILA_Trigger0(19)						<=				SATAS_DebugPortOut.TransceiverLayer.GTX_TX_ResetDone;
		TransceiverILA_Trigger0(20)						<=				SATAS_DebugPortOut.TransceiverLayer.GTX_RX_ResetDone;
		TransceiverILA_Trigger0(24 downto 21)	<=				SATAS_DebugPortOut.TransceiverLayer.FSM;
		TransceiverILA_Trigger0(26 downto 25)	<= to_slv(SATAS_DebugPortOut.TransceiverLayer.RP_SATAGeneration, 2);
		TransceiverILA_Trigger0(29 downto 27)	<= 				SATAS_DebugPortOut.TransceiverLayer.TX_RateSelection;
--		TransceiverILA_Trigger0(30)						<= SATAS_DebugPortOut.TransceiverLayer.TX_RateSelectionDone;
--		TransceiverILA_Trigger0(33 downto 31)	<= SATAS_DebugPortOut.TransceiverLayer.RX_RateSelection;
--		TransceiverILA_Trigger0(34)						<= SATAS_DebugPortOut.TransceiverLayer.RX_RateSelectionDone;
--  	TransceiverILA_Trigger0(35)						<= SATAS_DebugPortOut.TransceiverLayer.RP_Reconfig;
--		TransceiverILA_Trigger0(36)						<= SATAS_DebugPortOut.TransceiverLayer.RP_ConfigRealoaded;
		
--		TransceiverILA_Trigger0(24)						<= SATAS_DebugPortOut.TransceiverLayer.DD_NoDevice;
--		TransceiverILA_Trigger0(25)						<= SATAS_DebugPortOut.TransceiverLayer.DD_NewDevice;
--		TransceiverILA_Trigger0(26)						<= SATAS_DebugPortOut.TransceiverLayer.RX_ElectricalIDLE;
--		TransceiverILA_Trigger0(28)						<= PhyILA_TriggerEvent;
		
		PhyILA_Data(31 downto 0)			<= SATAS_DebugPortOut.TransceiverLayer.TX_Data;
		PhyILA_Data(35 downto 32)			<= SATAS_DebugPortOut.TransceiverLayer.TX_CharIsK;
		PhyILA_Data(67 downto 36)			<= SATAS_DebugPortOut.TransceiverLayer.RX_Data;
		PhyILA_Data(71 downto 68)			<= SATAS_DebugPortOut.TransceiverLayer.RX_CharIsK;
		PhyILA_Data(75 downto 72)			<= SATAS_DebugPortOut.TransceiverLayer.RX_CharIsComma;
		PhyILA_Data(76)								<= SATAS_DebugPortOut.TransceiverLayer.RX_CommaDetected;
		PhyILA_Data(77)								<= SATAS_DebugPortOut.TransceiverLayer.RX_ByteIsAligned;
		PhyILA_Data(78)								<= SATAS_DebugPortOut.TransceiverLayer.RX_ElectricalIDLE;
		PhyILA_Data(79)								<= SATAS_DebugPortOut.TransceiverLayer.RX_ComInitDetected;
		PhyILA_Data(80)								<= SATAS_DebugPortOut.TransceiverLayer.RX_ComWakeDetected;
		PhyILA_Data(81)								<= SATAS_DebugPortOut.TransceiverLayer.RX_Valid;
		PhyILA_Data(84 downto 82)			<= SATAS_DebugPortOut.TransceiverLayer.RX_BufferStatus;
		PhyILA_Data(86 downto 85)			<= SATAS_DebugPortOut.TransceiverLayer.RX_ClockCorrectionStatus;
		PhyILA_Data(87)								<= SATAS_DebugPortOut.TransceiverLayer.TX_ComInit;
		PhyILA_Data(88)								<= SATAS_DebugPortOut.TransceiverLayer.TX_ComWake;
		PhyILA_Data(89)								<= SATAS_DebugPortOut.TransceiverLayer.TX_ComFinish;
		PhyILA_Data(90)								<= SATAS_DebugPortOut.TransceiverLayer.TX_ElectricalIDLE;
		PhyILA_Data(92 downto 91)			<= SATAS_DebugPortOut.TransceiverLayer.TX_BufferStatus;
		PhyILA_Data(96 downto 93)			<= SATAS_DebugPortOut.TransceiverLayer.RX_DisparityError;
		PhyILA_Data(100 downto 97)		<= SATAS_DebugPortOut.TransceiverLayer.RX_NotInTableError;
		
		PhyILA_Data(103 downto 101)		<= 							to_slv(SATAS_DebugPortOut.PhysicalLayer.PFSM.Status); 							-- 3 bit
		PhyILA_Data(105 downto 104)		<= 							to_slv(SATAS_DebugPortOut.PhysicalLayer.PFSM.Error); 								-- 2 bit
		PhyILA_Data(106) 							<= '0';
		PhyILA_Data(108 downto 107)		<= dbg_EncodePrimitive(SATAS_DebugPortOut.PhysicalLayer.TX_Data, SATAS_DebugPortOut.PhysicalLayer.TX_CharIsK);	-- 2 bit
		PhyILA_Data(110 downto 109)		<= dbg_EncodePrimitive(SATAS_DebugPortOut.PhysicalLayer.RX_Data, SATAS_DebugPortOut.PhysicalLayer.RX_CharIsK);	-- 2 bit
		PhyILA_Data(114 downto 111)		<=										 SATAS_DebugPortOut.PhysicalLayer.OOBControl.FSM;							-- 3 bit
		PhyILA_Data(115)							<=										 SATAS_DebugPortOut.PhysicalLayer.PFSM.OOBC_Reset;
		PhyILA_Data(116)							<= 										 SATAS_DebugPortOut.PhysicalLayer.OOBControl.DeviceOrHostDetected;
		PhyILA_Data(117)							<= 										 SATAS_DebugPortOut.PhysicalLayer.OOBControl.Timeout;
		PhyILA_Data(118)							<= 										 SATAS_DebugPortOut.PhysicalLayer.OOBControl.LinkOK;
		PhyILA_Data(119)							<= 										 SATAS_DebugPortOut.PhysicalLayer.OOBControl.LinkDead;
		PhyILA_Data(123 downto	120)	<=										 SATAS_DebugPortOut.PhysicalLayer.PFSM.FSM;										-- 4 bit
		PhyILA_Data(124) 							<= '0';
		PhyILA_Data(125)							<=										 SATAS_DebugPortOut.TransceiverLayer.GTX_RX_ResetDone;
		PhyILA_Data(127 downto	126)	<=							to_slv(SATAS_DebugPortOut.PhysicalLayer.PFSM.SATAGeneration, 2);
		PhyILA_Data(128)							<=										 SATAS_DebugPortOut.PhysicalLayer.PFSM.SATAGeneration_Reset;
		PhyILA_Data(129)							<=										 SATAS_DebugPortOut.PhysicalLayer.PFSM.SATAGeneration_Change;
		PhyILA_Data(130)							<=										 SATAS_DebugPortOut.PhysicalLayer.PFSM.SATAGeneration_Changed;
		PhyILA_Data(131)							<=										 SATAS_DebugPortOut.PhysicalLayer.PFSM.Trans_Reconfig;
		PhyILA_Data(132)							<= '0';
		PhyILA_Data(133)							<=										 SATAS_DebugPortOut.PhysicalLayer.PFSM.Trans_ConfigReloaded;
		PhyILA_Data(141 downto	134)	<=										 SATAS_DebugPortOut.PhysicalLayer.PFSM.TrysPerGeneration;
		PhyILA_Data(149 downto	142)	<=										 SATAS_DebugPortOut.PhysicalLayer.PFSM.GenerationChanges;		
		PhyILA_Data(150)							<=										 SATAS_DebugPortOut.TransceiverLayer.RX_CDR_Hold;
		
		PhyILA_Trigger0(0)						<= SATAS_DebugPortOut.TransceiverLayer.GTX_TX_ResetDone;
		PhyILA_Trigger0(1)						<= SATAS_DebugPortOut.TransceiverLayer.GTX_RX_ResetDone;
		PhyILA_Trigger0(2)						<= TransceiverILA_TriggerEvent;
		PhyILA_Trigger0(3)						<= SATAC_ResetDone; -- instead of PHY
		PhyILA_Trigger0(4)						<= LinkILA_TriggerEvent;
		PhyILA_Trigger0(5)						<= TransILA_TriggerEvent;
		PhyILA_Trigger0(6)						<= Stream_TriggerEvent;
		PhyILA_Trigger0(7)						<= DebugPortIn_TriggerEvent;
		
		PhyILA_Trigger1(31 downto 0)	<= SATAS_DebugPortOut.TransceiverLayer.TX_Data;
		PhyILA_Trigger1(35 downto 32)	<= SATAS_DebugPortOut.TransceiverLayer.TX_CharIsK;
		
		PhyILA_Trigger2(31 downto 0)	<= SATAS_DebugPortOut.TransceiverLayer.RX_Data;
		PhyILA_Trigger2(35 downto 32)	<= SATAS_DebugPortOut.TransceiverLayer.RX_CharIsK;

		PhyILA_Trigger3(0)						<= SATAS_DebugPortOut.TransceiverLayer.RX_CommaDetected;
		PhyILA_Trigger3(1)						<= SATAS_DebugPortOut.TransceiverLayer.RX_ByteIsAligned;
		PhyILA_Trigger3(2)						<= SATAS_DebugPortOut.TransceiverLayer.RX_ElectricalIDLE;
		PhyILA_Trigger3(3)						<= SATAS_DebugPortOut.TransceiverLayer.RX_ComInitDetected;
		PhyILA_Trigger3(4)						<= SATAS_DebugPortOut.TransceiverLayer.RX_ComWakeDetected;
		PhyILA_Trigger3(5)						<= SATAS_DebugPortOut.TransceiverLayer.RX_Valid;
		PhyILA_Trigger3(8 downto 6)		<= SATAS_DebugPortOut.TransceiverLayer.RX_BufferStatus;
		PhyILA_Trigger3(10 downto 9)	<= SATAS_DebugPortOut.TransceiverLayer.RX_ClockCorrectionStatus;
		PhyILA_Trigger3(11)						<= SATAS_DebugPortOut.TransceiverLayer.TX_ComInit;
		PhyILA_Trigger3(12)						<= SATAS_DebugPortOut.TransceiverLayer.TX_ComWake;
		PhyILA_Trigger3(13)						<= SATAS_DebugPortOut.TransceiverLayer.TX_ComFinish;
		PhyILA_Trigger3(14)						<= SATAS_DebugPortOut.TransceiverLayer.TX_ElectricalIDLE;
		PhyILA_Trigger3(15)						<=			 SATAS_DebugPortOut.PhysicalLayer.OOBControl.DeviceOrHostDetected;
		PhyILA_Trigger3(16)						<=			 SATAS_DebugPortOut.PhysicalLayer.OOBControl.Timeout;
		PhyILA_Trigger3(17)						<=			 SATAS_DebugPortOut.PhysicalLayer.OOBControl.LinkOK;
		PhyILA_Trigger3(18)						<=			 SATAS_DebugPortOut.PhysicalLayer.OOBControl.LinkDead;
		PhyILA_Trigger3(19)						<= to_sl(SATAS_DebugPortOut.PhysicalLayer.PFSM.Status = SATA_PHY_STATUS_ERROR);
		PhyILA_Trigger3(20)						<=			 SATAS_DebugPortOut.PhysicalLayer.OOBControl.OOB_HandshakeComplete;
		PhyILA_Trigger3(21)						<=			 SATAS_DebugPortOut.PhysicalLayer.PFSM.SATAGeneration_Reset;
		PhyILA_Trigger3(22)						<=			 SATAS_DebugPortOut.PhysicalLayer.PFSM.SATAGeneration_Change;
		PhyILA_Trigger3(23)						<=			 SATAS_DebugPortOut.PhysicalLayer.PFSM.Trans_Reconfig;
		PhyILA_Trigger3(24)						<=			 SATAS_DebugPortOut.PhysicalLayer.PFSM.Trans_ConfigReloaded;
		PhyILA_Trigger3(25)						<=			 SATAS_DebugPortOut.TransceiverLayer.GTX_RX_ResetDone;
		
		PhyILA_Trigger4( 3 downto	 0)	<=				SATAS_DebugPortOut.PhysicalLayer.PFSM.FSM;
		PhyILA_Trigger4( 7 downto	 4)	<=				SATAS_DebugPortOut.PhysicalLayer.OOBControl.FSM;
		PhyILA_Trigger4(10 downto	 8)	<= to_slv(SATAS_DebugPortOut.PhysicalLayer.PFSM.Status);
		PhyILA_Trigger4(12 downto	11)	<= to_slv(SATAS_DebugPortOut.PhysicalLayer.PFSM.SATAGeneration, 2);
		
		LinkILA_Data(4 downto 0)			<= SATAS_DebugPortOut.LinkLayer.LLFSM.FSM;
		LinkILA_Data(5)								<= SATAS_DebugPortOut.LinkLayer.TX_InsertEOF;
		LinkILA_Data(6)								<= SATAS_DebugPortOut.LinkLayer.RX_FIFO_rollback;
		LinkILA_Data(7)								<= SATAS_DebugPortOut.LinkLayer.RX_FIFO_commit;
		LinkILA_Data(8)								<= SATAS_DebugPortOut.LinkLayer.LLFSM.TX_IsLongFrame;
		-- from physical layer
		LinkILA_Data(9)								<= SATAS_DebugPortOut.LinkLayer.Phy_Ready;
		-- RX: from physical layer
		LinkILA_Data(41 downto 10)		<= SATAS_DebugPortOut.LinkLayer.RX_Phy_Data;
		LinkILA_Data(45 downto 42)		<= SATAS_DebugPortOut.LinkLayer.RX_Phy_CiK;
		-- RX: after primitive detector
		LinkILA_Data(50 downto 46)		<= to_slv(SATAS_DebugPortOut.LinkLayer.RX_Primitive);
		-- RX: after unscrambling
		LinkILA_Data(51)							<= SATAS_DebugPortOut.LinkLayer.RX_DataUnscrambler_rst;
		LinkILA_Data(52)							<= SATAS_DebugPortOut.LinkLayer.RX_DataUnscrambler_en;
		LinkILA_Data(84 downto 53)		<= SATAS_DebugPortOut.LinkLayer.RX_DataUnscrambler_DataOut;
		-- RX: CRC control
		LinkILA_Data(85)							<= SATAS_DebugPortOut.LinkLayer.RX_CRC_rst;
		LinkILA_Data(86)							<= SATAS_DebugPortOut.LinkLayer.RX_CRC_en;
		-- RX: DataRegisters
		LinkILA_Data(87)							<= SATAS_DebugPortOut.LinkLayer.RX_DataReg_shift;
		LinkILA_Data(88)							<= SATAS_DebugPortOut.LinkLayer.LLFSM.TX_RetryFailed;
		-- RX: before RX_FIFO
		LinkILA_Data(89)							<= SATAS_DebugPortOut.LinkLayer.RX_FIFO_SpaceAvailable;
		LinkILA_Data(90)							<= SATAS_DebugPortOut.LinkLayer.RX_FIFO_rst;
		LinkILA_Data(91)							<= SATAS_DebugPortOut.LinkLayer.RX_FIFO_put;
		LinkILA_Data(92)							<= SATAS_DebugPortOut.LinkLayer.RX_FSFIFO_rst;
		LinkILA_Data(93)							<= SATAS_DebugPortOut.LinkLayer.RX_FSFIFO_put;
		-- RX: after RX_FIFO
		LinkILA_Data(94)							<= SATAS_DebugPortOut.LinkLayer.RX_Valid;
		LinkILA_Data(126 downto 95)		<= SATAS_DebugPortOut.LinkLayer.RX_Data;
		LinkILA_Data(127)							<= SATAS_DebugPortOut.LinkLayer.RX_SOF;
		LinkILA_Data(128)							<= SATAS_DebugPortOut.LinkLayer.RX_EOF;
		LinkILA_Data(129)							<= SATAS_DebugPortOut.LinkLayer.RX_Ack;
		LinkILA_Data(130)							<= SATAS_DebugPortOut.LinkLayer.RX_FS_Valid;
		LinkILA_Data(131)							<= SATAS_DebugPortOut.LinkLayer.RX_FS_CRCOK;
		LinkILA_Data(132)							<= SATAS_DebugPortOut.LinkLayer.RX_FS_SyncEsc;
		LinkILA_Data(133)							<= SATAS_DebugPortOut.LinkLayer.RX_FS_Ack;
		-- TX: from Link Layer
		LinkILA_Data(134)							<= SATAS_DebugPortOut.LinkLayer.TX_Valid;
		LinkILA_Data(166 downto 135)	<= SATAS_DebugPortOut.LinkLayer.TX_Data;
		LinkILA_Data(167)							<= SATAS_DebugPortOut.LinkLayer.TX_SOF;
		LinkILA_Data(168)							<= SATAS_DebugPortOut.LinkLayer.TX_EOF;
		LinkILA_Data(169)							<= SATAS_DebugPortOut.LinkLayer.TX_Ack;
		LinkILA_Data(170)							<= SATAS_DebugPortOut.LinkLayer.TX_FS_Valid;
		LinkILA_Data(171)							<= SATAS_DebugPortOut.LinkLayer.TX_FS_SendOK;
		LinkILA_Data(172)							<= SATAS_DebugPortOut.LinkLayer.TX_FS_SyncEsc;
		LinkILA_Data(173)							<= SATAS_DebugPortOut.LinkLayer.TX_FS_Ack;
		-- TX: TXFIFO
		LinkILA_Data(174)							<= SATAS_DebugPortOut.LinkLayer.TX_FIFO_got;
		LinkILA_Data(175)							<= SATAS_DebugPortOut.LinkLayer.TX_FSFIFO_got;
		-- TX: CRC control
		LinkILA_Data(176)							<= SATAS_DebugPortOut.LinkLayer.TX_CRC_rst;
		LinkILA_Data(177)							<= SATAS_DebugPortOut.LinkLayer.TX_CRC_en;
		LinkILA_Data(178)							<= SATAS_DebugPortOut.LinkLayer.TX_CRC_mux;
		-- TX: after scrambling
		LinkILA_Data(179)							<= SATAS_DebugPortOut.LinkLayer.TX_DataScrambler_rst;
		LinkILA_Data(180)							<= SATAS_DebugPortOut.LinkLayer.TX_DataScrambler_en;
		LinkILA_Data(212 downto 181)	<= SATAS_DebugPortOut.LinkLayer.TX_DataScrambler_DataOut;
		-- TX: PrimitiveMux
		LinkILA_Data(217 downto 213)	<= to_slv(SATAS_DebugPortOut.LinkLayer.TX_Primitive);
		-- TX: to Physical Layer
		LinkILA_Data(249 downto 218)	<= SATAS_DebugPortOut.LinkLayer.TX_Phy_Data;
		LinkILA_Data(253 downto 250)	<= SATAS_DebugPortOut.LinkLayer.TX_Phy_CiK;
		
		-- LinkLayer Trigger
		LinkILA_Trigger0(0)							<= '0';		-- clkdone
		LinkILA_Trigger0(1)							<= '0';		-- rstdone
		LinkILA_Trigger0(2)							<= TransceiverILA_TriggerEvent;
		LinkILA_Trigger0(3)							<= PhyILA_TriggerEvent;
		LinkILA_Trigger0(4)							<= '0';	--LinkILA_TriggerEvent;
		LinkILA_Trigger0(5)							<= TransILA_TriggerEvent;
		LinkILA_Trigger0(6)							<= Stream_TriggerEvent;
		LinkILA_Trigger0(7)							<= DebugPortIn_TriggerEvent;
		
		LinkILA_Trigger1(31 downto 0)		<= SATAS_DebugPortOut.LinkLayer.RX_Data;
		LinkILA_Trigger1(32)						<= SATAS_DebugPortOut.LinkLayer.RX_Valid;
		LinkILA_Trigger1(33)						<= SATAS_DebugPortOut.LinkLayer.RX_SOF;
		LinkILA_Trigger1(34)						<= SATAS_DebugPortOut.LinkLayer.RX_EOF;
		LinkILA_Trigger1(35)						<= SATAS_DebugPortOut.LinkLayer.RX_Ack;
		LinkILA_Trigger1(36)						<= SATAS_DebugPortOut.LinkLayer.RX_FS_Valid;
		LinkILA_Trigger1(37)						<= SATAS_DebugPortOut.LinkLayer.RX_FS_CRCOK;
		LinkILA_Trigger1(38)						<= SATAS_DebugPortOut.LinkLayer.RX_FS_SyncEsc;
		LinkILA_Trigger1(39)						<= SATAS_DebugPortOut.LinkLayer.RX_FS_Ack;
		
		LinkILA_Trigger2(31 downto 0)		<= SATAS_DebugPortOut.LinkLayer.RX_Phy_Data;
		LinkILA_Trigger2(35 downto 32)	<= SATAS_DebugPortOut.LinkLayer.RX_Phy_CiK;
		
		LinkILA_Trigger3(31 downto 0)		<= SATAS_DebugPortOut.LinkLayer.TX_Data;
		LinkILA_Trigger3(32)						<= SATAS_DebugPortOut.LinkLayer.TX_Valid;
		LinkILA_Trigger3(33)						<= SATAS_DebugPortOut.LinkLayer.TX_SOF;
		LinkILA_Trigger3(34)						<= SATAS_DebugPortOut.LinkLayer.TX_EOF;
		LinkILA_Trigger3(35)						<= SATAS_DebugPortOut.LinkLayer.TX_Ack;
		LinkILA_Trigger3(36)						<= SATAS_DebugPortOut.LinkLayer.TX_FS_Valid;
		LinkILA_Trigger3(37)						<= SATAS_DebugPortOut.LinkLayer.TX_FS_SendOK;
		LinkILA_Trigger3(38)						<= SATAS_DebugPortOut.LinkLayer.TX_FS_SyncEsc;
		LinkILA_Trigger3(39)						<= SATAS_DebugPortOut.LinkLayer.TX_FS_Ack;	
		
		LinkILA_Trigger4(31 downto 0)		<= SATAS_DebugPortOut.LinkLayer.TX_Phy_Data;
		LinkILA_Trigger4(35 downto 32)	<= SATAS_DebugPortOut.LinkLayer.TX_Phy_CiK;
		
		LinkILA_Trigger5(0)							<= SATAS_DebugPortOut.LinkLayer.LLFSM.TX_IsLongFrame;
		LinkILA_Trigger5(1)							<= SATAS_DebugPortOut.LinkLayer.LLFSM.TX_RetryFailed;
		LinkILA_Trigger5(15 downto 2)		<= (others => '0');
		
		LinkILA_Trigger6(4 downto 0)		<= SATAS_DebugPortOut.LinkLayer.LLFSM.FSM;
		LinkILA_Trigger6(15 downto 5)		<= (others => '0');
		
		TransILA_Data(4 downto 0)			<= SATAS_DebugPortOut.TransportLayer.TFSM.FSM;
		TransILA_Data(8 downto 5)			<= SATAS_DebugPortOut.TransportLayer.FISE.FSM;
		TransILA_Data(13 downto 9)		<= SATAS_DebugPortOut.TransportLayer.FISD.FSM;
		
		TransILA_Data(14)							<= SATAS_DebugPortOut.TransportLayer.UpdateATAHostRegisters;
		TransILA_Data(15)							<= SATAS_DebugPortOut.TransportLayer.ATAHostRegisters.Flag_C;
		TransILA_Data(23 downto 16)		<= SATAS_DebugPortOut.TransportLayer.ATAHostRegisters.Command;
		TransILA_Data(31 downto 24)		<= SATAS_DebugPortOut.TransportLayer.ATAHostRegisters.Control;
		TransILA_Data(39 downto 32)		<= SATAS_DebugPortOut.TransportLayer.ATAHostRegisters.Feature;
		TransILA_Data(40)							<= SATAS_DebugPortOut.TransportLayer.UpdateATADeviceRegisters;
		
		TransILA_Data(41)							<= SATAS_DebugPortOut.TransportLayer.TX_Valid;
		TransILA_Data(73 downto 42)		<= SATAS_DebugPortOut.TransportLayer.TX_Data;
		TransILA_Data(74)							<= SATAS_DebugPortOut.TransportLayer.TX_SOT;
		TransILA_Data(75)							<= SATAS_DebugPortOut.TransportLayer.TX_EOT;
		TransILA_Data(76)							<= SATAS_DebugPortOut.TransportLayer.TX_Ack;
		
		TransILA_Data(77)							<= SATAS_DebugPortOut.TransportLayer.RX_Valid;
		TransILA_Data(109 downto 78)	<= SATAS_DebugPortOut.TransportLayer.RX_Data;
		TransILA_Data(110)						<= SATAS_DebugPortOut.TransportLayer.RX_SOT;
		TransILA_Data(111)						<= SATAS_DebugPortOut.TransportLayer.RX_EOT;
		TransILA_Data(112)						<= SATAS_DebugPortOut.TransportLayer.RX_Ack;
		TransILA_Data(113)						<= SATAS_DebugPortOut.TransportLayer.RX_LastWord;
		TransILA_Data(114)						<= '0';
		
		TransILA_Data(118 downto 115)	<= dbg_EncodeFISType(SATAS_DebugPortOut.TransportLayer.FISE_FISType);
		TransILA_Data(121 downto 119)	<= to_slv(SATAS_DebugPortOut.TransportLayer.FISE_Status);
		TransILA_Data(125 downto 122)	<= dbg_EncodeFISType(SATAS_DebugPortOut.TransportLayer.FISD_FISType);
		TransILA_Data(128 downto 126)	<= to_slv(SATAS_DebugPortOut.TransportLayer.FISD_Status);
		
		TransILA_Data(129) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Flags.Interrupt;
		TransILA_Data(130) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Flags.Direction;
		TransILA_Data(131) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Flags.C;
		TransILA_Data(132) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.Error;
		TransILA_Data(133) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.DataRequest;
		TransILA_Data(134) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.DeviceFault;
		TransILA_Data(135) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.DataReady;
		TransILA_Data(136) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.Busy;
		TransILA_Data(137) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.Error;
		TransILA_Data(138) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.DataRequest;
		TransILA_Data(139) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.DeviceFault;
		TransILA_Data(140) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.DataReady;
		TransILA_Data(141) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.Busy;
		TransILA_Data(142) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.NoMediaPresent    ;
		TransILA_Data(143) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.CommandAborted    ;
		TransILA_Data(144) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.MediaChangeRequest;
		TransILA_Data(145) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.IDNotFound        ;
		TransILA_Data(146) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.MediaChange       ;
		TransILA_Data(147) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.UncorrectableError;
		TransILA_Data(148) 						<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.InterfaceCRCError ;
		TransILA_Data(164 downto 149)	<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.SectorCount;
		TransILA_Data(180 downto 165)	<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.TransferCount;
		
		-- TransportLayer Trigger
		TransILA_Trigger0(0)						<= '0';		-- clkdone
		TransILA_Trigger0(1)						<= '0';		-- rstdone
		TransILA_Trigger0(2)						<= TransceiverILA_TriggerEvent;
		TransILA_Trigger0(3)						<= PhyILA_TriggerEvent;
		TransILA_Trigger0(4)						<= LinkILA_TriggerEvent;
		TransILA_Trigger0(5)						<= '0';	--TransILA_TriggerEvent;
		TransILA_Trigger0(6)						<= Stream_TriggerEvent;
		TransILA_Trigger0(7)						<= DebugPortIn_TriggerEvent;

    TransILA_Trigger1(31 downto 0)	<= SATAS_DebugPortOut.TransportLayer.RX_Data;
		TransILA_Trigger1(32)						<= SATAS_DebugPortOut.TransportLayer.RX_Valid;
    TransILA_Trigger1(33)						<= SATAS_DebugPortOut.TransportLayer.RX_SOT;
    TransILA_Trigger1(34)						<= SATAS_DebugPortOut.TransportLayer.RX_EOT;
    TransILA_Trigger1(35)						<= SATAS_DebugPortOut.TransportLayer.RX_Ack;

		TransILA_Trigger2(4 downto 0)		<= SATAS_DebugPortOut.TransportLayer.TFSM.FSM;
		TransILA_Trigger2(8 downto 5)		<= SATAS_DebugPortOut.TransportLayer.FISE.FSM;
		TransILA_Trigger2(13 downto 9)	<= SATAS_DebugPortOut.TransportLayer.FISD.FSM;

		TransILA_Trigger3(3 downto 0)		<= dbg_EncodeFISType(SATAS_DebugPortOut.TransportLayer.FISE_FISType);
		TransILA_Trigger3(6 downto 4)		<= to_slv(SATAS_DebugPortOut.TransportLayer.FISE_Status);
		TransILA_Trigger3(10 downto 7)	<= dbg_EncodeFISType(SATAS_DebugPortOut.TransportLayer.FISD_FISType);
		TransILA_Trigger3(13 downto 11)	<= to_slv(SATAS_DebugPortOut.TransportLayer.FISD_Status);

		TransILA_Trigger4(0)						<= SATAS_DebugPortOut.TransportLayer.UpdateATAHostRegisters;
		TransILA_Trigger4(1)						<= SATAS_DebugPortOut.TransportLayer.ATAHostRegisters.Flag_C;
		TransILA_Trigger4(9 downto 2)		<= SATAS_DebugPortOut.TransportLayer.ATAHostRegisters.Command;
		TransILA_Trigger4(17 downto 10)	<= SATAS_DebugPortOut.TransportLayer.ATAHostRegisters.Control;
		TransILA_Trigger4(25 downto 18)	<= SATAS_DebugPortOut.TransportLayer.ATAHostRegisters.Feature;

		TransILA_Trigger5(  0) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Flags.Interrupt;
		TransILA_Trigger5(  1) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Flags.Direction;
		TransILA_Trigger5(  2) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Flags.C;
		TransILA_Trigger5(  3) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.Error;
		TransILA_Trigger5(  4) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.DataRequest;
		TransILA_Trigger5(  5) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.DeviceFault;
		TransILA_Trigger5(  6) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.DataReady;
		TransILA_Trigger5(  7) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Status.Busy;
		TransILA_Trigger5(  8) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.Error;
		TransILA_Trigger5(  9) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.DataRequest;
		TransILA_Trigger5( 10) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.DeviceFault;
		TransILA_Trigger5( 11) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.DataReady;
		TransILA_Trigger5( 12) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.EndStatus.Busy;
		TransILA_Trigger5( 13) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.NoMediaPresent    ;
		TransILA_Trigger5( 14) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.CommandAborted    ;
		TransILA_Trigger5( 15) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.MediaChangeRequest;
		TransILA_Trigger5( 16) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.IDNotFound        ;
		TransILA_Trigger5( 17) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.MediaChange       ;
		TransILA_Trigger5( 18) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.UncorrectableError;
		TransILA_Trigger5( 19) 					<= SATAS_DebugPortOut.TransportLayer.ATADeviceRegisters.Error.InterfaceCRCError ;

		Stream_Data(2 downto 0)				<= to_slv(SATAS_DebugPortOut.Streaming_Command);
    Stream_Data(5 downto 3)				<= to_slv(SATAS_DebugPortOut.Streaming_Status);
    Stream_Data(8 downto 6)				<= to_slv(SATAS_DebugPortOut.Streaming_Error);

    Stream_Data(13 downto 9)			<= SATAS_DebugPortOut.StreamingLayer.SFSM.FSM;
--    Stream_Data(13)								<= SATAS_DebugPortOut.StreamingLayer.SFSM.Load;
    Stream_Data(14)								<= SATAS_DebugPortOut.StreamingLayer.SFSM.NextTransfer;
    Stream_Data(15)								<= SATAS_DebugPortOut.StreamingLayer.SFSM.LastTransfer;
		
--    Stream_Data(97 downto 95)			<= SATAS_DebugPortOut.StreamingLayer.Address_AppLB;
--    Stream_Data(97 downto 95)			<= SATAS_DebugPortOut.StreamingLayer.BlockCount_AppLB;
    Stream_Data(47 downto 16)			<= SATAS_DebugPortOut.StreamingLayer.Address_DevLB(31 downto 0);				-- 32 bit
    Stream_Data(63 downto 48)			<= SATAS_DebugPortOut.StreamingLayer.BlockCount_DevLB(15 downto 0);			-- 16 bit
    
    -- identify device filter
    Stream_Data(64)								<= SATAS_DebugPortOut.StreamingLayer.IDF_Reset;
    Stream_Data(65)								<= SATAS_DebugPortOut.StreamingLayer.IDF_Enable;
    Stream_Data(66)								<= SATAS_DebugPortOut.StreamingLayer.IDF_Error;
    Stream_Data(67)								<= SATAS_DebugPortOut.StreamingLayer.IDF_Finished;
    Stream_Data(68)								<= '0';
    Stream_Data(69)								<= SATAS_DebugPortOut.StreamingLayer.IDF_DriveInformation.Valid;
    
    -- RX datapath to upper layer
    Stream_Data(70)								<= SATAS_DebugPortOut.StreamingLayer.RX_Valid;
    Stream_Data(102 downto 71)		<= SATAS_DebugPortOut.StreamingLayer.RX_Data;
    Stream_Data(103)							<= SATAS_DebugPortOut.StreamingLayer.RX_SOR;
    Stream_Data(104)							<= SATAS_DebugPortOut.StreamingLayer.RX_EOR;
    Stream_Data(105)							<= SATAS_DebugPortOut.StreamingLayer.RX_Ack;
    
		-- RX datapath between demultiplexer, RX_FIFO and SFSM
    Stream_Data(106)							<= SATAS_DebugPortOut.StreamingLayer.SFSM_RX_Valid;
    Stream_Data(107)							<= SATAS_DebugPortOut.StreamingLayer.SFSM_RX_SOR;
    Stream_Data(108)							<= SATAS_DebugPortOut.StreamingLayer.SFSM_RX_EOR;
    Stream_Data(109)							<= SATAS_DebugPortOut.StreamingLayer.SFSM_RX_Ack;
		
    -- TX datapath to upper layer
    Stream_Data(110)							<= SATAS_DebugPortOut.StreamingLayer.TX_Valid;
    Stream_Data(142 downto 111)		<= SATAS_DebugPortOut.StreamingLayer.TX_Data;
    Stream_Data(143)							<= SATAS_DebugPortOut.StreamingLayer.TX_SOR;
    Stream_Data(144)							<= SATAS_DebugPortOut.StreamingLayer.TX_EOR;
    Stream_Data(145)							<= SATAS_DebugPortOut.StreamingLayer.TX_Ack;
    
    -- TX datapath of transport cutter
    Stream_Data(146)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_Valid;
    Stream_Data(178 downto 147)		<= SATAS_DebugPortOut.StreamingLayer.TC_TX_Data;
    Stream_Data(179)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_SOT;
    Stream_Data(180)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_EOT;
    Stream_Data(181)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_Ack;
    Stream_Data(182)							<= SATAS_DebugPortOut.StreamingLayer.SFSM_TX_ForceEOT;
    Stream_Data(183)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_InsertEOT;
		
		-- StreamingLayer Trigger
		Stream_Trigger0(0)							<= '0';		-- clkdone
		Stream_Trigger0(1)							<= '0';		-- rstdone
		Stream_Trigger0(2)							<= TransceiverILA_TriggerEvent;
		Stream_Trigger0(3)							<= PhyILA_TriggerEvent;
		Stream_Trigger0(4)							<= LinkILA_TriggerEvent;
		Stream_Trigger0(5)							<= TransILA_TriggerEvent;
		Stream_Trigger0(6)							<= '0';	--Stream_TriggerEvent;
		Stream_Trigger0(7)							<= DebugPortIn_TriggerEvent;
		
    Stream_Trigger1(31 downto 0)		<= SATAS_DebugPortOut.StreamingLayer.RX_Data;
		Stream_Trigger1(32)							<= SATAS_DebugPortOut.StreamingLayer.RX_Valid;
    Stream_Trigger1(33)							<= SATAS_DebugPortOut.StreamingLayer.RX_SOR;
    Stream_Trigger1(34)							<= SATAS_DebugPortOut.StreamingLayer.RX_EOR;
    Stream_Trigger1(35)							<= SATAS_DebugPortOut.StreamingLayer.RX_Ack;
		
		Stream_Trigger2(2 downto 0)			<= to_slv(SATAS_DebugPortOut.Streaming_Command);
    Stream_Trigger2(5 downto 3)			<= to_slv(SATAS_DebugPortOut.Streaming_Status);
    Stream_Trigger2(8 downto 6)			<= to_slv(SATAS_DebugPortOut.Streaming_Error);

		Stream_Trigger3(4 downto 0)			<= SATAS_DebugPortOut.StreamingLayer.SFSM.FSM;
		
		Stream_Trigger4(0)							<= SATAS_DebugPortOut.StreamingLayer.SFSM.Load;
    Stream_Trigger4(1)							<= SATAS_DebugPortOut.StreamingLayer.SFSM.NextTransfer;
    Stream_Trigger4(2)							<= SATAS_DebugPortOut.StreamingLayer.SFSM.LastTransfer;
    Stream_Trigger4(3)							<= SATAS_DebugPortOut.StreamingLayer.IDF_Enable;
    Stream_Trigger4(4)							<= SATAS_DebugPortOut.StreamingLayer.IDF_Error;
    Stream_Trigger4(5)							<= SATAS_DebugPortOut.StreamingLayer.IDF_Finished;
    Stream_Trigger4(6)							<= '0';
    Stream_Trigger4(7)							<= SATAS_DebugPortOut.StreamingLayer.IDF_DriveInformation.Valid;
		
    Stream_Trigger5(31 downto 0)		<= SATAS_DebugPortOut.StreamingLayer.TX_Data;
		Stream_Trigger5(32)							<= SATAS_DebugPortOut.StreamingLayer.TX_Valid;
    Stream_Trigger5(33)							<= SATAS_DebugPortOut.StreamingLayer.TX_SOR;
    Stream_Trigger5(34)							<= SATAS_DebugPortOut.StreamingLayer.TX_EOR;
    Stream_Trigger5(35)							<= SATAS_DebugPortOut.StreamingLayer.TX_Ack;
		
    Stream_Trigger6(31 downto 0)		<= SATAS_DebugPortOut.StreamingLayer.TC_TX_Data;
		Stream_Trigger6(32)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_Valid;
    Stream_Trigger6(33)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_SOT;
    Stream_Trigger6(34)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_EOT;
    Stream_Trigger6(35)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_Ack;
    Stream_Trigger6(36)							<= SATAS_DebugPortOut.StreamingLayer.SFSM_TX_ForceEOT;
    Stream_Trigger6(37)							<= SATAS_DebugPortOut.StreamingLayer.TC_TX_InsertEOT;
		
		PhyILA_Data_d				<= PhyILA_Data			when rising_edge(SATAC_Clock);
		PhyILA_Trigger0_d		<= PhyILA_Trigger0	when rising_edge(SATAC_Clock);
		PhyILA_Trigger1_d		<= PhyILA_Trigger1	when rising_edge(SATAC_Clock);
		PhyILA_Trigger2_d		<= PhyILA_Trigger2	when rising_edge(SATAC_Clock);
		PhyILA_Trigger3_d		<= PhyILA_Trigger3	when rising_edge(SATAC_Clock);
		PhyILA_Trigger4_d		<= PhyILA_Trigger4	when rising_edge(SATAC_Clock);

		LinkILA_Data_d			<= LinkILA_Data			when rising_edge(SATAC_Clock);
		LinkILA_Trigger0_d	<= LinkILA_Trigger0	when rising_edge(SATAC_Clock);
		LinkILA_Trigger1_d	<= LinkILA_Trigger1	when rising_edge(SATAC_Clock);
		LinkILA_Trigger2_d	<= LinkILA_Trigger2	when rising_edge(SATAC_Clock);
		LinkILA_Trigger3_d	<= LinkILA_Trigger3	when rising_edge(SATAC_Clock);
		LinkILA_Trigger4_d	<= LinkILA_Trigger4	when rising_edge(SATAC_Clock);
		LinkILA_Trigger5_d	<= LinkILA_Trigger5	when rising_edge(SATAC_Clock);
		LinkILA_Trigger6_d	<= LinkILA_Trigger6	when rising_edge(SATAC_Clock);
		                    
		TransILA_Data_d			<= TransILA_Data			when rising_edge(SATAC_Clock);
		TransILA_Trigger0_d	<= TransILA_Trigger0	when rising_edge(SATAC_Clock);
		TransILA_Trigger1_d	<= TransILA_Trigger1	when rising_edge(SATAC_Clock);
		TransILA_Trigger2_d	<= TransILA_Trigger2	when rising_edge(SATAC_Clock);
		TransILA_Trigger3_d	<= TransILA_Trigger3	when rising_edge(SATAC_Clock);
		TransILA_Trigger4_d	<= TransILA_Trigger4	when rising_edge(SATAC_Clock);
		TransILA_Trigger5_d	<= TransILA_Trigger5	when rising_edge(SATAC_Clock);
		
		Stream_Data_d				<= Stream_Data			when rising_edge(SATAC_Clock);
		Stream_Trigger0_d		<= Stream_Trigger0	when rising_edge(SATAC_Clock);
		Stream_Trigger1_d		<= Stream_Trigger1	when rising_edge(SATAC_Clock);
		Stream_Trigger2_d		<= Stream_Trigger2	when rising_edge(SATAC_Clock);
		Stream_Trigger3_d		<= Stream_Trigger3	when rising_edge(SATAC_Clock);
		Stream_Trigger4_d		<= Stream_Trigger4	when rising_edge(SATAC_Clock);
		Stream_Trigger5_d		<= Stream_Trigger5	when rising_edge(SATAC_Clock);
		Stream_Trigger6_d		<= Stream_Trigger6	when rising_edge(SATAC_Clock);

		
		TransceiverILA : ENTITY PoC.sata_TransceiverLayer_ILA
			PORT MAP (
				CONTROL		=> TransceiverLayer_ILA_ControlBus,
				CLK				=> DebugClock,
				TRIG0			=> TransceiverILA_Trigger0,
				TRIG_OUT	=> TransceiverILA_TriggerEvent
			);

		PhyILA : ENTITY PoC.sata_PhysicalLayer_ILA
			port map (
				CONTROL		=> PhyLayer_ILA_ControlBus,
				CLK				=> SATAC_Clock,
				DATA			=> PhyILA_Data_d,
				TRIG0			=> PhyILA_Trigger0_d,
				TRIG1			=> PhyILA_Trigger1_d,
				TRIG2			=> PhyILA_Trigger2_d,
				TRIG3			=> PhyILA_Trigger3_d,
				TRIG4			=> PhyILA_Trigger4_d,
				TRIG_OUT	=> PhyILA_TriggerEvent
			);

		LinkILA : entity PoC.sata_LinkLayer_ILA
			port map (
				CONTROL		=> LinkLayer_ILA_ControlBus,
				CLK				=> SATAC_Clock,
				DATA			=> LinkILA_Data_d,
				TRIG0			=> LinkILA_Trigger0_d,
				TRIG1			=> LinkILA_Trigger1_d,
				TRIG2			=> LinkILA_Trigger2_d,
				TRIG3			=> LinkILA_Trigger3_d,
				TRIG4			=> LinkILA_Trigger4_d,
				TRIG5			=> LinkILA_Trigger5_d,
				TRIG6			=> LinkILA_Trigger6_d,
				TRIG_OUT	=> LinkILA_TriggerEvent
			);

		TransILA : entity PoC.sata_TransportLayer_ILA
			port map (
				CONTROL		=> TransportLayer_ILA_ControlBus,
				CLK				=> SATAC_Clock,
				DATA			=> TransILA_Data_d,
				TRIG0			=> TransILA_Trigger0_d,
				TRIG1			=> TransILA_Trigger1_d,
				TRIG2			=> TransILA_Trigger2_d,
				TRIG3			=> TransILA_Trigger3_d,
				TRIG4			=> TransILA_Trigger4_d,
				TRIG5			=> TransILA_Trigger5_d,
				TRIG_OUT	=> TransILA_TriggerEvent
			);

		StreamCtrlILA : entity PoC.sata_StreamingLayer_ILA
			port map (
				CONTROL		=> CommandLayer_ILA_ControlBus,
				CLK				=> SATAC_Clock,
				DATA			=> Stream_Data_d,
				TRIG0			=> Stream_Trigger0_d,
				TRIG1			=> Stream_Trigger1_d,
				TRIG2			=> Stream_Trigger2_d,
				TRIG3			=> Stream_Trigger3_d,
				TRIG4			=> Stream_Trigger4_d,
				TRIG5			=> Stream_Trigger5_d,
				TRIG6			=> Stream_Trigger6_d,
				TRIG_OUT	=> Stream_TriggerEvent
			);
	end generate;
	
end architecture;
