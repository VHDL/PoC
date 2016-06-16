library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library UNISIM;
use			UNISIM.VcomponentS.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.net.all;
use			PoC.net_comp.all;

entity eth_RSLayer_GMII_SGMII_Series7 is
	generic (
		CLOCK_IN_FREQ_MHZ					: REAL													:= 125.0					-- 125 MHz
	);
	port (
		Clock											: in		STD_LOGIC;
		Reset											: in		STD_LOGIC;

		-- GEMAC-GMII interface
		RS_TX_Clock								: in		STD_LOGIC;
		RS_TX_Valid								: in		STD_LOGIC;
		RS_TX_Data								: in		T_SLV_8;
		RS_TX_Error								: in		STD_LOGIC;

		RS_RX_Clock								: in		STD_LOGIC;
		RS_RX_Valid								: out		STD_LOGIC;
		RS_RX_Data								: out		T_SLV_8;
		RS_RX_Error								: out		STD_LOGIC;

		-- PHY-SGMII interface
		PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_SGMII;
		PHY_Management						: inout	T_NET_ETH_PHY_INTERFACE_MDIO
	);
end;

architecture rtl of eth_RSLayer_GMII_SGMII_Series7 is
	attribute KEEP							: BOOLEAN;

	signal MMCM_Reset						: STD_LOGIC;
	signal MMCM_Locked					: STD_LOGIC;

	signal MMCM_RefClock_In			: STD_LOGIC;
	signal MMCM_Clock_FB				: STD_LOGIC;

	signal MMCM_Clock_62_5_MHz	: STD_LOGIC;
	signal MMCM_Clock_125_MHz		: STD_LOGIC;

	signal Clock_62_5_MHz				: STD_LOGIC;
	signal Clock_125_MHz				: STD_LOGIC;

	signal SGMII_RefClock_Out		: STD_LOGIC;
	signal SGMII_ResetDone			: STD_LOGIC;

	signal SGMII_Status					: T_SLV_16;
	attribute KEEP OF SGMII_Status		: signal IS TRUE;

begin
	MMCM_RefClock_In		<= SGMII_RefClock_Out;

	MMCM : MMCME2_ADV
		generic map (
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
		port map (
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
		port map (
			I			=> MMCM_Clock_62_5_MHz,
			O			=> Clock_62_5_MHz					-- userclock
		);

	-- TODO: review comment
	-- This 125MHz clock is placed onto global clock routing and is then used
	-- to clock all Ethernet core logic.
	BUFG_Clock_125_MHz : BUFG
		port map (
			I			=> MMCM_Clock_125_MHz,
			O			=> Clock_125_MHz					-- userclock2
		);

	PHY_Interface.SGMII_TXRefClock_Out	<= Clock_125_MHz;
	PHY_Interface.SGMII_RXRefClock_Out	<= Clock_125_MHz;			-- FIXME: this seams not to be correct !!!

	PHY_Management.Clock_ts.t		<= '0';


	genPCSIPCore : if (TRUE) generate
		constant PCSCORE_MDIO_ADDRESS						: STD_LOGIC_VECTOR(4 downto 0)		:= "00101";
		constant PCSCORE_CONFIGURATION					: BOOLEAN													:= TRUE;
		constant PCSCORE_CONFIGURATION_VECTOR		: STD_LOGIC_VECTOR(4 downto 0)		:= "10000";

		-- Core <=> Transceiver interconnect
		signal plllock           : STD_LOGIC;                        -- The PLL Locked status of the Transceiver
		signal mgt_rx_reset      : STD_LOGIC;                        -- Reset for the receiver half of the Transceiver
		signal mgt_tx_reset      : STD_LOGIC;                        -- Reset for the transmitter half of the Transceiver
		signal rxbufstatus       : STD_LOGIC_VECTOR (1 downto 0);    -- Elastic Buffer Status (bit 1 asserted indicates overflow or underflow).
		signal rxchariscomma     : STD_LOGIC;                        -- Comma detected in RXDATA.
		signal rxcharisk         : STD_LOGIC;                        -- K character received (or extra data bit) in RXDATA.
		signal rxclkcorcnt       : STD_LOGIC_VECTOR(2 downto 0);     -- Indicates clock correction.
		signal rxdata            : T_SLV_8;														-- Data after 8B/10B decoding.
		signal rxdisperr         : STD_LOGIC;                        -- Disparity-error in RXDATA.
		signal rxnotintable      : STD_LOGIC;                        -- Non-existent 8B/10 code indicated.
		signal rxrundisp         : STD_LOGIC;                        -- Running Disparity after current byte, becomes 9th data bit when RXNOTINTABLE='1'.
		signal txbuferr          : STD_LOGIC;                        -- TX Buffer error (overflow or underflow).
		signal powerdown         : STD_LOGIC;                        -- Powerdown the Transceiver
		signal txchardispmode    : STD_LOGIC;                        -- Set running disparity for current byte.
		signal txchardispval     : STD_LOGIC;                        -- Set running disparity value.
		signal txcharisk         : STD_LOGIC;                        -- K character transmitted in TXDATA.
		signal txdata            : T_SLV_8;														-- Data for 8B/10B encoding.
		signal enablealign       : STD_LOGIC;                        -- Allow the transceivers to serially realign to a comma character.

		-- GMII signals routed between core and SGMII Adaptation Module
		signal Adapter_TX_Data				: T_SLV_8;											-- Internal gmii_txd signal (between core and SGMII adaptation module).
		signal Adapter_TX_Valid				: STD_LOGIC;										-- Internal gmii_tx_en signal (between core and SGMII adaptation module).
		signal Adapter_TX_Error				: STD_LOGIC;										-- Internal gmii_tx_er signal (between core and SGMII adaptation module).
		signal PCSCore_RX_Data				: T_SLV_8;											-- Internal gmii_rxd signal (between core and SGMII adaptation module).
		signal PCSCore_RX_Valid				: STD_LOGIC;										-- Internal gmii_rx_dv signal (between core and SGMII adaptation module).
		signal PCSCore_RX_Error				: STD_LOGIC;										-- Internal gmii_rx_er signal (between core and SGMII adaptation module).

		signal SGMII_Status_i					: T_SLV_16;
	begin
--		Adapter : entity L_Ethernet.GMII_SGMII_sgmii_adapt
--			port map (
--				reset                => Reset,
--				clk125m              => Clock_125_MHz,
--				sgmii_clk_r          => open,
--				sgmii_clk_f          => open,
--				sgmii_clk_en         => open,
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

		PCSCore : entity PoC.eth_GMII_SGMII_PCS_Series7
			port map (
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
				an_adv_config_vector => (others => '0'),
				an_adv_config_val    => '0',
				an_interrupt         => open,														-- TODO: 										-- Interrupt to processor to signal that Auto-Negotiation has completed,

				link_timer_value     => (others => '1'),
				status_vector        => SGMII_Status_i
			);

		SGMII_Status <= SGMII_Status_i;

		Trans : entity PoC.eth_SGMII_Transceiver_GTXE2
			port map (
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

				rxelecidle           => open,
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
	end generate;

--	genPCS : if (FALSE) generate
--
--	begin
--		PCS : entity L_Ethernet.Ethernet_PCS_GMII_TRANS_1000Base_X
--			port map (
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
--		Trans : entity L_Ethernet.Ethernet_SGMIITransceiver_Virtex7
--			generic map (
--				PORTS											=> 1
--			)
--			port map (
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
--	end generate;
end;
