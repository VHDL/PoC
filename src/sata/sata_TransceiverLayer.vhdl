-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--									Thomas Frank
--									Steffen Koehler
--
-- Description:
-- ------------------------------------
--		TODO
-- 
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.physical.ALL;
USE			PoC.sata.ALL;
USE			PoC.satacomp.ALL;
USE			PoC.satadbg.ALL;
USE			PoC.sata_TransceiverTypes.ALL;


ENTITY sata_TransceiverLayer IS
	GENERIC (
		DEBUG											: BOOLEAN											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: BOOLEAN											:= FALSE;																		-- export internal signals to upper layers for debug purposes
		CLOCK_IN_FREQ							: FREQ												:= 150.0 MHz;																							-- 150 MHz
		PORTS											: POSITIVE										:= 2;																											-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 => SATA_GENERATION_2,	1 => SATA_GENERATION_2)				-- intial SATA Generation
	);
	PORT (
		Reset											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		PowerDown									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
		Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Error									: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Error									: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
		-- debug ports
		DebugPortIn								: IN	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 DOWNTO 0);
		DebugPortOut							: OUT	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 DOWNTO 0);

		SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_SATAGeneration					: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
		RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		OOB_TX_Command						: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
		OOB_TX_Complete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		OOB_RX_Received						: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);		
		OOB_HandshakeComplete			: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
		TX_CharIsK								: IN	T_SLVV_4(PORTS - 1 DOWNTO 0);

		RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
		RX_CharIsK								: OUT	T_SLVV_4(PORTS - 1 DOWNTO 0);
		RX_Valid									: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		-- vendor specific signals
		VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
		VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF sata_TransceiverLayer IS
	ATTRIBUTE KEEP 								: BOOLEAN;

	CONSTANT C_DEVICE_INFO				: T_DEVICE_INFO		:= DEVICE_INFO;
	
BEGIN
	genReport : FOR I IN 0 TO PORTS - 1 GENERATE
		ASSERT FALSE REPORT "Port:    " & INTEGER'image(I)																										SEVERITY NOTE;
		ASSERT FALSE REPORT "  Init. SATA Generation: Gen " & INTEGER'image(INITIAL_SATA_GENERATIONS(I) + 1)	SEVERITY NOTE;
	END GENERATE;

-- ==================================================================
-- Assert statements
-- ==================================================================
	ASSERT ((C_DEVICE_INFO.VENDOR = VENDOR_XILINX) OR 
					(C_DEVICE_INFO.VENDOR = VENDOR_ALTERA))
		REPORT "Vendor not yet supported."
		SEVERITY FAILURE;
		
	ASSERT ((C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_VIRTEX) OR 
					(C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_KINTEX) OR
					(C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_STRATIX))
		REPORT "Device family not yet supported."
		SEVERITY FAILURE;
		
	ASSERT ((C_DEVICE_INFO.DEVICE = DEVICE_VIRTEX5) OR
					(C_DEVICE_INFO.DEVICE = DEVICE_KINTEX7) OR
					(C_DEVICE_INFO.DEVICE = DEVICE_STRATIX2) OR
					(C_DEVICE_INFO.DEVICE = DEVICE_STRATIX4))
		REPORT "Device not yet supported."
		SEVERITY FAILURE;
		
	ASSERT ((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTP_DUAL) OR
					(C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE2) OR
					(C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GXB))
		REPORT "Transceiver not yet supported."
		SEVERITY FAILURE;
		
	ASSERT (((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTP_DUAL)	AND (PORTS <= 2)) OR
					((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE1)		AND (PORTS <= 4)) OR
					((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE2)		AND (PORTS <= 4)) OR
					((C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GXB)			AND (PORTS <= 2)))
		REPORT "To many ports per transceiver."
		SEVERITY FAILURE;
	
	genXilinx : IF (C_DEVICE_INFO.VENDOR = VENDOR_XILINX) GENERATE
		genGPT_DUAL : IF (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTP_DUAL) GENERATE
			Trans : sata_Transceiver_Virtex5_GTP
				GENERIC MAP (
					DEBUG											=> DEBUG,
					CLOCK_IN_FREQ							=> CLOCK_IN_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,
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

					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
					);
		END GENERATE;	-- Xilinx.Virtex5.GTP_DUAL
		genGTXE1 : IF (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE1) GENERATE
			Trans : sata_Transceiver_Virtex6_GTXE1
				GENERIC MAP (
					DEBUG											=> DEBUG,
					CLOCK_IN_FREQ							=> CLOCK_IN_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,
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

					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		END GENERATE;	-- Xilinx.Virtex6.GTXE1
		genGTXE2 : IF (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE2) GENERATE
			Trans : sata_Transceiver_Series7_GTXE2
				GENERIC MAP (
					DEBUG											=> DEBUG,
					ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
					CLOCK_IN_FREQ							=> CLOCK_IN_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,
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

					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		END GENERATE;	-- Xilinx.Series7.GTXE2
	END GENERATE;		-- Xilinx.*
	genAltera : IF (C_DEVICE_INFO.VENDOR = VENDOR_ALTERA) GENERATE
		genS2GX_GXB : IF ((C_DEVICE_INFO.DEVICE = DEVICE_STRATIX2) AND (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GXB)) GENERATE
			Trans : sata_Transceiver_Stratix2GX_GXB
				GENERIC MAP (
					CLOCK_IN_FREQ							=> CLOCK_IN_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,
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

					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		END GENERATE;	-- Altera.Stratix2.GXB
		genS4GX_GXB : IF ((C_DEVICE_INFO.DEVICE = DEVICE_STRATIX4) AND (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GXB)) GENERATE
			Trans : sata_Transceiver_Stratix4GX_GXB
				GENERIC MAP (
					CLOCK_IN_FREQ							=> CLOCK_IN_FREQ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					Reset											=> Reset,
					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					PowerDown									=> PowerDown,
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,
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

					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_Valid									=> RX_Valid,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		END GENERATE;	-- Altera.Stratix4.GXB
	END GENERATE;		-- Altera.*
END;
