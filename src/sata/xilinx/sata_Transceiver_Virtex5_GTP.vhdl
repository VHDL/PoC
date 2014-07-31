LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.strings.ALL;
USE			PoC.sata.ALL;
USE			PoC.sata_TransceiverTypes.ALL;
USE			PoC.xil.ALL;


ENTITY sata_Transceiver_Virtex5_GTP IS
	GENERIC (
		DEBUG											: BOOLEAN											:= FALSE;																	-- generate ChipScope debugging "pins"
		CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																	-- 150 MHz
		PORTS											: POSITIVE										:= 2;																			-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 1 => T_SATA_GENERATION'high)			-- intial SATA Generation
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

--		DebugPortOut							: OUT T_DBG_TRANSOUT_VECTOR(PORTS	- 1 DOWNTO 0);

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
		VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS - 1 DOWNTO 0);
		VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF sata_Transceiver_Virtex5_GTP IS
	ATTRIBUTE KEEP 														: BOOLEAN;
	ATTRIBUTE TNM 														: STRING;

-- ==================================================================
-- SATATransceiver configuration
-- ==================================================================
	CONSTANT NO_DEVICE_TIMEOUT_MS							: REAL						:= ite(SIMULATION, 0.020, 50.0);				-- simulation: 20 us, synthesis: 50 ms
	CONSTANT NEW_DEVICE_TIMEOUT_MS						: REAL						:= 0.001;				-- FIXME: not used -> remove ???

	CONSTANT C_DEVICE_INFO										: T_DEVICE_INFO		:= DEVICE_INFO;

-- ==================================================================
-- calculate generic values for GTP transceiver
-- ==================================================================
	FUNCTION SATAGeneration2ClockDivider(SGEN : T_SATA_GENERATION_VECTOR) RETURN T_INTVEC IS
		VARIABLE ClkDiv : T_INTVEC(SGEN'range)	:= (OTHERS => 0);
	BEGIN
		FOR I IN 0 TO SGEN'length - 1 LOOP											-- GTP_DUAL PLL output = 1,5 GHz
			CASE SGEN(I) IS
				WHEN SATA_GENERATION_1 =>			ClkDiv(I) := 2;				-- Generation 1: 1,5 GHz line clock => 750 MHz TX/RX clock (DDR sampler)	=> devider = 2
				WHEN SATA_GENERATION_2 =>			ClkDiv(I) := 1;				-- Generation 2: 3,0 GHz line clock => 1,5 GHz TX/RX clock (DDR sampler)	=> devider = 1
				WHEN OTHERS =>								ClkDiv(I) := 1;
			END CASE;
		END LOOP;
		
		RETURN ClkDiv;
	END;

	CONSTANT CLOCK_DIVIDERS										: T_INTVEC(INITIAL_SATA_GENERATIONS'range)		:= SATAGeneration2ClockDivider(INITIAL_SATA_GENERATIONS);

	SIGNAL ClockIn_150MHz											: STD_LOGIC;
	SIGNAL ResetDone_i												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL GTP_Reset													: STD_LOGIC;
	SIGNAL GTP_ResetDone											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_ResetDone_i										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_PLL_Reset											: STD_LOGIC;
	SIGNAL GTP_PLL_ResetDone									:	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_PLL_ResetDone_i								:	STD_LOGIC;

	SIGNAL GTP_RefClockIn											: STD_LOGIC;
	SIGNAL GTP_RefClockOut										: STD_LOGIC;
	SIGNAL GTP_RefClockOut_i									: STD_LOGIC;
	SIGNAL GTP_TX_RefClockOut									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_RefClockOut									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Control_Clock											: STD_LOGIC;
	SIGNAL GTP_DRP_Clock											: STD_LOGIC;
	SIGNAL GTP_Clock_1X												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_Clock_4X												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL SATA_Clock_i												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL ClkNet_Reset												: STD_LOGIC;
	SIGNAL ClkNet_Reset_i											: STD_LOGIC;
	SIGNAL ClkNet_Reset_x											: STD_LOGIC;
	SIGNAL ClkNet_ResetDone										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL ClkNet_ResetDone_i									: STD_LOGIC;
	SIGNAL ClockNetwork_ResetDone_i						: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL GTP_PortReset											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_Reset												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_CDR_Reset										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);		-- Clock Data Recovery
	SIGNAL GTP_RX_BufferReset									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_Reset												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL GTP_PLL_PowerDown									: STD_LOGIC;
	SIGNAL GTP_TX_PowerDown										: T_SLVV_2(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_PowerDown										: T_SLVV_2(PORTS - 1 DOWNTO 0);

	SIGNAL GTPConfig_Reset										: STD_LOGIC;
	SIGNAL GTPConfig_Reset_i									: STD_LOGIC;
	SIGNAL GTP_ReloadConfig										: STD_LOGIC;
	SIGNAL GTP_ReloadConfigDone								: STD_LOGIC;
	SIGNAL GTP_ReloadConfigDone_i							: STD_LOGIC;

	SIGNAL GTP_DRP_en													: STD_LOGIC;
	SIGNAL GTP_DRP_Address										: T_XIL_DRP_ADDRESS;
	SIGNAL GTP_DRP_we													: STD_LOGIC;
	SIGNAL GTP_DRP_DataIn											: T_XIL_DRP_DATA;
	SIGNAL GTP_DRP_DataOut										: T_XIL_DRP_DATA;
	SIGNAL GTP_DRP_rdy												: STD_LOGIC;

	SIGNAL GTP_TX_ElectricalIDLE							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)													:= (OTHERS => '0');
	SIGNAL GTP_TX_ComStart										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_ComType											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)													:= (OTHERS => '0');
	SIGNAL GTP_TX_ComComplete									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_InvalidK										: T_SLVV_2(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_BufferStatus								: T_SLVV_2(PORTS - 1 DOWNTO 0);

	SIGNAL GTP_RX_ElectricalIDLE_Reset				: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_EnableElectricalIDLEReset		: STD_LOGIC;
	SIGNAL GTP_RX_ElectricalIDLE							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL GTP_RX_Status											: T_SLVV_3(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_DisparityError							: T_SLVV_2(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_Illegal8B10BCode						: T_SLVV_2(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_LossOfSync									: T_SLVV_2(PORTS - 1 DOWNTO 0);																	-- unused
	SIGNAL GTP_RX_ClockCorrectionStatus				: T_SLVV_3(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_BufferStatus								: T_SLVV_3(PORTS - 1 DOWNTO 0);
	
	SIGNAL GTP_RX_Data												: T_SLVV_16(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_Data_d											: T_SLVV_8(PORTS - 1 DOWNTO 0)																		:= (OTHERS => (OTHERS => '0'));
	SIGNAL GTP_RX_CommaDetected								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);													-- unused
	SIGNAL GTP_RX_CharIsComma									: T_SATA_CIK2_VECTOR(PORTS - 1 DOWNTO 0);												-- unused
	SIGNAL GTP_RX_CharIsK											: T_SATA_CIK2_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_CharIsK_d										: T_SATA_CIK2_VECTOR(PORTS - 1 DOWNTO 0)												:= (OTHERS => (OTHERS => '0'));
	SIGNAL GTP_RX_ByteIsAligned								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_ByteRealign									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);													-- unused
	SIGNAL GTP_RX_Valid												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);													-- unused
		
	SIGNAL GTP_TX_Data												: T_SLVV_16(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_CharIsK											: T_SATA_CIK2_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL BWC_RX_Align												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL TX_OOBCommand_d										: T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0)													:= (OTHERS => SATA_OOB_NONE);
	SIGNAL TX_OOBComplete_i										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL TX_InvalidK												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL TX_BufferStatus										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL RX_ElectricalIDLE									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL RX_DisparityError									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL RX_Illegal8B10BCode								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL RX_BufferStatus										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL DD_NoDevice												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL RX_Error_i													: T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL TX_Error_i													: T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL RX_OOBStatus_i											: T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL RX_OOBStatus_d											: T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0)													:= (OTHERS => SATA_OOB_NONE);

	ATTRIBUTE KEEP OF TX_OOBComplete									: SIGNAL IS DEBUG;
	ATTRIBUTE KEEP OF BWC_RX_Align										: SIGNAL IS DEBUG;
	ATTRIBUTE KEEP OF GTP_RX_ClockCorrectionStatus		: SIGNAL IS DEBUG;
	ATTRIBUTE KEEP OF GTP_RX_BufferStatus							: SIGNAL IS DEBUG;
	
	-- keep internal clock nets, so timing constrains from UCF can find them
	ATTRIBUTE KEEP OF GTP_RefClockOut 								: SIGNAL IS DEBUG;
	ATTRIBUTE KEEP OF GTP_Clock_1X										: SIGNAL IS DEBUG;
--	ATTRIBUTE KEEP OF GTP_Clock_4X										: SIGNAL IS DEBUG;
	ATTRIBUTE KEEP OF SATA_Clock_i										: SIGNAL IS TRUE;
	ATTRIBUTE TNM OF SATA_Clock_i											: SIGNAL IS "TGRP_SATA_Clock0";
	ATTRIBUTE KEEP OF GTP_TX_RefClockOut							: SIGNAL IS DEBUG;
	ATTRIBUTE KEEP OF GTP_RX_RefClockOut							: SIGNAL IS DEBUG;
	
BEGIN
	genReport : FOR I IN 0 TO PORTS - 1 GENERATE
		ASSERT FALSE REPORT "Port:    " & INTEGER'image(I)																								SEVERITY NOTE;
		ASSERT FALSE REPORT "  Init. SATA Generation:  Gen" & INTEGER'image(INITIAL_SATA_GENERATIONS(I))	SEVERITY NOTE;
		ASSERT FALSE REPORT "  ClockDivider:           " & INTEGER'image(I)																SEVERITY NOTE;
	END GENERATE;

-- ==================================================================
-- Assert statements
-- ==================================================================
	ASSERT (C_DEVICE_INFO.VENDOR = VENDOR_XILINX)						REPORT "Vendor not yet supported."				SEVERITY FAILURE;
	ASSERT (C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_VIRTEX)	REPORT "Device family not yet supported."	SEVERITY FAILURE;
	ASSERT (C_DEVICE_INFO.DEVICE = DEVICE_VIRTEX5)					REPORT "Device not yet supported."				SEVERITY FAILURE;
	ASSERT (PORTS <= 2)																			REPORT "To many ports per transceiver."		SEVERITY FAILURE;
		
	genAssert : FOR I IN 0 TO PORTS - 1 GENERATE
		ASSERT (CLOCK_DIVIDERS(I) > 0)												REPORT "illegal clock devider - unsupported initial SATA generation?" SEVERITY FAILURE;
		ASSERT ((SATA_Generation(I) = SATA_GENERATION_1) OR
						(SATA_Generation(I) = SATA_GENERATION_2))			REPORT "unsupported SATA generation"			SEVERITY FAILURE;
	END GENERATE;

-- ============================================================================
-- mapping of vendor specific ports
-- ============================================================================
	ClockIn_150MHz										<= VSS_Common_In.RefClockIn_150_MHz;
	
-- ==================================================================
-- ResetControl
-- ==================================================================
	ClkNet_Reset_i										<= slv_or(ClockNetwork_Reset);
	
	blkSync1 : BLOCK
		SIGNAL ClkNet_Reset_shift				: STD_LOGIC_VECTOR(15 DOWNTO 0)				:= (OTHERS => '0');
	BEGIN
		PROCESS(Control_Clock)
		BEGIN
			IF rising_edge(Control_Clock) THEN
				ClkNet_Reset_shift		<= ClkNet_Reset_shift(ClkNet_Reset_shift'high - 1 DOWNTO 0) & ClkNet_Reset_i;
			END IF;
		END PROCESS;

		ClkNet_Reset		<= ClkNet_Reset_shift(2);
		ClkNet_Reset_x	<= ClkNet_Reset_shift(ClkNet_Reset_shift'high);
	END BLOCK;

	GTP_PLL_Reset											<= ClkNet_Reset;
	GTPConfig_Reset										<= ClkNet_Reset;
	-- PLL reset must be mapped to global GTP reset
	-- reload configuration must be mapped to global GTP reset
	GTP_Reset													<= GTP_PLL_Reset OR GTP_ReloadConfig;

	genSync0 : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL GTP_Reset_meta							: STD_LOGIC				:= '0';
		SIGNAL GTP_Reset_d							: STD_LOGIC				:= '0';
		
		-- ------------------------------------------
		SIGNAL ClkNet_ResetDone_meta			: STD_LOGIC				:= '0';
		SIGNAL ClkNet_ResetDone_d			: STD_LOGIC				:= '0';
		
		SIGNAL GTP_PLL_ResetDone_meta			: STD_LOGIC				:= '0';
		SIGNAL GTP_PLL_ResetDone_d			: STD_LOGIC				:= '0';
		
		SIGNAL GTP_ResetDone_meta					: STD_LOGIC				:= '0';
		SIGNAL GTP_ResetDone_d					: STD_LOGIC				:= '0';
		
	BEGIN
		GTP_Reset_meta										<= GTP_Reset				WHEN rising_edge(SATA_Clock_i(I));
		GTP_Reset_d										<= GTP_Reset_meta			WHEN rising_edge(SATA_Clock_i(I));
		
		GTP_PortReset(I)								<= to_sl(Command(I) = SATA_TRANSCEIVER_CMD_RESET);
		GTP_TX_PowerDown(I)							<= ite((Command(I)	= SATA_TRANSCEIVER_CMD_POWERDOWN), "11", "00");			-- PowerDown => PowerDownState = P2
		GTP_RX_PowerDown(I)							<= ite((Command(I)	= SATA_TRANSCEIVER_CMD_POWERDOWN), "11", "00");
		
		GTP_TX_Reset(I)									<= GTP_Reset_d	OR GTP_PortReset(I);
		GTP_RX_Reset(I)									<= GTP_Reset_d	OR GTP_PortReset(I) OR	OOB_HandshakingComplete(I);
		GTP_RX_ElectricalIDLE_Reset(I)	<= GTP_RX_ElectricalIDLE(I)				AND GTP_ResetDone(I);				-- generate reset for CDR-unit (Clock-Data-Recovery) after OOB SIGNALing

		-- ------------------------------------------
--		ClkNet_ResetDone_meta						<= ClkNet_ResetDone_i			WHEN rising_edge(SATA_Clock_i(I));
--		ClkNet_ResetDone_d							<= ClkNet_ResetDone_meta	WHEN rising_edge(SATA_Clock_i(I));
		ClkNet_ResetDone(I)							<= ClkNet_ResetDone_i;
		
		GTP_PLL_ResetDone_meta					<= GTP_PLL_ResetDone_i		WHEN rising_edge(SATA_Clock_i(I));
		GTP_PLL_ResetDone_d							<= GTP_PLL_ResetDone_meta	WHEN rising_edge(SATA_Clock_i(I));
		GTP_PLL_ResetDone(I)						<= GTP_PLL_ResetDone_d;
		
		GTP_ResetDone_meta							<= GTP_ResetDone_i(I)			WHEN rising_edge(SATA_Clock_i(I));
		GTP_ResetDone_d									<= GTP_ResetDone_meta			WHEN rising_edge(SATA_Clock_i(I));
		GTP_ResetDone(I)								<= GTP_ResetDone_d;
	END GENERATE;
	
	ClockNetwork_ResetDone						<= ClkNet_ResetDone;
	
	ClockNetwork_ResetDone_i					<= GTP_PLL_ResetDone				AND ClkNet_ResetDone;
	ResetDone													<= ClockNetwork_ResetDone_i AND GTP_ResetDone;
	
	-- reload completion is recongnized by asserting GTP_ResetDone
	GTP_ReloadConfigDone_i						<= slv_and(GTP_ResetDone_i);
	
	blkSync2 : BLOCK
		SIGNAL GTP_ReloadConfigDone_meta	: STD_LOGIC				:= '0';
		SIGNAL GTP_ReloadConfigDone_d			: STD_LOGIC				:= '0';
	BEGIN
		GTP_ReloadConfigDone_meta					<= GTP_ReloadConfigDone_i			WHEN rising_edge(Control_Clock);
		GTP_ReloadConfigDone_d						<= GTP_ReloadConfigDone_meta	WHEN rising_edge(Control_Clock);
		GTP_ReloadConfigDone							<= GTP_ReloadConfigDone_d;
	END BLOCK;

	
  GTP_RX_CDR_Reset                  <= (OTHERS => '0');
  GTP_RX_BufferReset                <= (OTHERS => '0');
	GTP_PLL_PowerDown									<= '0';
	
	GTP_RX_EnableElectricalIDLEReset	<= slv_or(GTP_RX_ElectricalIDLE_Reset);

-- ==================================================================
-- ClockNetwork (37.5, 75, 150, 300 MHz)
-- ==================================================================
	GTP_RefClockIn		<= ClockIn_150MHz;
	
	BUFG_GTP_RefClockOut : BUFG
		PORT MAP (
			I		=> GTP_RefClockOut_i,
			O		=> GTP_RefClockOut
		);
	
	Control_Clock										<= GTP_RefClockOut;							-- use stable clock after GTP_DUAL / before DCM for reset control and so on
	GTP_DRP_Clock										<= GTP_RefClockOut;							-- use stable clock after GTP_DUAL / before DCM for Dynamic-Reconfiguration-Port
	
	SATA_Clock_i										<= GTP_Clock_4X;							-- SATAClock is a 4 Byte (Word) clock
	SATA_Clock											<= SATA_Clock_i;
	
	ClkNet : ENTITY PoC.sata_Transceiver_Virtex5_GTP_ClockNetwork
		GENERIC MAP (
			DEBUG							=> DEBUG,
			CLOCK_IN_FREQ_MHZ						=> CLOCK_IN_FREQ_MHZ,
			PORTS												=> PORTS,
			INITIAL_SATA_GENERATIONS		=> INITIAL_SATA_GENERATIONS
		)
		PORT MAP (
			ClockIn_150MHz							=> GTP_RefClockOut,							-- use stable clock after GTP_DUAL - not from CDR-Unit !! => enable elastic buffers

			ClockNetwork_Reset					=> ClkNet_Reset_x,
			ClockNetwork_ResetDone			=> ClkNet_ResetDone_i,
			
			SATA_Generation							=> SATA_Generation,
			
			GTP_Clock_1X								=> GTP_Clock_1X,
			GTP_Clock_4X								=> GTP_Clock_4X
		);


-- ==================================================================
-- async SIGNAL handling
-- ==================================================================
	genSync : FOR I IN 0 TO (PORTS - 1) GENERATE
		blkSync : BLOCK
			SIGNAL RX_ElectricalIDLE_meta		: STD_LOGIC							:= '0';
			SIGNAL RX_ElectricalIDLE_d			: STD_LOGIC							:= '0';
		BEGIN
			RX_ElectricalIDLE_meta		<= GTP_RX_ElectricalIDLE(I)		WHEN rising_edge(GTP_Clock_4X(I));
			RX_ElectricalIDLE_d				<= RX_ElectricalIDLE_meta			WHEN rising_edge(GTP_Clock_4X(I));
			RX_ElectricalIDLE(I)			<= RX_ElectricalIDLE_d;
		END BLOCK;
	END GENERATE;

-- ==================================================================
-- transceiver layer FSM
-- ==================================================================
--	FSM : ENTITY L_SATAController.SATATransceiverFSM
--		GENERIC MAP (
--			DEBUG						=> DEBUG,
--			PORTS											=> PORTS
--		)
--		PORT MAP (
--			SATAClock									=> GTP_Clock_4X,
--			ControlClock							=> Control_Clock,
--
--			Command										=> Command,							-- @SATAClock: 
--			Status										=> Status,							-- @SATAClock: 
--			Error											=> Error,								-- @SATAClock: 
--
--			PortReset									=> GTP_PortReset,				-- @ControlClock: 
--			ResetDone									=> GTP_ResetDone,				-- @ControlClock: 
--
--			NoDevice									=> DD_NoDevice,					-- @ControlClock: 
--			NewDevice									=> DD_NewDevice,				-- @ControlClock: 
--			
--			TX_InvalidK								=> TX_InvalidK,					-- 
--			TX_BufferStatus						=> TX_BufferStatus,			-- 
--
--			RX_DisparityError					=> RX_DisparityError,		-- 
--			RX_Illegal8B10BCode				=> RX_Illegal8B10BCode,	-- 
--			RX_BufferStatus						=> RX_BufferStatus,			-- 
--
--			Reconfig									=> Reconfig,						-- @ControlClock: 
--			ReconfigDone							=> ReconfigDone,				-- @ControlClock: 
--			Reload										=> Reload,							-- @ControlClock: 
--			ReloadDone								=> ReloadDone						-- @ControlClock: 
--		);
	
-- ==================================================================
-- data path buffers
-- ==================================================================
	genDataPath : FOR I IN 0 TO PORTS - 1 GENERATE
	BEGIN
		-- TX path
		BWC_TX_Data : ENTITY PoC.misc_BitwidthConverter
			GENERIC MAP (
				REGISTERED					=> TRUE,
				BITS1								=> 32,
				BITS2								=> 8
			)
			PORT MAP (
				Clock1							=> GTP_Clock_4X(I),
				Clock2							=> GTP_Clock_1X(I),
				Align								=> '0',
				I										=> TX_Data(I),
				O										=> GTP_TX_Data(I)(7 DOWNTO 0)
			);
		
		BWC_TX_CharIsK : ENTITY PoC.misc_BitwidthConverter
			GENERIC MAP (
				REGISTERED					=> TRUE,
				BITS1								=> 4,
				BITS2								=> 1
			)
			PORT MAP (
				Clock1							=> GTP_Clock_4X(I),
				Clock2							=> GTP_Clock_1X(I),
				Align								=> '0',
				I										=> TX_CharIsK(I),
				O										=> GTP_TX_CharIsK(I)(0 DOWNTO 0)
			);
	
		-- RX path
		-- ==============================================================
		-- insert register stage, so timing constrains can be solved
		GTP_RX_CharIsK_d(I)	<= GTP_RX_CharIsK(I)					WHEN rising_edge(GTP_Clock_1X(I));
		GTP_RX_Data_d(I)		<= GTP_RX_Data(I)(7 DOWNTO 0) WHEN rising_edge(GTP_Clock_1X(I));

		-- use K-characters for word alignment
		BWC_RX_Align(I) 		<= GTP_RX_CharIsK_d(I)(0);
	
		BWC_RX_Data : ENTITY PoC.misc_BitwidthConverter
			GENERIC MAP (
				REGISTERED					=> TRUE,
				BITS1								=> 8,
				BITS2								=> 32
			)
			PORT MAP (
				Clock1							=> GTP_Clock_1X(I),
				Clock2							=> GTP_Clock_4X(I),
				Align								=> BWC_RX_Align(I),
				I										=> GTP_RX_Data_d(I),
				O										=> RX_Data(I)
			);
			
		BWC_RX_CharIsK : ENTITY PoC.misc_BitwidthConverter
			GENERIC MAP (
				REGISTERED					=> TRUE,
				BITS1								=> 1,
				BITS2								=> 4
			)
			PORT MAP (
				Clock1							=> GTP_Clock_1X(I),
				Clock2							=> GTP_Clock_4X(I),
				Align								=> BWC_RX_Align(I),
				I										=> GTP_RX_CharIsK_d(I)(0 DOWNTO 0),
				O										=> RX_CharIsK(I)
			);

		RX_IsAligned(I)					<= GTP_RX_ByteIsAligned(I);
	END GENERATE;

-- ==================================================================
-- OOB signaling
-- ==================================================================
	genOOBControl : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL ForceElectricalIDLE		: STD_LOGIC;
		SIGNAL ForceElectricalIDLE_d	: STD_LOGIC													:= '0';
		SIGNAL ForceElectricalIDLE_re	: STD_LOGIC;
		SIGNAL ForceElectricalIDLE_fe	: STD_LOGIC;
	BEGIN
		TX_OOBCommand_d(I)	<= TX_OOBCommand(I) WHEN rising_edge(GTP_Clock_4X(I));

		-- TX OOB signals (generate GTP specific OOB SIGNALs)
		PROCESS(TX_OOBCommand_d(I))
		BEGIN
			GTP_TX_ComStart(I)			<= '0';
			ForceElectricalIDLE			<= '0';
		
			IF (TX_OOBCommand_d(I) = SATA_OOB_READY) THEN
				ForceElectricalIDLE		<= '1';
			ELSIF (TX_OOBCommand_d(I) = SATA_OOB_COMRESET) THEN
				GTP_TX_ComStart(I) 		<= '1';
			ELSIF (TX_OOBCommand_d(I) = SATA_OOB_COMWAKE) THEN
				GTP_TX_ComStart(I) 		<= '1';
			END IF;
		END PROCESS;

		ForceElectricalIDLE_d		<= ForceElectricalIDLE 		WHEN rising_edge(GTP_Clock_4X(I));
		ForceElectricalIDLE_re	<= ForceElectricalIDLE		AND NOT ForceElectricalIDLE_d;
		ForceElectricalIDLE_fe	<= ForceElectricalIDLE_d	AND NOT ForceElectricalIDLE;

		-- SR-FF for ElectricalIDLE:
		--		.set	= ComStart
		--		.rst	= OOBComplete || Reset
		PROCESS(GTP_Clock_4X(I))
		BEGIN
			IF rising_edge(GTP_Clock_4X(I)) THEN
				IF (GTP_PortReset(I) = '1') THEN
					GTP_TX_ElectricalIDLE(I)	<= '0';
				ELSE
					IF ((GTP_TX_ComStart(I) = '1') OR (ForceElectricalIDLE_re = '1')) THEN
						GTP_TX_ElectricalIDLE(I)	<= '1';
					ELSIF ((TX_OOBComplete_i(I) = '1') OR (ForceElectricalIDLE_fe = '1')) THEN
						GTP_TX_ElectricalIDLE(I)	<= '0';
					END IF;
				END IF;
			END IF;
		END PROCESS;
		
		-- SR-FF for ComType:
		--		.en		= ComStart
		--		.set	= OOBCommand = COMRESET | COMINIT
		--		.rst	= OOBCommand = COMWAKE
		PROCESS(GTP_Clock_4X(I))
		BEGIN
			IF rising_edge(GTP_Clock_4X(I)) THEN
				IF (GTP_TX_ComStart(I) = '1') THEN
					CASE TX_OOBCommand_d(I) IS
						WHEN SATA_OOB_COMRESET =>		GTP_TX_ComType(I)				<= '0';
						WHEN SATA_OOB_COMWAKE =>		GTP_TX_ComType(I)				<= '1';
						WHEN OTHERS =>							GTP_TX_ComType(I)				<= '0';
					END CASE;
				END IF;
			END IF;
		END PROCESS;
		
		-- OOB sequence is complete
		GTP_TX_ComComplete(I) <= to_sl(GTP_RX_Status(I)(0) = '1');
		
		SyncComComplete : ENTITY PoC.misc_Synchronizer
			GENERIC MAP (
				BITS										=> 1,														-- number of bit to be synchronized
				GATED_INPUT_BY_BUSY			=> TRUE													-- use gated input (by busy SIGNAL)
			)
			PORT MAP (
				Clock1									=> GTP_Clock_1X(I),						-- input clock domain
				Clock2									=> GTP_Clock_4X(I),						-- output clock domain
				I(0)										=> GTP_TX_ComComplete(I),				-- input bits
				O(0)										=> TX_OOBComplete_i(I),					-- output bits
				B												=> OPEN													-- busy bits
			);
		
		TX_OOBComplete		<= TX_OOBComplete_i;
		
		-- RX OOB SIGNALs (generate generic RX OOB status SIGNALs)
		PROCESS(GTP_RX_Status(I)(2 DOWNTO 1), RX_ElectricalIDLE(I))
		BEGIN
			RX_OOBStatus_i(I) 				<= SATA_OOB_NONE;
		
			IF (RX_ElectricalIDLE(I) = '1') THEN
				RX_OOBStatus_i(I)				<= SATA_OOB_READY;
			
				CASE GTP_RX_Status(I)(2 DOWNTO 1) IS
					WHEN "10" =>					RX_OOBStatus_i(I)		<= SATA_OOB_COMRESET;
					WHEN "01" =>					RX_OOBStatus_i(I)		<= SATA_OOB_COMWAKE;
					WHEN OTHERS =>				NULL;
				END CASE;
			END IF;
		END PROCESS;

		-- convert to Word-Clock
		RX_OOBStatus_d(I) <= RX_OOBStatus_i(I) WHEN rising_edge(GTP_Clock_4X(I));
		RX_OOBStatus(I)		<= RX_OOBStatus_d(I);
	END GENERATE;

-- ==================================================================
-- error handling
-- ==================================================================
	genError : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL Sync4_DataIn						: STD_LOGIC_VECTOR(1 DOWNTO 0);
		SIGNAL Sync4_DataOut					: STD_LOGIC_VECTOR(1 DOWNTO 0);
		SIGNAL Sync5_DataIn						: STD_LOGIC_VECTOR(2 DOWNTO 0);
		SIGNAL Sync5_DataOut					: STD_LOGIC_VECTOR(2 DOWNTO 0);

	BEGIN
		Sync4_DataIn(0)							<= GTP_TX_InvalidK(I)(0);
		Sync4_DataIn(1)							<= GTP_TX_BufferStatus(I)(1);
		
		Sync4 : ENTITY PoC.misc_Synchronizer
			GENERIC MAP (
				BITS										=> Sync4_DataIn'length,					-- number of bit to be synchronized
				GATED_INPUT_BY_BUSY			=> TRUE													-- use gated input (by busy SIGNAL)
			)
			PORT MAP (
				Clock1									=> GTP_Clock_1X(I),						-- input clock domain
				Clock2									=> GTP_Clock_4X(I),						-- output clock domain
				I												=> Sync4_DataIn,								-- input bits
				O												=> Sync4_DataOut,								-- output bits
				B												=> OPEN													-- busy bits
			);
	
		TX_InvalidK(I)							<= Sync4_DataOut(0);
		TX_BufferStatus(I)					<= Sync4_DataOut(1);
	
		Sync5_DataIn(0)							<= GTP_RX_DisparityError(I)(0);
		Sync5_DataIn(1)							<= GTP_RX_Illegal8B10BCode(I)(0);
		Sync5_DataIn(2)							<= GTP_RX_BufferStatus(I)(2);
		
		Sync5 : ENTITY PoC.misc_Synchronizer
			GENERIC MAP (
				BITS										=> Sync5_DataIn'length,					-- number of bit to be synchronized
				GATED_INPUT_BY_BUSY			=> TRUE													-- use gated input (by busy SIGNAL)
			)
			PORT MAP (
				Clock1									=> GTP_Clock_1X(I),						-- input clock domain
				Clock2									=> GTP_Clock_4X(I),						-- output clock domain
				I												=> Sync5_DataIn,								-- input bits
				O												=> Sync5_DataOut,								-- output bits
				B												=> OPEN													-- busy bits
			);
	
		RX_DisparityError(I)				<= Sync5_DataOut(0);
		RX_Illegal8B10BCode(I)			<= Sync5_DataOut(1);
		RX_BufferStatus(I)					<= Sync5_DataOut(2);
	
		-- RX errors
		PROCESS(GTP_RX_ByteIsAligned(I), RX_DisparityError, RX_Illegal8B10BCode, RX_BufferStatus)
		BEGIN
			RX_Error_i(I)		<= SATA_TRANSCEIVER_RX_ERROR_NONE;
		
			IF (GTP_RX_ByteIsAligned(I) = '0') THEN
				RX_Error_i(I)	<= SATA_TRANSCEIVER_RX_ERROR_ALIGNEMENT;
			ELSIF (RX_DisparityError(I) = '1') THEN
				RX_Error_i(I)	<= SATA_TRANSCEIVER_RX_ERROR_DISPARITY;
			ELSIF (RX_Illegal8B10BCode(I) = '1') THEN
				RX_Error_i(I)	<= SATA_TRANSCEIVER_RX_ERROR_DECODER;
			ELSIF (RX_BufferStatus(I) = '1') THEN
				RX_Error_i(I)	<= SATA_TRANSCEIVER_RX_ERROR_BUFFER;
			END IF;
		END PROCESS;

		-- TX errors
		PROCESS(TX_InvalidK, TX_BufferStatus)
		BEGIN
			TX_Error_i(I)		<= SATA_TRANSCEIVER_TX_ERROR_NONE;
		
			IF (TX_InvalidK(I) = '1') THEN
				TX_Error_i(I)	<= SATA_TRANSCEIVER_TX_ERROR_ENCODER;
			ELSIF (TX_BufferStatus(I) = '1') THEN
				TX_Error_i(I)	<= SATA_TRANSCEIVER_TX_ERROR_BUFFER;
			END IF;
		END PROCESS;
	END GENERATE;

	TX_Error			<= TX_Error_i;
	RX_Error			<= RX_Error_i;

-- ==================================================================
-- Transceiver status / DeviceDetection
-- ==================================================================
	genDeviceDetector : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL DD_NoDevice_i					: STD_LOGIC;
		SIGNAL DD_NewDevice						: STD_LOGIC;
		SIGNAL DD_NewDevice_i					: STD_LOGIC;

	BEGIN

		-- device detection
		DD : ENTITY PoC.sata_DeviceDetector
			GENERIC MAP (
				DEBUG					=> DEBUG,
				CLOCK_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,						-- 150 MHz
				NO_DEVICE_TIMEOUT_MS		=> NO_DEVICE_TIMEOUT_MS,				-- 1,0 ms
				NEW_DEVICE_TIMEOUT_MS		=> NEW_DEVICE_TIMEOUT_MS				-- 1,0 us								-- TODO: unused?
			)
			PORT MAP (
				Clock										=> Control_Clock,
				ElectricalIDLE					=> GTP_RX_ElectricalIDLE(I),		-- async
				
				NoDevice								=> DD_NoDevice(I),							-- @DRP_Clock
				NewDevice								=> DD_NewDevice									-- @DRP_Clock
			);

		blkSync6 : BLOCK
			SIGNAL NoDevice_sy				: STD_LOGIC;
			SIGNAL NoDevice_sy1				: STD_LOGIC									:= '0';
			SIGNAL NoDevice_sy2				: STD_LOGIC									:= '0';
		BEGIN
			NoDevice_sy							<= DD_NoDevice(I);
			NoDevice_sy1						<= NoDevice_sy			WHEN rising_edge(GTP_Clock_4X(I));
			NoDevice_sy2						<= NoDevice_sy1			WHEN rising_edge(GTP_Clock_4X(I));
			DD_NoDevice_i						<= NoDevice_sy2;
		END BLOCK;

		Sync6 : ENTITY PoC.misc_Synchronizer
			GENERIC MAP (
				BITS										=> 1,														-- number of bit to be synchronized
				GATED_INPUT_BY_BUSY			=> TRUE													-- use gated input (by busy SIGNAL)
			)
			PORT MAP (
				Clock1									=> Control_Clock,								-- input clock domain
				Clock2									=> GTP_Clock_4X(I),							-- output clock domain
				I(0)										=> DD_NewDevice,								-- input bits
				O(0)										=> DD_NewDevice_i,							-- output bits
				B												=> OPEN													-- busy bits
			);

		PROCESS(GTP_ResetDone_i, DD_NoDevice_i, DD_NewDevice_i, TX_Error_i, RX_Error_i, Command)
		BEGIN
			Status(I) 							<= SATA_TRANSCEIVER_STATUS_READY;
			
			IF (Command(I) = SATA_TRANSCEIVER_CMD_POWERDOWN) THEN
				Status(I)							<= SATA_TRANSCEIVER_STATUS_POWERED_DOWN;
			ELSIF (GTP_ResetDone_i(I) = '0') THEN
				Status(I)							<= SATA_TRANSCEIVER_STATUS_RESETING;
			ELSIF (DD_NewDevice_i = '1') THEN
				Status(I)							<= SATA_TRANSCEIVER_STATUS_NEW_DEVICE;
			ELSIF (DD_NoDevice_i = '1') THEN
				Status(I)							<= SATA_TRANSCEIVER_STATUS_NO_DEVICE;
			ELSIF ((TX_Error_i(I) /= SATA_TRANSCEIVER_TX_ERROR_NONE) OR (RX_Error_i(I) /= SATA_TRANSCEIVER_RX_ERROR_NONE)) THEN
				Status(I)							<= SATA_TRANSCEIVER_STATUS_ERROR;

-- TODO: add TRANS_STATUS_***
--	-	TRANS_STATUS_CONFIGURATION,
			END IF;
		END PROCESS;
	END GENERATE;


-- ==================================================================
-- DRP - dynamic reconfiguration port
-- ==================================================================
	GTPConfig : ENTITY PoC.sata_Transceiver_Virtex5_GTP_Configurator
		GENERIC MAP (
			DEBUG								=> DEBUG,
			DRPCLOCK_FREQ_MHZ							=> CLOCK_IN_FREQ_MHZ,
			PORTS													=> PORTS,
			INITIAL_SATA_GENERATIONS			=> INITIAL_SATA_GENERATIONS
		)
		PORT MAP (
			DRP_Clock											=> GTP_DRP_Clock,
			DRP_Reset											=> GTPConfig_Reset,								-- @DRP_Clock
			SATA_Clock										=> GTP_Clock_4X,
	
			Reconfig											=> RP_Reconfig,										-- @SATA_Clock
			ReconfigComplete							=> RP_ReconfigComplete,						-- @SATA_Clock
			ConfigReloaded								=> RP_ConfigReloaded,							-- @SATA_Clock
			Lock													=> RP_Lock,												-- @SATA_Clock
			Locked												=> RP_Locked,											-- @SATA_Clock
	
			SATA_Generation								=> SATA_Generation,								-- @SATA_Clock
			NoDevice											=> DD_NoDevice,										-- @DRP_Clock
	
			GTP_DRP_en										=> GTP_DRP_en,										-- @DRP_Clock
			GTP_DRP_Address								=> GTP_DRP_Address,								-- @DRP_Clock
			GTP_DRP_we										=> GTP_DRP_we,										-- @DRP_Clock
			GTP_DRP_DataIn								=> GTP_DRP_DataOut,								-- @DRP_Clock
			GTP_DRP_DataOut								=> GTP_DRP_DataIn,								-- @DRP_Clock
			GTP_DRP_Ready									=> GTP_DRP_rdy,										-- @DRP_Clock
			
			GTP_ReloadConfig							=> GTP_ReloadConfig,							-- @DRP_Clock
			GTP_ReloadConfigDone					=> GTP_ReloadConfigDone						-- @DRP_Clock
		);


-- ==================================================================
-- GTP_DUAL - 1 used port
-- ==================================================================
	SinglePort : IF (PORTS = 1) GENERATE
	 SIGNAL GTP_RX_DisableElectricalIDLEReset : STD_LOGIC;
	 
	BEGIN
		GTP_RX_DisableElectricalIDLEReset		<= NOT GTP_RX_EnableElectricalIDLEReset;

		GTP : GTP_DUAL
			GENERIC MAP (
				-- ===================== Simulation-Only Attributes ====================
	--			SIM_RECEIVER_DETECT_PASS0	 		=>			 TRUE,
	--			SIM_RECEIVER_DETECT_PASS1	 		=>			 TRUE,
				SIM_MODE											=>			 "FAST",				
				SIM_GTPRESET_SPEEDUP					=>			 0,
	--			SIM_PLL_PERDIV2								=>			 TILE_SIM_PLL_PERDIV2,

				-- ========================== Shared Attributes ========================
				-------------------------- Tile and PLL Attributes ---------------------
				CLK25_DIVIDER									=>			 6, 
				CLKINDC_B											=>			 TRUE,
				OOB_CLK_DIVIDER								=>			 6,							-- divide 150 MHz to 25 MHz => DIVIDER = 6
				OVERSAMPLE_MODE								=>			 FALSE,
				PLL_DIVSEL_FB									=>			 2,							-- PLL clock feedback devider 
				PLL_DIVSEL_REF								=>			 1,							-- PLL input clock devider
				PLL_TXDIVSEL_COMM_OUT					=>			 1,							-- don't devide common TX clock, use private TXDIVSEL_OUT clock deviders
				TX_SYNC_FILTERB								=>			 1,	 

				-- ================== Transmit Interface Attributes ====================
				------------------- TX Buffering and Phase Alignment -------------------	 
				TX_BUFFER_USE_0								=>			 TRUE,
				TX_XCLK_SEL_0									=>			 "TXOUT",
				TXRX_INVERT_0									=>			 "00000",				

				TX_BUFFER_USE_1								=>			 TRUE,
				TX_XCLK_SEL_1									=>			 "TXOUT",
				TXRX_INVERT_1									=>			 "00000",				

				--------------------- TX Serial Line Rate settings ---------------------	 
				PLL_TXDIVSEL_OUT_0						=>			 CLOCK_DIVIDERS(0),												-- 1 => GENERATION_2, 2 => GENERATION_1
				PLL_TXDIVSEL_OUT_1						=>			 CLOCK_DIVIDERS(0),												-- 1 => GENERATION_2, 2 => GENERATION_1

				--------------------- TX Driver and OOB SIGNALling --------------------	
				TX_DIFF_BOOST_0								=>			 TRUE,
				TX_DIFF_BOOST_1								=>			 TRUE,

				------------------ TX Pipe Control for PCI Express/SATA ---------------
				COM_BURST_VAL_0								=>			 "0110",																	-- TX OOB burst counter
				COM_BURST_VAL_1								=>			 "0110",																	-- TX OOB burst counter
					
				-- =================== Receive Interface Attributes ===================
				------------ RX Driver,OOB SIGNALling,Coupling and Eq,CDR -------------	
				AC_CAP_DIS_0									=>			 FALSE,
				OOBDETECT_THRESHOLD_0					=>			 "100",																		-- Threshold between RXN and RXP is 105 mV
				PMA_CDR_SCAN_0								=>			 x"6C08040",
				PMA_RX_CFG_0									=>			 x"0DCE111",	
				RCV_TERM_GND_0								=>			 FALSE,
				RCV_TERM_MID_0								=>			 TRUE,
				RCV_TERM_VTTRX_0							=>			 TRUE,
				TERMINATION_IMP_0							=>			 50,																			-- 50 Ohm Terminierung

				AC_CAP_DIS_1									=>			 FALSE,
				OOBDETECT_THRESHOLD_1					=>			 "100",																		-- Threshold between RXN and RXP is 105 mV
				PMA_CDR_SCAN_1								=>			 x"6C08040",
				PMA_RX_CFG_1									=>			 x"0DCE111",	
				RCV_TERM_GND_1								=>			 FALSE,
				RCV_TERM_MID_1								=>			 TRUE,
				RCV_TERM_VTTRX_1							=>			 TRUE,
				TERMINATION_IMP_1							=>			 50,																			-- 50 Ohm Terminierung

	--			PCS_COM_CFG										=>			 x"1680a0e",	
				TERMINATION_CTRL							=>			 "10100",
				TERMINATION_OVRD							=>			 FALSE,

				--------------------- RX Serial Line Rate Attributes ------------------	 
				PLL_RXDIVSEL_OUT_0						=>			 CLOCK_DIVIDERS(0),												-- 1 => GENERATION_2, 2 => GENERATION_1
				PLL_RXDIVSEL_OUT_1						=>			 CLOCK_DIVIDERS(0),

				PLL_SATA_0										=>			 FALSE,
				PLL_SATA_1										=>			 FALSE,

				----------------------- PRBS Detection Attributes ---------------------	
				PRBS_ERR_THRESHOLD_0					=>			 x"00000008",
				PRBS_ERR_THRESHOLD_1					=>			 x"00000008",

				---------------- Comma Detection and Alignment Attributes -------------	
				ALIGN_COMMA_WORD_0						=>			 1,
				COMMA_10B_ENABLE_0						=>			 "1111111111",
				COMMA_DOUBLE_0								=>			 FALSE,
				DEC_MCOMMA_DETECT_0						=>			 TRUE,
				DEC_PCOMMA_DETECT_0						=>			 TRUE,
				DEC_VALID_COMMA_ONLY_0				=>			 FALSE,
				MCOMMA_10B_VALUE_0						=>			 "1010000011",														-- K28.5
				MCOMMA_DETECT_0								=>			 TRUE,
				PCOMMA_10B_VALUE_0						=>			 "0101111100",														-- K28.5
				PCOMMA_DETECT_0								=>			 TRUE,
				RX_SLIDE_MODE_0								=>			 "PCS",

				ALIGN_COMMA_WORD_1						=>			 1,
				COMMA_10B_ENABLE_1						=>			 "1111111111",
				COMMA_DOUBLE_1								=>			 FALSE,
				DEC_MCOMMA_DETECT_1						=>			 TRUE,
				DEC_PCOMMA_DETECT_1						=>			 TRUE,
				DEC_VALID_COMMA_ONLY_1				=>			 FALSE,
				MCOMMA_10B_VALUE_1						=>			 "1010000011",														-- K28.5
				MCOMMA_DETECT_1								=>			 TRUE,
				PCOMMA_10B_VALUE_1						=>			 "0101111100",														-- K28.5
				PCOMMA_DETECT_1								=>			 TRUE,
				RX_SLIDE_MODE_1								=>			 "PCS",

				------------------ RX Loss-of-sync State Machine Attributes -----------	
				RX_LOSS_OF_SYNC_FSM_0					=>			 FALSE,
				RX_LOS_INVALID_INCR_0					=>			 8,
				RX_LOS_THRESHOLD_0						=>			 128,

				RX_LOSS_OF_SYNC_FSM_1					=>			 FALSE,
				RX_LOS_INVALID_INCR_1					=>			 8,
				RX_LOS_THRESHOLD_1						=>			 128,

				-------------- RX Elastic Buffer and Phase alignment Attributes -------	 
				RX_BUFFER_USE_0								=>			 TRUE,
				RX_XCLK_SEL_0									=>			 "RXREC",

				RX_BUFFER_USE_1								=>			 TRUE,
				RX_XCLK_SEL_1									=>			 "RXREC",									 

				------------------------ Clock Correction Attributes ------------------	 
				CLK_CORRECT_USE_0							=>			 TRUE,
				CLK_COR_ADJ_LEN_0							=>			 4,
				CLK_COR_DET_LEN_0							=>			 4,
				CLK_COR_INSERT_IDLE_FLAG_0		=>			 FALSE,
				CLK_COR_KEEP_IDLE_0						=>			 FALSE,
				CLK_COR_MIN_LAT_0							=>			 16,
				CLK_COR_MAX_LAT_0							=>			 22,
				CLK_COR_PRECEDENCE_0					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_0					=>			 0,
				CLK_COR_SEQ_1_1_0							=>			 "0110111100",
				CLK_COR_SEQ_1_2_0							=>			 "0001001010",
				CLK_COR_SEQ_1_3_0							=>			 "0001001010",
				CLK_COR_SEQ_1_4_0							=>			 "0001111011",
				CLK_COR_SEQ_1_ENABLE_0				=>			 "1111",
				CLK_COR_SEQ_2_1_0							=>			 "0000000000",
				CLK_COR_SEQ_2_2_0							=>			 "0000000000",
				CLK_COR_SEQ_2_3_0							=>			 "0000000000",
				CLK_COR_SEQ_2_4_0							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_0				=>			 "0000",
				CLK_COR_SEQ_2_USE_0						=>			 FALSE,
				RX_DECODE_SEQ_MATCH_0					=>			 TRUE,

				CLK_CORRECT_USE_1							=>			 TRUE,
				CLK_COR_ADJ_LEN_1							=>			 4,
				CLK_COR_DET_LEN_1							=>			 4,
				CLK_COR_INSERT_IDLE_FLAG_1		=>			 FALSE,
				CLK_COR_KEEP_IDLE_1						=>			 FALSE,
				CLK_COR_MIN_LAT_1							=>			 16,
				CLK_COR_MAX_LAT_1							=>			 22,
				CLK_COR_PRECEDENCE_1					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_1					=>			 0,
				CLK_COR_SEQ_1_ENABLE_1				=>			 "1111",
				CLK_COR_SEQ_1_1_1							=>			 "0110111100",
				CLK_COR_SEQ_1_2_1							=>			 "0001001010",
				CLK_COR_SEQ_1_3_1							=>			 "0001001010",
				CLK_COR_SEQ_1_4_1							=>			 "0001111011",
				CLK_COR_SEQ_2_USE_1						=>			 FALSE,
				CLK_COR_SEQ_2_ENABLE_1				=>			 "0000",
				CLK_COR_SEQ_2_1_1							=>			 "0000000000",
				CLK_COR_SEQ_2_2_1							=>			 "0000000000",
				CLK_COR_SEQ_2_3_1							=>			 "0000000000",
				CLK_COR_SEQ_2_4_1							=>			 "0000000000",
				RX_DECODE_SEQ_MATCH_1					=>			 TRUE,

				------------------------ Channel Bonding Attributes -------------------	 
				CHAN_BOND_1_MAX_SKEW_0				=>			 7,
				CHAN_BOND_2_MAX_SKEW_0				=>			 7,
				CHAN_BOND_LEVEL_0							=>			 0,
				CHAN_BOND_MODE_0							=>			 "OFF",
				CHAN_BOND_SEQ_LEN_0						=>			 1,
				CHAN_BOND_SEQ_1_ENABLE_0			=>			 "0000",
				CHAN_BOND_SEQ_1_1_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_2_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_3_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_4_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_USE_0					=>			 FALSE,	
				CHAN_BOND_SEQ_2_ENABLE_0			=>			 "0000",
				CHAN_BOND_SEQ_2_1_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_2_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_3_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_4_0						=>			 "0000000000",
				PCI_EXPRESS_MODE_0						=>			 FALSE,	 
			 
				CHAN_BOND_1_MAX_SKEW_1				=>			 7,
				CHAN_BOND_2_MAX_SKEW_1				=>			 7,
				CHAN_BOND_LEVEL_1							=>			 0,
				CHAN_BOND_MODE_1							=>			 "OFF",
				CHAN_BOND_SEQ_LEN_1						=>			 1,
				CHAN_BOND_SEQ_1_ENABLE_1			=>			 "0000",
				CHAN_BOND_SEQ_1_1_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_2_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_3_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_4_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_USE_1					=>			 FALSE,	
				CHAN_BOND_SEQ_2_ENABLE_1			=>			 "0000",
				CHAN_BOND_SEQ_2_1_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_2_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_3_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_4_1						=>			 "0000000000",
				PCI_EXPRESS_MODE_1						=>			 FALSE,

				------------------ RX Attributes for PCI Express/SATA ---------------
				-- OOB COM*** SIGNAL detector @ 25 MHz with DDR (20 ns)
				RX_STATUS_FMT_0								=>			 "SATA",
				SATA_BURST_VAL_0							=>			 "100",							-- Burst count to detect OOB COM*** SIGNALs
				SATA_IDLE_VAL_0								=>			 "011",							-- IDLE count between bursts in OOB COM*** SIGNALs
				SATA_MIN_BURST_0							=>			 4,									-- 80 ns				SATA Spec Rev 1.1		55 ns
				SATA_MAX_BURST_0							=>			 7,									-- 140 ns				SATA Spec Rev 1.1		175 ns
				SATA_MIN_INIT_0								=>			 12,								-- 240 ns				SATA Spec Rev 1.1		175 ns
				SATA_MAX_INIT_0								=>			 22,								-- 440 ns				SATA Spec Rev 1.1		525 ns
				SATA_MIN_WAKE_0								=>			 4,									-- 80 ns				SATA Spec Rev 1.1		55 ns
				SATA_MAX_WAKE_0								=>			 7,									-- 140 ns				SATA Spec Rev 1.1		175 ns
				TRANS_TIME_FROM_P2_0					=>			 x"0060",
				TRANS_TIME_NON_P2_0						=>			 x"0025",
				TRANS_TIME_TO_P2_0						=>			 x"0100",

				RX_STATUS_FMT_1								=>			"SATA",
				SATA_BURST_VAL_1							=>			"100",							-- Burst count to detect OOB COM*** SIGNALs
				SATA_IDLE_VAL_1								=>			"100",							-- IDLE count between bursts in OOB COM*** SIGNALs
				SATA_MAX_BURST_1							=>			7,
				SATA_MAX_INIT_1								=>			22,
				SATA_MAX_WAKE_1								=>			7,
				SATA_MIN_BURST_1							=>			4,
				SATA_MIN_INIT_1								=>			12,
				SATA_MIN_WAKE_1								=>			4,
				TRANS_TIME_FROM_P2_1					=>			x"0060",
				TRANS_TIME_NON_P2_1						=>			x"0025",
				TRANS_TIME_TO_P2_1						=>			x"0100"
			) 
			PORT MAP (
				------------------------ Loopback and Powerdown Ports ----------------------
				LOOPBACK0											=>			"000",
				LOOPBACK1											=>			"000",
				RXPOWERDOWN0									=>			GTP_RX_PowerDown(0),
				RXPOWERDOWN1									=>			"11",
				TXPOWERDOWN0									=>			GTP_TX_PowerDown(0),
				TXPOWERDOWN1									=>			"11",
				----------------------- Receive Ports - 8b10b Decoder ----------------------
				RXCHARISCOMMA0								=>			GTP_RX_CharIsComma(0),				-- @ GTP_ClockRX_2X,	
				RXCHARISCOMMA1								=>			OPEN,
				RXCHARISK0										=>			GTP_RX_CharIsK(0),						-- @ GTP_ClockRX_2X,	
				RXCHARISK1										=>			OPEN,
				RXDEC8B10BUSE0								=>			'1',
				RXDEC8B10BUSE1								=>			'0',
				RXDISPERR0										=>			GTP_RX_DisparityError(0),			-- @ GTP_ClockRX_2X,	
				RXDISPERR1										=>			OPEN,
				RXNOTINTABLE0									=>			GTP_RX_Illegal8B10BCode(0),		-- @ GTP_ClockRX_2X,	
				RXNOTINTABLE1									=>			OPEN,
				RXRUNDISP0										=>			OPEN,
				RXRUNDISP1										=>			OPEN,
				------------------- Receive Ports - Channel Bonding Ports ------------------
				RXCHANBONDSEQ0								=>			OPEN,
				RXCHANBONDSEQ1								=>			OPEN,
				RXCHBONDI0										=>			"000",
				RXCHBONDI1										=>			"000",
				RXCHBONDO0										=>			OPEN,
				RXCHBONDO1										=>			OPEN,
				RXENCHANSYNC0									=>			'0',
				RXENCHANSYNC1									=>			'0',
				------------------- Receive Ports - Clock Correction Ports -----------------
				RXCLKCORCNT0									=>			GTP_RX_ClockCorrectionStatus(0),
				RXCLKCORCNT1									=>			OPEN,
				--------------- Receive Ports - Comma Detection and Alignment --------------
				RXBYTEISALIGNED0							=>			GTP_RX_ByteIsAligned(0),									-- @ GTP_ClockRX_2X,	high-active, long SIGNAL			bytes are aligned			
				RXBYTEISALIGNED1							=>			OPEN,
				RXBYTEREALIGN0								=>			GTP_RX_ByteRealign(0),										-- @ GTP_ClockRX_2X,	hight-active, short pulse			alignment has changed
				RXBYTEREALIGN1								=>			OPEN,
				RXCOMMADET0										=>			GTP_RX_CommaDetected(0),
				RXCOMMADET1										=>			OPEN,
				RXCOMMADETUSE0								=>			'1',
				RXCOMMADETUSE1								=>			'0',
				RXENMCOMMAALIGN0							=>			'1',
				RXENMCOMMAALIGN1							=>			'1',
				RXENPCOMMAALIGN0							=>			'1',
				RXENPCOMMAALIGN1							=>			'1',
				RXSLIDE0											=>			'0',
				RXSLIDE1											=>			'0',
				----------------------- Receive Ports - PRBS Detection ---------------------
				PRBSCNTRESET0									=>			'0',
				PRBSCNTRESET1									=>			'0',
				RXENPRBSTST0									=>			"00",
				RXENPRBSTST1									=>			"00",
				RXPRBSERR0										=>			OPEN,
				RXPRBSERR1										=>			OPEN,
				------------------- Receive Ports - RX Data Path interface -----------------
				RXDATA0												=>			GTP_RX_Data(0),
				RXDATA1												=>			OPEN,
				RXDATAWIDTH0									=>			'0',																			-- 8 Bit data interface
				RXDATAWIDTH1									=>			'0',																			-- 8 Bit data interface
				RXRECCLK0											=>			GTP_RX_RefClockOut(0),										-- recovered clock from CDR
				RXRECCLK1											=>			OPEN,
				RXRESET0											=>			GTP_RX_Reset(0),
				RXRESET1											=>			'0',
				RXUSRCLK0											=>			GTP_Clock_1X(0),
				RXUSRCLK1											=>			'0',
				RXUSRCLK20										=>			GTP_Clock_1X(0),
				RXUSRCLK21										=>			'0',
				------- Receive Ports - RX Driver,OOB SIGNALing,Coupling and Eq.,CDR ------
				RXCDRRESET0										=>			GTP_RX_CDR_Reset(0),											-- CDR => Clock Data Recovery
				RXCDRRESET1										=>			'0',
				RXELECIDLE0										=>			GTP_RX_ElectricalIDLE(0),
				RXELECIDLE1										=>			OPEN,
				RXELECIDLERESET0							=>			GTP_RX_ElectricalIDLE_Reset(0),
				RXELECIDLERESET1							=>			'0',
				RXENEQB0											=>			'1',
				RXENEQB1											=>			'1',
				RXEQMIX0											=>			"00",
				RXEQMIX1											=>			"00",
				RXEQPOLE0											=>			"0000",
				RXEQPOLE1											=>			"0000",
				RXN0													=>			VSS_Private_In(0).RX_n,
				RXP0													=>			VSS_Private_In(0).RX_p,
				RXN1													=>			'0',
				RXP1													=>			'1',
				-------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
				RXBUFRESET0										=>			GTP_RX_BufferReset(0),
				RXBUFRESET1										=>			'0',
				RXBUFSTATUS0									=>			GTP_RX_BufferStatus(0),										-- GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXBUFSTATUS1									=>			OPEN,
				RXCHANISALIGNED0							=>			OPEN,
				RXCHANISALIGNED1							=>			OPEN,
				RXCHANREALIGN0								=>			OPEN,
				RXCHANREALIGN1								=>			OPEN,
				RXPMASETPHASE0								=>			'0',
				RXPMASETPHASE1								=>			'0',
				RXSTATUS0											=>			GTP_RX_Status(0),
				RXSTATUS1											=>			OPEN,
				--------------- Receive Ports - RX Loss-of-sync State Machine --------------
				RXLOSSOFSYNC0									=>			GTP_RX_LossOfSync(0),											-- Xilinx example has connected SIGNAL
				RXLOSSOFSYNC1									=>			OPEN,
				---------------------- Receive Ports - RX Oversampling ---------------------
				RXENSAMPLEALIGN0							=>			'0',
				RXENSAMPLEALIGN1							=>			'0',
				RXOVERSAMPLEERR0							=>			OPEN,
				RXOVERSAMPLEERR1							=>			OPEN,
				-------------- Receive Ports - RX Pipe Control for PCI Express -------------
				PHYSTATUS0										=>			OPEN,
				PHYSTATUS1										=>			OPEN,
				RXVALID0											=>			GTP_RX_Valid(0),
				RXVALID1											=>			OPEN,
				----------------- Receive Ports - RX Polarity Control Ports ----------------
				RXPOLARITY0										=>			'0',
				RXPOLARITY1										=>			'0',
				------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
				DCLK													=>			GTP_DRP_Clock,
				DEN														=>			GTP_DRP_en,
				DADDR													=>			GTP_DRP_Address(6 DOWNTO 0),							-- resize vector to GTP_DUAL specific address bits
				DWE														=>			GTP_DRP_we,
				DI														=>			GTP_DRP_DataIn,
				DO														=>			GTP_DRP_DataOut,
				DRDY													=>			GTP_DRP_rdy,
				--------------------- Shared Ports - Tile and PLL Ports --------------------
				CLKIN													=>			GTP_RefClockIn,
				GTPRESET											=>			GTP_Reset,
				GTPTEST												=>			"0000",
				INTDATAWIDTH									=>			'1',																									-- 10 Bit internal datawidth
				PLLLKDET											=>			GTP_PLL_ResetDone_i,																		-- GTP PLL lock detected
				PLLLKDETEN										=>			'1',
				PLLPOWERDOWN									=>			GTP_PLL_PowerDown,
				REFCLKOUT											=>			GTP_RefClockOut_i,
				REFCLKPWRDNB									=>			'1',
				RESETDONE0										=>			GTP_ResetDone_i(0),
				RESETDONE1										=>			OPEN,
				RXENELECIDLERESETB						=>			GTP_RX_DisableElectricalIDLEReset,									-- low-active => disable
				TXENPMAPHASEALIGN							=>			'0',
				TXPMASETPHASE									=>			'0',
					---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
				TXBYPASS8B10B0								=>			"00",																									-- encode both bytes with 8B10B
				TXBYPASS8B10B1								=>			"00",
				TXCHARDISPMODE0								=>			"00",
				TXCHARDISPMODE1								=>			"00",
				TXCHARDISPVAL0								=>			"00",
				TXCHARDISPVAL1								=>			"00",
				TXCHARISK0										=>			GTP_TX_CharIsK(0),
				TXCHARISK1										=>			"00",
				TXENC8B10BUSE0								=>			'1',																									-- use internal 8B10B encoder
				TXENC8B10BUSE1								=>			'0',
				TXKERR0												=>			GTP_TX_InvalidK(0),																		-- invalid K charakter
				TXKERR1												=>			OPEN,
				TXRUNDISP0										=>			OPEN,																									-- running disparity
				TXRUNDISP1										=>			OPEN,
				------------- Transmit Ports - TX Buffering and Phase Alignment ------------
				TXBUFSTATUS0									=>			GTP_TX_BufferStatus(0),
				TXBUFSTATUS1									=>			OPEN,
				------------------ Transmit Ports - TX Data Path interface -----------------
				TXDATA0												=>			GTP_TX_Data(0),
				TXDATA1												=>			(OTHERS => '0'),
				TXDATAWIDTH0									=>			'0',																									-- 8 Bit interface
				TXDATAWIDTH1									=>			'0',
				TXOUTCLK0											=>			GTP_TX_RefClockOut(0),
				TXOUTCLK1											=>			OPEN,
				TXRESET0											=>			GTP_TX_Reset(0),
				TXRESET1											=>			'0',								-- GTP_TX_Reset
				TXUSRCLK0											=>			GTP_Clock_1X(0),
				TXUSRCLK1											=>			'0',								-- GTP_Clock_1X
				TXUSRCLK20										=>			GTP_Clock_1X(0),	--GTP_ClockTX_2X(0),
				TXUSRCLK21										=>			'0',								-- GTP_ClockTX_2X
				--------------- Transmit Ports - TX Driver and OOB SIGNALing --------------
				TXBUFDIFFCTRL0								=>			"001",
				TXBUFDIFFCTRL1								=>			"001",
				TXDIFFCTRL0										=>			"100",
				TXDIFFCTRL1										=>			"100",
				TXINHIBIT0										=>			'0',
				TXINHIBIT1										=>			'0',
				TXN0													=>			VSS_Private_Out(0).TX_n,
				TXP0													=>			VSS_Private_Out(0).TX_p,
				TXN1													=>			OPEN,
				TXP1													=>			OPEN,
				TXPREEMPHASIS0								=>			"011",
				TXPREEMPHASIS1								=>			"011",
				--------------------- Transmit Ports - TX PRBS Generator -------------------
				TXENPRBSTST0									=>			"00",
				TXENPRBSTST1									=>			"00",
				-------------------- Transmit Ports - TX Polarity Control ------------------
				TXPOLARITY0										=>			'0',
				TXPOLARITY1										=>			'0',
					----------------- Transmit Ports - TX Ports for PCI Express ----------------
				TXDETECTRX0										=>			'0',
				TXDETECTRX1										=>			'0',
				TXELECIDLE0										=>			GTP_TX_ElectricalIDLE(0),
				TXELECIDLE1										=>			'1',
					--------------------- Transmit Ports - TX Ports for SATA -------------------
				TXCOMSTART0										=>			GTP_TX_ComStart(0),
				TXCOMSTART1										=>			'0',
				TXCOMTYPE0										=>			GTP_TX_ComType(0),
				TXCOMTYPE1										=>			'0'
			);
	END GENERATE;


-- ==================================================================
-- GTP_DUAL - 2 used ports
-- ==================================================================
	DualPort : IF (PORTS = 2) GENERATE
		SIGNAL GTP_RX_DisableElectricalIDLEReset : STD_LOGIC;
	BEGIN
		GTP_RX_DisableElectricalIDLEReset		<= NOT GTP_RX_EnableElectricalIDLEReset;
		
		GTP : GTP_DUAL
			GENERIC MAP (
				-- ===================== Simulation-Only Attributes ====================
	--			SIM_RECEIVER_DETECT_PASS0	 		=>			 TRUE,
	--			SIM_RECEIVER_DETECT_PASS1	 		=>			 TRUE,
				SIM_MODE											=>			 "FAST",				
				SIM_GTPRESET_SPEEDUP					=>			 1,
	--			SIM_PLL_PERDIV2								=>			 TILE_SIM_PLL_PERDIV2,

				-- ========================== Shared Attributes ========================
				-------------------------- Tile and PLL Attributes ---------------------
				CLK25_DIVIDER									=>			 6, 
				CLKINDC_B											=>			 TRUE,
				OOB_CLK_DIVIDER								=>			 6,
				OVERSAMPLE_MODE								=>			 FALSE,
				PLL_DIVSEL_FB									=>			 2,
				PLL_DIVSEL_REF								=>			 1,
				PLL_TXDIVSEL_COMM_OUT					=>			 1,
				TX_SYNC_FILTERB								=>			 1,	 

				-- ================== Transmit Interface Attributes ====================
				------------------- TX Buffering and Phase Alignment -------------------	 
				TX_BUFFER_USE_0								=>			 TRUE,
				TX_XCLK_SEL_0									=>			 "TXOUT",
				TXRX_INVERT_0									=>			 "00000",				

				TX_BUFFER_USE_1								=>			 TRUE,
				TX_XCLK_SEL_1									=>			 "TXOUT",
				TXRX_INVERT_1									=>			 "00000",				

				--------------------- TX Serial Line Rate settings ---------------------	 
				PLL_TXDIVSEL_OUT_0						=>			 CLOCK_DIVIDERS(0),							-- 1 => GENERATION_2, 2 => GENERATION_1
				PLL_TXDIVSEL_OUT_1						=>			 CLOCK_DIVIDERS(1),

				--------------------- TX Driver and OOB SIGNALling --------------------	
				TX_DIFF_BOOST_0								=>			 TRUE,
				TX_DIFF_BOOST_1								=>			 TRUE,

				------------------ TX Pipe Control for PCI Express/SATA ---------------
				COM_BURST_VAL_0								=>			 "0110",
				COM_BURST_VAL_1								=>			 "0110",
					
				-- =================== Receive Interface Attributes ===================
				------------ RX Driver,OOB SIGNALling,Coupling and Eq,CDR -------------	
				AC_CAP_DIS_0									=>			 FALSE,
				OOBDETECT_THRESHOLD_0					=>			 "100",					-- treshold voltage = 105 mV
				PMA_CDR_SCAN_0								=>			 x"6C08040",
				PMA_RX_CFG_0									=>			 x"0DCE111",	
				RCV_TERM_GND_0								=>			 FALSE,
				RCV_TERM_MID_0								=>			 TRUE,
				RCV_TERM_VTTRX_0							=>			 TRUE,
				TERMINATION_IMP_0							=>			 50,						-- 50 Ohm termination

				AC_CAP_DIS_1									=>			 FALSE,
				OOBDETECT_THRESHOLD_1					=>			 "100",					-- treshold voltage = 105 mV
				PMA_CDR_SCAN_1								=>			 x"6C08040",
				PMA_RX_CFG_1									=>			 x"0DCE111",	
				RCV_TERM_GND_1								=>			 FALSE,
				RCV_TERM_MID_1								=>			 TRUE,
				RCV_TERM_VTTRX_1							=>			 TRUE,
				TERMINATION_IMP_1							=>			 50,						-- 50 Ohm termination

	--			PCS_COM_CFG										=>			 x"1680a0e",	
				TERMINATION_CTRL							=>			 "10100",
				TERMINATION_OVRD							=>			 FALSE,

				--------------------- RX Serial Line Rate Attributes ------------------	 
				PLL_RXDIVSEL_OUT_0						=>			 CLOCK_DIVIDERS(0),							-- 1 => GENERATION_2, 2 => GENERATION_1
				PLL_RXDIVSEL_OUT_1						=>			 CLOCK_DIVIDERS(1),							-- 1 => GENERATION_2, 2 => GENERATION_1
				
				PLL_SATA_0										=>			 FALSE,
				PLL_SATA_1										=>			 FALSE,

				----------------------- PRBS Detection Attributes ---------------------	
				PRBS_ERR_THRESHOLD_0					=>			 x"00000008",
				PRBS_ERR_THRESHOLD_1					=>			 x"00000008",

				---------------- Comma Detection and Alignment Attributes -------------	
				ALIGN_COMMA_WORD_0						=>			 1,
				COMMA_10B_ENABLE_0						=>			 "1111111111",
				COMMA_DOUBLE_0								=>			 FALSE,
				DEC_MCOMMA_DETECT_0						=>			 TRUE,
				DEC_PCOMMA_DETECT_0						=>			 TRUE,
				DEC_VALID_COMMA_ONLY_0				=>			 FALSE,
				MCOMMA_10B_VALUE_0						=>			 "1010000011",
				MCOMMA_DETECT_0								=>			 TRUE,
				PCOMMA_10B_VALUE_0						=>			 "0101111100",
				PCOMMA_DETECT_0								=>			 TRUE,
				RX_SLIDE_MODE_0								=>			 "PCS",

				ALIGN_COMMA_WORD_1						=>			 1,
				COMMA_10B_ENABLE_1						=>			 "1111111111",
				COMMA_DOUBLE_1								=>			 FALSE,
				DEC_MCOMMA_DETECT_1						=>			 TRUE,
				DEC_PCOMMA_DETECT_1						=>			 TRUE,
				DEC_VALID_COMMA_ONLY_1				=>			 FALSE,
				MCOMMA_10B_VALUE_1						=>			 "1010000011",
				MCOMMA_DETECT_1								=>			 TRUE,
				PCOMMA_10B_VALUE_1						=>			 "0101111100",
				PCOMMA_DETECT_1								=>			 TRUE,
				RX_SLIDE_MODE_1								=>			 "PCS",

				------------------ RX Loss-of-sync State Machine Attributes -----------	
				RX_LOSS_OF_SYNC_FSM_0					=>			 FALSE,
				RX_LOS_INVALID_INCR_0					=>			 8,
				RX_LOS_THRESHOLD_0						=>			 128,

				RX_LOSS_OF_SYNC_FSM_1					=>			 FALSE,
				RX_LOS_INVALID_INCR_1					=>			 8,
				RX_LOS_THRESHOLD_1						=>			 128,

				-------------- RX Elastic Buffer and Phase alignment Attributes -------	 
				RX_BUFFER_USE_0								=>			 TRUE,
				RX_XCLK_SEL_0									=>			 "RXREC",

				RX_BUFFER_USE_1								=>			 TRUE,
				RX_XCLK_SEL_1									=>			 "RXREC",									 

				------------------------ Clock Correction Attributes ------------------	 
				CLK_CORRECT_USE_0							=>			 TRUE,
				CLK_COR_ADJ_LEN_0							=>			 4,
				CLK_COR_DET_LEN_0							=>			 4,
				CLK_COR_INSERT_IDLE_FLAG_0		=>			 FALSE,
				CLK_COR_KEEP_IDLE_0						=>			 FALSE,
				CLK_COR_MIN_LAT_0							=>			 16,
				CLK_COR_MAX_LAT_0							=>			 18,
				CLK_COR_PRECEDENCE_0					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_0					=>			 0,
				CLK_COR_SEQ_1_1_0							=>			 "0110111100",
				CLK_COR_SEQ_1_2_0							=>			 "0001001010",
				CLK_COR_SEQ_1_3_0							=>			 "0001001010",
				CLK_COR_SEQ_1_4_0							=>			 "0001111011",
				CLK_COR_SEQ_1_ENABLE_0				=>			 "1111",
				CLK_COR_SEQ_2_1_0							=>			 "0000000000",
				CLK_COR_SEQ_2_2_0							=>			 "0000000000",
				CLK_COR_SEQ_2_3_0							=>			 "0000000000",
				CLK_COR_SEQ_2_4_0							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_0				=>			 "0000",
				CLK_COR_SEQ_2_USE_0						=>			 FALSE,
				RX_DECODE_SEQ_MATCH_0					=>			 TRUE,

				CLK_CORRECT_USE_1							=>			 TRUE,
				CLK_COR_ADJ_LEN_1							=>			 4,
				CLK_COR_DET_LEN_1							=>			 4,
				CLK_COR_INSERT_IDLE_FLAG_1		=>			 FALSE,
				CLK_COR_KEEP_IDLE_1						=>			 FALSE,
				CLK_COR_MIN_LAT_1							=>			 16,
				CLK_COR_MAX_LAT_1							=>			 18,
				CLK_COR_PRECEDENCE_1					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_1					=>			 0,
				CLK_COR_SEQ_1_1_1							=>			 "0110111100",
				CLK_COR_SEQ_1_2_1							=>			 "0001001010",
				CLK_COR_SEQ_1_3_1							=>			 "0001001010",
				CLK_COR_SEQ_1_4_1							=>			 "0001111011",
				CLK_COR_SEQ_1_ENABLE_1				=>			 "1111",
				CLK_COR_SEQ_2_1_1							=>			 "0000000000",
				CLK_COR_SEQ_2_2_1							=>			 "0000000000",
				CLK_COR_SEQ_2_3_1							=>			 "0000000000",
				CLK_COR_SEQ_2_4_1							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_1				=>			 "0000",
				CLK_COR_SEQ_2_USE_1						=>			 FALSE,
				RX_DECODE_SEQ_MATCH_1					=>			 TRUE,

				------------------------ Channel Bonding Attributes -------------------	 
				CHAN_BOND_1_MAX_SKEW_0				=>			 7,
				CHAN_BOND_2_MAX_SKEW_0				=>			 7,
				CHAN_BOND_LEVEL_0							=>			 0,
				CHAN_BOND_MODE_0							=>			 "OFF",
				CHAN_BOND_SEQ_1_1_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_2_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_3_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_4_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_ENABLE_0			=>			 "0000",
				CHAN_BOND_SEQ_2_1_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_2_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_3_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_4_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_ENABLE_0			=>			 "0000",
				CHAN_BOND_SEQ_2_USE_0					=>			 FALSE,	
				CHAN_BOND_SEQ_LEN_0						=>			 1,
				PCI_EXPRESS_MODE_0						=>			 FALSE,	 
			 
				CHAN_BOND_1_MAX_SKEW_1				=>			 7,
				CHAN_BOND_2_MAX_SKEW_1				=>			 7,
				CHAN_BOND_LEVEL_1							=>			 0,
				CHAN_BOND_MODE_1							=>			 "OFF",
				CHAN_BOND_SEQ_1_1_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_2_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_3_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_4_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_ENABLE_1			=>			 "0000",
				CHAN_BOND_SEQ_2_1_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_2_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_3_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_4_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_ENABLE_1			=>			 "0000",
				CHAN_BOND_SEQ_2_USE_1					=>			 FALSE,	
				CHAN_BOND_SEQ_LEN_1						=>			 1,
				PCI_EXPRESS_MODE_1						=>			 FALSE,

				------------------ RX Attributes for PCI Express/SATA ---------------
				RX_STATUS_FMT_0								=>			 "SATA",
				SATA_BURST_VAL_0							=>			 "100",
				SATA_IDLE_VAL_0								=>			 "011",
				SATA_MIN_BURST_0							=>			 4,
				SATA_MAX_BURST_0							=>			 7,
				SATA_MIN_INIT_0								=>			 12,
				SATA_MAX_INIT_0								=>			 22,
				SATA_MIN_WAKE_0								=>			 4,
				SATA_MAX_WAKE_0								=>			 7,
				TRANS_TIME_FROM_P2_0					=>			 x"0060",
				TRANS_TIME_NON_P2_0						=>			 x"0025",
				TRANS_TIME_TO_P2_0						=>			 x"0100",

				RX_STATUS_FMT_1								=>			"SATA",
				SATA_BURST_VAL_1							=>			"100",
				SATA_IDLE_VAL_1								=>			"011",
				SATA_MIN_BURST_1							=>			4,
				SATA_MAX_BURST_1							=>			7,
				SATA_MIN_INIT_1								=>			12,
				SATA_MAX_INIT_1								=>			22,
				SATA_MIN_WAKE_1								=>			4,
				SATA_MAX_WAKE_1								=>			7,
				TRANS_TIME_FROM_P2_1					=>			x"0060",
				TRANS_TIME_NON_P2_1						=>			x"0025",
				TRANS_TIME_TO_P2_1						=>			x"0100"
			) 
			PORT MAP (
				------------------------ Loopback and Powerdown Ports ----------------------
				LOOPBACK0											=>			"000",
				LOOPBACK1											=>			"000",
				RXPOWERDOWN0									=>			GTP_RX_PowerDown(0),
				RXPOWERDOWN1									=>			GTP_RX_PowerDown(1),
				TXPOWERDOWN0									=>			GTP_TX_PowerDown(0),
				TXPOWERDOWN1									=>			GTP_TX_PowerDown(1),
				----------------------- Receive Ports - 8b10b Decoder ----------------------
				RXCHARISCOMMA0								=>			GTP_RX_CharIsComma(0),				-- @ GTP_ClockRX_2X,	
				RXCHARISCOMMA1								=>			GTP_RX_CharIsComma(1),
				RXCHARISK0										=>			GTP_RX_CharIsK(0),						-- @ GTP_ClockRX_2X,	
				RXCHARISK1										=>			GTP_RX_CharIsK(1),
				RXDEC8B10BUSE0								=>			'1',
				RXDEC8B10BUSE1								=>			'1',
				RXDISPERR0										=>			GTP_RX_DisparityError(0),			-- @ GTP_ClockRX_2X,	
				RXDISPERR1										=>			GTP_RX_DisparityError(1),
				RXNOTINTABLE0									=>			GTP_RX_Illegal8B10BCode(0),		-- @ GTP_ClockRX_2X,	
				RXNOTINTABLE1									=>			GTP_RX_Illegal8B10BCode(1),
				RXRUNDISP0										=>			OPEN,
				RXRUNDISP1										=>			OPEN,
				------------------- Receive Ports - Channel Bonding Ports ------------------
				RXCHANBONDSEQ0								=>			OPEN,
				RXCHANBONDSEQ1								=>			OPEN,
				RXCHBONDI0										=>			"000",
				RXCHBONDI1										=>			"000",
				RXCHBONDO0										=>			OPEN,
				RXCHBONDO1										=>			OPEN,
				RXENCHANSYNC0									=>			'0',
				RXENCHANSYNC1									=>			'0',
				------------------- Receive Ports - Clock Correction Ports -----------------
				RXCLKCORCNT0									=>			GTP_RX_ClockCorrectionStatus(0),
				RXCLKCORCNT1									=>			GTP_RX_ClockCorrectionStatus(1),
				--------------- Receive Ports - Comma Detection and Alignment --------------
				RXBYTEISALIGNED0							=>			GTP_RX_ByteIsAligned(0),									-- @ GTP_ClockRX_2X,	high-active, long SIGNAL			bytes are aligned			
				RXBYTEISALIGNED1							=>			GTP_RX_ByteIsAligned(1),
				RXBYTEREALIGN0								=>			GTP_RX_ByteRealign(0),										-- @ GTP_ClockRX_2X,	hight-active, short pulse			alignment has changed
				RXBYTEREALIGN1								=>			GTP_RX_ByteRealign(1),
				RXCOMMADET0										=>			GTP_RX_CommaDetected(0),
				RXCOMMADET1										=>			GTP_RX_CommaDetected(1),
				RXCOMMADETUSE0								=>			'1',
				RXCOMMADETUSE1								=>			'1',
				RXENMCOMMAALIGN0							=>			'1',
				RXENMCOMMAALIGN1							=>			'1',
				RXENPCOMMAALIGN0							=>			'1',
				RXENPCOMMAALIGN1							=>			'1',
				RXSLIDE0											=>			'0',
				RXSLIDE1											=>			'0',
				----------------------- Receive Ports - PRBS Detection ---------------------
				PRBSCNTRESET0									=>			'0',
				PRBSCNTRESET1									=>			'0',
				RXENPRBSTST0									=>			"00",
				RXENPRBSTST1									=>			"00",
				RXPRBSERR0										=>			OPEN,
				RXPRBSERR1										=>			OPEN,
				------------------- Receive Ports - RX Data Path interface -----------------
				RXDATA0												=>			GTP_RX_Data(0),
				RXDATA1												=>			GTP_RX_Data(1),
				RXDATAWIDTH0									=>			'0',																			-- 8 Bit data interface
				RXDATAWIDTH1									=>			'0',																			-- 8 Bit data interface
				RXRECCLK0											=>			GTP_RX_RefClockOut(0),										-- recovered clock from CDR
				RXRECCLK1											=>			GTP_RX_RefClockOut(1),										-- recovered clock from CDR
				RXRESET0											=>			GTP_RX_Reset(0),
				RXRESET1											=>			GTP_RX_Reset(1),
				RXUSRCLK0											=>			GTP_Clock_1X(0),
				RXUSRCLK1											=>			GTP_Clock_1X(1),
				RXUSRCLK20										=>			GTP_Clock_1X(0),
				RXUSRCLK21										=>			GTP_Clock_1X(1),
				------- Receive Ports - RX Driver,OOB SIGNALing,Coupling and Eq.,CDR ------
				RXCDRRESET0										=>			GTP_RX_CDR_Reset(0),											-- CDR => Clock Data Recovery
				RXCDRRESET1										=>			GTP_RX_CDR_Reset(1),
				RXELECIDLE0										=>			GTP_RX_ElectricalIDLE(0),
				RXELECIDLE1										=>			GTP_RX_ElectricalIDLE(1),
				RXELECIDLERESET0							=>			GTP_RX_ElectricalIDLE_Reset(0),
				RXELECIDLERESET1							=>			GTP_RX_ElectricalIDLE_Reset(1),
				RXENEQB0											=>			'1',
				RXENEQB1											=>			'1',
				RXEQMIX0											=>			"00",
				RXEQMIX1											=>			"00",
				RXEQPOLE0											=>			"0000",
				RXEQPOLE1											=>			"0000",
				RXN0													=>			VSS_Private_In(0).RX_n,
				RXP0													=>			VSS_Private_In(0).RX_p,
				RXN1													=>			VSS_Private_In(1).RX_n,
				RXP1													=>			VSS_Private_In(1).RX_p,
				-------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
				RXBUFRESET0										=>			GTP_RX_BufferReset(0),
				RXBUFRESET1										=>			GTP_RX_BufferReset(1),
				RXBUFSTATUS0									=>			GTP_RX_BufferStatus(0),													-- @GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXBUFSTATUS1									=>			GTP_RX_BufferStatus(1),
				RXCHANISALIGNED0							=>			OPEN,
				RXCHANISALIGNED1							=>			OPEN,
				RXCHANREALIGN0								=>			OPEN,
				RXCHANREALIGN1								=>			OPEN,
				RXPMASETPHASE0								=>			'0',
				RXPMASETPHASE1								=>			'0',
				RXSTATUS0											=>			GTP_RX_Status(0),
				RXSTATUS1											=>			GTP_RX_Status(1),
				--------------- Receive Ports - RX Loss-of-sync State Machine --------------
				RXLOSSOFSYNC0									=>			GTP_RX_LossOfSync(0),														-- Xilinx example has connected SIGNAL
				RXLOSSOFSYNC1									=>			GTP_RX_LossOfSync(1),
				---------------------- Receive Ports - RX Oversampling ---------------------
				RXENSAMPLEALIGN0							=>			'0',
				RXENSAMPLEALIGN1							=>			'0',
				RXOVERSAMPLEERR0							=>			OPEN,
				RXOVERSAMPLEERR1							=>			OPEN,
				-------------- Receive Ports - RX Pipe Control for PCI Express -------------
				PHYSTATUS0										=>			OPEN,
				PHYSTATUS1										=>			OPEN,
				RXVALID0											=>			GTP_RX_Valid(0),
				RXVALID1											=>			GTP_RX_Valid(1),
				----------------- Receive Ports - RX Polarity Control Ports ----------------
				RXPOLARITY0										=>			'0',
				RXPOLARITY1										=>			'0',
				------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
				DCLK													=>			GTP_DRP_Clock,
				DEN														=>			GTP_DRP_en,
				DADDR													=>			GTP_DRP_Address,
				DWE														=>			GTP_DRP_we,
				DI														=>			GTP_DRP_DataIn,
				DO														=>			GTP_DRP_DataOut,
				DRDY													=>			GTP_DRP_rdy,
				--------------------- Shared Ports - Tile and PLL Ports --------------------
				CLKIN													=>			GTP_RefClockIn,
				GTPRESET											=>			GTP_Reset,
				GTPTEST												=>			"0000",
				INTDATAWIDTH									=>			'1',																			-- 10 Bit internal datawidth
				PLLLKDET											=>			GTP_PLL_ResetDone_i,												-- GTP PLL lock detected
				PLLLKDETEN										=>			'1',
				PLLPOWERDOWN									=>			GTP_PLL_PowerDown,
				REFCLKOUT											=>			GTP_RefClockOut_i,
				REFCLKPWRDNB									=>			'1',
				RESETDONE0										=>			GTP_ResetDone_i(0),
				RESETDONE1										=>			GTP_ResetDone_i(1),
				RXENELECIDLERESETB						=>			GTP_RX_DisableElectricalIDLEReset,				-- low-active
				TXENPMAPHASEALIGN							=>			'0',
				TXPMASETPHASE									=>			'0',
					---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
				TXBYPASS8B10B0								=>			"00",																			-- encode both bytes with 8B10B
				TXBYPASS8B10B1								=>			"00",
				TXCHARDISPMODE0								=>			"00",
				TXCHARDISPMODE1								=>			"00",
				TXCHARDISPVAL0								=>			"00",
				TXCHARDISPVAL1								=>			"00",
				TXCHARISK0										=>			GTP_TX_CharIsK(0),
				TXCHARISK1										=>			GTP_TX_CharIsK(1),
				TXENC8B10BUSE0								=>			'1',																			-- use internal 8B10B encoder
				TXENC8B10BUSE1								=>			'1',
				TXKERR0												=>			GTP_TX_InvalidK(0),												-- invalid K charakter
				TXKERR1												=>			GTP_TX_InvalidK(1),
				TXRUNDISP0										=>			OPEN,																			-- running disparity
				TXRUNDISP1										=>			OPEN,
				------------- Transmit Ports - TX Buffering and Phase Alignment ------------
				TXBUFSTATUS0									=>			GTP_TX_BufferStatus(0),
				TXBUFSTATUS1									=>			GTP_TX_BufferStatus(1),
				------------------ Transmit Ports - TX Data Path interface -----------------
				TXDATA0												=>			GTP_TX_Data(0),
				TXDATA1												=>			GTP_TX_Data(1),
				TXDATAWIDTH0									=>			'0',																			-- 8 Bit data interface
				TXDATAWIDTH1									=>			'0',																			-- 8 Bit data interface
				TXOUTCLK0											=>			GTP_TX_RefClockOut(0),
				TXOUTCLK1											=>			GTP_TX_RefClockOut(1),
				TXRESET0											=>			GTP_TX_Reset(0),
				TXRESET1											=>			GTP_TX_Reset(1),													-- GTP_TX_Reset
				TXUSRCLK0											=>			GTP_Clock_1X(0),
				TXUSRCLK1											=>			GTP_Clock_1X(1),												-- GTP_Clock_1X
				TXUSRCLK20										=>			GTP_Clock_1X(0),
				TXUSRCLK21										=>			GTP_Clock_1X(1),												-- GTP_ClockTX_2X
				--------------- Transmit Ports - TX Driver and OOB SIGNALing --------------
				TXBUFDIFFCTRL0								=>			"001",
				TXBUFDIFFCTRL1								=>			"001",
				TXDIFFCTRL0										=>			"100",
				TXDIFFCTRL1										=>			"100",
				TXINHIBIT0										=>			'0',
				TXINHIBIT1										=>			'0',
				TXN0													=>			VSS_Private_Out(0).TX_n,
				TXP0													=>			VSS_Private_Out(0).TX_p,
				TXN1													=>			VSS_Private_Out(1).TX_n,
				TXP1													=>			VSS_Private_Out(1).TX_p,
				TXPREEMPHASIS0								=>			"011",
				TXPREEMPHASIS1								=>			"011",
				--------------------- Transmit Ports - TX PRBS Generator -------------------
				TXENPRBSTST0									=>			"00",
				TXENPRBSTST1									=>			"00",
				-------------------- Transmit Ports - TX Polarity Control ------------------
				TXPOLARITY0										=>			'0',
				TXPOLARITY1										=>			'0',
					----------------- Transmit Ports - TX Ports for PCI Express ----------------
				TXDETECTRX0										=>			'0',
				TXDETECTRX1										=>			'0',
				TXELECIDLE0										=>			GTP_TX_ElectricalIDLE(0),
				TXELECIDLE1										=>			GTP_TX_ElectricalIDLE(1),
					--------------------- Transmit Ports - TX Ports for SATA -------------------
				TXCOMSTART0										=>			GTP_TX_ComStart(0),
				TXCOMSTART1										=>			GTP_TX_ComStart(1),
				TXCOMTYPE0										=>			GTP_TX_ComType(0),
				TXCOMTYPE1										=>			GTP_TX_ComType(1)
			);
	END GENERATE;
	
-- ==================================================================
-- ChipScope debugging signals
-- ==================================================================
	genCSP : IF (DEBUG = TRUE) GENERATE
		SIGNAL DBG_ClockTX_1X												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_ClockTX_4X												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		SIGNAL DBG_GTP_RX_ByteIsAligned							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_GTP_RX_CharIsComma								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_GTP_RX_CharIsK										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_GTP_RX_Data											: T_SLVV_8(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_GTP_TX_CharIsK										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_GTP_TX_Data											: T_SLVV_8(PORTS - 1 DOWNTO 0);
		
		SIGNAL DBG_RX_CharIsK												: T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_RX_Data													: T_SLVV_32(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_TX_CharIsK												: T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_TX_Data													: T_SLVV_32(PORTS - 1 DOWNTO 0);
		
		SIGNAL DBG_OOBStatus_COMRESET								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		SIGNAL DBG_OOBStatus_COMWAKE								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
		ATTRIBUTE KEEP OF DBG_ClockTX_1X						: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_ClockTX_4X						: SIGNAL IS TRUE;

		ATTRIBUTE KEEP OF DBG_GTP_RX_ByteIsAligned	: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_GTP_RX_CharIsComma		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_GTP_RX_CharIsK				: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_GTP_RX_Data						: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_GTP_TX_CharIsK				: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_GTP_TX_Data						: SIGNAL IS TRUE;
		
		ATTRIBUTE KEEP OF DBG_RX_CharIsK						: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_RX_Data								: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_TX_CharIsK						: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_TX_Data								: SIGNAL IS TRUE;
	
		ATTRIBUTE KEEP OF DBG_OOBStatus_COMRESET		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_OOBStatus_COMWAKE			: SIGNAL IS TRUE;	
	BEGIN
			loop0: FOR I IN 0 TO PORTS - 1 GENERATE
				DBG_ClockTX_1X(I)						<= GTP_Clock_1X(I);
				DBG_ClockTX_4X(I)						<= GTP_Clock_4X(I);
			
				DBG_GTP_RX_ByteIsAligned(I)	<= GTP_RX_ByteIsAligned(I);
--				DBG_GTP_RX_CharIsComma(I)		<= GTP_RX_CharIsComma(I);
--				DBG_GTP_RX_CharIsK(I)				<= GTP_RX_CharIsK(I);
				DBG_GTP_RX_Data(I)					<= GTP_RX_Data(I)(DBG_GTP_RX_Data(I)'range);
--				DBG_GTP_TX_CharIsK(I)				<= GTP_TX_CharIsK(I);
				DBG_GTP_TX_Data(I)					<= GTP_TX_Data(I)(DBG_GTP_TX_Data(I)'range);
		
--				DBG_RX_CharIsK(I)						<= RX_CharIsK(I);
--				DBG_RX_Data(I)							<= RX_Data(I);
				DBG_TX_CharIsK(I)						<= TX_CharIsK(I);
				DBG_TX_Data(I)							<= TX_Data(I);
			
				DBG_OOBStatus_COMRESET(I)		<= to_sl(RX_OOBStatus_i(I) = SATA_OOB_COMRESET);
				DBG_OOBStatus_COMWAKE(I)		<= to_sl(RX_OOBStatus_i(I) = SATA_OOB_COMWAKE);
			END GENERATE;
	END GENERATE;
	
	
	-- debug port
	-- ==========================================================================================================================================================
--	DebugPortOut(0).RefClock		<= GTP_RefClockOut;
--	DebugPortOut(0).TXOutClock	<= GTP_TX_RefClockOut(0);
--	DebugPortOut(0).RXRecClock	<= GTP_RX_RefClockOut(0);
END;
