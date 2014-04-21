LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;

ENTITY Eth_Wrapper_Virtex7 IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ							: REAL															:= 125.0;												-- 125 MHz
		ETHERNET_MAC_IP_TYPE					: T_IP_TYPE													:= SOFT_IP;											-- 
		ETHERNET_RS_INTERFACE_TYPE		: T_ETHERNET_RS_INTERFACE_TYPES			:= ETHERNET_RS_INTERFACE_GMII;	-- 
		ETHERNET_PHY_INTERFACE_TYPE		: T_ETHERNET_PHY_INTERFACE_TYPES		:= ETHERNET_PHY_INTERFACE_GMII	-- 
	);
	PORT (
		-- clock interface
		RS_TX_Clock								: IN	STD_LOGIC;
		RS_RX_Clock								: IN	STD_LOGIC;
		MAC_TX_Clock							: IN	STD_LOGIC;
		MAC_RX_Clock							: IN	STD_LOGIC;
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
		PHY_Interface							:	INOUT	T_ETHERNET_PHY_INTERFACES
	);
END ENTITY;

-- Structure
-- ============================================================================================================================================================
-- 	genHardIP
--		ASSERT FAILURE
--	genSoftIP
--		o	GEMAC					- Gigabit Ethernet MAC (GEMAC) SoftCore with GMII interface
--		genPHY_GMII
--			o	GMII				- GMII-GMII adapter; FlipFlop and IDelay instances
--		genPHY_SGMII
--			o	SGMII				- GMII-SGMII adapter; transceiver

-- +----------+---------------+---------------+-------------------------------------------+
-- |	IP-Type	|	RS-Interface	|	PHY-Interface	|	status / comment													|
-- +----------+---------------+---------------+-------------------------------------------+
-- |	HardIP	|			***				|			***				|	ASSERT FAILURE														|
-- |----------+---------------+---------------+-------------------------------------------+
-- |	SoftIP	|			GMII			|			GMII			|	OPEN	not yet tested; no board available	|
-- |		"			|			GMII			|			SGMII			|				under development										|
-- +----------+---------------+---------------+-------------------------------------------+

ARCHITECTURE rtl OF Eth_Wrapper_Virtex7 IS
	ATTRIBUTE KEEP									: BOOLEAN;

	SIGNAL Reset_a							: STD_LOGIC;		-- FIXME: 

	SIGNAL TX_Reset									: STD_LOGIC;		-- FIXME: 
	SIGNAL RX_Reset									: STD_LOGIC;		-- FIXME: 

BEGIN
--	
--	-- XXX: review reset-tree and clock distribution
--	Reset_a		<= Reset;
--	
--	-- ==========================================================================================================================================================
--	-- Xilinx Virtex 5 Tri-Mode Ethernet MAC (TEMAC) HardIP
--	-- ==========================================================================================================================================================
--	genHardIP	: IF (ETHERNET_MAC_IP_TYPE = HARD_IP) GENERATE
--	BEGIN
--		ASSERT FALSE REPORT "HardIP is not supported on Series 7 devices!" SEVERITY FAILURE;
--	END GENERATE;		-- MAC_IP: HARD_IP
--	
--	-- ==========================================================================================================================================================
--	-- Gigabit Ethernet MAC (GEMAC) - SoftIP
--	-- ==========================================================================================================================================================
--	genSoftIP	: IF (ETHERNET_MAC_IP_TYPE = SOFT_IP) GENERATE
--		SIGNAL GEMAC_MDIO							: T_ETHERNET_PHY_INTERFACE_MDIO;
--	BEGIN
--		-- ========================================================================================================================================================
--		-- reconcilation sublayer (RS) interface	: GMII
--		-- ========================================================================================================================================================
--		genRS_GMII	: IF (ETHERNET_RS_INTERFACE_TYPE = ETHERNET_RS_INTERFACE_GMII) GENERATE
--			-- RS-GMII interface
--			SIGNAL RS_TX_Valid					: STD_LOGIC;
--			SIGNAL RS_TX_Data						: T_SLV_8;
--			SIGNAL RS_TX_Error					: STD_LOGIC;
--				
--			SIGNAL RS_RX_Valid					: STD_LOGIC;
--			SIGNAL RS_RX_Data						: T_SLV_8;
--			SIGNAL RS_RX_Error					: STD_LOGIC;
--		BEGIN
--			GEMAC	: ENTITY L_Ethernet.Ethernet_GEMAC_GMII
--				GENERIC MAP (
--					DEBUG									=> TRUE,
--					CLOCK_IN_FREQ_MHZ								=> CLOCK_IN_FREQ_MHZ,		-- 
--				
--					TX_FIFO_DEPTH										=> 2048,								-- 2 kiB TX Buffer
--					TX_INSERT_CROSSCLOCK_FIFO				=> TRUE,								-- TODO: 
--					TX_SUPPORT_JUMBO_FRAMES					=> FALSE,								-- TODO: 
--					TX_DISABLE_UNDERRUN_PROTECTION	=> FALSE,								-- TODO: 							true: no protection; false: store complete frame in buffer befor transmitting it
--					
--					RX_FIFO_DEPTH										=> 4096,								-- 4 kiB TX Buffer
--					RX_INSERT_CROSSCLOCK_FIFO				=> TRUE,								-- TODO: 
--					RX_SUPPORT_JUMBO_FRAMES					=> FALSE								-- TODO: 
--				)
--				PORT MAP (
--					-- clock interface
--					TX_Clock									=> TX_Clock,
--					RX_Clock									=> RX_Clock,
--					MAC_TX_Clock							=> MAC_TX_Clock,
--					MAC_RX_Clock							=> MAC_RX_Clock,
--					RS_TX_Clock								=> RS_TX_Clock,
--					RS_RX_Clock								=> RS_RX_Clock,
--					
--					TX_Reset									=> Reset,
--					RX_Reset									=> Reset,
--					RS_TX_Reset								=> Reset,
--					RS_RX_Reset								=> Reset,
--
--					TX_BufferUnderrun					=> OPEN,
--					RX_FrameDrop							=> OPEN,
--					RX_FrameCorrupt						=> OPEN,
--					
--					-- MAC LocalLink interface
--					TX_Valid									=> TX_Valid,
--					TX_Data										=> TX_Data,
--					TX_SOF										=> TX_SOF,
--					TX_EOF										=> TX_EOF,
--					TX_Ready									=> TX_Ready,
--
--					RX_Valid									=> RX_Valid,
--					RX_Data										=> RX_Data,
--					RX_SOF										=> RX_SOF,
--					RX_EOF										=> RX_EOF,
--					RX_Ready									=> RX_Ready,
--					
--					-- RS-GMII interface
--					RS_TX_Valid								=> RS_TX_Valid,
--					RS_TX_Data								=> RS_TX_Data,
--					RS_TX_Error								=> RS_TX_Error,
--					
--					RS_RX_Valid								=> RS_RX_Valid,
--					RS_RX_Data								=> RS_RX_Data,
--					RS_RX_Error								=> RS_RX_Error,
--					
--					MDIO											=> GEMAC_MDIO
--				);
--		
--			-- ========================================================================================================================================================
--			-- FPGA-PHY inferface: MII
--			-- ========================================================================================================================================================
--			genPHY_MII	: IF (ETHERNET_PHY_INTERFACE_TYPE = ETHERNET_PHY_INTERFACE_MII) GENERATE
--				ASSERT FALSE REPORT "Physical interface MII is not supported!" SEVERITY FAILURE;
--			END GENERATE;
--			-- ========================================================================================================================================================
--			-- FPGA-PHY inferface: GMII
--			-- ========================================================================================================================================================
--			genPHY_GMII	: IF (ETHERNET_PHY_INTERFACE_TYPE = ETHERNET_PHY_INTERFACE_GMII) GENERATE
--			
--			BEGIN
--				GMII	: ENTITY L_Ethernet.Ethernet_RSLayer_GMII_GMII_Virtex7
--					PORT MAP (
--						RS_TX_Clock								=> RS_TX_Clock,
--						RS_RX_Clock								=> RS_RX_Clock,						
--						
--						Reset_async								=> Reset_a,																		-- @async: 
--						
--						-- RS-GMII interface
--						RS_TX_Valid								=> RS_TX_Valid,
--						RS_TX_Data								=> RS_TX_Data,
--						RS_TX_Error								=> RS_TX_Error,
--						
--						RS_RX_Valid								=> RS_RX_Valid,
--						RS_RX_Data								=> RS_RX_Data,
--						RS_RX_Error								=> RS_RX_Error,
--						
--						-- PHY-GMII interface
--						PHY_Interface							=> PHY_Interface.GMII
--					);
--				
--				-- FIXME: add MDIO assignments
--			END GENERATE;		-- PHY_INTERFACE: GMII
--		
--			-- ========================================================================================================================================================
--			-- FPGA-PHY inferface: SGMII
--			-- ========================================================================================================================================================
--			genPHY_SGMII	: IF (ETHERNET_PHY_INTERFACE_TYPE = ETHERNET_PHY_INTERFACE_SGMII) GENERATE
--				SIGNAL SGMII_MDIO						: T_ETHERNET_PHY_INTERFACE_MDIO;
--			BEGIN
--				SGMII	: ENTITY L_Ethernet.Ethernet_RSLayer_GMII_SGMII_Virtex7
--					GENERIC MAP (
--						CLOCK_IN_FREQ_MHZ				=> CLOCK_IN_FREQ_MHZ					-- 125 MHz
--					)
--					PORT MAP (
--						Clock										=> RS_TX_Clock,
--						Reset										=> Reset_a,
--						
--						-- GEMAC-GMII interface
--						RS_TX_Clock							=> RS_TX_Clock,
--						RS_TX_Valid							=> RS_TX_Valid,
--						RS_TX_Data							=> RS_TX_Data,
--						RS_TX_Error							=> RS_TX_Error,
--						
--						RS_RX_Clock							=> RS_RX_Clock,
--						RS_RX_Valid							=> RS_RX_Valid,
--						RS_RX_Data							=> RS_RX_Data,
--						RS_RX_Error							=> RS_RX_Error,
--						
--						-- PHY-SGMII interface
--						PHY_Interface						=> PHY_Interface.SGMII,
--						PHY_Management					=> SGMII_MDIO
--					);
--
--				-- Management Data Interface multiplexer (on-chip tristate logic)
--				GEMAC_MDIO.Clock_i					<= PHY_Interface.MDIO.Clock_i;
--				GEMAC_MDIO.Data_i						<= ite((SGMII_MDIO.Data_t = '0'), SGMII_MDIO.Data_o, PHY_Interface.MDIO.Data_i);
--				
--				SGMII_MDIO.Clock_i					<= GEMAC_MDIO.Clock_o;
--				SGMII_MDIO.Data_i						<= GEMAC_MDIO.Data_o;
--
--				PHY_Interface.MDIO.Clock_o	<= GEMAC_MDIO.Clock_o;
--				PHY_Interface.MDIO.Clock_t	<= GEMAC_MDIO.Clock_t;
--				PHY_Interface.MDIO.Data_o		<= GEMAC_MDIO.Data_o;
--				PHY_Interface.MDIO.Data_t		<= GEMAC_MDIO.Data_t;
--				
--			END GENERATE;		-- PHY_INTERFACE: SGMII
--		END GENERATE;		-- RS_INTERFACE: GMII
--		
--		-- ========================================================================================================================================================
--		-- reconcilation sublayer (RS) interface	: TRANSCEIVER
--		-- ========================================================================================================================================================
--		genRS_TRANS	: IF (ETHERNET_RS_INTERFACE_TYPE = ETHERNET_RS_INTERFACE_TRANSCEIVER) GENERATE
--		BEGIN
--			ASSERT FALSE REPORT "Reconcilation SubLayer interface TRANS is not supported!" SEVERITY FAILURE;
--		END GENERATE;		-- RS_INTERFACE: TRANSCEIVER
--	END GENERATE;		-- MAC_IP: SOFT_IP
END;
