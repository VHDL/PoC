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

ENTITY ICMPv6_Wrapper IS
	PORT (
		Clock															: IN	STD_LOGIC;
		Reset															: IN	STD_LOGIC;
		
		IP_TX_Valid												: OUT	STD_LOGIC;
		IP_TX_Data												: OUT	T_SLV_8;
		IP_TX_SOF													: OUT	STD_LOGIC;
		IP_TX_EOF													: OUT	STD_LOGIC;
		IP_TX_Ack													: IN	STD_LOGIC;
		IP_TX_Meta_rst										: IN	STD_LOGIC;
		IP_TX_Meta_DestIPv6Address_nxt		: IN	STD_LOGIC;
		IP_TX_Meta_DestIPv6Address_Data		: OUT	T_SLV_8;
		
		IP_RX_Valid												: IN	STD_LOGIC;
		IP_RX_Data												: IN	T_SLV_8;
		IP_RX_SOF													: IN	STD_LOGIC;
		IP_RX_EOF													: IN	STD_LOGIC;
		IP_RX_Ack													: OUT	STD_LOGIC--;
		
--		Command										: IN	T_ETHERNET_ICMPV6_COMMAND;
--		Status										: OUT	T_ETHERNET_ICMPV6_STATUS
		
		
	);
END;

ARCHITECTURE rtl OF ICMPv6_Wrapper IS
	SIGNAL RX_Received_EchoRequest			: STD_LOGIC;
	
BEGIN

	IP_RX_Ack													<= '1';
	
	IP_TX_Valid												<= '0';
	IP_TX_Data												<= (OTHERS => '0');
	IP_TX_SOF													<= '0';
	IP_TX_EOF													<= '0';
	IP_TX_Meta_DestIPv6Address_Data		<= (OTHERS => '0');


--	ICMPv6_loop : ENTITY L_Ethernet.FrameLoopback
--		GENERIC MAP (
--			DATA_BW										=> 8,
--			META_BW										=> 0
--		)
--		PORT MAP (
--			Clock									=> Clock,
--			Reset									=> Reset,
--		
--			In_Valid							=> IP_RX_Valid,
--			In_Data								=> IP_RX_Data,
--			In_Meta								=> (OTHERS => '0'),
--			In_SOF								=> IP_RX_SOF,
--			In_EOF								=> IP_RX_EOF,
--			In_Ack								=> IP_RX_Ack,
--			
--			Out_Valid							=> IP_TX_Valid,
--			Out_Data							=> IP_TX_Data,
--			Out_Meta							=> OPEN,
--			Out_SOF								=> IP_TX_SOF,
--			Out_EOF								=> IP_TX_EOF,
--			Out_Ack								=> IP_TX_Ack	
--		);

-- ============================================================================================================================================================
-- RX Path
-- ============================================================================================================================================================
--	RX : ENTITY L_Ethernet.ICMPv6_RX
--		PORT MAP (
--			Clock										=> Clock,	
--			Reset										=> Reset,
--			
--			RX_Valid								=> IP_RX_Valid,
--			RX_Data									=> IP_RX_Data,
--			RX_SOF									=> IP_RX_SOF,
--			RX_EOF									=> IP_RX_EOF,
--			RX_Ack									=> IP_RX_Ack,
--			
--			Received_EchoRequest		=> RX_Received_EchoRequest
--		);

-- ============================================================================================================================================================
-- TX Path
-- ============================================================================================================================================================
--	TX : ENTITY L_Ethernet.ICMPv6_TX
--		PORT MAP (
--			Clock										=> Clock,	
--			Reset										=> Reset,
--			
--			TX_Valid								=> IP_TX_Valid,
--			TX_Data									=> IP_TX_Data,
--			TX_SOF									=> IP_TX_SOF,
--			TX_EOF									=> IP_TX_EOF,
--			TX_Ack									=> IP_TX_Ack,
--			
--			Send_EchoResponse				=> RX_Received_EchoRequest
--    );
END ARCHITECTURE;
