LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;


ENTITY Eth_Wrapper_Virtex6 IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ							: REAL															:= 125.0;												-- 125 MHz
		ETHERNET_MAC_IP_TYPE					: T_IP_TYPE													:= SOFT_IP;											-- 
		ETHERNET_RS_INTERFACE_TYPE		: T_ETHERNET_RS_INTERFACE_TYPES			:= ETHERNET_RS_INTERFACE_GMII;	-- 
		ETHERNET_PHY_INTERFACE_TYPE		: T_ETHERNET_PHY_INTERFACE_TYPES		:= ETHERNET_PHY_INTERFACE_GMII	-- 
	);
	PORT (
--		Clock											: IN	STD_LOGIC;
--		Reset											: IN	STD_LOGIC;
		
		-- Command-Status-Error interface
		
		-- MAC LocalLink interface
		TX_Clock									: IN	STD_LOGIC;
		TX_Valid									: IN	STD_LOGIC;
		TX_Data										: IN	T_SLV_8;
		TX_SOF										: IN	STD_LOGIC;
		TX_EOF										: IN	STD_LOGIC;
		TX_Ready									: OUT	STD_LOGIC;

		RX_Clock									: IN	STD_LOGIC;
		RX_Valid									: OUT	STD_LOGIC;
		RX_Data										: OUT	T_SLV_8;
		RX_SOF										: OUT	STD_LOGIC;
		RX_EOF										: OUT	STD_LOGIC;
		RX_Ready									: In	STD_LOGIC;
		
		PHY_Interface							:	INOUT	T_ETHERNET_PHY_INTERFACES
	);
END ENTITY;

ARCHITECTURE rtl OF Eth_Wrapper_Virtex6 IS

BEGIN


END ARCHITECTURE;
