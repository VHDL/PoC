library	ieee;
use			ieee.std_logic_1164.all;

entity eth_GMII_SGMII_PCS_Virtex5 is
	port (
		reset									: in	STD_LOGIC;
		signal_detect					: in	STD_LOGIC;
		link_timer_value			: in	STD_LOGIC_VECTOR(8 downto 0);
		mgt_rx_reset					: out	STD_LOGIC;
		mgt_tx_reset					: out	STD_LOGIC;
		userclk								: in	STD_LOGIC;
		userclk2							: in	STD_LOGIC;
		dcm_locked						: in	STD_LOGIC;
		rxbufstatus						: in	STD_LOGIC_VECTOR(1 downto 0);
		rxchariscomma					: in	STD_LOGIC_VECTOR(0 downto 0);
		rxcharisk							: in	STD_LOGIC_VECTOR(0 downto 0);
		rxclkcorcnt						: in	STD_LOGIC_VECTOR(2 downto 0);
		rxdata								: in	STD_LOGIC_VECTOR(7 downto 0);
		rxdisperr							: in	STD_LOGIC_VECTOR(0 downto 0);
		rxnotintable					: in	STD_LOGIC_VECTOR(0 downto 0);
		rxrundisp							: in	STD_LOGIC_VECTOR(0 downto 0);
		txbuferr							: in	STD_LOGIC;
		powerdown							: out	STD_LOGIC;
		txchardispmode				: out	STD_LOGIC;
		txchardispval					: out	STD_LOGIC;
		txcharisk							: out	STD_LOGIC;
		txdata								: out	STD_LOGIC_VECTOR(7 downto 0);
		enablealign						: out	STD_LOGIC;
		gmii_txd							: in	STD_LOGIC_VECTOR(7 downto 0);
		gmii_tx_en						: in	STD_LOGIC;
		gmii_tx_er						: in	STD_LOGIC;
		gmii_rxd							: out	STD_LOGIC_VECTOR(7 downto 0);
		gmii_rx_dv						: out	STD_LOGIC;
		gmii_rx_er						: out	STD_LOGIC;
		gmii_isolate					: out	STD_LOGIC;
		an_interrupt					: out	STD_LOGIC;
		an_adv_config_vector	: in	STD_LOGIC_VECTOR(15 downto 0);
		an_adv_config_val			: in	STD_LOGIC;
		an_restart_config			: in	STD_LOGIC;
		phyad									: in	STD_LOGIC_VECTOR(4 downto 0);
		mdc										: in	STD_LOGIC;
		mdio_in								: in	STD_LOGIC;
		mdio_out							: out	STD_LOGIC;
		mdio_tri							: out	STD_LOGIC;
		configuration_vector	: in	STD_LOGIC_VECTOR(4 downto 0);
		configuration_valid		: in	STD_LOGIC;
		status_vector					: out	STD_LOGIC_VECTOR(15 downto 0)
	);
end;


architecture ngc of eth_GMII_SGMII_PCS_Virtex5 is

begin


end;
