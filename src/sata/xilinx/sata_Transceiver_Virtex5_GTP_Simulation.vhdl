LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;


ENTITY SATATransceiver_Virtex5_GTPSIM IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																									-- 150 MHz
		PORTS											: POSITIVE										:= 2;																											-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GEN_2, SATA_GEN_2)			-- intial SATA Generation
	);
	PORT (
		ClockIn_150MHz						: IN	STD_LOGIC;
		SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		Reset											: IN	STD_LOGIC;
--		ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		ClockNetwork_Reset				: IN	STD_LOGIC;
		ClockNetwork_ResetDone		: OUT	STD_LOGIC;

		RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		SATA_Generation						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
		OOB_HandshakingComplete		: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		Command										: IN	T_TRANS_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
		Status										: OUT	T_TRANS_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Error									: OUT	T_RX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Error									: OUT	T_TX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

		RX_OOBStatus							: OUT	T_OOB_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
		RX_CharIsK								: OUT	T_CIK_VECTOR(PORTS - 1 DOWNTO 0);
		RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		
		TX_OOBCommand							: IN	T_OOB_VECTOR(PORTS - 1 DOWNTO 0);
		TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
		TX_CharIsK								: IN	T_CIK_VECTOR(PORTS - 1 DOWNTO 0);
		
		-- LVDS Ports
		RX_n											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RX_p											: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_n											: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_p											: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF SATATransceiver_Virtex5_GTPSIM IS
	ATTRIBUTE KEEP 				: STRING;

	CONSTANT NO_DEVICE_TIMEOUT_MS				: REAL						:= 0.1;					-- 0,1 ms

	FUNCTION SATAGeneration2ClockDivider(SGEN : T_SATA_GENERATION_VECTOR) RETURN T_INTVEC IS
		VARIABLE ClkDiv : T_INTVEC(SGEN'range)	:= (OTHERS => 0);
	BEGIN
		FOR I IN SGEN'range LOOP										-- GTP_DUAL PLL output = 1,5 GHz
			IF (SGEN(I) = SATA_GEN_1) THEN						-- generation 1: 1,5 GHz line clock => 750 MHz TX/RX clock (DDR sampler)	=> devider = 2
				ClkDiv(I) := 2;
			ELSIF (SGEN(I) = SATA_GEN_2) THEN					-- generation 1: 3,0 GHz line clock => 1,5 GHz TX/RX clock (DDR sampler)	=> devider = 1
				ClkDiv(I) := 1;
			END IF;
		END LOOP;
		
		RETURN ClkDiv;
	END;

	FUNCTION IsSupportedGeneration(SATAGen : T_SATA_GENERATION) RETURN BOOLEAN IS
	BEGIN
		CASE SATAGen IS
			WHEN SATA_GEN_1 =>			RETURN TRUE;
			WHEN SATA_GEN_2 =>			RETURN TRUE;
			WHEN OTHERS =>					RETURN FALSE;
		END CASE;
	END;

	CONSTANT CLOCK_DIVIDERS										: T_INTVEC(INITIAL_SATA_GENERATIONS'range)		:= SATAGeneration2ClockDivider(INITIAL_SATA_GENERATIONS);

	SIGNAL ResetDone_i												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL GTP_Reset													: STD_LOGIC;
	SIGNAL GTP_ResetDone											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_PLL_Reset											: STD_LOGIC;
	SIGNAL GTP_PLL_ResetDone									:	STD_LOGIC;

	SIGNAL GTP_RefClockIn											: STD_LOGIC;
	SIGNAL GTP_RefClockOut										: STD_LOGIC;
	SIGNAL GTP_RefClockOut_i									: STD_LOGIC;
	SIGNAL GTP_DRP_Clock											: STD_LOGIC;
	SIGNAL GTP_ClockRX_1X											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_ClockRX_4X											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_ClockTX_1X											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_ClockTX_4X											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL SATA_Clock_i												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL ClkNet_Reset												: STD_LOGIC;
	SIGNAL ClkNet_ResetDone										: STD_LOGIC;
	SIGNAL ClockNetwork_ResetDone_i						: STD_LOGIC;
	
	SIGNAL GTP_RX_Reset												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_CDR_Reset										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);		-- Clock Data Recovery
	SIGNAL GTP_RX_BufferReset									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_Reset												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
--	SIGNAL GTP_ResetDone_i										: STD_LOGIC;

	SIGNAL GTPConfig_Reset										: STD_LOGIC;
	SIGNAL GTPConfig_GTP_ReloadConfig					: STD_LOGIC;

--	SIGNAL SATA_Generation_d									: T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0)										:= (SATA_GEN_1, SATA_GEN_1);
	SIGNAL GTP_DRP_en													: STD_LOGIC;
	SIGNAL GTP_DRP_Address										: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL GTP_DRP_we													: STD_LOGIC;
	SIGNAL GTP_DRP_DataIn											: T_SLV_16;
	SIGNAL GTP_DRP_DataOut										: T_SLV_16;
	SIGNAL GTP_DRP_rdy												: STD_LOGIC;

	SIGNAL GTP_TX_ElectricalIDLE							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)														:= (OTHERS => '0');
	SIGNAL GTP_TX_ComStart										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_ComType											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)														:= (OTHERS => '0');
	SIGNAL GTP_TX_Status											: T_SLVV_2(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_InvalidK										: T_SLVV_2(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_BufferStatus								: T_SLVV_2(PORTS - 1 DOWNTO 0);

	SIGNAL GTP_RX_ElectricalIDLE_Reset				: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_EnableElectricalIDLEReset		: STD_LOGIC;
	SIGNAL GTP_RX_ElectricalIDLE							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL GTP_RX_Status											: T_SLVV_3(PORTS - 1 DOWNTO 0);
	SIGNAl GTP_RX_IsAligned										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAl GTP_RX_DisparityError							: T_SLVV_2(PORTS - 1 DOWNTO 0);
	SIGNAl GTP_RX_Illegal8B10BCode						: T_SLVV_2(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_LossOfSync									: T_SLVV_2(PORTS - 1 DOWNTO 0);																	-- unused
	SIGNAL GTP_RX_ClockCorrectionStatus				: T_SLVV_3(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_BufferStatus								: T_SLVV_3(PORTS - 1 DOWNTO 0);
	
	SIGNAL GTP_RX_Data												: T_SLVV_16(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_Data_d											: T_SLVV_8(PORTS - 1 DOWNTO 0)																		:= (OTHERS => (OTHERS => '0'));
	SIGNAL GTP_RX_CommaDetected								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);													-- unused
	SIGNAL GTP_RX_CharIsComma									: T_SLVV_2(PORTS - 1 DOWNTO 0);																	-- unused
	SIGNAL GTP_RX_CharIsK											: T_SLVV_2(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_CharIsK_d										: T_SLVV_2(PORTS - 1 DOWNTO 0)																		:= (OTHERS => (OTHERS => '0'));
	SIGNAL GTP_RX_ByteIsAligned								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_RX_ByteRealign									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);													-- unused
	SIGNAL GTP_RX_Valid												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);													-- unused
		
	SIGNAL GTP_TX_Data												: T_SLVV_16(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_TX_CharIsK											: T_CIK2_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL BWC_RX_Align												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL BWC_TX_Align												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL TX_OOBCommand_d										: T_OOB_VECTOR(PORTS - 1 DOWNTO 0)																:= (OTHERS => OOB_NONE);
	SIGNAL TX_OOBComplete_i										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	SIGNAL Sync3_RX_ElectricalIDLE_sy					: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Sync3_RX_ElectricalIDLE_sy1				: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)														:= (OTHERS => '0');
	SIGNAL Sync3_RX_ElectricalIDLE_sy2				: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)														:= (OTHERS => '0');

	SIGNAL RX_ElectricalIDLE									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL RX_OOBStatus_i											: T_OOB_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL RX_OOBStatus_d											: T_OOB_VECTOR(PORTS - 1 DOWNTO 0)																:= (OTHERS => OOB_NONE);

	SIGNAL NDD_NoDevice												: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);


	ATTRIBUTE KEEP OF GTP_RX_IsAligned				: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_RX_CharIsComma			: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_RX_CharIsK					: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_RX_Data							: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_TX_CharIsK					: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_TX_Data							: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF TX_OOBComplete					: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF BWC_RX_Align						: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF BWC_TX_Align						: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_RX_ClockCorrectionStatus		: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_RX_BufferStatus							: SIGNAL IS "TRUE";
	
	-- keep internal clock nets, so timing constrains from UCF can find them
	ATTRIBUTE KEEP OF GTP_DRP_Clock						: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_ClockRX_1X					: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_ClockRX_4X					: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_ClockTX_1X					: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF GTP_ClockTX_4X					: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF SATA_Clock_i						: SIGNAL IS "TRUE";
	
	SIGNAL DBG_Trigger_COMRESET								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL DBG_Trigger_COMWAKE								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	ATTRIBUTE KEEP OF Status									: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF NDD_NoDevice						: SIGNAL IS "TRUE";

	ATTRIBUTE KEEP OF DBG_Trigger_COMRESET		: SIGNAL IS "TRUE";
	ATTRIBUTE KEEP OF DBG_Trigger_COMWAKE			: SIGNAL IS "TRUE";

BEGIN
-- ==================================================================
-- Assert statements
-- ==================================================================
	ASSERT (VENDOR = VENDOR_XILINX)		REPORT "Vendor not yet supported."						SEVERITY FAILURE;
	ASSERT (DEVFAM = DEVFAM_VIRTEX)		REPORT "Device family not yet supported."			SEVERITY FAILURE;
	ASSERT (DEVICE = DEVICE_VIRTEX5)	REPORT "Device not yet supported."						SEVERITY FAILURE;
	ASSERT (PORTS <= 2)								REPORT "To many ports per transceiver."				SEVERITY FAILURE;
	
	ASSERT (SIMULATION = TRUE)				REPORT "this module is only for simulation."	SEVERITY FAILURE;
	
	genassert : FOR I IN 0 TO PORTS - 1 GENERATE
		ASSERT (CLOCK_DIVIDERS(I) > 0)										REPORT "illegal clock devider - unsupported initial SATA generation?" SEVERITY FAILURE;
		ASSERT 	IsSupportedGeneration(SATA_Generation(I))	REPORT "unsupported SATA generation" SEVERITY FAILURE;
	END GENERATE;

-- ==================================================================
-- ResetControl
-- ==================================================================
	ClkNet_Reset							<= ClockNetwork_Reset;
	GTP_PLL_Reset							<= ClockNetwork_Reset;
	
	GTP_Reset									<= GTP_PLL_Reset OR GTPConfig_GTP_ReloadConfig;				-- PLL reset must be mapped to global GTP reset
	ClockNetwork_ResetDone_i	<= GTP_PLL_ResetDone AND ClkNet_ResetDone;						-- calculate when all clocknetwork components are stable
	ClockNetwork_ResetDone		<= ClockNetwork_ResetDone_i;													-- 
	
	gen0 : FOR I IN 0 TO PORTS - 1 GENERATE
		ResetDone_i(I)				<= ClockNetwork_ResetDone_i AND GTP_ResetDone(I);				-- calculate individual ResetDone per GTP_DUAL port
--		ResetDone(I)					<= ResetDone_i(I);
		GTP_RX_Reset(I)				<= OOB_HandshakingComplete(I);
	END GENERATE;

-- ==================================================================
-- ClockNetwork (37.5, 75, 150, 300 MHz)
-- ==================================================================
	GTP_RefClockIn		<= ClockIn_150MHz;
	SATA_Clock				<= SATA_Clock_i;
	
	BUFG_GTP_RefClockOut : BUFG
		PORT MAP (
			I		=> GTP_RefClockOut_i,
			O		=> GTP_RefClockOut
		);
	
	ClkNet : ENTITY L_SATAController.ClockNetwork
		GENERIC MAP (
			CLOCK_IN_FREQ_MHZ						=> CLOCK_IN_FREQ_MHZ,
			PORTS												=> PORTS,
			INITIAL_SATA_GENERATIONS		=> INITIAL_SATA_GENERATIONS
		)
		PORT MAP (
			ClockIn_150MHz							=> GTP_RefClockOut,

			ClockNetwork_Reset					=> ClkNet_Reset,
			ClockNetwork_ResetDone			=> ClkNet_ResetDone,
			
			SATA_Generation							=> SATA_Generation,
			
			GTP_ClockRX_1X							=> GTP_ClockRX_1X,
			GTP_ClockRX_4X							=> GTP_ClockRX_4X,
			GTP_ClockTX_1X							=> GTP_ClockTX_1X,
			GTP_ClockTX_4X							=> GTP_ClockTX_4X,
			GTP_DRP_Clock								=> GTP_DRP_Clock
		);


-- ==================================================================
-- data path buffers
-- ==================================================================
	gen1 : FOR I IN 0 TO (PORTS - 1) GENERATE
		SIGNAL Sync1_GTP_RX_ByteIsAligned_sy		: STD_LOGIC;
		SIGNAL Sync1_GTP_RX_ByteIsAligned_sy1		: STD_LOGIC					:= '0';
		SIGNAL Sync1_GTP_RX_ByteIsAligned_sy2		: STD_LOGIC					:= '0';
		SIGNAL Sync1_GTP_RX_ByteIsAligned				: STD_LOGIC					:= '0';
		
		SIGNAL Sync4_NoDevice_sy								: STD_LOGIC;
		SIGNAL Sync4_NoDevice_sy1								: STD_LOGIC					:= '0';
		SIGNAL Sync4_NoDevice_sy2								: STD_LOGIC					:= '0';
		SIGNAL Sync4_NoDevice										: STD_LOGIC;
		
	BEGIN
		-- TX path
		BWC_TX_Align(I)					<= NOT ClkNet_ResetDone;
		
		BWC_TX_CharIsK : ENTITY L_SATAController.alu_BitwidthConverter
			GENERIC MAP (
				REGISTERED					=> TRUE,
				BW1									=> 4,
				BW2									=> 1
			)
			PORT MAP (
				Clock1							=> GTP_ClockTX_4X(I),
				Clock2							=> GTP_ClockTX_1X(I),
				Align								=> BWC_TX_Align(I),
				I										=> TX_CharIsK(I),
				O										=> GTP_TX_CharIsK(I)(0 DOWNTO 0)
			);
	
		BWC_TX_Data : ENTITY L_SATAController.alu_BitwidthConverter
			GENERIC MAP (
				REGISTERED					=> TRUE,
				BW1									=> 32,
				BW2									=> 8
			)
			PORT MAP (
				Clock1							=> GTP_ClockTX_4X(I),
				Clock2							=> GTP_ClockTX_1X(I),
				Align								=> BWC_TX_Align(I),
				I										=> TX_Data(I),
				O										=> GTP_TX_Data(I)(7 DOWNTO 0)
			);
	
	
		-- RX path
		-- insert register stage, so timing constrains can be solved
		GTP_RX_CharIsK_d(I)	<= GTP_RX_CharIsK(I)					WHEN rising_edge(GTP_ClockRX_1X(I));
		GTP_RX_Data_d(I)		<= GTP_RX_Data(I)(7 DOWNTO 0) WHEN rising_edge(GTP_ClockRX_1X(I));

		-- use K-characters for word alignment
		BWC_RX_Align(I) 		<= GTP_RX_CharIsK_d(I)(0);
		
		BWC_RX_CharIsK : ENTITY L_SATAController.alu_BitwidthConverter
			GENERIC MAP (
				REGISTERED					=> TRUE,
				BW1									=> 1,
				BW2									=> 4
			)
			PORT MAP (
				Clock1							=> GTP_ClockRX_1X(I),
				Clock2							=> GTP_ClockRX_4X(I),
				Align								=> BWC_RX_Align(I),
				I										=> GTP_RX_CharIsK_d(I)(0 DOWNTO 0),
				O										=> RX_CharIsK(I)
			);
	
		BWC_RX_Data : ENTITY L_SATAController.alu_BitwidthConverter
			GENERIC MAP (
				REGISTERED					=> TRUE,
				BW1									=> 8,
				BW2									=> 32
			)
			PORT MAP (
				Clock1							=> GTP_ClockRX_1X(I),
				Clock2							=> GTP_ClockRX_4X(I),
				Align								=> BWC_RX_Align(I),
				I										=> GTP_RX_Data_d(I),
				O										=> RX_Data(I)
			);

		-- synchronize IsAligned signal
		Sync1_GTP_RX_ByteIsAligned_sy		<= GTP_RX_ByteIsAligned(I);
		Sync1_GTP_RX_ByteIsAligned_sy1	<= Sync1_GTP_RX_ByteIsAligned_sy	WHEN rising_edge(GTP_ClockRX_4X(I));
		Sync1_GTP_RX_ByteIsAligned_sy2	<= Sync1_GTP_RX_ByteIsAligned_sy1 WHEN rising_edge(GTP_ClockRX_4X(I));
		Sync1_GTP_RX_ByteIsAligned			<= Sync1_GTP_RX_ByteIsAligned_sy2;
		
		-- return IsAligned signal
		RX_IsAligned(I)									<= Sync1_GTP_RX_ByteIsAligned;

-- ==================================================================
-- OOB signaling
-- ==================================================================
		TX_OOBCommand_d(I)	<= TX_OOBCommand(I) WHEN rising_edge(GTP_ClockTX_1X(I));

		-- TX OOB signals (generate GTP specific OOB signals)
		WITH TX_OOBCommand_d(I) SELECT
			GTP_TX_ComStart(I) <= '1' WHEN OOB_COMRESET | OOB_COMWAKE,
														'0' WHEN OTHERS;

		-- SR-FF for ElectricalIDLE:
		--		.set	= ComStart
		--		.rst	= OOBComplete || Reset
		PROCESS(GTP_ClockTX_1X(I))
		BEGIN
			IF rising_edge(GTP_ClockTX_1X(I)) THEN
				IF (Reset(I) = '1') THEN
					GTP_TX_ElectricalIDLE(I)	<= '0';
				ELSE
					IF (GTP_TX_ComStart(I) = '1') THEN
						GTP_TX_ElectricalIDLE(I)	<= '1';
					ELSIF (TX_OOBComplete_i(I) = '1') THEN
						GTP_TX_ElectricalIDLE(I)	<= '0';
					END IF;
				END IF;
			END IF;
		END PROCESS;
		
		-- SR-FF for ComType:
		--		.en		= ComStart
		--		.set	= OOBCommand = COMRESET | COMINIT
		--		.rst	= OOBCommand = COMWAKE
		PROCESS(GTP_ClockTX_1X(I))
		BEGIN
			IF rising_edge(GTP_ClockTX_1X(I)) THEN
				IF (GTP_TX_ComStart(I) = '1') THEN
					CASE TX_OOBCommand_d(I) IS
						WHEN OOB_COMRESET =>		GTP_TX_ComType(I)				<= '0';
						WHEN OOB_COMWAKE =>			GTP_TX_ComType(I)				<= '1';
						WHEN OTHERS =>					NULL;
					END CASE;
				END IF;
			END IF;
		END PROCESS;
		
		-- OOB sequence is complete
		TX_OOBComplete_i(I) <= '1' WHEN (GTP_RX_Status(I)(0) = '1') ELSE '0';
		-- TODO add cross clock domain synchronizer if you are using different clock domains für TX und RX !!
		
		Sync2 : ENTITY L_SATAController.Synchronizer
			GENERIC MAP (
				BW											=> 1,														-- number of bit to be synchronized
				GATED_INPUT_BY_BUSY			=> TRUE													-- use gated input (by busy signal)
			)
			PORT MAP (
				Clock1									=> GTP_ClockRX_1X(I),						-- input clock domain
				Clock2									=> GTP_ClockRX_4X(I),						-- output clock domain
				I(0)										=> TX_OOBComplete_i(I),					-- input bits
				O(0)										=> TX_OOBComplete(I),						-- output bits
				B(0)										=> OPEN													-- busy bits
			);
		
		-- RX OOB signals (generate generic RX OOB status signals)
		PROCESS(GTP_RX_Status(I)(2 DOWNTO 1), RX_ElectricalIDLE(I))
		BEGIN
			RX_OOBStatus_i(I) 				<= OOB_NONE;
		
			IF (RX_ElectricalIDLE(I) = '1') THEN
				RX_OOBStatus_i(I)				<= OOB_READY;
			
				CASE GTP_RX_Status(I)(2 DOWNTO 1) IS
					WHEN "10" =>					RX_OOBStatus_i(I)		<= OOB_COMRESET;
					WHEN "01" =>					RX_OOBStatus_i(I)		<= OOB_COMWAKE;
					WHEN OTHERS =>				NULL;
				END CASE;
			END IF;
		END PROCESS;

		RX_OOBStatus_d(I) <= RX_OOBStatus_i(I) WHEN rising_edge(SATA_Clock_i(I));
		RX_OOBStatus(I)		<= RX_OOBStatus_d(I);

-- ==================================================================
-- reset control
-- ==================================================================
		-- generate reset for CDR-unit (Clock-Data-Recovery) after OOB signaling (GTP_RX_ElectricalIDLE is async)
		Sync3_RX_ElectricalIDLE_sy(I)		<= GTP_RX_ElectricalIDLE(I);
		Sync3_RX_ElectricalIDLE_sy1(I) 	<= Sync3_RX_ElectricalIDLE_sy(I)		WHEN rising_edge(GTP_ClockRX_1X(I));
		Sync3_RX_ElectricalIDLE_sy2(I)	<= Sync3_RX_ElectricalIDLE_sy1(I)		WHEN rising_edge(GTP_ClockRX_1X(I));
		RX_ElectricalIDLE(I)						<= Sync3_RX_ElectricalIDLE_sy2(I);
		
		GTP_RX_ElectricalIDLE_Reset(I)	<= RX_ElectricalIDLE(I) AND GTP_ResetDone(I);
		
		GTP_TX_Reset(I)									<= GTP_Reset;


-- ==================================================================
-- error handling
-- ==================================================================
		-- RX errors
		PROCESS(GTP_RX_IsAligned(I), GTP_RX_DisparityError(I)(0), GTP_RX_Illegal8B10BCode(I)(0), GTP_RX_BufferStatus(I)(2))
		BEGIN
			RX_Error(I) <= RX_ERR_NONE;
		
			IF (GTP_RX_IsAligned(I) = '0') THEN
				RX_Error(I) <= RX_ERR_ALIGNEMENT;
			ELSIF (GTP_RX_DisparityError(I)(0) = '1') THEN
				RX_Error(I) <= RX_ERR_DISPARITY;
			ELSIF (GTP_RX_Illegal8B10BCode(I)(0) = '1') THEN
				RX_Error(I) <= RX_ERR_DECODER;
			ELSIF (GTP_RX_BufferStatus(I)(2) = '1') THEN
				RX_Error(I) <= RX_ERR_BUFFER;
			END IF;
		END PROCESS;

		-- TX errors
		PROCESS(GTP_TX_InvalidK(I)(0), GTP_TX_BufferStatus(I)(1))
		BEGIN
			TX_Error(I) <= TX_ERR_NONE;
		
			IF (GTP_TX_InvalidK(I)(0) = '1') THEN
				TX_Error(I) <= TX_ERR_ENCODER;
			ELSIF (GTP_TX_BufferStatus(I)(1) = '1') THEN
				TX_Error(I) <= TX_ERR_BUFFER;
			END IF;
		END PROCESS;
		

-- ==================================================================
-- Transceiver status
-- ==================================================================
		-- NO_DEVICE detection
		NDD : ENTITY L_SATAController.NoDeviceDetector
			GENERIC MAP (
				CLOCKSPEED_NS						=> Freq_MHz2Real_ns(150),			-- 150 MHz
				NO_DEVICE_TIMEOUT_MS		=> NO_DEVICE_TIMEOUT_MS				-- 0,1 ms
			)
			PORT MAP (
				Clock										=> GTP_DRP_Clock,
				ElectricalIDLE					=> RX_ElectricalIDLE(I),
				NoDevice								=> NDD_NoDevice(I)
			);

		Sync4_NoDevice_sy			<= NDD_NoDevice(I);
		Sync4_NoDevice_sy1		<= Sync4_NoDevice_sy			WHEN rising_edge(SATA_Clock_i(I));
		Sync4_NoDevice_sy2		<= Sync4_NoDevice_sy1			WHEN rising_edge(SATA_Clock_i(I));
		Sync4_NoDevice				<= Sync4_NoDevice_sy2;

		PROCESS(Sync4_NoDevice)
		BEGIN
			Status(I) 							<= TRANS_STATUS_NORMAL;
			
			IF (Sync4_NoDevice = '1') THEN
				Status(I)							<= TRANS_STATUS_NO_DEVICE;
-- TODO: add TRANS_STATUS_***
--	- POWERED_DOWN
--	- RESET
--			ELSIF () THEN
--				Status(I)							<= TRANS_STATUS_POWERED_DOWN;
			END IF;
		END PROCESS;
	
	END GENERATE;

	GTP_RX_EnableElectricalIDLEReset	<= slv_or(GTP_RX_ElectricalIDLE_Reset);


-- ==================================================================
-- DRP - dynamic reconfiguration port
-- ==================================================================
	GTPConfig : ENTITY L_SATAController.GTP_DUALConfigurator
		GENERIC MAP (
			PORTS													=> PORTS
		)
		PORT MAP (
			DRP_Clock											=> GTP_DRP_Clock,
			SATA_Clock										=> SATA_Clock_i,
			Reset													=> GTPConfig_Reset,
	
			Reconfig											=> RP_Reconfig,
			ReconfigComplete							=> RP_ReconfigComplete,
			ConfigReloaded								=> RP_ConfigReloaded,
			Lock													=> RP_Lock,
			Locked												=> RP_Locked,
	
			SATA_Generation								=> SATA_Generation,
			NoDevice											=> NDD_NoDevice,
	
			GTP_DRP_en										=> GTP_DRP_en,
			GTP_DRP_Address								=> GTP_DRP_Address,
			GTP_DRP_we										=> GTP_DRP_we,
			GTP_DRP_DataIn								=> GTP_DRP_DataOut,
			GTP_DRP_DataOut								=> GTP_DRP_DataIn,
			GTP_DRP_rdy										=> GTP_DRP_rdy,
			
			GTP_ReloadConfig							=> GTPConfig_GTP_ReloadConfig,
			GTP_ReloadConfigDone					=> slv_and(GTP_ResetDone)
		);


-- ==================================================================
-- GTP_DUAL - 1 used port
-- ==================================================================
	SinglePort : IF (PORTS = 1) GENERATE
	 SIGNAL GTP_RX_DisableElectricalIDLEReset : STD_LOGIC;
	 
	BEGIN
		GTP_RX_DisableElectricalIDLEReset		<= NOT GTP_RX_EnableElectricalIDLEReset;
		
		-- takt erzeugen 1,5 oder 3 GHz
		-- takt erzeugen 25 mhz
		-- reset nach xx takten bestätigen
		-- oob erzeugen mit 1,0,Z und bestätigen
		-- oob erkennen mit 1,0,Z
		-- 8bit => 1 bit => 8 bit
		-- drp port nach xx takten bestätigen
		-- empfangenes oob fürt zu UU an rx_data
		-- align erkennen
		-- nach > 500 wörter align => 0
		-- verzögerung
		
		-- 8b10b / 10b8b
		

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
				CLK_COR_MAX_LAT_0							=>			 18,
				CLK_COR_MIN_LAT_0							=>			 16,
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
				CLK_COR_MAX_LAT_1							=>			 18,
				CLK_COR_MIN_LAT_1							=>			 16,
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
				-- OOB COM*** signal detector @ 25 MHz with DDR (20 ns)
				RX_STATUS_FMT_0								=>			 "SATA",
				SATA_BURST_VAL_0							=>			 "100",							-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL_0								=>			 "011",							-- IDLE count between bursts in OOB COM*** signals
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
				SATA_BURST_VAL_1							=>			"100",							-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL_1								=>			"100",							-- IDLE count between bursts in OOB COM*** signals
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
				RXPOWERDOWN0									=>			"00",
				RXPOWERDOWN1									=>			"00",
				TXPOWERDOWN0									=>			"00",
				TXPOWERDOWN1									=>			"00",
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
				RXBYTEISALIGNED0							=>			GTP_RX_ByteIsAligned(0),									-- @ GTP_ClockRX_2X,	high-active, long signal			bytes are aligned			
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
				RXRECCLK0											=>			OPEN,																			-- recovered clock from CDR
				RXRECCLK1											=>			OPEN,
				RXRESET0											=>			GTP_RX_Reset(0),
				RXRESET1											=>			'0',
				RXUSRCLK0											=>			GTP_ClockRX_1X(0),
				RXUSRCLK1											=>			'0',
				RXUSRCLK20										=>			GTP_ClockRX_1X(0),	--GTP_ClockRX_2X(0),
				RXUSRCLK21										=>			'0',
				------- Receive Ports - RX Driver,OOB Signaling,Coupling and Eq.,CDR ------
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
				RXN0													=>			RX_n(0),
				RXP0													=>			RX_p(0),
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
				RXLOSSOFSYNC0									=>			GTP_RX_LossOfSync(0),											-- Xilinx example has connected signal
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
				DADDR													=>			GTP_DRP_Address,
				DWE														=>			GTP_DRP_we,
				DI														=>			GTP_DRP_DataIn,
				DO														=>			GTP_DRP_DataOut,
				DRDY													=>			GTP_DRP_rdy,
				--------------------- Shared Ports - Tile and PLL Ports --------------------
				CLKIN													=>			GTP_RefClockIn,
				GTPRESET											=>			GTP_Reset,
				GTPTEST												=>			"0000",
				INTDATAWIDTH									=>			'1',																									-- 10 Bit internal datawidth
				PLLLKDET											=>			GTP_PLL_ResetDone,																		-- GTP PLL lock detected
				PLLLKDETEN										=>			'1',
				PLLPOWERDOWN									=>			'0',
				REFCLKOUT											=>			GTP_RefClockOut_i,
				REFCLKPWRDNB									=>			'1',
				RESETDONE0										=>			GTP_ResetDone(0),
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
				TXOUTCLK0											=>			OPEN,
				TXOUTCLK1											=>			OPEN,
				TXRESET0											=>			GTP_TX_Reset(0),
				TXRESET1											=>			'0',								-- GTP_TX_Reset
				TXUSRCLK0											=>			GTP_ClockTX_1X(0),
				TXUSRCLK1											=>			'0',								-- GTP_ClockTX_1X
				TXUSRCLK20										=>			GTP_ClockTX_1X(0),	--GTP_ClockTX_2X(0),
				TXUSRCLK21										=>			'0',								-- GTP_ClockTX_2X
				--------------- Transmit Ports - TX Driver and OOB Signaling --------------
				TXBUFDIFFCTRL0								=>			"001",
				TXBUFDIFFCTRL1								=>			"001",
				TXDIFFCTRL0										=>			"100",
				TXDIFFCTRL1										=>			"100",
				TXINHIBIT0										=>			'0',
				TXINHIBIT1										=>			'0',
				TXN0													=>			TX_n(0),
				TXP0													=>			TX_p(0),
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
				RXPOWERDOWN0									=>			"00",
				RXPOWERDOWN1									=>			"00",
				TXPOWERDOWN0									=>			"00",
				TXPOWERDOWN1									=>			"00",
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
				RXBYTEISALIGNED0							=>			GTP_RX_ByteIsAligned(0),									-- @ GTP_ClockRX_2X,	high-active, long signal			bytes are aligned			
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
				RXRECCLK0											=>			OPEN,																			-- recovered clock from CDR
				RXRECCLK1											=>			OPEN,
				RXRESET0											=>			GTP_RX_Reset(0),
				RXRESET1											=>			GTP_RX_Reset(1),
				RXUSRCLK0											=>			GTP_ClockRX_1X(0),
				RXUSRCLK1											=>			GTP_ClockRX_1X(1),
				RXUSRCLK20										=>			GTP_ClockRX_1X(0),
				RXUSRCLK21										=>			GTP_ClockRX_1X(1),
				------- Receive Ports - RX Driver,OOB Signaling,Coupling and Eq.,CDR ------
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
				RXN0													=>			RX_n(0),
				RXP0													=>			RX_p(0),
				RXN1													=>			RX_n(1),
				RXP1													=>			RX_p(1),
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
				RXLOSSOFSYNC0									=>			GTP_RX_LossOfSync(0),														-- Xilinx example has connected signal
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
				PLLLKDET											=>			GTP_PLL_ResetDone,												-- GTP PLL lock detected
				PLLLKDETEN										=>			'1',
				PLLPOWERDOWN									=>			'0',
				REFCLKOUT											=>			GTP_RefClockOut_i,
				REFCLKPWRDNB									=>			'1',
				RESETDONE0										=>			GTP_ResetDone(0),
				RESETDONE1										=>			GTP_ResetDone(1),
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
				TXOUTCLK0											=>			OPEN,
				TXOUTCLK1											=>			OPEN,
				TXRESET0											=>			GTP_TX_Reset(0),
				TXRESET1											=>			GTP_TX_Reset(1),													-- GTP_TX_Reset
				TXUSRCLK0											=>			GTP_ClockTX_1X(0),
				TXUSRCLK1											=>			GTP_ClockTX_1X(1),												-- GTP_ClockTX_1X
				TXUSRCLK20										=>			GTP_ClockTX_1X(0),
				TXUSRCLK21										=>			GTP_ClockTX_1X(1),												-- GTP_ClockTX_2X
				--------------- Transmit Ports - TX Driver and OOB Signaling --------------
				TXBUFDIFFCTRL0								=>			"001",
				TXBUFDIFFCTRL1								=>			"001",
				TXDIFFCTRL0										=>			"100",
				TXDIFFCTRL1										=>			"100",
				TXINHIBIT0										=>			'0',
				TXINHIBIT1										=>			'0',
				TXN0													=>			TX_n(0),
				TXP0													=>			TX_p(0),
				TXN1													=>			TX_n(1),
				TXP1													=>			TX_p(1),
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
-- ChipScope Pro Debugging signals
-- ==================================================================

	genCSP : FOR I IN 0 TO PORTS - 1 GENERATE
		DBG_Trigger_COMRESET(I)		<= '1' WHEN (RX_OOBStatus_i(I) = OOB_COMRESET)	ELSE '0';
		DBG_Trigger_COMWAKE(I)		<= '1' WHEN (RX_OOBStatus_i(I) = OOB_COMWAKE)		ELSE '0';
	END GENERATE;
	
END;
