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

-- entity eth_RSLayer_GMII_SGMII_Series7 is
 -- PORT (
		-- --Control
    -- reset : IN STD_LOGIC;
    -- resetdone : OUT STD_LOGIC;
		
    -- status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    -- configuration_vector : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    -- speed_is_10_100 : IN STD_LOGIC;
    -- speed_is_100 : IN STD_LOGIC;
    -- signal_detect : IN STD_LOGIC;
		
		-- --CLK s
    -- gtrefclk_bufg : IN STD_LOGIC;
    -- gtrefclk : IN STD_LOGIC;
		
    -- gt0_qplloutclk_in : IN STD_LOGIC;
    -- gt0_qplloutrefclk_in : IN STD_LOGIC;
		
    -- independent_clock_bufg : IN STD_LOGIC;
		
    -- mmcm_locked : IN STD_LOGIC;
    -- mmcm_reset : OUT STD_LOGIC;
		
    -- txoutclk : OUT STD_LOGIC;
    -- rxoutclk : OUT STD_LOGIC;
		
    -- cplllock : OUT STD_LOGIC;
		
    -- pma_reset : IN STD_LOGIC;
		
    -- userclk : IN STD_LOGIC;
    -- userclk2 : IN STD_LOGIC;
		
    -- rxuserclk : IN STD_LOGIC;
    -- rxuserclk2 : IN STD_LOGIC;
		
    -- sgmii_clk_r : OUT STD_LOGIC;
    -- sgmii_clk_f : OUT STD_LOGIC;
    -- sgmii_clk_en : OUT STD_LOGIC;
		
		-- --SGMII PHY Interface
    -- txn : OUT STD_LOGIC;
    -- txp : OUT STD_LOGIC;
    -- rxn : IN STD_LOGIC;
    -- rxp : IN STD_LOGIC;
		
		-- --GMII Interface
    -- gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    -- gmii_tx_en : IN STD_LOGIC;
    -- gmii_tx_er : IN STD_LOGIC;
    -- gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    -- gmii_rx_dv : OUT STD_LOGIC;
    -- gmii_rx_er : OUT STD_LOGIC;
    -- gmii_isolate : OUT STD_LOGIC
  -- );
-- end;

architecture rtl of eth_RSLayer_GMII_SGMII_Series7 is

	COMPONENT eth_GMII_SGMII_PCS_Series7
  PORT (
    gtrefclk_bufg : IN STD_LOGIC;
    gtrefclk : IN STD_LOGIC;
    txn : OUT STD_LOGIC;
    txp : OUT STD_LOGIC;
    rxn : IN STD_LOGIC;
    rxp : IN STD_LOGIC;
    independent_clock_bufg : IN STD_LOGIC;
    txoutclk : OUT STD_LOGIC;
    rxoutclk : OUT STD_LOGIC;
    resetdone : OUT STD_LOGIC;
    cplllock : OUT STD_LOGIC;
    mmcm_reset : OUT STD_LOGIC;
    userclk : IN STD_LOGIC;
    userclk2 : IN STD_LOGIC;
    pma_reset : IN STD_LOGIC;
    mmcm_locked : IN STD_LOGIC;
    rxuserclk : IN STD_LOGIC;
    rxuserclk2 : IN STD_LOGIC;
    sgmii_clk_r : OUT STD_LOGIC;
    sgmii_clk_f : OUT STD_LOGIC;
    sgmii_clk_en : OUT STD_LOGIC;
    gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_tx_en : IN STD_LOGIC;
    gmii_tx_er : IN STD_LOGIC;
    gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_rx_dv : OUT STD_LOGIC;
    gmii_rx_er : OUT STD_LOGIC;
    gmii_isolate : OUT STD_LOGIC;
    configuration_vector : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    speed_is_10_100 : IN STD_LOGIC;
    speed_is_100 : IN STD_LOGIC;
    status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    reset : IN STD_LOGIC;
    signal_detect : IN STD_LOGIC;
    gt0_qplloutclk_in : IN STD_LOGIC;
    gt0_qplloutrefclk_in : IN STD_LOGIC
  );
END COMPONENT;

	constant PCSCORE_MDIO_ADDRESS						: std_logic_vector(4 downto 0)		:= "00101";
	constant PCSCORE_CONFIGURATION					: boolean													:= TRUE;
	constant PCSCORE_CONFIGURATION_VECTOR		: std_logic_vector(4 downto 0)		:= "10000";
	constant AN_CONFIGURATION_VECTOR		: std_logic_vector(15 downto 0)		:= "0001100000100000";

	signal SGMII_Status_i					: T_SLV_16;
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
	
	signal cplllock					 : std_logic;
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

	
eth_GMII_SGMII_PCS_Series7_inst : eth_GMII_SGMII_PCS_Series7
  PORT MAP (
		gtrefclk_bufg => PHY_Interface.SGMII_RefClock_In,--gtrefclk_bufg,
		gtrefclk => PHY_Interface.SGMII_RefClock_In,--gtrefclk,
		txn => PHY_Interface.TX_n,--txn,
		txp => PHY_Interface.TX_p,--txp,
		rxn => PHY_Interface.RX_n,--rxn,
		rxp => PHY_Interface.RX_p,--rxp,
		independent_clock_bufg => PHY_Interface.DGB_SystemClock_In,--independent_clock_bufg,
		txoutclk => SGMII_RefClock_Out,--txoutclk,
		rxoutclk => open,--rxoutclk,
		resetdone => SGMII_ResetDone,--resetdone,
		cplllock => cplllock,
		mmcm_reset => mmcm_reset_req,--mmcm_reset,
		userclk => Clock_62_5_MHz,--userclk,
		userclk2 => Clock_125_MHz,--userclk2,
		pma_reset => '0',--pma_reset,
		mmcm_locked => mmcm_locked,
		rxuserclk => Clock_125_MHz,--rxuserclk,
		rxuserclk2 => Clock_125_MHz,--rxuserclk2,
		sgmii_clk_r => open,--sgmii_clk_r,
		sgmii_clk_f => open,--sgmii_clk_f,
		sgmii_clk_en => open,--sgmii_clk_en,
		gmii_txd => RS_TX_Data,			--gmii_txd,
		gmii_tx_en => RS_TX_Valid,		--gmii_tx_en,
		gmii_tx_er => RS_TX_Error,		--gmii_tx_er,
		gmii_rxd => RS_RX_Data,			--gmii_rxd,
		gmii_rx_dv => RS_RX_Valid,		--gmii_rx_dv,
		gmii_rx_er => RS_RX_Error,		--gmii_rx_er,
		gmii_isolate => open,						--gmii_isolate,
		configuration_vector => PCSCORE_CONFIGURATION_VECTOR,	--configuration_vector,
		speed_is_10_100 => speed_is_10_100,
		speed_is_100 => speed_is_100,
		status_vector => status_vector,
		reset => reset,
		signal_detect => '1',--signal_detect,
		gt0_qplloutclk_in => '0',--gt0_qplloutclk_in,
		gt0_qplloutrefclk_in => '0'--gt0_qplloutrefclk_in
	);
	
end;
