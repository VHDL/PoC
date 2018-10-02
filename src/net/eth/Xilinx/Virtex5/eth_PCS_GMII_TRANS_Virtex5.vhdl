library	ieee;
use			ieee.std_logic_1164.all;

entity eth_GMII_SGMII_PCS_Virtex5 is
	port (
		reset									: in	std_logic;
		signal_detect					: in	std_logic;
		link_timer_value			: in	std_logic_vector(8 downto 0);
		mgt_rx_reset					: out	std_logic;
		mgt_tx_reset					: out	std_logic;
		userclk								: in	std_logic;
		userclk2							: in	std_logic;
		dcm_locked						: in	std_logic;
		rxbufstatus						: in	std_logic_vector(1 downto 0);
		rxchariscomma					: in	std_logic_vector(0 downto 0);
		rxcharisk							: in	std_logic_vector(0 downto 0);
		rxclkcorcnt						: in	std_logic_vector(2 downto 0);
		rxdata								: in	std_logic_vector(7 downto 0);
		rxdisperr							: in	std_logic_vector(0 downto 0);
		rxnotintable					: in	std_logic_vector(0 downto 0);
		rxrundisp							: in	std_logic_vector(0 downto 0);
		txbuferr							: in	std_logic;
		powerdown							: out	std_logic;
		txchardispmode				: out	std_logic;
		txchardispval					: out	std_logic;
		txcharisk							: out	std_logic;
		txdata								: out	std_logic_vector(7 downto 0);
		enablealign						: out	std_logic;
		gmii_txd							: in	std_logic_vector(7 downto 0);
		gmii_tx_en						: in	std_logic;
		gmii_tx_er						: in	std_logic;
		gmii_rxd							: out	std_logic_vector(7 downto 0);
		gmii_rx_dv						: out	std_logic;
		gmii_rx_er						: out	std_logic;
		gmii_isolate					: out	std_logic;
		an_interrupt					: out	std_logic;
		an_adv_config_vector	: in	std_logic_vector(15 downto 0);
		an_adv_config_val			: in	std_logic;
		an_restart_config			: in	std_logic;
		phyad									: in	std_logic_vector(4 downto 0);
		mdc										: in	std_logic;
		mdio_in								: in	std_logic;
		mdio_out							: out	std_logic;
		mdio_tri							: out	std_logic;
		configuration_vector	: in	std_logic_vector(4 downto 0);
		configuration_valid		: in	std_logic;
		status_vector					: out	std_logic_vector(15 downto 0)
	);
end;


architecture ngc of eth_GMII_SGMII_PCS_Virtex5 is

begin


end;
