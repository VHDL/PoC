library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library UNISIM;
use			UNISIM.VcomponentS.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.physical.all;
use			PoC.vectors.all;
use			PoC.net.all;
use			PoC.net_comp.all;

entity eth_RSLayer_GMII_SGMII_Series7 is
	generic (
		CLOCKIN_FREQ					: FREQ													:= 125 MHz
	);
	port (
		Clock											: in		std_logic;
		Reset											: in		std_logic;

		-- GEMAC-GMII interface
		RS_TX_Clock								: in		std_logic;
		RS_TX_Valid								: in		std_logic;
		RS_TX_Data								: in		T_SLV_8;
		RS_TX_Error								: in		std_logic;

		RS_RX_Clock								: in		std_logic;
		RS_RX_Valid								: out		std_logic;
		RS_RX_Data								: out		T_SLV_8;
		RS_RX_Error								: out		std_logic;
		
		status_vector							: out T_SLV_16;
		configuration_vector			: in T_SLV_16;

		-- PHY-SGMII interface
		PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_SGMII;
		PHY_Management						: inout	T_NET_ETH_PHY_INTERFACE_MDIO
	);
end;

architecture rtl of eth_RSLayer_GMII_SGMII_Series7 is
	attribute KEEP							: boolean;

	signal MMCM_Reset						: std_logic;
	signal MMCM_Reset_Req				: std_logic;
	signal MMCM_Locked					: std_logic;

	signal MMCM_RefClock_In			: std_logic;
	signal MMCM_Clock_FB				: std_logic;

	signal MMCM_Clock_62_5_MHz	: std_logic;
	signal MMCM_Clock_125_MHz		: std_logic;

	signal Clock_62_5_MHz				: std_logic;
	signal Clock_125_MHz				: std_logic;

	signal SGMII_RefClock_Out		: std_logic;
	signal SGMII_ResetDone			: std_logic;

	signal SGMII_Status					: T_SLV_16;
	attribute KEEP of SGMII_Status		: signal is TRUE;
	

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

	MMCM_Reset <= Reset or (not SGMII_ResetDone) or MMCM_Reset_Req;

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
		constant PCSCORE_MDIO_ADDRESS						: std_logic_vector(4 downto 0)		:= "00101";
		constant PCSCORE_CONFIGURATION					: boolean													:= TRUE;
		constant PCSCORE_CONFIGURATION_VECTOR		: std_logic_vector(4 downto 0)		:= "10000";

		-- Core <=> Transceiver interconnect
		signal plllock           : std_logic;                        -- The PLL Locked status of the Transceiver
		signal mgt_rx_reset      : std_logic;                        -- Reset for the receiver half of the Transceiver
		signal mgt_tx_reset      : std_logic;                        -- Reset for the transmitter half of the Transceiver
		signal rxbufstatus       : std_logic_vector (1 downto 0);    -- Elastic Buffer Status (bit 1 asserted indicates overflow or underflow).
		signal rxchariscomma     : std_logic;                        -- Comma detected in RXDATA.
		signal rxcharisk         : std_logic;                        -- K character received (or extra data bit) in RXDATA.
		signal rxclkcorcnt       : std_logic_vector(2 downto 0);     -- Indicates clock correction.
		signal rxdata            : T_SLV_8;														-- Data after 8B/10B decoding.
		signal rxdisperr         : std_logic;                        -- Disparity-error in RXDATA.
		signal rxnotintable      : std_logic;                        -- Non-existent 8B/10 code indicated.
		signal rxrundisp         : std_logic;                        -- Running Disparity after current byte, becomes 9th data bit when RXNOTINTABLE='1'.
		signal txbuferr          : std_logic;                        -- TX Buffer error (overflow or underflow).
		signal powerdown         : std_logic;                        -- Powerdown the Transceiver
		signal txchardispmode    : std_logic;                        -- Set running disparity for current byte.
		signal txchardispval     : std_logic;                        -- Set running disparity value.
		signal txcharisk         : std_logic;                        -- K character transmitted in TXDATA.
		signal txdata            : T_SLV_8;														-- Data for 8B/10B encoding.
		signal enablealign       : std_logic;                        -- Allow the transceivers to serially realign to a comma character.

		GMII signals routed between core and SGMII Adaptation Module
		signal Adapter_TX_Data				: T_SLV_8;											-- Internal gmii_txd signal (between core and SGMII adaptation module).
		signal Adapter_TX_Valid				: std_logic;										-- Internal gmii_tx_en signal (between core and SGMII adaptation module).
		signal Adapter_TX_Error				: std_logic;										-- Internal gmii_tx_er signal (between core and SGMII adaptation module).
		signal PCSCore_RX_Data				: T_SLV_8;											-- Internal gmii_rxd signal (between core and SGMII adaptation module).
		signal PCSCore_RX_Valid				: std_logic;										-- Internal gmii_rx_dv signal (between core and SGMII adaptation module).
		signal PCSCore_RX_Error				: std_logic;										-- Internal gmii_rx_er signal (between core and SGMII adaptation module).

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

--		Adapter_TX_Data        <= RS_TX_Data;
--		Adapter_TX_Valid       <= RS_TX_Valid;
--		Adapter_TX_Error       <= RS_TX_Error;
--		RS_RX_Data      		   <= PCSCore_RX_Data;
--		RS_RX_Valid      			 <= PCSCore_RX_Valid;
--		RS_RX_Error      			 <= PCSCore_RX_Error;

		PCSCore : entity PoC.eth_GMII_SGMII_PCS_Series7   --IP Core fore Series7
			port map (
-- --				userclk              => Clock_125_MHz,
-- --				userclk2             => Clock_125_MHz,
-- --				dcm_locked           => MMCM_Locked,

-- ----				reset                => Reset,

-- --				mgt_rx_reset         => mgt_rx_reset,
-- --				mgt_tx_reset         => mgt_tx_reset,

				-- -- powerdown            => powerdown,
				-- -- enablealign          => enablealign,

				-- -- txdata               => txdata,
				-- -- txcharisk            => txcharisk,
				-- -- txbuferr             => txbuferr,
				-- -- txchardispmode       => txchardispmode,
				-- -- txchardispval        => txchardispval,

				-- -- signal_detect        => '1',														-- Input from PMD to indicate presence of optical input.
				
				-- -- rxdata               => rxdata,
				-- -- rxchariscomma        => rxchariscomma,
				-- -- rxcharisk            => rxcharisk,
				-- -- rxdisperr            => rxdisperr,
				-- -- rxnotintable         => rxnotintable,
				-- -- rxrundisp            => rxrundisp,
				-- -- rxclkcorcnt          => rxclkcorcnt,
				-- -- rxbufstatus          => rxbufstatus,

				-- -- gmii_txd             => RS_TX_Data,								-- Transmit data from client MAC.
				-- -- gmii_tx_en           => RS_TX_Valid,								-- Transmit control SIGNAL from client MAC.
				-- -- gmii_tx_er           => RS_TX_Error,								-- Transmit control SIGNAL from client MAC.
				-- -- gmii_rxd             => RS_RX_Data,								-- Received Data to client MAC.
				-- -- gmii_rx_dv           => RS_RX_Valid,								-- Received control SIGNAL to client MAC.
				-- -- gmii_rx_er           => RS_RX_Error,								-- Received control SIGNAL to client MAC.
				-- -- gmii_isolate         => open,														-- Tristate control to electrically isolate GMII

				-- -- phyad                => PCSCORE_MDIO_ADDRESS,
				mdc                  => PHY_Management.Clock_ts.i,					-- PHY_Management Data Clock
				mdio_in              => PHY_Management.Data_ts.i,					-- PHY_Management Data In
				mdio_out             => PHY_Management.Data_ts.o,					-- PHY_Management Data Out
				mdio_tri             => PHY_Management.Data_ts.t,					-- PHY_Management Data Tristate

				-- -- configuration_vector => PCSCORE_CONFIGURATION_VECTOR,
				-- -- configuration_valid  => to_sl(PCSCORE_CONFIGURATION),

				an_restart_config    => '0',
				an_adv_config_vector => (others => '0'),
				an_adv_config_val    => '0',
				an_interrupt         => open,														-- TODO: 										-- Interrupt to processor to signal that Auto-Negotiation has completed,

				link_timer_value     => (others => '1')
--				status_vector        => SGMII_Status_i
			);
			---------------------
			
-- -- -- -- -- -- -- -- -- -- -- your_instance_name : gig_ethernet_pcs_pma_0
-- -- -- -- -- -- -- -- -- -- -- PORT MAP (
-- -- -- -- -- -- -- -- -- -- -- cplllock => open,--cplllock,
-- -- -- -- -- -- -- -- -- -- -- mmcm_reset => MMCM_Reset_Req,--mmcm_reset,


-- -- -- -- -- -- -- -- -- -- -- rxuserclk => Clock_125_MHz,--rxuserclk,
-- -- -- -- -- -- -- -- -- -- -- rxuserclk2 => Clock_125_MHz,--rxuserclk2,		
-- -- -- -- -- -- -- -- -- -- -- ---------------------------------  
-- -- -- -- -- -- -- -- -- -- -- --			    gtrefclk_p => open,--gtrefclk_p,
-- -- -- -- -- -- -- -- -- -- -- --			    gtrefclk_n => open,--gtrefclk_n,
-- -- -- -- -- -- -- -- -- -- -- ----------------------------------------
-- -- -- -- -- -- -- -- -- -- -- --			    gtrefclk_out => gtrefclk_out,
-- -- -- -- -- -- -- -- -- -- -- --			    gtrefclk_bufg_out => gtrefclk_bufg_out,
-- -- -- -- -- -- -- -- -- -- -- -----------
-- -- -- -- -- -- -- -- -- -- -- gtrefclk_bufg => Clock_125_MHz,--gtrefclk_bufg,
-- -- -- -- -- -- -- -- -- -- -- gtrefclk => PHY_Interface.SGMII_RefClock_In,--
-- -- -- -- -- -- -- -- -- -- -- ----------------------------------------
-- -- -- -- -- -- -- -- -- -- -- txn                  => PHY_Interface.TX_n,--
-- -- -- -- -- -- -- -- -- -- -- txp                  => PHY_Interface.TX_p,--
-- -- -- -- -- -- -- -- -- -- -- rxn                  => PHY_Interface.RX_n,--
-- -- -- -- -- -- -- -- -- -- -- rxp                  => PHY_Interface.RX_p,--

-- -- -- -- -- -- -- -- -- -- -- independent_clock_bufg => Clock_125_MHz,--independent_clock_bufg,
-- -- -- -- -- -- -- -- -- -- -- ----------------------------------------
-- -- -- -- -- -- -- -- -- -- -- --			    userclk_out => Clock_125_MHz,--
-- -- -- -- -- -- -- -- -- -- -- --			    userclk2_out => Clock_125_MHz,--
-- -- -- -- -- -- -- -- -- -- -- ---------
-- -- -- -- -- -- -- -- -- -- -- userclk => Clock_125_MHz,--
-- -- -- -- -- -- -- -- -- -- -- userclk2 => Clock_125_MHz,--
-- -- -- -- -- -- -- -- -- -- -- -------------------------------------
-- -- -- -- -- -- -- -- -- -- -- --			    rxuserclk_out => rxuserclk_out,
-- -- -- -- -- -- -- -- -- -- -- --			    rxuserclk2_out => rxuserclk2_out,
-- -- -- -- -- -- -- -- -- -- -- --			    resetdone => SGMII_ResetDone,--
-- -- -- -- -- -- -- -- -- -- -- -----------
-- -- -- -- -- -- -- -- -- -- -- txoutclk => open,--txoutclk,
-- -- -- -- -- -- -- -- -- -- -- rxoutclk => open,--rxoutclk,
-- -- -- -- -- -- -- -- -- -- -- resetdone => SGMII_ResetDone,--
-- -- -- -- -- -- -- -- -- -- -- -------------------------------------
-- -- -- -- -- -- -- -- -- -- -- --			    pma_reset_out => pma_reset_out,
-- -- -- -- -- -- -- -- -- -- -- --			    mmcm_locked_out => mmcm_locked_out,
-- -- -- -- -- -- -- -- -- -- -- ---------
-- -- -- -- -- -- -- -- -- -- -- pma_reset => '0',--
-- -- -- -- -- -- -- -- -- -- -- mmcm_locked => MMCM_Locked,--
-- -- -- -- -- -- -- -- -- -- -- ---------------------------------------------
-- -- -- -- -- -- -- -- -- -- -- sgmii_clk_r => open,--sgmii_clk_r,
-- -- -- -- -- -- -- -- -- -- -- sgmii_clk_f => open,--sgmii_clk_f,
-- -- -- -- -- -- -- -- -- -- -- sgmii_clk_en => open,--sgmii_clk_en,

-- -- -- -- -- -- -- -- -- -- -- gmii_txd             => RS_TX_Data,								-- Transmit data from client MAC.
-- -- -- -- -- -- -- -- -- -- -- gmii_tx_en           => RS_TX_Valid,								-- Transmit control SIGNAL from client MAC.
-- -- -- -- -- -- -- -- -- -- -- gmii_tx_er           => RS_TX_Error,								-- Transmit control SIGNAL from client MAC.
-- -- -- -- -- -- -- -- -- -- -- gmii_rxd             => RS_RX_Data,								-- Received Data to client MAC.
-- -- -- -- -- -- -- -- -- -- -- gmii_rx_dv           => RS_RX_Valid,								-- Received control SIGNAL to client MAC.
-- -- -- -- -- -- -- -- -- -- -- gmii_rx_er           => RS_RX_Error,								-- Received control SIGNAL to client MAC.
-- -- -- -- -- -- -- -- -- -- -- gmii_isolate         => open,														-- Tristate control to electrically isolate GMII


-- -- -- -- -- -- -- -- -- -- -- mdc 						=> PHY_Management.Clock_ts.i,					-- PHY_Management Data Clock
-- -- -- -- -- -- -- -- -- -- -- mdio_i					=> PHY_Management.Data_ts.i,					-- PHY_Management Data In
-- -- -- -- -- -- -- -- -- -- -- mdio_o					=> PHY_Management.Data_ts.o,					-- PHY_Management Data Out
-- -- -- -- -- -- -- -- -- -- -- mdio_t					=> PHY_Management.Data_ts.t,					-- PHY_Management Data Tristate

-- -- -- -- -- -- -- -- -- -- -- ext_mdc => open,--ext_mdc,
-- -- -- -- -- -- -- -- -- -- -- ext_mdio_i => '0',--ext_mdio_i,

-- -- -- -- -- -- -- -- -- -- -- mdio_t_in =>  '0',--mdio_t_in,
-- -- -- -- -- -- -- -- -- -- -- ext_mdio_o => open,--ext_mdio_o,
-- -- -- -- -- -- -- -- -- -- -- ext_mdio_t => open,--ext_mdio_t,

-- -- -- -- -- -- -- -- -- -- -- phyaddr => PCSCORE_MDIO_ADDRESS,											--
-- -- -- -- -- -- -- -- -- -- -- configuration_vector => PCSCORE_CONFIGURATION_VECTOR,	--configuration_vector
-- -- -- -- -- -- -- -- -- -- -- configuration_valid => to_sl(PCSCORE_CONFIGURATION),	--

-- -- -- -- -- -- -- -- -- -- -- an_interrupt => open,										--
-- -- -- -- -- -- -- -- -- -- -- an_adv_config_vector => (others => '0'),--
-- -- -- -- -- -- -- -- -- -- -- an_adv_config_val => '0',								--
-- -- -- -- -- -- -- -- -- -- -- an_restart_config => '0',								--

-- -- -- -- -- -- -- -- -- -- -- speed_is_10_100 =>  '0',--speed_is_10_100,
-- -- -- -- -- -- -- -- -- -- -- speed_is_100 =>  '1',--speed_is_100,

-- -- -- -- -- -- -- -- -- -- -- status_vector => SGMII_Status,--
-- -- -- -- -- -- -- -- -- -- -- reset => Reset,									--
-- -- -- -- -- -- -- -- -- -- -- signal_detect => '1',						--


-- -- -- -- -- -- -- -- -- -- -- -------------------
-- -- -- -- -- -- -- -- -- -- -- --			    gt0_qplloutclk_out => open,--gt0_qplloutclk_out,
-- -- -- -- -- -- -- -- -- -- -- --			    gt0_qplloutrefclk_out => open,--gt0_qplloutrefclk_out,
-- -- -- -- -- -- -- -- -- -- -- ---
-- -- -- -- -- -- -- -- -- -- -- gt0_qplloutclk_in =>  '0',--gt0_qplloutclk_in,
-- -- -- -- -- -- -- -- -- -- -- gt0_qplloutrefclk_in =>  '0'--gt0_qplloutrefclk_in
-- -- -- -- -- -- -- -- -- -- -- ----------------------------

-- -- -- -- -- -- -- -- -- -- -- );

			status_vector <=SGMII_Status;
--		SGMII_Status <= SGMII_Status_i;

		Trans : entity PoC.eth_SGMII_Transceiver_GTXE2
			port map (
				-- -- independent_clock    => PHY_Interface.DGB_SystemClock_In,
-- -- --				gtrefclk             => PHY_Interface.SGMII_RefClock_In,

				-- -- txoutclk             => SGMII_RefClock_Out,
				-- -- plllkdet             => plllock,

				-- -- usrclk               => Clock_62_5_MHz,
				-- -- usrclk2              => Clock_125_MHz,
-- -- --				mmcm_locked          => MMCM_Locked,

-- -- --				pmareset             => '0',																-- TODO:
				-- -- txreset              => mgt_tx_reset,
				-- -- rxreset              => mgt_rx_reset,
-- -- --				resetdone            => SGMII_ResetDone,

				-- -- powerdown            => powerdown,
				-- -- loopback             => '0',														-- Set the Transceiver for loopback.

				-- -- encommaalign         => enablealign,

				-- -- data_valid           => SGMII_Status_i(1)

				-- -- txdata               => txdata,
				-- -- txcharisk            => txcharisk,
				-- -- txbuferr             => txbuferr,
				-- -- txchardispmode       => txchardispmode,
				-- -- txchardispval        => txchardispval,

				-- -- rxelecidle           => open,----
				-- -- rxdata               => rxdata,
				-- -- rxchariscomma        => rxchariscomma,
				-- -- rxcharisk            => rxcharisk,
				-- -- rxdisperr            => rxdisperr,
				-- -- rxnotintable         => rxnotintable,
				-- -- rxrundisp            => rxrundisp,
				-- -- rxclkcorcnt          => rxclkcorcnt,
				-- -- rxbuferr             => rxbufstatus(1)

				-- -- txn                  => PHY_Interface.TX_n,
				-- -- txp                  => PHY_Interface.TX_p,
				-- -- rxn                  => PHY_Interface.RX_n,
				-- -- rxp                  => PHY_Interface.RX_p
			);

		 -- Unused
--		 rxbufstatus(0) <= '0';
	end generate;

end;
