library	ieee;
use			ieee.std_logic_1164.all;

entity eth_GMII_SGMII_PCS_Virtex5 is
	port (
		reset									: IN	STD_LOGIC;
		signal_detect					: IN	STD_LOGIC;
		link_timer_value			: IN	STD_LOGIC_VECTOR(8 DOWNTO 0);
		mgt_rx_reset					: OUT	STD_LOGIC;
		mgt_tx_reset					: OUT	STD_LOGIC;
		userclk								: IN	STD_LOGIC;
		userclk2							: IN	STD_LOGIC;
		dcm_locked						: IN	STD_LOGIC;
		rxbufstatus						: IN	STD_LOGIC_VECTOR(1 DOWNTO 0);
		rxchariscomma					: IN	STD_LOGIC_VECTOR(0 DOWNTO 0);
		rxcharisk							: IN	STD_LOGIC_VECTOR(0 DOWNTO 0);
		rxclkcorcnt						: IN	STD_LOGIC_VECTOR(2 DOWNTO 0);
		rxdata								: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
		rxdisperr							: IN	STD_LOGIC_VECTOR(0 DOWNTO 0);
		rxnotintable					: IN	STD_LOGIC_VECTOR(0 DOWNTO 0);
		rxrundisp							: IN	STD_LOGIC_VECTOR(0 DOWNTO 0);
		txbuferr							: IN	STD_LOGIC;
		powerdown							: OUT	STD_LOGIC;
		txchardispmode				: OUT	STD_LOGIC;
		txchardispval					: OUT	STD_LOGIC;
		txcharisk							: OUT	STD_LOGIC;
		txdata								: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
		enablealign						: OUT	STD_LOGIC;
		gmii_txd							: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
		gmii_tx_en						: IN	STD_LOGIC;
		gmii_tx_er						: IN	STD_LOGIC;
		gmii_rxd							: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
		gmii_rx_dv						: OUT	STD_LOGIC;
		gmii_rx_er						: OUT	STD_LOGIC;
		gmii_isolate					: OUT	STD_LOGIC;
		an_interrupt					: OUT	STD_LOGIC;
		an_adv_config_vector	: IN	STD_LOGIC_VECTOR(15 DOWNTO 0);
		an_adv_config_val			: IN	STD_LOGIC;
		an_restart_config			: IN	STD_LOGIC;
		phyad									: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
		mdc										: IN	STD_LOGIC;
		mdio_in								: IN	STD_LOGIC;
		mdio_out							: OUT	STD_LOGIC;
		mdio_tri							: OUT	STD_LOGIC;
		configuration_vector	: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
		configuration_valid		: IN	STD_LOGIC;
		status_vector					: OUT	STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
end;


architecture ngc of eth_GMII_SGMII_PCS_Virtex5 is

begin


end;
