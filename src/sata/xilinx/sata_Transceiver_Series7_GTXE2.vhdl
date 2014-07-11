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


ENTITY sata_Transceiver_Series7_GTXE2 IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																	-- 150 MHz
		PORTS											: POSITIVE										:= 2;																			-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3	=> T_SATA_GENERATION'high)			-- intial SATA Generation
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
		
		Command										: IN	T_SATA_TRANS_COMMAND_VECTOR(PORTS	- 1 DOWNTO 0);
		Status										: OUT	T_SATA_TRANS_STATUS_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_Error									: OUT	T_SATA_RX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_Error									: OUT	T_SATA_TX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);

		RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_Data										: OUT	T_SLVV_32(PORTS	- 1 DOWNTO 0);
		RX_CharIsK								: OUT	T_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		
		TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_Data										: IN	T_SLVV_32(PORTS	- 1 DOWNTO 0);
		TX_CharIsK								: IN	T_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
		
		-- vendor specific signals (Xilinx)
		VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS - 1 DOWNTO 0);
		VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF sata_Transceiver_Series7_GTXE2 IS
	ATTRIBUTE KEEP 														: BOOLEAN;

--	==================================================================
-- SATATransceiver configuration
--	==================================================================
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
--	==================================================================
-- Assert statements
--	==================================================================
	ASSERT (VENDOR	= VENDOR_XILINX)		REPORT "Vendor not yet supported."				SEVERITY FAILURE;
	ASSERT (DEVFAM	= DEVFAM_VIRTEX)		REPORT "Device family not yet supported."	SEVERITY FAILURE;
--	ASSERT (DEVICE	= DEVICE_VIRTEX6)	REPORT "Device not yet supported."				SEVERITY FAILURE;
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
	
--	==================================================================
-- data path buffers
--	==================================================================
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
		
		WA_Data : ENTITY PoC.WordAligner
			GENERIC MAP (
				REGISTERED					=> FALSE,
				INPUT_BITS						=> 32,
				WORD_BITS							=> 16
			)
			PORT MAP (
				Clock								=> GTX_ClockRX_4X,
				Align								=> WA_Align,
				I										=> GTX_RX_Data,
				O										=> RX_Data(I,
				Valid								=> OPEN
			);

		WA_CharIsK : ENTITY PoC.WordAligner
			GENERIC MAP (
				REGISTERED					=> FALSE,
				INPUT_BITS						=> 4,
				WORD_BITS							=> 2
			)
			PORT MAP (
				Clock								=> GTX_ClockRX_4X,
				Align								=> WA_Align,
				I										=> GTX_RX_CharIsK,
				O										=> RX_CharIsK(I,
				Valid								=> OPEN
			);
		
		RX_IsAligned(I)					<= GTX_RX_ByteIsAligned;


		--	==================================================================
		-- ResetControl
		--	==================================================================
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
		GTX_Reset											<= to_sl(Command(I)	= TRANS_CMD_RESET) OR Reset(I);
		GTX_TX_Reset									<= GTX_Reset;
		GTX_RX_Reset									<= GTX_Reset;
		
		GTX_ResetDone									<= GTX_TX_ResetDone AND GTX_RX_ResetDone;									-- @GTX_Clock_4X
		ResetDone(I)									<= GTX_ResetDone;																					-- @GTX_Clock_4X

		--	==================================================================
		-- ClockNetwork (75, 150 MHz)
		--	==================================================================
		GTX_TX_RefClockIn							<= (0	=> '0', 1	=> ClockIn_150MHz);
		GTX_RX_RefClockIn							<= (0	=> '0', 1	=> ClockIn_150MHz);
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

		--	==================================================================
		-- OOB signaling
		--	==================================================================
		TX_OOBCommand_d								<= TX_OOBCommand(I);	-- WHEN rising_edge(GTX_ClockTX_2X(I));

		-- TX OOB signals (generate GTX specific OOB signals)
		PROCESS(TX_OOBCommand_d)
		BEGIN
			GTX_TX_ComStart			<= '0';
			GTX_TX_ComInit			<= '0';
			GTX_TX_ComWake			<= '0';
		
			CASE TX_OOBCommand_d IS
				WHEN OOB_NONE	=>
					NULL;
				
				WHEN OOB_READY	=>
					NULL;
				
				WHEN OOB_COMRESET	=>
					GTX_TX_ComStart	<= '1';
					GTX_TX_ComInit	<= '1';
				
				WHEN OOB_COMWAKE	=>
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
				IF (Reset(I)	= '1') THEN
					GTX_TX_ElectricalIDLE				<= '0';
				ELSE
					IF (GTX_TX_ComStart	= '1') THEN
						GTX_TX_ElectricalIDLE			<= '1';
					ELSIF (GTX_TX_OOBComplete	= '1') THEN
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
		
			IF (GTX_RX_ElectricalIDLE	= '1') THEN
				RX_OOBStatus_i					<= OOB_READY;
			
				IF (GTX_RX_ComInit	= '1') THEN
					RX_OOBStatus_i				<= OOB_COMRESET;
				ELSIF (GTX_RX_ComWake	= '1') THEN
					RX_OOBStatus_i				<= OOB_COMWAKE;
				END IF;
			END IF;
		END PROCESS;

		--RX_OOBStatus_d		<= RX_OOBStatus_i;		-- WHEN rising_edge(SATA_Clock_i(I));
		RX_OOBStatus(I)		<= RX_OOBStatus_i;

		--	==================================================================
		-- error handling
		--	==================================================================
		-- TX errors
		PROCESS(GTX_TX_InvalidK, GTX_TX_BufferStatus(1))
		BEGIN
			TX_Error_i		<= TX_ERROR_NONE;
		
			IF (slv_or(GTX_TX_InvalidK)	= '1') THEN
				TX_Error_i	<= TX_ERROR_ENCODER;
			ELSIF (GTX_TX_BufferStatus(1)	= '1') THEN
				TX_Error_i	<= TX_ERROR_BUFFER;
			END IF;
		END PROCESS;
		
		-- RX errors
		PROCESS(GTX_RX_ByteIsAligned, GTX_RX_DisparityError, GTX_RX_Illegal8B10BCode, GTX_RX_BufferStatus(2))
		BEGIN
			RX_Error_i		<= RX_ERROR_NONE;
		
			IF (GTX_RX_ByteIsAligned	= '0') THEN
				RX_Error_i	<= RX_ERROR_ALIGNEMENT;
			ELSIF (slv_or(GTX_RX_DisparityError)	= '1') THEN
				RX_Error_i	<= RX_ERROR_DISPARITY;
			ELSIF (slv_or(GTX_RX_Illegal8B10BCode)	= '1') THEN
				RX_Error_i	<= RX_ERROR_DECODER;
			ELSIF (GTX_RX_BufferStatus(2)	= '1') THEN
				RX_Error_i	<= RX_ERROR_BUFFER;
			END IF;
		END PROCESS;

		TX_Error(I)										<= TX_Error_i;
		RX_Error(I)										<= RX_Error_i;

		--	==================================================================
		-- Transceiver status
		--	==================================================================
		-- device detection
		DD : ENTITY PoC.sata_DeviceDetector
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

		Sync1 : ENTITY PoC.misc_Synchronizer
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
			
			IF (GTX_ResetDone	= '0') THEN
				Status(I)							<= TRANS_STATUS_RESET;
			ELSIF (DD_NoDevice	= '1') THEN
				Status(I)							<= TRANS_STATUS_NO_DEVICE;
			ELSIF ((TX_Error_i /= TX_ERROR_NONE) OR (RX_Error_i /= RX_ERROR_NONE)) THEN
				Status(I)							<= TRANS_STATUS_ERROR;
			ELSIF (DD_NewDevice	= '1') THEN
				Status(I)							<= TRANS_STATUS_NEW_DEVICE;
				
-- TODO:
-- TRANS_STATUS_POWERED_DOWN,
-- TRANS_STATUS_CONFIGURATION,

			END IF;
		END PROCESS;
	
--	==================================================================
-- LineRate control
--	==================================================================
		PROCESS(GTX_Clock_4X)
		BEGIN
			IF rising_edge(GTX_Clock_4X) THEN
				IF (RP_Reconfig(I)	= '1') THEN
					IF (SATA_Generation(I)	= SATA_GEN_1) THEN
						GTX_TX_LineRate		<= "10";								-- TXPLL Divider (D)	= 2
						GTX_RX_LineRate		<= "10";								-- rXPLL Divider (D)	= 2
					ELSIF (SATA_Generation(I)	= SATA_GEN_2) THEN
						GTX_TX_LineRate		<= "11";								-- TXPLL Divider (D)	= 1
						GTX_RX_LineRate		<= "11";								-- rXPLL Divider (D)	= 1
					ELSE
						NULL;
					END IF;
				END IF;
			END IF;
		END PROCESS;

		RP_Locked(I)									<= '0';																											-- all ports are independant	=> never set a lock
		RP_ReconfigComplete(I)				<= RP_Reconfig(I) WHEN rising_edge(GTX_Clock_4X);						-- acknoledge reconfiguration with 1 cycle latency

		-- SR-FF for GTX_*_LineRate_Locked:
		--		.set	= GTX_*_LineRate_Changed
		--		.rst	= RP_Reconfig(I)
		PROCESS(GTX_Clock_4X)
		BEGIN
			IF rising_edge(GTX_Clock_4X) THEN
				IF (RP_Reconfig(I)	= '1') THEN
					GTX_TX_LineRate_Locked		<= '0';
					GTX_RX_LineRate_Locked		<= '0';
				ELSE
					IF (GTX_TX_LineRate_Changed	= '1') THEN
						GTX_TX_LineRate_Locked	<= '1';
					END IF;
					IF (GTX_RX_LineRate_Changed	= '1') THEN
						GTX_RX_LineRate_Locked	<= '1';
					END IF;
				END IF;
			END IF;
		END PROCESS;
		
		GTX_LineRate_Locked						<= GTX_TX_LineRate_Locked AND GTX_RX_LineRate_Locked;
		RP_ConfigReloaded(I)					<= GTX_LineRate_Locked AND ClockNetwork_ResetDone_i;

--	==================================================================
-- GTXE2_CHANNEL instance for Port I
--	==================================================================
		GTX : GTXE2_CHANNEL
			GENERIC MAP (
				--	===================== Simulation-Only Attributes	===================
				SIM_RECEIVER_DETECT_PASS								=> TRUE,
				SIM_GTXRESET_SPEEDUP										=> "TRUE",																-- set to "TRUE" to speed up simulation reset
				SIM_TX_EIDLE_DRIVE_LEVEL								=> "X",
				SIM_VERSION															=> "4.0",
				SIM_CPLLREFCLK_SEL											=> "001",																	-- 

				------------------RX Byte and Word Alignment Attributes---------------
				ALIGN_COMMA_DOUBLE											=> "FALSE",
				ALIGN_COMMA_ENABLE											=> "1111111111",
--diff 1				ALIGN_COMMA_WORD												=> 4,
				ALIGN_MCOMMA_DET												=> "TRUE",
				ALIGN_MCOMMA_VALUE											=> "1010000011",
				ALIGN_PCOMMA_DET												=> "TRUE",
				ALIGN_PCOMMA_VALUE											=> "0101111100",
--new				SHOW_REALIGN_COMMA											=> "TRUE",
--new				RXSLIDE_AUTO_WAIT												=> 7,
--diff PCS				RXSLIDE_MODE														=> "OFF",
--new				RX_SIG_VALID_DLY												=> 10,

				-----------------RX 8B/10B Decoder Attributes---------------
--new				RX_DISPERR_SEQ_MATCH										=> "TRUE",
				DEC_MCOMMA_DETECT												=> "TRUE",
				DEC_PCOMMA_DETECT												=> "TRUE",
				DEC_VALID_COMMA_ONLY										=> "FALSE",

				-----------------------RX Clock Correction Attributes----------------------
				CLK_CORRECT_USE													=> "TRUE",
--new				CBCC_DATA_SOURCE_SEL										=> "DECODED",
				CLK_COR_KEEP_IDLE												=> "FALSE",
--diff 16				CLK_COR_MIN_LAT													=> 24,
--diff 22				CLK_COR_MAX_LAT													=> 31,
				CLK_COR_PRECEDENCE											=> "TRUE",
				CLK_COR_REPEAT_WAIT											=> 0,
				CLK_COR_SEQ_LEN													=> 4,
				CLK_COR_SEQ_1_ENABLE										=> "1111",
				CLK_COR_SEQ_1_1													=> "0110111100",
				CLK_COR_SEQ_1_2													=> "0001001010",
				CLK_COR_SEQ_1_3													=> "0001001010",
				CLK_COR_SEQ_1_4													=> "0001111011",
				CLK_COR_SEQ_2_USE												=> "FALSE",
				CLK_COR_SEQ_2_ENABLE										=> "1111",
				CLK_COR_SEQ_2_1													=> "0000000000",
				CLK_COR_SEQ_2_2													=> "0000000000",
				CLK_COR_SEQ_2_3													=> "0000000000",
				CLK_COR_SEQ_2_4													=> "0000000000",

				-----------------------RX Channel Bonding Attributes----------------------
--new				CHAN_BOND_KEEP_ALIGN										=> "FALSE",
--diff 7				CHAN_BOND_MAX_SKEW											=> 1,
				CHAN_BOND_SEQ_LEN												=> 1,
--diff 0000				CHAN_BOND_SEQ_1_ENABLE									=> "1111",
				CHAN_BOND_SEQ_1_1												=> "0000000000",
				CHAN_BOND_SEQ_1_2												=> "0000000000",
				CHAN_BOND_SEQ_1_3												=> "0000000000",
				CHAN_BOND_SEQ_1_4												=> "0000000000",
				CHAN_BOND_SEQ_2_USE											=> "FALSE",
--diff 0000				CHAN_BOND_SEQ_2_ENABLE									=> "1111",
			CHAN_BOND_SEQ_2_1												=> "0000000000",
			CHAN_BOND_SEQ_2_2												=> "0000000000",
			CHAN_BOND_SEQ_2_3												=> "0000000000",
			CHAN_BOND_SEQ_2_4												=> "0000000000",
--new				FTS_DESKEW_SEQ_ENABLE										=> "1111",
--new				FTS_LANE_DESKEW_CFG											=> "1111",
--new				FTS_LANE_DESKEW_EN											=> "FALSE",

				--------------------------RX Margin Analysis Attributes----------------------------
--new				ES_CONTROL															=> "000000",
--new				ES_ERRDET_EN														=> "FALSE",
--new				ES_EYE_SCAN_EN													=> "TRUE",
--new				ES_HORZ_OFFSET													=> x"000",
--new				ES_PMA_CFG															=> "0000000000",
--new				ES_PRESCALE															=> "00000",
--new				ES_QUALIFIER														=> x"00000000000000000000",
--new				ES_QUAL_MASK														=> x"00000000000000000000",
--new				ES_SDATA_MASK														=> x"00000000000000000000",
--new				ES_VERT_OFFSET													=> "000000000",

				------------------------FPGA RX Interface Attributes-------------------------
				RX_DATA_WIDTH														=> 40,

				--------------------------PMA Attributes----------------------------
--				OUTREFCLK_SEL_INV												=> "11",
--				PMA_RSV																	=> PMA_RSV_IN,
--				PMA_RSV2																=> x"2050",
--				PMA_RSV3																=> "00",
--				PMA_RSV4																=> x"00000000",
--				RX_BIAS_CFG															=> "000000000100",
--				DMONITOR_CFG														=> x"000A00",
--				RX_CM_SEL																=> "11",
--				RX_CM_TRIM															=> "010",
--				RX_DEBUG_CFG														=> "000000000000",
--				RX_OS_CFG																=> "0000010000000",
--				TERM_RCAL_CFG														=> "10000",
--				TERM_RCAL_OVRD													=> '0',
--				TST_RSV																	=> x"00000000",
--				RX_CLK25_DIV														=> 6,
--				TX_CLK25_DIV														=> 6,
--				UCODEER_CLR															=> '0',

				--------------------------PCI Express Attributes----------------------------
				PCS_PCIE_EN															=> "FALSE",

				--------------------------PCS Attributes----------------------------
--				PCS_RSVD_ATTR														=> PCS_RSVD_ATTR_IN,

				------------RX Buffer Attributes------------
--				RXBUF_ADDR_MODE													=> "FULL",
--				RXBUF_EIDLE_HI_CNT											=> "1000",
--				RXBUF_EIDLE_LO_CNT											=> "0000",
				RXBUF_EN																=> "TRUE",
--				RX_BUFFER_CFG														=> "000000",
--				RXBUF_RESET_ON_CB_CHANGE								=> "TRUE",
--				RXBUF_RESET_ON_COMMAALIGN								=> "FALSE",
--				RXBUF_RESET_ON_EIDLE										=> "FALSE",
--				RXBUF_RESET_ON_RATE_CHANGE							=> "TRUE",
--				RXBUFRESET_TIME													=> "00001",
--				RXBUF_THRESH_OVFLW											=> 61,
--				RXBUF_THRESH_OVRD												=> "FALSE",
--				RXBUF_THRESH_UNDFLW											=> 4,
--				RXDLY_CFG																=> x"001F",
--				RXDLY_LCFG															=> x"030",
--				RXDLY_TAP_CFG														=> x"0000",
--				RXPH_CFG																=> x"000000",
--				RXPHDLY_CFG															=> x"084020",
--				RXPH_MONITOR_SEL												=> "00000",
				RX_XCLK_SEL															=> "RXREC",
--				RX_DDI_SEL															=> "000000",
--				RX_DEFER_RESET_BUF_EN										=> "TRUE",

				----------------------CDR Attributes-------------------------

--				--For GTX only: Display Port, HBR/RBR- set RXCDR_CFG=72'h0380008bff40200008

--				--For GTX only: Display Port, HBR2 -	 set RXCDR_CFG=72'h038C008bff20200010
--				RXCDR_CFG																=> x"03000023ff20400020",
--				RXCDR_FR_RESET_ON_EIDLE									=> '0',
--				RXCDR_HOLD_DURING_EIDLE									=> '0',
--				RXCDR_PH_RESET_ON_EIDLE									=> '0',
--				RXCDR_LOCK_CFG													=> "010101",

				------------------RX Initialization and Reset Attributes-------------------
--				RXCDRFREQRESET_TIME											=> "00001",
--				RXCDRPHRESET_TIME												=> "00001",
--				RXISCANRESET_TIME												=> "00001",
--				RXPCSRESET_TIME													=> "00001",
--				RXPMARESET_TIME													=> "00011",

				------------------RX OOB Signaling Attributes-------------------
--				RXOOB_CFG																=> "0000110",

				------------------------RX Gearbox Attributes---------------------------
--				RXGEARBOX_EN														=> "FALSE",
--				GEARBOX_MODE														=> "000",

				------------------------PRBS Detection Attribute-----------------------
--				RXPRBS_ERR_LOOPBACK											=> '0',

				------------Power-Down Attributes----------
--diff				PD_TRANS_TIME_FROM_P2										=> x"03c",
--diff				PD_TRANS_TIME_NONE_P2										=> x"3c",
--diff				PD_TRANS_TIME_TO_P2											=> x"64",

				------------RX OOB Signaling Attributes----------
--new				SAS_MAX_COM															=> 64,
--new				SAS_MIN_COM															=> 36,
				SATA_BURST_SEQ_LEN											=> "0110",

-- recalculate upon OOB timing counter
				SATA_BURST_VAL													=> "100",
				SATA_EIDLE_VAL													=> "011",
				SATA_MIN_BURST													=> 4,
				SATA_MAX_BURST													=> 7,
				SATA_MIN_INIT														=> 12,
				SATA_MAX_INIT														=> 22,
				SATA_MIN_WAKE														=> 4,
				SATA_MAX_WAKE														=> 7,

				------------RX Fabric Clock Output Control Attributes----------
--				TRANS_TIME_RATE													=> x"0E",

				-------------TX Buffer Attributes----------------
				TXBUF_EN																=> "TRUE",
--				TXBUF_RESET_ON_RATE_CHANGE							=> "TRUE",
--				TXDLY_CFG																=> x"001F",
--				TXDLY_LCFG															=> x"030",
--				TXDLY_TAP_CFG														=> x"0000",
--				TXPH_CFG																=> x"0780",
--				TXPHDLY_CFG															=> x"084020",
--				TXPH_MONITOR_SEL												=> "00000",
				TX_XCLK_SEL															=> "TXOUT",

				------------------------FPGA TX Interface Attributes-------------------------
				TX_DATA_WIDTH														=> 40,

				------------------------TX Configurable Driver Attributes-------------------------
--				TX_DEEMPH0															=> "00000",
--				TX_DEEMPH1															=> "00000",
--				TX_EIDLE_ASSERT_DELAY										=> "110",
--				TX_EIDLE_DEASSERT_DELAY									=> "100",
--				TX_LOOPBACK_DRIVE_HIZ										=> "FALSE",
--				TX_MAINCURSOR_SEL												=> '0',
--				TX_DRIVE_MODE														=> "DIRECT",
--				TX_MARGIN_FULL_0												=> "1001110",
--				TX_MARGIN_FULL_1												=> "1001001",
--				TX_MARGIN_FULL_2												=> "1000101",
--				TX_MARGIN_FULL_3												=> "1000010",
--				TX_MARGIN_FULL_4												=> "1000000",
--				TX_MARGIN_LOW_0													=> "1000110",
--				TX_MARGIN_LOW_1													=> "1000100",
--				TX_MARGIN_LOW_2													=> "1000010",
--				TX_MARGIN_LOW_3													=> "1000000",
--				TX_MARGIN_LOW_4													=> "1000000",

				------------------------TX Gearbox Attributes--------------------------
--				TXGEARBOX_EN														=> "FALSE",

				------------------------TX Initialization and Reset Attributes--------------------------
--				TXPCSRESET_TIME													=> "00001",
--				TXPMARESET_TIME													=> "00001",

				------------------------TX Receiver Detection Attributes--------------------------
--				TX_RXDETECT_CFG													=> x"1832",
--				TX_RXDETECT_REF													=> "100",

				---------------------------CPLL Attributes----------------------------
--				CPLL_CFG																=> x"BC07DC",
--				CPLL_FBDIV															=> 4,
--				CPLL_FBDIV_45														=> 5,
--				CPLL_INIT_CFG														=> x"00001E",
--				CPLL_LOCK_CFG														=> x"01E8",
--				CPLL_REFCLK_DIV													=> 1,
--				RXOUT_DIV																=> 1,
--				TXOUT_DIV																=> 1,
--				SATA_CPLL_CFG														=> "VCO_3000MHZ",

				-------------RX Initialization and Reset Attributes-------------
--				RXDFELPMRESET_TIME											=> "0001111",

				-------------RX Equalizer Attributes-------------
--				RXLPM_HF_CFG														=> "00000011110000",
--				RXLPM_LF_CFG														=> "00000011110000",
--				RX_DFE_GAIN_CFG													=> x"020FEA",
--				RX_DFE_H2_CFG														=> "000000000000",
--				RX_DFE_H3_CFG														=> "000001000000",
--				RX_DFE_H4_CFG														=> "00011110000",
--				RX_DFE_H5_CFG														=> "00011100000",
--				RX_DFE_KL_CFG														=> "0000011111110",
--				RX_DFE_LPM_CFG													=> x"0954",
--				RX_DFE_LPM_HOLD_DURING_EIDLE						=> '0',
--				RX_DFE_UT_CFG														=> "10001111000000000",
--				RX_DFE_VP_CFG														=> "00011111100000011",

				------------------------Power-Down Attributes-------------------------
--				RX_CLKMUX_PD														=> '1',
--				TX_CLKMUX_PD														=> '1',

				------------------------FPGA RX Interface Attribute-------------------------
--				RX_INT_DATAWIDTH												=> 1,

				------------------------FPGA TX Interface Attribute-------------------------
--				TX_INT_DATAWIDTH												=> 1,

				-----------------TX Configurable Driver Attributes---------------
--				TX_QPI_STATUS_EN												=> '0',

				------------------------RX Equalizer Attributes--------------------------
--				RX_DFE_KL_CFG2													=> RX_DFE_KL_CFG2_IN,
--				RX_DFE_XYD_CFG													=> "0000000000000",

				------------------------TX Configurable Driver Attributes--------------------------
--				TX_PREDRIVER_MODE												=> '0'
			)
			PORT MAP (
				--------------------------------- CPLL Ports -------------------------------
--				CPLLFBCLKLOST										=> CPLLFBCLKLOST_OUT,
				CPLLLOCK												=> ChannelPLL_Locked,
--				CPLLLOCKDETCLK									=> CPLLLOCKDETCLK_IN,
--				CPLLLOCKEN											=> '1',
--				CPLLPD													=> '0',
--				CPLLREFCLKLOST									=> CPLLREFCLKLOST_OUT,
--				CPLLREFCLKSEL										=> "001",
--				CPLLRESET												=> CPLLRESET_IN,
--				GTRSVD													=> "0000000000000000",
--				PCSRSVDIN												=> "0000000000000000",
--				PCSRSVDIN2											=> "00000",
--				PMARSVDIN												=> "00000",
--				PMARSVDIN2											=> "00000",
--				TSTIN														=> "11111111111111111111",
--				TSTOUT													=> open,
				---------------------------------- Channel ---------------------------------
--				CLKRSVD													=> "0000",
				-------------------------- Channel - Clocking Ports ------------------------
--				GTGREFCLK												=> GTGREFCLK_IN,
--				GTNORTHREFCLK0									=> GTNORTHREFCLK0_IN,
--				GTNORTHREFCLK1									=> GTNORTHREFCLK1_IN,
--				GTREFCLK0												=> GTREFCLK0_IN,
--				GTREFCLK1												=> GTREFCLK1_IN,
--				GTSOUTHREFCLK0									=> GTSOUTHREFCLK0_IN,
--				GTSOUTHREFCLK1									=> GTSOUTHREFCLK1_IN,
				---------------------------- Channel - DRP Ports	--------------------------
				DRPCLK													=> GTX_DRP_Clock,
				DRPEN														=> GTX_DRP_en,
				DRPWE														=> GTX_DRP_we,
				DRPADDR													=> GTX_DRP_Address,
				DRPDI														=> GTX_DRP_DataIn,
				DRPDO														=> GTX_DRP_DataOut,
				DRPRDY													=> GTX_DRP_Ready,
				------------------------------- Clocking Ports -----------------------------
--				GTREFCLKMONITOR									=> open,
--				QPLLCLK													=> QPLLCLK_IN,
--				QPLLREFCLK											=> QPLLREFCLK_IN,
--				RXSYSCLKSEL											=> "00",
--				TXSYSCLKSEL											=> "00",
				--------------------------- Digital Monitor Ports --------------------------
--				DMONITOROUT											=> open,
				----------------- FPGA TX Interface Datapath Configuration	----------------
				TX8B10BEN												=> '1',
				------------------------------- Loopback Ports -----------------------------
--				LOOPBACK												=> (2 downto 0 => '0'),
				----------------------------- PCI Express Ports ----------------------------
--				PHYSTATUS												=> PHYSTATUS_OUT,
--				RXRATE													=> RXRATE_IN,
--				RXVALID													=> RXVALID_OUT,
				------------------------------ Power-Down Ports ----------------------------
				RXPD														=> GTX_RX_PowerDown(I),
				TXPD														=> GTX_TX_PowerDown(I),
				-------------------------- RX 8B/10B Decoder Ports -------------------------
--				SETERRSTATUS										=> '0',
				--------------------- RX Initialization and Reset Ports --------------------
--				EYESCANRESET										=> '0',
--				RXUSERRDY												=> RXUSERRDY_IN,
				-------------------------- RX Margin Analysis Ports ------------------------
--				EYESCANDATAERROR								=> EYESCANDATAERROR_OUT,
--				EYESCANMODE											=> '0',
--				EYESCANTRIGGER									=> '0',
				------------------------- Receive Ports - CDR Ports ------------------------
--				RXCDRFREQRESET									=> '0',
--				RXCDRHOLD												=> '0',
--				RXCDRLOCK												=> RXCDRLOCK_OUT,
--				RXCDROVRDEN											=> '0',
--				RXCDRRESET											=> '0',
--				RXCDRRESETRSV										=> '0',
				------------------- Receive Ports - Clock Correction Ports -----------------
--				RXCLKCORCNT											=> RXCLKCORCNT_OUT,
				---------- Receive Ports - FPGA RX Interface Datapath Configuration --------
				RX8B10BEN												=> '1',
				------------------ Receive Ports - FPGA RX Interface Ports -----------------
--				RXUSRCLK												=> RXUSRCLK_IN,
--				RXUSRCLK2												=> RXUSRCLK2_IN,
				------------------ Receive Ports - FPGA RX interface Ports -----------------
				RXDATA													=> GTX_RX_Data(I),
				------------------- Receive Ports - Pattern Checker Ports ------------------
--				RXPRBSCNTRESET									=> '0',
--				RXPRBSERR												=> open,
--				RXPRBSSEL												=> (2 downto 0 => '0'),
				-------------------- Receive Ports - RX	Equalizer Ports -------------------
--				RXDFEXYDEN											=> '1',
--				RXDFEXYDHOLD										=> '0',
--				RXDFEXYDOVRDEN									=> '0',
				------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
--				RXDISPERR(7 downto 4)						=> rxdisperr_float_i,
--				RXDISPERR(3 downto 0)						=> RXDISPERR_OUT,
--				RXNOTINTABLE(7 downto 4)				=> rxnotintable_float_i,
--				RXNOTINTABLE(3 downto 0)				=> RXNOTINTABLE_OUT,
				--------------------------- Receive Ports - RX AFE -------------------------
				GTXRXN													=> VSS_Private_In(0).RX_n,
				GTXRXP													=> VSS_Private_In(0).RX_p,
				------------------- Receive Ports - RX Buffer Bypass Ports -----------------
--				RXBUFRESET											=> RXBUFRESET_IN,
--				RXBUFSTATUS											=> RXBUFSTATUS_OUT,
--				RXDDIEN													=> '0',
--				RXDLYBYPASS											=> '1',
--				RXDLYEN													=> '0',
--				RXDLYOVRDEN											=> '0',
--				RXDLYSRESET											=> '0',
--				RXDLYSRESETDONE									=> open,
--				RXPHALIGN												=> '0',
--				RXPHALIGNDONE										=> open,
--				RXPHALIGNEN											=> '0',
--				RXPHDLYPD												=> '0',
--				RXPHDLYRESET										=> '0',
--				RXPHMONITOR											=> open,
--				RXPHOVRDEN											=> '0',
--				RXPHSLIPMONITOR									=> open,
--				RXSTATUS												=> RXSTATUS_OUT,
				-------------- Receive Ports - RX Byte and Word Alignment Ports ------------
--				RXBYTEISALIGNED									=> RXBYTEISALIGNED_OUT,
--				RXBYTEREALIGN										=> RXBYTEREALIGN_OUT,
--				RXCOMMADET											=> RXCOMMADET_OUT,
--				RXCOMMADETEN										=> '1',
--				RXMCOMMAALIGNEN									=> RXMCOMMAALIGNEN_IN,
--				RXPCOMMAALIGNEN									=> RXPCOMMAALIGNEN_IN,
				------------------ Receive Ports - RX Channel Bonding Ports ----------------
--				RXCHANBONDSEQ										=> open,
--				RXCHBONDEN											=> '0',
--				RXCHBONDLEVEL										=> (2 downto 0 => '0'),
--				RXCHBONDMASTER									=> '0',
--				RXCHBONDO												=> open,
--				RXCHBONDSLAVE										=> '0',
				----------------- Receive Ports - RX Channel Bonding Ports	----------------
--				RXCHANISALIGNED									=> open,
--				RXCHANREALIGN										=> open,
				-------------------- Receive Ports - RX Equailizer Ports -------------------
--				RXLPMHFHOLD											=> '0',
--				RXLPMHFOVRDEN										=> '0',
--				RXLPMLFHOLD											=> '0',
				--------------------- Receive Ports - RX Equalizer Ports -------------------
--				RXDFEAGCHOLD										=> RXDFEAGCHOLD_IN,
--				RXDFEAGCOVRDEN									=> '0',
--				RXDFECM1EN											=> '0',
--				RXDFELFHOLD											=> RXDFELFHOLD_IN,
--				RXDFELFOVRDEN										=> '1',
--				RXDFELPMRESET										=> '0',
--				RXDFETAP2HOLD										=> '0',
--				RXDFETAP2OVRDEN									=> '0',
--				RXDFETAP3HOLD										=> '0',
--				RXDFETAP3OVRDEN									=> '0',
--				RXDFETAP4HOLD										=> '0',
--				RXDFETAP4OVRDEN									=> '0',
--				RXDFETAP5HOLD										=> '0',
--				RXDFETAP5OVRDEN									=> '0',
--				RXDFEUTHOLD											=> '0',
--				RXDFEUTOVRDEN										=> '0',
--				RXDFEVPHOLD											=> '0',
--				RXDFEVPOVRDEN										=> '0',
--				RXDFEVSEN												=> '0',
--				RXLPMLFKLOVRDEN									=> '0',
--				RXMONITOROUT										=> open,
--				RXMONITORSEL										=> "00",
--				RXOSHOLD												=> '0',
--				RXOSOVRDEN											=> '0',
				------------ Receive Ports - RX Fabric ClocK Output Control Ports ----------
--				RXRATEDONE											=> RXRATEDONE_OUT,
				--------------- Receive Ports - RX Fabric Output Control Ports -------------
--				RXOUTCLK												=> RXOUTCLK_OUT,
--				RXOUTCLKFABRIC									=> open,
--				RXOUTCLKPCS											=> open,
--				RXOUTCLKSEL											=> "010",
				---------------------- Receive Ports - RX Gearbox Ports --------------------
--				RXDATAVALID											=> open,
--				RXHEADER												=> open,
--				RXHEADERVALID										=> open,
--				RXSTARTOFSEQ										=> open,
				--------------------- Receive Ports - RX Gearbox Ports	--------------------
--				RXGEARBOXSLIP										=> '0',
				------------- Receive Ports - RX Initialization and Reset Ports ------------
--				GTRXRESET												=> GTRXRESET_IN,
--				RXOOBRESET											=> '0',
--				RXPCSRESET											=> '0',
--				RXPMARESET											=> RXPMARESET_IN,
				------------------ Receive Ports - RX Margin Analysis ports ----------------
--				RXLPMEN													=> '0',
				------------------- Receive Ports - RX OOB Signaling ports -----------------
				RXCOMINITDET										=> GTX_RX_ComInitDetected,
				RXCOMWAKEDET										=> GTX_RX_ComWakeDetected,
				RXCOMSASDET											=> open,
				------------------ Receive Ports - RX OOB Signaling ports	-----------------
				RXELECIDLE											=> GTP_RX_ElectricalIDLE,
--				RXELECIDLEMODE									=> "00",
				----------------- Receive Ports - RX Polarity Control Ports ----------------
--				RXPOLARITY											=> '0',
				---------------------- Receive Ports - RX gearbox ports --------------------
--				RXSLIDE													=> '0',
				------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
				RXCHARISCOMMA(7 downto 4)				=> GTX_RX_CharIsComma_float,
				RXCHARISCOMMA(3 downto 0)				=> GTX_RX_CharIsComma(I),
				RXCHARISK(7 downto 4)						=> GTX_RX_CharIsK_float,
				RXCHARISK(3 downto 0)						=> GTX_RX_CharIsK(I),
				------------------ Receive Ports - Rx Channel Bonding Ports ----------------
--				RXCHBONDI												=> "00000",
				-------------- Receive Ports -RX Initialization and Reset Ports ------------
				RXRESETDONE											=> GTX_RX_ResetDone(I),
				-------------------------------- Rx AFE Ports ------------------------------
--				RXQPIEN													=> '0',
--				RXQPISENN												=> open,
--				RXQPISENP												=> open,
				--------------------------- TX Buffer Bypass Ports -------------------------
--				TXPHDLYTSTCLK										=> '0',
				------------------------ TX Configurable Driver Ports ----------------------
--				TXPOSTCURSOR										=> "00000",
--				TXPOSTCURSORINV									=> '0',
--				TXPRECURSOR											=> (4 downto 0 => '0'),
--				TXPRECURSORINV									=> '0',
--				TXQPIBIASEN											=> '0',
--				TXQPISTRONGPDOWN								=> '0',
--				TXQPIWEAKPUP										=> '0',
				--------------------- TX Initialization and Reset Ports --------------------
--				CFGRESET												=> '0',
--				GTTXRESET												=> GTTXRESET_IN,
--				PCSRSVDOUT											=> open,
--				TXUSERRDY												=> TXUSERRDY_IN,
				---------------------- Transceiver Reset Mode Operation --------------------
--				GTRESETSEL											=> '0',
--				RESETOVRD												=> '0',
				---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
--				TXCHARDISPMODE									=> (7 downto 0 => '0'),
--				TXCHARDISPVAL										=> (7 downto 0 => '0'),
				------------------ Transmit Ports - FPGA TX Interface Ports ----------------
--				TXUSRCLK												=> TXUSRCLK_IN,
--				TXUSRCLK2												=> TXUSRCLK2_IN,
				--------------------- Transmit Ports - PCI Express Ports -------------------
--				TXELECIDLE											=> '0',
--				TXMARGIN												=> (2 downto 0 => '0'),
--				TXRATE													=> TXRATE_IN,
--				TXSWING													=> '0',
				------------------ Transmit Ports - Pattern Generator Ports ----------------
--				TXPRBSFORCEERR									=> '0',
				------------------ Transmit Ports - TX Buffer Bypass Ports -----------------
--				TXDLYBYPASS											=> '1',
--				TXDLYEN													=> '0',
--				TXDLYHOLD												=> '0',
--				TXDLYOVRDEN											=> '0',
--				TXDLYSRESET											=> '0',
--				TXDLYSRESETDONE									=> open,
--				TXDLYUPDOWN											=> '0',
--				TXPHALIGN												=> '0',
--				TXPHALIGNDONE										=> open,
--				TXPHALIGNEN											=> '0',
--				TXPHDLYPD												=> '0',
--				TXPHDLYRESET										=> '0',
--				TXPHINIT												=> '0',
--				TXPHINITDONE										=> open,
--				TXPHOVRDEN											=> '0',
				---------------------- Transmit Ports - TX Buffer Ports --------------------
--				TXBUFSTATUS											=> TXBUFSTATUS_OUT,
				--------------- Transmit Ports - TX Configurable Driver Ports --------------
--				TXBUFDIFFCTRL										=> "100",
--				TXDEEMPH												=> '0',
--				TXDIFFCTRL											=> "1000",
--				TXDIFFPD												=> '0',
--				TXINHIBIT												=> '0',
--				TXMAINCURSOR										=> "0000000",
--				TXPISOPD												=> '0',
				------------------ Transmit Ports - TX Data Path interface -----------------
				TXDATA													=> GTX_TX_Data(I),
				---------------- Transmit Ports - TX Driver and OOB signaling --------------
				
				GTXTXN													=> VSS_Private_Out(I).TX_n,
				GTXTXP													=> VSS_Private_Out(I).TX_p,
				----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
--				TXOUTCLK												=> TXOUTCLK_OUT,
--				TXOUTCLKFABRIC									=> TXOUTCLKFABRIC_OUT,
--				TXOUTCLKPCS											=> TXOUTCLKPCS_OUT,
--				TXOUTCLKSEL											=> "010",
--				TXRATEDONE											=> TXRATEDONE_OUT,
				--------------------- Transmit Ports - TX Gearbox Ports --------------------
				TXCHARISK(7 downto 4)						=> (7 downto 4 => '0'),
				TXCHARISK(3 downto 0)						=> GTX_TX_CharIsK(I),
--				TXGEARBOXREADY									=> open,
--				TXHEADER												=> (2 downto 0 => '0'),
--				TXSEQUENCE											=> (6 downto 0 => '0'),
--				TXSTARTSEQ											=> '0',
				------------- Transmit Ports - TX Initialization and Reset Ports -----------
--				TXPCSRESET											=> '0',
--				TXPMARESET											=> '0',
--				TXRESETDONE											=> TXRESETDONE_OUT,
				------------------ Transmit Ports - TX OOB signalling Ports ----------------
				TXCOMINIT												=> GTP_TX_ComInit,
				TXCOMWAKE												=> GTP_TX_ComWake,
				TXCOMSAS												=> '0',
				TXCOMFINISH											=> GTP_TX_ComFinish,
--				TXPDELECIDLEMODE								=> '0',
				----------------- Transmit Ports - TX Polarity Control Ports ---------------
				TXPOLARITY											=> '0',
				--------------- Transmit Ports - TX Receiver Detection Ports	--------------
				TXDETECTRX											=> '0',
				------------------ Transmit Ports - TX8b/10b Encoder Ports -----------------
--				TX8B10BBYPASS										=> (7 downto 0 => '0'),
				------------------ Transmit Ports - pattern Generator Ports ----------------
--				TXPRBSSEL												=> (2 downto 0 => '0'),
				----------------------- Tx Configurable Driver	Ports ----------------------
--				TXQPISENN												=> open,
--				TXQPISENP												=> open
			);
		
	END GENERATE;
END;