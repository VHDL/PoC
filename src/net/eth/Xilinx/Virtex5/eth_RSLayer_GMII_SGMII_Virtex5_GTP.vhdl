-- EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Entity:					TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
<<<<<<< Updated upstream
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
=======
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--										Chair for VLSI-Design, Diagnostics and Architecture
>>>>>>> Stashed changes
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.net.all;


entity Eth_RSLayer_GMII_SGMII_Virtex5 is
	generic (
		CLOCKIN_FREQ_MHZ					: REAL													:= 125.0					-- 125 MHz
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

		-- PHY-SGMII interface
		PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_SGMII;
		PHY_Management						: inout	T_NET_ETH_PHY_INTERFACE_MDIO
	);
end;


architecture rtl of Eth_RSLayer_GMII_SGMII_Virtex5 is


begin



	Trans : entity PoC.eth_GMII_SGMII_PCS_Virtex5_transceiver_A
		generic map (
			SIM_GTPRESET_SPEEDUP => SIM_GTPRESET_SPEEDUP
		)
		port map (
			refclkout						=> refclkout,
			refclkin						=> userclk2,
			gtpreset						=> gtpreset,

			-- tranceiver 0
			resetdone0					=> open,
			enablealign0				=> enablealign0,
			powerdown0					=> powerdown0,
			loopback0						=> loopback,
			rxchariscomma0			=> rxchariscomma0(0),
			rxcharisk0					=> rxcharisk0(0),
			rxclkcorcnt0				=> rxclkcorcnt0,
			rxdata0							=> rxdata0,
			rxdisperr0					=> rxdisperr0(0),
			rxnotintable0				=> rxnotintable0(0),
			rxrundisp0					=> rxrundisp0(0),
			rxbuferr0						=> rxbufstatus0(1),
			rxusrclk0						=> userclk2,
			rxusrclk20					=> userclk2,
			rxreset0						=> mgt_rx_reset0,
			txchardispmode0			=> txchardispmode0,
			txchardispval0			=> txchardispval0,
			txcharisk0					=> txcharisk0,
			txdata0							=> txdata0,
			txbuferr0						=> txbuferr0,
			txusrclk0						=> userclk2,
			txusrclk20					=> userclk2,
			txreset0						=> mgt_tx_reset0,


			txn0								=> txn0,
			txp0								=> txp0,
			rxn0								=> rxn0,
			rxp0								=> rxp0,

			txn1								=> txn1,
			txp1								=> txp1,
			rxn1								=> rxn1,
			rxp1								=> rxp1,

			plllkdet						=> plllkdet,
			clkin								=> clkin
		);

--	PCS : entity work.Ethernet_Virtex5_SGMII_example_design
--		port map (
--			-- GMII Interface
--			-----------------
--			sgmii_clk0					: out std_logic;										-- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
--			gmii_txd0						: in std_logic_vector(7 downto 0);	-- Transmit data from client MAC.
--			gmii_tx_en0					: in std_logic;										-- Transmit control signal from client MAC.
--			gmii_tx_er0					: in std_logic;										-- Transmit control signal from client MAC.
--			gmii_rxd0						: out std_logic_vector(7 downto 0); -- Received Data to client MAC.
--			gmii_rx_dv0					: out std_logic;										-- Received control signal to client MAC.
--			gmii_rx_er0					: out std_logic;										-- Received control signal to client MAC.
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
--			an_interrupt0						=> open,													-- Interrupt to processor to signal that Auto-Negotiation has completed
--			an_adv_config_vector0		=> (others => '0'),								-- Alternate interface to program REG4 (AN ADV)
--			an_adv_config_val0			=> '0',														-- Validation signal for AN ADV
--			an_restart_config0			=> '0',														-- Alternate signal to modify AN restart bit in REG0
--			link_timer_value0				=> (others => '1'),								-- Programmable Auto-Negotiation Link Timer Control
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
--			txp0										=> PHY_Interface.									-- Differential +ve of serial transmission from PMA to PMD.
--			txn0										=> PHY_Interface.										-- Differential -ve of serial transmission from PMA to PMD.
--			rxp0										=> PHY_Interface.										-- Differential +ve for serial reception from PMD to PMA.
--			rxn0										=> PHY_Interface.									-- Differential -ve for serial reception from PMD to PMA.
--		);
end;
