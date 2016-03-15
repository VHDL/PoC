LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;
USE			PoC.net_comp.all;

ENTITY eth_RSLayer_GMII_SGMII_Series7 IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ					: REAL													:= 125.0					-- 125 MHz
	);
	PORT (
		Clock											: IN		STD_LOGIC;
		Reset											: IN		STD_LOGIC;
		
		-- GEMAC-GMII interface
		RS_TX_Clock								: IN		STD_LOGIC;
		RS_TX_Valid								: IN		STD_LOGIC;
		RS_TX_Data								: IN		T_SLV_8;
		RS_TX_Error								: IN		STD_LOGIC;
		
		RS_RX_Clock								: IN		STD_LOGIC;
		RS_RX_Valid								: OUT		STD_LOGIC;
		RS_RX_Data								: OUT		T_SLV_8;
		RS_RX_Error								: OUT		STD_LOGIC;
		
		-- PHY-SGMII interface
		PHY_Interface							: INOUT	T_NET_ETH_PHY_INTERFACE_SGMII;
		PHY_Management						: INOUT	T_NET_ETH_PHY_INTERFACE_MDIO
	);
END;

ARCHITECTURE rtl OF eth_RSLayer_GMII_SGMII_Series7 IS
	ATTRIBUTE KEEP							: BOOLEAN;

	SIGNAL MMCM_Reset						: STD_LOGIC;
	SIGNAL MMCM_Locked					: STD_LOGIC;
	
	SIGNAL MMCM_RefClock_In			: STD_LOGIC;
	SIGNAL MMCM_Clock_FB				: STD_LOGIC;
	
	SIGNAL MMCM_Clock_62_5_MHz	: STD_LOGIC;
	SIGNAL MMCM_Clock_125_MHz		: STD_LOGIC;
	
	SIGNAL Clock_62_5_MHz				: STD_LOGIC;
	SIGNAL Clock_125_MHz				: STD_LOGIC;
	
	SIGNAL SGMII_RefClock_Out		: STD_LOGIC;
	SIGNAL SGMII_ResetDone			: STD_LOGIC;
	
	SIGNAL SGMII_Status					: T_SLV_16;
	ATTRIBUTE KEEP OF SGMII_Status		: SIGNAL IS TRUE;
	
BEGIN
	MMCM_RefClock_In		<= SGMII_RefClock_Out;

	MMCM : MMCME2_ADV
		GENERIC MAP (
			BANDWIDTH            => "OPTIMIZED",
			CLKOUT4_CASCADE      => FALSE,
			COMPENSATION         => "ZHOLD",
			STARTUP_WAIT         => FALSE,
			DIVCLK_DIVIDE        => 1,
			CLKFBOUT_MULT_F      => 16.000,
			CLKFBOUT_PHASE       => 0.000,
			CLKFBOUT_USE_FINE_PS => FALSE,
			CLKOUT0_DIVIDE_F     => 8.000,
			CLKOUT0_PHASE        => 0.000,
			CLKOUT0_DUTY_CYCLE   => 0.5,
			CLKOUT0_USE_FINE_PS  => FALSE,
			CLKOUT1_DIVIDE       => 16,
			CLKOUT1_PHASE        => 0.000,
			CLKOUT1_DUTY_CYCLE   => 0.5,
			CLKOUT1_USE_FINE_PS  => FALSE,
			CLKIN1_PERIOD        => 16.0,						-- 62.5 MHz; transceiver DDR-sampling -> half GbE byte-clock ?
			REF_JITTER1          => 0.010
		)
		PORT MAP (
			CLKFBOUT             => MMCM_Clock_FB,
			CLKFBOUTB            => open,
			CLKOUT0              => MMCM_Clock_125_MHz,
			CLKOUT0B             => open,
			CLKOUT1              => MMCM_Clock_62_5_MHz,
			CLKOUT1B             => open,
			CLKOUT2              => open,
			CLKOUT2B             => open,
			CLKOUT3              => open,
			CLKOUT3B             => open,
			CLKOUT4              => open,
			CLKOUT5              => open,
			CLKOUT6              => open,
			-- Input clock control
			CLKFBIN              => MMCM_Clock_FB,
			CLKIN1               => MMCM_RefClock_In,
			CLKIN2               => '0',
			-- Tied to always select the primary input clock
			CLKINSEL             => '1',
			-- Ports for dynamic reconfiguration
			DADDR                => (others => '0'),
			DCLK                 => '0',
			DEN                  => '0',
			DI                   => (others => '0'),
			DO                   => open,
			DRDY                 => open,
			DWE                  => '0',
			-- Ports for dynamic phase shift
			PSCLK                => '0',
			PSEN                 => '0',
			PSINCDEC             => '0',
			PSDONE               => open,
			-- Other control and status SIGNALs
			LOCKED               => MMCM_Locked,
			CLKINSTOPPED         => open,
			CLKFBSTOPPED         => open,
			PWRDWN               => '0',
			RST                  => MMCM_Reset
		);

	MMCM_Reset <= Reset OR (NOT SGMII_ResetDone);

	-- TODO: review comment
	-- This 62.5MHz clock is placed onto global clock routing and is then used
	-- for tranceiver TXUSRCLK/RXUSRCLK.
	BUFG_Clock_62_5_MHz : BUFG
		PORT MAP (
			I			=> MMCM_Clock_62_5_MHz,
			O			=> Clock_62_5_MHz					-- userclock
		);

	-- TODO: review comment
	-- This 125MHz clock is placed onto global clock routing and is then used
	-- to clock all Ethernet core logic.
	BUFG_Clock_125_MHz : BUFG
		PORT MAP (
			I			=> MMCM_Clock_125_MHz,
			O			=> Clock_125_MHz					-- userclock2
		);

	PHY_Interface.SGMII_TXRefClock_Out	<= Clock_125_MHz;
	PHY_Interface.SGMII_RXRefClock_Out	<= Clock_125_MHz;			-- FIXME: this seams not to be correct !!!

	PHY_Management.Clock_ts.t		<= '0';


	genPCSIPCore : IF (TRUE) GENERATE
		CONSTANT PCSCORE_MDIO_ADDRESS						: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= "00101";
		CONSTANT PCSCORE_CONFIGURATION					: BOOLEAN													:= TRUE;
		CONSTANT PCSCORE_CONFIGURATION_VECTOR		: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= "10000";
	
		-- Core <=> Transceiver interconnect
		SIGNAL plllock           : STD_LOGIC;                        -- The PLL Locked status of the Transceiver
		SIGNAL mgt_rx_reset      : STD_LOGIC;                        -- Reset for the receiver half of the Transceiver
		SIGNAL mgt_tx_reset      : STD_LOGIC;                        -- Reset for the transmitter half of the Transceiver
		SIGNAL rxbufstatus       : STD_LOGIC_VECTOR (1 DOWNTO 0);    -- Elastic Buffer Status (bit 1 asserted indicates overflow or underflow).
		SIGNAL rxchariscomma     : STD_LOGIC;                        -- Comma detected in RXDATA.
		SIGNAL rxcharisk         : STD_LOGIC;                        -- K character received (or extra data bit) in RXDATA.
		SIGNAL rxclkcorcnt       : STD_LOGIC_VECTOR(2 DOWNTO 0);     -- Indicates clock correction.
		SIGNAL rxdata            : T_SLV_8;														-- Data after 8B/10B decoding.
		SIGNAL rxdisperr         : STD_LOGIC;                        -- Disparity-error in RXDATA.
		SIGNAL rxnotintable      : STD_LOGIC;                        -- Non-existent 8B/10 code indicated.
		SIGNAL rxrundisp         : STD_LOGIC;                        -- Running Disparity after current byte, becomes 9th data bit when RXNOTINTABLE='1'.
		SIGNAL txbuferr          : STD_LOGIC;                        -- TX Buffer error (overflow or underflow).
		SIGNAL powerdown         : STD_LOGIC;                        -- Powerdown the Transceiver
		SIGNAL txchardispmode    : STD_LOGIC;                        -- Set running disparity for current byte.
		SIGNAL txchardispval     : STD_LOGIC;                        -- Set running disparity value.
		SIGNAL txcharisk         : STD_LOGIC;                        -- K character transmitted in TXDATA.
		SIGNAL txdata            : T_SLV_8;														-- Data for 8B/10B encoding.
		SIGNAL enablealign       : STD_LOGIC;                        -- Allow the transceivers to serially realign to a comma character.

		-- GMII SIGNALs routed between core and SGMII Adaptation Module
		SIGNAL Adapter_TX_Data				: T_SLV_8;											-- Internal gmii_txd SIGNAL (between core and SGMII adaptation module).
		SIGNAL Adapter_TX_Valid				: STD_LOGIC;										-- Internal gmii_tx_en SIGNAL (between core and SGMII adaptation module).
		SIGNAL Adapter_TX_Error				: STD_LOGIC;										-- Internal gmii_tx_er SIGNAL (between core and SGMII adaptation module).
		SIGNAL PCSCore_RX_Data				: T_SLV_8;											-- Internal gmii_rxd SIGNAL (between core and SGMII adaptation module).
		SIGNAL PCSCore_RX_Valid				: STD_LOGIC;										-- Internal gmii_rx_dv SIGNAL (between core and SGMII adaptation module).
		SIGNAL PCSCore_RX_Error				: STD_LOGIC;										-- Internal gmii_rx_er SIGNAL (between core and SGMII adaptation module).
		
		SIGNAL SGMII_Status_i					: T_SLV_16;
	BEGIN
--		Adapter : ENTITY L_Ethernet.GMII_SGMII_sgmii_adapt
--			PORT MAP (
--				reset                => Reset,
--				clk125m              => Clock_125_MHz,
--				sgmii_clk_r          => OPEN,
--				sgmii_clk_f          => OPEN,
--				sgmii_clk_en         => OPEN,
--				gmii_txd_in          => RS_TX_Data,
--				gmii_tx_en_in        => RS_TX_Valid,
--				gmii_tx_er_in        => RS_TX_Error,
--				gmii_rxd_in          => PCSCore_RX_Data,
--				gmii_rx_dv_in        => PCSCore_RX_Valid,
--				gmii_rx_er_in        => PCSCore_RX_Error,
--				gmii_txd_out         => Adapter_TX_Data,
--				gmii_tx_en_out       => Adapter_TX_Valid,
--				gmii_tx_er_out       => Adapter_TX_Error,
--				gmii_rxd_out         => RS_RX_Data,
--				gmii_rx_dv_out       => RS_RX_Valid,
--				gmii_rx_er_out       => RS_RX_Error,
--				speed_is_10_100      => '0',																-- TODO:							-- Core should operate at either 10Mbps or 100Mbps speeds
--				speed_is_100         => '0'																	-- TODO:							-- Core should operate at 100Mbps speed
--			);

		Adapter_TX_Data        <= RS_TX_Data;
		Adapter_TX_Valid       <= RS_TX_Valid;
		Adapter_TX_Error       <= RS_TX_Error;
		RS_RX_Data      		   <= PCSCore_RX_Data;
		RS_RX_Valid      			 <= PCSCore_RX_Valid;
		RS_RX_Error      			 <= PCSCore_RX_Error;

		PCSCore : ENTITY PoC.eth_GMII_SGMII_PCS_Series7
			PORT MAP (
				userclk              => Clock_125_MHz,
				userclk2             => Clock_125_MHz,
				dcm_locked           => MMCM_Locked,

				reset                => Reset,

				mgt_rx_reset         => mgt_rx_reset,
				mgt_tx_reset         => mgt_tx_reset,

				powerdown            => powerdown,
				enablealign          => enablealign,

				txdata               => txdata,
				txcharisk            => txcharisk,
				txbuferr             => txbuferr,
				txchardispmode       => txchardispmode,
				txchardispval        => txchardispval,

				signal_detect        => '1',														-- Input from PMD to indicate presence of optical input.
				rxdata               => rxdata,
				rxchariscomma        => rxchariscomma,
				rxcharisk            => rxcharisk,
				rxdisperr            => rxdisperr,
				rxnotintable         => rxnotintable,
				rxrundisp            => rxrundisp,
				rxclkcorcnt          => rxclkcorcnt,
				rxbufstatus          => rxbufstatus,

				gmii_txd             => Adapter_TX_Data,								-- Transmit data from client MAC.
				gmii_tx_en           => Adapter_TX_Valid,								-- Transmit control SIGNAL from client MAC.
				gmii_tx_er           => Adapter_TX_Error,								-- Transmit control SIGNAL from client MAC.
				gmii_rxd             => PCSCore_RX_Data,								-- Received Data to client MAC.
				gmii_rx_dv           => PCSCore_RX_Valid,								-- Received control SIGNAL to client MAC.
				gmii_rx_er           => PCSCore_RX_Error,								-- Received control SIGNAL to client MAC.
				gmii_isolate         => OPEN,														-- Tristate control to electrically isolate GMII
				
				phyad                => PCSCORE_MDIO_ADDRESS,
				mdc                  => PHY_Management.Clock_ts.i,					-- PHY_Management Data Clock
				mdio_in              => PHY_Management.Data_ts.i,					-- PHY_Management Data In
				mdio_out             => PHY_Management.Data_ts.o,					-- PHY_Management Data Out
				mdio_tri             => PHY_Management.Data_ts.t,					-- PHY_Management Data Tristate
				
				configuration_vector => PCSCORE_CONFIGURATION_VECTOR,
				configuration_valid  => to_sl(PCSCORE_CONFIGURATION),
				
				an_restart_config    => '0',
				an_adv_config_vector => (OTHERS => '0'),
				an_adv_config_val    => '0',
				an_interrupt         => OPEN,														-- TODO: 										-- Interrupt to processor to SIGNAL that Auto-Negotiation has completed,

				link_timer_value     => (OTHERS => '1'),
				status_vector        => SGMII_Status_i
			);

		SGMII_Status <= SGMII_Status_i;

		Trans : ENTITY PoC.eth_SGMII_Transceiver_GTXE2
			PORT MAP (
				independent_clock    => PHY_Interface.DGB_SystemClock_In,
				gtrefclk             => PHY_Interface.SGMII_RefClock_In,
				
				txoutclk             => SGMII_RefClock_Out,
				plllkdet             => plllock,
				
				usrclk               => Clock_62_5_MHz,
				usrclk2              => Clock_125_MHz,
				mmcm_locked          => MMCM_Locked,

				pmareset             => '0',																-- TODO: 
				txreset              => mgt_tx_reset,
				rxreset              => mgt_rx_reset,
				resetdone            => SGMII_ResetDone,

				powerdown            => powerdown,
				loopback             => '0',														-- Set the Transceiver for loopback.

				encommaalign         => enablealign,

				data_valid           => SGMII_Status_i(1),

				txdata               => txdata,
				txcharisk            => txcharisk,
				txbuferr             => txbuferr,
				txchardispmode       => txchardispmode,
				txchardispval        => txchardispval,

				rxelecidle           => OPEN,
				rxdata               => rxdata,
				rxchariscomma        => rxchariscomma,
				rxcharisk            => rxcharisk,
				rxdisperr            => rxdisperr,
				rxnotintable         => rxnotintable,
				rxrundisp            => rxrundisp,
				rxclkcorcnt          => rxclkcorcnt,
				rxbuferr             => rxbufstatus(1),

				txn                  => PHY_Interface.TX_n,
				txp                  => PHY_Interface.TX_p,
				rxn                  => PHY_Interface.RX_n,
				rxp                  => PHY_Interface.RX_p
			);

		 -- Unused
		 rxbufstatus(0) <= '0';
	END GENERATE;
	
--	genPCS : IF (FALSE) GENERATE
--	
--	BEGIN
--		PCS : ENTITY L_Ethernet.Ethernet_PCS_GMII_TRANS_1000Base_X
--			PORT MAP (
--				TX_Clock											=> TX_Clock,
--				RX_Clock											=> RX_Clock,
--				
--				TX_Reset											=> TX_Reset,
--				RX_Reset											=> RX_Reset,
--				
--				-- GMII interface
--				TX_Valid									=> TX_Valid,
--				TX_Data										=> TX_Data,
--				TX_Error									=> TX_Error,
--				
--				RX_Valid									=> RX_Valid,
--				RX_Data										=> RX_Data,
--				RX_Error									=> RX_Error,
--				
--				-- TRANS interface
--				Trans_TX_Data							=> PCS_TX_Data,
--				Trans_TX_CharIsK					=> PCS_TX_CharIsK,
--				Trans_TX_RunningDisparity	=> Trans_TX_RunningDisparity,
--				
--				Trans_RX_Data							=> Trans_RX_Data,
--				Trans_RX_CharIsK					=> Trans_RX_CharIsK,
--				Trans_RX_RunningDisparity	=> Trans_RX_RunningDisparity
--			);
--			
--		Trans : ENTITY L_Ethernet.Ethernet_SGMIITransceiver_Virtex7
--			GENERIC MAP (
--				PORTS											=> 1
--			)
--			PORT MAP (
--				TX_RefClock_In						=> PHY_Interface.SGMII_RefClock_In,
--				RX_RefClock_In						=> PHY_Interface.SGMII_RefClock_In,
--				TX_RefClock_Out						=> PHY_Interface.SGMII_TXRefClock_Out,
--				RX_RefClock_Out						=> PHY_Interface.SGMII_TXRefClock_Out,
--				
--				ClockNetwork_Reset				=> ClkNet_Reset,
--				ClockNetwork_ResetDone		=> ClkNet_ResetDone,
--				
----				Command										=> Trans_Command,
----				Status										=> Trans_Status,
----				TX_Error									=> Trans_TX_Error,
----				RX_Error									=> Trans_RX_Error,
--				
--				TX_Data										=> PCS_TX_Data,
--				TX_CharIsK								=> PCS_TX_CharIsK,
--				TX_RunningDisparity				=> Trans_TX_RunningDisparity,
--				
--				RX_Data										=> Trans_RX_Data,
--				RX_CharIsK								=> Trans_RX_CharIsK,
--				RX_RunningDisparity				=> Trans_RX_RunningDisparity,
--				
--				TX_n											=> PHY_Interface.TX_n,
--				TX_p											=> PHY_Interface.TX_p,
--				RX_n											=> PHY_Interface.RX_n,
--				RX_p											=> PHY_Interface.RX_p
--			);
--	END GENERATE;
END;
