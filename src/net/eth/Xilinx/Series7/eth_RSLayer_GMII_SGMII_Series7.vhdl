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
 PORT (
		--Control
    reset : IN STD_LOGIC;
    resetdone : OUT STD_LOGIC;
		
    status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    configuration_vector : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    speed_is_10_100 : IN STD_LOGIC;
    speed_is_100 : IN STD_LOGIC;
    signal_detect : IN STD_LOGIC;
		
		--CLK s
    gtrefclk_bufg : IN STD_LOGIC;
    gtrefclk : IN STD_LOGIC;
		
    gt0_qplloutclk_in : IN STD_LOGIC;
    gt0_qplloutrefclk_in : IN STD_LOGIC;
		
    independent_clock_bufg : IN STD_LOGIC;
		
    mmcm_locked : IN STD_LOGIC;
    mmcm_reset : OUT STD_LOGIC;
		
    txoutclk : OUT STD_LOGIC;
    rxoutclk : OUT STD_LOGIC;
		
    cplllock : OUT STD_LOGIC;
		
    pma_reset : IN STD_LOGIC;
		
    userclk : IN STD_LOGIC;
    userclk2 : IN STD_LOGIC;
		
    rxuserclk : IN STD_LOGIC;
    rxuserclk2 : IN STD_LOGIC;
		
    sgmii_clk_r : OUT STD_LOGIC;
    sgmii_clk_f : OUT STD_LOGIC;
    sgmii_clk_en : OUT STD_LOGIC;
		
		--SGMII PHY Interface
    txn : OUT STD_LOGIC;
    txp : OUT STD_LOGIC;
    rxn : IN STD_LOGIC;
    rxp : IN STD_LOGIC;
		
		--GMII Interface
    gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_tx_en : IN STD_LOGIC;
    gmii_tx_er : IN STD_LOGIC;
    gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_rx_dv : OUT STD_LOGIC;
    gmii_rx_er : OUT STD_LOGIC;
    gmii_isolate : OUT STD_LOGIC
  );
end;

architecture rtl of eth_RSLayer_GMII_SGMII_Series7 is

--	COMPONENT eth_GMII_SGMII_PCS_Series7
--    PORT (
--    gtrefclk_p : IN STD_LOGIC;
--    gtrefclk_n : IN STD_LOGIC;
--    gtrefclk_out : OUT STD_LOGIC;
--    gtrefclk_bufg_out : OUT STD_LOGIC;
		
		
--    txn : OUT STD_LOGIC;
--    txp : OUT STD_LOGIC;
--    rxn : IN STD_LOGIC;
--    rxp : IN STD_LOGIC;
		
		
--    independent_clock_bufg : IN STD_LOGIC;
		
		
--    userclk_out : OUT STD_LOGIC;
--    userclk2_out : OUT STD_LOGIC;
--    rxuserclk_out : OUT STD_LOGIC;
--    rxuserclk2_out : OUT STD_LOGIC;
		
		
--    resetdone : OUT STD_LOGIC;
--    pma_reset_out : OUT STD_LOGIC;
--    mmcm_locked_out : OUT STD_LOGIC;
		
		
--    sgmii_clk_r : OUT STD_LOGIC;
--    sgmii_clk_f : OUT STD_LOGIC;
--    sgmii_clk_en : OUT STD_LOGIC;
		
		
--    gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
--    gmii_tx_en : IN STD_LOGIC;
--    gmii_tx_er : IN STD_LOGIC;
--    gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
--    gmii_rx_dv : OUT STD_LOGIC;
--    gmii_rx_er : OUT STD_LOGIC;
--    gmii_isolate : OUT STD_LOGIC;
		
		
--    mdc : IN STD_LOGIC;
--    mdio_i : IN STD_LOGIC;
--    mdio_o : OUT STD_LOGIC;
--    mdio_t : OUT STD_LOGIC;
--    ext_mdc : OUT STD_LOGIC;
--    ext_mdio_i : IN STD_LOGIC;
--    mdio_t_in : IN STD_LOGIC;
--    ext_mdio_o : OUT STD_LOGIC;
--    ext_mdio_t : OUT STD_LOGIC;
--    phyaddr : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		
		
--    configuration_vector : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
--    configuration_valid : IN STD_LOGIC;
		
		
--    an_interrupt : OUT STD_LOGIC;
--    an_adv_config_vector : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    an_adv_config_val : IN STD_LOGIC;
--    an_restart_config : IN STD_LOGIC;
		
		
--    speed_is_10_100 : IN STD_LOGIC;
--    speed_is_100 : IN STD_LOGIC;
		
		
--    status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
--    reset : IN STD_LOGIC;
--    signal_detect : IN STD_LOGIC;
--    gt0_qplloutclk_out : OUT STD_LOGIC;
--    gt0_qplloutrefclk_out : OUT STD_LOGIC
--  );
--	END COMPONENT;

begin

eth_GMII_SGMII_PCS_Series7_inst : eth_GMII_SGMII_PCS_Series7
  PORT MAP (
		gtrefclk_bufg => gtrefclk_bufg,
		gtrefclk => gtrefclk,
		txn => txn,
		txp => txp,
		rxn => rxn,
		rxp => rxp,
		independent_clock_bufg => independent_clock_bufg,
		txoutclk => txoutclk,
		rxoutclk => rxoutclk,
		resetdone => resetdone,
		cplllock => cplllock,
		mmcm_reset => mmcm_reset,
		userclk => userclk,
		userclk2 => userclk2,
		pma_reset => pma_reset,
		mmcm_locked => mmcm_locked,
		rxuserclk => rxuserclk,
		rxuserclk2 => rxuserclk2,
		sgmii_clk_r => sgmii_clk_r,
		sgmii_clk_f => sgmii_clk_f,
		sgmii_clk_en => sgmii_clk_en,
		gmii_txd => gmii_txd,
		gmii_tx_en => gmii_tx_en,
		gmii_tx_er => gmii_tx_er,
		gmii_rxd => gmii_rxd,
		gmii_rx_dv => gmii_rx_dv,
		gmii_rx_er => gmii_rx_er,
		gmii_isolate => gmii_isolate,
		configuration_vector => configuration_vector,
		speed_is_10_100 => speed_is_10_100,
		speed_is_100 => speed_is_100,
		status_vector => status_vector,
		reset => reset,
		signal_detect => signal_detect,
		gt0_qplloutclk_in => gt0_qplloutclk_in,
		gt0_qplloutrefclk_in => gt0_qplloutrefclk_in
	);
	
end;
