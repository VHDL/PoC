LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;
USE			L_SATAController.SATADebug.ALL;
USE			L_SATAController.SATATransceiverTypes.ALL;

ENTITY SATATransceiver_Virtex6_GTXE1 IS
	GENERIC (
		CHIPSCOPE_KEEP						: BOOLEAN											:= TRUE;
		CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																	-- 150 MHz
		PORTS											: POSITIVE										:= 2;																			-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3 => T_SATA_GENERATION'high)			-- intial SATA Generation
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

		DebugPortIn								: IN	T_DBG_TRANSIN_VECTOR(PORTS	- 1 DOWNTO 0);
		DebugPortOut							: OUT T_DBG_TRANSOUT_VECTOR(PORTS	- 1 DOWNTO 0);

		RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_Data										: OUT	T_SLVV_32(PORTS	- 1 DOWNTO 0);
		RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		
		TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_Data										: IN	T_SLVV_32(PORTS	- 1 DOWNTO 0);
		TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
		
		-- Xilinx specific GTXE1 ports
		VSS_Common								: INOUT	T_SATA_TRANSCEIVER_COMMON_SIGNALS;
		VSS_Private								: INOUT	T_SATA_TRANSCEIVER_PRIVATE_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF SATATransceiver_Virtex6_GTXE1 IS
	ATTRIBUTE KEEP 														: BOOLEAN;

-- ==================================================================
-- SATATransceiver configuration
-- ==================================================================
	CONSTANT NO_DEVICE_TIMEOUT_MS							: REAL						:= 50.0;					-- 50 ms
	CONSTANT NEW_DEVICE_TIMEOUT_MS						: REAL						:= 0.001;				-- FIXME: not used -> remove ???

	FUNCTION IsSupportedGeneration(SATAGen : T_SATA_GENERATION) RETURN BOOLEAN IS
	BEGIN
		CASE SATAGen IS
			WHEN SATA_GENERATION_1	=> RETURN TRUE;
			WHEN SATA_GENERATION_2	=> RETURN TRUE;
			WHEN OTHERS	=> 		RETURN FALSE;
		END CASE;
	END;

	SIGNAL ClockIn_75MHz											: STD_LOGIC;
	SIGNAL ClockIn_150MHz											: STD_LOGIC;
	SIGNAL ClockIn_150MHz_BUFR								: STD_LOGIC;
		
	SIGNAL Control_Clock											: STD_LOGIC;
	
	SIGNAL GTXConfig_Reset										: STD_LOGIC;
	SIGNAL GTXConfig_Reconfig									: STD_LOGIC;
	SIGNAL GTXConfig_ReconfigComplete					: STD_LOGIC;
	SIGNAl GTXConfig_ConfigReloaded						: STD_LOGIC;
	SIGNAL GTXConfig_GTX_ReloadConfig					: STD_LOGIC;

	ATTRIBUTE KEEP OF Control_Clock						: SIGNAL IS CHIPSCOPE_KEEP;
BEGIN
-- ==================================================================
-- Assert statements
-- ==================================================================
	ASSERT (VENDOR = VENDOR_XILINX)		REPORT "Vendor not yet supported."				SEVERITY FAILURE;
	ASSERT (DEVFAM = DEVFAM_VIRTEX)		REPORT "Device family not yet supported."	SEVERITY FAILURE;
	ASSERT (DEVICE = DEVICE_VIRTEX6)	REPORT "Device not yet supported."				SEVERITY FAILURE;
	ASSERT (PORTS <= 4)								REPORT "To many ports per Quad."					SEVERITY FAILURE;
		
	genassert : FOR I IN 0 TO PORTS	- 1 GENERATE
		ASSERT 	IsSupportedGeneration(SATA_Generation(I))	REPORT "unsupported SATA generation" SEVERITY FAILURE;
	END GENERATE;

-- ============================================================================
-- mapping of vendor specific ports
-- ============================================================================
	ClockIn_150MHz					<= VSS_Common.RefClockIn_150_MHz;
	ClockIn_75MHz						<= VSS_Common.RefClockIn_75_MHz;

	-- common clocking resources
	BUFR_SATA_RefClockIn : BUFR
		PORT MAP (
			I				=> ClockIn_150MHz,
			CE			=> '1',
			CLR			=> '0',
			O				=> ClockIn_150MHz_BUFR
		);
	
--	ClkNet : ENTITY L_SATAController.SATATransceiver_Virtex6_ClockNetwork
--		GENERIC MAP (
--			CLOCK_IN_FREQ_MHZ						=> CLOCK_IN_FREQ_MHZ,																		-- 150 MHz
--			PORTS												=> PORTS
--		)
--		PORT MAP (
--			ClockIn_150MHz							=> ClockIn_150MHz_BUFR,
--
--			ClockNetwork_Reset					=> ClkNet_Reset,
--			ClockNetwork_ResetDone			=> ClkNet_ResetDone,
--			
--			SATA_Generation							=> SATA_Generation,
--			
--			GTX_Clock_2X								=> GTX_Clock_2X,
--			GTX_Clock_4X								=> GTX_Clock_4X
--		);

	
	Control_Clock				<= ClockIn_150MHz_BUFR;					-- stable clock for reset control and device detection logics
--	SATA_Clock					<= GTX_Clock_4X;

-- ==================================================================
-- data path buffers
-- ==================================================================
	genGTXE1 : FOR I IN 0 TO (PORTS	- 1) GENERATE
		SIGNAL TX_OOBCommand_d										: T_SATA_OOB;			--						:= OOB_NONE;
		SIGNAL RX_OOBStatus_i											: T_SATA_OOB;
		SIGNAL RX_OOBStatus_d											: T_SATA_OOB;			--						:= OOB_NONE;
		
		SIGNAL ClkNet_Reset												: STD_LOGIC;
		SIGNAL ClkNet_ResetDone										: STD_LOGIC;
		SIGNAL ClockNetwork_ResetDone_i						: STD_LOGIC;
		
		SIGNAL GTX_TX_RefClockIn									: STD_LOGIC;
		SIGNAL GTX_RX_RefClockIn									: STD_LOGIC;
		SIGNAL GTX_RefClockOut										: STD_LOGIC;
		
		SIGNAL GTX_FABClockOut										: STD_LOGIC_VECTOR(1 DOWNTO 0);
		SIGNAL GTX_TX_RefClockOut									: STD_LOGIC;
		SIGNAL GTX_TX_PCSClockOut									: STD_LOGIC;
		SIGNAL GTX_RX_RefClockOut									: STD_LOGIC;
		SIGNAL GTX_RX_PCSClockOut									: STD_LOGIC;
		
		SIGNAL GTX_Clock_2X												: STD_LOGIC;
		SIGNAL GTX_Clock_4X												: STD_LOGIC;
		
		SIGNAL GTX_ResetDone											: STD_LOGIC;
		
		SIGNAL GTX_TX_Reset												: STD_LOGIC;
		SIGNAL GTX_TX_ResetDone										: STD_LOGIC;
		
		SIGNAL GTX_RX_Reset												: STD_LOGIC;
		SIGNAL GTX_RX_ResetDone										: STD_LOGIC;
		
		SIGNAL GTX_PLL_Reset											: STD_LOGIC;
		SIGNAL GTX_PLL_Reset_r										:	STD_LOGIC																:= '0';
		SIGNAL GTX_PLL_ResetDone_i								:	STD_LOGIC;
		SIGNAL GTX_PLL_ResetDone_d								:	STD_LOGIC																:= '0';
		SIGNAL GTX_PLL_ResetDone_d2								:	STD_LOGIC																:= '0';
		SIGNAL GTX_PLL_ResetDone									:	STD_LOGIC;
		
		SIGNAL GTX_TXPLL_Reset										:	STD_LOGIC;
		SIGNAL GTX_TXPLL_ResetDone								:	STD_LOGIC;
		SIGNAL GTX_RXPLL_Reset										:	STD_LOGIC;
		SIGNAL GTX_RXPLL_ResetDone								:	STD_LOGIC;
		
		SIGNAL GTX_TX_LineRate										: T_SLV_2																	:= "00";
		SIGNAL GTX_TX_LineRate_Changed						: STD_LOGIC;
		SIGNAL GTX_TX_LineRate_Locked							: STD_LOGIC																:= '0';
		SIGNAL GTX_RX_LineRate										: T_SLV_2																	:= "00";
		SIGNAL GTX_RX_LineRate_Changed						: STD_LOGIC;
		SIGNAL GTX_RX_LineRate_Locked							: STD_LOGIC																:= '0';
		SIGNAL GTX_LineRate_Locked								: STD_LOGIC;
		
		SIGNAL GTX_TX_ElectricalIDLE							: STD_LOGIC																:= '0';
		SIGNAL GTX_TX_ComInit											: STD_LOGIC																:= '0';
		SIGNAL GTX_TX_ComWake											: STD_LOGIC																:= '0';
		SIGNAL GTX_TX_OOBComplete									: STD_LOGIC;

		SIGNAL GTX_TX_InvalidK										: T_SLV_4;
		SIGNAL GTX_TX_BufferStatus								: T_SLV_2;

		SIGNAL GTX_RX_ElectricalIDLE_i						: STD_LOGIC;
		SIGNAL GTX_RX_ElectricalIDLE_d						: STD_LOGIC																:= '0';
		SIGNAL GTX_RX_ElectricalIDLE_d2						: STD_LOGIC																:= '0';
		SIGNAL GTX_RX_ElectricalIDLE							: STD_LOGIC;
		SIGNAL GTX_RX_ComInit											: STD_LOGIC;
		SIGNAL GTX_RX_ComWake											: STD_LOGIC;
		
		SIGNAL GTX_RX_Status											: T_SLV_3;
		SIGNAl GTX_RX_DisparityError							: T_SLV_4;
		SIGNAl GTX_RX_Illegal8B10BCode						: T_SLV_4;
		SIGNAL GTX_RX_LossOfSync									: T_SLV_2;																-- unused
		SIGNAL GTX_RX_BufferStatus								: T_SLV_3;
		
		SIGNAL GTX_RX_Data												: T_SLV_32;
		SIGNAL GTX_RX_CommaDetected								: STD_LOGIC;															-- unused
		SIGNAL GTX_RX_CharIsComma									: T_SLV_4;																-- unused
		SIGNAL GTX_RX_CharIsK											: T_SLV_4;
		SIGNAL GTX_RX_ByteIsAligned								: STD_LOGIC;
		SIGNAL GTX_RX_ByteRealign									: STD_LOGIC;															-- unused
		SIGNAL GTX_RX_Valid												: STD_LOGIC;															-- unused
			
		SIGNAL GTX_TX_Data												: T_SLV_32;
		SIGNAL GTX_TX_CharIsK											: T_SLV_4;
		
		SIGNAL GTX_TX_n														: STD_LOGIC;
		SIGNAL GTX_TX_p														: STD_LOGIC;
		SIGNAL GTX_RX_n														: STD_LOGIC;
		SIGNAL GTX_RX_p														: STD_LOGIC;
		
		SIGNAL DD_NoDevice_i											: STD_LOGIC;
		SIGNAL DD_NoDevice												: STD_LOGIC;
		SIGNAL DD_NewDevice_i											: STD_LOGIC;
		SIGNAL DD_NewDevice												: STD_LOGIC;
		
		SIGNAL TX_Error_i													: T_SATA_TRANSCEIVER_TX_ERROR;
		SIGNAL RX_Error_i													: T_SATA_TRANSCEIVER_RX_ERROR;
		
		SIGNAL WA_Align														: T_SLV_2;
		
		-- keep internal clock nets, so timing constrains from UCF can find them
		ATTRIBUTE KEEP OF GTX_Clock_2X						: SIGNAL IS CHIPSCOPE_KEEP;
		ATTRIBUTE KEEP OF GTX_Clock_4X						: SIGNAL IS CHIPSCOPE_KEEP;
		
	BEGIN
		-- TX path
		GTX_TX_Data							<= TX_Data(I);
		GTX_TX_CharIsK					<= TX_CharIsK(I);

		-- RX path
		WA_Align(0)							<= slv_or(GTX_RX_CharIsK(1 DOWNTO 0));
		WA_Align(1)							<= slv_or(GTX_RX_CharIsK(3 DOWNTO 2));
		
		WA_Data : ENTITY L_Global.WordAligner
			GENERIC MAP (
				REGISTERED					=> FALSE,
				INPUT_BITS						=> 32,
				WORD_BITS							=> 16
			)
			PORT MAP (
				Clock								=> GTX_Clock_4X,
				Align								=> WA_Align,
				I										=> GTX_RX_Data,
				O										=> RX_Data(I),
				Valid								=> OPEN
			);

		WA_CharIsK : ENTITY L_Global.WordAligner
			GENERIC MAP (
				REGISTERED					=> FALSE,
				INPUT_BITS						=> 4,
				WORD_BITS							=> 2
			)
			PORT MAP (
				Clock								=> GTX_Clock_4X,
				Align								=> WA_Align,
				I										=> GTX_RX_CharIsK,
				O										=> RX_CharIsK(I),
				Valid								=> OPEN
			);
		
		RX_IsAligned(I)					<= GTX_RX_ByteIsAligned;


		-- ==================================================================
		-- ResetControl
		-- ==================================================================
		blkReset : BLOCK
			SIGNAL GTX_PLL_Reset											: STD_LOGIC;
			SIGNAL GTX_PLL_Reset_r1										: STD_LOGIC																:= '0';
			SIGNAL GTX_PLL_Reset_r2										: STD_LOGIC																:= '0';
			
			SIGNAL GTX_PLL_ResetDone_i								: STD_LOGIC;
			SIGNAL GTX_PLL_ResetDone_d1								: STD_LOGIC																:= '0';
			SIGNAL GTX_PLL_ResetDone_d2								: STD_LOGIC																:= '0';
			SIGNAL GTX_PLL_ResetDone									: STD_LOGIC;
			
			SIGNAL ClockNetwork_ResetDone_d1					: STD_LOGIC																:= '0';					
			SIGNAL ClockNetwork_ResetDone_d2					: STD_LOGIC																:= '0';
			
			SIGNAL GTX_Port_Reset											: STD_LOGIC;
		BEGIN
			-- clock related reset generation
			-- ======================================================================
			-- clock network resets
			ClkNet_Reset							<= ClockNetwork_Reset(I);																			-- @async
			GTX_PLL_Reset							<= ClockNetwork_Reset(I);																			-- @async

			-- D-FF @Control_Clock with async reset
			PROCESS(Control_Clock)
			BEGIN
				IF ((GTX_PLL_Reset_r2 = '1') AND (GTX_PLL_ResetDone = '0')) THEN
					GTX_PLL_Reset_r1			<= '0';
					GTX_PLL_Reset_r2			<= '0';
				ELSE
					IF rising_edge(Control_Clock) THEN
						GTX_PLL_Reset_r1		<= GTX_PLL_Reset;
						GTX_PLL_Reset_r2		<= GTX_PLL_Reset_r1;
					END IF;
				END IF;
			END PROCESS;

			-- assign signals
			GTX_TXPLL_Reset								<= GTX_PLL_Reset_r2;																			-- @Control_Clock
			GTX_RXPLL_Reset								<= GTX_PLL_Reset_r2;																			-- @Control_Clock

			-- clock related resetdone evaluation
			-- ======================================================================
			-- combine TX and RX PLLs
			GTX_PLL_ResetDone_i						<= GTX_TXPLL_ResetDone AND GTX_RXPLL_ResetDone;						-- @async
			
			-- synchronize signal
			GTX_PLL_ResetDone_d1					<= GTX_PLL_ResetDone_i	WHEN rising_edge(Control_Clock);
			GTX_PLL_ResetDone_d2					<= GTX_PLL_ResetDone_d1	WHEN rising_edge(Control_Clock);
			GTX_PLL_ResetDone							<= GTX_PLL_ResetDone_d2;
			
			-- combine all clock related resetdone signals
			ClockNetwork_ResetDone_i			<= GTX_PLL_ResetDone AND ClkNet_ResetDone;								-- @Control_Clock: is high, if all clocknetwork components are stable
			ClockNetwork_ResetDone(I)			<= ClockNetwork_ResetDone_i;
			
	--		GTX_RX_LineRate_Changed_d			<= GTX_RX_LineRate_Changed	WHEN rising_edge(Control_Clock);
				
			-- logic related reset generation
			-- ======================================================================
			GTX_Port_Reset								<= to_sl(Command(I) = SATA_TRANSCEIVER_CMD_RESET);				-- @GTX_Clock_4X
			
			GTX_TX_Reset									<= GTX_Port_Reset;																				-- @GTX_Clock_4X
			GTX_RX_Reset									<= GTX_Port_Reset;																				-- @GTX_Clock_4X
			
			-- logic related resetdone evaluation
			-- ======================================================================
			GTX_ResetDone									<= GTX_TX_ResetDone AND GTX_RX_ResetDone;									-- @GTX_Clock_4X
			
			ClockNetwork_ResetDone_d1			<= ClockNetwork_ResetDone_i		WHEN rising_edge(GTX_Clock_4X);
			ClockNetwork_ResetDone_d2			<= ClockNetwork_ResetDone_d1	WHEN rising_edge(GTX_Clock_4X);
			
			ResetDone(I)									<= GTX_ResetDone AND ClockNetwork_ResetDone_d2;						-- @GTX_Clock_4X: gate output with clocknetwork resetdone to ensure a delayed release of signal
		END BLOCK;
		
		-- ==================================================================
		-- ClockNetwork (75, 150 MHz)
		-- ==================================================================
		GTX_TX_RefClockIn							<= ClockIn_150MHz;
		GTX_RX_RefClockIn							<= ClockIn_150MHz;
		GTX_RefClockOut								<= GTX_FABClockOut(0);			-- GTX_TX_RefClockOut;				-- GTX_FABClockOut(0) -> TX, GTX_FABClockOut(1) -> RX

		ClkNet : ENTITY L_SATAController.SATATransceiver_Virtex6_ClockNetwork
			GENERIC MAP (
				CLOCK_IN_FREQ_MHZ						=> CLOCK_IN_FREQ_MHZ																		-- 150 MHz
--				PORTS												=> PORTS
			)
			PORT MAP (
				ClockIn_150MHz							=> GTX_RefClockOut,		-- Control_Clock,

				ClockNetwork_Reset					=> ClkNet_Reset,
				ClockNetwork_ResetDone			=> ClkNet_ResetDone,
				
				SATA_Generation							=> SATA_Generation(I),
				
				GTX_Clock_2X								=> GTX_Clock_2X,
				GTX_Clock_4X								=> GTX_Clock_4X
			);

		SATA_Clock(I)									<= GTX_Clock_4X;

		-- ==================================================================
		-- OOB signaling
		-- ==================================================================
		TX_OOBCommand_d								<= TX_OOBCommand(I)	WHEN rising_edge(GTX_Clock_4X);

		-- TX OOB signals (generate GTX specific OOB signals)
		-- multiple SR-FFs for
		--	GTX_TX_ElectricalIDLE		.set = OOBCommand /= NONE			.rst = GTX_TX_OOBComplete
		--	GTX_TX_ComInit					.set = OOBCommand = COMINIT		.rst = (OOBCommand = COMWAKE)	or GTX_TX_OOBComplete
		--	GTX_TX_ComWake					.set = OOBCommand = COMWAKE		.rst = (OOBCommand = COMINIT)	or GTX_TX_OOBComplete
		PROCESS(GTX_Clock_4X)
		BEGIN
			IF rising_edge(GTX_Clock_4X) THEN
				CASE TX_OOBCommand_d IS
					WHEN SATA_OOB_NONE =>
						NULL;

					WHEN SATA_OOB_READY =>
--						GTX_TX_ElectricalIDLE		<= '1';
						NULL;
						
					WHEN SATA_OOB_COMRESET =>
						GTX_TX_ElectricalIDLE		<= '1';
					
					WHEN SATA_OOB_COMWAKE =>
						GTX_TX_ElectricalIDLE		<= '1';
				END CASE;
				
				IF (GTX_TX_OOBComplete = '1') THEN
					GTX_TX_ElectricalIDLE			<= '0';
				END IF;
			END IF;
		END PROCESS;
		
		PROCESS(TX_OOBCommand_d)
		BEGIN
			CASE TX_OOBCommand_d IS
				WHEN SATA_OOB_NONE =>
					GTX_TX_ComInit					<= '0';
					GTX_TX_ComWake					<= '0';

				WHEN SATA_OOB_READY =>
--					GTX_TX_ComInit					<= '0';
--					GTX_TX_ComWake					<= '0';
					
				WHEN SATA_OOB_COMRESET =>
					GTX_TX_ComInit					<= '1';
					GTX_TX_ComWake					<= '0';
				
				WHEN SATA_OOB_COMWAKE =>
					GTX_TX_ComInit					<= '0';
					GTX_TX_ComWake					<= '1';
			END CASE;
		END PROCESS;

--		PROCESS(GTX_Clock_4X)
--		BEGIN
--			IF rising_edge(GTX_Clock_4X) THEN
--				CASE TX_OOBCommand_d IS
--					WHEN SATA_OOB_NONE =>
--						NULL;
--
--					WHEN SATA_OOB_READY =>
----						GTX_TX_ElectricalIDLE		<= '1';
--						GTX_TX_ComInit					<= '0';
--						GTX_TX_ComWake					<= '0';
--						
--					WHEN SATA_OOB_COMRESET =>
--						GTX_TX_ElectricalIDLE		<= '1';
--						GTX_TX_ComInit					<= '1';
--						GTX_TX_ComWake					<= '0';
--					
--					WHEN SATA_OOB_COMWAKE =>
--						GTX_TX_ElectricalIDLE		<= '1';
--						GTX_TX_ComInit					<= '0';
--						GTX_TX_ComWake					<= '1';
--				END CASE;
--				
--				IF (GTX_TX_OOBComplete = '1') THEN
--					GTX_TX_ElectricalIDLE			<= '0';
--					GTX_TX_ComInit						<= '0';
--					GTX_TX_ComWake						<= '0';
--				END IF;
--			END IF;
--		END PROCESS;
		
		-- TX OOB sequence is complete
		TX_OOBComplete(I)					<= GTX_TX_OOBComplete;

		-- RX OOB signals
		GTX_RX_ElectricalIDLE_d 	<= GTX_RX_ElectricalIDLE_i	WHEN rising_edge(GTX_Clock_4X);
		GTX_RX_ElectricalIDLE_d2	<= GTX_RX_ElectricalIDLE_d	WHEN rising_edge(GTX_Clock_4X);
		GTX_RX_ElectricalIDLE			<= GTX_RX_ElectricalIDLE_d2;																		-- @GTX_Clock_4X
		
		
		-- RX OOB signals (generate generic RX OOB status signals)
		PROCESS(GTX_RX_ComInit, GTX_RX_ComWake, GTX_RX_ElectricalIDLE)
		BEGIN
			RX_OOBStatus_i		 				<= SATA_OOB_NONE;
		
			IF (GTX_RX_ElectricalIDLE = '1') THEN
				RX_OOBStatus_i					<= SATA_OOB_READY;
			
				IF (GTX_RX_ComInit = '1') THEN
					RX_OOBStatus_i				<= SATA_OOB_COMRESET;
				ELSIF (GTX_RX_ComWake = '1') THEN
					RX_OOBStatus_i				<= SATA_OOB_COMWAKE;
				END IF;
			END IF;
		END PROCESS;

		RX_OOBStatus_d		<= RX_OOBStatus_i	WHEN rising_edge(GTX_Clock_4X);
		RX_OOBStatus(I)		<= RX_OOBStatus_d;

		-- ==================================================================
		-- error handling
		-- ==================================================================
		-- TX errors
		PROCESS(GTX_TX_InvalidK, GTX_TX_BufferStatus(1))
		BEGIN
			TX_Error_i		<= SATA_TRANSCEIVER_TX_ERROR_NONE;
		
			IF (slv_or(GTX_TX_InvalidK) = '1') THEN
				TX_Error_i	<= SATA_TRANSCEIVER_TX_ERROR_ENCODER;
			ELSIF (GTX_TX_BufferStatus(1) = '1') THEN
				TX_Error_i	<= SATA_TRANSCEIVER_TX_ERROR_BUFFER;
			END IF;
		END PROCESS;
		
		-- RX errors
		PROCESS(GTX_RX_ByteIsAligned, GTX_RX_DisparityError, GTX_RX_Illegal8B10BCode, GTX_RX_BufferStatus(2))
		BEGIN
			RX_Error_i		<= SATA_TRANSCEIVER_RX_ERROR_NONE;
		
			IF (GTX_RX_ByteIsAligned = '0') THEN
				RX_Error_i	<= SATA_TRANSCEIVER_RX_ERROR_ALIGNEMENT;
			ELSIF (slv_or(GTX_RX_DisparityError) = '1') THEN
				RX_Error_i	<= SATA_TRANSCEIVER_RX_ERROR_DISPARITY;
			ELSIF (slv_or(GTX_RX_Illegal8B10BCode) = '1') THEN
				RX_Error_i	<= SATA_TRANSCEIVER_RX_ERROR_DECODER;
			ELSIF (GTX_RX_BufferStatus(2) = '1') THEN
				RX_Error_i	<= SATA_TRANSCEIVER_RX_ERROR_BUFFER;
			END IF;
		END PROCESS;

		TX_Error(I)										<= TX_Error_i;
		RX_Error(I)										<= RX_Error_i;

		-- ==================================================================
		-- Transceiver status
		-- ==================================================================
		-- device detection
		DD : ENTITY L_SATAController.DeviceDetector
			GENERIC MAP (
				CLOCK_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,						-- 150 MHz
				NO_DEVICE_TIMEOUT_MS		=> NO_DEVICE_TIMEOUT_MS,				-- 1,0 ms
				NEW_DEVICE_TIMEOUT_MS		=> NEW_DEVICE_TIMEOUT_MS				-- 1,0 us
			)
			PORT MAP (
				Clock										=> Control_Clock,
				ElectricalIDLE					=> GTX_RX_ElectricalIDLE_i,			-- @async
				
				NoDevice								=> DD_NoDevice_i,								-- @Control_Clock
				NewDevice								=> DD_NewDevice_i								-- @Control_Clock
			);

		blkSync1 : BLOCK
			SIGNAL NoDevice_sy1				: STD_LOGIC									:= '0';
			SIGNAL NoDevice_sy2				: STD_LOGIC									:= '0';
		BEGIN
			NoDevice_sy1						<= DD_NoDevice_i	WHEN rising_edge(GTX_Clock_4X);
			NoDevice_sy2						<= NoDevice_sy1		WHEN rising_edge(GTX_Clock_4X);
			DD_NoDevice							<= NoDevice_sy2;
		END BLOCK;

		Sync1 : ENTITY L_Global.Synchronizer
			GENERIC MAP (
				BW											=> 1,														-- number of bit to be synchronized
				GATED_INPUT_BY_BUSY			=> TRUE													-- use gated input (by busy signal)
			)
			PORT MAP (
				Clock1									=> Control_Clock,								-- input clock domain
				Clock2									=> GTX_Clock_4X,							-- output clock domain
				I(0)										=> DD_NewDevice_i,							-- input bits
				O(0)										=> DD_NewDevice,								-- output bits
				B												=> OPEN													-- busy bits
			);
		
		PROCESS(GTX_ResetDone, DD_NoDevice, DD_NewDevice, TX_Error_i, RX_Error_i)
		BEGIN
			Status(I) 							<= SATA_TRANSCEIVER_STATUS_IDLE;
			
			IF (GTX_ResetDone = '0') THEN
				Status(I)							<= SATA_TRANSCEIVER_STATUS_RESETING;
			ELSIF (DD_NoDevice = '1') THEN
				Status(I)							<= SATA_TRANSCEIVER_STATUS_NO_DEVICE;
			ELSIF ((TX_Error_i /= SATA_TRANSCEIVER_TX_ERROR_NONE) OR (RX_Error_i /= SATA_TRANSCEIVER_RX_ERROR_NONE)) THEN
				Status(I)							<= SATA_TRANSCEIVER_STATUS_ERROR;
			ELSIF (DD_NewDevice = '1') THEN
				Status(I)							<= SATA_TRANSCEIVER_STATUS_NEW_DEVICE;
				
-- TODO:
-- TRANS_STATUS_POWERED_DOWN,
-- TRANS_STATUS_CONFIGURATION,

			END IF;
		END PROCESS;
	
-- ==================================================================
-- LineRate control
-- ==================================================================
--		PROCESS(GTX_Clock_4X)
--		BEGIN
--			IF rising_edge(GTX_Clock_4X) THEN
--				IF (RP_Reconfig(I) = '1') THEN
--					IF (SATA_Generation(I) = SATA_GENERATION_1) THEN
--						GTX_TX_LineRate		<= "10";								-- TXPLL Divider (D) = 2
--						GTX_RX_LineRate		<= "10";								-- rXPLL Divider (D) = 2
--					ELSIF (SATA_Generation(I) = SATA_GENERATION_2) THEN
--						GTX_TX_LineRate		<= "11";								-- TXPLL Divider (D) = 1
--						GTX_RX_LineRate		<= "11";								-- rXPLL Divider (D) = 1
--					ELSE
--						NULL;
--					END IF;
--				END IF;
--			END IF;
--		END PROCESS;
		
		GTX_TX_LineRate		<= "00";								-- TXPLL Divider => use generic
		GTX_RX_LineRate		<= "00";								-- rXPLL Divider => use generic

		RP_Locked(I)									<= '0';																											-- all ports are independant => never set a lock
		RP_ReconfigComplete(I)				<= RP_Reconfig(I) WHEN rising_edge(GTX_Clock_4X);						-- acknoledge reconfiguration with 1 cycle latency

		-- SR-FF for GTX_*_LineRate_Locked:
		--		.set	= GTX_*_LineRate_Changed
		--		.rst	= RP_Reconfig(I)
		PROCESS(GTX_Clock_4X)
		BEGIN
			IF rising_edge(GTX_Clock_4X) THEN
				IF (RP_Reconfig(I) = '1') THEN
					GTX_TX_LineRate_Locked		<= '0';
					GTX_RX_LineRate_Locked		<= '0';
				ELSE
					IF (GTX_TX_LineRate_Changed = '1') THEN
						GTX_TX_LineRate_Locked	<= '1';
					END IF;
					IF (GTX_RX_LineRate_Changed = '1') THEN
						GTX_RX_LineRate_Locked	<= '1';
					END IF;
				END IF;
			END IF;
		END PROCESS;
		
		GTX_LineRate_Locked						<= GTX_TX_LineRate_Locked AND GTX_RX_LineRate_Locked;
		RP_ConfigReloaded(I)					<= GTX_LineRate_Locked AND ClockNetwork_ResetDone_i;

-- ==================================================================
-- GTXE1 - instance for Port I
-- ==================================================================
		GTX : GTXE1
			GENERIC MAP (
				-- ===================== Simulation-Only Attributes ===================
				SIM_RECEIVER_DETECT_PASS								=> TRUE,
				SIM_GTXRESET_SPEEDUP										=> 1,																			-- set to 1 to speed up simulation reset
				SIM_TX_ELEC_IDLE_LEVEL									=> "X",
				SIM_VERSION															=> "2.0",
				SIM_TXREFCLK_SOURCE											=> "001",																	-- must be same value as TXPLLREFSELDY
				SIM_RXREFCLK_SOURCE											=> "001",																	-- must be same value as RXPLLREFSELDY

				-- Power Saving
				
				POWER_SAVE															=> "0000110000",

				-- unknown
				TXPLL_COM_CFG														=> x"21680a",
				RXPLL_COM_CFG														=> x"21680a",
				
				TXPLL_CP_CFG														=> x"0D",
				RXPLL_CP_CFG														=> x"0D",
				
				TXPLL_LKDET_CFG													=> "111",
				RXPLL_LKDET_CFG													=> "111",
				
				TXPLL_SATA															=> "01",

				TXOUTCLK_DLY														=> "0000000000",
				TX_USRCLK_CFG														=> x"00",

				TX_TDCC_CFG															=> "11",
			
				RXRECCLK_DLY														=> "0000000000",
				RXUSRCLK_DLY														=> x"0000",
				
				-- clock multiplexer
				-- ====================================================================
				PMA_CAS_CLK_EN													=> FALSE,																	-- disable CAS_CLK
				
				TX_CLK_SOURCE														=> "TXPLL",																-- TX and RX have same linerate => use only RXPLL => powerdown TXPLL
				TXOUTCLK_CTRL														=> "TXOUTCLKPCS",													-- TXOUTCLK is TXOUTCLKPCS
				RXRECCLK_CTRL														=> "RXRECCLKPCS",													-- 

				-- linerate clock divider
				TXPLL_DIVSEL_OUT												=> 1,																			-- TXPLL linerate divider (D)
				RXPLL_DIVSEL_OUT												=> 1,																			-- RXPLL linerate divider (D)

				-- parallel word clock divider
				TXPLL_DIVSEL_REF												=> 1,																			-- TXPLL multiplier (M)
				TXPLL_DIVSEL_FB													=> 2,																			-- TXPLL divider (N2)
				TXPLL_DIVSEL45_FB												=> 5,																			-- TXPLL divider (N1); 5 => 10 Bit symbols	
				
				RXPLL_DIVSEL_REF												=> 1,																			-- RXPLL multiplier (M)
				RXPLL_DIVSEL_FB													=> 2,																			-- RXPLL divider (N2)
				RXPLL_DIVSEL45_FB												=> 5,																			-- RXPLL divider (N1); 5 => 10 Bit symbols

				-- oversampling
				-- ====================================================================
				TX_OVERSAMPLE_MODE											=> FALSE,
				RX_OVERSAMPLE_MODE											=> FALSE,

				-- generate user clock
				-- ====================================================================
				GEN_TXUSRCLK														=> FALSE,
				GEN_RXUSRCLK														=> FALSE,

				-- parallel clock domain source (XCLK)
				-- ====================================================================
				RX_XCLK_SEL															=> "RXREC",																-- use recovered clock from CDR to drive PMA parallel circuits (elastic buffer usage => value MUST be "RXREC"
				TX_XCLK_SEL															=> "TXOUT",																-- enabled TX buffer requires TXOUT els TXUSR

				-- Datawidth
				-- ====================================================================
				TX_DATA_WIDTH														=> 40,
				RX_DATA_WIDTH														=> 40,

				-- buffers
				-- ====================================================================
				TX_BUFFER_USE														=> TRUE,
				RX_BUFFER_USE														=> TRUE,

				-- rx buffer reset behavior
				-- ====================================================================
				RX_EN_IDLE_RESET_BUF										=> TRUE,
				RX_EN_MODE_RESET_BUF										=> TRUE,
				RX_EN_RATE_RESET_BUF										=> TRUE,
				RX_EN_REALIGN_RESET_BUF									=> FALSE,
				RX_EN_REALIGN_RESET_BUF2								=> FALSE,

				-- OOB timing settings
				-- ====================================================================
				-- clock divider for OOB signaling circuits
				TX_CLK25_DIVIDER												=> 6,																			-- RefClockIn @150 MHz => divider = 6 => 25 MHz
				RX_CLK25_DIVIDER												=> 6,																			-- RefClockIn @150 MHz => divider = 6 => 25 MHz
				
				-- tx OOB
				COM_BURST_VAL														=> "0110",																-- 
				
				-- for SATA																																				-- OOB COM*** signal detector @ 25 MHz with DDR (20 ns)
				SATA_BURST_VAL													=> "100",																	-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL														=> "011",																	-- IDLE count between bursts in OOB COM*** signals
				SATA_MIN_BURST													=> 4,																			-- 80 ns				SATA Spec Rev 1.1		55 ns
				SATA_MAX_BURST													=> 7,																			-- 140 ns				SATA Spec Rev 1.1		175 ns
				SATA_MIN_INIT														=> 12,																		-- 240 ns				SATA Spec Rev 1.1		175 ns
				SATA_MAX_INIT														=> 22,																		-- 440 ns				SATA Spec Rev 1.1		525 ns
				SATA_MIN_WAKE														=> 4,																			-- 80 ns				SATA Spec Rev 1.1		55 ns
				SATA_MAX_WAKE														=> 7,																			-- 140 ns				SATA Spec Rev 1.1		175 ns

				-- for SAS
				SAS_MIN_COMSAS													=> 40,																		-- 
				SAS_MAX_COMSAS													=> 52,																		-- 
				
				-- for PCI Express
				PCI_EXPRESS_MODE												=> FALSE,																	-- 

				TRANS_TIME_FROM_P2											=> x"03c",																-- 
				TRANS_TIME_NON_P2												=> x"19",																	-- 
				TRANS_TIME_RATE													=> x"ff",																	-- 
				TRANS_TIME_TO_P2												=> x"064",																-- 

				-- =================== TX Buffering and Phase Alignment ===============
				TX_PMADATA_OPT													=> '0',																		-- 0 => TX Buffer is used
				PMA_TX_CFG															=> x"80082",

				TX_BYTECLK_CFG													=> x"00",
				TX_EN_RATE_RESET_BUF										=> TRUE,
				TX_DLYALIGN_CTRINC											=> "0100",
				TX_DLYALIGN_LPFINC											=> "0110",
				TX_DLYALIGN_MONSEL											=> "000",
				TX_DLYALIGN_OVRDSETTING									=> "10000000",

				-- =========================== TX Gearbox =============================
				TXGEARBOX_USE														=> FALSE,
				GEARBOX_ENDEC														=> "000",

				-- ================== TX Driver and OOB Signalling ====================
				TX_DRIVE_MODE														=> "DIRECT",
				TX_IDLE_ASSERT_DELAY										=> "100",
				TX_IDLE_DEASSERT_DELAY									=> "010",
				TXDRIVE_LOOPBACK_HIZ										=> FALSE,
				TXDRIVE_LOOPBACK_PD											=> FALSE,

				-- =================== TX Attributes for PCI Express ==================
				TX_DEEMPH_0															=> "11010",
				TX_DEEMPH_1															=> "10000",
				TX_MARGIN_LOW_0													=> "1000110",
				TX_MARGIN_LOW_1													=> "1000100",
				TX_MARGIN_LOW_2													=> "1000010",
				TX_MARGIN_LOW_3													=> "1000000",
				TX_MARGIN_LOW_4													=> "1000000",
				TX_MARGIN_FULL_0												=> "1001110",
				TX_MARGIN_FULL_1												=> "1001001",
				TX_MARGIN_FULL_2												=> "1000101",
				TX_MARGIN_FULL_3												=> "1000010",
				TX_MARGIN_FULL_4												=> "1000000",

				-- ========== RX Driver, OOB signalling, Coupling and Eq., CDR ===========
				AC_CAP_DIS															=> FALSE,		-- TRUE,
				CDR_PH_ADJ_TIME													=> "10100",
				OOBDETECT_THRESHOLD											=> "111",
				PMA_CDR_SCAN														=> x"640404C",
				PMA_RX_CFG															=> x"05ce049",
				RCV_TERM_GND														=> FALSE,
				RCV_TERM_VTTRX													=> TRUE,
				RX_EN_IDLE_HOLD_CDR											=> FALSE,
				RX_EN_IDLE_RESET_FR											=> TRUE,
				RX_EN_IDLE_RESET_PH											=> TRUE,
				TX_DETECT_RX_CFG												=> x"1832",
				TERMINATION_CTRL												=> "00000",
				TERMINATION_OVRD												=> FALSE,
				CM_TRIM																	=> "01",
				PMA_RXSYNC_CFG													=> x"00",
				PMA_CFG																	=> x"0040000040000000003",
				BGTEST_CFG															=> "00",
				BIAS_CFG																=> x"00000",

				-- =============== RX Decision Feedback Equalizer(DFE) ================
				RX_EN_IDLE_HOLD_DFE											=> TRUE,
				RX_EYE_OFFSET														=> x"4C",
				RX_EYE_SCANMODE													=> "00",
				DFE_CAL_TIME														=> "01100",
				DFE_CFG																	=> "00011011",

				-- ========================= PRBS Detection ===========================
				RXPRBSERR_LOOPBACK											=> '0',

				-- ================= Comma Detection and Alignment ====================
				ALIGN_COMMA_WORD												=> 2,

				DEC_MCOMMA_DETECT												=> TRUE,
				DEC_PCOMMA_DETECT												=> TRUE,
				DEC_VALID_COMMA_ONLY										=> FALSE,

				COMMA_DOUBLE														=> FALSE,				
				COMMA_10B_ENABLE												=> "1111111111",
				MCOMMA_DETECT														=> TRUE,
				MCOMMA_10B_VALUE												=> "1010000011",
				PCOMMA_DETECT														=> TRUE,
				PCOMMA_10B_VALUE												=> "0101111100",
				RX_DECODE_SEQ_MATCH											=> TRUE,
				RX_SLIDE_MODE														=> "OFF",				
				RX_SLIDE_AUTO_WAIT											=> 5,
				SHOW_REALIGN_COMMA											=> FALSE,

				-- =================== RX Loss-of-sync State Machine ==================
				RX_LOSS_OF_SYNC_FSM											=> FALSE,
				RX_LOS_INVALID_INCR											=> 8,
				RX_LOS_THRESHOLD												=> 128,

				-- =========================== RX Gearbox =============================
				RXGEARBOX_USE														=> FALSE,

				-- =============== RX Elastic Buffer and Phase alignment ==============
				RX_FIFO_ADDR_MODE												=> "FULL",
				RX_IDLE_HI_CNT													=> "1000",
				RX_IDLE_LO_CNT													=> "0000",
				RX_DLYALIGN_CTRINC											=> "1110",
				RX_DLYALIGN_EDGESET											=> "00010",
				RX_DLYALIGN_LPFINC											=> "1110",
				RX_DLYALIGN_MONSEL											=> "000",
				RX_DLYALIGN_OVRDSETTING									=> "10000000",

				-- clock correction
				CLK_CORRECT_USE													=> TRUE,
				
				CLK_COR_ADJ_LEN													=> 4,
				CLK_COR_DET_LEN													=> 4,
				CLK_COR_INSERT_IDLE_FLAG								=> FALSE,
				CLK_COR_KEEP_IDLE												=> FALSE,
				CLK_COR_MIN_LAT													=> 16,
				CLK_COR_MAX_LAT													=> 22,
				CLK_COR_PRECEDENCE											=> TRUE,
				CLK_COR_REPEAT_WAIT											=> 0,

				CLK_COR_SEQ_1_ENABLE										=> "1111",
				CLK_COR_SEQ_1_1													=> "0110111100",						-- K28.5
				CLK_COR_SEQ_1_2													=> "0001001010",						-- D
				CLK_COR_SEQ_1_3													=> "0001001010",						-- D
				CLK_COR_SEQ_1_4													=> "0001111011",						-- D

				CLK_COR_SEQ_2_USE												=> FALSE,
				CLK_COR_SEQ_2_ENABLE										=> "0000",
				CLK_COR_SEQ_2_1													=> "0100000000",
				CLK_COR_SEQ_2_2													=> "0100000000",
				CLK_COR_SEQ_2_3													=> "0100000000",
				CLK_COR_SEQ_2_4													=> "0100000000",

				-- channel bonding
				CHAN_BOND_1_MAX_SKEW										=> 1,
				CHAN_BOND_2_MAX_SKEW										=> 1,
				CHAN_BOND_KEEP_ALIGN										=> FALSE,
				CHAN_BOND_SEQ_LEN												=> 1,
				
				CHAN_BOND_SEQ_1_ENABLE									=> "1111",
				CHAN_BOND_SEQ_1_1												=> "0000000000",
				CHAN_BOND_SEQ_1_2												=> "0000000000",
				CHAN_BOND_SEQ_1_3												=> "0000000000",
				CHAN_BOND_SEQ_1_4												=> "0000000000",

				CHAN_BOND_SEQ_2_USE											=> FALSE,
				CHAN_BOND_SEQ_2_ENABLE									=> "1111",
				CHAN_BOND_SEQ_2_1												=> "0000000000",
				CHAN_BOND_SEQ_2_2												=> "0000000000",
				CHAN_BOND_SEQ_2_3												=> "0000000000",
				CHAN_BOND_SEQ_2_4												=> "0000000000",
				CHAN_BOND_SEQ_2_CFG											=> "00000"
			)
			PORT MAP (
				-- loopback
				-- ====================================================================
				LOOPBACK																=> "000",
				
				-- powerdown
				-- ====================================================================
				TXPOWERDOWN															=> "00",																		-- normal operation
				RXPOWERDOWN															=> "00",																		-- normal operation

				TXPLLPOWERDOWN													=> '0',																			-- power down TXPLL, "1" if RXPLL is used (see => )
				RXPLLPOWERDOWN													=> '0',																			-- power down RXPLL

				-- clock sources
				-- ====================================================================
				GREFCLKTX																=> '0',																			-- unused
				PERFCLKTX																=> '0',																			-- internal FPGA clock, for testing only
				MGTREFCLKTX(0)													=> '0',																			-- MGT reference clock: MGTREFCLKTX0
				MGTREFCLKTX(1)													=> GTX_TX_RefClockIn,												-- MGT reference clock: MGTREFCLKTX1
				NORTHREFCLKTX														=> "00",																		-- reference clock from QUAD-1 (to north)
				SOUTHREFCLKTX														=> "00",																		-- reference clock from QUAD+1 (to south)
				
				GREFCLKRX																=> '0',																			-- global reference clock
				PERFCLKRX																=> '0',																			-- internal FPGA clock, for testing only
				MGTREFCLKRX(0)													=> '0',																			-- MGT reference clock: MGTREFCLKRX0
				MGTREFCLKRX(1)													=> GTX_RX_RefClockIn,												-- MGT reference clock: MGTREFCLKRX1
				NORTHREFCLKRX														=> "00",																		-- reference clock from QUAD-1 (to north)
				SOUTHREFCLKRX														=> "00",																		-- reference clock from QUAD+1 (to south)

				-- reference clock multiplexer
				-- ====================================================================
				TXPLLREFSELDY														=> "001",																		-- MGTREFCLKTX[1] <= MGTREFCLK1
				RXPLLREFSELDY														=> "001",																		-- MGTREFCLKRX[1] <= MGTREFCLK1
				
				-- PLL signals
				-- ====================================================================
				TXPLLLKDETEN														=> '1',
				TXPLLLKDET															=> GTX_TXPLL_ResetDone,
				
				RXPLLLKDETEN														=> '1',
				RXPLLLKDET															=> GTX_RXPLL_ResetDone,

				-- reset signals
				-- ====================================================================
				PLLTXRESET															=> GTX_TXPLL_Reset,													-- 
				GTXTXRESET															=> GTX_TX_Reset,														-- @async:
				TXRESET																	=> '0',																			-- @async: subset of GTX_TX_Reset
				TXRESETDONE															=> GTX_TX_ResetDone,												-- @async:

				PLLRXRESET															=> GTX_RXPLL_Reset,													-- 
				GTXRXRESET															=> GTX_RX_Reset,														-- @async:
				RXRESET																	=> '0',																			-- @async : subset of GTX_RX_Reset
				RXRESETDONE															=> GTX_RX_ResetDone,												-- @async:
				
				-- line rate signals
				-- ====================================================================
				TXRATE																	=> GTX_TX_LineRate,													-- dynamic tx line rate devider: 1,2,4
				TXRATEDONE															=> GTX_TX_LineRate_Changed,									-- tx line rate changed
				
				RXRATE																	=> GTX_RX_LineRate,													-- dynamic rx line rate devider: 1,2,4
				RXRATEDONE															=> GTX_RX_LineRate_Changed,									-- rx line rate changed
				
				-- Clock outputs
				-- ====================================================================
				MGTREFCLKFAB														=> GTX_FABClockOut,													-- MGT Fabric clock outputs (0 => TX, 1 => RX)

				TXOUTCLK																=> GTX_TX_RefClockOut,											-- TX reference clock
				TXOUTCLKPCS															=> GTX_TX_PCSClockOut,											-- internal TX PCS clock

				RXRECCLK																=> GTX_RX_RefClockOut,											-- recovered clock from device
				RXRECCLKPCS															=> GTX_RX_PCSClockOut,											-- internal RX PCS clock, also recovered clock

				-- user clocks
				-- ====================================================================
				TXUSRCLK																=> GTX_Clock_2X,													-- 2 byte word clock
				TXUSRCLK2																=> GTX_Clock_4X,													-- 4 byte word clock
				
				RXUSRCLK																=> GTX_Clock_2X,													-- 2 byte word clock
				RXUSRCLK2																=> GTX_Clock_4X,													-- 4 byte word clock

				-- Dynamic Reconfiguration Port (DRP)
				DCLK																		=> '0',
				DEN																			=> '0',
				DADDR																		=> (OTHERS => '0'),
				DWE																			=> '0',
				DI																			=> (OTHERS => '0'),
				DRPDO																		=> OPEN,
				DRDY																		=> OPEN,

				-- GTX test ports
				GTXTEST																	=> "1000000000000",
				TSTCLK0																	=> '0',
				TSTCLK1																	=> '0',
				TSTIN																		=> "11111111111111111111",
				TSTOUT																	=> OPEN,
			
				-------------- Receive Ports	- 64b66b and 64b67b Gearbox Ports	-------------
				RXGEARBOXSLIP														=> '0',
				RXHEADER																=> OPEN,
				RXHEADERVALID														=> OPEN,
				RXDATAVALID															=> OPEN,
				RXSTARTOFSEQ														=> OPEN,
				
				-- Receive Ports	- 8b10b Decoder
				RXDEC8B10BUSE														=> '1',
				RXDISPERR																=> GTX_RX_DisparityError,
				RXNOTINTABLE														=> GTX_RX_Illegal8B10BCode,
				RXRUNDISP																=> OPEN,
				USRCODEERR															=> '0',
				
				-- Receive Ports	- Channel Bonding Ports
				RXCHANBONDSEQ														=> OPEN,
				RXCHBONDI																=> "0000",
				RXCHBONDLEVEL														=> "000",
				RXCHBONDMASTER													=> '0',
				RXCHBONDO																=> OPEN,
				RXCHBONDSLAVE														=> '0',
				RXENCHANSYNC														=> '0',
				
				-- Receive Ports	- Clock Correction Ports
				RXCLKCORCNT															=> OPEN,																		-- Clock Correction Status / ElasticBuffer word insert/remove information
				
				-- Receive Ports	- Comma Detection and Alignment
				RXBYTEISALIGNED													=> GTX_RX_ByteIsAligned,									-- @ GTX_Clock_2X,	high-active, long signal			bytes are aligned
				RXBYTEREALIGN														=> GTX_RX_ByteRealign,										-- @ GTX_Clock_2X,	hight-active, short pulse			alignment has changed
				RXCOMMADET															=> GTX_RX_CommaDetected,
				RXCOMMADETUSE														=> '1',
				RXENMCOMMAALIGN													=> '1',
				RXENPCOMMAALIGN													=> '1',
				RXSLIDE																	=> '0',
				
				-- Receive Ports	- PRBS Detection
				PRBSCNTRESET														=> '0',
				RXENPRBSTST															=> "000",
				RXPRBSERR																=> OPEN,
				
				-- Receive Ports	- RX Decision Feedback Equalizer(DFE)
				DFECLKDLYADJ														=> "000000",
				DFECLKDLYADJMON													=> OPEN,
				DFEDLYOVRD															=> '0',
				DFEEYEDACMON														=> OPEN,
				DFESENSCAL															=> OPEN,
				DFETAP1																	=> "00000",
				DFETAP1MONITOR													=> OPEN,
				DFETAP2																	=> "00000",
				DFETAP2MONITOR													=> OPEN,
				DFETAP3																	=> "0000",
				DFETAP3MONITOR													=> OPEN,
				DFETAP4																	=> "0000",
				DFETAP4MONITOR													=> OPEN,
				DFETAPOVRD															=> '1',
				
				-- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR
				IGNORESIGDET														=> '0',
				RXCDRRESET															=> '0',																			-- CDR => Clock Data Recovery

				RXEQMIX																	=> "0000000000",
				
				-------- Receive Ports	- RX Elastic Buffer and Phase Alignment Ports	-------

				RXCHANISALIGNED													=> OPEN,
				RXCHANREALIGN														=> OPEN,
				RXDLYALIGNDISABLE												=> '0',
				RXDLYALIGNMONENB												=> '0',
				RXDLYALIGNMONITOR												=> OPEN,
				RXDLYALIGNOVERRIDE											=> '1',
				RXDLYALIGNRESET													=> '0',
				RXDLYALIGNSWPPRECURB										=> '1',
				RXDLYALIGNUPDSW													=> '0',
				RXENPMAPHASEALIGN												=> '0',
				RXPMASETPHASE														=> '0',
				RXSTATUS																=> OPEN,
				
				--------------- Receive Ports	- RX Loss-of-sync State Machine	--------------
				RXLOSSOFSYNC														=> GTX_RX_LossOfSync,											-- Xilinx example has connected signal
				
				---------------------- Receive Ports	- RX Oversampling	---------------------
				RXENSAMPLEALIGN													=> '0',
				RXOVERSAMPLEERR													=> OPEN,
				
				-- differential signals
				-- ====================================================================
				TXN																			=> GTX_TX_n,
				TXP																			=> GTX_TX_p,
				
				RXN																			=> GTX_RX_n,
				RXP																			=> GTX_RX_p,

				-- OOB signaling
				-- ====================================================================
				TXELECIDLE															=> GTX_TX_ElectricalIDLE,										-- send electrical idle
				RXELECIDLE															=> GTX_RX_ElectricalIDLE_i,									-- electrical idle detected
				GATERXELECIDLE													=> '0',

				TXCOMINIT																=> GTX_TX_ComInit,
				TXCOMWAKE																=> GTX_TX_ComWake,
				TXCOMSAS																=> '0',
				COMFINISH																=> GTX_TX_OOBComplete,
				
				COMINITDET															=> GTX_RX_ComInit,
				COMWAKEDET															=> GTX_RX_ComWake,
				COMSASDET																=> OPEN,
				
				-- data ports
				TXDATA																	=> GTX_TX_Data,															-- 32 bit tx data port
				TXCHARISK																=> GTX_TX_CharIsK,													-- 4 bit tx k-symbol port
				
				RXDATA																	=> GTX_RX_Data,															-- 32 bit rx data port
				RXCHARISCOMMA														=> GTX_RX_CharIsComma,											-- 4 bit rx comma port
				RXCHARISK																=> GTX_RX_CharIsK,													-- 4 bit rx k-symbol port
				
				-- buffer
				RXBUFRESET															=> '0',
				
				TXBUFSTATUS															=> GTX_TX_BufferStatus,				
				RXBUFSTATUS															=> GTX_RX_BufferStatus,											-- @GTX_Clock_2X: RX buffer status (over/underflow)	
-- ======================
				
								-------------- Receive Ports	- RX Pipe Control for PCI Express	-------------
				PHYSTATUS																=> OPEN,
				RXVALID																	=> GTX_RX_Valid,
				
				----------------- Receive Ports	- RX Polarity Control Ports	----------------
				RXPOLARITY															=> '0',

				
				-- TX elastic buffer and phase alignment

				
				TXDLYALIGNDISABLE												=> '1',
				TXDLYALIGNMONENB												=> '0',
				TXDLYALIGNMONITOR												=> OPEN,
				TXDLYALIGNOVERRIDE											=> '0',
				TXDLYALIGNRESET													=> '0',
				TXDLYALIGNUPDSW													=> '1',
				TXENPMAPHASEALIGN												=> '0',
				TXPMASETPHASE														=> '0',

				-- TX 64B66B and 64B67B Gearbox ports
				TXGEARBOXREADY													=> OPEN,
				TXHEADER																=> "000",
				TXSEQUENCE															=> "0000000",
				TXSTARTSEQ															=> '0',
				
				-- TX 8B10B encoder ports
				TXENC8B10BUSE														=> '1',
				TXBYPASS8B10B														=> "0000",
				TXCHARDISPMODE													=> "0000",
				TXCHARDISPVAL														=> "0000",

				TXKERR																	=> GTX_TX_InvalidK,
				TXRUNDISP																=> OPEN,

				-- TX PRBS generator
				TXENPRBSTST															=> "000",
				TXPRBSFORCEERR													=> '0',
				
				-- TX polarity control
				TXPOLARITY															=> '0',
				
				-- TX ports for PCI Express
				TXDEEMPH																=> '0',
				TXDETECTRX															=> '0',
				TXMARGIN																=> "000",
				TXPDOWNASYNCH														=> '0',
				TXSWING																	=> '0',
				
				-- TX driver and OOB signaling	--------------
				TXBUFDIFFCTRL														=> "100",
				TXDIFFCTRL															=> "0100",								-- 480 mV (mV_PPD)
				TXINHIBIT																=> '0',
				TXPREEMPHASIS														=> "0000",
				TXPOSTEMPHASIS													=> "00000"
		 );
		
		VSS_Private(I).TX_n			<= GTX_TX_n;
		VSS_Private(I).TX_p			<= GTX_TX_p;
		GTX_RX_n								<= VSS_Private(I).RX_n;
		GTX_RX_p								<= VSS_Private(I).RX_p;


-- ==================================================================
-- debugging signals
-- ==================================================================
		DebugPortOut(I).PLL_Reset						<= GTX_PLL_Reset_r;
		DebugPortOut(I).TXPLL_Locked				<= GTX_TXPLL_ResetDone;
		DebugPortOut(I).RXPLL_Locked				<= GTX_RXPLL_ResetDone;
		
		DebugPortOut(I).MMCM_Reset					<= ClkNet_Reset;
		DebugPortOut(I).MMCM_Locked					<= ClkNet_ResetDone;
		
		DebugPortOut(I).RefClock						<= ClockIn_150MHz_BUFR;
		DebugPortOut(I).TXOutClock					<= GTX_TX_RefClockOut;
		DebugPortOut(I).RXRecClock					<= GTX_RX_RefClockOut;
		DebugPortOut(I).SATAClock						<= GTX_Clock_4X;
		
-- ==================================================================
-- ChipScope debugging signals
-- ==================================================================
		genCSP : IF (CHIPSCOPE_KEEP = TRUE) GENERATE
			SIGNAL DBG_ClockTX_1X												: STD_LOGIC;
			SIGNAL DBG_ClockTX_4X												: STD_LOGIC;
			
			SIGNAL DBG_GTP_RX_ByteIsAligned							: STD_LOGIC;
			SIGNAL DBG_GTP_RX_CharIsComma								: STD_LOGIC;
			SIGNAL DBG_GTP_RX_CharIsK										: STD_LOGIC;
			SIGNAL DBG_GTP_RX_Data											: T_SLV_8;
			SIGNAL DBG_GTP_TX_CharIsK										: STD_LOGIC;
			SIGNAL DBG_GTP_TX_Data											: T_SLV_8;
			
			SIGNAL DBG_RX_CharIsK												: T_SATA_CIK;
			SIGNAL DBG_RX_Data													: T_SLV_32;
			SIGNAL DBG_TX_CharIsK												: T_SATA_CIK;
			SIGNAL DBG_TX_Data													: T_SLV_32;
			
			SIGNAL DBG_OOBCommand_COMRESET							: STD_LOGIC;
			SIGNAL DBG_OOBCommand_COMWAKE								: STD_LOGIC;
			SIGNAL DBG_GTX_COMRESET											: STD_LOGIC;
			SIGNAL DBG_GTX_COMWAKE											: STD_LOGIC;
			
			SIGNAL DBG_OOBStatus_COMRESET								: STD_LOGIC;
			SIGNAL DBG_OOBStatus_COMWAKE								: STD_LOGIC;
		
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
		
			ATTRIBUTE KEEP OF DBG_OOBCommand_COMRESET		: SIGNAL IS TRUE;
			ATTRIBUTE KEEP OF DBG_OOBCommand_COMWAKE		: SIGNAL IS TRUE;
			ATTRIBUTE KEEP OF DBG_GTX_COMRESET					: SIGNAL IS TRUE;
			ATTRIBUTE KEEP OF DBG_GTX_COMWAKE						: SIGNAL IS TRUE;
		
			ATTRIBUTE KEEP OF DBG_OOBStatus_COMRESET		: SIGNAL IS TRUE;
			ATTRIBUTE KEEP OF DBG_OOBStatus_COMWAKE			: SIGNAL IS TRUE;	
		BEGIN
--			DBG_ClockTX_1X							<= GTP_ClockTX_1X;
--			DBG_ClockTX_4X							<= GTP_ClockTX_4X;
				
--			DBG_GTP_RX_ByteIsAligned		<= GTP_RX_ByteIsAligned;
--			DBG_GTP_RX_CharIsComma			<= GTP_RX_CharIsComma;
--			DBG_GTP_RX_CharIsK					<= GTP_RX_CharIsK;
--			DBG_GTP_RX_Data							<= GTP_RX_Data;
--			DBG_GTP_TX_CharIsK					<= GTP_TX_CharIsK;
--			DBG_GTP_TX_Data							<= GTP_TX_Data;
			
--			DBG_RX_CharIsK							<= RX_CharIsK;
--			DBG_RX_Data									<= RX_Data;
--			DBG_TX_CharIsK							<= TX_CharIsK;
--			DBG_TX_Data									<= TX_Data;
				
			DBG_OOBCommand_COMRESET			<= to_sl(TX_OOBCommand_d = SATA_OOB_COMRESET);
			DBG_OOBCommand_COMWAKE			<= to_sl(TX_OOBCommand_d = SATA_OOB_COMWAKE);
			DBG_GTX_COMRESET						<= GTX_TX_ComInit;
			DBG_GTX_COMWAKE							<= GTX_TX_ComWake;
			
			DBG_OOBStatus_COMRESET			<= to_sl(RX_OOBStatus_i = SATA_OOB_COMRESET);
			DBG_OOBStatus_COMWAKE				<= to_sl(RX_OOBStatus_i = SATA_OOB_COMWAKE);
		END GENERATE;
	END GENERATE;
END;