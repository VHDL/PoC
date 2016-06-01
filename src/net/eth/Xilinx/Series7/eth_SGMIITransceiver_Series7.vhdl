LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.net.ALL;


ENTITY Ethernet_SGMIITransceiver_Virtex7 IS
	GENERIC (
		SIM_SPEEDUP								: BOOLEAN				:= TRUE;
		CLOCK_IN_FREQ_MHZ					: REAL					:= 125.0
	);
	PORT (
		TX_RefClock_In						: IN		STD_LOGIC;
		RX_RefClock_In						: IN		STD_LOGIC;
		TX_RefClock_Out						: OUT		STD_LOGIC;
		RX_RefClock_Out						: OUT		STD_LOGIC;

		ClockNetwork_Reset				: IN		STD_LOGIC;
		ClockNetwork_ResetDone		: OUT		STD_LOGIC;

--		Command										: IN		T_ETHERNET_SGMIITRANSCEIVER_COMMAND;
--		Status										: OUT		T_ETHERNET_SGMIITRANSCEIVER_STATUS;
--		Error											: OUT		T_ETHERNET_SGMIITRANSCEIVER_ERROR;

		TX_Data										: IN		T_SLV_16;
		TX_CharIsK								: IN		T_SLV_2;
		TX_RunningDisparity				: OUT		STD_LOGIC;

		RX_Data										: OUT		T_SLV_16;
		RX_CharIsK								: OUT		T_SLV_2;
		RX_CharIsComma						: OUT		T_SLV_2;
		RX_CharIsNotInTable				: OUT		T_SLV_2;
		RX_RunningDisparity				: OUT		STD_LOGIC;

		TX_n											: OUT		STD_LOGIC;
		TX_p											: OUT		STD_LOGIC;
		RX_n											: IN		STD_LOGIC;
		RX_p											: IN		STD_LOGIC
	);
END;

-- TODO descipbe marks:
--				ATTENTION

ARCHITECTURE rtl OF Ethernet_SGMIITransceiver_Virtex7 IS

	CONSTANT GT_SIM_GTRESET_SPEEDUP					: STRING			:= ite(SIM_SPEEDUP, "true", "false");

	SIGNAL TX_Data_i												: T_SLV_64;
	SIGNAL RX_Data_i												: T_SLV_64;

BEGIN

	TX_Data_i			<= resize(TX_Data, TX_Data_i'length);
	RX_Data				<= resize(RX_Data_i, RX_Data'length);


	GTX_Channel	: GTXE2_Channel
		GENERIC MAP (
		--_______________________ Simulation-Only Attributes ___________________
			SIM_RECEIVER_DETECT_PASS								=> "TRUE",
			SIM_RESET_SPEEDUP												=> GT_SIM_GTRESET_SPEEDUP,
			SIM_TX_EIDLE_DRIVE_LEVEL								=> "Z",
			SIM_CPLLREFCLK_SEL											=> "001",														-- ATTENTION: this signal must be the same as CPLLREFCLKSEL[2:0]
			SIM_VERSION															=> "3.0",

		 ------------------RX Byte and Word Alignment Attributes---------------
			ALIGN_COMMA_DOUBLE											=> "FALSE",
			ALIGN_COMMA_ENABLE											=> "0001111111",
			ALIGN_COMMA_WORD												=> 2,
			ALIGN_MCOMMA_DET												=> "TRUE",
			ALIGN_MCOMMA_VALUE											=> "1010000011",
			ALIGN_PCOMMA_DET												=> "TRUE",
			ALIGN_PCOMMA_VALUE											=> "0101111100",
			SHOW_REALIGN_COMMA											=> "TRUE",
			RXSLIDE_AUTO_WAIT												=> 7,
			RXSLIDE_MODE														=> "OFF",
			RX_SIG_VALID_DLY												=> 10,

		 ------------------RX 8B/10B Decoder Attributes---------------
			RX_DISPERR_SEQ_MATCH										=> "TRUE",
			DEC_MCOMMA_DETECT												=> "TRUE",
			DEC_PCOMMA_DETECT												=> "TRUE",
			DEC_VALID_COMMA_ONLY										=> "FALSE",

		 ------------------------RX Clock Correction Attributes----------------------
			CBCC_DATA_SOURCE_SEL										=> "DECODED",
			CLK_COR_SEQ_2_USE												=> "TRUE",
			CLK_COR_KEEP_IDLE												=> "FALSE",
			CLK_COR_MAX_LAT													=> 15,
			CLK_COR_MIN_LAT													=> 12,
			CLK_COR_PRECEDENCE											=> "TRUE",
			CLK_COR_REPEAT_WAIT											=> 0,
			CLK_COR_SEQ_LEN													=> 2,
			CLK_COR_SEQ_1_ENABLE										=> "1111",
			CLK_COR_SEQ_1_1													=> "0110111100",
			CLK_COR_SEQ_1_2													=> "0001010000",
			CLK_COR_SEQ_1_3													=> "0000000000",
			CLK_COR_SEQ_1_4													=> "0000000000",
			CLK_CORRECT_USE													=> "TRUE",
			CLK_COR_SEQ_2_ENABLE										=> "1111",
			CLK_COR_SEQ_2_1													=> "0110111100",
			CLK_COR_SEQ_2_2													=> "0010110101",
			CLK_COR_SEQ_2_3													=> "0000000000",
			CLK_COR_SEQ_2_4													=> "0000000000",

		 ------------------------RX Channel Bonding Attributes----------------------
			CHAN_BOND_KEEP_ALIGN										=> "FALSE",
			CHAN_BOND_MAX_SKEW											=> 1,
			CHAN_BOND_SEQ_LEN												=> 1,
			CHAN_BOND_SEQ_1_1												=> "0000000000",
			CHAN_BOND_SEQ_1_2												=> "0000000000",
			CHAN_BOND_SEQ_1_3												=> "0000000000",
			CHAN_BOND_SEQ_1_4												=> "0000000000",
			CHAN_BOND_SEQ_1_ENABLE									=> "1111",
			CHAN_BOND_SEQ_2_1												=> "0000000000",
			CHAN_BOND_SEQ_2_2												=> "0000000000",
			CHAN_BOND_SEQ_2_3												=> "0000000000",
			CHAN_BOND_SEQ_2_4												=> "0000000000",
			CHAN_BOND_SEQ_2_ENABLE									=> "1111",
			CHAN_BOND_SEQ_2_USE											=> "FALSE",
			FTS_DESKEW_SEQ_ENABLE										=> "1111",
			FTS_LANE_DESKEW_CFG											=> "1111",
			FTS_LANE_DESKEW_EN											=> "FALSE",

		 ---------------------------RX Margin Analysis Attributes----------------------------
			ES_CONTROL															=> "000000",
			ES_ERRDET_EN														=> "FALSE",
			ES_EYE_SCAN_EN													=> "TRUE",
			ES_HORZ_OFFSET													=> x"000",
			ES_PMA_CFG															=> "0000000000",
			ES_PRESCALE															=> "00000",
			ES_QUALIFIER														=> x"00000000000000000000",
			ES_QUAL_MASK														=> x"00000000000000000000",
			ES_SDATA_MASK														=> x"00000000000000000000",
			ES_VERT_OFFSET													=> "000000000",

		 -------------------------FPGA RX Interface Attributes-------------------------
			RX_DATA_WIDTH														=> 20,

		 ---------------------------PMA Attributes----------------------------
			OUTREFCLK_SEL_INV												=> "11",
			PMA_RSV																	=> x"00000000",
			PMA_RSV2																=> x"2050",
			PMA_RSV3																=> "00",
			PMA_RSV4																=> x"00000000",
			RX_BIAS_CFG															=> "000000000100",
			DMONITOR_CFG														=> x"000A00",
			RX_CM_SEL																=> "11",
			RX_CM_TRIM															=> "010",
			RX_DEBUG_CFG														=> "000000000000",
			RX_OS_CFG																=> "0000010000000",
			TERM_RCAL_CFG														=> "10000",
			TERM_RCAL_OVRD													=> '0',
			TST_RSV																	=> x"00000000",
			RX_CLK25_DIV														=> 5,
			TX_CLK25_DIV														=> 5,
			UCODEER_CLR															=> '0',

		 ---------------------------PCI Express Attributes----------------------------
			PCS_PCIE_EN															=> "FALSE",

		 ---------------------------PCS Attributes----------------------------
			PCS_RSVD_ATTR														=> x"000000000000",

		 -------------RX Buffer Attributes------------
			RXBUF_ADDR_MODE													=> "FULL",
			RXBUF_EIDLE_HI_CNT											=> "1000",
			RXBUF_EIDLE_LO_CNT											=> "0000",
			RXBUF_EN																=> "TRUE",
			RX_BUFFER_CFG														=> "000000",
			RXBUF_RESET_ON_CB_CHANGE								=> "TRUE",
			RXBUF_RESET_ON_COMMAALIGN								=> "FALSE",
			RXBUF_RESET_ON_EIDLE										=> "FALSE",
			RXBUF_RESET_ON_RATE_CHANGE							=> "TRUE",
			RXBUFRESET_TIME													=> "00001",
			RXBUF_THRESH_OVFLW											=> 61,
			RXBUF_THRESH_OVRD												=> "FALSE",
			RXBUF_THRESH_UNDFLW											=> 4,
			RXDLY_CFG																=> x"001F",
			RXDLY_LCFG															=> x"030",
			RXDLY_TAP_CFG														=> x"0000",
			RXPH_CFG																=> x"000000",
			RXPHDLY_CFG															=> x"084020",
			RXPH_MONITOR_SEL												=> "00000",
			RX_XCLK_SEL															=> "RXREC",
			RX_DDI_SEL															=> "000000",
			RX_DEFER_RESET_BUF_EN										=> "TRUE",

		 -----------------------CDR Attributes-------------------------
			RXCDR_CFG																=> x"03000023ff40080020",
			RXCDR_FR_RESET_ON_EIDLE									=> '0',
			RXCDR_HOLD_DURING_EIDLE									=> '0',
			RXCDR_PH_RESET_ON_EIDLE									=> '0',
			RXCDR_LOCK_CFG													=> "010101",

		 -------------------RX Initialization and Reset Attributes-------------------
			RXCDRFREQRESET_TIME											=> "00001",
			RXCDRPHRESET_TIME												=> "00001",
			RXISCANRESET_TIME												=> "00001",
			RXPCSRESET_TIME													=> "00001",
			RXPMARESET_TIME													=> "00011",

		 -------------------RX OOB Signaling Attributes-------------------
			RXOOB_CFG																=> "0000110",

		 -------------------------RX Gearbox Attributes---------------------------
			RXGEARBOX_EN														=> "FALSE",
			GEARBOX_MODE														=> "000",

		 -------------------------PRBS Detection Attribute-----------------------
			RXPRBS_ERR_LOOPBACK											=> '0',

		 -------------Power-Down Attributes----------
			PD_TRANS_TIME_FROM_P2										=> x"03c",
			PD_TRANS_TIME_NONE_P2										=> x"19",
			PD_TRANS_TIME_TO_P2											=> x"64",

		 -------------RX OOB Signaling Attributes----------
			SAS_MAX_COM															=> 64,
			SAS_MIN_COM															=> 36,
			SATA_BURST_SEQ_LEN											=> "1111",
			SATA_BURST_VAL													=> "100",
			SATA_EIDLE_VAL													=> "100",
			SATA_MAX_BURST													=> 8,
			SATA_MAX_INIT														=> 21,
			SATA_MAX_WAKE														=> 7,
			SATA_MIN_BURST													=> 4,
			SATA_MIN_INIT														=> 12,
			SATA_MIN_WAKE														=> 4,

		 -------------RX Fabric Clock Output Control Attributes----------
			TRANS_TIME_RATE													=> x"0E",

		 --------------TX Buffer Attributes----------------
			TXBUF_EN																=> "TRUE",
			TXBUF_RESET_ON_RATE_CHANGE							=> "TRUE",
			TXDLY_CFG																=> x"001F",
			TXDLY_LCFG															=> x"030",
			TXDLY_TAP_CFG														=> x"0000",
			TXPH_CFG																=> x"0780",
			TXPHDLY_CFG															=> x"084020",
			TXPH_MONITOR_SEL												=> "00000",
			TX_XCLK_SEL															=> "TXOUT",

		 -------------------------FPGA TX Interface Attributes-------------------------
			TX_DATA_WIDTH														=> 20,

		 -------------------------TX Configurable Driver Attributes-------------------------
			TX_DEEMPH0															=> "00000",
			TX_DEEMPH1															=> "00000",
			TX_EIDLE_ASSERT_DELAY										=> "110",
			TX_EIDLE_DEASSERT_DELAY									=> "100",
			TX_LOOPBACK_DRIVE_HIZ										=> "FALSE",
			TX_MAINCURSOR_SEL												=> '0',
			TX_DRIVE_MODE														=> "DIRECT",
			TX_MARGIN_FULL_0												=> "1001110",
			TX_MARGIN_FULL_1												=> "1001001",
			TX_MARGIN_FULL_2												=> "1000101",
			TX_MARGIN_FULL_3												=> "1000010",
			TX_MARGIN_FULL_4												=> "1000000",
			TX_MARGIN_LOW_0													=> "1000110",
			TX_MARGIN_LOW_1													=> "1000100",
			TX_MARGIN_LOW_2													=> "1000010",
			TX_MARGIN_LOW_3													=> "1000000",
			TX_MARGIN_LOW_4													=> "1000000",

		 -------------------------TX Gearbox Attributes--------------------------
			TXGEARBOX_EN														=> "FALSE",

		 -------------------------TX Initialization and Reset Attributes--------------------------
			TXPCSRESET_TIME													=> "00001",
			TXPMARESET_TIME													=> "00001",

		 -------------------------TX Receiver Detection Attributes--------------------------
			TX_RXDETECT_CFG													=> x"1832",
			TX_RXDETECT_REF													=> "100",

		 ----------------------------CPLL Attributes----------------------------
			CPLL_CFG																=> x"BC07DC",
			CPLL_FBDIV															=> 4,
			CPLL_FBDIV_45														=> 5,
			CPLL_INIT_CFG														=> x"00001E",
			CPLL_LOCK_CFG														=> x"01E8",
			CPLL_REFCLK_DIV													=> 1,
			RXOUT_DIV																=> 4,
			TXOUT_DIV																=> 4,
			SATA_CPLL_CFG														=> "VCO_3000MHZ",

		 --------------RX Initialization and Reset Attributes-------------
			RXDFELPMRESET_TIME											=> "0001111",

		 --------------RX Equalizer Attributes-------------
			RXLPM_HF_CFG														=> "00000011110000",
			RXLPM_LF_CFG														=> "00000011110000",
			RX_DFE_GAIN_CFG													=> x"020FEA",
			RX_DFE_H2_CFG														=> "000000000000",
			RX_DFE_H3_CFG														=> "000001000000",
			RX_DFE_H4_CFG														=> "00011110000",
			RX_DFE_H5_CFG														=> "00011100000",
			RX_DFE_KL_CFG														=> "0000011111110",
			RX_DFE_LPM_CFG													=> x"0954",
			RX_DFE_LPM_HOLD_DURING_EIDLE						=> '0',
			RX_DFE_UT_CFG														=> "10001111000000000",
			RX_DFE_VP_CFG														=> "00011111100000011",

		 -------------------------Power-Down Attributes-------------------------
			RX_CLKMUX_PD														=> '1',
			TX_CLKMUX_PD														=> '1',

		 -------------------------FPGA RX Interface Attribute-------------------------
			RX_INT_DATAWIDTH												=> 0,

		 -------------------------FPGA TX Interface Attribute-------------------------
			TX_INT_DATAWIDTH												=> 0,

		 ------------------TX Configurable Driver Attributes---------------
			TX_QPI_STATUS_EN												=> '0',

		 -------------------------RX Equalizer Attributes--------------------------
			RX_DFE_KL_CFG2													=> x"3008E56A",
			RX_DFE_XYD_CFG													=> "0001100010000",

		 -------------------------TX Configurable Driver Attributes--------------------------
			TX_PREDRIVER_MODE												=> '0'
		)
		PORT MAP (
			---------------------------------- Channel ---------------------------------
			CFGRESET												=> '0',
			CLKRSVD												=> "0000",
			DMONITOROUT										=> OPEN,
			GTRESETSEL											=> '0',
			GTRSVD													=> "0000000000000000",
			QPLLCLK												=> '0',
			QPLLREFCLK											=> '0',
			RESETOVRD											=> '0',
			---------------- Channel - Dynamic Reconfiguration Port (DRP) --------------
			DRPADDR												=> (OTHERS => '0'),
			DRPCLK													=> '0',
			DRPDI													=> (OTHERS => '0'),
			DRPDO													=> OPEN,
			DRPEN													=> '0',
			DRPRDY													=> OPEN,
			DRPWE													=> '0',
			------------------------- Channel - Ref Clock Ports ------------------------
			GTGREFCLK											=> '0',
			GTNORTHREFCLK0									=> '0',
			GTNORTHREFCLK1									=> '0',
			GTREFCLK0											=> GTREFCLK0_IN,
			GTREFCLK1											=> '0',
			GTREFCLKMONITOR								=> OPEN,
			GTSOUTHREFCLK0									=> '0',
			GTSOUTHREFCLK1									=> '0',
			-------------------------------- Channel PLL -------------------------------
			CPLLFBCLKLOST									=> CPLLFBCLKLOST_OUT,
			CPLLLOCK												=> CPLLLOCK_OUT,
			CPLLLOCKDETCLK									=> CPLLLOCKDETCLK_IN,
			CPLLLOCKEN											=> '1',
			CPLLPD													=> '0',
			CPLLREFCLKLOST									=> CPLLREFCLKLOST_OUT,
			CPLLREFCLKSEL									=> "001",
			CPLLRESET											=> CPLLRESET_IN,
			------------------------------- Eye Scan Ports -----------------------------
			EYESCANDATAERROR								=> EYESCANDATAERROR_OUT,
			EYESCANMODE										=> '0',
			EYESCANRESET										=> '0',
			EYESCANTRIGGER									=> '0',
			------------------------ Loopback and Powerdown Ports ----------------------
			LOOPBACK												=> LOOPBACK_IN,
			RXPD														=> RXPD_IN,
			TXPD														=> TXPD_IN,
			----------------------------- PCS Reserved Ports ---------------------------
			PCSRSVDIN											=> "0000000000000000",
			PCSRSVDIN2											=> "00000",
			PCSRSVDOUT											=> OPEN,
			----------------------------- PMA Reserved Ports ---------------------------
			PMARSVDIN											=> "00000",
			PMARSVDIN2											=> "00000",
			------------------------------- Receive Ports ------------------------------
			RXQPIEN												=> '0',
			RXQPISENN											=> OPEN,
			RXQPISENP											=> OPEN,
			RXSYSCLKSEL										=> "00",
			RXUSERRDY											=> RXUSERRDY_IN,
			-------------- Receive Ports - 64b66b and 64b67b Gearbox Ports -------------
			RXDATAVALID										=> OPEN,
			RXGEARBOXSLIP									=> '0',
			RXHEADER												=> OPEN,
			RXHEADERVALID									=> OPEN,
			RXSTARTOFSEQ										=> OPEN,
			----------------------- Receive Ports - 8b10b Decoder ----------------------
			RX8B10BEN											=> '1',
			RXCHARISCOMMA(7 DOWNTO 2)			=> rxchariscomma_float_i,
			RXCHARISCOMMA(1 DOWNTO 0)			=> RXCHARISCOMMA_OUT,
			RXCHARISK(7 DOWNTO 2)					=> rxcharisk_float_i,
			RXCHARISK(1 DOWNTO 0)					=> RXCHARISK_OUT,
			RXDISPERR(7 DOWNTO 2)					=> rxdisperr_float_i,
			RXDISPERR(1 DOWNTO 0)					=> RXDISPERR_OUT,
			RXNOTINTABLE(7 DOWNTO 2)				=> rxnotintable_float_i,
			RXNOTINTABLE(1 DOWNTO 0)				=> RXNOTINTABLE_OUT,
			------------------- Receive Ports - Channel Bonding Ports ------------------
			RXCHANBONDSEQ									=> OPEN,
			RXCHBONDEN											=> '0',
			RXCHBONDI											=> "00000",
			RXCHBONDLEVEL									=> (OTHERS => '0'),
			RXCHBONDMASTER									=> '0',
			RXCHBONDO											=> OPEN,
			RXCHBONDSLAVE									=> '0',
			------------------- Receive Ports - Channel Bonding Ports	-----------------
			RXCHANISALIGNED								=> OPEN,
			RXCHANREALIGN									=> OPEN,
			------------------- Receive Ports - Clock Correction Ports -----------------
			RXCLKCORCNT										=> RXCLKCORCNT_OUT,
			--------------- Receive Ports - Comma Detection and Alignment --------------
			RXBYTEISALIGNED								=> OPEN,
			RXBYTEREALIGN									=> OPEN,
			RXCOMMADET											=> OPEN,
			RXCOMMADETEN										=> '1',
			RXMCOMMAALIGNEN								=> RXMCOMMAALIGNEN_IN,
			RXPCOMMAALIGNEN								=> RXPCOMMAALIGNEN_IN,
			RXSLIDE												=> '0',
			----------------------- Receive Ports - PRBS Detection ---------------------
			RXPRBSCNTRESET									=> '0',
			RXPRBSERR											=> OPEN,
			RXPRBSSEL											=> (OTHERS => '0'),
			------------------- Receive Ports - RX Data Path interface -----------------
			GTRXRESET											=> GTRXRESET_IN,
			RXDATA													=> rxdata_i,
			RXOUTCLK												=> RXOUTCLK_OUT,
			RXOUTCLKFABRIC									=> OPEN,
			RXOUTCLKPCS										=> OPEN,
			RXOUTCLKSEL										=> "010",
			RXPCSRESET											=> RXPCSRESET_IN,
			RXPMARESET											=> '0',
			RXUSRCLK												=> RXUSRCLK_IN,
			RXUSRCLK2											=> RXUSRCLK2_IN,
			------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
			RXDFEAGCHOLD										=> '0',
			RXDFEAGCOVRDEN									=> '0',
			RXDFECM1EN											=> '0',
			RXDFELFHOLD										=> '0',
			RXDFELFOVRDEN									=> '1',
			RXDFELPMRESET									=> '0',
			RXDFETAP2HOLD									=> '0',
			RXDFETAP2OVRDEN								=> '0',
			RXDFETAP3HOLD									=> '0',
			RXDFETAP3OVRDEN								=> '0',
			RXDFETAP4HOLD									=> '0',
			RXDFETAP4OVRDEN								=> '0',
			RXDFETAP5HOLD									=> '0',
			RXDFETAP5OVRDEN								=> '0',
			RXDFEUTHOLD										=> '0',
			RXDFEUTOVRDEN									=> '0',
			RXDFEVPHOLD										=> '0',
			RXDFEVPOVRDEN									=> '0',
			RXDFEVSEN											=> '0',
			RXDFEXYDEN											=> '0',
			RXDFEXYDHOLD										=> '0',
			RXDFEXYDOVRDEN									=> '0',
			RXMONITOROUT										=> OPEN,
			RXMONITORSEL										=> "00",
			RXOSHOLD												=> '0',
			RXOSOVRDEN											=> '0',
			------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
			GTXRXN													=> GTXRXN_IN,
			GTXRXP													=> GTXRXP_IN,
			RXCDRFREQRESET									=> '0',
			RXCDRHOLD											=> '0',
			RXCDRLOCK											=> RXCDRLOCK_OUT,
			RXCDROVRDEN										=> '0',
			RXCDRRESET											=> '0',
			RXCDRRESETRSV									=> '0',
			RXELECIDLE											=> RXELECIDLE_OUT,
			RXELECIDLEMODE									=> "10",
			RXLPMEN												=> '0',
			RXLPMHFHOLD										=> '0',
			RXLPMHFOVRDEN									=> '0',
			RXLPMLFHOLD										=> '0',
			RXLPMLFKLOVRDEN								=> '0',
			RXOOBRESET											=> '0',
			-------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
			RXBUFRESET											=> RXBUFRESET_IN,
			RXBUFSTATUS										=> RXBUFSTATUS_OUT,
			RXDDIEN												=> '0',
			RXDLYBYPASS										=> '1',
			RXDLYEN												=> '0',
			RXDLYOVRDEN										=> '0',
			RXDLYSRESET										=> '0',
			RXDLYSRESETDONE								=> OPEN,
			RXPHALIGN											=> '0',
			RXPHALIGNDONE									=> OPEN,
			RXPHALIGNEN										=> '0',
			RXPHDLYPD											=> '0',
			RXPHDLYRESET										=> '0',
			RXPHMONITOR										=> OPEN,
			RXPHOVRDEN											=> '0',
			RXPHSLIPMONITOR								=> OPEN,
			RXSTATUS												=> OPEN,
			------------------------ Receive Ports - RX PLL Ports ----------------------
			RXRATE													=> (OTHERS => '0'),
			RXRATEDONE											=> OPEN,
			RXRESETDONE										=> RXRESETDONE_OUT,
			-------------- Receive Ports - RX Pipe Control for PCI Express -------------
			PHYSTATUS											=> OPEN,
			RXVALID												=> OPEN,
			----------------- Receive Ports - RX Polarity Control Ports ----------------
			RXPOLARITY											=> '0',
			--------------------- Receive Ports - RX Ports for SATA --------------------
			RXCOMINITDET										=> OPEN,
			RXCOMSASDET										=> OPEN,
			RXCOMWAKEDET										=> OPEN,
			------------------------------- Transmit Ports -----------------------------
			SETERRSTATUS										=> '0',
			TSTIN													=> "11111111111111111111",
			TSTOUT													=> OPEN,
			TXPHDLYTSTCLK									=> '0',
			TXPOSTCURSOR										=> "00000",
			TXPOSTCURSORINV								=> '0',
			TXPRECURSOR										=> (OTHERS => '0'),
			TXPRECURSORINV									=> '0',
			TXQPIBIASEN										=> '0',
			TXQPISENN											=> OPEN,
			TXQPISENP											=> OPEN,
			TXQPISTRONGPDOWN								=> '0',
			TXQPIWEAKPUP										=> '0',
			TXSYSCLKSEL										=> "00",
			TXUSERRDY											=> TXUSERRDY_IN,
			-------------- Transmit Ports - 64b66b and 64b67b Gearbox Ports ------------
			TXGEARBOXREADY									=> OPEN,
			TXHEADER												=> (OTHERS => '0'),
			TXSEQUENCE											=> (OTHERS => '0'),
			TXSTARTSEQ											=> '0',
			---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
			TX8B10BBYPASS									=> (OTHERS => '0'),
			TX8B10BEN											=> '1',
			TXCHARDISPMODE(7 DOWNTO 2)			=> (OTHERS => '0'),
			TXCHARDISPMODE(1 DOWNTO 0)			=> TXCHARDISPMODE_IN,
			TXCHARDISPVAL(7 DOWNTO 2)			=> (OTHERS => '0'),
			TXCHARDISPVAL(1 DOWNTO 0)			=> TXCHARDISPVAL_IN,
			TXCHARISK(7 DOWNTO 2)					=> (OTHERS => '0'),
			TXCHARISK(1 DOWNTO 0)					=> TXCHARISK_IN,
			------------ Transmit Ports - TX Buffer and Phase Alignment Ports ----------
			TXBUFSTATUS										=> TXBUFSTATUS_OUT,
			TXDLYBYPASS										=> '1',
			TXDLYEN												=> '0',
			TXDLYHOLD											=> '0',
			TXDLYOVRDEN										=> '0',
			TXDLYSRESET										=> '0',
			TXDLYSRESETDONE								=> OPEN,
			TXDLYUPDOWN										=> '0',
			TXPHALIGN											=> '0',
			TXPHALIGNDONE									=> OPEN,
			TXPHALIGNEN										=> '0',
			TXPHDLYPD											=> '0',
			TXPHDLYRESET										=> '0',
			TXPHINIT												=> '0',
			TXPHINITDONE										=> OPEN,
			TXPHOVRDEN											=> '0',
			------------------ Transmit Ports - TX Data Path interface -----------------
			GTTXRESET											=> GTTXRESET_IN,
			TXDATA													=> txdata_i,
			TXOUTCLK												=> TXOUTCLK_OUT,
			TXOUTCLKFABRIC									=> TXOUTCLKFABRIC_OUT,
			TXOUTCLKPCS										=> TXOUTCLKPCS_OUT,
			TXOUTCLKSEL										=> "100",
			TXPCSRESET											=> TXPCSRESET_IN,
			TXPMARESET											=> '0',
			TXUSRCLK												=> TXUSRCLK_IN,
			TXUSRCLK2											=> TXUSRCLK2_IN,
			---------------- Transmit Ports - TX Driver and OOB signaling --------------
			GTXTXN													=> TX_n,
			GTXTXP													=> TX_p,
			TXBUFDIFFCTRL									=> "100",
			TXDIFFCTRL											=> "1000",
			TXDIFFPD												=> '0',
			TXINHIBIT											=> '0',
			TXMAINCURSOR										=> "0000000",
			TXPDELECIDLEMODE								=> '0',
			TXPISOPD												=> '0',
			----------------------- Transmit Ports - TX PLL Ports ----------------------
			TXRATE													=> (OTHERS => '0'),
			TXRATEDONE											=> OPEN,
			TXRESETDONE										=> TXRESETDONE_OUT,
			--------------------- Transmit Ports - TX PRBS Generator -------------------
			TXPRBSFORCEERR									=> '0',
			TXPRBSSEL											=> (OTHERS => '0'),
			-------------------- Transmit Ports - TX Polarity Control ------------------
			TXPOLARITY											=> '0',
			----------------- Transmit Ports - TX Ports for PCI Express ----------------
			TXDEEMPH												=> '0',
			TXDETECTRX											=> '0',
			TXELECIDLE											=> TXPD_IN(0),
			TXMARGIN												=> (OTHERS => '0'),
			TXSWING												=> '0',
			--------------------- Transmit Ports - TX Ports for SATA -------------------
			TXCOMFINISH										=> OPEN,
			TXCOMINIT											=> '0',
			TXCOMSAS												=> '0',
			TXCOMWAKE											=> '0'
		);
END;
