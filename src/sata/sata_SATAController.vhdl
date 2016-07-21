-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Steffen Koehler
--									Martin Zabel
--
-- Entity:					SATA Controller (Physical, Link and Transport Layer)
--
-- Description:
-- -------------------------------------
-- Provides the SATA Transport Layer to transfer ATA commands and data from host to
-- device and vice versa.
--
-- Reset Procedure:
-- ----------------
-- The SATAController automatically powers up, if inputs PowerDown and
-- ClockNetwork_Reset are low. The SATAController synchronously asserts
-- ResetDone when his Command-Status-Error interface is ready after power-up.
-- It is only deasserted asynchronously in case of asynchronously asserting
-- PowerDown or ClockNetwork_Reset, but both are optional features.
--
-- All upper layers must be hold in reset as long as ResetDone is deasserted.
--
-- The output SATA_Clock_Stable is synchronously asserted if the output
-- SATA_Clock delivers a stable clock signal, so it can be used as clock
-- enable. SATA_Clock_Stable is hight at least one cycle before ResetDone
-- is asserted.
--
-- SATA_Clock_Stable might be deasserted synchronously when a change of the
-- SATA generation is needed and SATA_Clock is instable for a while. ResetDone
-- is kept asserted because Status and Error are still valid but are not
-- changing until the SATA_Clock is stable again. The inputs Command and
-- (synchronous) Reset are ignored when SATA_Clock_Stable is low.
--
-- ClockNetwork_ResetDone is asserted asynchronously when all internal clock
-- networks are stable. This signal can be used for debugging or if another
-- PLL/DLL is connected to SATA_Clock.
--
-- Command:
-- -------
-- Commands are only accepted when Status.TransportLayer is
-- *_TRANS_STATUS_IDLE, *_TRANS_STATUS_TRANSFER_OK or
-- *_TRANS_STATUS_TRANSFER_ERROR.
--
-- Command = *_SATACTRL_CMD_TRANSFER:
--   Transfer and execute ATA command provided by input ATAHostRegisters.
--   Completes with Status.TransportLayer:
--   - *_TRANS_STATUS_TRANSFER_OK if successful. New commands can be applied
--     	directly.
--
--   - *_TRANS_STATUS_TRANSFER_ERROR if the device reports an error via the ATA
--   		register block. New commands can be applied directly.

--   - *_TRANS_STATUS_ERROR if a fatal error occurs. In this case at least a
--   		synchronous reset must be applied.
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
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.sata.all;
use			PoC.satadbg.all;
use			PoC.sata_TransceiverTypes.all;


entity sata_SATAController is
	generic (
		DEBUG														: boolean											:= FALSE;
		ENABLE_DEBUGPORT								: boolean											:= FALSE;
		-- transceiver settings
		REFCLOCK_FREQ										: FREQ												:= 150 MHz;
		PORTS														: positive										:= 2;	-- Port 0									Port 1
		-- physical layer settings
		CONTROLLER_TYPES								: T_SATA_DEVICE_TYPE_VECTOR		:= (0 => SATA_DEVICE_TYPE_HOST,	1 => SATA_DEVICE_TYPE_HOST);
		INITIAL_SATA_GENERATIONS				: T_SATA_GENERATION_VECTOR		:= (0 => C_SATA_GENERATION_MAX,	1 => C_SATA_GENERATION_MAX);
		ALLOW_SPEED_NEGOTIATION					: T_BOOLVEC										:= (0 => TRUE,									1 => TRUE);
		ALLOW_STANDARD_VIOLATION				: T_BOOLVEC										:= (0 => TRUE,									1 => TRUE);
		OOB_TIMEOUT											: T_TIMEVEC										:= (0 => time'low,							1 => TIME'low);
		GENERATION_CHANGE_COUNT					: T_INTVEC										:= (0 => 8,											1 => 8);
		ATTEMPTS_PER_GENERATION					: T_INTVEC										:= (0 => 5,											1 => 3);
		-- linklayer settings
		AHEAD_CYCLES_FOR_INSERT_EOF			: T_INTVEC										:= (0 => 1,											1 => 1);
		MAX_FRAME_SIZE									: T_MEMVEC										:= (0 => C_SATA_MAX_FRAMESIZE,	1 => C_SATA_MAX_FRAMESIZE);
		-- transport layer settings
		SIM_WAIT_FOR_INITIAL_REGDH_FIS	: T_BOOLVEC										:= (0 => TRUE,									1 => TRUE);       -- required by ATA/SATA standard
		ENABLE_GLUE_FIFOS								: T_BOOLVEC										:= (0 => FALSE,									1 => FALSE)
	);
	port (
		ClockNetwork_Reset					: in	std_logic_vector(PORTS - 1 downto 0);						-- @async:			asynchronous reset
		ClockNetwork_ResetDone			: out	std_logic_vector(PORTS - 1 downto 0);						-- @async:			all clocks are stable
		PowerDown										: in	std_logic_vector(PORTS - 1 downto 0);						-- @async:
		Reset												: in	std_logic_vector(PORTS - 1 downto 0);						-- @SATA_Clock:	synchronous reset, done in next cycle
		ResetDone										: out	std_logic_vector(PORTS - 1 downto 0);						-- @SATA_Clock: layers have been resetted after powerup / hard reset

		SATAGenerationMin						: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);		--
		SATAGenerationMax						: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);		--
		SATAGeneration          	  : out T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);

		SATA_Clock									: out	std_logic_vector(PORTS - 1 downto 0);
		SATA_Clock_Stable						: out	std_logic_vector(PORTS - 1 downto 0);

		Command											: in	T_SATA_TRANS_COMMAND_VECTOR(PORTS - 1 downto 0);
		Status											: out T_SATA_SATACONTROLLER_STATUS_VECTOR(PORTS - 1 downto 0);
		Error												: out	T_SATA_SATACONTROLLER_ERROR_VECTOR(PORTS - 1 downto 0);
		ATAHostRegisters						: in	T_SATA_ATA_HOST_REGISTERS_VECTOR(PORTS - 1 downto 0);
		ATADeviceRegisters					: out	T_SATA_ATA_DEVICE_REGISTERS_VECTOR(PORTS - 1 downto 0);

		-- Debug ports
		DebugPortIn									: in	T_SATADBG_SATACONTROLLER_IN_VECTOR(PORTS - 1 downto 0);
		DebugPortOut								: out	T_SATADBG_SATACONTROLLER_OUT_VECTOR(PORTS - 1 downto 0);

		-- TX port
		TX_SOT											: in	std_logic_vector(PORTS - 1 downto 0);
		TX_EOT											: in	std_logic_vector(PORTS - 1 downto 0);
		TX_Valid										: in	std_logic_vector(PORTS - 1 downto 0);
		TX_Data											: in	T_SLVV_32(PORTS - 1 downto 0);
		TX_Ack											: out	std_logic_vector(PORTS - 1 downto 0);

		-- RX port
		RX_SOT											: out	std_logic_vector(PORTS - 1 downto 0);
		RX_EOT											: out	std_logic_vector(PORTS - 1 downto 0);
		RX_Valid										: out	std_logic_vector(PORTS - 1 downto 0);
		RX_Data											: out	T_SLVV_32(PORTS - 1 downto 0);
		RX_Ack											: in	std_logic_vector(PORTS - 1 downto 0);

		-- vendor specific signals
		VSS_Common_In								: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In							: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS - 1 downto 0);
		VSS_Private_Out							: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 downto 0)
	);
end entity;


architecture rtl of sata_SATAController is
	attribute KEEP													: boolean;

	constant CONTROLLER_TYPES_I							: T_SATA_DEVICE_TYPE_VECTOR(0 to PORTS - 1)	:= CONTROLLER_TYPES(0 to PORTS - 1);
	constant INITIAL_SATA_GENERATIONS_I			: T_SATA_GENERATION_VECTOR(0 to PORTS - 1)	:= INITIAL_SATA_GENERATIONS(0 to PORTS - 1);
	constant ALLOW_SPEED_NEGOTIATION_I			: T_BOOLVEC(0 to PORTS - 1)									:= ALLOW_SPEED_NEGOTIATION(0 to PORTS - 1);
	constant ALLOW_STANDARD_VIOLATION_I			: T_BOOLVEC(0 to PORTS - 1)									:= ALLOW_STANDARD_VIOLATION(0 to PORTS - 1);
	constant OOB_TIMEOUT_I									: T_TIMEVEC(0 to PORTS - 1)									:= OOB_TIMEOUT(0 to PORTS - 1);
	constant GENERATION_CHANGE_COUNT_I			: T_INTVEC(0 to PORTS - 1)									:= GENERATION_CHANGE_COUNT(0 to PORTS - 1);
	constant ATTEMPTS_PER_GENERATION_I			: T_INTVEC(0 to PORTS - 1)									:= ATTEMPTS_PER_GENERATION(0 to PORTS - 1);
	constant AHEAD_CYCLES_FOR_INSERT_EOF_I	: T_INTVEC(0 to PORTS - 1)									:= AHEAD_CYCLES_FOR_INSERT_EOF(0 to PORTS - 1);
	constant MAX_FRAME_SIZE_I								: T_MEMVEC(0 to PORTS - 1)									:= MAX_FRAME_SIZE(0 to PORTS - 1);

	-- Clocking & ResetDone, provided by transceiver layer
	signal SATA_Clock_i									: std_logic_vector(PORTS - 1 downto 0);
	signal SATA_Clock_Stable_i					: std_logic_vector(PORTS - 1 downto 0);

	-- physical layer <=> transceiver layer signals
	signal Phy_RP_Reconfig										: std_logic_vector(PORTS - 1 downto 0);
	signal Phy_RP_SATAGeneration							: T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);
	signal Transceiver_RP_ConfigReloaded			: std_logic_vector(PORTS - 1 downto 0);
	signal Phy_RP_Lock												: std_logic_vector(PORTS - 1 downto 0);

	signal Transceiver_ResetDone							: std_logic_vector(PORTS-1 downto 0);
	signal Transceiver_Command								: T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 downto 0);
	signal Transceiver_Status									: T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 downto 0);
	signal Transceiver_Error									: T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 downto 0);

	signal Phy_OOB_TX_Command									: T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
	signal Transceiver_OOB_TX_Complete				: std_logic_vector(PORTS - 1 downto 0);
	signal Transceiver_OOB_RX_Received				: T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
	signal Phy_OOB_HandshakeComplete					: std_logic_vector(PORTS - 1 downto 0);
	signal Phy_OOB_AlignDetected    					: std_logic_vector(PORTS - 1 downto 0);

	signal Phy_TX_Data												: T_SLVV_32(PORTS - 1 downto 0);
	signal Phy_TX_CharIsK											: T_SLVV_4(PORTS - 1 downto 0);
	signal Transceiver_RX_Data								: T_SLVV_32(PORTS - 1 downto 0);
	signal Transceiver_RX_CharIsK							: T_SLVV_4(PORTS - 1 downto 0);
	signal Transceiver_RX_Valid								: std_logic_vector(PORTS - 1 downto 0);

	signal Transceiver_DebugPortIn						: T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS - 1 downto 0);
	signal Transceiver_DebugPortOut						: T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS - 1 downto 0);

	attribute KEEP of SATA_Clock_i			: signal is DEBUG;

begin
	genReport : for i in 0 to PORTS - 1 generate
		assert FALSE report "Port:    " & integer'image(i)																											severity NOTE;
		assert FALSE report "  ControllerType:         " & T_SATA_DEVICE_TYPE'image(CONTROLLER_TYPES_I(i))			severity NOTE;
		assert FALSE report "  AllowSpeedNegotiation:  " & to_string(ALLOW_SPEED_NEGOTIATION_I(i))							severity NOTE;
		assert FALSE report "  AllowStandardViolation: " & to_string(ALLOW_STANDARD_VIOLATION_I(i))							severity NOTE;
		assert FALSE report "  Init. SATA Generation:  Gen" & integer'image(INITIAL_SATA_GENERATIONS_I(i) + 1)	severity NOTE;
	end generate;

	-- generate layer moduls per port
	gen1 : for i in 0 to PORTS - 1 generate
		-- transport layer signals to/from upper
		signal Transport_ResetDone 		: std_logic;
		signal Transport_Command			: T_SATA_TRANS_COMMAND;
		signal Transport_Status				: T_SATA_TRANS_STATUS;
		signal Transport_Error				: T_SATA_TRANS_ERROR;

		-- TX glue FIFO signals to transport layer
		signal TX_Glue_Data						: T_SLV_32;
		signal TX_Glue_SOT						: std_logic;
		signal TX_Glue_EOT						: std_logic;
		signal TX_Glue_Valid					: std_logic;
		signal RX_Glue_Ack						: std_logic;

		-- transport layer signals to glue FIFO
		signal Transport_RX_Valid			: std_logic;
		signal Transport_RX_Data			: T_SLV_32;
		signal Transport_RX_SOT				: std_logic;
		signal Transport_RX_EOT				: std_logic;
		signal Transport_TX_Ack				: std_logic;

		-- transport layer signals to link layer
		signal Transport_TX_Data			: T_SLV_32;
		signal Transport_TX_SOF				: std_logic;
		signal Transport_TX_EOF				: std_logic;
		signal Transport_TX_Valid			: std_logic;
		signal Transport_TX_FS_Ack		: std_logic;
		signal Transport_RX_Ack				: std_logic;
		signal Transport_RX_FS_Ack		: std_logic;

		-- link layer signals
		signal Link_ResetDone 				: std_logic;
		signal Link_Command						: T_SATA_LINK_COMMAND;
		signal Link_Status						: T_SATA_LINK_STATUS;
		signal Link_Error							: T_SATA_LINK_ERROR;

		-- link layer signals to transport layer
		signal Link_TX_Ack						: std_logic;
		signal Link_TX_InsertEOF			: std_logic;
		signal Link_TX_FS_Valid				: std_logic;
		signal Link_TX_FS_SendOK			: std_logic;
		signal Link_TX_FS_SyncEsc			: std_logic;

		signal Link_RX_SOF						: std_logic;
		signal Link_RX_EOF						: std_logic;
		signal Link_RX_Valid					: std_logic;
		signal Link_RX_Data						: T_SLV_32;
		signal Link_RX_FS_Valid				: std_logic;
		signal Link_RX_FS_CRCOK				: std_logic;
		signal Link_RX_FS_SyncEsc			: std_logic;

		-- physical layer signals
		signal Phy_ResetDone 					: std_logic;
		signal Phy_Command						: T_SATA_PHY_COMMAND;
		signal Phy_Status							: T_SATA_PHY_STATUS;
		signal Phy_Error							: T_SATA_PHY_ERROR;

		-- link layer to physical layer signals
		signal Link_TX_Data						: T_SLV_32;
		signal Link_TX_CharIsK				: T_SLV_4;

		-- physical layer signals to link layer
		signal Phy_RX_Data						: T_SLV_32;
		signal Phy_RX_CharIsK					: T_SLV_4;

		-- debug ports
		signal Transport_DebugPortOut	: T_SATADBG_TRANS_OUT;
		signal Link_DebugPortIn				: T_SATADBG_LINK_IN;
		signal Link_DebugPortOut			: T_SATADBG_LINK_OUT;
		signal Phy_DebugPortOut				: T_SATADBG_PHYSICAL_OUT;

	begin
		-- =========================================================================
		-- SATAController interface
		-- =========================================================================
		-- common signals
		ResetDone(i) 									<= Transport_ResetDone;
		SATAGeneration(i)							<= Phy_RP_SATAGeneration(i);

		Transport_Command							<= Command(i);

		Status(i).TransportLayer			<= Transport_Status;
		Status(i).LinkLayer						<= Link_Status;
		Status(i).PhysicalLayer				<= Phy_Status;
		Status(i).TransceiverLayer		<= Transceiver_Status(i);

		Error(i).TransportLayer				<= Transport_Error;
		Error(i).LinkLayer						<= Link_Error;
		Error(i).PhysicalLayer				<= Phy_Error;
		Error(i).TransceiverLayer			<= Transceiver_Error(i);


		genNoFIFO : if (ENABLE_GLUE_FIFOS(i) = FALSE) generate
		begin
			TX_Glue_Valid	<= TX_Valid(i);
			TX_Glue_Data	<= TX_Data(i);
			TX_Glue_SOT		<= TX_SOT(i);
			TX_Glue_EOT		<= TX_EOT(i);
			TX_Ack(i)			<= Transport_TX_Ack;

			RX_Valid(i)		<= Transport_RX_Valid;
			RX_Data(i) 		<= Transport_RX_Data;
			RX_SOT(i) 		<= Transport_RX_SOT;
			RX_EOT(i) 		<= Transport_RX_EOT;
			RX_Glue_Ack		<= RX_Ack(i);
		end generate;
		genFIFO : if (ENABLE_GLUE_FIFOS(i) = TRUE) generate
			signal FIFO_Reset		: std_logic;

			signal TX_GlueFIFO_Full		: std_logic;
			signal TX_GlueFIFO_DataIn	: std_logic_vector(33 downto 0);
			signal TX_GlueFIFO_DataOut	: std_logic_vector(33 downto 0);

			signal RX_GlueFIFO_Full		: std_logic;
			signal RX_GlueFIFO_DataIn	: std_logic_vector(33 downto 0);
			signal RX_GlueFIFO_DataOut	: std_logic_vector(33 downto 0);

		begin
			-- Reset FIFOs until initial reset of SATAController has been
			-- completed. Allow synchronous 'Reset' only when ClockEnable = '1'.
			FIFO_Reset <= (not Transport_ResetDone) or (Reset(i) and SATA_Clock_Stable_i(i));

			-- TX port
			TX_FIFO : entity PoC.fifo_glue
				generic map (
					D_BITS => TX_GlueFIFO_DataIn'length
					)
				port map (
					clk => SATA_Clock_i(i),
					rst => FIFO_Reset,

					di 	=> TX_GlueFIFO_DataIn,
					ful => TX_GlueFIFO_Full,
					put => TX_Valid(i),

					do 	=> TX_GlueFIFO_DataOut,
					vld => TX_Glue_Valid,
					got => Transport_TX_Ack
				);

			TX_Ack(i)													<= not TX_GlueFIFO_Full;
			TX_GlueFIFO_DataIn(31 downto 0) 	<= TX_Data(i);
			TX_GlueFIFO_DataIn(32) 						<= TX_SOT(i);
			TX_GlueFIFO_DataIn(33) 						<= TX_EOT(i);
			TX_Glue_Data											<= TX_GlueFIFO_DataOut(31 downto 0);
			TX_Glue_SOT												<= TX_GlueFIFO_DataOut(32);
			TX_Glue_EOT												<= TX_GlueFIFO_DataOut(33);

			-- RX port
			RX_FIFO : entity PoC.fifo_glue
				generic map (
					D_BITS => RX_GlueFIFO_DataIn'length
					)
				port map (
					clk => SATA_Clock_i(i),
					rst => FIFO_Reset,

					di 	=> RX_GlueFIFO_DataIn,
					ful => RX_GlueFIFO_Full,
					put => Transport_RX_Valid,

					do 	=> RX_GlueFIFO_DataOut,
					vld => RX_Valid(i),
					got => RX_Ack(i)
				);

			RX_Glue_Ack											<= not RX_GlueFIFO_Full;

			RX_GlueFIFO_DataIn(31 downto 0) <= Transport_RX_Data;
			RX_GlueFIFO_DataIn(32)					<= Transport_RX_SOT;
			RX_GlueFIFO_DataIn(33)					<= Transport_RX_EOT;
			RX_Data(i) 											<= RX_GlueFIFO_DataOut(31 downto 0);
			RX_SOT(i) 											<= RX_GlueFIFO_DataOut(32);
			RX_EOT(i) 											<= RX_GlueFIFO_DataOut(33);
		end generate;

		-- =========================================================================
		-- Transport Layer
		-- =========================================================================
		Trans : entity PoC.sata_TransportLayer
			generic map (
				DEBUG														=> DEBUG,
				ENABLE_DEBUGPORT								=> ENABLE_DEBUGPORT,
				SIM_WAIT_FOR_INITIAL_REGDH_FIS  => SIM_WAIT_FOR_INITIAL_REGDH_FIS(i)
			)
			port map (
				Clock												=> SATA_Clock_i(i),
				ClockEnable									=> SATA_Clock_Stable_i(i),
				Reset												=> Reset(i),

				-- TransportLayer interface
				Command											=> Transport_Command,
				Status											=> Transport_Status,
				Error												=> Transport_Error,

				DebugPortOut								=> Transport_DebugPortOut,

				-- ATA registers
				ATAHostRegisters						=> ATAHostRegisters(i),
				ATADeviceRegisters					=> ATADeviceRegisters(i),

				-- TX path
				TX_Valid										=> TX_Glue_Valid,
				TX_Data											=> TX_Glue_Data,
				TX_SOT											=> TX_Glue_SOT,
				TX_EOT											=> TX_Glue_EOT,
				TX_Ack											=> Transport_TX_Ack,

				-- RX path
				RX_Valid										=> Transport_RX_Valid,
				RX_Data											=> Transport_RX_Data,
				RX_SOT											=> Transport_RX_SOT,
				RX_EOT											=> Transport_RX_EOT,
				RX_Ack											=> RX_Glue_Ack,

				-- LinkLayer interface
				Link_ResetDone							=> Link_ResetDone,
				Link_Command								=> Link_Command,
				Link_Status									=> Link_Status,
				SATAGeneration 							=> Phy_RP_SATAGeneration(i),

				-- TX path
				Link_TX_Valid								=> Transport_TX_Valid,
				Link_TX_Data								=> Transport_TX_Data,
				Link_TX_SOF									=> Transport_TX_SOF,
				Link_TX_EOF									=> Transport_TX_EOF,
				Link_TX_Ack									=> Link_TX_Ack,
				Link_TX_InsertEOF						=> Link_TX_InsertEOF,				-- helper signal: insert EOF - max frame size reached

				Link_TX_FS_Valid						=> Link_TX_FS_Valid,
				Link_TX_FS_SendOK						=> Link_TX_FS_SendOK,
				Link_TX_FS_SyncEsc					=> Link_TX_FS_SyncEsc,
				Link_TX_FS_Ack							=> Transport_TX_FS_Ack,

				-- RX path
				Link_RX_Valid								=> Link_RX_Valid,
				Link_RX_Data								=> Link_RX_Data,
				Link_RX_SOF									=> Link_RX_SOF,
				Link_RX_EOF									=> Link_RX_EOF,
				Link_RX_Ack									=> Transport_RX_Ack,

				Link_RX_FS_Valid						=> Link_RX_FS_Valid,
				Link_RX_FS_CRCOK						=> Link_RX_FS_CRCOK,
				Link_RX_FS_SyncEsc					=> Link_RX_FS_SyncEsc,
				Link_RX_FS_Ack							=> Transport_RX_FS_Ack
			);



		-- The CSE interface of the TransportLayer is ready, when the CSE interface
		-- of the LinkLayer is ready.
		Transport_ResetDone <= Link_ResetDone;

		-- =========================================================================
		-- link layer
		-- =========================================================================
		Link : entity PoC.sata_LinkLayer
			generic map (
				DEBUG												=> DEBUG,
				ENABLE_DEBUGPORT						=> ENABLE_DEBUGPORT,
				CONTROLLER_TYPE							=> CONTROLLER_TYPES_I(i),
				AHEAD_CYCLES_FOR_INSERT_EOF	=> AHEAD_CYCLES_FOR_INSERT_EOF_I(i),
				MAX_FRAME_SIZE							=> MAX_FRAME_SIZE_I(i)
			)
			port map (
				Clock										=> SATA_Clock_i(i),
				ClockEnable							=> SATA_Clock_Stable_i(i),
				Reset										=> Reset(i),

				Command									=> Link_Command,
				Status									=> Link_Status,
				Error										=> Link_Error,

				-- Debug ports
				DebugPortIn						 	=> Link_DebugPortIn,
				DebugPortOut					 	=> Link_DebugPortOut,

				-- TX port
				TX_SOF									=> Transport_TX_SOF,
				TX_EOF									=> Transport_TX_EOF,
				TX_Valid								=> Transport_TX_Valid,
				TX_Data									=> Transport_TX_Data,
				TX_Ack									=> Link_TX_Ack,
				TX_InsertEOF						=> Link_TX_InsertEOF,

				TX_FS_Ack								=> Transport_TX_FS_Ack,
				TX_FS_Valid							=> Link_TX_FS_Valid,
				TX_FS_SendOK						=> Link_TX_FS_SendOK,
				TX_FS_SyncEsc						=> Link_TX_FS_SyncEsc,

				-- RX port
				RX_SOF									=> Link_RX_SOF,
				RX_EOF									=> Link_RX_EOF,
				RX_Valid								=> Link_RX_Valid,
				RX_Data									=> Link_RX_Data,
				RX_Ack									=> Transport_RX_Ack,

				RX_FS_Ack								=> Transport_RX_FS_Ack,
				RX_FS_Valid							=> Link_RX_FS_Valid,
				RX_FS_CRCOK							=> Link_RX_FS_CRCOK,
				RX_FS_SyncEsc						=> Link_RX_FS_SyncEsc,

				-- physical layer interface
				Phy_ResetDone 					=> Phy_ResetDone,
				Phy_Status							=> Phy_Status,

				Phy_RX_Data							=> Phy_RX_Data,
				Phy_RX_CharIsK					=> Phy_RX_CharIsK,

				Phy_TX_Data							=> Link_TX_Data,
				Phy_TX_CharIsK					=> Link_TX_CharIsK
			);

		-- The CSE interface of the Linklayer is ready, when the CSE interface
		-- of the PHY is ready.
		Link_ResetDone 	<= Phy_ResetDone;
		Phy_Command 		<= SATA_PHY_CMD_NONE;

		-- =========================================================================
		-- physical layer
		-- =========================================================================
		Phy : entity PoC.sata_PhysicalLayer
			generic map (
				DEBUG													=> DEBUG,
				ENABLE_DEBUGPORT							=> ENABLE_DEBUGPORT,
				CONTROLLER_TYPE								=> CONTROLLER_TYPES_I(i),
				ALLOW_SPEED_NEGOTIATION				=> ALLOW_SPEED_NEGOTIATION_I(i),
				INITIAL_SATA_GENERATION				=> INITIAL_SATA_GENERATIONS_I(i),
				ALLOW_STANDARD_VIOLATION			=> ALLOW_STANDARD_VIOLATION_I(i),
				OOB_TIMEOUT										=> OOB_TIMEOUT_I(i),		--ite(SIMULATION, 15, OOB_TIMEOUT_US(i)),			-- simulation: limit OOBTimeout to 15 us
				GENERATION_CHANGE_COUNT				=> GENERATION_CHANGE_COUNT_I(i),
				ATTEMPTS_PER_GENERATION				=> ATTEMPTS_PER_GENERATION_I(i)
			)
			port map (
				Clock													=> SATA_Clock_i(i),
				ClockEnable										=> SATA_Clock_Stable_i(i),
				Reset													=> Reset(i),
				SATAGenerationMin							=> SATAGenerationMin(i),
				SATAGenerationMax							=> SATAGenerationMax(i),

				Command												=> Phy_Command,
				Status												=> Phy_Status,
				Error													=> Phy_Error,

				DebugPortOut									=> Phy_DebugPortOut,

				Link_RX_Data									=> Phy_RX_Data,
				Link_RX_CharIsK								=> Phy_RX_CharIsK,

				Link_TX_Data									=> Link_TX_Data,
				Link_TX_CharIsK								=> Link_TX_CharIsK,

				-- transceiver interface
				Trans_ResetDone								=> Transceiver_ResetDone(i),

				Trans_Command									=> Transceiver_Command(i),
				Trans_Status									=> Transceiver_Status(i),
				Trans_Error										=> Transceiver_Error(i),

				-- reconfiguration interface
				Trans_RP_Reconfig							=> Phy_RP_Reconfig(i),
				Trans_RP_SATAGeneration				=> Phy_RP_SATAGeneration(i),
				Trans_RP_ConfigReloaded				=> Transceiver_RP_ConfigReloaded(i),

				Trans_OOB_TX_Command					=> Phy_OOB_TX_Command(i),
				Trans_OOB_TX_Complete					=> Transceiver_OOB_TX_Complete(i),
				Trans_OOB_RX_Received					=> Transceiver_OOB_RX_Received(i),
				Trans_OOB_HandshakeComplete		=> Phy_OOB_HandshakeComplete(i),
				Trans_OOB_AlignDetected				=> Phy_OOB_AlignDetected(i),

				Trans_TX_Data									=> Phy_TX_Data(i),
				Trans_TX_CharIsK							=> Phy_TX_CharIsK(i),

				Trans_RX_Data									=> Transceiver_RX_Data(i),
				Trans_RX_CharIsK							=> Transceiver_RX_CharIsK(i),
				Trans_RX_Valid								=> Transceiver_RX_Valid(i)
			);

		-- The CSE interface of the PHY is ready, when the CSE interface
		-- of the transceiver is ready.
		Phy_ResetDone <= Transceiver_ResetDone(i);

		-- =========================================================================
		-- debug port
		-- =========================================================================
		genDebugPort : if (ENABLE_DEBUGPORT = TRUE) generate
			-- Transport Layer
			DebugPortOut(i).TransportLayer						<= Transport_DebugPortOut;
			DebugPortOut(i).Transport_Command					<= Transport_Command;
			DebugPortOut(i).Transport_Status					<= Transport_Status;
			DebugPortOut(i).Transport_Error						<= Transport_Error;

			-- Link Layer
			Link_DebugPortIn											<= DebugPortIn(i).LinkLayer;

			DebugPortOut(i).LinkLayer							<= Link_DebugPortOut;				-- RX: 125 + TX: 120 bit
			DebugPortOut(i).Link_Command					<= Link_Command;						-- 1 bit
			DebugPortOut(i).Link_Status						<= Link_Status;							-- 3 bit
			DebugPortOut(i).Link_Error						<= Link_Error;

			-- Physical Layer
			DebugPortOut(i).PhysicalLayer					<= Phy_DebugPortOut;				--
			DebugPortOut(i).Physical_Command			<= Phy_Command;							--
			DebugPortOut(i).Physical_Status				<= Phy_Status;							-- 3 bit
			DebugPortOut(i).Physical_Error				<= Phy_Error;								--

			-- Transceiver Layer
			Transceiver_DebugPortIn(i)						<= DebugPortIn(i).TransceiverLayer;

			DebugPortOut(i).TransceiverLayer			<= Transceiver_DebugPortOut(i);		--
			DebugPortOut(i).Transceiver_Command		<= Transceiver_Command(i);				--
			DebugPortOut(i).Transceiver_Status		<= Transceiver_Status(i);					--
			DebugPortOut(i).Transceiver_Error			<= Transceiver_Error(i);					--

		end generate;
		genNoDebugPort : if not(ENABLE_DEBUGPORT = TRUE) generate
			Link_DebugPortIn											<= C_SATADBG_LINK_IN_EMPTY;
			Transceiver_DebugPortIn(i)						<= C_SATADBG_TRANSCEIVER_IN_EMPTY;
		end generate;
	end generate;

	-- ===========================================================================
	-- transceiver layer
	-- ===========================================================================
	Trans : entity PoC.sata_TransceiverLayer
		generic map (
			DEBUG											=> DEBUG,
			ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
			REFCLOCK_FREQ							=> REFCLOCK_FREQ,
			PORTS											=> PORTS,
			INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS_I
		)
		port map (
			ClockNetwork_Reset				=> ClockNetwork_Reset,
			ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

			PowerDown									=> PowerDown,
			Reset											=> Reset,

			-- CSE interface
			ResetDone									=> Transceiver_ResetDone,
			Command										=> Transceiver_Command,
			Status										=> Transceiver_Status,
			Error											=> Transceiver_Error,

			-- debug ports
			DebugPortIn								=> Transceiver_DebugPortIn,
			DebugPortOut							=> Transceiver_DebugPortOut,

			SATA_Clock								=> SATA_Clock_i,
			SATA_Clock_Stable					=> SATA_Clock_Stable_i,

			RP_Reconfig								=> Phy_RP_Reconfig,
			RP_SATAGeneration					=> Phy_RP_SATAGeneration,
			RP_ConfigReloaded					=> Transceiver_RP_ConfigReloaded,
			RP_Lock										=> (others => '0'),

			OOB_TX_Command						=> Phy_OOB_TX_Command,
			OOB_TX_Complete						=> Transceiver_OOB_TX_Complete,
			OOB_RX_Received						=> Transceiver_OOB_RX_Received,
			OOB_HandshakeComplete			=> Phy_OOB_HandshakeComplete,
			OOB_AlignDetected 				=> Phy_OOB_AlignDetected,

			TX_Data										=> Phy_TX_Data,
			TX_CharIsK								=> Phy_TX_CharIsK,

			RX_Data										=> Transceiver_RX_Data,
			RX_CharIsK								=> Transceiver_RX_CharIsK,
			RX_Valid									=> Transceiver_RX_Valid,

			-- vendor specific signals
			VSS_Common_In							=> VSS_Common_In,
			VSS_Private_In						=> VSS_Private_In,
			VSS_Private_Out						=> VSS_Private_Out
		);

	SATA_Clock 				<= SATA_Clock_i;
	SATA_Clock_Stable <= SATA_Clock_Stable_i;
end;
