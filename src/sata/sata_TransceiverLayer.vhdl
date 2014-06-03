-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
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
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.strings.ALL;
--USE			PoC.sata.ALL;


ENTITY sata_SATATransceiver IS
	GENERIC (
		DEBUG											: BOOLEAN											:= FALSE;
		CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																									-- 150 MHz
		PORTS											: POSITIVE										:= 2;																											-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 => SATA_GENERATION_2,	1 => SATA_GENERATION_2)				-- intial SATA Generation
	);
	PORT (
		SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		SATA_Generation						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
		OOB_HandshakingComplete		: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
		Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Error									: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Error									: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

		DebugPortOut							: OUT T_DBG_TRANSOUT_VECTOR(PORTS	- 1 DOWNTO 0);

		RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
		RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
		RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
		TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
		TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
		
		-- vendor specific signals
		VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
		VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF sata_SATATransceiver IS
	ATTRIBUTE KEEP 								: BOOLEAN;

	FUNCTION ite(cond : BOOLEAN; value1 : devgrp_t; value2 : devgrp_t) RETURN devgrp_t IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END;

	CONSTANT DEVICE_GROUP			: devgrp_t		:= DEVGRP;		-- ite(((DEVICE = DEVICE_VIRTEX5) AND SIMULATION), DEVGRP_V6LXT, DEVGRP);				-- default is Xilinx.Virtex6.LXT => can be simulated
	
--	ATTRIBUTE KEEP OF SATA_Clock	: SIGNAL IS "TRUE";
BEGIN

	genReport : FOR I IN 0 TO PORTS - 1 GENERATE
		ASSERT FALSE REPORT "Port:    " & ite((I = 0), "0", ite((I = 1), "1", ite((I = 2), "2", ite((I = 3), "3", ite((I = 4), "4", "X"))))) SEVERITY NOTE;
--		ASSERT FALSE REPORT "  ControllerType:         " & ite((CONTROLLER_TYPES(I)					= SATA_DEVICE_TYPE_HOST), "HOST", "DEVICE") SEVERITY NOTE;
--		ASSERT FALSE REPORT "  AllowSpeedNegotiation:  " & ite((ALLOW_SPEED_NEGOTIATION(I)	= TRUE),									"YES",	"NO")			SEVERITY NOTE;
--		ASSERT FALSE REPORT "  AllowAutoReconnect:     " & ite((ALLOW_AUTO_RECONNECT(I)			= TRUE),									"YES",	"NO")			SEVERITY NOTE;
--		ASSERT FALSE REPORT "  AllowStandardViolation: " & ite((ALLOW_STANDARD_VIOLATION(I)	= TRUE),									"YES",	"NO")			SEVERITY NOTE;
		ASSERT FALSE REPORT "  Init. SATA Generation:  " & ite((INITIAL_SATA_GENERATIONS(I)	= SATA_GENERATION_1),			"Gen1", "Gen2")		SEVERITY NOTE;
	END GENERATE;

-- ==================================================================
-- Assert statements
-- ==================================================================
	ASSERT (NOT ((DEVICE = DEVICE_VIRTEX5) AND
							 SIMULATION))
		 REPORT "Xilinx Virtex5 simulation model is incomplete => device group V5LXT replaced throught V6LXT."
		 SEVERITY WARNING;

	ASSERT ((VENDOR = VENDOR_XILINX) OR 
					(VENDOR = VENDOR_ALTERA))
		REPORT "Vendor not yet supported."
		SEVERITY FAILURE;
		
	ASSERT ((DEVFAM = DEVFAM_VIRTEX) OR 
					(DEVFAM = DEVFAM_STRATIX))
		REPORT "Device family not yet supported."
		SEVERITY FAILURE;
		
	ASSERT ((DEVICE = DEVICE_VIRTEX5) OR
					(DEVICE = DEVICE_VIRTEX6) OR
					(DEVICE = DEVICE_STRATIX2) OR
					(DEVICE = DEVICE_STRATIX4))
		REPORT "Device not yet supported."
		SEVERITY FAILURE;
		
	ASSERT ((DEVICE_GROUP = DEVGRP_V5LXT) OR
					(DEVICE_GROUP = DEVGRP_V6LXT) OR 
					(DEVICE_GROUP = DEVGRP_S2GX) OR
					(DEVICE_GROUP = DEVGRP_S4GX))
		REPORT "Device group not yet supported."
		SEVERITY FAILURE;
		
	ASSERT (((DEVICE_GROUP = DEVGRP_V5LXT) AND (PORTS <= 2)) OR
					((DEVICE_GROUP = DEVGRP_V6LXT) AND (PORTS <= 4)) OR
					((DEVICE_GROUP = DEVGRP_S2GX)  AND (PORTS <= 2)) OR
					((DEVICE_GROUP = DEVGRP_S4GX)  AND (PORTS <= 2)))
		REPORT "To many ports per transceiver."
		SEVERITY FAILURE;
	
	genXilinx : IF (VENDOR = VENDOR_XILINX) GENERATE
		genV5LXT : IF (DEVICE_GROUP = DEVGRP_V5LXT) GENERATE
			V5GTP : SATATransceiver_Virtex5_GTP
				GENERIC MAP (
					DEBUG											=> DEBUG					,
					CLOCK_IN_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					SATA_Clock								=> SATA_Clock,

					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					RP_Reconfig								=> RP_Reconfig,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					SATA_Generation						=> SATA_Generation,
					OOB_HandshakingComplete		=> OOB_HandshakingComplete,
					
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,

--					DebugPortOut							=> DebugPortOut,

					RX_OOBStatus							=> RX_OOBStatus,
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_IsAligned							=> RX_IsAligned,
					
					TX_OOBCommand							=> TX_OOBCommand,
					TX_OOBComplete						=> TX_OOBComplete,
					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
					);
		END GENERATE;	-- Xilinx.Virtex5.LXT
		genV6LXT : IF (DEVICE_GROUP = DEVGRP_V6LXT) GENERATE
			V6GTXE1 : SATATransceiver_Virtex6_GTXE1
				GENERIC MAP (
					DEBUG											=> DEBUG					,
					CLOCK_IN_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					SATA_Clock								=> SATA_Clock,

					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					RP_Reconfig								=> RP_Reconfig,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					SATA_Generation						=> SATA_Generation,
					OOB_HandshakingComplete		=> OOB_HandshakingComplete,
					
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,

--					DebugPortOut							=> DebugPortOut,

					RX_OOBStatus							=> RX_OOBStatus,
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_IsAligned							=> RX_IsAligned,
					
					TX_OOBCommand							=> TX_OOBCommand,
					TX_OOBComplete						=> TX_OOBComplete,
					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		END GENERATE;	-- Xilinx.Virtex6.LXT
		genS7GTX : IF (DEVICE_SERIES = 7) GENERATE
			-- TODO: check für GTP, GTX, GTH
			S7GTX : sata_Transceiver_Series7_GTXE2
				GENERIC MAP (
					DEBUG											=> DEBUG					,
					CLOCK_IN_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					SATA_Clock								=> SATA_Clock,

					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					RP_Reconfig								=> RP_Reconfig,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					SATA_Generation						=> SATA_Generation,
					OOB_HandshakingComplete		=> OOB_HandshakingComplete,
					
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,

--					DebugPortOut							=> DebugPortOut,

					RX_OOBStatus							=> RX_OOBStatus,
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_IsAligned							=> RX_IsAligned,
					
					TX_OOBCommand							=> TX_OOBCommand,
					TX_OOBComplete						=> TX_OOBComplete,
					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
					);
		END GENERATE;	-- Xilinx.Series7.GTXE2
	END GENERATE;		-- Xilinx.*
	genAltera : IF (VENDOR = VENDOR_ALTERA) GENERATE
		genS2GX : IF (DEVICE_GROUP = DEVGRP_S2GX) GENERATE
			S2GX_GXB : SATATransceiver_S2GX_GXB
				GENERIC MAP (
					CLOCK_IN_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					SATA_Clock								=> SATA_Clock,

					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					RP_Reconfig								=> RP_Reconfig,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					SATA_Generation						=> SATA_Generation,
					OOB_HandshakingComplete		=> OOB_HandshakingComplete,
					
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,

					DebugPortOut							=> DebugPortOut,

					RX_OOBStatus							=> RX_OOBStatus,
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_IsAligned							=> RX_IsAligned,
					
					TX_OOBCommand							=> TX_OOBCommand,
					TX_OOBComplete						=> TX_OOBComplete,
					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		END GENERATE;	-- Altera.Stratix2.GX
		genS4GX : IF (DEVICE_GROUP = DEVGRP_S4GX) GENERATE
			S4GX_GXB : SATATransceiver_S4GX_GXB
				GENERIC MAP (
					CLOCK_IN_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,
					PORTS											=> PORTS,													-- Number of Ports per Transceiver
					INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS				-- intial SATA Generation
				)
				PORT MAP (
					SATA_Clock								=> SATA_Clock,

					ResetDone									=> ResetDone,
					ClockNetwork_Reset				=> ClockNetwork_Reset,
					ClockNetwork_ResetDone		=> ClockNetwork_ResetDone,

					RP_Reconfig								=> RP_Reconfig,
					RP_ReconfigComplete				=> RP_ReconfigComplete,
					RP_ConfigReloaded					=> RP_ConfigReloaded,
					RP_Lock										=> RP_Lock,
					RP_Locked									=> RP_Locked,

					SATA_Generation						=> SATA_Generation,
					OOB_HandshakingComplete		=> OOB_HandshakingComplete,
					
					Command										=> Command,
					Status										=> Status,
					RX_Error									=> RX_Error,
					TX_Error									=> TX_Error,

					DebugPortOut							=> DebugPortOut,

					RX_OOBStatus							=> RX_OOBStatus,
					RX_Data										=> RX_Data,
					RX_CharIsK								=> RX_CharIsK,
					RX_IsAligned							=> RX_IsAligned,
					
					TX_OOBCommand							=> TX_OOBCommand,
					TX_OOBComplete						=> TX_OOBComplete,
					TX_Data										=> TX_Data,
					TX_CharIsK								=> TX_CharIsK,
					
					-- vendor specific signals
					VSS_Common_In							=> VSS_Common_In,
					VSS_Private_In						=> VSS_Private_In,
					VSS_Private_Out						=> VSS_Private_Out
				);
		END GENERATE;	-- Altera.Stratix4.GX
	END GENERATE;		-- Altera.*
END;
