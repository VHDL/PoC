LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;


ENTITY Eth_RSLayer_GMII_SGMII_Virtex5 IS
	GENERIC (
		CLOCKIN_FREQ_MHZ					: REAL													:= 125.0					-- 125 MHz
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

ARCHITECTURE rtl OF Eth_RSLayer_GMII_SGMII_Virtex5 IS


BEGIN


--	PCS : ENTITY work.Ethernet_Virtex5_SGMII_example_design
--		PORT MAP (
--			-- GMII Interface
--			-----------------
--			sgmii_clk0           : out std_logic;                    -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
--			gmii_txd0            : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
--			gmii_tx_en0          : in std_logic;                     -- Transmit control signal from client MAC.
--			gmii_tx_er0          : in std_logic;                     -- Transmit control signal from client MAC.
--			gmii_rxd0            : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
--			gmii_rx_dv0          : out std_logic;                    -- Received control signal to client MAC.
--			gmii_rx_er0          : out std_logic;                    -- Received control signal to client MAC.
--
--			-- Management: MDIO Interface
--			-----------------------------
--			mdc0										=> MDIO_Clock,										-- Management Data Clock
--			mdio0_i									=> MDIO_i,												-- Management Data In
--			mdio0_o									=> MDIO_o,												-- Management Data Out
--			mdio0_t									=> MDIO_t,												-- Management Data Tristate
--			phyad0									=> "00101",												-- Port address for MDIO.
--			configuration_vector0		=> "10000",												-- Alternative to MDIO interface.
--			configuration_valid0		=> '1',														-- Validation signal for Config vector.
--			an_interrupt0						=> OPEN,													-- Interrupt to processor to signal that Auto-Negotiation has completed
--			an_adv_config_vector0		=> (OTHERS => '0'),								-- Alternate interface to program REG4 (AN ADV)
--			an_adv_config_val0			=> '0',														-- Validation signal for AN ADV
--			an_restart_config0			=> '0',														-- Alternate signal to modify AN restart bit in REG0
--			link_timer_value0				=> (OTHERS => '1'),								-- Programmable Auto-Negotiation Link Timer Control
--
--			-- General IO's
--			---------------
--			status_vector0					=> status,												-- Core status.
--			reset0									=> Reset,													-- Asynchronous reset for entire core.
--			signal_detect0					=> '1',														-- Input from PMD to indicate presence of optical input.
--			-- Speed Control
--			----------------
--			speed0_is_10_100				=> '0',														-- Core should operate at either 10Mbps or 100Mbps speeds
--			speed0_is_100						=> '0',														-- Core should operate at 100Mbps speed
--
--
--			--------------------------------------------------------------------------
--			-- Tranceiver interfaces
--			--------------------------------------------------------------------------
--			brefclk									=> PHY_Interface.
--
--			txp0										=> PHY_Interface.                   -- Differential +ve of serial transmission from PMA to PMD.
--			txn0										=> PHY_Interface.                    -- Differential -ve of serial transmission from PMA to PMD.
--			rxp0										=> PHY_Interface.                     -- Differential +ve for serial reception from PMD to PMA.
--			rxn0										=> PHY_Interface.                   -- Differential -ve for serial reception from PMD to PMA.
--		);
END;
