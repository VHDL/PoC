LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;
USE			L_SATAController.SATADebug.ALL;
USE			L_SATAController.SATATransceiverTypes.ALL;


PACKAGE SATAPackage IS
	COMPONENT SATAController IS
		GENERIC (
			CHIPSCOPE_KEEP							: BOOLEAN														:= TRUE;
			CLOCK_IN_FREQ_MHZ						: REAL															:= 150.0;
			PORTS												: POSITIVE													:= 1;												-- Port 0									Port 1
			CONTROLLER_TYPES						: T_SATA_DEVICE_TYPE_VECTOR					:= T_SATA_DEVICE_TYPE_VECTOR'(0 => SATA_DEVICE_TYPE_HOST,	1 => SATA_DEVICE_TYPE_DEVICE);
			INITIAL_SATA_GENERATIONS		: T_SATA_GENERATION_VECTOR					:= T_SATA_GENERATION_VECTOR'(	0 => SATA_GENERATION_1,			1 => SATA_GENERATION_1);
			ALLOW_SPEED_NEGOTIATION			: T_BOOLVEC													:= T_BOOLVEC'(								0 => TRUE,							1 => TRUE);
			ALLOW_STANDARD_VIOLATION		: T_BOOLVEC													:= T_BOOLVEC'(								0 => TRUE,							1 => TRUE);
			ALLOW_AUTO_RECONNECT				: T_BOOLVEC													:= T_BOOLVEC'(								0 => TRUE,							1 => TRUE);
			OOB_TIMEOUT_US							: T_INTVEC													:= T_INTVEC'(									0 => 0,									1 => 0);
			GENERATION_CHANGE_COUNT			: T_INTVEC													:= T_INTVEC'(									0 => 8,									1 => 8);
			TRYS_PER_GENERATION					: T_INTVEC													:= T_INTVEC'(									0 => 5,									1 => 3);
			AHEAD_CYCLES_FOR_INSERT_EOF	: T_INTVEC													:= T_INTVEC'(									0 => 1,									1 => 1);
			MAX_FRAME_SIZE_B						: T_INTVEC													:= T_INTVEC'(									0 => 4 * (2048 + 1),		1 => 4 * (2048 + 1))
		);
		PORT (
			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock: initialisation done
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async: reset all / hard reset
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async: all clocks are stable
			
			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			SATA_Reset								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock: clock is stable
			
			DebugPortOut							: OUT T_DBG_SATAOUT_VECTOR(PORTS - 1 DOWNTO 0);
			
			Command										: IN	T_SATA_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT T_SATA_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			Error											: OUT	T_SATA_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
			SATAGeneration            : OUT T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- TX port
			TX_SOF										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_EOF										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Valid									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_Ready									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_InsertEOF							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_FS_Ready								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_FS_Valid								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_FS_SendOK							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_FS_Abort								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- RX port
			RX_SOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_EOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Valid									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_Ready									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			RX_FS_Ready									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_FS_Valid								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_FS_CRC_OK							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_FS_Abort								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT LinkLayer IS
		GENERIC (
			CHIPSCOPE_KEEP							: BOOLEAN																:= TRUE;
			CONTROLLER_TYPE							: T_SATA_DEVICE_TYPE										:= SATA_DEVICE_TYPE_HOST;
			MAX_FRAME_SIZE_B						: POSITIVE															:= 2048;
			AHEAD_CYCLES_FOR_INSERT_EOF	: NATURAL																:= 1;
			RETRYBUFFER									: BOOLEAN																:= TRUE
		);
		PORT (
			Clock										: IN	STD_LOGIC;
			Reset										: IN	STD_LOGIC;
			
			Command									: IN	T_SATA_LINK_COMMAND;
			Status									: OUT	T_SATA_LINK_STATUS;
			Error										: OUT	T_SATA_LINK_ERROR;
			
			-- TX port
			TX_SOF									: IN	STD_LOGIC;
			TX_EOF									: IN	STD_LOGIC;
			TX_Valid								: IN	STD_LOGIC;
			TX_Data									: IN	T_SLV_32;
			TX_Ready								: OUT	STD_LOGIC;
			TX_InsertEOF						: OUT	STD_LOGIC;
			
			TX_FS_Ready							: IN	STD_LOGIC;
			TX_FS_Valid							:	OUT	STD_LOGIC;
			TX_FS_SendOK						: OUT	STD_LOGIC;
			TX_FS_Abort							: OUT	STD_LOGIC;
			
			-- RX port
			RX_SOF									: OUT	STD_LOGIC;
			RX_EOF									: OUT	STD_LOGIC;
			RX_Valid								: OUT	STD_LOGIC;
			RX_Data									: OUT	T_SLV_32;
			RX_Ready								: IN	STD_LOGIC;
			
			RX_FS_Ready							: IN	STD_LOGIC;
			RX_FS_Valid							:	OUT	STD_LOGIC;
			RX_FS_CRC_OK						: OUT	STD_LOGIC;
			RX_FS_Abort							: OUT	STD_LOGIC;

			-- physical layer interface
			Phy_Status							: IN	T_SATA_PHY_STATUS;
			
			Phy_RX_Data							: IN	T_SLV_32;
			Phy_RX_CharIsK					: IN	T_SATA_CIK;
			
			Phy_TX_Data							: OUT	T_SLV_32;
			Phy_TX_CharIsK					: OUT	T_SATA_CIK
		);
	END COMPONENT;

	COMPONENT PhysicalLayer IS
		GENERIC (
			CHIPSCOPE_KEEP									: BOOLEAN													:= TRUE;
			CONTROLLER_TYPE									: T_SATA_DEVICE_TYPE							:= SATA_DEVICE_TYPE_HOST;
			ALLOW_STANDARD_VIOLATION				: BOOLEAN													:= FALSE;
			OOB_TIMEOUT_US									: INTEGER													:= 0;
			GENERATION_CHANGE_COUNT					: INTEGER													:= 8;
			ATTEMPTS_PER_GENERATION					: INTEGER													:= 4
		);
		PORT (
			ClockNetwork_Reset							: IN	STD_LOGIC;

			Clock														: IN	STD_LOGIC;
			ClockEnable											: IN	STD_LOGIC;
			Reset														: IN	STD_LOGIC;

			DebugPortOut										: OUT	T_DBG_PHYOUT;

			Command													: IN	T_SATA_PHY_COMMAND;
			Status													: OUT	T_SATA_PHY_STATUS;
			Error														: OUT	T_SATA_PHY_ERROR;

			Link_RX_Data										: OUT	T_SLV_32;
			Link_RX_CharIsK									: OUT	T_SATA_CIK;
			
			Link_TX_Data										: IN	T_SLV_32;
			Link_TX_CharIsK									: IN	T_SATA_CIK;

			-- reconfiguration interface
			Trans_Reconfig									: OUT	STD_LOGIC;
	--		Trans_ReconfigComplete					: IN	STD_LOGIC;
			Trans_ConfigReloaded						: IN	STD_LOGIC;
			Trans_Lock											: OUT	STD_LOGIC;
			Trans_Locked										: IN	STD_LOGIC;
			SATA_Generation									: OUT	T_SATA_GENERATION;
			
			Trans_ResetDone									: IN	STD_LOGIC;
			Trans_OOB_HandshakingComplete		: OUT	STD_LOGIC;
			Trans_Status										: IN	T_SATA_TRANSCEIVER_STATUS;
			Trans_TX_Error									: IN	T_SATA_TRANSCEIVER_TX_ERROR;
			Trans_RX_Error									: IN	T_SATA_TRANSCEIVER_RX_ERROR;

			Trans_RX_OOBStatus							: IN	T_SATA_OOB;
			Trans_RX_Data										: IN	T_SLV_32;
			Trans_RX_CharIsK								: IN	T_SATA_CIK;
			Trans_RX_IsAligned							: IN	STD_LOGIC;

			Trans_TX_OOBCommand							: OUT	T_SATA_OOB;
			Trans_TX_OOBComplete						: IN	STD_LOGIC;
			Trans_TX_Data										: OUT	T_SLV_32;
			Trans_TX_CharIsK								: OUT T_SATA_CIK
		);
	END COMPONENT;

	COMPONENT SATATransceiver IS
		GENERIC (
			CHIPSCOPE_KEEP						: BOOLEAN											:= TRUE;
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																									-- 150 MHz
			PORTS											: POSITIVE										:= 2;																											-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
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

--			DebugPortIn								: IN	T_DBG_TRANSIN_VECTOR(PORTS	- 1 DOWNTO 0);
--			DebugPortOut							: OUT T_DBG_TRANSOUT_VECTOR(PORTS	- 1 DOWNTO 0);

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
	END COMPONENT;

	COMPONENT SATATransceiver_Virtex5_GTP IS
		GENERIC (
			CHIPSCOPE_KEEP						: BOOLEAN											:= TRUE;																																-- generate ChipScope debugging "pins"
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
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

--			DebugPortOut							: OUT T_DBG_TRANSOUT_VECTOR(PORTS	- 1 DOWNTO 0);

			RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
			RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals (Xilinx)
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT SATATransceiver_Virtex6_GTXE1 IS
		GENERIC (
			CHIPSCOPE_KEEP						: BOOLEAN											:= TRUE;
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																									-- 150 MHz
			PORTS											: POSITIVE										:= 2;																											-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		PORT (
			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

			SATA_Generation						: IN	T_SATA_GENERATION_VECTOR(PORTS	- 1 DOWNTO 0);
			OOB_HandshakingComplete		: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS	- 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS	- 1 DOWNTO 0);
			RX_Error									: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);
			TX_Error									: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);

--			DebugPortOut							: OUT T_DBG_TRANSOUT_VECTOR(PORTS	- 1 DOWNTO 0);

			RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS	- 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
			RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			
			TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
			TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS	- 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
			
			-- vendor specific signals (Xilinx)
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;
	
	COMPONENT SATATransceiver_S2GX_GXB IS
		GENERIC (
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
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

			RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
			RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);

			DebugPortOut	: OUT T_DBG_TRANSOUT_VECTOR(PORTS-1 DOWNTO 0);
			
			-- vendor specific signals (Altera GXB ports)
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;
	COMPONENT SATATransceiver_S4GX_GXB IS
		GENERIC (
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
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

			RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
			RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);

			DebugPortOut	: OUT T_DBG_TRANSOUT_VECTOR(PORTS-1 DOWNTO 0);
			
			-- vendor specific signals (Altera GXB ports)
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;
END SATAPackage;


PACKAGE BODY SATAPackage IS
		
END PACKAGE BODY;
