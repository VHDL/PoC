LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;


PACKAGE EthComp IS
	-- ==========================================================================================================================================================
	-- Ethernet: reconcilation sublayer (RS)
	-- ==========================================================================================================================================================
	COMPONENT Eth_RSLayer_GMII_GMII_Virtex5 IS
		PORT (
			Reset_async								: IN	STD_LOGIC;																	-- @async: 
			
			-- RS-GMII interface
			RS_TX_Clock								: IN	STD_LOGIC;
			RS_TX_Valid								: IN	STD_LOGIC;
			RS_TX_Data								: IN	T_SLV_8;
			RS_TX_Error								: IN	STD_LOGIC;
			
			RS_RX_Clock								: IN	STD_LOGIC;
			RS_RX_Valid								: OUT	STD_LOGIC;
			RS_RX_Data								: OUT	T_SLV_8;
			RS_RX_Error								: OUT	STD_LOGIC;

			-- PHY-GMII interface		
			PHY_Interface							: INOUT	T_NET_ETH_PHY_INTERFACE_GMII
		);
	END COMPONENT;

	COMPONENT Eth_RSLayer_GMII_GMII_Virtex6 IS
		PORT (
			Reset_async								: IN	STD_LOGIC;																	-- @async: 
			
			-- RS-GMII interface
			RS_TX_Clock								: IN	STD_LOGIC;
			RS_TX_Valid								: IN	STD_LOGIC;
			RS_TX_Data								: IN	T_SLV_8;
			RS_TX_Error								: IN	STD_LOGIC;
			
			RS_RX_Clock								: IN	STD_LOGIC;
			RS_RX_Valid								: OUT	STD_LOGIC;
			RS_RX_Data								: OUT	T_SLV_8;
			RS_RX_Error								: OUT	STD_LOGIC;

			-- PHY-GMII interface		
			PHY_Interface							: INOUT	T_NET_ETH_PHY_INTERFACE_GMII
		);
	END COMPONENT;

	COMPONENT Eth_RSLayer_GMII_GMII_Virtex7 IS
		PORT (
			Reset_async								: IN	STD_LOGIC;																	-- @async: 
			
			-- RS-GMII interface
			RS_TX_Clock								: IN	STD_LOGIC;
			RS_TX_Valid								: IN	STD_LOGIC;
			RS_TX_Data								: IN	T_SLV_8;
			RS_TX_Error								: IN	STD_LOGIC;
			
			RS_RX_Clock								: IN	STD_LOGIC;
			RS_RX_Valid								: OUT	STD_LOGIC;
			RS_RX_Data								: OUT	T_SLV_8;
			RS_RX_Error								: OUT	STD_LOGIC;

			-- PHY-GMII interface		
			PHY_Interface							: INOUT	T_NET_ETH_PHY_INTERFACE_GMII
		);
	END COMPONENT;

	COMPONENT Eth_RSLayer_GMII_SGMII_Virtex5 IS
		GENERIC (
			CLOCK_IN_FREQ_MHZ					: REAL													:= 125.0					-- 125 MHz
		);
		PORT (
			Clock											: IN	STD_LOGIC;
			Reset											: IN	STD_LOGIC;
			
			-- GEMAC-GMII interface
			RS_TX_Clock								: IN	STD_LOGIC;
			RS_TX_Valid								: IN	STD_LOGIC;
			RS_TX_Data								: IN	T_SLV_8;
			RS_TX_Error								: IN	STD_LOGIC;
			
			RS_RX_Clock								: IN	STD_LOGIC;
			RS_RX_Valid								: OUT	STD_LOGIC;
			RS_RX_Data								: OUT	T_SLV_8;
			RS_RX_Error								: OUT	STD_LOGIC;
			
			-- PHY-SGMII interface		
			PHY_Interface							: INOUT	T_NET_ETH_PHY_INTERFACE_SGMII
		);
	END COMPONENT;

	COMPONENT Eth_RSLayer_GMII_SGMII_Virtex6 IS
		GENERIC (
			CLOCK_IN_FREQ_MHZ					: REAL													:= 125.0					-- 125 MHz
		);
		PORT (
			Clock											: IN	STD_LOGIC;
			Reset											: IN	STD_LOGIC;
			
			-- GEMAC-GMII interface
			RS_TX_Clock								: IN	STD_LOGIC;
			RS_TX_Valid								: IN	STD_LOGIC;
			RS_TX_Data								: IN	T_SLV_8;
			RS_TX_Error								: IN	STD_LOGIC;
			
			RS_RX_Clock								: IN	STD_LOGIC;
			RS_RX_Valid								: OUT	STD_LOGIC;
			RS_RX_Data								: OUT	T_SLV_8;
			RS_RX_Error								: OUT	STD_LOGIC;
			
			-- PHY-SGMII interface		
			PHY_Interface							: INOUT	T_NET_ETH_PHY_INTERFACE_SGMII
		);
	END COMPONENT;

	COMPONENT Eth_RSLayer_GMII_SGMII_Virtex7 IS
		GENERIC (
			CLOCK_IN_FREQ_MHZ					: REAL													:= 125.0					-- 125 MHz
		);
		PORT (
			Clock											: IN	STD_LOGIC;
			Reset											: IN	STD_LOGIC;
			
			-- GEMAC-GMII interface
			RS_TX_Clock								: IN	STD_LOGIC;
			RS_TX_Valid								: IN	STD_LOGIC;
			RS_TX_Data								: IN	T_SLV_8;
			RS_TX_Error								: IN	STD_LOGIC;
			
			RS_RX_Clock								: IN	STD_LOGIC;
			RS_RX_Valid								: OUT	STD_LOGIC;
			RS_RX_Data								: OUT	T_SLV_8;
			RS_RX_Error								: OUT	STD_LOGIC;
			
			-- PHY-SGMII interface		
			PHY_Interface							: INOUT	T_NET_ETH_PHY_INTERFACE_SGMII
		);
	END COMPONENT;

 -----------------------------------------------------------------------------
   -- Component Declaration for the 1000BASE-X PCS/PMA sublayer core.
   -----------------------------------------------------------------------------
	COMPONENT Eth_PCS_IPCore_Virtex7
		PORT (
			-- Core <=> Transceiver Interface
			------------------------------
			mgt_rx_reset         : out std_logic;                    -- Transceiver connection: reset for the receiver half of the Transceiver
			mgt_tx_reset         : out std_logic;                    -- Transceiver connection: reset for the transmitter half of the Transceiver
			userclk              : in std_logic;                     -- Routed to TXUSERCLK and RXUSERCLK of Transceiver.
			userclk2             : in std_logic;                     -- Routed to TXUSERCLK2 and RXUSERCLK2 of Transceiver.
			dcm_locked           : in std_logic;                     -- LOCKED signal from DCM.

			rxbufstatus          : in std_logic_vector (1 downto 0); -- Transceiver connection: Elastic Buffer Status.
			rxchariscomma        : in std_logic;                     -- Transceiver connection: Comma detected in RXDATA.
			rxcharisk            : in std_logic;                     -- Transceiver connection: K character received (or extra data bit) in RXDATA.
			rxclkcorcnt          : in std_logic_vector(2 downto 0);  -- Transceiver connection: Indicates clock correction.
			rxdata               : in std_logic_vector(7 downto 0);  -- Transceiver connection: Data after 8B/10B decoding.
			rxdisperr            : in std_logic;                     -- Transceiver connection: Disparity-error in RXDATA.
			rxnotintable         : in std_logic;                     -- Transceiver connection: Non-existent 8B/10 code indicated.
			rxrundisp            : in std_logic;                     -- Transceiver connection: Running Disparity of RXDATA (or extra data bit).
			txbuferr             : in std_logic;                     -- Transceiver connection: TX Buffer error (overflow or underflow).

			powerdown            : out std_logic;                    -- Transceiver connection: Powerdown the Transceiver
			txchardispmode       : out std_logic;                    -- Transceiver connection: Set running disparity for current byte.
			txchardispval        : out std_logic;                    -- Transceiver connection: Set running disparity value.
			txcharisk            : out std_logic;                    -- Transceiver connection: K character transmitted in TXDATA.
			txdata               : out std_logic_vector(7 downto 0); -- Transceiver connection: Data for 8B/10B encoding.
			enablealign          : out std_logic;                    -- Allow the transceivers to serially realign to a comma character.

			-- GMII Interface
			-----------------
			gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
			gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
			gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
			gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
			gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
			gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
			gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.

			-- Management: MDIO Interface
			-----------------------------
			mdc                  : in    std_logic;                  -- Management Data Clock
			mdio_in              : in    std_logic;                  -- Management Data In
			mdio_out             : out   std_logic;                  -- Management Data Out
			mdio_tri             : out   std_logic;                  -- Management Data Tristate
			phyad                : in std_logic_vector(4 downto 0);  -- Port address to for MDIO to recognise.
			configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
			configuration_valid  : in std_logic;                     -- Validation signal for Config vector.

			an_interrupt         : out std_logic;                    -- Interrupt to processor to signal that Auto-Negotiation has completed
			an_adv_config_vector : in std_logic_vector(15 downto 0); -- Alternate interface to program REG4 (AN ADV)
			an_adv_config_val    : in std_logic;                     -- Validation signal for AN ADV
			an_restart_config    : in std_logic;                     -- Alternate signal to modify AN restart bit in REG0
			link_timer_value     : in std_logic_vector(8 downto 0);  -- Programmable Auto-Negotiation Link Timer Control

			-- General IO's
			---------------
			status_vector        : out std_logic_vector(15 downto 0); -- Core status.
			reset                : in std_logic;                     -- Asynchronous reset for entire core.
			signal_detect        : in std_logic                      -- Input from PMD to indicate presence of optical input.
		);
	END COMPONENT;

	-- ==========================================================================================================================================================
	-- Ethernet: MAC Control-Layer
	-- ==========================================================================================================================================================
	COMPONENT Eth_Wrapper_Virtex5 IS
		GENERIC (
			CHIPSCOPE_KEEP						: BOOLEAN														:= FALSE;															-- 
			CLOCKIN_FREQ_MHZ					: REAL															:= 125.0;															-- 125 MHz
			ETHERNET_IPSTYLE					: T_IPSTYLE													:= IPSTYLE_SOFT;											-- 
			RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE				:= NET_ETH_RS_DATA_INTERFACE_GMII;		-- 
			PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE			:= NET_ETH_PHY_DATA_INTERFACE_GMII		-- 
		);
		PORT (
			-- clock interface
			RS_TX_Clock								: IN	STD_LOGIC;
			RS_RX_Clock								: IN	STD_LOGIC;
			Eth_TX_Clock							: IN	STD_LOGIC;
			Eth_RX_Clock							: IN	STD_LOGIC;
			TX_Clock									: IN	STD_LOGIC;
			RX_Clock									: IN	STD_LOGIC;

			-- reset interface
			Reset											: IN	STD_LOGIC;
			
			-- Command-Status-Error interface
			
			-- MAC LocalLink interface
			TX_Valid									: IN	STD_LOGIC;
			TX_Data										: IN	T_SLV_8;
			TX_SOF										: IN	STD_LOGIC;
			TX_EOF										: IN	STD_LOGIC;
			TX_Ready									: OUT	STD_LOGIC;

			RX_Valid									: OUT	STD_LOGIC;
			RX_Data										: OUT	T_SLV_8;
			RX_SOF										: OUT	STD_LOGIC;
			RX_EOF										: OUT	STD_LOGIC;
			RX_Ready									: In	STD_LOGIC;
			
			-- PHY-SGMII interface
			PHY_Interface							:	INOUT	T_NET_ETH_PHY_INTERFACES
		);
	END COMPONENT;
	
	COMPONENT Eth_Wrapper_Virtex6 IS
		GENERIC (
			CHIPSCOPE_KEEP						: BOOLEAN														:= FALSE;															-- 
			CLOCKIN_FREQ_MHZ					: REAL															:= 125.0;															-- 125 MHz
			ETHERNET_IPSTYLE					: T_IPSTYLE													:= IPSTYLE_SOFT;											-- 
			RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE				:= NET_ETH_RS_DATA_INTERFACE_GMII;		-- 
			PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE			:= NET_ETH_PHY_DATA_INTERFACE_GMII		-- 
		);
		PORT (
			-- clock interface
			RS_TX_Clock								: IN	STD_LOGIC;
			RS_RX_Clock								: IN	STD_LOGIC;
			Eth_TX_Clock							: IN	STD_LOGIC;
			Eth_RX_Clock							: IN	STD_LOGIC;
			TX_Clock									: IN	STD_LOGIC;
			RX_Clock									: IN	STD_LOGIC;
			
			-- reset interface
			Reset											: IN	STD_LOGIC;
			
			-- Command-Status-Error interface
			
			-- MAC LocalLink interface
			TX_Valid									: IN	STD_LOGIC;
			TX_Data										: IN	T_SLV_8;
			TX_SOF										: IN	STD_LOGIC;
			TX_EOF										: IN	STD_LOGIC;
			TX_Ready									: OUT	STD_LOGIC;

			RX_Valid									: OUT	STD_LOGIC;
			RX_Data										: OUT	T_SLV_8;
			RX_SOF										: OUT	STD_LOGIC;
			RX_EOF										: OUT	STD_LOGIC;
			RX_Ready									: In	STD_LOGIC;
			
			-- PHY-SGMII interface
			PHY_Interface							:	INOUT	T_NET_ETH_PHY_INTERFACES
		);
	END COMPONENT;
	
	COMPONENT Eth_Wrapper_Virtex7 IS
		GENERIC (
			CHIPSCOPE_KEEP						: BOOLEAN														:= FALSE;															-- 
			CLOCKIN_FREQ_MHZ					: REAL															:= 125.0;															-- 125 MHz
			ETHERNET_IPSTYLE					: T_IPSTYLE													:= IPSTYLE_SOFT;											-- 
			RS_DATA_INTERFACE					: T_NET_ETH_RS_DATA_INTERFACE				:= NET_ETH_RS_DATA_INTERFACE_GMII;		-- 
			PHY_DATA_INTERFACE				: T_NET_ETH_PHY_DATA_INTERFACE			:= NET_ETH_PHY_DATA_INTERFACE_GMII		-- 
		);
		PORT (
			-- clock interface
			RS_TX_Clock								: IN	STD_LOGIC;
			RS_RX_Clock								: IN	STD_LOGIC;
			Eth_TX_Clock							: IN	STD_LOGIC;
			Eth_RX_Clock							: IN	STD_LOGIC;
			TX_Clock									: IN	STD_LOGIC;
			RX_Clock									: IN	STD_LOGIC;
			
			-- reset interface
			Reset											: IN	STD_LOGIC;
			
			-- Command-Status-Error interface
			
			-- MAC LocalLink interface
			TX_Valid									: IN	STD_LOGIC;
			TX_Data										: IN	T_SLV_8;
			TX_SOF										: IN	STD_LOGIC;
			TX_EOF										: IN	STD_LOGIC;
			TX_Ready									: OUT	STD_LOGIC;

			RX_Valid									: OUT	STD_LOGIC;
			RX_Data										: OUT	T_SLV_8;
			RX_SOF										: OUT	STD_LOGIC;
			RX_EOF										: OUT	STD_LOGIC;
			RX_Ready									: In	STD_LOGIC;
			
			-- PHY-SGMII interface
			PHY_Interface							:	INOUT	T_NET_ETH_PHY_INTERFACES
		);
	END COMPONENT;
	
	
	-- Management Data I/O
	-- ==========================================================================================================================================================
	COMPONENT Eth_MDIOController IS
		GENERIC (
			CHIPSCOPE_KEEP						: BOOLEAN												:= TRUE;
			CLOCK_IN_FREQ_MHZ					: REAL													:= 125.0					-- 125 MHz
		);
		PORT (
			Clock											: IN	STD_LOGIC;
			Reset											: IN	STD_LOGIC;
			
			-- MDIO interface
			Command										: IN	T_NET_ETH_MDIOCONTROLLER_COMMAND;
			Status										: OUT	T_NET_ETH_MDIOCONTROLLER_STATUS;

			Physical_Address					: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
			Register_Address					: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
			Register_DataIn						: IN	T_SLV_16;
			Register_DataOut					: OUT	T_SLV_16;
			
			-- tri-state interface
			MD_Clock_i								: IN	STD_LOGIC;			-- IEEE 802.3: MDC		-> Managament Data Clock I
			MD_Clock_o								: OUT	STD_LOGIC;			-- IEEE 802.3: MDC		-> Managament Data Clock O
			MD_Clock_t								: OUT	STD_LOGIC;			-- IEEE 802.3: MDC		-> Managament Data Clock tri-state
			MD_Data_i									: IN	STD_LOGIC;			-- IEEE 802.3: MDIO		-> Managament Data I
			MD_Data_o									: OUT	STD_LOGIC;			-- IEEE 802.3: MDIO		-> Managament Data O
			MD_Data_t									: OUT	STD_LOGIC				-- IEEE 802.3: MDIO		-> Managament Data tri-state
		);
	END COMPONENT;
	
	COMPONENT MDIO_SFF8431_Adapter IS
		GENERIC (
			CHIPSCOPE_KEEP								: BOOLEAN												:= TRUE
		);
		PORT (
			Clock													: IN	STD_LOGIC;
			Reset													: IN	STD_LOGIC;
			
			-- MDIO interface
			Command												: IN	T_NET_ETH_MDIOCONTROLLER_COMMAND;
			Status												: OUT	T_NET_ETH_MDIOCONTROLLER_STATUS;
			
			Physical_Address							: IN	STD_LOGIC_VECTOR(6 DOWNTO 0);
			Register_Address							: IN	STD_LOGIC_VECTOR(4 DOWNTO 0);
			Register_DataIn								: IN	T_SLV_16;
			Register_DataOut							: OUT	T_SLV_16;
			
			-- IICController_SFF8431 interface
			SFF8431_Command								: OUT	T_IO_IIC_SFF8431_COMMAND;
			SFF8431_Status								: IN	T_IO_IIC_SFF8431_STATUS;
			
			SFF8431_PhysicalAddress				: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
			SFF8431_RegisterAddress				: OUT	T_SLV_8;
			
			SFF8431_LastByte							: OUT	STD_LOGIC;
			SFF8431_DataIn								: IN	T_SLV_8;
			SFF8431_Valid									: IN	STD_LOGIC;
				
			SFF8431_MoreBytes							: OUT	STD_LOGIC;
			SFF8431_DataOut								: OUT	T_SLV_8;
			SFF8431_NextByte							: IN	STD_LOGIC
		);
	END COMPONENT;

	-- ==========================================================================================================================================================
	-- Ethernet: MAC Data-Link-Layer
	-- ==========================================================================================================================================================
	COMPONENT TEMAC_GMII_Virtex5 IS
		PORT (
			-- Client Receiver Interface - EMAC0
			EMAC0CLIENTRXCLIENTCLKOUT       : out std_logic;
			CLIENTEMAC0RXCLIENTCLKIN        : in  std_logic;
			EMAC0CLIENTRXD                  : out std_logic_vector(7 downto 0);
			EMAC0CLIENTRXDVLD               : out std_logic;
			EMAC0CLIENTRXDVLDMSW            : out std_logic;
			EMAC0CLIENTRXGOODFRAME          : out std_logic;
			EMAC0CLIENTRXBADFRAME           : out std_logic;
			EMAC0CLIENTRXFRAMEDROP          : out std_logic;
			EMAC0CLIENTRXSTATS              : out std_logic_vector(6 downto 0);
			EMAC0CLIENTRXSTATSVLD           : out std_logic;
			EMAC0CLIENTRXSTATSBYTEVLD       : out std_logic;

			-- Client Transmitter Interface - EMAC0
			EMAC0CLIENTTXCLIENTCLKOUT       : out std_logic;
			CLIENTEMAC0TXCLIENTCLKIN        : in  std_logic;
			CLIENTEMAC0TXD                  : in  std_logic_vector(7 downto 0);
			CLIENTEMAC0TXDVLD               : in  std_logic;
			CLIENTEMAC0TXDVLDMSW            : in  std_logic;
			EMAC0CLIENTTXACK                : out std_logic;
			CLIENTEMAC0TXFIRSTBYTE          : in  std_logic;
			CLIENTEMAC0TXUNDERRUN           : in  std_logic;
			EMAC0CLIENTTXCOLLISION          : out std_logic;
			EMAC0CLIENTTXRETRANSMIT         : out std_logic;
			CLIENTEMAC0TXIFGDELAY           : in  std_logic_vector(7 downto 0);
			EMAC0CLIENTTXSTATS              : out std_logic;
			EMAC0CLIENTTXSTATSVLD           : out std_logic;
			EMAC0CLIENTTXSTATSBYTEVLD       : out std_logic;

			-- MAC Control Interface - EMAC0
			CLIENTEMAC0PAUSEREQ             : in  std_logic;
			CLIENTEMAC0PAUSEVAL             : in  std_logic_vector(15 downto 0);

			-- Clock Signal - EMAC0
			GTX_CLK_0                       : in  std_logic;
			PHYEMAC0TXGMIIMIICLKIN          : in  std_logic;
			EMAC0PHYTXGMIIMIICLKOUT         : out std_logic;

			-- GMII Interface - EMAC0
			GMII_TXD_0                      : out std_logic_vector(7 downto 0);
			GMII_TX_EN_0                    : out std_logic;
			GMII_TX_ER_0                    : out std_logic;
			GMII_RXD_0                      : in  std_logic_vector(7 downto 0);
			GMII_RX_DV_0                    : in  std_logic;
			GMII_RX_ER_0                    : in  std_logic;
			GMII_RX_CLK_0                   : in  std_logic;

			DCM_LOCKED_0                    : in  std_logic;

			-- Asynchronous Reset
			RESET                           : in  std_logic
		);
	END COMPONENT;

	-- ==========================================================================================================================================================
	-- Eth_Wrapper: configuration data structures
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
	
END;

PACKAGE BODY EthComp IS
	
END PACKAGE BODY;