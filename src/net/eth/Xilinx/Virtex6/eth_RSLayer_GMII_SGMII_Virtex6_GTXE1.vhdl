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


entity eth_RSLayer_GMII_SGMII_Virtex6_GTXE1 is
	generic (
		CLOCK_IN_FREQ_MHZ					: REAL													:= 125.0					-- 125 MHz
	);
	port (
		Clock											: in	STD_LOGIC;
		Reset											: in	STD_LOGIC;

		-- GEMAC-GMII interface
		RS_TX_Clock								: in	STD_LOGIC;
		RS_TX_Valid								: in	STD_LOGIC;
		RS_TX_Data								: in	T_SLV_8;
		RS_TX_Error								: in	STD_LOGIC;

		RS_RX_Clock								: out	STD_LOGIC;
		RS_RX_Valid								: out	STD_LOGIC;
		RS_RX_Data								: out	T_SLV_8;
		RS_RX_Error								: out	STD_LOGIC
	);
end;

architecture rtl of eth_RSLayer_GMII_SGMII_Virtex6_GTXE1 is


begin
--	SGMII : entity work.Ethernet_Virtex6_SGMII_example_design
--		port map (
--			-- MAC-GMII interface
--			sgmii_clk						=> GMII_ClockOut,										-- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
--
--			gmii_txd						=> GMII_TX_Data,										-- Transmit data from client MAC.
--			gmii_tx_en					=> GMII_TX_Valid,										-- Transmit control signal from client MAC.
--			gmii_tx_er					=> GMII_TX_Error,										-- Transmit control signal from client MAC.
--
--			gmii_rxd						=> GMII_RX_Data, 										-- Received Data to client MAC.
--			gmii_rx_dv					=> GMII_RX_Valid,										-- Received control signal to client MAC.
--			gmii_rx_er					=> GMII_RX_Error										-- Received control signal to client MAC.
--
--			-- Tranceiver Interface
--			-----------------------
----			mgtrefclk_p					: in std_logic;										 -- Differential +ve of reference clock for tranceiver: 125MHz, very high quality
----			mgtrefclk_n					: in std_logic;										 -- Differential -ve of reference clock for tranceiver: 125MHz, very high quality
----			txp									: out std_logic;										-- Differential +ve of serial transmission from PMA to PMD.
----			txn									: out std_logic;										-- Differential -ve of serial transmission from PMA to PMD.
----			rxp									: in std_logic;										 -- Differential +ve for serial reception from PMD to PMA.
----			rxn									: in std_logic;										 -- Differential -ve for serial reception from PMD to PMA.
--
--
--			-- Management: Alternative to MDIO Interface
--			--------------------------------------------
--
----			configuration_vector : in std_logic_vector(4 downto 0);	-- Alternative to MDIO interface.
--
--			-- Speed Control
--			----------------
----			speed_is_10_100			: in std_logic;										 -- Core should operate at either 10Mbps or 100Mbps speeds
----			speed_is_100				 : in std_logic;										 -- Core should operate at 100Mbps speed
--
--			-- General IO's
--			---------------
----			status_vector				: out std_logic_vector(15 downto 0); -- Core status.
----			reset								: in std_logic;										 -- Asynchronous reset for entire core.
----			signal_detect				: in std_logic											-- Input from PMD to indicate presence of optical input.
--			);

end;
