

library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gig_ethernet_pcs_pma_v16_1_2;
use gig_ethernet_pcs_pma_v16_1_2.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.physical.all;
use			PoC.vectors.all;
use			PoC.net.all;
use			PoC.net_comp.all;
--------------------------------------------------------------------------------
-- The entity declaration for the Core Block wrapper.
--------------------------------------------------------------------------------
entity eth_RSLayer_GMII_SGMII_Series7 is
	generic (
		CLOCKIN_FREQ					: FREQ													:= 125 MHz
	);
	port (
--		Clock											: in		std_logic;
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
		 resetdone            : out std_logic;                    -- The GT transceiver has completed its reset cycle
		 speed_is_10_100            : in std_logic;   
		 speed_is_100            : in std_logic;  

		-- PHY-SGMII interface
		PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_SGMII
--		PHY_Management						: inout	T_NET_ETH_PHY_INTERFACE_MDIO
	);
end;

architecture rtl of eth_RSLayer_GMII_SGMII_Series7 is
   	attribute KEEP							: boolean;
   -----------------------------------------------------------------------------
   -- Component Declaration for the 1000BASE-X PCS/PMA sublayer core.
   -----------------------------------------------------------------------------
   component gig_ethernet_pcs_pma_v16_1_2
      generic (
         C_ELABORATION_TRANSIENT_DIR : string := "";
         C_COMPONENT_NAME            : string := "";
         C_RX_GMII_CLK               : string  := "TXOUTCLK";          
         C_FAMILY                    : string := "virtex2";
         C_IS_SGMII                  : boolean := false;
         C_USE_TRANSCEIVER           : boolean := true;
         C_HAS_TEMAC                 : boolean := true;
         C_USE_TBI                   : boolean := false;
         C_USE_LVDS                  : boolean := false;
         C_HAS_AN                    : boolean := true;
         C_HAS_MDIO                  : boolean := true;
         C_SGMII_PHY_MODE            : boolean := false;
         C_DYNAMIC_SWITCHING         : boolean := false;
         C_SGMII_FABRIC_BUFFER       : boolean := false;
         C_2_5G                      : boolean := false;
         C_1588                      : integer := 0;
         B_SHIFTER_ADDR              : std_logic_vector(9 downto 0) := "0101001110";
         GT_RX_BYTE_WIDTH            : integer := 1
      );
      port(
    reset : in std_logic := '0';
    signal_detect : in std_logic := '0';
    link_timer_value : in std_logic_vector(9 downto 0) := (others => '0');
    link_timer_basex : in std_logic_vector(9 downto 0) := (others => '0');
    link_timer_sgmii : in std_logic_vector(9 downto 0) := (others => '0');
    rx_gt_nominal_latency : in std_logic_vector(15 downto 0) := "0000000011001000";
    speed_is_10_100       : in std_logic := '0';                 
    speed_is_100          : in std_logic := '0'; 
    mgt_rx_reset : out std_logic;
    mgt_tx_reset : out std_logic;
    userclk : in std_logic := '0';
    userclk2 : in std_logic := '0';
    dcm_locked : in std_logic := '0';
    rxbufstatus : in std_logic_vector(1 downto 0) := (others => '0');
    rxchariscomma : in std_logic_vector(1-1 downto 0) := (others => '0');
    rxcharisk     : in std_logic_vector(1-1 downto 0) := (others => '0');
    rxclkcorcnt : in std_logic_vector(2 downto 0) := (others => '0');
    rxdata        : in std_logic_vector((1*8)-1 downto 0) := (others => '0');
    rxdisperr     : in std_logic_vector(1-1 downto 0) := (others => '0');
    rxnotintable  : in std_logic_vector(1-1 downto 0) := (others => '0');
    rxrundisp     : in std_logic_vector(1-1 downto 0) := (others => '0');
    txbuferr : in std_logic := '0';
    powerdown : out std_logic;
    txchardispmode : out std_logic;
    txchardispval : out std_logic;
    txcharisk : out std_logic;
    txdata : out std_logic_vector(7 downto 0);
    enablealign : out std_logic;
    gtx_clk : in std_logic := '0';
    tx_code_group : out std_logic_vector(9 downto 0);
    loc_ref : out std_logic;
    ewrap : out std_logic;
    rx_code_group0 : in std_logic_vector(9 downto 0) := (others => '0');
    rx_code_group1 : in std_logic_vector(9 downto 0) := (others => '0');
    pma_rx_clk0 : in std_logic := '0';
    pma_rx_clk1 : in std_logic := '0';
    en_cdet : out std_logic;
    gmii_txd : in std_logic_vector(7 downto 0) := (others => '0');
    gmii_tx_en : in std_logic := '0';
    gmii_tx_er : in std_logic := '0';
    gmii_rxd : out std_logic_vector(7 downto 0);
    gmii_rx_dv : out std_logic;
    gmii_rx_er : out std_logic;
    gmii_isolate : out std_logic;
    an_interrupt : out std_logic;
    an_enable : out std_logic;
    speed_selection : out std_logic_vector(1 downto 0);
    phyad : in std_logic_vector(4 downto 0) := (others => '0');
    mdc : in std_logic := '0';
    mdio_in : in std_logic := '0';
    mdio_out : out std_logic;
    mdio_tri : out std_logic;
    an_adv_config_vector : in std_logic_vector ( 15 downto 0) := (others => '0');
    an_adv_config_val : in std_logic := '0';
    an_restart_config : in std_logic := '0';  
    configuration_vector : in std_logic_vector(4 downto 0) := (others => '0');
    configuration_valid : in std_logic := '0';
    status_vector : out std_logic_vector(15 downto 0);
    basex_or_sgmii : in std_logic := '0';

    -----------------------
    -- I/O for 1588 support
    -----------------------
    -- Transceiver DRP
    drp_dclk                    : in  std_logic := '0';
    drp_req                     : out std_logic;
    drp_gnt                     : in  std_logic := '0';
    drp_den                     : out std_logic;
    drp_dwe                     : out std_logic;
    drp_drdy                    : in  std_logic := '0';
    drp_daddr                   : out std_logic_vector( 9 downto 0);
    drp_di                      : out std_logic_vector(15 downto 0);
    drp_do                      : in  std_logic_vector(15 downto 0) := (others => '0');
    
    -- 1588 Timer input
    systemtimer_s_field     : in std_logic_vector(47 downto 0) := (others => '0');
    systemtimer_ns_field    : in std_logic_vector(31 downto 0) := (others => '0');
    correction_timer        : in std_logic_vector(63 downto 0) := (others => '0');
    -- Rx CDR recovered clock from GT transcevier
    rxrecclk                : in  std_logic := '0';

    -- Rx 1588 Timer PHY Correction Ports
    rxphy_s_field           : out  std_logic_vector(47 downto 0) := (others => '0');
    rxphy_ns_field          : out  std_logic_vector(31 downto 0) := (others => '0');
    rxphy_correction_timer  : out  std_logic_vector(63 downto 0) := (others => '0');
    --resetdone indication from gt.
    reset_done            : in std_logic
      );

   end component;

  ------------------------------------------------------------------------------
  -- internal signals used in this block level wrapper.
  ------------------------------------------------------------------------------

  -- Core <=> Transceiver interconnect
  signal mgt_rx_reset      : std_logic;                        -- Reset for the receiver half of the Transceiver
  signal mgt_tx_reset      : std_logic;                        -- Reset for the transmitter half of the Transceiver
  signal rxbufstatus       : std_logic_vector (1 downto 0);    -- Elastic Buffer Status (bit 1 asserted indicates overflow or underflow).

  signal rxchariscomma     : std_logic_vector (0 downto 0);    -- Comma detected in RXDATA.
  signal rxcharisk         : std_logic_vector (0 downto 0);    -- K character received (or extra data bit) in RXDATA.
  signal rxclkcorcnt       : std_logic_vector (2 downto 0);    -- Indicates clock correction.
  signal rxdata            : t_slv_8;--std_logic_vector (7 downto 0);    -- Data after 8B/10B decoding.
  signal rxdisperr         : std_logic_vector (0 downto 0);    -- Disparity-error in RXDATA.
  signal rxnotintable      : std_logic_vector (0 downto 0);    -- Non-existent 8B/10 code indicated.
  signal rxrundisp         : std_logic_vector (0 downto 0);    -- Running Disparity after current byte, becomes 9th data bit when RXNOTINTABLE='1'.
  signal txbuferr          : std_logic;                        -- TX Buffer error (overflow or underflow).
  signal powerdown         : std_logic;                        -- Powerdown the Transceiver
  signal txchardispmode    : std_logic;                        -- Set running disparity for current byte.
  signal txchardispval     : std_logic;                        -- Set running disparity value.
  signal txcharisk         : std_logic;                        -- K character transmitted in TXDATA.
  signal txdata            : t_slv_8;--std_logic_vector(7 downto 0);     -- Data for 8B/10B encoding.
  signal enablealign       : std_logic;                        -- Allow the transceivers to serially realign to a comma character.
	signal cplllock					 : std_logic;
 
 
  -- -- GMII signals routed between core and SGMII Adaptation Module
  -- signal gmii_txd_int      : std_logic_vector(7 downto 0);     -- Internal gmii_txd signal (between core and SGMII adaptation module).
  -- signal gmii_tx_en_int    : std_logic;                        -- Internal gmii_tx_en signal (between core and SGMII adaptation module).
  -- signal gmii_tx_er_int    : std_logic;                        -- Internal gmii_tx_er signal (between core and SGMII adaptation module).
  -- signal gmii_rxd_int      : std_logic_vector(7 downto 0);     -- Internal gmii_rxd signal (between core and SGMII adaptation module).
  -- signal gmii_rx_dv_int    : std_logic;                        -- Internal gmii_rx_dv signal (between core and SGMII adaptation module).
  -- signal gmii_rx_er_int    : std_logic;                        -- Internal gmii_rx_er signal (between core and SGMII adaptation module).

  -- clock generation signals for SGMII clock
--  signal status_vector_i   : std_logic_vector(15 downto 0);    -- Internal status vector signal.

signal gt0_txresetdone_out_i : std_logic;
signal gt0_rxresetdone_out_i : std_logic;
--signal resetdone_i : std_logic;
signal tx_reset_done_i : std_logic;
signal rx_reset_done_i : std_logic;
signal reset_done_i : std_logic;
--signal mdio_o_int : std_logic;
--signal mdio_t_int : std_logic;

signal rx_gt_nominal_latency : std_logic_vector(15 downto 0);


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

	--PHY_Management.Clock_ts.t		<= '0';

	

rx_gt_nominal_latency <=  std_logic_vector(to_unsigned(280, 16));

genPCSIPCore : if (TRUE) generate
		constant PCSCORE_MDIO_ADDRESS						: std_logic_vector(4 downto 0)		:= "00101";
		constant PCSCORE_CONFIGURATION					: boolean													:= TRUE;
		constant PCSCORE_CONFIGURATION_VECTOR		: std_logic_vector(4 downto 0)		:= "10000";
		constant AN_CONFIGURATION_VECTOR		: std_logic_vector(15 downto 0)		:= "0001100000100000";

		-- Core <=> Transceiver interconnect
--		signal plllock           : std_logic;                        -- The PLL Locked status of the Transceiver
--		signal mgt_rx_reset      : std_logic;                        -- Reset for the receiver half of the Transceiver
--		signal mgt_tx_reset      : std_logic;                        -- Reset for the transmitter half of the Transceiver
--		signal rxbufstatus       : std_logic_vector (1 downto 0);    -- Elastic Buffer Status (bit 1 asserted indicates overflow or underflow).
--		signal rxchariscomma     : std_logic_vector (0 downto 0);                        -- Comma detected in RXDATA.
--		signal rxcharisk         : std_logic_vector (0 downto 0);                        -- K character received (or extra data bit) in RXDATA.
--		signal rxclkcorcnt       : std_logic_vector(2 downto 0);     -- Indicates clock correction.
--		signal rxdata            : T_SLV_8;														-- Data after 8B/10B decoding.
--		signal rxdisperr         : std_logic_vector (0 downto 0);                        -- Disparity-error in RXDATA.
--		signal rxnotintable      : std_logic_vector (0 downto 0);                        -- Non-existent 8B/10 code indicated.
--		signal rxrundisp         : std_logic_vector (0 downto 0);                        -- Running Disparity after current byte, becomes 9th data bit when RXNOTINTABLE='1'.
--		signal txbuferr          : std_logic;                        -- TX Buffer error (overflow or underflow).
--		signal powerdown         : std_logic;                        -- Powerdown the Transceiver
--		signal txchardispmode    : std_logic;                        -- Set running disparity for current byte.
--		signal txchardispval     : std_logic;                        -- Set running disparity value.
--		signal txcharisk         : std_logic;                        -- K character transmitted in TXDATA.
--		signal txdata            : T_SLV_8;														-- Data for 8B/10B encoding.
--		signal enablealign       : std_logic;                        -- Allow the transceivers to serially realign to a comma character.

		signal SGMII_Status_i					: T_SLV_16;
	begin
  ------------------------------------------------------------------------------
  -- Instantiate the core
  ------------------------------------------------------------------------------

  eth_GMII_SGMII_PCS_Series7_core : gig_ethernet_pcs_pma_v16_1_2
    generic map (
      C_ELABORATION_TRANSIENT_DIR => "BlankString",
      C_COMPONENT_NAME            => "eth_GMII_SGMII_PCS_Series7",
      C_RX_GMII_CLK               => "TXOUTCLK",
      C_FAMILY                    => "kintex7",
      C_IS_SGMII                  => true,
      C_USE_TRANSCEIVER           => true,
      C_HAS_TEMAC                 => true,
      C_USE_TBI                   => false,
      C_USE_LVDS                  => false,
      C_HAS_AN                    => false,
      C_HAS_MDIO                  => false,
      C_SGMII_PHY_MODE            => false,
      C_DYNAMIC_SWITCHING         => false,
      C_SGMII_FABRIC_BUFFER       => false,
      C_1588                      => 0,
      B_SHIFTER_ADDR              => "0101001110",
      C_2_5G                      => false,
      GT_RX_BYTE_WIDTH            => 1
    )
    port map (
      mgt_rx_reset         => mgt_rx_reset,		--
      mgt_tx_reset         => mgt_tx_reset,		--
			
      userclk              => Clock_125_MHz,	--userclk2,
      userclk2             => Clock_125_MHz,	--userclk2,
			
      rx_gt_nominal_latency => rx_gt_nominal_latency, 
			
      speed_is_10_100      => speed_is_10_100,
      speed_is_100         => speed_is_100,
      
 
      dcm_locked           => MMCM_Locked,		--
			
      rxbufstatus          => rxbufstatus,		--
      rxchariscomma        => rxchariscomma,	--
      rxcharisk            => rxcharisk,			--
      rxclkcorcnt          => rxclkcorcnt,		--
      rxdata               => rxdata,					--
      rxdisperr            => rxdisperr,			--
      rxnotintable         => rxnotintable,		--
      rxrundisp            => rxrundisp,			--
      
      powerdown            => powerdown,			--
			
      txchardispmode       => txchardispmode,	--
      txchardispval        => txchardispval,	--
      txcharisk            => txcharisk,			--
      txdata               => txdata,					--
			txbuferr             => txbuferr,				--
			
      enablealign          => enablealign,		--
			
      rxrecclk             => Clock_125_MHz,
			
      gmii_txd             => RS_TX_Data,			--gmii_txd,
      gmii_tx_en           => RS_TX_Valid,		--gmii_tx_en,
      gmii_tx_er           => RS_TX_Error,		--gmii_tx_er,
      gmii_rxd             => RS_RX_Data,			--gmii_rxd,
      gmii_rx_dv           => RS_RX_Valid,		--gmii_rx_dv,
      gmii_rx_er           => RS_RX_Error,		--gmii_rx_er,
      gmii_isolate         => open,						--gmii_isolate,
			
      configuration_vector => PCSCORE_CONFIGURATION_VECTOR,	--configuration_vector(4 downto 0),
      configuration_valid  => to_sl(PCSCORE_CONFIGURATION),	--'0',
			
      mdc                  => '0',--PHY_Management.Clock_ts.i,
      mdio_in              => '0',--PHY_Management.Data_ts.i,
      mdio_out             => open,--PHY_Management.Data_ts.o,
      mdio_tri             => open,--PHY_Management.Data_ts.t,
			phyad                => PCSCORE_MDIO_ADDRESS,					--(others => '0'),
            
      an_interrupt         => open,
      an_adv_config_vector => AN_CONFIGURATION_VECTOR,--(others => '0'),
      an_restart_config    => '0',
      an_adv_config_val    => '0',
			
      link_timer_value     => (others => '0'),--(others => '1')---------TODO:Review
      link_timer_basex     => (others => '0'),
      link_timer_sgmii     => (others => '0'),
      
      basex_or_sgmii       => '1',
      status_vector        => SGMII_Status_i,
      an_enable            => open,
      speed_selection      => open,
      signal_detect        => '1',					--signal_detect,
      -- drp interface used in 1588 mode
      drp_dclk             => '0',        
      drp_gnt              => '0',        
      drp_drdy             => '0',        
      drp_do               => (others => '0'),
      drp_req              => open, 
      drp_den              => open,
      drp_dwe              => open,
      drp_daddr            => open,
      drp_di               => open,
      -- 1588 Timer input
      systemtimer_s_field  => (others => '0'),
      systemtimer_ns_field => (others => '0'),
      correction_timer     => (others => '0'),
      rxphy_s_field          => open,
      rxphy_ns_field         => open,
      rxphy_correction_timer => open,
      
      
      gtx_clk              => Clock_125_MHz,--'0',
      rx_code_group0       => (others => '0'),
      rx_code_group1       => (others => '0'),
      pma_rx_clk0          => '0',
      pma_rx_clk1          => '0',
      tx_code_group        => open,
      loc_ref              => open,
      ewrap                => open,
      en_cdet              => open,
      reset_done           => reset_done_i,
			reset                => Reset
            
   );


  status_vector <= SGMII_Status_i;

  ------------------------------------------------------------------------------
  -- Component Instantiation for the Series-7 Transceiver wrapper
  ------------------------------------------------------------------------------

   transceiver_inst : entity work.eth_GMII_SGMII_PCS_Series7_transceiver
   generic map
    (
        EXAMPLE_SIMULATION            => 0
    )    
    
   port map (

      encommaalign                 => enablealign,
      powerdown                    => powerdown,
      usrclk                       => Clock_62_5_MHz,--userclk,
      usrclk2                      => Clock_125_MHz,--userclk2,
      rxusrclk                     => Clock_125_MHz,
      rxusrclk2                    => Clock_125_MHz,
      independent_clock            => PHY_Interface.DGB_SystemClock_In,--Clock_125_MHz,--independent_clock_bufg,
      data_valid                   => SGMII_Status_i(1),--status_vector_i(1),
			
      txreset                      => mgt_tx_reset,
      txchardispmode               => txchardispmode,
      txchardispval                => txchardispval,
      txcharisk                    => txcharisk,
      txdata                       => txdata,
      txbuferr                     => txbuferr,
			
      rxreset                      => mgt_rx_reset,
		
      rxchariscomma                => rxchariscomma(0),
      rxcharisk                    => rxcharisk(0),
      rxclkcorcnt                  => rxclkcorcnt,
      rxdata                       => rxdata,
      rxdisperr                    => rxdisperr(0),
      rxnotintable                 => rxnotintable(0),
      rxrundisp                    => rxrundisp(0),
      rxbuferr                     => rxbufstatus(1),
			
      plllkdet                     => cplllock,
      mmcm_reset                   => mmcm_reset_req,
      recclk_mmcm_reset            => open,
      txoutclk                     => SGMII_RefClock_Out,--txoutclk,
      rxoutclk                     => open,--rxoutclk,
			
      txn                          => PHY_Interface.TX_n,
      txp                          => PHY_Interface.TX_p,
      rxn                          => PHY_Interface.RX_n,
      rxp                          => PHY_Interface.RX_p,

      gtrefclk                     => PHY_Interface.SGMII_RefClock_In,--gtrefclk,
      gtrefclk_bufg                => PHY_Interface.SGMII_RefClock_In,--gtrefclk_bufg,
      pmareset                     => '0',--pma_reset,
      mmcm_locked                  => mmcm_locked,
      gt0_txpmareset_in         => '0',
      gt0_txpcsreset_in         => '0',
      gt0_rxpmareset_in         => '0',
      gt0_rxpcsreset_in         => '0',
      gt0_rxbufreset_in         => '0',
      gt0_rxbufstatus_out       => open,
      gt0_txbufstatus_out       => open,
      gt0_drpaddr_in            => (others=>'0'),
      
      gt0_drpclk_in                => PHY_Interface.SGMII_RefClock_In,--gtrefclk_bufg,

      gt0_drpdi_in              => (others=>'0'),
      gt0_drpdo_out             => open,
      gt0_drpen_in              => '0',
      gt0_drprdy_out            => open,
      gt0_drpwe_in              => '0',
      gt0_rxbyteisaligned_out   => open,
      gt0_rxbyterealign_out     => open,
      gt0_rxdfeagcovrden_in     => '0',
      gt0_rxmonitorout_out      => open,
      gt0_rxmonitorsel_in       => (others=>'0'),
      gt0_rxcommadet_out        => open,
      gt0_txpolarity_in         => '0',
      gt0_txdiffctrl_in         => "1000",
      
      gt0_txinhibit_in          => '0',
      gt0_txpostcursor_in       => (others=>'0'),
      gt0_txprecursor_in        => (others=>'0'),
      gt0_rxpolarity_in         => '0',
      gt0_rxdfelpmreset_in      => '0',
      gt0_rxlpmen_in            => '1',
      gt0_txprbssel_in          => (others=>'0'),
      gt0_txprbsforceerr_in     => '0',
      gt0_rxprbscntreset_in     => '0',
      gt0_rxprbserr_out         => open,
      gt0_rxprbssel_in          => (others=>'0'),
      gt0_loopback_in           => (others=>'0'),
      gt0_txresetdone_out       => gt0_txresetdone_out_i,
      gt0_rxresetdone_out       => gt0_rxresetdone_out_i,
      gt0_eyescanreset_in       => '0',
      gt0_eyescandataerror_out  => open,
      gt0_eyescantrigger_in     => '0',
      gt0_rxcdrhold_in          => '0',
      gt0_dmonitorout_out       => open ,       
      
      resetdone                 => SGMII_ResetDone,--open,
     gt0_qplloutclk             => '0',--gt0_qplloutclk_in,
     gt0_qplloutrefclk          => '0'--gt0_qplloutrefclk_in
   );

sync_Bits_inst : entity poc.sync_Bits
  generic map(
	  BITS					=> 2,								-- number of bit to be synchronized
		INIT					=>x"00",			-- initialitation bits
		SYNC_DEPTH		=> 2									-- generate SYNC_DEPTH many stages, at least 2
	)
  port map(
		Clock					=> Clock_125_MHz ,												-- <Clock>	output clock domain
		Input(0)			=> gt0_txresetdone_out_i,	-- @async:	input bits
		Input(1)			=> gt0_rxresetdone_out_i,	-- @async:	input bits
		Output(0)			=> tx_reset_done_i,		-- @Clock:	output bits
		Output(1)			 => rx_reset_done_i		-- @Clock:	output bits
	);
  
 reset_done_i <= tx_reset_done_i and rx_reset_done_i and SGMII_ResetDone;

 resetdone  <= reset_done_i;

   -- Unused
   rxbufstatus(0)           <= '0';
	end generate;
end rtl;

