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
--USE			PoC.sata_TransceiverTypes.ALL;


ENTITY SATATransceiver_Series7_GTXE2 IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																	-- 150 MHz
		PORTS											: POSITIVE										:= 2;																			-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3 => T_SATA_GENERATION'high)			-- intial SATA Generation
	);
	PORT (
		ClockIn_150MHz						: IN	STD_LOGIC;
		SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

		Reset											: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
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
		
		Command										: IN	T_TRANS_COMMAND_VECTOR(PORTS	- 1 DOWNTO 0);
		Status										: OUT	T_TRANS_STATUS_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_Error									: OUT	T_RX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_Error									: OUT	T_TX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);

		RX_OOBStatus							: OUT	T_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_Data										: OUT	T_SLVV_32(PORTS	- 1 DOWNTO 0);
		RX_CharIsK								: OUT	T_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		
		TX_OOBCommand							: IN	T_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_Data										: IN	T_SLVV_32(PORTS	- 1 DOWNTO 0);
		TX_CharIsK								: IN	T_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
		
		-- LVDS Ports
		RX_n											: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_p											: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_n											: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_p											: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF SATATransceiver_Series7_GTXE2 IS
	ATTRIBUTE KEEP 														: BOOLEAN;

-- ==================================================================
-- SATATransceiver configuration
-- ==================================================================
	CONSTANT NO_DEVICE_TIMEOUT_MS							: REAL						:= 50.0;					-- 50 ms
	CONSTANT NEW_DEVICE_TIMEOUT_MS						: REAL						:= 0.001;				-- FIXME: not used -> remove ???

	FUNCTION IsSupportedGeneration(SATAGen : T_SATA_GENERATION) RETURN BOOLEAN IS
	BEGIN
		CASE SATAGen IS
			WHEN SATA_GEN_1	=> RETURN TRUE;
			WHEN SATA_GEN_2	=> RETURN TRUE;
			WHEN OTHERS	=> 		RETURN FALSE;
		END CASE;
	END;

	SIGNAL ClockIn_150MHz_BUFR								: STD_LOGIC;
	SIGNAL DD_Clock														: STD_LOGIC;
	SIGNAL Control_Clock											: STD_LOGIC;
	
	SIGNAL GTXConfig_Reset										: STD_LOGIC;
	SIGNAL GTXConfig_Reconfig									: STD_LOGIC;
	SIGNAL GTXConfig_ReconfigComplete					: STD_LOGIC;
	SIGNAl GTXConfig_ConfigReloaded						: STD_LOGIC;
	SIGNAL GTXConfig_GTX_ReloadConfig					: STD_LOGIC;

BEGIN
-- ==================================================================
-- Assert statements
-- ==================================================================
	ASSERT (VENDOR = VENDOR_XILINX)		REPORT "Vendor not yet supported."				SEVERITY FAILURE;
	ASSERT (DEVFAM = DEVFAM_VIRTEX)		REPORT "Device family not yet supported."	SEVERITY FAILURE;
--	ASSERT (DEVICE = DEVICE_VIRTEX6)	REPORT "Device not yet supported."				SEVERITY FAILURE;
	ASSERT (PORTS <= 4)								REPORT "To many ports per Quad."					SEVERITY FAILURE;
	
	ASSERT (FALSE) REPORT "not yet implemented" SEVERITY FAILURE;
	
	genassert : FOR I IN 0 TO PORTS	- 1 GENERATE
		ASSERT 	IsSupportedGeneration(SATA_Generation(I))	REPORT "unsupported SATA generation" SEVERITY FAILURE;
	END GENERATE;

	-- common clocking resources
	BUFR_SATA_RefClockIn : BUFR
		PORT MAP (
			I				=> ClockIn_150MHz,
			CE			=> '1',
			CLR			=> '0',
			O				=> ClockIn_150MHz_BUFR
		);
	
	-- stable clock for device detection logics
	DD_Clock												<= ClockIn_150MHz_BUFR;
	Control_Clock										<= ClockIn_150MHz_BUFR;

--	gtxe2_common_0_i : GTXE2_COMMON
--    generic map
--    (
--            -- Simulation attributes
--            SIM_RESET_SPEEDUP    => WRAPPER_SIM_GTRESET_SPEEDUP,
--            SIM_QPLLREFCLK_SEL   => ("001"),
--            SIM_VERSION          => SIM_VERSION,
--
--
--       ------------------COMMON BLOCK---------------
--        BIAS_CFG                                =>     (x"0000040000001000"),
--        COMMON_CFG                              =>     (x"00000000"),
--        QPLL_CFG                                =>     (x"06801C1"),
--        QPLL_CLKOUT_CFG                         =>     ("0000"),
--        QPLL_COARSE_FREQ_OVRD                   =>     ("010000"),
--        QPLL_COARSE_FREQ_OVRD_EN                =>     ('0'),
--        QPLL_CP                                 =>     ("0000011111"),
--        QPLL_CP_MONITOR_EN                      =>     ('0'),
--        QPLL_DMONITOR_SEL                       =>     ('0'),
--        QPLL_FBDIV                              =>     (QPLL_FBDIV_IN),
--        QPLL_FBDIV_MONITOR_EN                   =>     ('0'),
--        QPLL_FBDIV_RATIO                        =>     (QPLL_FBDIV_RATIO),
--        QPLL_INIT_CFG                           =>     (x"000006"),
--        QPLL_LOCK_CFG                           =>     (x"21E8"),
--        QPLL_LPF                                =>     ("1111"),
--        QPLL_REFCLK_DIV                         =>     (1)
--
--        
--    )
--    port map
--    (
--        ------------- Common Block  - Dynamic Reconfiguration Port (DRP) -----------
--        DRPADDR                         =>      tied_to_ground_vec_i(7 downto 0),
--        DRPCLK                          =>      tied_to_ground_i,
--        DRPDI                           =>      tied_to_ground_vec_i(15 downto 0),
--        DRPDO                           =>      open,
--        DRPEN                           =>      tied_to_ground_i,
--        DRPRDY                          =>      open,
--        DRPWE                           =>      tied_to_ground_i,
--        ---------------------- Common Block  - Ref Clock Ports ---------------------
--        GTGREFCLK                       =>      tied_to_ground_i,
--        GTNORTHREFCLK0                  =>      tied_to_ground_i,
--        GTNORTHREFCLK1                  =>      tied_to_ground_i,
--        GTREFCLK0                       =>      GT0_GTREFCLK0_COMMON_IN,
--        GTREFCLK1                       =>      tied_to_ground_i,
--        GTSOUTHREFCLK0                  =>      tied_to_ground_i,
--        GTSOUTHREFCLK1                  =>      tied_to_ground_i,
--        ------------------------- Common Block - QPLL Ports ------------------------
--        QPLLFBCLKLOST                   =>      open,
--        QPLLLOCK                        =>      GT0_QPLLLOCK_OUT,
--        QPLLLOCKDETCLK                  =>      GT0_QPLLLOCKDETCLK_IN,
--        QPLLLOCKEN                      =>      tied_to_vcc_i,
--        QPLLOUTCLK                      =>      gt0_qplloutclk_i,
--        QPLLOUTREFCLK                   =>      gt0_qplloutrefclk_i,
--        QPLLOUTRESET                    =>      tied_to_ground_i,
--        QPLLPD                          =>      tied_to_ground_i,
--        QPLLREFCLKLOST                  =>      open,
--        QPLLREFCLKSEL                   =>      "001",
--        QPLLRESET                       =>      GT0_QPLLRESET_IN,
--        QPLLRSVD1                       =>      "0000000000000000",
--        QPLLRSVD2                       =>      "11111",
--        RCALENB                         =>      tied_to_vcc_i,
--        REFCLKOUTMONITOR                =>      open,
--        ----------------------------- Common Block Ports ---------------------------
--        BGBYPASSB                       =>      tied_to_vcc_i,
--        BGMONITORENB                    =>      tied_to_vcc_i,
--        BGPDB                           =>      tied_to_vcc_i,
--        BGRCALOVRD                      =>      "00000",
--        PMARSVD                         =>      "00000000",
--        QPLLDMONITOR                    =>      open
--
--    );

	
-- ==================================================================
-- data path buffers
-- ==================================================================
	genGTXE1 : FOR I IN 0 TO (PORTS	- 1) GENERATE
		SIGNAL TX_OOBCommand_d										: T_OOB;			--						:= OOB_NONE;
		SIGNAL RX_OOBStatus_i											: T_OOB;
		SIGNAL RX_OOBStatus_d											: T_OOB;			--						:= OOB_NONE;
		
		SIGNAL ClkNet_Reset												: STD_LOGIC;
		SIGNAL ClkNet_ResetDone_i									: STD_LOGIC;
		SIGNAL ClkNet_ResetDone_d									: STD_LOGIC																:= '0';
		SIGNAL ClkNet_ResetDone_d2								: STD_LOGIC																:= '0';
		SIGNAL ClkNet_ResetDone										: STD_LOGIC;
		SIGNAL GTX_RefClockOut										: STD_LOGIC;
		
		SIGNAL ClockNetwork_ResetDone_i						: STD_LOGIC;
		
		SIGNAL GTX_TX_RefClockIn									: T_SLV_2;
		SIGNAL GTX_RX_RefClockIn									: T_SLV_2;
		SIGNAL GTX_TX_RefClockOut									: STD_LOGIC;
		
		SIGNAL GTX_Clock_2X												: STD_LOGIC;
		SIGNAL GTX_Clock_4X												: STD_LOGIC;
		SIGNAL GTX_ClockTX_2X											: STD_LOGIC;
		SIGNAL GTX_ClockTX_4X											: STD_LOGIC;
		SIGNAL GTX_ClockRX_2X											: STD_LOGIC;
		SIGNAL GTX_ClockRX_4X											: STD_LOGIC;
		
		SIGNAL GTX_Reset													: STD_LOGIC;
		SIGNAL GTX_ResetDone											: STD_LOGIC;
		
		SIGNAL GTX_TX_Reset												: STD_LOGIC;
		SIGNAL GTX_TX_ResetDone										: STD_LOGIC;
		
		SIGNAL GTX_RX_Reset												: STD_LOGIC;
		SIGNAL GTX_RX_ResetDone										: STD_LOGIC;
		
		SIGNAL GTX_PLL_Reset											: STD_LOGIC;
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
		SIGNAL GTX_TX_ComStart										: STD_LOGIC;
		SIGNAL GTX_TX_ComInit											: STD_LOGIC;
		SIGNAL GTX_TX_ComWake											: STD_LOGIC;
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
		
		SIGNAL TX_Error_i													: T_TX_ERROR;
		SIGNAL RX_Error_i													: T_RX_ERROR;
		
		SIGNAL WA_Align														: T_SLV_2;
		
		-- keep internal clock nets, so timing constrains from UCF can find them
		ATTRIBUTE KEEP OF GTX_Clock_2X						: SIGNAL IS "TRUE";
		ATTRIBUTE KEEP OF GTX_Clock_4X						: SIGNAL IS "TRUE";
		
		ATTRIBUTE KEEP OF GTX_RX_ByteIsAligned		: SIGNAL IS "TRUE";
		ATTRIBUTE KEEP OF GTX_RX_CharIsComma			: SIGNAL IS "TRUE";
		ATTRIBUTE KEEP OF GTX_RX_CharIsK					: SIGNAL IS "TRUE";
		ATTRIBUTE KEEP OF GTX_RX_Data							: SIGNAL IS "TRUE";
		ATTRIBUTE KEEP OF GTX_RX_BufferStatus			: SIGNAL IS "TRUE";
		ATTRIBUTE KEEP OF GTX_TX_CharIsK					: SIGNAL IS "TRUE";
		ATTRIBUTE KEEP OF GTX_TX_Data							: SIGNAL IS "TRUE";
		ATTRIBUTE KEEP OF GTX_TX_OOBComplete			: SIGNAL IS "TRUE";
		
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
				Clock								=> GTX_ClockRX_4X,
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
				Clock								=> GTX_ClockRX_4X,
				Align								=> WA_Align,
				I										=> GTX_RX_CharIsK,
				O										=> RX_CharIsK(I),
				Valid								=> OPEN
			);
		
		RX_IsAligned(I)					<= GTX_RX_ByteIsAligned;


		-- ==================================================================
		-- ResetControl
		-- ==================================================================
		-- synchronize signals
		GTX_PLL_ResetDone_d						<= GTX_PLL_ResetDone_i	WHEN rising_edge(Control_Clock);
		GTX_PLL_ResetDone_d2					<= GTX_PLL_ResetDone_d	WHEN rising_edge(Control_Clock);
		GTX_PLL_ResetDone							<= GTX_PLL_ResetDone_d2;
		
		ClkNet_ResetDone_d						<= ClkNet_ResetDone_i			WHEN rising_edge(Control_Clock);
		ClkNet_ResetDone_d2						<= ClkNet_ResetDone_d			WHEN rising_edge(Control_Clock);
		ClkNet_ResetDone							<= ClkNet_ResetDone_d2;
		
--		GTX_RX_LineRate_Changed_d			<= GTX_RX_LineRate_Changed	WHEN rising_edge(Control_Clock);
		
		-- clock network resets
		ClkNet_Reset									<= ClockNetwork_Reset(I) OR Reset(I) OR (NOT GTX_PLL_ResetDone); -- OR GTX_RX_LineRate_Changed_d;
		GTX_PLL_Reset									<= ClockNetwork_Reset(I) OR Reset(I);
		GTX_TXPLL_Reset								<= GTX_PLL_Reset;
		GTX_RXPLL_Reset								<= GTX_PLL_Reset;
		
--		GTX_TXPLL_ResetDone_i					<= '1';
		GTX_PLL_ResetDone_i						<= GTX_TXPLL_ResetDone AND GTX_RXPLL_ResetDone;						-- @async
		ClockNetwork_ResetDone_i			<= GTX_PLL_ResetDone AND ClkNet_ResetDone;								-- @Control_Clock: is high, if all clocknetwork components are stable
		ClockNetwork_ResetDone(I)			<= ClockNetwork_ResetDone_i;															-- @Control_Clock:
		
		-- logic resets
		GTX_Reset											<= to_sl(Command(I) = TRANS_CMD_RESET) OR Reset(I);
		GTX_TX_Reset									<= GTX_Reset;
		GTX_RX_Reset									<= GTX_Reset;
		
		GTX_ResetDone									<= GTX_TX_ResetDone AND GTX_RX_ResetDone;									-- @GTX_Clock_4X
		ResetDone(I)									<= GTX_ResetDone;																					-- @GTX_Clock_4X

		-- ==================================================================
		-- ClockNetwork (75, 150 MHz)
		-- ==================================================================
		GTX_TX_RefClockIn							<= (0 => '0', 1 => ClockIn_150MHz);
		GTX_RX_RefClockIn							<= (0 => '0', 1 => ClockIn_150MHz);
		GTX_RefClockOut								<= GTX_TX_RefClockOut;

		ClkNet : ENTITY L_SATAController.SATATransceiver_Virtex6_ClockNetwork
			GENERIC MAP (
				CLOCK_IN_FREQ_MHZ						=> 150.0																								-- 150 MHz
			)
			PORT MAP (
				ClockIn_150MHz							=> GTX_RefClockOut,

				ClockNetwork_Reset					=> ClkNet_Reset,
				ClockNetwork_ResetDone			=> ClkNet_ResetDone_i,
				
				GTX_Clock_2X								=> GTX_Clock_2X,
				GTX_Clock_4X								=> GTX_Clock_4X
			);

		GTX_ClockTX_2X								<= GTX_Clock_2X;
		GTX_ClockTX_4X								<= GTX_Clock_4X;
		GTX_ClockRX_2X								<= GTX_Clock_2X;
		GTX_ClockRX_4X								<= GTX_Clock_4X;
		
		SATA_Clock(I)									<= GTX_ClockRX_4X;

		-- ==================================================================
		-- OOB signaling
		-- ==================================================================
		TX_OOBCommand_d								<= TX_OOBCommand(I);	-- WHEN rising_edge(GTX_ClockTX_2X(I));

		-- TX OOB signals (generate GTX specific OOB signals)
		PROCESS(TX_OOBCommand_d)
		BEGIN
			GTX_TX_ComStart			<= '0';
			GTX_TX_ComInit			<= '0';
			GTX_TX_ComWake			<= '0';
		
			CASE TX_OOBCommand_d IS
				WHEN OOB_NONE =>
					NULL;
				
				WHEN OOB_READY =>
					NULL;
				
				WHEN OOB_COMRESET =>
					GTX_TX_ComStart	<= '1';
					GTX_TX_ComInit	<= '1';
				
				WHEN OOB_COMWAKE =>
					GTX_TX_ComStart	<= '1';
					GTX_TX_ComWake	<= '1';
			
			END CASE;
		END PROCESS;
		
		-- SR-FF for GTX_TX_ElectricalIDLE:
		--		.set	= ComStart
		--		.rst	= OOBComplete || Reset
		PROCESS(GTX_ClockTX_4X)
		BEGIN
			IF rising_edge(GTX_ClockTX_4X) THEN
				IF (Reset(I) = '1') THEN
					GTX_TX_ElectricalIDLE				<= '0';
				ELSE
					IF (GTX_TX_ComStart = '1') THEN
						GTX_TX_ElectricalIDLE			<= '1';
					ELSIF (GTX_TX_OOBComplete = '1') THEN
						GTX_TX_ElectricalIDLE			<= '0';
					END IF;
				END IF;
			END IF;
		END PROCESS;
		
		-- TX OOB sequence is complete
		TX_OOBComplete(I)							<= GTX_TX_OOBComplete;

		-- RX OOB signals
		GTX_RX_ElectricalIDLE_d 	<= GTX_RX_ElectricalIDLE_i WHEN rising_edge(GTX_ClockRX_4X);
		GTX_RX_ElectricalIDLE_d2	<= GTX_RX_ElectricalIDLE_d WHEN rising_edge(GTX_ClockRX_4X);
		GTX_RX_ElectricalIDLE			<= GTX_RX_ElectricalIDLE_d2;
		
		
		-- RX OOB signals (generate generic RX OOB status signals)
		PROCESS(GTX_RX_ComInit, GTX_RX_ComWake, GTX_RX_ElectricalIDLE)
		BEGIN
			RX_OOBStatus_i		 				<= OOB_NONE;
		
			IF (GTX_RX_ElectricalIDLE = '1') THEN
				RX_OOBStatus_i					<= OOB_READY;
			
				IF (GTX_RX_ComInit = '1') THEN
					RX_OOBStatus_i				<= OOB_COMRESET;
				ELSIF (GTX_RX_ComWake = '1') THEN
					RX_OOBStatus_i				<= OOB_COMWAKE;
				END IF;
			END IF;
		END PROCESS;

		--RX_OOBStatus_d		<= RX_OOBStatus_i;		-- WHEN rising_edge(SATA_Clock_i(I));
		RX_OOBStatus(I)		<= RX_OOBStatus_i;

		-- ==================================================================
		-- error handling
		-- ==================================================================
		-- TX errors
		PROCESS(GTX_TX_InvalidK, GTX_TX_BufferStatus(1))
		BEGIN
			TX_Error_i		<= TX_ERROR_NONE;
		
			IF (slv_or(GTX_TX_InvalidK) = '1') THEN
				TX_Error_i	<= TX_ERROR_ENCODER;
			ELSIF (GTX_TX_BufferStatus(1) = '1') THEN
				TX_Error_i	<= TX_ERROR_BUFFER;
			END IF;
		END PROCESS;
		
		-- RX errors
		PROCESS(GTX_RX_ByteIsAligned, GTX_RX_DisparityError, GTX_RX_Illegal8B10BCode, GTX_RX_BufferStatus(2))
		BEGIN
			RX_Error_i		<= RX_ERROR_NONE;
		
			IF (GTX_RX_ByteIsAligned = '0') THEN
				RX_Error_i	<= RX_ERROR_ALIGNEMENT;
			ELSIF (slv_or(GTX_RX_DisparityError) = '1') THEN
				RX_Error_i	<= RX_ERROR_DISPARITY;
			ELSIF (slv_or(GTX_RX_Illegal8B10BCode) = '1') THEN
				RX_Error_i	<= RX_ERROR_DECODER;
			ELSIF (GTX_RX_BufferStatus(2) = '1') THEN
				RX_Error_i	<= RX_ERROR_BUFFER;
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
				Clock										=> DD_Clock,
				ElectricalIDLE					=> GTX_RX_ElectricalIDLE_i,			-- async
				
				NoDevice								=> DD_NoDevice_i,								-- @DD_Clock
				NewDevice								=> DD_NewDevice_i								-- @DD_Clock
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
				Clock1									=> DD_Clock,										-- input clock domain
				Clock2									=> GTX_Clock_4X,								-- output clock domain
				I(0)										=> DD_NewDevice_i,							-- input bits
				O(0)										=> DD_NewDevice,								-- output bits
				B												=> OPEN													-- busy bits
			);
		
		PROCESS(GTX_ResetDone, DD_NoDevice, DD_NewDevice, TX_Error_i, RX_Error_i)
		BEGIN
			Status(I) 							<= TRANS_STATUS_NORMAL;
			
			IF (GTX_ResetDone = '0') THEN
				Status(I)							<= TRANS_STATUS_RESET;
			ELSIF (DD_NoDevice = '1') THEN
				Status(I)							<= TRANS_STATUS_NO_DEVICE;
			ELSIF ((TX_Error_i /= TX_ERROR_NONE) OR (RX_Error_i /= RX_ERROR_NONE)) THEN
				Status(I)							<= TRANS_STATUS_ERROR;
			ELSIF (DD_NewDevice = '1') THEN
				Status(I)							<= TRANS_STATUS_NEW_DEVICE;
				
-- TODO:
-- TRANS_STATUS_POWERED_DOWN,
-- TRANS_STATUS_CONFIGURATION,

			END IF;
		END PROCESS;
	
-- ==================================================================
-- LineRate control
-- ==================================================================
		PROCESS(GTX_Clock_4X)
		BEGIN
			IF rising_edge(GTX_Clock_4X) THEN
				IF (RP_Reconfig(I) = '1') THEN
					IF (SATA_Generation(I) = SATA_GEN_1) THEN
						GTX_TX_LineRate		<= "10";								-- TXPLL Divider (D) = 2
						GTX_RX_LineRate		<= "10";								-- rXPLL Divider (D) = 2
					ELSIF (SATA_Generation(I) = SATA_GEN_2) THEN
						GTX_TX_LineRate		<= "11";								-- TXPLL Divider (D) = 1
						GTX_RX_LineRate		<= "11";								-- rXPLL Divider (D) = 1
					ELSE
						NULL;
					END IF;
				END IF;
			END IF;
		END PROCESS;

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

				-- =========================== TX PLL =================================
				TX_OVERSAMPLE_MODE											=> FALSE,
				TXPLL_COM_CFG														=> x"21680a",
				TXPLL_CP_CFG														=> x"0D",
				TXPLL_DIVSEL_OUT												=> 1,																			-- TXPLL multiplier (M)
				TXPLL_DIVSEL45_FB												=> 5,																			-- TXPLL divider (N1); 5 => 10 Bit symbols
				TXPLL_DIVSEL_FB													=> 2,																			-- TXPLL divider (N2)
				TXPLL_DIVSEL_REF												=> 1,																			-- TXPLL linerate divider (D)
				TXPLL_LKDET_CFG													=> "111",
				TXPLL_SATA															=> "01",
				TX_CLK_SOURCE														=> "TXPLL",		-- "RXPLL",															-- TX and RX have same linerate => use only RXPLL => powerdown TXPLL

				TX_CLK25_DIVIDER												=> 6,																			-- RefClockIn @150 MHz => divider = 6

				TX_TDCC_CFG															=> "11",
				PMA_CAS_CLK_EN													=> FALSE,
				POWER_SAVE															=> "0000110000",

				-- ===========================  RX PLL ================================
				RX_OVERSAMPLE_MODE											=> FALSE,
				RXPLL_COM_CFG														=> x"21680a",
				RXPLL_CP_CFG														=> x"0D",
				RXPLL_DIVSEL_OUT												=> 1,																			-- TXPLL multiplier (M)
				RXPLL_DIVSEL_FB													=> 2,																			-- TXPLL divider (N2)
				RXPLL_DIVSEL45_FB												=> 5,																			-- TXPLL divider (N1); 5 => 10 Bit symbols
				RXPLL_DIVSEL_REF												=> 1,																			-- TXPLL linerate divider (D)
				RXPLL_LKDET_CFG													=> "111",
				
				RX_CLK25_DIVIDER												=> 6,																			-- RefClockIn @150 MHz => divider = 6

				-- =========================== TX interface ===========================
				GEN_TXUSRCLK														=> FALSE,
				TX_DATA_WIDTH														=> 40,
				TX_USRCLK_CFG														=> x"00",
				TXOUTCLK_CTRL														=> "TXOUTCLKPMA_DIV2",	--"TXOUTCLKPCS",
				TXOUTCLK_DLY														=> "0000000000",

				-- =========================== RX Interface ===========================
				GEN_RXUSRCLK														=> FALSE,
				RX_DATA_WIDTH														=> 40,
				RXRECCLK_CTRL														=> "RXRECCLKPCS",
				RXRECCLK_DLY														=> "0000000000",
				RXUSRCLK_DLY														=> x"0000",

				-- =================== TX Buffering and Phase Alignment ===============
				TX_PMADATA_OPT													=> '0',
				PMA_TX_CFG															=> x"80082",
				TX_BUFFER_USE														=> TRUE,
				TX_BYTECLK_CFG													=> x"00",
				TX_EN_RATE_RESET_BUF										=> TRUE,
				TX_XCLK_SEL															=> "TXOUT",
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

				-- =============== TX Pipe Control for PCI Express/SATA ===============
				COM_BURST_VAL														=> "0110",

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
				AC_CAP_DIS															=> TRUE,
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
				RX_BUFFER_USE														=> TRUE,
				RX_EN_IDLE_RESET_BUF										=> TRUE,
				RX_EN_MODE_RESET_BUF										=> TRUE,
				RX_EN_RATE_RESET_BUF										=> TRUE,
				RX_EN_REALIGN_RESET_BUF									=> FALSE,
				RX_EN_REALIGN_RESET_BUF2								=> FALSE,
				RX_FIFO_ADDR_MODE												=> "FULL",
				RX_IDLE_HI_CNT													=> "1000",
				RX_IDLE_LO_CNT													=> "0000",
				RX_XCLK_SEL															=> "RXREC",
				RX_DLYALIGN_CTRINC											=> "1110",
				RX_DLYALIGN_EDGESET											=> "00010",
				RX_DLYALIGN_LPFINC											=> "1110",
				RX_DLYALIGN_MONSEL											=> "000",
				RX_DLYALIGN_OVRDSETTING									=> "10000000",

				-- ======================== Clock Correction ==========================
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
				CLK_COR_SEQ_2_ENABLE										=> "1111",
				CLK_COR_SEQ_2_1													=> "0100000000",
				CLK_COR_SEQ_2_2													=> "0100000000",
				CLK_COR_SEQ_2_3													=> "0100000000",
				CLK_COR_SEQ_2_4													=> "0100000000",

				-- ======================== Channel Bonding ===========================
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
				CHAN_BOND_SEQ_2_CFG											=> "00000",
				
				PCI_EXPRESS_MODE												=> FALSE,

				-- =============== RX Attributes for PCI Express/SATA/SAS =============
				-- for SATA
				-- OOB COM*** signal detector @ 25 MHz with DDR (20 ns)
				SATA_BURST_VAL													=> "100",							-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL														=> "011",							-- IDLE count between bursts in OOB COM*** signals
				SATA_MIN_BURST													=> 4,									-- 80 ns				SATA Spec Rev 1.1		55 ns
				SATA_MAX_BURST													=> 7,									-- 140 ns				SATA Spec Rev 1.1		175 ns
				SATA_MIN_INIT														=> 12,								-- 240 ns				SATA Spec Rev 1.1		175 ns
				SATA_MAX_INIT														=> 22,								-- 440 ns				SATA Spec Rev 1.1		525 ns
				SATA_MIN_WAKE														=> 4,									-- 80 ns				SATA Spec Rev 1.1		55 ns
				SATA_MAX_WAKE														=> 7,									-- 140 ns				SATA Spec Rev 1.1		175 ns

				-- for SAS
				SAS_MIN_COMSAS													=> 40,								-- 
				SAS_MAX_COMSAS													=> 52,								-- 
				
				-- for PCI Express
				TRANS_TIME_FROM_P2											=> x"03c",
				TRANS_TIME_NON_P2												=> x"19",
				TRANS_TIME_RATE													=> x"ff",
				TRANS_TIME_TO_P2												=> x"064"
			)
			PORT MAP (
				------------------------ Loopback and Powerdown Ports	----------------------
				LOOPBACK																=> "000",
				RXPOWERDOWN															=> "00",
				
				-- GTX pest ports
				GTXTEST																	=> "1000000000000",
				MGTREFCLKFAB														=> OPEN,
				TSTCLK0																	=> '0',
				TSTCLK1																	=> '0',
				TSTIN																		=> "11111111111111111111",
				TSTOUT																	=> OPEN,
				
				-- Dynamic Reconfiguration Port (DRP)
				DCLK																		=> '0',
				DEN																			=> '0',
				DADDR																		=> (OTHERS => '0'),
				DWE																			=> '0',
				DI																			=> (OTHERS => '0'),
				DRPDO																		=> OPEN,
				DRDY																		=> OPEN,
				
-- ====================
				
				
				-------------- Receive Ports	- 64b66b and 64b67b Gearbox Ports	-------------
				RXGEARBOXSLIP														=> '0',
				RXHEADER																=> OPEN,
				RXHEADERVALID														=> OPEN,
				RXDATAVALID															=> OPEN,
				RXSTARTOFSEQ														=> OPEN,
				
				----------------------- Receive Ports	- 8b10b Decoder	----------------------
				RXCHARISCOMMA														=> GTX_RX_CharIsComma,
				RXCHARISK																=> GTX_RX_CharIsK,
				RXDEC8B10BUSE														=> '1',
				RXDISPERR																=> GTX_RX_DisparityError,
				RXNOTINTABLE														=> GTX_RX_Illegal8B10BCode,
				RXRUNDISP																=> OPEN,
				USRCODEERR															=> '0',
				
				------------------- Receive Ports	- Channel Bonding Ports	------------------
				RXCHANBONDSEQ														=> OPEN,
				RXCHBONDI																=> "0000",
				RXCHBONDLEVEL														=> "000",
				RXCHBONDMASTER													=> '0',
				RXCHBONDO																=> OPEN,
				RXCHBONDSLAVE														=> '0',
				RXENCHANSYNC														=> '0',
				
				------------------- Receive Ports	- Clock Correction Ports	-----------------
				RXCLKCORCNT															=> OPEN,																		-- Clock Correction Status / ElasticBuffer word insert/remove information
				
				--------------- Receive Ports	- Comma Detection and Alignment	--------------
				RXBYTEISALIGNED													=> GTX_RX_ByteIsAligned,									-- @ GTX_ClockRX_2X,	high-active, long signal			bytes are aligned
				RXBYTEREALIGN														=> GTX_RX_ByteRealign,										-- @ GTX_ClockRX_2X,	hight-active, short pulse			alignment has changed
				RXCOMMADET															=> GTX_RX_CommaDetected,
				RXCOMMADETUSE														=> '1',
				RXENMCOMMAALIGN													=> '1',
				RXENPCOMMAALIGN													=> '1',
				RXSLIDE																	=> '0',
				
				----------------------- Receive Ports	- PRBS Detection	---------------------
				PRBSCNTRESET														=> '0',
				RXENPRBSTST															=> "000",
				RXPRBSERR																=> OPEN,
				
				------------------- Receive Ports	- RX Data Path interface	-----------------
				RXDATA																	=> GTX_RX_Data,
				RXRECCLK																=> OPEN,																		-- CDR ClockOut - recovered clock from device
				RXRECCLKPCS															=> OPEN,
				RXRESET																	=> '0',																			-- @async : subset of GTX_RX_Reset
				RXUSRCLK																=> GTX_ClockRX_2X,
				RXUSRCLK2																=> GTX_ClockRX_4X,
				
				------------ Receive Ports	- RX Decision Feedback Equalizer(DFE)	-----------
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
				
				------- Receive Ports	- RX Driver,OOB signalling,Coupling and Eq.,CDR	------
				GATERXELECIDLE													=> '0',
				IGNORESIGDET														=> '0',
				RXCDRRESET															=> '0',																			-- CDR => Clock Data Recovery
				RXELECIDLE															=> GTX_RX_ElectricalIDLE_i,									-- 
				RXEQMIX																	=> "0000000000",
				RXN																			=> RX_n(I),
				RXP																			=> RX_p(I),
				
				-------- Receive Ports	- RX Elastic Buffer and Phase Alignment Ports	-------
				RXBUFRESET															=> '0',
				RXBUFSTATUS															=> GTX_RX_BufferStatus,									-- GTX_ClockRX_2X,	RX buffer status (over/underflow)
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
				
				------------------------ Receive Ports	- RX PLL Ports	----------------------
				-- clock sources
				GREFCLKRX																=> '0',
				MGTREFCLKRX															=> GTX_RX_RefClockIn,
				NORTHREFCLKRX														=> "00",
				SOUTHREFCLKRX														=> "00",				
				
				PERFCLKRX																=> '0',

				-- RX PLL
				PLLRXRESET															=> GTX_RXPLL_Reset,
				RXPLLLKDETEN														=> '1',
				RXPLLLKDET															=> GTX_RXPLL_ResetDone,
				RXPLLPOWERDOWN													=> '0',
				RXPLLREFSELDY														=> "001",

				-- RX reset
				GTXRXRESET															=> GTX_RX_Reset,
				RXRESETDONE															=> GTX_RX_ResetDone,
				
				-- RX line rate
				RXRATE																	=> GTX_RX_LineRate,
				RXRATEDONE															=> GTX_RX_LineRate_Changed,

				-------------- Receive Ports	- RX Pipe Control for PCI Express	-------------
				PHYSTATUS																=> OPEN,
				RXVALID																	=> GTX_RX_Valid,
				
				----------------- Receive Ports	- RX Polarity Control Ports	----------------
				RXPOLARITY															=> '0',
				
				--------------------- Receive Ports	- RX Ports for SATA	--------------------
				COMINITDET															=> GTX_RX_ComInit,
				COMWAKEDET															=> GTX_RX_ComWake,
				COMSASDET																=> OPEN,
				

				

				


	-- ======================
				-- TX reset ports
				GTXTXRESET															=> GTX_TX_Reset,														-- @async:
				TXRESET																	=> '0',																			-- @async: subset of GTX_TX_Reset
				TXRESETDONE															=> GTX_TX_ResetDone,												-- @async:

				-- TX power control
				TXPOWERDOWN															=> "00",
				TXPLLPOWERDOWN													=> '0',																			-- power down TXPLL, RXPLLis used
				
				-- TXPLL ports ----------------------
				GREFCLKTX																=> '0',																			-- unused
				MGTREFCLKTX															=> GTX_TX_RefClockIn,												-- use MGTREFCLKTX1
				NORTHREFCLKTX														=> "00",																		-- unused
				SOUTHREFCLKTX														=> "00",																		-- unused
				PERFCLKTX																=> '0',																			-- unused
				
				PLLTXRESET															=> GTX_TXPLL_Reset,
				TXPLLLKDETEN														=> '1',
				TXPLLLKDET															=> GTX_TXPLL_ResetDone,
				TXPLLREFSELDY														=> "001",
				
				TXRATE																	=> GTX_TX_LineRate,
				TXRATEDONE															=> GTX_TX_LineRate_Changed,

				-- TX data ports
				TXUSRCLK																=> GTX_ClockTX_2X,
				TXUSRCLK2																=> GTX_ClockTX_4X,
				TXDATA																	=> GTX_TX_Data,
				TXOUTCLK																=> GTX_TX_RefClockOut,
				TXOUTCLKPCS															=> OPEN,

				-- TX elastic buffer and phase alignment
				TXBUFSTATUS															=> GTX_TX_BufferStatus,
				
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
				TXCHARISK																=> GTX_TX_CharIsK,
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
				TXELECIDLE															=> GTX_TX_ElectricalIDLE,
				TXMARGIN																=> "000",
				TXPDOWNASYNCH														=> '0',
				TXSWING																	=> '0',
				
				-- TX OOB ports for SATA
				TXCOMINIT																=> GTX_TX_ComInit,
				TXCOMWAKE																=> GTX_TX_ComWake,
				TXCOMSAS																=> '0',
				COMFINISH																=> GTX_TX_OOBComplete,
				
				-- TX driver and OOB signaling	--------------
				TXBUFDIFFCTRL														=> "100",
				TXDIFFCTRL															=> "0000",
				TXINHIBIT																=> '0',
				TXPREEMPHASIS														=> "0000",
				TXPOSTEMPHASIS													=> "00000",
				TXN																			=> GTX_TX_n,
				TXP																			=> GTX_TX_p
		 );
		
--		gtxe2_i :GTXE2_CHANNEL
--    generic map
--    (
--
--        --_______________________ Simulation-Only Attributes ___________________
--
--        SIM_RECEIVER_DETECT_PASS   =>      ("TRUE"),
--        SIM_RESET_SPEEDUP          =>      (GT_SIM_GTRESET_SPEEDUP),
--        SIM_TX_EIDLE_DRIVE_LEVEL   =>      ("X"),
--        SIM_CPLLREFCLK_SEL         =>      ("001"),
--        SIM_VERSION                =>      (SIM_VERSION), 
--        
--
--       ------------------Comma Detection and Alignment---------------
--        ALIGN_COMMA_DOUBLE                      =>     ("FALSE"),
--        ALIGN_COMMA_ENABLE                      =>     ("1111111111"),
--        ALIGN_COMMA_WORD                        =>     (2),
--        ALIGN_MCOMMA_DET                        =>     ("TRUE"),
--        ALIGN_MCOMMA_VALUE                      =>     ("1010000011"),
--        ALIGN_PCOMMA_DET                        =>     ("TRUE"),
--        ALIGN_PCOMMA_VALUE                      =>     ("0101111100"),
--        DEC_MCOMMA_DETECT                       =>     ("TRUE"),
--        DEC_PCOMMA_DETECT                       =>     ("TRUE"),
--        DEC_VALID_COMMA_ONLY                    =>     ("TRUE"),
--        SHOW_REALIGN_COMMA                      =>     ("TRUE"),
--        RX_DISPERR_SEQ_MATCH                    =>     ("TRUE"),
--        RXSLIDE_AUTO_WAIT                       =>     (7),
--        RXSLIDE_MODE                            =>     ("OFF"),
--        RX_SIG_VALID_DLY                        =>     (10),
--
--       ------------------------Channel Bonding----------------------
--        CBCC_DATA_SOURCE_SEL                    =>     ("DECODED"),
--        CHAN_BOND_KEEP_ALIGN                    =>     ("FALSE"),
--        CHAN_BOND_MAX_SKEW                      =>     (1),
--        CHAN_BOND_SEQ_LEN                       =>     (1),
--        CHAN_BOND_SEQ_1_1                       =>     ("0000000000"),
--        CHAN_BOND_SEQ_1_2                       =>     ("0000000000"),
--        CHAN_BOND_SEQ_1_3                       =>     ("0000000000"),
--        CHAN_BOND_SEQ_1_4                       =>     ("0000000000"),
--        CHAN_BOND_SEQ_1_ENABLE                  =>     ("1111"),
--        CHAN_BOND_SEQ_2_1                       =>     ("0000000000"),
--        CHAN_BOND_SEQ_2_2                       =>     ("0000000000"),
--        CHAN_BOND_SEQ_2_3                       =>     ("0000000000"),
--        CHAN_BOND_SEQ_2_4                       =>     ("0000000000"),
--        CHAN_BOND_SEQ_2_ENABLE                  =>     ("1111"),
--        CHAN_BOND_SEQ_2_USE                     =>     ("FALSE"),
--        FTS_DESKEW_SEQ_ENABLE                   =>     ("1111"),
--        FTS_LANE_DESKEW_CFG                     =>     ("1111"),
--        FTS_LANE_DESKEW_EN                      =>     ("FALSE"),
--
--       ------------------------Clock Correction----------------------
--        CLK_COR_KEEP_IDLE                       =>     ("FALSE"),
--        CLK_COR_MAX_LAT                         =>     (31),
--        CLK_COR_MIN_LAT                         =>     (24),
--        CLK_COR_PRECEDENCE                      =>     ("TRUE"),
--        CLK_CORRECT_USE                         =>     ("TRUE"),
--        CLK_COR_REPEAT_WAIT                     =>     (0),
--        CLK_COR_SEQ_LEN                         =>     (4),
--        CLK_COR_SEQ_1_1                         =>     ("0000000000"),
--        CLK_COR_SEQ_1_2                         =>     ("0000000000"),
--        CLK_COR_SEQ_1_3                         =>     ("0000000000"),
--        CLK_COR_SEQ_1_4                         =>     ("0000000000"),
--        CLK_COR_SEQ_1_ENABLE                    =>     ("1111"),
--        CLK_COR_SEQ_2_1                         =>     ("0000000000"),
--        CLK_COR_SEQ_2_2                         =>     ("0000000000"),
--        CLK_COR_SEQ_2_3                         =>     ("0000000000"),
--        CLK_COR_SEQ_2_4                         =>     ("0000000000"),
--        CLK_COR_SEQ_2_ENABLE                    =>     ("1111"),
--        CLK_COR_SEQ_2_USE                       =>     ("FALSE"),
--
--       ----------------------------CHANNEL PLL----------------------------
--        CPLL_CFG                                =>     (x"BC07DC"),
--        CPLL_FBDIV                              =>     (4),
--        CPLL_FBDIV_45                           =>     (5),
--        CPLL_INIT_CFG                           =>     (x"00001E"),
--        CPLL_LOCK_CFG                           =>     (x"01E8"),
--        CPLL_REFCLK_DIV                         =>     (1),
--        RXOUT_DIV                               =>     (1),
--        TXOUT_DIV                               =>     (1),
--
--       ---------------------------EYESCAN----------------------------
--        ES_CONTROL                              =>     ("000000"),
--        ES_ERRDET_EN                            =>     ("FALSE"),
--        ES_EYE_SCAN_EN                          =>     ("TRUE"),
--        ES_HORZ_OFFSET                          =>     (x"000"),
--        ES_PMA_CFG                              =>     ("0000000000"),
--        ES_PRESCALE                             =>     ("00000"),
--        ES_QUALIFIER                            =>     (x"00000000000000000000"),
--        ES_QUAL_MASK                            =>     (x"00000000000000000000"),
--        ES_SDATA_MASK                           =>     (x"00000000000000000000"),
--        ES_VERT_OFFSET                          =>     ("000000000"),
--        OUTREFCLK_SEL_INV                       =>     ("11"),
--        PCS_PCIE_EN                             =>     ("TRUE"),
--        PCS_RSVD_ATTR                           =>     (PCS_RSVD_ATTR_IN),
--        PMA_RSV                                 =>     (PMA_RSV_IN),
--        PMA_RSV2                                =>     (x"2050"),
--        PMA_RSV3                                =>     ("00"),
--        PMA_RSV4                                =>     (x"00000000"),
--        RX_BIAS_CFG                             =>     ("000000000100"),
--        DMONITOR_CFG                            =>     (x"000A00"),
--
--       -------------RX Elastic Buffer and Phase alignment------------
--        RXBUF_ADDR_MODE                         =>     ("FULL"),
--        RXBUF_EIDLE_HI_CNT                      =>     ("1000"),
--        RXBUF_EIDLE_LO_CNT                      =>     ("0000"),
--        RXBUF_EN                                =>     ("TRUE"),
--        RX_BUFFER_CFG                           =>     ("000000"),
--        RXBUF_RESET_ON_CB_CHANGE                =>     ("TRUE"),
--        RXBUF_RESET_ON_COMMAALIGN               =>     ("FALSE"),
--        RXBUF_RESET_ON_EIDLE                    =>     ("FALSE"),
--        RXBUF_RESET_ON_RATE_CHANGE              =>     ("TRUE"),
--        RXBUFRESET_TIME                         =>     ("00001"),
--        RXBUF_THRESH_OVFLW                      =>     (61),
--        RXBUF_THRESH_OVRD                       =>     ("FALSE"),
--        RXBUF_THRESH_UNDFLW                     =>     (4),
--        RXDLY_CFG                               =>     (x"001F"),
--        RXDLY_LCFG                              =>     (x"030"),
--        RXDLY_TAP_CFG                           =>     (x"0000"),
--        RXPH_CFG                                =>     (x"000000"),
--        RXPHDLY_CFG                             =>     (x"084020"),
--        RXPH_MONITOR_SEL                        =>     ("00000"),
--        RX_XCLK_SEL                             =>     ("RXREC"),
--
--       ----------RX Driver,OOB signalling,Coupling and Eq.,CDR-------
--        RXCDR_CFG                               =>     (x"0b000023ff20400020"),
--        RXCDRFREQRESET_TIME                     =>     ("00001"),
--        RXCDR_FR_RESET_ON_EIDLE                 =>     ('0'),
--        RXCDR_HOLD_DURING_EIDLE                 =>     ('0'),
--        RXCDR_LOCK_CFG                          =>     ("010101"),
--        RXCDR_PH_RESET_ON_EIDLE                 =>     ('0'),
--        RXCDRPHRESET_TIME                       =>     ("00001"),
--        RXOOB_CFG                               =>     ("0000110"),
--
--       -------------------------RX Interface-------------------------
--        RX_INT_DATAWIDTH                        =>     (1),
--        RX_DATA_WIDTH                           =>     (40),
--        RX_CLKMUX_PD                            =>     ('1'),
--        RX_CLK25_DIV                            =>     (6),
--        RX_CM_SEL                               =>     ("11"),
--        RX_CM_TRIM                              =>     ("010"),
--        RX_DDI_SEL                              =>     ("000000"),
--        RX_DEBUG_CFG                            =>     ("000000000000"),
--
--       --------------RX Decision Feedback Equalizer(DFE)-------------
--        RX_DEFER_RESET_BUF_EN                   =>     ("TRUE"),
--        RX_DFE_GAIN_CFG                         =>     (x"020FEA"),
--        RX_DFE_H2_CFG                           =>     ("000000000000"),
--        RX_DFE_H3_CFG                           =>     ("000001000000"),
--        RX_DFE_H4_CFG                           =>     ("00011110000"),
--        RX_DFE_H5_CFG                           =>     ("00011100000"),
--        RX_DFE_LPM_HOLD_DURING_EIDLE            =>     ('0'),
--        RX_DFE_KL_CFG                           =>     ("0000011111110"),
--        RX_DFE_LPM_CFG                          =>     (x"0954"),
--        RX_OS_CFG                               =>     ("0000010000000"),
--        RX_DFE_UT_CFG                           =>     ("10001111000000000"),
--        RX_DFE_VP_CFG                           =>     ("00011111100000011"),
--        RXDFELPMRESET_TIME                      =>     ("0001111"),
--        RXLPM_HF_CFG                            =>     ("00000011110000"),
--        RXLPM_LF_CFG                            =>     ("00000011110000"),
--
--       -------------------------RX Gearbox---------------------------
--        RXGEARBOX_EN                            =>     ("FALSE"),
--        GEARBOX_MODE                            =>     ("000"),
--        RXISCANRESET_TIME                       =>     ("00001"),
--        RXPCSRESET_TIME                         =>     ("00001"),
--        RXPMARESET_TIME                         =>     ("00011"),
--
--       -------------------------PRBS Detection-----------------------
--        RXPRBS_ERR_LOOPBACK                     =>     ('0'),
--
--       -------------RX Attributes for PCI Express/SATA/SAS----------
--        PD_TRANS_TIME_FROM_P2                   =>     (x"03c"),
--        PD_TRANS_TIME_NONE_P2                   =>     (x"19"),
--        PD_TRANS_TIME_TO_P2                     =>     (x"64"),
--        SAS_MAX_COM                             =>     (64),
--        SAS_MIN_COM                             =>     (36),
--        SATA_BURST_SEQ_LEN                      =>     ("1111"),
--        SATA_BURST_VAL                          =>     ("100"),
--        SATA_CPLL_CFG                           =>     ("VCO_3000MHZ"),
--        SATA_EIDLE_VAL                          =>     ("100"),
--        SATA_MAX_BURST                          =>     (8),
--        SATA_MAX_INIT                           =>     (21),
--        SATA_MAX_WAKE                           =>     (7),
--        SATA_MIN_BURST                          =>     (4),
--        SATA_MIN_INIT                           =>     (12),
--        SATA_MIN_WAKE                           =>     (4),
--        TERM_RCAL_CFG                           =>     ("10000"),
--        TERM_RCAL_OVRD                          =>     ('0'),
--        TRANS_TIME_RATE                         =>     (x"0E"),
--        TST_RSV                                 =>     (x"00000000"),
--
--       --------------TX Buffering and Phase Alignment----------------
--        TXBUF_EN                                =>     ("TRUE"),
--        TXBUF_RESET_ON_RATE_CHANGE              =>     ("TRUE"),
--        TXDLY_CFG                               =>     (x"001F"),
--        TXDLY_LCFG                              =>     (x"030"),
--        TXDLY_TAP_CFG                           =>     (x"0000"),
--        TXPH_CFG                                =>     (x"0780"),
--        TXPHDLY_CFG                             =>     (x"084020"),
--        TXPH_MONITOR_SEL                        =>     ("00000"),
--        TX_XCLK_SEL                             =>     ("TXOUT"),
--
--       -------------------------TX Interface-------------------------
--        TX_DATA_WIDTH                           =>     (40),
--        TX_DEEMPH0                              =>     ("00000"),
--        TX_DEEMPH1                              =>     ("00000"),
--        TX_INT_DATAWIDTH                        =>     (1),
--        TX_CLKMUX_PD                            =>     ('1'),
--        TX_CLK25_DIV                            =>     (6),
--
--       ----------------TX Driver and OOB Signalling------------------
--        TX_EIDLE_ASSERT_DELAY                   =>     ("110"),
--        TX_EIDLE_DEASSERT_DELAY                 =>     ("100"),
--        TX_LOOPBACK_DRIVE_HIZ                   =>     ("FALSE"),
--        TX_MAINCURSOR_SEL                       =>     ('0'),
--        TX_DRIVE_MODE                           =>     ("DIRECT"),
--
--       -------------------------TX Gearbox---------------------------
--        TXGEARBOX_EN                            =>     ("FALSE"),
--
--       ------------------TX Attributes for PCI Express---------------
--        TX_MARGIN_FULL_0                        =>     ("1001110"),
--        TX_MARGIN_FULL_1                        =>     ("1001001"),
--        TX_MARGIN_FULL_2                        =>     ("1000101"),
--        TX_MARGIN_FULL_3                        =>     ("1000010"),
--        TX_MARGIN_FULL_4                        =>     ("1000000"),
--        TX_MARGIN_LOW_0                         =>     ("1000110"),
--        TX_MARGIN_LOW_1                         =>     ("1000100"),
--        TX_MARGIN_LOW_2                         =>     ("1000010"),
--        TX_MARGIN_LOW_3                         =>     ("1000000"),
--        TX_MARGIN_LOW_4                         =>     ("1000000"),
--        TXPCSRESET_TIME                         =>     ("00001"),
--        TXPMARESET_TIME                         =>     ("00001"),
--        TX_QPI_STATUS_EN                        =>     ('0'),
--        TX_RXDETECT_CFG                         =>     (x"1832"),
--        TX_RXDETECT_REF                         =>     ("100"),
--        UCODEER_CLR                             =>     ('0'),
--        RX_DFE_KL_CFG2                          =>     (RX_DFE_KL_CFG2_IN),
--        RX_DFE_XYD_CFG                          =>     ("0001100010000"),
--        TX_PREDRIVER_MODE                       =>     ('0')
--
--
--    )
--    port map
--    (
--                      ---------------------------------- Channel ---------------------------------
--        CFGRESET                        =>      tied_to_ground_i,
--        CLKRSVD                         =>      "0000",
--        DMONITOROUT                     =>      open,
--        GTRESETSEL                      =>      tied_to_ground_i,
--        GTRSVD                          =>      "0000000000000000",
--        QPLLCLK                         =>      QPLLCLK_IN,
--        QPLLREFCLK                      =>      QPLLREFCLK_IN,
--        RESETOVRD                       =>      tied_to_ground_i,
--        ---------------- Channel - Dynamic Reconfiguration Port (DRP) --------------
--        DRPADDR                         =>      DRPADDR_IN,
--        DRPCLK                          =>      DRPCLK_IN,
--        DRPDI                           =>      DRPDI_IN,
--        DRPDO                           =>      DRPDO_OUT,
--        DRPEN                           =>      DRPEN_IN,
--        DRPRDY                          =>      DRPRDY_OUT,
--        DRPWE                           =>      DRPWE_IN,
--        ------------------------- Channel - Ref Clock Ports ------------------------
--        GTGREFCLK                       =>      tied_to_ground_i,
--        GTNORTHREFCLK0                  =>      tied_to_ground_i,
--        GTNORTHREFCLK1                  =>      tied_to_ground_i,
--        GTREFCLK0                       =>      tied_to_ground_i,
--        GTREFCLK1                       =>      tied_to_ground_i,
--        GTREFCLKMONITOR                 =>      open,
--        GTSOUTHREFCLK0                  =>      tied_to_ground_i,
--        GTSOUTHREFCLK1                  =>      tied_to_ground_i,
--        -------------------------------- Channel PLL -------------------------------
--        CPLLFBCLKLOST                   =>      open,
--        CPLLLOCK                        =>      open,
--        CPLLLOCKDETCLK                  =>      tied_to_ground_i,
--        CPLLLOCKEN                      =>      tied_to_vcc_i,
--        CPLLPD                          =>      tied_to_vcc_i,
--        CPLLREFCLKLOST                  =>      open,
--        CPLLREFCLKSEL                   =>      "001",
--        CPLLRESET                       =>      tied_to_ground_i,
--        ------------------------------- Eye Scan Ports -----------------------------
--        EYESCANDATAERROR                =>      EYESCANDATAERROR_OUT,
--        EYESCANMODE                     =>      tied_to_ground_i,
--        EYESCANRESET                    =>      tied_to_ground_i,
--        EYESCANTRIGGER                  =>      tied_to_ground_i,
--        ------------------------ Loopback and Powerdown Ports ----------------------
--        LOOPBACK                        =>      tied_to_ground_vec_i(2 downto 0),
--        RXPD                            =>      "00",
--        TXPD                            =>      "00",
--        ----------------------------- PCS Reserved Ports ---------------------------
--        PCSRSVDIN                       =>      "0000000000000000",
--        PCSRSVDIN2                      =>      "00000",
--        PCSRSVDOUT                      =>      open,
--        ----------------------------- PMA Reserved Ports ---------------------------
--        PMARSVDIN                       =>      "00000",
--        PMARSVDIN2                      =>      "00000",
--        ------------------------------- Receive Ports ------------------------------
--        RXQPIEN                         =>      tied_to_ground_i,
--        RXQPISENN                       =>      open,
--        RXQPISENP                       =>      open,
--        RXSYSCLKSEL                     =>      "11",
--        RXUSERRDY                       =>      RXUSERRDY_IN,
--        -------------- Receive Ports - 64b66b and 64b67b Gearbox Ports -------------
--        RXDATAVALID                     =>      open,
--        RXGEARBOXSLIP                   =>      tied_to_ground_i,
--        RXHEADER                        =>      open,
--        RXHEADERVALID                   =>      open,
--        RXSTARTOFSEQ                    =>      open,
--        ----------------------- Receive Ports - 8b10b Decoder ----------------------
--        RX8B10BEN                       =>      tied_to_vcc_i,
--        RXCHARISCOMMA(7 downto 4)       =>      rxchariscomma_float_i,
--        RXCHARISCOMMA(3 downto 0)       =>      RXCHARISCOMMA_OUT,
--        RXCHARISK(7 downto 4)           =>      rxcharisk_float_i,
--        RXCHARISK(3 downto 0)           =>      RXCHARISK_OUT,
--        RXDISPERR(7 downto 4)           =>      rxdisperr_float_i,
--        RXDISPERR(3 downto 0)           =>      RXDISPERR_OUT,
--        RXNOTINTABLE(7 downto 4)        =>      rxnotintable_float_i,
--        RXNOTINTABLE(3 downto 0)        =>      RXNOTINTABLE_OUT,
--        ------------------- Receive Ports - Channel Bonding Ports ------------------
--        RXCHANBONDSEQ                   =>      open,
--        RXCHBONDEN                      =>      tied_to_ground_i,
--        RXCHBONDI                       =>      "00000",
--        RXCHBONDLEVEL                   =>      tied_to_ground_vec_i(2 downto 0),
--        RXCHBONDMASTER                  =>      tied_to_ground_i,
--        RXCHBONDO                       =>      open,
--        RXCHBONDSLAVE                   =>      tied_to_ground_i,
--        ------------------- Receive Ports - Channel Bonding Ports  -----------------
--        RXCHANISALIGNED                 =>      open,
--        RXCHANREALIGN                   =>      open,
--        ------------------- Receive Ports - Clock Correction Ports -----------------
--        RXCLKCORCNT                     =>      RXCLKCORCNT_OUT,
--        --------------- Receive Ports - Comma Detection and Alignment --------------
--        RXBYTEISALIGNED                 =>      RXBYTEISALIGNED_OUT,
--        RXBYTEREALIGN                   =>      open,
--        RXCOMMADET                      =>      RXCOMMADET_OUT,
--        RXCOMMADETEN                    =>      tied_to_vcc_i,
--        RXMCOMMAALIGNEN                 =>      RXMCOMMAALIGNEN_IN,
--        RXPCOMMAALIGNEN                 =>      RXPCOMMAALIGNEN_IN,
--        RXSLIDE                         =>      tied_to_ground_i,
--        ----------------------- Receive Ports - PRBS Detection ---------------------
--        RXPRBSCNTRESET                  =>      tied_to_ground_i,
--        RXPRBSERR                       =>      open,
--        RXPRBSSEL                       =>      tied_to_ground_vec_i(2 downto 0),
--        ------------------- Receive Ports - RX Data Path interface -----------------
--        GTRXRESET                       =>      GTRXRESET_IN,
--        RXDATA                          =>      rxdata_i,
--        RXOUTCLK                        =>      open,
--        RXOUTCLKFABRIC                  =>      open,
--        RXOUTCLKPCS                     =>      open,
--        RXOUTCLKSEL                     =>      "010",
--        RXPCSRESET                      =>      RXPCSRESET_IN,
--        RXPMARESET                      =>      tied_to_ground_i,
--        RXUSRCLK                        =>      RXUSRCLK_IN,
--        RXUSRCLK2                       =>      RXUSRCLK2_IN,
--        ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
--        RXDFEAGCHOLD                    =>      tied_to_ground_i,
--        RXDFEAGCOVRDEN                  =>      tied_to_ground_i,
--        RXDFECM1EN                      =>      tied_to_ground_i,
--        RXDFELFHOLD                     =>      tied_to_ground_i,
--        RXDFELFOVRDEN                   =>      tied_to_vcc_i,
--        RXDFELPMRESET                   =>      tied_to_ground_i,
--        RXDFETAP2HOLD                   =>      tied_to_ground_i,
--        RXDFETAP2OVRDEN                 =>      tied_to_ground_i,
--        RXDFETAP3HOLD                   =>      tied_to_ground_i,
--        RXDFETAP3OVRDEN                 =>      tied_to_ground_i,
--        RXDFETAP4HOLD                   =>      tied_to_ground_i,
--        RXDFETAP4OVRDEN                 =>      tied_to_ground_i,
--        RXDFETAP5HOLD                   =>      tied_to_ground_i,
--        RXDFETAP5OVRDEN                 =>      tied_to_ground_i,
--        RXDFEUTHOLD                     =>      tied_to_ground_i,
--        RXDFEUTOVRDEN                   =>      tied_to_ground_i,
--        RXDFEVPHOLD                     =>      tied_to_ground_i,
--        RXDFEVPOVRDEN                   =>      tied_to_ground_i,
--        RXDFEVSEN                       =>      tied_to_ground_i,
--        RXDFEXYDEN                      =>      tied_to_ground_i,
--        RXDFEXYDHOLD                    =>      tied_to_ground_i,
--        RXDFEXYDOVRDEN                  =>      tied_to_ground_i,
--        RXMONITOROUT                    =>      open,
--        RXMONITORSEL                    =>      "00",
--        RXOSHOLD                        =>      tied_to_ground_i,
--        RXOSOVRDEN                      =>      tied_to_ground_i,
--        ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
--        GTXRXN                          =>      GTXRXN_IN,
--        GTXRXP                          =>      GTXRXP_IN,
--        RXCDRFREQRESET                  =>      tied_to_ground_i,
--        RXCDRHOLD                       =>      tied_to_ground_i,
--        RXCDRLOCK                       =>      RXCDRLOCK_OUT,
--        RXCDROVRDEN                     =>      tied_to_ground_i,
--        RXCDRRESET                      =>      tied_to_ground_i,
--        RXCDRRESETRSV                   =>      tied_to_ground_i,
--        RXELECIDLE                      =>      RXELECIDLE_OUT,
--        RXELECIDLEMODE                  =>      "00",
--        RXLPMEN                         =>      tied_to_ground_i,
--        RXLPMHFHOLD                     =>      tied_to_ground_i,
--        RXLPMHFOVRDEN                   =>      tied_to_ground_i,
--        RXLPMLFHOLD                     =>      tied_to_ground_i,
--        RXLPMLFKLOVRDEN                 =>      tied_to_ground_i,
--        RXOOBRESET                      =>      tied_to_ground_i,
--        -------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
--        RXBUFRESET                      =>      RXBUFRESET_IN,
--        RXBUFSTATUS                     =>      RXBUFSTATUS_OUT,
--        RXDDIEN                         =>      tied_to_ground_i,
--        RXDLYBYPASS                     =>      tied_to_vcc_i,
--        RXDLYEN                         =>      tied_to_ground_i,
--        RXDLYOVRDEN                     =>      tied_to_ground_i,
--        RXDLYSRESET                     =>      tied_to_ground_i,
--        RXDLYSRESETDONE                 =>      open,
--        RXPHALIGN                       =>      tied_to_ground_i,
--        RXPHALIGNDONE                   =>      open,
--        RXPHALIGNEN                     =>      tied_to_ground_i,
--        RXPHDLYPD                       =>      tied_to_ground_i,
--        RXPHDLYRESET                    =>      tied_to_ground_i,
--        RXPHMONITOR                     =>      open,
--        RXPHOVRDEN                      =>      tied_to_ground_i,
--        RXPHSLIPMONITOR                 =>      open,
--        RXSTATUS                        =>      open,
--        ------------------------ Receive Ports - RX PLL Ports ----------------------
--        RXRATE                          =>      RXRATE_IN,
--        RXRATEDONE                      =>      RXRATEDONE_OUT,
--        RXRESETDONE                     =>      RXRESETDONE_OUT,
--        -------------- Receive Ports - RX Pipe Control for PCI Express -------------
--        PHYSTATUS                       =>      PHYSTATUS_OUT,
--        RXVALID                         =>      open,
--        ----------------- Receive Ports - RX Polarity Control Ports ----------------
--        RXPOLARITY                      =>      tied_to_ground_i,
--        --------------------- Receive Ports - RX Ports for SATA --------------------
--        RXCOMINITDET                    =>      RXCOMINITDET_OUT,
--        RXCOMSASDET                     =>      RXCOMSASDET_OUT,
--        RXCOMWAKEDET                    =>      RXCOMWAKEDET_OUT,
--        ------------------------------- Transmit Ports -----------------------------
--        SETERRSTATUS                    =>      tied_to_ground_i,
--        TSTIN                           =>      "11111111111111111111",
--        TSTOUT                          =>      open,
--        TXPHDLYTSTCLK                   =>      tied_to_ground_i,
--        TXPOSTCURSOR                    =>      "00000",
--        TXPOSTCURSORINV                 =>      tied_to_ground_i,
--        TXPRECURSOR                     =>      tied_to_ground_vec_i(4 downto 0),
--        TXPRECURSORINV                  =>      tied_to_ground_i,
--        TXQPIBIASEN                     =>      tied_to_ground_i,
--        TXQPISENN                       =>      open,
--        TXQPISENP                       =>      open,
--        TXQPISTRONGPDOWN                =>      tied_to_ground_i,
--        TXQPIWEAKPUP                    =>      tied_to_ground_i,
--        TXSYSCLKSEL                     =>      "11",
--        TXUSERRDY                       =>      TXUSERRDY_IN,
--        -------------- Transmit Ports - 64b66b and 64b67b Gearbox Ports ------------
--        TXGEARBOXREADY                  =>      open,
--        TXHEADER                        =>      tied_to_ground_vec_i(2 downto 0),
--        TXSEQUENCE                      =>      tied_to_ground_vec_i(6 downto 0),
--        TXSTARTSEQ                      =>      tied_to_ground_i,
--        ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
--        TX8B10BBYPASS                   =>      tied_to_ground_vec_i(7 downto 0),
--        TX8B10BEN                       =>      tied_to_vcc_i,
--        TXCHARDISPMODE                  =>      tied_to_ground_vec_i(7 downto 0),
--        TXCHARDISPVAL                   =>      tied_to_ground_vec_i(7 downto 0),
--        TXCHARISK(7 downto 4)           =>      tied_to_ground_vec_i(3 downto 0),
--        TXCHARISK(3 downto 0)           =>      TXCHARISK_IN,
--        ------------ Transmit Ports - TX Buffer and Phase Alignment Ports ----------
--        TXBUFSTATUS                     =>      TXBUFSTATUS_OUT,
--        TXDLYBYPASS                     =>      tied_to_vcc_i,
--        TXDLYEN                         =>      tied_to_ground_i,
--        TXDLYHOLD                       =>      tied_to_ground_i,
--        TXDLYOVRDEN                     =>      tied_to_ground_i,
--        TXDLYSRESET                     =>      tied_to_ground_i,
--        TXDLYSRESETDONE                 =>      open,
--        TXDLYUPDOWN                     =>      tied_to_ground_i,
--        TXPHALIGN                       =>      tied_to_ground_i,
--        TXPHALIGNDONE                   =>      open,
--        TXPHALIGNEN                     =>      tied_to_ground_i,
--        TXPHDLYPD                       =>      tied_to_ground_i,
--        TXPHDLYRESET                    =>      tied_to_ground_i,
--        TXPHINIT                        =>      tied_to_ground_i,
--        TXPHINITDONE                    =>      open,
--        TXPHOVRDEN                      =>      tied_to_ground_i,
--        ------------------ Transmit Ports - TX Data Path interface -----------------
--        GTTXRESET                       =>      GTTXRESET_IN,
--        TXDATA                          =>      txdata_i,
--        TXOUTCLK                        =>      TXOUTCLK_OUT,
--        TXOUTCLKFABRIC                  =>      TXOUTCLKFABRIC_OUT,
--        TXOUTCLKPCS                     =>      TXOUTCLKPCS_OUT,
--        TXOUTCLKSEL                     =>      "010",
--        TXPCSRESET                      =>      TXPCSRESET_IN,
--        TXPMARESET                      =>      tied_to_ground_i,
--        TXUSRCLK                        =>      TXUSRCLK_IN,
--        TXUSRCLK2                       =>      TXUSRCLK2_IN,
--        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
--        GTXTXN                          =>      GTXTXN_OUT,
--        GTXTXP                          =>      GTXTXP_OUT,
--        TXBUFDIFFCTRL                   =>      "100",
--        TXDIFFCTRL                      =>      "1000",
--        TXDIFFPD                        =>      tied_to_ground_i,
--        TXINHIBIT                       =>      TXINHIBIT_IN,
--        TXMAINCURSOR                    =>      "0000000",
--        TXPDELECIDLEMODE                =>      tied_to_ground_i,
--        TXPISOPD                        =>      tied_to_ground_i,
--        ----------------------- Transmit Ports - TX PLL Ports ----------------------
--        TXRATE                          =>      TXRATE_IN,
--        TXRATEDONE                      =>      TXRATEDONE_OUT,
--        TXRESETDONE                     =>      TXRESETDONE_OUT,
--        --------------------- Transmit Ports - TX PRBS Generator -------------------
--        TXPRBSFORCEERR                  =>      tied_to_ground_i,
--        TXPRBSSEL                       =>      tied_to_ground_vec_i(2 downto 0),
--        -------------------- Transmit Ports - TX Polarity Control ------------------
--        TXPOLARITY                      =>      tied_to_ground_i,
--        ----------------- Transmit Ports - TX Ports for PCI Express ----------------
--        TXDEEMPH                        =>      TXDEEMPH_IN,
--        TXDETECTRX                      =>      TXDETECTRX_IN,
--        TXELECIDLE                      =>      TXELECIDLE_IN,
--        TXMARGIN                        =>      TXMARGIN_IN,
--        TXSWING                         =>      TXSWING_IN,
--        --------------------- Transmit Ports - TX Ports for SATA -------------------
--        TXCOMFINISH                     =>      TXCOMFINISH_OUT,
--        TXCOMINIT                       =>      TXCOMINIT_IN,
--        TXCOMSAS                        =>      TXCOMSAS_IN,
--        TXCOMWAKE                       =>      TXCOMWAKE_IN
--
--    );
		
		
		TX_n(I)			<= GTX_TX_n;
		TX_p(I)			<= GTX_TX_p;
		
		GTX_RX_n		<= RX_n(I);
		GTX_RX_p		<= RX_p(I);
	END GENERATE;
END;