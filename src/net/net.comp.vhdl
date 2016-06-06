-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS is" BASIS,
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
use			PoC.physical.all;
use			PoC.io.all;
use			PoC.net.all;


package net_comp is
	-- ==========================================================================================================================================================
	-- Ethernet: reconcilation sublayer (RS)
	-- ==========================================================================================================================================================
	component eth_RSLayer_GMII_GMII_Xilinx is
		port (
			Reset_async								: in	STD_LOGIC;																	-- @async:

			-- RS-GMII interface
			RS_TX_Clock								: in	STD_LOGIC;
			RS_TX_Valid								: in	STD_LOGIC;
			RS_TX_Data								: in	T_SLV_8;
			RS_TX_Error								: in	STD_LOGIC;

			RS_RX_Clock								: in	STD_LOGIC;
			RS_RX_Valid								: out	STD_LOGIC;
			RS_RX_Data								: out	T_SLV_8;
			RS_RX_Error								: out	STD_LOGIC;

			-- PHY-GMII interface
			PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_GMII
		);
	end component;

	component eth_RSLayer_GMII_SGMII_Virtex5 is
		generic (
			CLOCK_IN_FREQ							: FREQ													:= 125 MHz					-- 125 MHz
		);
		port (
			Clock											: in	STD_LOGIC;
			Reset											: in	STD_LOGIC;

			-- GEMAC-GMII interface
			RS_TX_Clock								: in	STD_LOGIC;
			RS_TX_Valid								: in	STD_LOGIC;
			RS_TX_Data								: in	T_SLV_8;
			RS_TX_Error								: in	STD_LOGIC;

			RS_RX_Clock								: in	STD_LOGIC;
			RS_RX_Valid								: out	STD_LOGIC;
			RS_RX_Data								: out	T_SLV_8;
			RS_RX_Error								: out	STD_LOGIC;

			-- PHY-SGMII interface
			PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_SGMII
		);
	end component;

	component eth_RSLayer_GMII_SGMII_Virtex6 is
		generic (
			CLOCK_IN_FREQ							: FREQ													:= 125 MHz					-- 125 MHz
		);
		port (
			Clock											: in	STD_LOGIC;
			Reset											: in	STD_LOGIC;

			-- GEMAC-GMII interface
			RS_TX_Clock								: in	STD_LOGIC;
			RS_TX_Valid								: in	STD_LOGIC;
			RS_TX_Data								: in	T_SLV_8;
			RS_TX_Error								: in	STD_LOGIC;

			RS_RX_Clock								: in	STD_LOGIC;
			RS_RX_Valid								: out	STD_LOGIC;
			RS_RX_Data								: out	T_SLV_8;
			RS_RX_Error								: out	STD_LOGIC;

			-- PHY-SGMII interface
			PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_SGMII
		);
	end component;

	component eth_RSLayer_GMII_SGMII_Series7 is
		generic (
			CLOCK_IN_FREQ							: FREQ													:= 125 MHz					-- 125 MHz
		);
		port (
			Clock											: in	STD_LOGIC;
			Reset											: in	STD_LOGIC;

			-- GEMAC-GMII interface
			RS_TX_Clock								: in	STD_LOGIC;
			RS_TX_Valid								: in	STD_LOGIC;
			RS_TX_Data								: in	T_SLV_8;
			RS_TX_Error								: in	STD_LOGIC;

			RS_RX_Clock								: in	STD_LOGIC;
			RS_RX_Valid								: out	STD_LOGIC;
			RS_RX_Data								: out	T_SLV_8;
			RS_RX_Error								: out	STD_LOGIC;

			-- PHY-SGMII interface
			PHY_Interface							: inout	T_NET_ETH_PHY_INTERFACE_SGMII
		);
	end component;

 -----------------------------------------------------------------------------
   -- Component Declaration for the 1000BASE-X PCS/PMA sublayer core.
   -----------------------------------------------------------------------------
	component eth_PCS_IPCore_Virtex7
		port (
			-- Core <=> Transceiver Interface
			------------------------------
			mgt_rx_reset         : out STD_LOGIC;                    -- Transceiver connection: reset for the receiver half of the Transceiver
			mgt_tx_reset         : out STD_LOGIC;                    -- Transceiver connection: reset for the transmitter half of the Transceiver
			userclk              : in STD_LOGIC;                     -- Routed to TXUSERCLK and RXUSERCLK of Transceiver.
			userclk2             : in STD_LOGIC;                     -- Routed to TXUSERCLK2 and RXUSERCLK2 of Transceiver.
			dcm_locked           : in STD_LOGIC;                     -- LOCKED signal from DCM.

			rxbufstatus          : in STD_LOGIC_VECTOR (1 downto 0); -- Transceiver connection: Elastic Buffer Status.
			rxchariscomma        : in STD_LOGIC;                     -- Transceiver connection: Comma detected in RXDATA.
			rxcharisk            : in STD_LOGIC;                     -- Transceiver connection: K character received (or extra data bit) in RXDATA.
			rxclkcorcnt          : in STD_LOGIC_VECTOR(2 downto 0);  -- Transceiver connection: Indicates clock correction.
			rxdata               : in STD_LOGIC_VECTOR(7 downto 0);  -- Transceiver connection: Data after 8B/10B decoding.
			rxdisperr            : in STD_LOGIC;                     -- Transceiver connection: Disparity-error in RXDATA.
			rxnotintable         : in STD_LOGIC;                     -- Transceiver connection: Non-existent 8B/10 code indicated.
			rxrundisp            : in STD_LOGIC;                     -- Transceiver connection: Running Disparity of RXDATA (or extra data bit).
			txbuferr             : in STD_LOGIC;                     -- Transceiver connection: TX Buffer error (overflow or underflow).

			powerdown            : out STD_LOGIC;                    -- Transceiver connection: Powerdown the Transceiver
			txchardispmode       : out STD_LOGIC;                    -- Transceiver connection: Set running disparity for current byte.
			txchardispval        : out STD_LOGIC;                    -- Transceiver connection: Set running disparity value.
			txcharisk            : out STD_LOGIC;                    -- Transceiver connection: K character transmitted in TXDATA.
			txdata               : out STD_LOGIC_VECTOR(7 downto 0); -- Transceiver connection: Data for 8B/10B encoding.
			enablealign          : out STD_LOGIC;                    -- Allow the transceivers to serially realign to a comma character.

			-- GMII Interface
			-----------------
			gmii_txd             : in STD_LOGIC_VECTOR(7 downto 0);  -- Transmit data from client MAC.
			gmii_tx_en           : in STD_LOGIC;                     -- Transmit control signal from client MAC.
			gmii_tx_er           : in STD_LOGIC;                     -- Transmit control signal from client MAC.
			gmii_rxd             : out STD_LOGIC_VECTOR(7 downto 0); -- Received Data to client MAC.
			gmii_rx_dv           : out STD_LOGIC;                    -- Received control signal to client MAC.
			gmii_rx_er           : out STD_LOGIC;                    -- Received control signal to client MAC.
			gmii_isolate         : out STD_LOGIC;                    -- Tristate control to electrically isolate GMII.

			-- Management: MDIO Interface
			-----------------------------
			mdc                  : in    STD_LOGIC;                  -- Management Data Clock
			mdio_in              : in    STD_LOGIC;                  -- Management Data In
			mdio_out             : out   STD_LOGIC;                  -- Management Data Out
			mdio_tri             : out   STD_LOGIC;                  -- Management Data Tristate
			phyad                : in STD_LOGIC_VECTOR(4 downto 0);  -- Port address to for MDIO to recognise.
			configuration_vector : in STD_LOGIC_VECTOR(4 downto 0);  -- Alternative to MDIO interface.
			configuration_valid  : in STD_LOGIC;                     -- Validation signal for Config vector.

			an_interrupt         : out STD_LOGIC;                    -- Interrupt to processor to signal that Auto-Negotiation has completed
			an_adv_config_vector : in STD_LOGIC_VECTOR(15 downto 0); -- Alternate interface to program REG4 (AN ADV)
			an_adv_config_val    : in STD_LOGIC;                     -- Validation signal for AN ADV
			an_restart_config    : in STD_LOGIC;                     -- Alternate signal to modify AN restart bit in REG0
			link_timer_value     : in STD_LOGIC_VECTOR(8 downto 0);  -- Programmable Auto-Negotiation Link Timer Control

			-- General IO's
			---------------
			status_vector        : out STD_LOGIC_VECTOR(15 downto 0); -- Core status.
			reset                : in STD_LOGIC;                     -- Asynchronous reset for entire core.
			signal_detect        : in STD_LOGIC                      -- Input from PMD to indicate presence of optical input.
		);
	end component;

	-- ==========================================================================================================================================================
	-- Ethernet: MAC Control-Layer
	-- ==========================================================================================================================================================
	component eth_Wrapper_Virtex5 is
		generic (
			DEBUG											: BOOLEAN														:= FALSE;															--
			CLOCKIN_FREQ							: FREQ															:= 125 MHz;													-- 125 MHz
			ETHERNET_IPSTYLE					: T_IPSTYLE													:= IPSTYLE_SOFT;											--
			RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE				:= NET_ETH_RS_DATA_INTERFACE_GMII;		--
			PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE			:= NET_ETH_PHY_DATA_INTERFACE_GMII		--
		);
		port (
			-- clock interface
			RS_TX_Clock								: in	STD_LOGIC;
			RS_RX_Clock								: in	STD_LOGIC;
			Eth_TX_Clock							: in	STD_LOGIC;
			Eth_RX_Clock							: in	STD_LOGIC;
			TX_Clock									: in	STD_LOGIC;
			RX_Clock									: in	STD_LOGIC;

			-- reset interface
			Reset											: in	STD_LOGIC;

			-- Command-Status-Error interface

			-- MAC LocalLink interface
			TX_Valid									: in	STD_LOGIC;
			TX_Data										: in	T_SLV_8;
			TX_SOF										: in	STD_LOGIC;
			TX_EOF										: in	STD_LOGIC;
			TX_Ack										: out	STD_LOGIC;

			RX_Valid									: out	STD_LOGIC;
			RX_Data										: out	T_SLV_8;
			RX_SOF										: out	STD_LOGIC;
			RX_EOF										: out	STD_LOGIC;
			RX_Ack										: In	STD_LOGIC;

			-- PHY-SGMII interface
			PHY_Interface							:	INOUT	T_NET_ETH_PHY_INTERFACES
		);
	end component;

	component eth_Wrapper_Virtex6 is
		generic (
			DEBUG											: BOOLEAN														:= FALSE;															--
			CLOCKIN_FREQ							: FREQ															:= 125 MHz;													-- 125 MHz
			ETHERNET_IPSTYLE					: T_IPSTYLE													:= IPSTYLE_SOFT;											--
			RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE				:= NET_ETH_RS_DATA_INTERFACE_GMII;		--
			PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE			:= NET_ETH_PHY_DATA_INTERFACE_GMII		--
		);
		port (
			-- clock interface
			RS_TX_Clock								: in	STD_LOGIC;
			RS_RX_Clock								: in	STD_LOGIC;
			Eth_TX_Clock							: in	STD_LOGIC;
			Eth_RX_Clock							: in	STD_LOGIC;
			TX_Clock									: in	STD_LOGIC;
			RX_Clock									: in	STD_LOGIC;

			-- reset interface
			Reset											: in	STD_LOGIC;

			-- Command-Status-Error interface

			-- MAC LocalLink interface
			TX_Valid									: in	STD_LOGIC;
			TX_Data										: in	T_SLV_8;
			TX_SOF										: in	STD_LOGIC;
			TX_EOF										: in	STD_LOGIC;
			TX_Ack										: out	STD_LOGIC;

			RX_Valid									: out	STD_LOGIC;
			RX_Data										: out	T_SLV_8;
			RX_SOF										: out	STD_LOGIC;
			RX_EOF										: out	STD_LOGIC;
			RX_Ack										: In	STD_LOGIC;

			-- PHY-SGMII interface
			PHY_Interface							:	INOUT	T_NET_ETH_PHY_INTERFACES
		);
	end component;

	component eth_Wrapper_Series7 is
		generic (
			DEBUG											: BOOLEAN														:= FALSE;															--

			CLOCKIN_FREQ							: FREQ															:= 125 MHz;													-- 125 MHz
			ETHERNET_IPSTYLE					: T_IPSTYLE													:= IPSTYLE_SOFT;											--
			RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE				:= NET_ETH_RS_DATA_INTERFACE_GMII;		--
			PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE			:= NET_ETH_PHY_DATA_INTERFACE_GMII		--
		);
		port (
			-- clock interface
			RS_TX_Clock								: in	STD_LOGIC;
			RS_RX_Clock								: in	STD_LOGIC;
			Eth_TX_Clock							: in	STD_LOGIC;
			Eth_RX_Clock							: in	STD_LOGIC;
			TX_Clock									: in	STD_LOGIC;
			RX_Clock									: in	STD_LOGIC;

			-- reset interface
			Reset											: in	STD_LOGIC;

			-- Command-Status-Error interface

			-- MAC LocalLink interface
			TX_Valid									: in	STD_LOGIC;
			TX_Data										: in	T_SLV_8;
			TX_SOF										: in	STD_LOGIC;
			TX_EOF										: in	STD_LOGIC;
			TX_Ack										: out	STD_LOGIC;

			RX_Valid									: out	STD_LOGIC;
			RX_Data										: out	T_SLV_8;
			RX_SOF										: out	STD_LOGIC;
			RX_EOF										: out	STD_LOGIC;
			RX_Ack										: In	STD_LOGIC;

			-- PHY-SGMII interface
			PHY_Interface							:	INOUT	T_NET_ETH_PHY_INTERFACES
		);
	end component;

	-- ==========================================================================================================================================================
	-- Ethernet: MAC Data-Link-Layer
	-- ==========================================================================================================================================================
	component TEMAC_GMII_Virtex5 is
		port (
			-- Client Receiver Interface - EMAC0
			EMAC0CLIENTRXCLIENTCLKOUT       : out STD_LOGIC;
			CLIENTEMAC0RXCLIENTCLKIN        : in  STD_LOGIC;
			EMAC0CLIENTRXD                  : out STD_LOGIC_VECTOR(7 downto 0);
			EMAC0CLIENTRXDVLD               : out STD_LOGIC;
			EMAC0CLIENTRXDVLDMSW            : out STD_LOGIC;
			EMAC0CLIENTRXGOODFRAME          : out STD_LOGIC;
			EMAC0CLIENTRXBADFRAME           : out STD_LOGIC;
			EMAC0CLIENTRXFRAMEDROP          : out STD_LOGIC;
			EMAC0CLIENTRXSTATS              : out STD_LOGIC_VECTOR(6 downto 0);
			EMAC0CLIENTRXSTATSVLD           : out STD_LOGIC;
			EMAC0CLIENTRXSTATSBYTEVLD       : out STD_LOGIC;

			-- Client Transmitter Interface - EMAC0
			EMAC0CLIENTTXCLIENTCLKOUT       : out STD_LOGIC;
			CLIENTEMAC0TXCLIENTCLKIN        : in  STD_LOGIC;
			CLIENTEMAC0TXD                  : in  STD_LOGIC_VECTOR(7 downto 0);
			CLIENTEMAC0TXDVLD               : in  STD_LOGIC;
			CLIENTEMAC0TXDVLDMSW            : in  STD_LOGIC;
			EMAC0CLIENTTXACK                : out STD_LOGIC;
			CLIENTEMAC0TXFIRSTBYTE          : in  STD_LOGIC;
			CLIENTEMAC0TXUNDERRUN           : in  STD_LOGIC;
			EMAC0CLIENTTXCOLLISION          : out STD_LOGIC;
			EMAC0CLIENTTXRETRANSMIT         : out STD_LOGIC;
			CLIENTEMAC0TXIFGDELAY           : in  STD_LOGIC_VECTOR(7 downto 0);
			EMAC0CLIENTTXSTATS              : out STD_LOGIC;
			EMAC0CLIENTTXSTATSVLD           : out STD_LOGIC;
			EMAC0CLIENTTXSTATSBYTEVLD       : out STD_LOGIC;

			-- MAC Control Interface - EMAC0
			CLIENTEMAC0PAUSEREQ             : in  STD_LOGIC;
			CLIENTEMAC0PAUSEVAL             : in  STD_LOGIC_VECTOR(15 downto 0);

			-- Clock Signal - EMAC0
			GTX_CLK_0                       : in  STD_LOGIC;
			PHYEMAC0TXGMIIMIICLKIN          : in  STD_LOGIC;
			EMAC0PHYTXGMIIMIICLKOUT         : out STD_LOGIC;

			-- GMII Interface - EMAC0
			GMII_TXD_0                      : out STD_LOGIC_VECTOR(7 downto 0);
			GMII_TX_EN_0                    : out STD_LOGIC;
			GMII_TX_ER_0                    : out STD_LOGIC;
			GMII_RXD_0                      : in  STD_LOGIC_VECTOR(7 downto 0);
			GMII_RX_DV_0                    : in  STD_LOGIC;
			GMII_RX_ER_0                    : in  STD_LOGIC;
			GMII_RX_CLK_0                   : in  STD_LOGIC;

			DCM_LOCKED_0                    : in  STD_LOGIC;

			-- Asynchronous Reset
			RESET                           : in  STD_LOGIC
		);
	end component;

	-- ==========================================================================================================================================================
	-- eth_Wrapper: configuration data structures
	-- ==========================================================================================================================================================

	-- ==========================================================================================================================================================
	-- local network: sequence and flow control protocol (SFC)
	-- ==========================================================================================================================================================

	-- ==========================================================================================================================================================
	-- internet layer: Internet Protocol Version 4 (IPv4)
	-- ==========================================================================================================================================================

	-- ==========================================================================================================================================================
	-- internet layer: Address Resolution Protocol (ARP)
	-- ==========================================================================================================================================================

end package;
