-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Thomas Frank
--									Steffen Koehler
--									Martin Zabel
--
-- Module: 					Wrapper for Device-Specific Transceivers
--
-- Description:
-- ------------------------------------
-- Asynchronous signals: PowerDown, ClockNetwork_Reset, ClockNetwork_ResetDone
-- Transceiver In/Outputs: VSS_*
--
-- All other signals are synchronous to SATA_Clock.
--
-- The transceiver asserts ResetDone when his Command-Status-Error
-- interface is ready after powerup or asynchronous reset. It is only
-- deasserted in case of powerdown or asynchronous reset, if supported by
-- the transceiver. SATA_Clock_Stable is asserted at least one cycle before
-- ResetDone is asserted. All upper layers must be hold in reset as long as
-- ResetDone is deasserted.
--
-- SATA_Clock might go instable (SATA_Clock_Stable low) during change of
-- SATA generation. ResetDone is kept asserted because Status and Error are
-- still valid but are not changing until the SATA_Clock is stable again.
--
-- The transceiver has its own internal reset procedure. Synchronous reset
-- via input Reset is an optional feature.
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
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.components.all;
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satacomp.all;
use			PoC.satadbg.all;
use			PoC.sata_TransceiverTypes.all;


entity sata_TransceiverLayer is
	generic (
		DEBUG											: BOOLEAN											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: BOOLEAN											:= FALSE;																		-- export internal signals to upper layers for debug purposes
		REFCLOCK_FREQ							: FREQ												:= 150 MHz;																								-- 150 MHz
		PORTS											: POSITIVE										:= 2;																											-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 => SATA_GENERATION_2,	1 => SATA_GENERATION_2)				-- intial SATA Generation
	);
	port (
		-- @async --------------------------------------------------------------------------------
		PowerDown									: in	STD_LOGIC_VECTOR(portS - 1 downto 0);
		ClockNetwork_Reset				: in	STD_LOGIC_VECTOR(portS - 1 downto 0);
		ClockNetwork_ResetDone		: out	STD_LOGIC_VECTOR(portS - 1 downto 0);

		-- @SATA_Clock ---------------------------------------------------------------------------
		Reset											: in	STD_LOGIC_VECTOR(portS - 1 downto 0);
		ResetDone									: out	STD_LOGIC_VECTOR(portS - 1 downto 0);

		Command										: in	T_SATA_TRANSCEIVER_COMMAND_VECTOR(portS - 1 downto 0);
		Status										: out	T_SATA_TRANSCEIVER_STATUS_VECTOR(portS - 1 downto 0);
		Error											: out	T_SATA_TRANSCEIVER_ERROR_VECTOR(portS - 1 downto 0);

		-- debug ports
		DebugPortIn								: IN	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 DOWNTO 0);
		DebugPortOut							: OUT	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 DOWNTO 0);

		SATA_Clock								: out	STD_LOGIC_VECTOR(portS - 1 downto 0);
		SATA_Clock_Stable					: out	STD_LOGIC_VECTOR(portS - 1 downto 0);

		RP_Reconfig								: in	STD_LOGIC_VECTOR(portS - 1 downto 0);
		RP_SATAGeneration					: in	T_SATA_GENERATION_VECTOR(portS - 1 downto 0);
		RP_ReconfigComplete				: out	STD_LOGIC_VECTOR(portS - 1 downto 0);
		RP_ConfigReloaded					: out	STD_LOGIC_VECTOR(portS - 1 downto 0);
		RP_Lock										:	IN	STD_LOGIC_VECTOR(portS - 1 downto 0);
		RP_Locked									: out	STD_LOGIC_VECTOR(portS - 1 downto 0);

		OOB_TX_Command						: in	T_SATA_OOB_VECTOR(portS - 1 downto 0);
		OOB_TX_Complete						: out	STD_LOGIC_VECTOR(portS - 1 downto 0);
		OOB_RX_Received						: out	T_SATA_OOB_VECTOR(portS - 1 downto 0);		
		OOB_HandshakeComplete			: in	STD_LOGIC_VECTOR(portS - 1 downto 0);
		OOB_AlignDetected    			: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		
		TX_Data										: in	T_SLVV_32(portS - 1 downto 0);
		TX_CharIsK								: in	T_SLVV_4(portS - 1 downto 0);

		RX_Data										: out	T_SLVV_32(portS - 1 downto 0);
		RX_CharIsK								: out	T_SLVV_4(portS - 1 downto 0);
		RX_Valid									: out STD_LOGIC_VECTOR(portS - 1 downto 0);
		
		-- vendor specific signals
		VSS_Common_In							: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In						: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(portS	- 1 downto 0);
		VSS_Private_Out						: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(portS	- 1 downto 0)
	);
end;


architecture rtl of sata_TransceiverLayer is
	attribute KEEP 								: BOOLEAN;

	constant C_DEVICE_INFO				: T_DEVICE_INFO		:= DEVICE_INFO;

	signal TX_Data_i 		: T_SLVV_32(PORTS - 1 downto 0);
	signal RX_Data_i 		: T_SLVV_32(PORTS - 1 downto 0);
	signal RX_CharIsK_i : T_SLVV_4(PORTS - 1 downto 0);
	
begin
	genreport : for i in 0 to portS - 1 generate
		assert FALSE report "port:    " & INTEGER'image(I)																										severity NOTE;
		assert FALSE report "  Init. SATA Generation: Gen " & INTEGER'image(INITIAL_SATA_GENERATIONS(I) + 1)	severity NOTE;
	end generate;

-- ==================================================================
-- assert statements
-- ==================================================================
	assert ((C_DEVICE_INFO.VENDOR = VENDOR_ALTERA) or
					(C_DEVICE_INFO.VENDOR = VENDOR_XILINX)) 
		report "Vendor not yet supported."
		severity FAILURE;
		
	assert ((C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_ZYNQ) or
					(C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_KINTEX) or
					(C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_VIRTEX) or 
					(C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_STRATIX))
		report "Device family not yet supported."
		severity FAILURE;
		
	assert ((C_DEVICE_INFO.DEVICE = DEVICE_VIRTEX5) or
					(C_DEVICE_INFO.DEVICE = DEVICE_ZYNQ7) or
					(C_DEVICE_INFO.DEVICE = DEVICE_KINTEX7) or
					(C_DEVICE_INFO.DEVICE = DEVICE_VIRTEX7) or
					(C_DEVICE_INFO.DEVICE = DEVICE_STRATIX2) or
					(C_DEVICE_INFO.DEVICE = DEVICE_STRATIX4))
		report "Device not yet supported."
		severity FAILURE;
		
	assert ((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTP_DUAL) or
					(C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE2) or
					(C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GXB))
		report "Transceiver not yet supported."
		severity FAILURE;
		
	assert (((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTP_DUAL)	and (portS <= 2)) or
					((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE1)		and (portS <= 4)) or
					((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE2)		and (portS <= 4)) or
					((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GXB)			and (portS <= 2)))
		report "To many ports per transceiver."
		severity FAILURE;

	
-- ==================================================================
-- insert bit errors
-- ==================================================================

	RX_CharIsK <= RX_CharIsK_i;
	
	genBitError : if (ENABLE_DEBUGPORT = TRUE) generate
		-- Insert BitErrors
		genPort : for i in 0 to PORTS - 1 generate
			TX_Data_i(i) <= mux(DebugPortIn(i).InsertBitErrorTX and not TX_CharIsK(i)(0), -- only for data
													TX_Data(i),   not TX_Data(i));
			RX_Data  (i) <= mux(DebugPortIn(i).InsertBitErrorRX and not RX_CharIsK_i(i)(0), -- only for data
													RX_Data_i(i), not RX_Data_i(i));
		end generate;
	end generate;

	genNoBitError : if not(ENABLE_DEBUGPORT = TRUE) generate
		TX_Data_i <= TX_Data;
		RX_Data 	<= RX_Data_i;
	end generate;

	
-- ==================================================================
-- transeiver instances
-- ==================================================================
	
	genXilinx : if (C_DEVICE_INFO.VENDOR = VENDOR_XILINX) generate
		genGPT_DUAL : if (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTP_DUAL) generate
			Trans : sata_Transceiver_Virtex5_GTP
				generic map (
					DEBUG											=> DEBUG,
					CLOCK_IN_FREQ							=> REFCLOCK_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				port map (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					Error											=> Error,

					-- debug ports
					DebugPortIn								=> DebugPortIn,
					DebugPortOut							=> DebugPortOut,

					SATA_Clock								=> SATA_Clock,

					RP_Reconfig								=> RP_Reconfig,
					RP_SATAGeneration					=> RP_SATAGeneration,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					OOB_TX_Command						=> OOB_TX_Command,
					OOB_TX_Complete						=> OOB_TX_Complete,
					OOB_RX_Received						=> OOB_RX_Received,
					OOB_HandshakeComplete			=> OOB_HandshakeComplete,

					TX_Data										=> TX_Data_i,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data_i,
					RX_CharIsK								=> RX_CharIsK_i,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
					);
		end generate;	-- Xilinx.Virtex5.GTP_DUAL
		genGTXE1 : if (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE1) generate
			Trans : sata_Transceiver_Virtex6_GTXE1
				generic map (
					DEBUG											=> DEBUG,
					CLOCK_IN_FREQ							=> REFCLOCK_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				port map (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					Error											=> Error,

					-- debug ports
					DebugPortIn								=> DebugPortIn,
					DebugPortOut							=> DebugPortOut,

					SATA_Clock								=> SATA_Clock,

					RP_Reconfig								=> RP_Reconfig,
					RP_SATAGeneration					=> RP_SATAGeneration,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					OOB_TX_Command						=> OOB_TX_Command,
					OOB_TX_Complete						=> OOB_TX_Complete,
					OOB_RX_Received						=> OOB_RX_Received,
					OOB_HandshakeComplete			=> OOB_HandshakeComplete,

					TX_Data										=> TX_Data_i,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data_i,
					RX_CharIsK								=> RX_CharIsK_i,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		end generate;	-- Xilinx.Virtex6.GTXE1
		genGTXE2 : if (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE2) generate
			Trans : sata_Transceiver_Series7_GTXE2
				generic map (
					DEBUG											=> DEBUG,
					ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
					REFCLOCK_FREQ							=> REFCLOCK_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				port map (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					Error											=> Error,

					-- debug ports
					DebugPortIn								=> DebugPortIn,
					DebugPortOut							=> DebugPortOut,

					SATA_Clock								=> SATA_Clock,
					SATA_Clock_Stable					=> SATA_Clock_Stable,

					RP_Reconfig								=> RP_Reconfig,
					RP_SATAGeneration					=> RP_SATAGeneration,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					OOB_TX_Command						=> OOB_TX_Command,
					OOB_TX_Complete						=> OOB_TX_Complete,
					OOB_RX_Received						=> OOB_RX_Received,
					OOB_HandshakeComplete			=> OOB_HandshakeComplete,
					OOB_AlignDetected 				=> OOB_AlignDetected,

					TX_Data										=> TX_Data_i,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data_i,
					RX_CharIsK								=> RX_CharIsK_i,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		end generate;	-- Xilinx.Series7.GTXE2
	end generate;		-- Xilinx.*
	genAltera : if (C_DEVICE_INFO.VENDOR = VENDOR_ALTERA) generate
		genS2GX_GXB : if ((C_DEVICE_INFO.DEVICE = DEVICE_STRATIX2) and (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GXB)) generate
			Trans : sata_Transceiver_Stratix2GX_GXB
				generic map (
					CLOCK_IN_FREQ							=> REFCLOCK_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				port map (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					Error											=> Error,

					-- debug ports
--					DebugPortIn								=> DebugPortIn,
--					DebugPortOut							=> DebugPortOut,

					SATA_Clock								=> SATA_Clock,

					RP_Reconfig								=> RP_Reconfig,
					RP_SATAGeneration					=> RP_SATAGeneration,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					OOB_TX_Command						=> OOB_TX_Command,
					OOB_TX_Complete						=> OOB_TX_Complete,
					OOB_RX_Received						=> OOB_RX_Received,
					OOB_HandshakeComplete			=> OOB_HandshakeComplete,

					TX_Data										=> TX_Data_i,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data_i,
					RX_CharIsK								=> RX_CharIsK_i,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		end generate;	-- Altera.Stratix2.GXB
		genS4GX_GXB : if ((C_DEVICE_INFO.DEVICE = DEVICE_STRATIX4) and (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GXB)) generate
			Trans : sata_Transceiver_Stratix4GX_GXB
				generic map (
					CLOCK_IN_FREQ							=> REFCLOCK_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				port map (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					Error											=> Error,

					-- debug ports
--					DebugPortIn								=> DebugPortIn,
--					DebugPortOut							=> DebugPortOut,

					SATA_Clock								=> SATA_Clock,

					RP_Reconfig								=> RP_Reconfig,
					RP_SATAGeneration					=> RP_SATAGeneration,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					OOB_TX_Command						=> OOB_TX_Command,
					OOB_TX_Complete						=> OOB_TX_Complete,
					OOB_RX_Received						=> OOB_RX_Received,
					OOB_HandshakeComplete			=> OOB_HandshakeComplete,

					TX_Data										=> TX_Data_i,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data_i,
					RX_CharIsK								=> RX_CharIsK_i,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		end generate;	-- Altera.Stratix4.GXB
	end generate;		-- Altera.*
	
-- ==================================================================
-- debugport
-- ==================================================================
	
	genDebugPort : if (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_generateCommandEncodings return string is
			variable  l : STD.TextIO.line;
		begin
			for i in T_SATA_TRANSCEIVER_COMMAND loop
				STD.TextIO.write(l, str_replace(T_SATA_TRANSCEIVER_COMMAND'image(i), "sata_transceiver_cmd_", ""));
				STD.TextIO.write(l, ';');
			end loop;
			return  l.all;
		end function;
		
		function dbg_generateStatusEncodings return string is
			variable  l : STD.TextIO.line;
		begin
			for i in T_SATA_TRANSCEIVER_STATUS loop
				STD.TextIO.write(l, str_replace(T_SATA_TRANSCEIVER_STATUS'image(i), "sata_transceiver_status_", ""));
				STD.TextIO.write(l, ';');
			end loop;
			return  l.all;
		end function;
		
		function dbg_generateCommonErrorEncodings return string is
			variable  l : STD.TextIO.line;
		begin
			for i in T_SATA_TRANSCEIVER_COMMON_ERROR loop
				STD.TextIO.write(l, str_replace(T_SATA_TRANSCEIVER_COMMON_ERROR'image(i), "sata_transceiver_common_error_", ""));
				STD.TextIO.write(l, ';');
			end loop;
			return  l.all;
		end function;
		
		function dbg_generateTXErrorEncodings return string is
			variable  l : STD.TextIO.line;
		begin
			for i in T_SATA_TRANSCEIVER_TX_ERROR loop
				STD.TextIO.write(l, str_replace(T_SATA_TRANSCEIVER_TX_ERROR'image(i), "sata_transceiver_tx_error_", ""));
				STD.TextIO.write(l, ';');
			end loop;
			return  l.all;
		end function;
		
		function dbg_generateRXErrorEncodings return string is
			variable  l : STD.TextIO.line;
		begin
			for i in T_SATA_TRANSCEIVER_RX_ERROR loop
				STD.TextIO.write(l, str_replace(T_SATA_TRANSCEIVER_RX_ERROR'image(i), "sata_transceiver_rx_error_", ""));
				STD.TextIO.write(l, ';');
			end loop;
			return  l.all;
		end function;

		constant dummy : T_BOOLVEC := (
			0 => dbg_ExportEncoding("Transceiver Layer - Command Enum",				dbg_generateCommandEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Transceiver_Command.tok"),
			1 => dbg_ExportEncoding("Transceiver Layer - Status Enum",				dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Transceiver_Status.tok"),
			2 => dbg_ExportEncoding("Transceiver Layer - Common Error Enum",	dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Transceiver_Error_Common.tok"),
			3 => dbg_ExportEncoding("Transceiver Layer - TX Error Enum",			dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Transceiver_Error_TX.tok"),
			4 => dbg_ExportEncoding("Transceiver Layer - RX Error Enum",			dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Transceiver_Error_RX.tok")
		);
	begin
	end generate;
end;
