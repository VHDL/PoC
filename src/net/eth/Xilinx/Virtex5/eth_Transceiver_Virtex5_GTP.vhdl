library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library UNISIM;
use			UNISIM.VcomponentS.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;
use			PoC.io.all;
use			PoC.xil.all;


entity eth_Transceiver_Virtex5_GTP is
	generic (
		DEBUG											: BOOLEAN											:= FALSE;																	-- generate ChipScope debugging "pins"
		CLOCK_IN_FREQ							: FREQ												:= 125 MHz;																-- 150 MHz
		PORTS											: POSITIVE										:= 2																			-- Number of Ports per Transceiver
	);
	port (
		PowerDown								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RefClockIn_125_MHz			: in	STD_LOGIC;
		ClockNetwork_Reset			: in	STD_LOGIC;
		ClockNetwork_ResetDone	: out	STD_LOGIC;

		TX_Clock								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_Clock								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		TX_Reset								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_Reset								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		LoopBack								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);										-- perform loopback testing
		EnableCommaAlign				: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);						-- enable comma alignment

		-- TX interface
		TX_Data									: in	T_SLVV_8(PORTS - 1 downto 0);
		TX_CharIsK							: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		TX_DisparityMode				: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		TX_DisparityValue				: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		TX_BufferError					: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		-- RX interface
		RX_Data									: out	T_SLVV_8(PORTS - 1 downto 0);
		RX_CharIsK							: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_CharIsComma					: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_RunningDisparity			: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_DisparityError				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_NotInTable						: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_BufferStatus					: out	T_SLVV_2(PORTS - 1 downto 0);
		RX_ClockCorrectionCount	: out	T_SLVV_3(PORTS - 1 downto 0);

		TX_ds										: out	T_IO_LVDS_VECTOR(PORTS - 1 downto 0);
		RX_ds										: in	T_IO_LVDS_VECTOR(PORTS - 1 downto 0)
	);
end;


architecture rtl of eth_Transceiver_Virtex5_GTP is
	attribute KEEP 														: BOOLEAN;
	attribute TNM 														: STRING;

	-- ===========================================================================
	-- Ethernet SGMII configuration
	-- ===========================================================================
	constant C_DEVICE_INFO										: T_DEVICE_INFO		:= DEVICE_INFO;

	signal ClockIn_125MHz											: STD_LOGIC;
	signal ResetDone_i												: STD_LOGIC_VECTOR(PORTS - 1 downto 0);

	signal GTP_Reset													: STD_LOGIC;
	signal GTP_ResetDone											: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal GTP_ResetDone_i										: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal GTP_PLL_Reset											: STD_LOGIC;
	signal GTP_PLL_ResetDone									:	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal GTP_PLL_ResetDone_i								:	STD_LOGIC;

	signal GTP_RefClockIn											: STD_LOGIC;
	signal GTP_RefClockOut										: STD_LOGIC;
	signal GTP_RefClockOut_i									: STD_LOGIC;
	signal GTP_TX_RefClockOut									: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal GTP_RX_RefClockOut									: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal Control_Clock											: STD_LOGIC;

	signal ClkNet_Reset												: STD_LOGIC;
	signal ClkNet_Reset_i											: STD_LOGIC;
	signal ClkNet_Reset_x											: STD_LOGIC;
	signal ClkNet_ResetDone										: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal ClkNet_ResetDone_i									: STD_LOGIC;
	signal ClockNetwork_ResetDone_i						: STD_LOGIC_VECTOR(PORTS - 1 downto 0);

	signal GTP_PortReset											: STD_LOGIC_VECTOR(PORTS - 1 downto 0);

	-- keep internal clock nets, so timing constrains from UCF can find them
	attribute KEEP OF GTP_TX_RefClockOut			: signal IS DEBUG;
	attribute KEEP OF GTP_RX_RefClockOut			: signal IS DEBUG;
	attribute KEEP OF GTP_RefClockOut 				: signal IS DEBUG;

--	attribute KEEP OF SATA_Clock_i										: signal IS TRUE;
--	attribute TNM OF SATA_Clock_i											: signal IS "TGRP_SATA_Clock0";

	signal RX_CharIsComma_float								: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal RX_CharIsK_float										: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal RX_DisparityError_float						: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal RX_Data_float											: T_SLVV_8(PORTS - 1 downto 0);
	signal RX_NotInTable_float								: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal RX_RunningDisparity_float					: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal GTP_RX_BufferStatus_float					: T_SLVV_2(PORTS - 1 downto 0);
	signal GTP_TX_BufferStatus_float					: T_SLVV_2(PORTS - 1 downto 0);

begin
	-- ===========================================================================
	-- Assert statements
	-- ===========================================================================
	assert (C_DEVICE_INFO.VENDOR = VENDOR_XILINX)						report "Vendor not yet supported."				severity FAILURE;
	assert (C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_VIRTEX)	report "Device family not yet supported."	severity FAILURE;
	assert (C_DEVICE_INFO.DEVICE = DEVICE_VIRTEX5)					report "Device not yet supported."				severity FAILURE;
	assert (PORTS <= 2)																			report "To many ports per transceiver."		severity FAILURE;

	-- ===========================================================================
	-- ResetControl
	-- ===========================================================================
	ClkNet_Reset_i										<= ClockNetwork_Reset;

	blkSync1 : block
		signal ClkNet_Reset_shift				: STD_LOGIC_VECTOR(15 downto 0)				:= (others => '0');
	begin
		process(Control_Clock)
		begin
			if rising_edge(Control_Clock) then
				ClkNet_Reset_shift		<= ClkNet_Reset_shift(ClkNet_Reset_shift'high - 1 downto 0) & ClkNet_Reset_i;
			end if;
		end process;

		ClkNet_Reset		<= ClkNet_Reset_shift(2);
		ClkNet_Reset_x	<= ClkNet_Reset_shift(ClkNet_Reset_shift'high);
	end block;

	GTP_PLL_Reset											<= ClkNet_Reset;
	GTP_Reset													<= GTP_PLL_Reset;					-- PLL reset must be mapped to global GTP reset

	genSync0 : for i in 0 to PORTS - 1 generate
		signal GTP_Reset_meta						: STD_LOGIC				:= '0';
		signal GTP_Reset_d							: STD_LOGIC				:= '0';

		-- ------------------------------------------
		signal ClkNet_ResetDone_meta		: STD_LOGIC				:= '0';
		signal ClkNet_ResetDone_d				: STD_LOGIC				:= '0';

		signal GTP_PLL_ResetDone_meta		: STD_LOGIC				:= '0';
		signal GTP_PLL_ResetDone_d			: STD_LOGIC				:= '0';

		signal GTP_ResetDone_meta				: STD_LOGIC				:= '0';
		signal GTP_ResetDone_d					: STD_LOGIC				:= '0';

	begin
		GTP_Reset_meta									<= GTP_Reset				when rising_edge(Control_Clock);
		GTP_Reset_d											<= GTP_Reset_meta		when rising_edge(Control_Clock);

		-- ------------------------------------------
--		ClkNet_ResetDone_meta						<= ClkNet_ResetDone_i			when rising_edge(Control_Clock);
--		ClkNet_ResetDone_d							<= ClkNet_ResetDone_meta	when rising_edge(Control_Clock);
		ClkNet_ResetDone(I)							<= ClkNet_ResetDone_i;

		GTP_PLL_ResetDone_meta					<= GTP_PLL_ResetDone_i		when rising_edge(Control_Clock);
		GTP_PLL_ResetDone_d							<= GTP_PLL_ResetDone_meta	when rising_edge(Control_Clock);
		GTP_PLL_ResetDone(I)						<= GTP_PLL_ResetDone_d;

		GTP_ResetDone_meta							<= GTP_ResetDone_i(I)			when rising_edge(Control_Clock);
		GTP_ResetDone_d									<= GTP_ResetDone_meta			when rising_edge(Control_Clock);
		GTP_ResetDone(I)								<= GTP_ResetDone_d;
	end generate;

	ClockNetwork_ResetDone						<= ClkNet_ResetDone;

	ClockNetwork_ResetDone_i					<= GTP_PLL_ResetDone				AND ClkNet_ResetDone;
--	ResetDone													<= ClockNetwork_ResetDone_i AND GTP_ResetDone;

	-- ==================================================================
	-- ClockNetwork (37.5, 75, 150, 300 MHz)
	-- ==================================================================
	GTP_RefClockIn		<= RefClockIn_125_MHz;

	BUFG_GTP_RefClockOut : BUFG
		port map (
			I		=> GTP_RefClockOut_i,
			O		=> GTP_RefClockOut
		);

	Control_Clock										<= GTP_RefClockOut;							-- use stable clock after GTP_DUAL / before DCM for reset control and so on


	-- ===========================================================================
	-- GTP_DUAL - 1 used port
	-- ===========================================================================
	SinglePort : if (PORTS = 1) generate

	begin
		GTP : GTP_DUAL
			generic map (
				-- ===================== Simulation-Only Attributes ====================
				SIM_RECEIVER_DETECT_PASS0	 		=>			 TRUE,
				SIM_RECEIVER_DETECT_PASS1	 		=>			 TRUE,
				SIM_MODE											=>			 "FAST",
				SIM_GTPRESET_SPEEDUP					=>			 1,
				SIM_PLL_PERDIV2								=>			 x"190",

				-- ========================== Shared Attributes ========================
				-------------------------- Tile and PLL Attributes ---------------------
				CLK25_DIVIDER									=>			 5, 						--
				CLKINDC_B											=>			 TRUE,					--
				OOB_CLK_DIVIDER								=>			 4,							--
				OVERSAMPLE_MODE								=>			 FALSE,					--
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
				PLL_TXDIVSEL_OUT_0						=>			 2,												--
				PLL_TXDIVSEL_OUT_1						=>			 2,												--

				--------------------- TX Driver and OOB signalling --------------------
				TX_DIFF_BOOST_0								=>			 TRUE,
				TX_DIFF_BOOST_1								=>			 TRUE,

				------------------ TX Pipe Control for PCI Express/SATA ---------------
				COM_BURST_VAL_0								=>			 "1111",																	-- TX OOB burst counter
				COM_BURST_VAL_1								=>			 "1111",																	-- TX OOB burst counter

				-- =================== Receive Interface Attributes ===================
				------------ RX Driver,OOB signalling,Coupling and Eq,CDR -------------
				AC_CAP_DIS_0									=>			 FALSE,
				OOBDETECT_THRESHOLD_0					=>			 "001",																		-- Threshold between RXN and RXP is 105 mV
				PMA_CDR_SCAN_0								=>			 x"6c07640",
				PMA_RX_CFG_0									=>			 x"09f0088",
				RCV_TERM_GND_0								=>			 FALSE,
				RCV_TERM_MID_0								=>			 FALSE,
				RCV_TERM_VTTRX_0							=>			 FALSE,
				TERMINATION_IMP_0							=>			 50,																			-- 50 Ohm Terminierung

				AC_CAP_DIS_1									=>			 FALSE,
				OOBDETECT_THRESHOLD_1					=>			 "001",																		-- Threshold between RXN and RXP is 105 mV
				PMA_CDR_SCAN_1								=>			 x"6c07640",
				PMA_RX_CFG_1									=>			 x"09f0088",
				RCV_TERM_GND_1								=>			 FALSE,
				RCV_TERM_MID_1								=>			 FALSE,
				RCV_TERM_VTTRX_1							=>			 FALSE,
				TERMINATION_IMP_1							=>			 50,																			-- 50 Ohm Terminierung

				PCS_COM_CFG										=>			 x"1680a0e",
				TERMINATION_CTRL							=>			 "10100",
				TERMINATION_OVRD							=>			 FALSE,

				--------------------- RX Serial Line Rate Attributes ------------------
				PLL_RXDIVSEL_OUT_0						=>			 2,												--
				PLL_RXDIVSEL_OUT_1						=>			 2,

				PLL_SATA_0										=>			 FALSE,
				PLL_SATA_1										=>			 FALSE,

				----------------------- PRBS Detection Attributes ---------------------
				PRBS_ERR_THRESHOLD_0					=>			 x"00000001",
				PRBS_ERR_THRESHOLD_1					=>			 x"00000001",

				---------------- Comma Detection and Alignment Attributes -------------
				ALIGN_COMMA_WORD_0						=>			 1,
				COMMA_10B_ENABLE_0						=>			 "0001111111",
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
				COMMA_10B_ENABLE_1						=>			 "0001111111",
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
				CLK_COR_ADJ_LEN_0							=>			 2,
				CLK_COR_DET_LEN_0							=>			 2,
				CLK_COR_INSERT_IDLE_FLAG_0		=>			 FALSE,
				CLK_COR_KEEP_IDLE_0						=>			 FALSE,
				CLK_COR_MIN_LAT_0							=>			 16,
				CLK_COR_MAX_LAT_0							=>			 18,
				CLK_COR_PRECEDENCE_0					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_0					=>			 0,
				CLK_COR_SEQ_1_1_0							=>			 "0110111100",
				CLK_COR_SEQ_1_2_0							=>			 "0001010000",
				CLK_COR_SEQ_1_3_0							=>			 "0000000000",
				CLK_COR_SEQ_1_4_0							=>			 "0000000000",
				CLK_COR_SEQ_1_ENABLE_0				=>			 "0011",
				CLK_COR_SEQ_2_1_0							=>			 "0110111100",
				CLK_COR_SEQ_2_2_0							=>			 "0010110101",
				CLK_COR_SEQ_2_3_0							=>			 "0000000000",
				CLK_COR_SEQ_2_4_0							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_0				=>			 "0011",
				CLK_COR_SEQ_2_USE_0						=>			 TRUE,
				RX_DECODE_SEQ_MATCH_0					=>			 TRUE,

				CLK_CORRECT_USE_1							=>			 TRUE,
				CLK_COR_ADJ_LEN_1							=>			 2,
				CLK_COR_DET_LEN_1							=>			 2,
				CLK_COR_INSERT_IDLE_FLAG_1		=>			 FALSE,
				CLK_COR_KEEP_IDLE_1						=>			 FALSE,
				CLK_COR_MIN_LAT_1							=>			 16,
				CLK_COR_MAX_LAT_1							=>			 18,
				CLK_COR_PRECEDENCE_1					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_1					=>			 0,
				CLK_COR_SEQ_1_1_1							=>			 "0110111100",
				CLK_COR_SEQ_1_2_1							=>			 "0001010000",
				CLK_COR_SEQ_1_3_1							=>			 "0000000000",
				CLK_COR_SEQ_1_4_1							=>			 "0000000000",
				CLK_COR_SEQ_1_ENABLE_1				=>			 "0011",
				CLK_COR_SEQ_2_1_1							=>			 "0110111100",
				CLK_COR_SEQ_2_2_1							=>			 "0010110101",
				CLK_COR_SEQ_2_3_1							=>			 "0000000000",
				CLK_COR_SEQ_2_4_1							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_1				=>			 "0011",
				CLK_COR_SEQ_2_USE_1						=>			 TRUE,
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
				-- OOB COM*** signal detector @ 25 MHz with DDR (20 ns)
				RX_STATUS_FMT_0								=>			 "PCIE",
				SATA_BURST_VAL_0							=>			 "100",							-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL_0								=>			 "100",							-- IDLE count between bursts in OOB COM*** signals
				SATA_MIN_BURST_0							=>			 5,									--
				SATA_MAX_BURST_0							=>			 9,									--
				SATA_MIN_INIT_0								=>			 15,								--
				SATA_MAX_INIT_0								=>			 27,								--
				SATA_MIN_WAKE_0								=>			 5,									--
				SATA_MAX_WAKE_0								=>			 9,									--
				TRANS_TIME_FROM_P2_0					=>			 x"0060",
				TRANS_TIME_NON_P2_0						=>			 x"0025",
				TRANS_TIME_TO_P2_0						=>			 x"0100",

				RX_STATUS_FMT_1								=>			"PCIE",
				SATA_BURST_VAL_1							=>			"100",							-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL_1								=>			"100",							-- IDLE count between bursts in OOB COM*** signals
				SATA_MIN_BURST_1							=>			 5,									--
				SATA_MAX_BURST_1							=>			 9,									--
				SATA_MIN_INIT_1								=>			 15,								--
				SATA_MAX_INIT_1								=>			 27,								--
				SATA_MIN_WAKE_1								=>			 5,									--
				SATA_MAX_WAKE_1								=>			 9,									--
				TRANS_TIME_FROM_P2_1					=>			x"0060",
				TRANS_TIME_NON_P2_1						=>			x"0025",
				TRANS_TIME_TO_P2_1						=>			x"0100"
			)
			port map (
				------------------------ Loopback and Powerdown Ports ----------------------
				LOOPBACK0(0)									=>			Loopback(0),
				LOOPBACK0(2 downto 1)					=>			"00",
				LOOPBACK1											=>			"000",
				TXPOWERDOWN0									=>			(others => Powerdown(0)),
				RXPOWERDOWN0									=>			(others => Powerdown(0)),
				TXPOWERDOWN1									=>			(others => '1'),
				RXPOWERDOWN1									=>			(others => '1'),
				----------------------- Receive Ports - 8b10b Decoder ----------------------
				RXCHARISCOMMA0(0)							=>			RX_CharIsComma(0),						-- @ GTP_ClockRX_2X,
				RXCHARISCOMMA0(1)							=>			RX_CharIsComma_float(0),			-- @ GTP_ClockRX_2X,
				RXCHARISCOMMA1								=>			open,
				RXCHARISK0(0)									=>			RX_CharIsK(0),								-- @ GTP_ClockRX_2X,
				RXCHARISK0(1)									=>			RX_CharIsK_float(0),					-- @ GTP_ClockRX_2X,
				RXCHARISK1										=>			open,
				RXDEC8B10BUSE0								=>			'1',
				RXDEC8B10BUSE1								=>			'1',
				RXDISPERR0(0)									=>			RX_DisparityError(0),					-- @ GTP_ClockRX_2X,
				RXDISPERR0(1)									=>			RX_DisparityError_float(0),		-- @ GTP_ClockRX_2X,
				RXDISPERR1										=>			open,
				RXNOTINTABLE0(0)							=>			RX_NotInTable(0),							-- @ GTP_ClockRX_2X,
				RXNOTINTABLE0(1)							=>			RX_NotInTable_float(0),				-- @ GTP_ClockRX_2X,
				RXNOTINTABLE1									=>			open,
				RXRUNDISP0(0)									=>			RX_RunningDisparity(0),
				RXRUNDISP0(1)									=>			RX_RunningDisparity_float(0),
				RXRUNDISP1										=>			open,
				------------------- Receive Ports - Channel Bonding Ports ------------------
				RXCHANBONDSEQ0								=>			open,
				RXCHANBONDSEQ1								=>			open,
				RXCHBONDI0										=>			"000",
				RXCHBONDI1										=>			"000",
				RXCHBONDO0										=>			open,
				RXCHBONDO1										=>			open,
				RXENCHANSYNC0									=>			'0',
				RXENCHANSYNC1									=>			'0',
				------------------- Receive Ports - Clock Correction Ports -----------------
				RXCLKCORCNT0									=>			RX_ClockCorrectionCount(0),
				RXCLKCORCNT1									=>			open,
				--------------- Receive Ports - Comma Detection and Alignment --------------
				RXBYTEISALIGNED0							=>			open,	--RX_ByteIsAligned(0),									-- @ GTP_ClockRX_2X,	high-active, long signal			bytes are aligned
				RXBYTEISALIGNED1							=>			open,	--RX_ByteIsAligned(1),
				RXBYTEREALIGN0								=>			open,	--RX_ByteRealign(0),										-- @ GTP_ClockRX_2X,	hight-active, short pulse			alignment has changed
				RXBYTEREALIGN1								=>			open,	--RX_ByteRealign(1),
				RXCOMMADET0										=>			open,	--RX_CommaDetected(0),
				RXCOMMADET1										=>			open,	--RX_CommaDetected(1),
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
				RXPRBSERR0										=>			open,
				RXPRBSERR1										=>			open,
				------------------- Receive Ports - RX Data Path interface -----------------
				RXDATA0(7 downto 0)						=>			RX_Data(0),
				RXDATA0(15 downto 8)					=>			RX_Data_float(0),
				RXDATA1												=>			open,
				RXDATAWIDTH0									=>			'0',																			-- 8 Bit data interface
				RXDATAWIDTH1									=>			'0',																			-- 8 Bit data interface
				RXRECCLK0											=>			GTP_RX_RefClockOut(0),										-- recovered clock from CDR
				RXRECCLK1											=>			open,
				RXRESET0											=>			RX_Reset(0),
				RXRESET1											=>			'0',
				RXUSRCLK0											=>			RX_Clock(0),
				RXUSRCLK1											=>			'0',
				RXUSRCLK20										=>			RX_Clock(0),
				RXUSRCLK21										=>			'0',
				------- Receive Ports - RX Driver,OOB signaling,Coupling and Eq.,CDR ------
				RXCDRRESET0										=>			'0',											-- CDR => Clock Data Recovery
				RXCDRRESET1										=>			'0',
				RXELECIDLE0										=>			open,
				RXELECIDLE1										=>			open,
				RXELECIDLERESET0							=>			'0',
				RXELECIDLERESET1							=>			'0',
				RXENEQB0											=>			'1',
				RXENEQB1											=>			'1',
				RXEQMIX0											=>			"00",
				RXEQMIX1											=>			"00",
				RXEQPOLE0											=>			"0000",
				RXEQPOLE1											=>			"0000",
				RXN0													=>			RX_ds(0).N,
				RXP0													=>			RX_ds(0).P,
				RXN1													=>			'0',
				RXP1													=>			'1',
				-------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
				RXBUFRESET0										=>			RX_Reset(0),
				RXBUFRESET1										=>			'0',
				RXBUFSTATUS0(1 downto 0)			=>			GTP_RX_BufferStatus_float(0),					-- GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXBUFSTATUS0(2)								=>			RX_BufferError(0),										-- GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXBUFSTATUS1									=>			open,																	-- GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXCHANISALIGNED0							=>			open,
				RXCHANISALIGNED1							=>			open,
				RXCHANREALIGN0								=>			open,
				RXCHANREALIGN1								=>			open,
				RXPMASETPHASE0								=>			'0',
				RXPMASETPHASE1								=>			'0',
				RXSTATUS0											=>			open,
				RXSTATUS1											=>			open,
				--------------- Receive Ports - RX Loss-of-sync State Machine --------------
				RXLOSSOFSYNC0									=>			open,											-- Xilinx example has connected signal
				RXLOSSOFSYNC1									=>			open,
				---------------------- Receive Ports - RX Oversampling ---------------------
				RXENSAMPLEALIGN0							=>			'0',
				RXENSAMPLEALIGN1							=>			'0',
				RXOVERSAMPLEERR0							=>			open,
				RXOVERSAMPLEERR1							=>			open,
				-------------- Receive Ports - RX Pipe Control for PCI Express -------------
				PHYSTATUS0										=>			open,
				PHYSTATUS1										=>			open,
				RXVALID0											=>			open,
				RXVALID1											=>			open,
				----------------- Receive Ports - RX Polarity Control Ports ----------------
				RXPOLARITY0										=>			'0',
				RXPOLARITY1										=>			'0',
				------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
				DCLK													=>			'0',
				DEN														=>			'0',
				DADDR													=>			(others => '0'),																			-- resize vector to GTP_DUAL specific address bits
				DWE														=>			'0',
				DI														=>			(others => '0'),
				DO														=>			open,
				DRDY													=>			open,
				--------------------- Shared Ports - Tile and PLL Ports --------------------
				CLKIN													=>			GTP_RefClockIn,
				GTPRESET											=>			GTP_Reset,
				GTPTEST												=>			"0000",
				INTDATAWIDTH									=>			'1',																									-- 10 Bit internal datawidth
				PLLLKDET											=>			GTP_PLL_ResetDone_i,																	-- GTP PLL lock detected
				PLLLKDETEN										=>			'1',
				PLLPOWERDOWN									=>			'0',
				REFCLKOUT											=>			GTP_RefClockOut_i,
				REFCLKPWRDNB									=>			'1',
				RESETDONE0										=>			GTP_ResetDone_i(0),
				RESETDONE1										=>			open,
				RXENELECIDLERESETB						=>			'1',																									-- low-active => disable
				TXENPMAPHASEALIGN							=>			'0',
				TXPMASETPHASE									=>			'0',
					---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
				TXBYPASS8B10B0								=>			"00",																									-- encode both bytes with 8B10B
				TXBYPASS8B10B1								=>			"00",
				TXCHARDISPMODE0(0)						=>			TX_DisparityMode(0),
				TXCHARDISPMODE0(1)						=>			'0',
				TXCHARDISPMODE1								=>			"00",
				TXCHARDISPVAL0(0)							=>			TX_DisparityValue(0),
				TXCHARDISPVAL0(1)							=>			'0',
				TXCHARDISPVAL1								=>			"00",
				TXCHARISK0(0)									=>			TX_CharIsK(0),
				TXCHARISK0(1)									=>			'0',
				TXCHARISK1										=>			"00",
				TXENC8B10BUSE0								=>			'1',																									-- use internal 8B10B encoder
				TXENC8B10BUSE1								=>			'1',
				TXKERR0												=>			open,																									-- invalid K charakter
				TXKERR1												=>			open,
				TXRUNDISP0										=>			open,																									-- running disparity
				TXRUNDISP1										=>			open,
				------------- Transmit Ports - TX Buffering and Phase Alignment ------------
				TXBUFSTATUS0(0)								=>			GTP_TX_BufferStatus_float(0),
				TXBUFSTATUS0(1)								=>			TX_BufferError(0),
				TXBUFSTATUS1									=>			open,
				------------------ Transmit Ports - TX Data Path interface -----------------
				TXDATA0(7 downto 0)						=>			TX_Data(0),
				TXDATA0(15 downto 8)					=>			(others => '0'),
				TXDATA1												=>			(others => '0'),
				TXDATAWIDTH0									=>			'0',																									-- 8 Bit interface
				TXDATAWIDTH1									=>			'0',
				TXOUTCLK0											=>			GTP_TX_RefClockOut(0),
				TXOUTCLK1											=>			open,
				TXRESET0											=>			TX_Reset(0),
				TXRESET1											=>			'0',												-- GTP_TX_Reset
				TXUSRCLK0											=>			TX_Clock(0),
				TXUSRCLK1											=>			'0',												--
				TXUSRCLK20										=>			TX_Clock(0),								--
				TXUSRCLK21										=>			'0',												--
				--------------- Transmit Ports - TX Driver and OOB signaling --------------
				TXBUFDIFFCTRL0								=>			"000",
				TXBUFDIFFCTRL1								=>			"000",
				TXDIFFCTRL0										=>			"000",
				TXDIFFCTRL1										=>			"000",
				TXINHIBIT0										=>			'0',
				TXINHIBIT1										=>			'0',
				TXN0													=>			TX_ds(0).N,
				TXP0													=>			TX_ds(0).P,
				TXN1													=>			open,
				TXP1													=>			open,
				TXPREEMPHASIS0								=>			"000",
				TXPREEMPHASIS1								=>			"000",
				--------------------- Transmit Ports - TX PRBS Generator -------------------
				TXENPRBSTST0									=>			"00",
				TXENPRBSTST1									=>			"00",
				-------------------- Transmit Ports - TX Polarity Control ------------------
				TXPOLARITY0										=>			'0',
				TXPOLARITY1										=>			'0',
					----------------- Transmit Ports - TX Ports for PCI Express ----------------
				TXDETECTRX0										=>			'0',
				TXDETECTRX1										=>			'0',
				TXELECIDLE0										=>			'0',
				TXELECIDLE1										=>			'0',
					--------------------- Transmit Ports - TX Ports for SATA -------------------
				TXCOMSTART0										=>			'0',
				TXCOMSTART1										=>			'0',
				TXCOMTYPE0										=>			'0',
				TXCOMTYPE1										=>			'0'
			);
	end generate;


	-- ===========================================================================
	-- GTP_DUAL - 2 used ports
	-- ===========================================================================
	DualPort : if (PORTS = 2) generate

	begin

		GTP : GTP_DUAL
			generic map (
				-- ===================== Simulation-Only Attributes ====================
				SIM_RECEIVER_DETECT_PASS0	 		=>			 TRUE,
				SIM_RECEIVER_DETECT_PASS1	 		=>			 TRUE,
				SIM_MODE											=>			 "FAST",
				SIM_GTPRESET_SPEEDUP					=>			 1,
				SIM_PLL_PERDIV2								=>			 x"190",

				-- ========================== Shared Attributes ========================
				-------------------------- Tile and PLL Attributes ---------------------
				CLK25_DIVIDER									=>			 5, 						--
				CLKINDC_B											=>			 TRUE,					--
				OOB_CLK_DIVIDER								=>			 4,							--
				OVERSAMPLE_MODE								=>			 FALSE,					--
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
				PLL_TXDIVSEL_OUT_0						=>			 2,												--
				PLL_TXDIVSEL_OUT_1						=>			 2,												--

				--------------------- TX Driver and OOB signalling --------------------
				TX_DIFF_BOOST_0								=>			 TRUE,
				TX_DIFF_BOOST_1								=>			 TRUE,

				------------------ TX Pipe Control for PCI Express/SATA ---------------
				COM_BURST_VAL_0								=>			 "1111",																	-- TX OOB burst counter
				COM_BURST_VAL_1								=>			 "1111",																	-- TX OOB burst counter

				-- =================== Receive Interface Attributes ===================
				------------ RX Driver,OOB signalling,Coupling and Eq,CDR -------------
				AC_CAP_DIS_0									=>			 FALSE,
				OOBDETECT_THRESHOLD_0					=>			 "001",																		-- Threshold between RXN and RXP is 105 mV
				PMA_CDR_SCAN_0								=>			 x"6c07640",
				PMA_RX_CFG_0									=>			 x"09f0088",
				RCV_TERM_GND_0								=>			 FALSE,
				RCV_TERM_MID_0								=>			 FALSE,
				RCV_TERM_VTTRX_0							=>			 FALSE,
				TERMINATION_IMP_0							=>			 50,																			-- 50 Ohm Terminierung

				AC_CAP_DIS_1									=>			 FALSE,
				OOBDETECT_THRESHOLD_1					=>			 "001",																		-- Threshold between RXN and RXP is 105 mV
				PMA_CDR_SCAN_1								=>			 x"6c07640",
				PMA_RX_CFG_1									=>			 x"09f0088",
				RCV_TERM_GND_1								=>			 FALSE,
				RCV_TERM_MID_1								=>			 FALSE,
				RCV_TERM_VTTRX_1							=>			 FALSE,
				TERMINATION_IMP_1							=>			 50,																			-- 50 Ohm Terminierung

				PCS_COM_CFG										=>			 x"1680a0e",
				TERMINATION_CTRL							=>			 "10100",
				TERMINATION_OVRD							=>			 FALSE,

				--------------------- RX Serial Line Rate Attributes ------------------
				PLL_RXDIVSEL_OUT_0						=>			 2,												--
				PLL_RXDIVSEL_OUT_1						=>			 2,

				PLL_SATA_0										=>			 FALSE,
				PLL_SATA_1										=>			 FALSE,

				----------------------- PRBS Detection Attributes ---------------------
				PRBS_ERR_THRESHOLD_0					=>			 x"00000001",
				PRBS_ERR_THRESHOLD_1					=>			 x"00000001",

				---------------- Comma Detection and Alignment Attributes -------------
				ALIGN_COMMA_WORD_0						=>			 1,
				COMMA_10B_ENABLE_0						=>			 "0001111111",
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
				COMMA_10B_ENABLE_1						=>			 "0001111111",
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
				CLK_COR_ADJ_LEN_0							=>			 2,
				CLK_COR_DET_LEN_0							=>			 2,
				CLK_COR_INSERT_IDLE_FLAG_0		=>			 FALSE,
				CLK_COR_KEEP_IDLE_0						=>			 FALSE,
				CLK_COR_MIN_LAT_0							=>			 16,
				CLK_COR_MAX_LAT_0							=>			 18,
				CLK_COR_PRECEDENCE_0					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_0					=>			 0,
				CLK_COR_SEQ_1_1_0							=>			 "0110111100",
				CLK_COR_SEQ_1_2_0							=>			 "0001010000",
				CLK_COR_SEQ_1_3_0							=>			 "0000000000",
				CLK_COR_SEQ_1_4_0							=>			 "0000000000",
				CLK_COR_SEQ_1_ENABLE_0				=>			 "0011",
				CLK_COR_SEQ_2_1_0							=>			 "0110111100",
				CLK_COR_SEQ_2_2_0							=>			 "0010110101",
				CLK_COR_SEQ_2_3_0							=>			 "0000000000",
				CLK_COR_SEQ_2_4_0							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_0				=>			 "0011",
				CLK_COR_SEQ_2_USE_0						=>			 TRUE,
				RX_DECODE_SEQ_MATCH_0					=>			 TRUE,

				CLK_CORRECT_USE_1							=>			 TRUE,
				CLK_COR_ADJ_LEN_1							=>			 2,
				CLK_COR_DET_LEN_1							=>			 2,
				CLK_COR_INSERT_IDLE_FLAG_1		=>			 FALSE,
				CLK_COR_KEEP_IDLE_1						=>			 FALSE,
				CLK_COR_MIN_LAT_1							=>			 16,
				CLK_COR_MAX_LAT_1							=>			 18,
				CLK_COR_PRECEDENCE_1					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_1					=>			 0,
				CLK_COR_SEQ_1_1_1							=>			 "0110111100",
				CLK_COR_SEQ_1_2_1							=>			 "0001010000",
				CLK_COR_SEQ_1_3_1							=>			 "0000000000",
				CLK_COR_SEQ_1_4_1							=>			 "0000000000",
				CLK_COR_SEQ_1_ENABLE_1				=>			 "0011",
				CLK_COR_SEQ_2_1_1							=>			 "0110111100",
				CLK_COR_SEQ_2_2_1							=>			 "0010110101",
				CLK_COR_SEQ_2_3_1							=>			 "0000000000",
				CLK_COR_SEQ_2_4_1							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_1				=>			 "0011",
				CLK_COR_SEQ_2_USE_1						=>			 TRUE,
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
				-- OOB COM*** signal detector @ 25 MHz with DDR (20 ns)
				RX_STATUS_FMT_0								=>			 "PCIE",
				SATA_BURST_VAL_0							=>			 "100",							-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL_0								=>			 "100",							-- IDLE count between bursts in OOB COM*** signals
				SATA_MIN_BURST_0							=>			 5,									--
				SATA_MAX_BURST_0							=>			 9,									--
				SATA_MIN_INIT_0								=>			 15,								--
				SATA_MAX_INIT_0								=>			 27,								--
				SATA_MIN_WAKE_0								=>			 5,									--
				SATA_MAX_WAKE_0								=>			 9,									--
				TRANS_TIME_FROM_P2_0					=>			 x"0060",
				TRANS_TIME_NON_P2_0						=>			 x"0025",
				TRANS_TIME_TO_P2_0						=>			 x"0100",

				RX_STATUS_FMT_1								=>			"PCIE",
				SATA_BURST_VAL_1							=>			"100",							-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL_1								=>			"100",							-- IDLE count between bursts in OOB COM*** signals
				SATA_MIN_BURST_1							=>			 5,									--
				SATA_MAX_BURST_1							=>			 9,									--
				SATA_MIN_INIT_1								=>			 15,								--
				SATA_MAX_INIT_1								=>			 27,								--
				SATA_MIN_WAKE_1								=>			 5,									--
				SATA_MAX_WAKE_1								=>			 9,									--
				TRANS_TIME_FROM_P2_1					=>			x"0060",
				TRANS_TIME_NON_P2_1						=>			x"0025",
				TRANS_TIME_TO_P2_1						=>			x"0100"
			)
			port map (
				------------------------ Loopback and Powerdown Ports ----------------------
				LOOPBACK0(0)									=>			Loopback(0),
				LOOPBACK0(2 downto 1)					=>			"00",
				LOOPBACK1(0)									=>			Loopback(1),
				LOOPBACK1(2 downto 1)					=>			"00",
				TXPOWERDOWN0									=>			(others => Powerdown(0)),
				RXPOWERDOWN0									=>			(others => Powerdown(0)),
				TXPOWERDOWN1									=>			(others => Powerdown(1)),
				RXPOWERDOWN1									=>			(others => Powerdown(1)),
				----------------------- Receive Ports - 8b10b Decoder ----------------------
				RXCHARISCOMMA0(0)							=>			RX_CharIsComma(0),						-- @ GTP_ClockRX_2X,
				RXCHARISCOMMA0(1)							=>			RX_CharIsComma_float(0),			-- @ GTP_ClockRX_2X,
				RXCHARISCOMMA1(0)							=>			RX_CharIsComma(1),
				RXCHARISCOMMA1(1)							=>			RX_CharIsComma_float(1),
				RXCHARISK0(0)									=>			RX_CharIsK(0),								-- @ GTP_ClockRX_2X,
				RXCHARISK0(1)									=>			RX_CharIsK_float(0),					-- @ GTP_ClockRX_2X,
				RXCHARISK1(0)									=>			RX_CharIsK(1),
				RXCHARISK1(1)									=>			RX_CharIsK_float(1),
				RXDEC8B10BUSE0								=>			'1',
				RXDEC8B10BUSE1								=>			'1',
				RXDISPERR0(0)									=>			RX_DisparityError(0),					-- @ GTP_ClockRX_2X,
				RXDISPERR0(1)									=>			RX_DisparityError_float(0),		-- @ GTP_ClockRX_2X,
				RXDISPERR1(0)									=>			RX_DisparityError(1),
				RXDISPERR1(1)									=>			RX_DisparityError_float(1),
				RXNOTINTABLE0(0)							=>			RX_NotInTable(0),							-- @ GTP_ClockRX_2X,
				RXNOTINTABLE0(1)							=>			RX_NotInTable_float(0),							-- @ GTP_ClockRX_2X,
				RXNOTINTABLE1(0)							=>			RX_NotInTable(1),
				RXNOTINTABLE1(1)							=>			RX_NotInTable_float(1),
				RXRUNDISP0(0)									=>			RX_RunningDisparity(0),
				RXRUNDISP0(1)									=>			RX_RunningDisparity_float(0),
				RXRUNDISP1(0)									=>			RX_RunningDisparity(1),
				RXRUNDISP1(1)									=>			RX_RunningDisparity_float(1),
				------------------- Receive Ports - Channel Bonding Ports ------------------
				RXCHANBONDSEQ0								=>			open,
				RXCHANBONDSEQ1								=>			open,
				RXCHBONDI0										=>			"000",
				RXCHBONDI1										=>			"000",
				RXCHBONDO0										=>			open,
				RXCHBONDO1										=>			open,
				RXENCHANSYNC0									=>			'0',
				RXENCHANSYNC1									=>			'0',
				------------------- Receive Ports - Clock Correction Ports -----------------
				RXCLKCORCNT0									=>			RX_ClockCorrectionCount(0),
				RXCLKCORCNT1									=>			RX_ClockCorrectionCount(1),
				--------------- Receive Ports - Comma Detection and Alignment --------------
				RXBYTEISALIGNED0							=>			open,	--RX_ByteIsAligned(0),									-- @ GTP_ClockRX_2X,	high-active, long signal			bytes are aligned
				RXBYTEISALIGNED1							=>			open,	--RX_ByteIsAligned(1),
				RXBYTEREALIGN0								=>			open,	--RX_ByteRealign(0),										-- @ GTP_ClockRX_2X,	hight-active, short pulse			alignment has changed
				RXBYTEREALIGN1								=>			open,	--RX_ByteRealign(1),
				RXCOMMADET0										=>			open,	--RX_CommaDetected(0),
				RXCOMMADET1										=>			open,	--RX_CommaDetected(1),
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
				RXPRBSERR0										=>			open,
				RXPRBSERR1										=>			open,
				------------------- Receive Ports - RX Data Path interface -----------------
				RXDATA0(7 downto 0)						=>			RX_Data(0),
				RXDATA0(15 downto 8)					=>			RX_Data_float(0),
				RXDATA1(7 downto 0)						=>			RX_Data(0),
				RXDATA1(15 downto 8)					=>			RX_Data_float(1),
				RXDATAWIDTH0									=>			'0',																			-- 8 Bit data interface
				RXDATAWIDTH1									=>			'0',																			-- 8 Bit data interface
				RXRECCLK0											=>			GTP_RX_RefClockOut(0),										-- recovered clock from CDR
				RXRECCLK1											=>			GTP_RX_RefClockOut(1),
				RXRESET0											=>			RX_Reset(0),
				RXRESET1											=>			RX_Reset(1),
				RXUSRCLK0											=>			RX_Clock(0),
				RXUSRCLK1											=>			RX_Clock(1),
				RXUSRCLK20										=>			RX_Clock(0),
				RXUSRCLK21										=>			RX_Clock(1),
				------- Receive Ports - RX Driver,OOB signaling,Coupling and Eq.,CDR ------
				RXCDRRESET0										=>			'0',											-- CDR => Clock Data Recovery
				RXCDRRESET1										=>			'0',
				RXELECIDLE0										=>			open,
				RXELECIDLE1										=>			open,
				RXELECIDLERESET0							=>			'0',
				RXELECIDLERESET1							=>			'0',
				RXENEQB0											=>			'1',
				RXENEQB1											=>			'1',
				RXEQMIX0											=>			"00",
				RXEQMIX1											=>			"00",
				RXEQPOLE0											=>			"0000",
				RXEQPOLE1											=>			"0000",
				RXN0													=>			RX_ds(0).N,
				RXP0													=>			RX_ds(0).P,
				RXN1													=>			RX_ds(1).N,
				RXP1													=>			RX_ds(1).P,
				-------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
				RXBUFRESET0										=>			RX_Reset(0),
				RXBUFRESET1										=>			RX_Reset(1),
				RXBUFSTATUS0(1 downto 0)			=>			GTP_RX_BufferStatus_float(0),					-- GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXBUFSTATUS0(2)								=>			RX_BufferError(0),										-- GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXBUFSTATUS1(1 downto 0)			=>			GTP_RX_BufferStatus_float(1),					-- GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXBUFSTATUS1(2)								=>			RX_BufferError(1),										-- GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXCHANISALIGNED0							=>			open,
				RXCHANISALIGNED1							=>			open,
				RXCHANREALIGN0								=>			open,
				RXCHANREALIGN1								=>			open,
				RXPMASETPHASE0								=>			'0',
				RXPMASETPHASE1								=>			'0',
				RXSTATUS0											=>			open,
				RXSTATUS1											=>			open,
				--------------- Receive Ports - RX Loss-of-sync State Machine --------------
				RXLOSSOFSYNC0									=>			open,											-- Xilinx example has connected signal
				RXLOSSOFSYNC1									=>			open,
				---------------------- Receive Ports - RX Oversampling ---------------------
				RXENSAMPLEALIGN0							=>			'0',
				RXENSAMPLEALIGN1							=>			'0',
				RXOVERSAMPLEERR0							=>			open,
				RXOVERSAMPLEERR1							=>			open,
				-------------- Receive Ports - RX Pipe Control for PCI Express -------------
				PHYSTATUS0										=>			open,
				PHYSTATUS1										=>			open,
				RXVALID0											=>			open,
				RXVALID1											=>			open,
				----------------- Receive Ports - RX Polarity Control Ports ----------------
				RXPOLARITY0										=>			'0',
				RXPOLARITY1										=>			'0',
				------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
				DCLK													=>			'0',
				DEN														=>			'0',
				DADDR													=>			(others => '0'),																			-- resize vector to GTP_DUAL specific address bits
				DWE														=>			'0',
				DI														=>			(others => '0'),
				DO														=>			open,
				DRDY													=>			open,
				--------------------- Shared Ports - Tile and PLL Ports --------------------
				CLKIN													=>			GTP_RefClockIn,
				GTPRESET											=>			GTP_Reset,
				GTPTEST												=>			"0000",
				INTDATAWIDTH									=>			'1',																									-- 10 Bit internal datawidth
				PLLLKDET											=>			GTP_PLL_ResetDone_i,																	-- GTP PLL lock detected
				PLLLKDETEN										=>			'1',
				PLLPOWERDOWN									=>			'0',
				REFCLKOUT											=>			GTP_RefClockOut_i,
				REFCLKPWRDNB									=>			'1',
				RESETDONE0										=>			GTP_ResetDone_i(0),
				RESETDONE1										=>			GTP_ResetDone_i(1),
				RXENELECIDLERESETB						=>			'1',																									-- low-active => disable
				TXENPMAPHASEALIGN							=>			'0',
				TXPMASETPHASE									=>			'0',
					---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
				TXBYPASS8B10B0								=>			"00",																									-- encode both bytes with 8B10B
				TXBYPASS8B10B1								=>			"00",
				TXCHARDISPMODE0								=>			TX_DisparityMode(0),
				TXCHARDISPMODE1								=>			TX_DisparityMode(1),
				TXCHARDISPVAL0								=>			TX_DisparityValue(0),
				TXCHARDISPVAL1								=>			TX_DisparityValue(1),
				TXCHARISK0(0)									=>			TX_CharIsK(0),
				TXCHARISK0(1)									=>			'0',
				TXCHARISK1(0)									=>			TX_CharIsK(1),
				TXCHARISK1(1)									=>			'0',
				TXENC8B10BUSE0								=>			'1',																									-- use internal 8B10B encoder
				TXENC8B10BUSE1								=>			'1',
				TXKERR0												=>			open,																									-- invalid K charakter
				TXKERR1												=>			open,
				TXRUNDISP0										=>			open,																									-- running disparity
				TXRUNDISP1										=>			open,
				------------- Transmit Ports - TX Buffering and Phase Alignment ------------
				TXBUFSTATUS0(0)								=>			GTP_TX_BufferStatus_float(0),
				TXBUFSTATUS0(1)								=>			TX_BufferError(0),
				TXBUFSTATUS1(0)								=>			GTP_TX_BufferStatus_float(1),
				TXBUFSTATUS1(1)								=>			TX_BufferError(1),
				------------------ Transmit Ports - TX Data Path interface -----------------
				TXDATA0(7 downto 0)						=>			TX_Data(0),
				TXDATA0(15 downto 8)					=>			(others => '0'),
				TXDATA1(7 downto 0)						=>			TX_Data(1),
				TXDATA1(15 downto 8)					=>			(others => '0'),
				TXDATAWIDTH0									=>			'0',																									-- 8 Bit interface
				TXDATAWIDTH1									=>			'0',
				TXOUTCLK0											=>			GTP_TX_RefClockOut(0),
				TXOUTCLK1											=>			GTP_TX_RefClockOut(1),
				TXRESET0											=>			TX_Reset(0),
				TXRESET1											=>			TX_Reset(1),								-- GTP_TX_Reset
				TXUSRCLK0											=>			TX_Clock(0),
				TXUSRCLK1											=>			TX_Clock(1),								--
				TXUSRCLK20										=>			TX_Clock(0),								--
				TXUSRCLK21										=>			TX_Clock(1),								--
				--------------- Transmit Ports - TX Driver and OOB signaling --------------
				TXBUFDIFFCTRL0								=>			"000",
				TXBUFDIFFCTRL1								=>			"000",
				TXDIFFCTRL0										=>			"000",
				TXDIFFCTRL1										=>			"000",
				TXINHIBIT0										=>			'0',
				TXINHIBIT1										=>			'0',
				TXN0													=>			TX_ds(0).N,
				TXP0													=>			TX_ds(0).P,
				TXN1													=>			TX_ds(1).N,
				TXP1													=>			TX_ds(1).P,
				TXPREEMPHASIS0								=>			"000",
				TXPREEMPHASIS1								=>			"000",
				--------------------- Transmit Ports - TX PRBS Generator -------------------
				TXENPRBSTST0									=>			"00",
				TXENPRBSTST1									=>			"00",
				-------------------- Transmit Ports - TX Polarity Control ------------------
				TXPOLARITY0										=>			'0',
				TXPOLARITY1										=>			'0',
					----------------- Transmit Ports - TX Ports for PCI Express ----------------
				TXDETECTRX0										=>			'0',
				TXDETECTRX1										=>			'0',
				TXELECIDLE0										=>			'0',
				TXELECIDLE1										=>			'0',
					--------------------- Transmit Ports - TX Ports for SATA -------------------
				TXCOMSTART0										=>			'0',
				TXCOMSTART1										=>			'0',
				TXCOMTYPE0										=>			'0',
				TXCOMTYPE1										=>			'0'
			);
	end generate;
end;
