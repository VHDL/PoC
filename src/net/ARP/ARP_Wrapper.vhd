LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;


ENTITY ARP_Wrapper IS
	GENERIC (
		CLOCK_FREQ_MHZ											: REAL																	:= 125.0;					-- 125 MHz
		INTERFACE_MACADDRESS								: T_NET_MAC_ADDRESS											:= C_NET_MAC_ADDRESS_EMPTY;
		INITIAL_IPV4ADDRESSES								: T_NET_IPV4_ADDRESS_VECTOR							:= (OTHERS => C_NET_IPV4_ADDRESS_EMPTY);
		INITIAL_ARPCACHE_CONTENT						: T_NET_ARP_ARPCACHE_VECTOR							:= (0 => (Tag => C_NET_IPV4_ADDRESS_EMPTY, MAC => C_NET_MAC_ADDRESS_EMPTY));
		APR_REQUEST_TIMEOUT_MS							: REAL																	:= 100.0
	);
	PORT (
		Clock																: IN	STD_LOGIC;
		Reset																: IN	STD_LOGIC;
		
		IPPool_Announce											: IN	STD_LOGIC;
		IPPool_Announced										: OUT	STD_LOGIC;
		
		IPCache_Lookup											: IN	STD_LOGIC;
		IPCache_IPv4Address_rst							: OUT	STD_LOGIC;
		IPCache_IPv4Address_nxt							: OUT	STD_LOGIC;
		IPCache_IPv4Address_Data						: IN	T_SLV_8;
		
		IPCache_Valid												: OUT	STD_LOGIC;
		IPCache_MACAddress_rst							: IN	STD_LOGIC;
		IPCache_MACAddress_nxt							: IN	STD_LOGIC;
		IPCache_MACAddress_Data							: OUT	T_SLV_8;
		
		Eth_UC_TX_Valid											: OUT	STD_LOGIC;
		Eth_UC_TX_Data											: OUT	T_SLV_8;
		Eth_UC_TX_SOF												: OUT	STD_LOGIC;
		Eth_UC_TX_EOF												: OUT	STD_LOGIC;
		Eth_UC_TX_Ready											: IN	STD_LOGIC;
		Eth_UC_TX_Meta_rst									: IN	STD_LOGIC;
		Eth_UC_TX_Meta_DestMACAddress_nxt		: IN	STD_LOGIC;
		Eth_UC_TX_Meta_DestMACAddress_Data	: OUT	T_SLV_8;
		
		Eth_UC_RX_Valid											: IN	STD_LOGIC;
		Eth_UC_RX_Data											: IN	T_SLV_8;
		Eth_UC_RX_SOF												: IN	STD_LOGIC;
		Eth_UC_RX_EOF												: IN	STD_LOGIC;
		Eth_UC_RX_Ready											: OUT	STD_LOGIC;
		Eth_UC_RX_Meta_rst									: OUT	STD_LOGIC;
		Eth_UC_RX_Meta_SrcMACAddress_nxt		: OUT	STD_LOGIC;
		Eth_UC_RX_Meta_SrcMACAddress_Data		: IN	T_SLV_8;
		Eth_UC_RX_Meta_DestMACAddress_nxt		: OUT	STD_LOGIC;
		Eth_UC_RX_Meta_DestMACAddress_Data	: IN	T_SLV_8;
		
		Eth_BC_RX_Valid											: IN	STD_LOGIC;
		Eth_BC_RX_Data											: IN	T_SLV_8;
		Eth_BC_RX_SOF												: IN	STD_LOGIC;
		Eth_BC_RX_EOF												: IN	STD_LOGIC;
		Eth_BC_RX_Ready											: OUT	STD_LOGIC;
		Eth_BC_RX_Meta_rst									: OUT	STD_LOGIC;
		Eth_BC_RX_Meta_SrcMACAddress_nxt		: OUT	STD_LOGIC;
		Eth_BC_RX_Meta_SrcMACAddress_Data		: IN	T_SLV_8;
		Eth_BC_RX_Meta_DestMACAddress_nxt		: OUT	STD_LOGIC;
		Eth_BC_RX_Meta_DestMACAddress_Data	: IN	T_SLV_8
	);
END;

ARCHITECTURE rtl OF ARP_Wrapper IS
	SIGNAL ARPCache_Command												: T_NET_ARP_ARPCACHE_COMMAND;
	SIGNAL IPPool_Command													: T_NET_ARP_IPPOOL_COMMAND;
	
	SIGNAL IPPool_Announce_l											: STD_LOGIC							:= '0';
	SIGNAL IPPool_Announced_i											: STD_LOGIC;
	
	TYPE T_FSMPOOL_STATE IS (
		ST_IDLE,
		ST_IPPOOL_WAIT,
		ST_SEND_RESPONSE,
		ST_SEND_ANNOUNCE,
		ST_ERROR
	);
	
	SIGNAL FSMPool_State													: T_FSMPOOL_STATE				:= ST_IDLE;
	SIGNAL FSMPool_NextState											: T_FSMPOOL_STATE;
	
	SIGNAL FSMPool_MACSeq1_SenderMACAddress_rst		: STD_LOGIC;
	SIGNAL FSMPool_MACSeq1_SenderMACAddress_nxt		: STD_LOGIC;
	
	SIGNAL FSMPool_BCRcv_Clear										: STD_LOGIC;
	SIGNAL FSMPool_BCRcv_Address_rst							: STD_LOGIC;
	SIGNAL FSMPool_BCRcv_SenderMACAddress_nxt			: STD_LOGIC;
	SIGNAL FSMPool_BCRcv_SenderIPv4Address_nxt		: STD_LOGIC;
	SIGNAL FSMPool_BCRcv_TargetIPv4Address_nxt		: STD_LOGIC;
	
	SIGNAL FSMPool_Command												: T_NET_ARP_IPPOOL_COMMAND;
	SIGNAL FSMPool_NewIPv4Address_Data						: T_NET_IPV4_ADDRESS;
	SIGNAL FSMPool_NewMACAddress_Data							: T_NET_MAC_ADDRESS;
	SIGNAL FSMPool_IPPool_Lookup									: STD_LOGIC;
	SIGNAL FSMPool_IPPool_IPv4Address_Data				: T_SLV_8;
	
	SIGNAL FSMPool_UCRsp_SendResponse							: STD_LOGIC;
	SIGNAL FSMPool_UCRsp_SenderMACAddress_Data		: T_SLV_8;
	SIGNAL FSMPool_UCRsp_SenderIPv4Address_Data		: T_SLV_8;
	SIGNAL FSMPool_UCRsp_TargetMACAddress_Data		: T_SLV_8;
	SIGNAL FSMPool_UCRsp_TargetIPv4Address_Data		: T_SLV_8;
	
	-- Sender MACAddress sequencer
	SIGNAL MACSeq1_SenderMACAddress_Data					: T_SLV_8;
	
	-- broadcast receiver
	SIGNAL BCRcv_Error														: STD_LOGIC;
	
	SIGNAL BCRcv_RequestReceived									: STD_LOGIC;
	SIGNAL BCRcv_SenderMACAddress_Data						: T_SLV_8;
	SIGNAL BCRcv_SenderIPv4Address_Data						: T_SLV_8;
	SIGNAL BCRcv_TargetIPv4Address_Data						: T_SLV_8;
	
	-- ippool
	SIGNAL IPPool_Insert													: STD_LOGIC;
	SIGNAL IPPool_UCRsp_SendResponse							: STD_LOGIC;
	SIGNAL IPPool_IPv4Address_rst									: STD_LOGIC;
	SIGNAL IPPool_IPv4Address_nxt									: STD_LOGIC;
	SIGNAL IPPool_PoolResult											: T_CACHE_RESULT;
	
	-- unicast responder
	SIGNAL UCRsp_Complete													: STD_LOGIC;
	
	SIGNAL UCRsp_Address_rst											: STD_LOGIC;
	SIGNAL UCRsp_SenderMACAddress_nxt							: STD_LOGIC;
	SIGNAL UCRsp_SenderIPv4Address_nxt						: STD_LOGIC;
	SIGNAL UCRsp_TargetMACAddress_nxt							: STD_LOGIC;
	SIGNAL UCRsp_TargetIPv4Address_nxt						: STD_LOGIC;
	
	SIGNAL UCRsp_TX_Valid													: STD_LOGIC;
	SIGNAL UCRsp_TX_Data													: T_SLV_8;
	SIGNAL UCRsp_TX_SOF														: STD_LOGIC;
	SIGNAL UCRsp_TX_EOF														: STD_LOGIC;
	SIGNAL UCRsp_TX_Ready													: STD_LOGIC;
	SIGNAL UCRsp_TX_Meta_DestMACAddress_rst				: STD_LOGIC;
	SIGNAL UCRsp_TX_Meta_DestMACAddress_nxt				: STD_LOGIC;
	SIGNAL UCRsp_TX_Meta_DestMACAddress_Data			: T_SLV_8;
	
	TYPE T_FSMCACHE_STATE IS (
		ST_IDLE,
			ST_CACHE, ST_CACHE_WAIT, ST_READ_CACHE,
			ST_SEND_BROADCAST_REQUEST, ST_SEND_BROADCAST_REQUEST_WAIT, ST_WAIT_FOR_UNICAST_RESPONSE,
			ST_UPDATE_CACHE,
		ST_ERROR
	);
	
	SIGNAL FSMCache_State													: T_FSMCACHE_STATE								:= ST_IDLE;
	SIGNAL FSMCache_NextState											: T_FSMCACHE_STATE;
	
	SIGNAL FSMCache_ARPCache_Command							: T_NET_ARP_ARPCACHE_COMMAND;
	SIGNAL FSMCache_ARPCache_NewIPv4Address_Data	: T_SLV_8;
	SIGNAL FSMCache_ARPCache_NewMACAddress_Data		: T_SLV_8;

	SIGNAL FSMCache_MACSeq2_SenderMACAddress_rst	: STD_LOGIC;
	SIGNAL FSMCache_MACSeq2_SenderMACAddress_nxt	: STD_LOGIC;
	SIGNAL FSMCache_IPSeq2_SenderIPv4Address_rst	: STD_LOGIC;
	SIGNAL FSMCache_IPSeq2_SenderIPv4Address_nxt	: STD_LOGIC;

	SIGNAL FSMCache_UCRcv_Clear										: STD_LOGIC;
	SIGNAL FSMCache_UCRcv_Address_rst							: STD_LOGIC;
	SIGNAL FSMCache_UCRcv_SenderMACAddress_nxt		: STD_LOGIC;
	SIGNAL FSMCache_UCRcv_SenderIPv4Address_nxt		: STD_LOGIC;
	SIGNAL FSMCache_UCRcv_TargetMACAddress_nxt		: STD_LOGIC;
	SIGNAL FSMCache_UCRcv_TargetIPv4Address_nxt		: STD_LOGIC;
	
	SIGNAL FSMCache_ARPCache_Lookup								: STD_LOGIC;
	SIGNAL FSMCache_ARPCache_IPv4Address_Data			: T_SLV_8;
	SIGNAL FSMCache_ARPCache_MACAddress_rst				: STD_LOGIC;
	SIGNAL FSMCache_ARPCache_MACAddress_nxt				: STD_LOGIC;

	SIGNAL FSMCache_BCReq_SendRequest							: STD_LOGIC;
	SIGNAL FSMCache_BCReq_SenderMACAddress_Data		: T_SLV_8;
	SIGNAL FSMCache_BCReq_SenderIPv4Address_Data	: T_SLV_8;
	SIGNAL FSMCache_BCReq_TargetMACAddress_Data		: T_SLV_8;
	SIGNAL FSMCache_BCReq_TargetIPv4Address_Data	: T_SLV_8;

	-- Sender ***Address sequencer
	SIGNAL MACSeq2_SenderMACAddress_Data					: T_SLV_8;
	SIGNAL IPSeq2_SenderIPv4Address_Data					: T_SLV_8;

	-- ARP request timeout counter
	CONSTANT ARPREQ_TIMEOUTCOUNTER_MAX						: POSITIVE																						:= TimingToCycles_ms(APR_REQUEST_TIMEOUT_MS, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ));
	CONSTANT ARPREQ_TIMEOUTCOUNTER_BITS						: POSITIVE																						:= log2ceilnz(ARPREQ_TIMEOUTCOUNTER_MAX);
	
	SIGNAL FSMCache_ARPReq_TimeoutCounter_rst			: STD_LOGIC;
	SIGNAL ARPReq_TimeoutCounter_s								: SIGNED(ARPREQ_TIMEOUTCOUNTER_BITS DOWNTO 0)					:= to_signed(ARPREQ_TIMEOUTCOUNTER_MAX, ARPREQ_TIMEOUTCOUNTER_BITS + 1);
	SIGNAL ARPReq_Timeout													: STD_LOGIC;
	
	-- unicast receiver
	SIGNAL UCRcv_Error														: STD_LOGIC;
	SIGNAL UCRcv_ResponseReceived									: STD_LOGIC;
	SIGNAL UCRcv_SenderMACAddress_Data						: T_SLV_8;
	SIGNAL UCRcv_SenderIPv4Address_Data						: T_SLV_8;
	SIGNAL UCRcv_TargetMACAddress_Data						: T_SLV_8;
	SIGNAL UCRcv_TargetIPv4Address_Data						: T_SLV_8;
	
	-- arp cache
	SIGNAL ARPCache_Status												: T_NET_ARP_ARPCACHE_STATUS;
	SIGNAL ARPCache_NewMACAddress_nxt							: STD_LOGIC;
	SIGNAL ARPCache_NewIPv4Address_nxt						: STD_LOGIC;
	SIGNAL ARPCache_CacheResult										: T_CACHE_RESULT;
	SIGNAL ARPCache_IPv4Address_rst								: STD_LOGIC;
	SIGNAL ARPCache_IPv4Address_nxt								: STD_LOGIC;
	SIGNAL ARPCache_MACAddress_Data								: T_SLV_8;
	
	-- broadcast requester
	SIGNAL BCReq_Complete													: STD_LOGIC;
	
	SIGNAL BCReq_Address_rst											: STD_LOGIC;
	SIGNAL BCReq_SenderMACAddress_nxt							: STD_LOGIC;
	SIGNAL BCReq_SenderIPv4Address_nxt						: STD_LOGIC;
	SIGNAL BCReq_TargetMACAddress_nxt							: STD_LOGIC;
	SIGNAL BCReq_TargetIPv4Address_nxt						: STD_LOGIC;
	
	SIGNAL BCReq_TX_Valid													: STD_LOGIC;
	SIGNAL BCReq_TX_Data													: T_SLV_8;
	SIGNAL BCReq_TX_SOF														: STD_LOGIC;
	SIGNAL BCReq_TX_EOF														: STD_LOGIC;
	SIGNAL BCReq_TX_Ready													: STD_LOGIC;
	SIGNAL BCReq_TX_Meta_DestMACAddress_rst				: STD_LOGIC;
	SIGNAL BCReq_TX_Meta_DestMACAddress_nxt				: STD_LOGIC;
	SIGNAL BCReq_TX_Meta_DestMACAddress_Data			: T_SLV_8;
	
BEGIN
	-- latched inputs (high-active)
	IPPool_Announce_l	<= ((IPPool_Announce OR IPPool_Announce_l) AND NOT IPPool_Announced_i) WHEN rising_edge(Clock);
	IPPool_Announced	<= IPPool_Announced_i;
	
	-- FIXME: assign correct value
	IPPool_Insert		<= '0';
	
-- ============================================================================================================================================================
-- Responder Path
-- ============================================================================================================================================================
	MACSeq1 : ENTITY L_Global.Sequenzer
		GENERIC MAP (
			INPUT_BITS						=> 48,
			OUTPUT_BITS						=> 8,
			REGISTERED						=> FALSE
		)
		PORT MAP (
			Clock									=> Clock,
			Reset									=> Reset,
			
			Input									=> to_slv(INTERFACE_MACADDRESS),
			rst										=> FSMPool_MACSeq1_SenderMACAddress_rst,
			rev										=> '1',
			nxt										=> FSMPool_MACSeq1_SenderMACAddress_nxt,
			Output								=> MACSeq1_SenderMACAddress_Data
		);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				FSMPool_State		<= ST_IDLE;
			ELSE
				FSMPool_State		<= FSMPool_NextState;
			END IF;
		END IF;
	END PROCESS;

	-- sequencer
	--INTERFACE_MACAddress_Data

	PROCESS(FSMPool_State,
					IPPool_Announce_l,
					MACSeq1_SenderMACAddress_Data,
					BCRcv_RequestReceived, BCRcv_Error, BCRcv_SenderMACAddress_Data, BCRcv_SenderIPv4Address_Data, BCRcv_TargetIPv4Address_Data,
					IPPool_PoolResult, IPPool_IPv4Address_nxt,
					UCRsp_Address_rst, UCRsp_SenderMACAddress_nxt, UCRsp_SenderIPv4Address_nxt, UCRsp_TargetMACAddress_nxt, UCRsp_TargetIPv4Address_nxt, UCRsp_Complete)
	BEGIN
		FSMPool_NextState											<= FSMPool_State;
	
--		FSMPool_Command						<= NET_ARP_CACHE_CMD_NONE;
--		FSMPool_NewIPv4Address_Data		<= UCRcv_SenderIPv4Address_Data;
--		FSMPool_NewMACAddress_Data			<= UCRcv_SenderMACAddress_Data;
	
		IPPool_Announced_i										<= '0';
	
		FSMPool_MACSeq1_SenderMACAddress_rst	<= '0';
		FSMPool_MACSeq1_SenderMACAddress_nxt	<= '0';
	
		FSMPool_BCRcv_Clear										<= '0';
		FSMPool_BCRcv_Address_rst							<= '0';
		FSMPool_BCRcv_SenderMACAddress_nxt		<= '0';
		FSMPool_BCRcv_SenderIPv4Address_nxt		<= '0';
		FSMPool_BCRcv_TargetIPv4Address_nxt		<= '0';
	
		FSMPool_IPPool_Lookup									<= '0';
		FSMPool_IPPool_IPv4Address_Data				<= BCRcv_TargetIPv4Address_Data;

		FSMPool_UCRsp_SendResponse						<= '0';
		FSMPool_UCRsp_SenderMACAddress_Data		<= MACSeq1_SenderMACAddress_Data;
		FSMPool_UCRsp_SenderIPv4Address_Data	<= BCRcv_TargetIPv4Address_Data;
		FSMPool_UCRsp_TargetMACAddress_Data		<= BCRcv_SenderMACAddress_Data;
		FSMPool_UCRsp_TargetIPv4Address_Data	<= BCRcv_SenderIPv4Address_Data;
	
		CASE FSMPool_State IS
			WHEN ST_IDLE =>
				IF (BCRcv_RequestReceived = '1') THEN
					FSMPool_IPPool_Lookup									<= '1';
					FSMPool_BCRcv_TargetIPv4Address_nxt		<= IPPool_IPv4Address_nxt;
				
					FSMPool_NextState											<= ST_IPPOOL_WAIT;
				ELSIF (IPPool_Announce_l = '1') THEN
--					FSMPool_UCRsp_SendResponse						<= '1';
					
--					FSMPool_NextState											<= ST_SEND_ANNOUNCE;
				END IF;
				
			WHEN ST_IPPOOL_WAIT =>
				FSMPool_BCRcv_TargetIPv4Address_nxt			<= IPPool_IPv4Address_nxt;
			
				IF (IPPool_PoolResult = CACHE_RESULT_HIT) THEN
					FSMPool_BCRcv_Address_rst							<= '1';
					FSMPool_MACSeq1_SenderMACAddress_rst	<= '1';
					FSMPool_UCRsp_SendResponse						<= '1';
					
					FSMPool_NextState											<= ST_SEND_RESPONSE;
				ELSIF (IPPool_PoolResult = CACHE_RESULT_MISS) THEN
					FSMPool_BCRcv_Clear										<= '1';
					FSMPool_NextState											<= ST_IDLE;
				END IF;
	
			WHEN ST_SEND_RESPONSE =>
				FSMPool_BCRcv_Address_rst								<= UCRsp_Address_rst;
				FSMPool_BCRcv_SenderMACAddress_nxt			<= UCRsp_TargetMACAddress_nxt;
				FSMPool_BCRcv_SenderIPv4Address_nxt			<= UCRsp_TargetIPv4Address_nxt;
				FSMPool_MACSeq1_SenderMACAddress_nxt		<= UCRsp_SenderMACAddress_nxt;
				FSMPool_BCRcv_TargetIPv4Address_nxt			<= UCRsp_SenderIPv4Address_nxt;
			
				IF (UCRsp_Complete = '1') THEN
					FSMPool_BCRcv_Clear							<= '1';
					FSMPool_NextState								<= ST_IDLE;
				END IF;
	
			WHEN ST_SEND_ANNOUNCE =>
				IF (UCRsp_Complete = '1') THEN
					IPPool_Announced_i							<= '1';
					FSMPool_BCRcv_Clear							<= '1';
					
					FSMPool_NextState								<= ST_IDLE;
				END IF;
				
			WHEN ST_ERROR =>
				NULL;
				
		END CASE;
	END PROCESS;

	BCRcv : ENTITY L_Ethernet.ARP_BroadCast_Receiver
		GENERIC MAP (
			ALLOWED_PROTOCOL_IPV4					=> TRUE,
			ALLOWED_PROTOCOL_IPV6					=> FALSE
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			RX_Valid											=> Eth_BC_RX_Valid,
			RX_Data												=> Eth_BC_RX_Data,
			RX_SOF												=> Eth_BC_RX_SOF,
			RX_EOF												=> Eth_BC_RX_EOF,
			RX_Ready											=> Eth_BC_RX_Ready,
			RX_Meta_rst										=> Eth_BC_RX_Meta_rst,
			RX_Meta_SrcMACAddress_nxt			=> Eth_BC_RX_Meta_SrcMACAddress_nxt,
			RX_Meta_SrcMACAddress_Data		=> Eth_BC_RX_Meta_SrcMACAddress_Data,
			RX_Meta_DestMACAddress_nxt		=> Eth_BC_RX_Meta_DestMACAddress_nxt,
			RX_Meta_DestMACAddress_Data		=> Eth_BC_RX_Meta_DestMACAddress_Data,
			
			Clear													=> FSMPool_BCRcv_Clear,
			Error													=> BCRcv_Error,
			
			RequestReceived								=> BCRcv_RequestReceived,
			Address_rst										=> FSMPool_BCRcv_Address_rst,
			SenderMACAddress_nxt					=> FSMPool_BCRcv_SenderMACAddress_nxt,
			SenderMACAddress_Data					=> BCRcv_SenderMACAddress_Data,
			SenderIPAddress_nxt						=> FSMPool_BCRcv_SenderIPv4Address_nxt,
			SenderIPAddress_Data					=> BCRcv_SenderIPv4Address_Data,
			TargetIPAddress_nxt						=> FSMPool_BCRcv_TargetIPv4Address_nxt,
			TargetIPAddress_Data					=> BCRcv_TargetIPv4Address_Data
		);

	IPPool : ENTITY L_Ethernet.ARP_IPPool
		GENERIC MAP (
			IPPOOL_SIZE										=> 8,
			INITIAL_IPV4ADDRESSES					=> INITIAL_IPV4ADDRESSES
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,

--			Command												=> IPPool_Command,
--			IPv4Address_Data							=> (OTHERS => '0'),
--			MACAddress_Data								=> (OTHERS => '0'),
			
			Lookup												=> FSMPool_IPPool_Lookup,
			IPv4Address_rst								=> IPPool_IPv4Address_rst,
			IPv4Address_nxt								=> IPPool_IPv4Address_nxt,
			IPv4Address_Data							=> FSMPool_IPPool_IPv4Address_Data,
			
			PoolResult										=> IPPool_PoolResult
		);

	UCRsp : ENTITY L_Ethernet.ARP_UniCast_Responder
--		GENERIC MAP (
--			
--		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
							
			SendResponse									=> FSMPool_UCRsp_SendResponse,
			Complete											=> UCRsp_Complete,
			
			Address_rst										=> UCRsp_Address_rst,
			SenderMACAddress_nxt					=> UCRsp_SenderMACAddress_nxt,
			SenderMACAddress_Data					=> FSMPool_UCRsp_SenderMACAddress_Data,					-- self
			SenderIPv4Address_nxt					=> UCRsp_SenderIPv4Address_nxt,
			SenderIPv4Address_Data				=> FSMPool_UCRsp_SenderIPv4Address_Data,				-- self
			TargetMACAddress_nxt					=> UCRsp_TargetMACAddress_nxt,
			TargetMACAddress_Data					=> FSMPool_UCRsp_TargetMACAddress_Data,					-- requester
			TargetIPv4Address_nxt					=> UCRsp_TargetIPv4Address_nxt,
			TargetIPv4Address_Data				=> FSMPool_UCRsp_TargetIPv4Address_Data,				-- requester
							
			TX_Valid											=> UCRsp_TX_Valid,
			TX_Data												=> UCRsp_TX_Data,
			TX_SOF												=> UCRsp_TX_SOF,
			TX_EOF												=> UCRsp_TX_EOF,
			TX_Ready											=> UCRsp_TX_Ready,
			TX_Meta_DestMACAddress_rst		=> UCRsp_TX_Meta_DestMACAddress_rst,
			TX_Meta_DestMACAddress_nxt		=> UCRsp_TX_Meta_DestMACAddress_nxt,
			TX_Meta_DestMACAddress_Data		=> UCRsp_TX_Meta_DestMACAddress_Data
		);
-- ============================================================================================================================================================
-- ARPCache Path
-- ============================================================================================================================================================
	MACSeq2 : ENTITY L_Global.Sequenzer
		GENERIC MAP (
			INPUT_BITS						=> 48,
			OUTPUT_BITS						=> 8,
			REGISTERED						=> FALSE
		)
		PORT MAP (
			Clock									=> Clock,
			Reset									=> Reset,
			
			Input									=> to_slv(INTERFACE_MACADDRESS),
			rst										=> FSMCache_MACSeq2_SenderMACAddress_rst,
			rev										=> '1',
			nxt										=> FSMCache_MACSeq2_SenderMACAddress_nxt,
			Output								=> MACSeq2_SenderMACAddress_Data
		);
		
	IPSeq2 : ENTITY L_Global.Sequenzer
		GENERIC MAP (
			INPUT_BITS						=> 32,
			OUTPUT_BITS						=> 8,
			REGISTERED						=> FALSE
		)
		PORT MAP (
			Clock									=> Clock,
			Reset									=> Reset,
			
			Input									=> to_slv(INITIAL_IPV4ADDRESSES(0)),
			rst										=> FSMCache_IPSeq2_SenderIPv4Address_rst,
			rev										=> '1',
			nxt										=> FSMCache_IPSeq2_SenderIPv4Address_nxt,
			Output								=> IPSeq2_SenderIPv4Address_Data
		);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				FSMCache_State		<= ST_IDLE;
			ELSE
				FSMCache_State		<= FSMCache_NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(FSMCache_State,
					IPCache_Lookup, IPCache_IPv4Address_Data,	IPCache_MACAddress_rst, IPCache_MACAddress_nxt,
					MACSeq2_SenderMACAddress_Data, IPSeq2_SenderIPv4Address_Data, ARPReq_Timeout,
					UCRcv_Error, UCRcv_ResponseReceived, UCRcv_SenderIPv4Address_Data, UCRcv_SenderMACAddress_Data, UCRcv_TargetIPv4Address_Data, UCRcv_TargetMACAddress_Data,
					ARPCache_Status, ARPCache_CacheResult, ARPCache_IPv4Address_rst, ARPCache_IPv4Address_nxt, ARPCache_MACAddress_Data, ARPCache_NewMACAddress_nxt, ARPCache_NewIPv4Address_nxt,
					BCReq_Address_rst, BCReq_SenderMACAddress_nxt, BCReq_SenderIPv4Address_nxt, BCReq_TargetMACAddress_nxt, BCReq_TargetIPv4Address_nxt, BCReq_Complete)
	BEGIN
		FSMCache_NextState													<= FSMCache_State;
		
		IPCache_IPv4Address_rst											<= '0';
		IPCache_IPv4Address_nxt											<= '0';
		
		IPCache_Valid																<= '0';
		IPCache_MACAddress_Data											<= ARPCache_MACAddress_Data;
		
		FSMCache_ARPCache_Command										<= NET_ARP_ARPCACHE_CMD_NONE;
		FSMCache_ARPCache_NewMACAddress_Data				<= UCRcv_SenderMACAddress_Data;
		FSMCache_ARPCache_NewIPv4Address_Data				<= UCRcv_SenderIPv4Address_Data;
		
		FSMCache_MACSeq2_SenderMACAddress_rst				<= '0';
		FSMCache_MACSeq2_SenderMACAddress_nxt				<= '0';
		FSMCache_IPSeq2_SenderIPv4Address_rst				<= '0';
		FSMCache_IPSeq2_SenderIPv4Address_nxt				<= '0';
		
		FSMCache_ARPReq_TimeoutCounter_rst					<= '1';
		
		FSMCache_ARPCache_Lookup										<= '0';
		FSMCache_ARPCache_IPv4Address_Data					<= IPCache_IPv4Address_Data;
		FSMCache_ARPCache_MACAddress_rst						<= IPCache_MACAddress_rst;
		FSMCache_ARPCache_MACAddress_nxt						<= IPCache_MACAddress_nxt;
		
		FSMCache_BCReq_SendRequest									<= '0';
		FSMCache_BCReq_SenderMACAddress_Data				<= MACSeq2_SenderMACAddress_Data;
		FSMCache_BCReq_SenderIPv4Address_Data				<= IPSeq2_SenderIPv4Address_Data;
		FSMCache_BCReq_TargetMACAddress_Data				<= x"00";
		FSMCache_BCReq_TargetIPv4Address_Data				<= IPCache_IPv4Address_Data;

		FSMCache_UCRcv_Clear												<= UCRcv_ResponseReceived;		-- discard all ARP packets, which are not requested / expected
		FSMCache_UCRcv_Address_rst									<= '0';
		FSMCache_UCRcv_SenderMACAddress_nxt					<= '0';
		FSMCache_UCRcv_SenderIPv4Address_nxt				<= '0';
		FSMCache_UCRcv_TargetMACAddress_nxt					<= '0';		-- default assignment for unsed metadata TargetMACAddress
		FSMCache_UCRcv_TargetIPv4Address_nxt				<= '0';		-- default assignment for unsed metadata TargetIPv4Address
	
		CASE FSMCache_State IS
			WHEN ST_IDLE =>
				IPCache_IPv4Address_rst									<= '1';
				
				IF (IPCache_Lookup = '1') THEN
					FSMCache_NextState										<= ST_CACHE;
				END IF;

			WHEN ST_CACHE =>
				FSMCache_ARPCache_Lookup								<= '1';
				IPCache_IPv4Address_rst									<= ARPCache_IPv4Address_rst;
				IPCache_IPv4Address_nxt									<= ARPCache_IPv4Address_nxt;
				
				IF (ARPCache_CacheResult = CACHE_RESULT_MISS) THEN
					FSMCache_NextState										<= ST_SEND_BROADCAST_REQUEST;
				ELSE
					FSMCache_NextState										<= ST_CACHE_WAIT;
				END IF;

			WHEN ST_CACHE_WAIT =>
				IPCache_IPv4Address_rst									<= ARPCache_IPv4Address_rst;
				IPCache_IPv4Address_nxt									<= ARPCache_IPv4Address_nxt;
			
				IF (ARPCache_CacheResult = CACHE_RESULT_HIT) THEN
					FSMCache_NextState										<= ST_READ_CACHE;
				ELSIF (ARPCache_CacheResult = CACHE_RESULT_MISS) THEN
					FSMCache_NextState										<= ST_SEND_BROADCAST_REQUEST;
				END IF;
			
			WHEN ST_READ_CACHE =>
				IPCache_IPv4Address_rst									<= '1';
				IPCache_Valid														<= '1';
				
				FSMCache_ARPCache_MACAddress_rst				<= IPCache_MACAddress_rst;
				FSMCache_ARPCache_MACAddress_nxt				<= IPCache_MACAddress_nxt;
				
				IF (IPCache_Lookup = '1') THEN
					FSMCache_NextState										<= ST_CACHE;
				END IF;
			
			WHEN ST_SEND_BROADCAST_REQUEST =>
				FSMCache_MACSeq2_SenderMACAddress_rst		<= '1';
				FSMCache_IPSeq2_SenderIPv4Address_rst		<= '1';
				FSMCache_BCReq_SendRequest							<= '1';
				
				IPCache_IPv4Address_rst									<= BCReq_Address_rst;
				IPCache_IPv4Address_nxt									<= BCReq_TargetIPv4Address_nxt;	
				
				FSMCache_NextState											<= ST_SEND_BROADCAST_REQUEST_WAIT;
			
			WHEN ST_SEND_BROADCAST_REQUEST_WAIT =>
				FSMCache_MACSeq2_SenderMACAddress_rst		<= BCReq_Address_rst;
				FSMCache_MACSeq2_SenderMACAddress_nxt		<= BCReq_SenderMACAddress_nxt;
				FSMCache_IPSeq2_SenderIPv4Address_rst		<= BCReq_Address_rst;
				FSMCache_IPSeq2_SenderIPv4Address_nxt		<= BCReq_SenderIPv4Address_nxt;

				IPCache_IPv4Address_rst									<= BCReq_Address_rst;
				IPCache_IPv4Address_nxt									<= BCReq_TargetIPv4Address_nxt;	

				IF (BCReq_Complete = '1') THEN
					FSMCache_NextState										<= ST_WAIT_FOR_UNICAST_RESPONSE;
				END IF;
		
			WHEN ST_WAIT_FOR_UNICAST_RESPONSE =>
				FSMCache_UCRcv_Clear										<= '0';
				FSMCache_ARPReq_TimeoutCounter_rst			<= '0';
				-- TODO: check received ARP packet data with ethernet metadata
				
				IF (UCRcv_Error = '1') THEN
					-- FIXME: error handling
					FSMCache_NextState										<= ST_ERROR;
				ELSIF (UCRcv_ResponseReceived = '1') THEN
					FSMCache_ARPCache_Command							<= NET_ARP_ARPCACHE_CMD_ADD;
					FSMCache_UCRcv_SenderMACAddress_nxt		<= ARPCache_NewMACAddress_nxt;
					FSMCache_UCRcv_SenderIPv4Address_nxt	<= ARPCache_NewIPv4Address_nxt;
					
					FSMCache_NextState										<= ST_UPDATE_CACHE;
				ELSIF (ARPReq_Timeout = '1') THEN
					-- FIXME: error handling
--					FSMCache_NextState										<= ST_ERROR;
					FSMCache_NextState										<= ST_SEND_BROADCAST_REQUEST;
				END IF;
				
			WHEN ST_UPDATE_CACHE =>
				FSMCache_UCRcv_Clear										<= '0';
				FSMCache_UCRcv_SenderMACAddress_nxt			<= ARPCache_NewMACAddress_nxt;
				FSMCache_UCRcv_SenderIPv4Address_nxt		<= ARPCache_NewIPv4Address_nxt;
				
				IF (ARPCache_Status = NET_ARP_ARPCACHE_STATUS_UPDATE_COMPLETE) THEN
					FSMCache_UCRcv_Clear									<= '1';
					IPCache_IPv4Address_rst								<= '1';
									
					FSMCache_NextState										<= ST_CACHE;
				END IF;
			
			WHEN ST_ERROR =>
				-- FIXME: error handling
				FSMCache_NextState											<= ST_IDLE;
				
		END CASE;
	END PROCESS;

	-- ARP request expiration timer
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (FSMCache_ARPReq_TimeoutCounter_rst = '1') THEN
				ARPReq_TimeoutCounter_s		<= to_signed(ARPREQ_TIMEOUTCOUNTER_MAX, ARPReq_TimeoutCounter_s'length);
			ELSE
				ARPReq_TimeoutCounter_s		<= ARPReq_TimeoutCounter_s - 1;
			END IF;
		END IF;
	END PROCESS;
	
	ARPReq_Timeout			<= ARPReq_TimeoutCounter_s(ARPReq_TimeoutCounter_s'high);

	UCRcv : ENTITY L_Ethernet.ARP_UniCast_Receiver
		GENERIC MAP (
			ALLOWED_PROTOCOL_IPV4					=> TRUE,
			ALLOWED_PROTOCOL_IPV6					=> FALSE
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			RX_Valid											=> Eth_UC_RX_Valid,
			RX_Data												=> Eth_UC_RX_Data,
			RX_SOF												=> Eth_UC_RX_SOF,
			RX_EOF												=> Eth_UC_RX_EOF,
			RX_Ready											=> Eth_UC_RX_Ready,
			RX_Meta_rst										=> Eth_UC_RX_Meta_rst,
			RX_Meta_SrcMACAddress_nxt			=> Eth_UC_RX_Meta_SrcMACAddress_nxt,
			RX_Meta_SrcMACAddress_Data		=> Eth_UC_RX_Meta_SrcMACAddress_Data,
			RX_Meta_DestMACAddress_nxt		=> Eth_UC_RX_Meta_DestMACAddress_nxt,
			RX_Meta_DestMACAddress_Data		=> Eth_UC_RX_Meta_DestMACAddress_Data,
			
			Clear													=> FSMCache_UCRcv_Clear,
			Error													=> UCRcv_Error,
			
			ResponseReceived							=> UCRcv_ResponseReceived,
			Address_rst										=> FSMCache_UCRcv_Address_rst,
			SenderIPAddress_nxt						=> FSMCache_UCRcv_SenderIPv4Address_nxt,
			SenderIPAddress_Data					=> UCRcv_SenderIPv4Address_Data,
			SenderMACAddress_nxt					=> FSMCache_UCRcv_SenderMACAddress_nxt,
			SenderMACAddress_Data					=> UCRcv_SenderMACAddress_Data,
			TargetIPAddress_nxt						=> FSMCache_UCRcv_TargetIPv4Address_nxt,
			TargetIPAddress_Data					=> UCRcv_TargetIPv4Address_Data,
			TargetMACAddress_nxt					=> FSMCache_UCRcv_TargetMACAddress_nxt,
			TargetMACAddress_Data					=> UCRcv_TargetMACAddress_Data
		);

	ARPCache : ENTITY L_Ethernet.ARP_Cache
		GENERIC MAP (
			CLOCK_FREQ_MHZ							=> CLOCK_FREQ_MHZ,
			REPLACEMENT_POLICY					=> "LRU",
			TAG_BYTE_ORDER							=> BIG_ENDIAN,
			DATA_BYTE_ORDER							=> BIG_ENDIAN,
			INITIAL_CACHE_CONTENT				=> INITIAL_ARPCACHE_CONTENT
		)
		PORT MAP (
			Clock												=> Clock,
			Reset												=> Reset,

			Command											=> FSMCache_ARPCache_Command,
			Status											=> ARPCache_Status,
			NewMACAddress_nxt						=> ARPCache_NewMACAddress_nxt,
			NewMACAddress_Data					=> FSMCache_ARPCache_NewMACAddress_Data,
			NewIPv4Address_nxt					=> ARPCache_NewIPv4Address_nxt,
			NewIPv4Address_Data					=> FSMCache_ARPCache_NewIPv4Address_Data,
			
			Lookup											=> FSMCache_ARPCache_Lookup,
			IPv4Address_rst							=> ARPCache_IPv4Address_rst,
			IPv4Address_nxt							=> ARPCache_IPv4Address_nxt,
			IPv4Address_Data						=> FSMCache_ARPCache_IPv4Address_Data,
			
			CacheResult									=> ARPCache_CacheResult,
			MACAddress_rst							=> FSMCache_ARPCache_MACAddress_rst,
			MACAddress_nxt							=> FSMCache_ARPCache_MACAddress_nxt,
			MACAddress_Data							=> ARPCache_MACAddress_Data
		);

	BCReq : ENTITY L_Ethernet.ARP_BroadCast_Requester
--		GENERIC MAP (
--			
--		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,

			SendRequest										=> FSMCache_BCReq_SendRequest,
			Complete											=> BCReq_Complete,
			Address_rst										=> BCReq_Address_rst,
			SenderMACAddress_nxt					=> BCReq_SenderMACAddress_nxt,
			SenderMACAddress_Data					=> FSMCache_BCReq_SenderMACAddress_Data,			-- self
			SenderIPv4Address_nxt					=> BCReq_SenderIPv4Address_nxt,
			SenderIPv4Address_Data				=> FSMCache_BCReq_SenderIPv4Address_Data,			-- self
			TargetMACAddress_nxt					=> BCReq_TargetMACAddress_nxt,
			TargetMACAddress_Data					=> FSMCache_BCReq_TargetMACAddress_Data,			-- broadcast + request for mac-to-ip mapping
			TargetIPv4Address_nxt					=> BCReq_TargetIPv4Address_nxt,
			TargetIPv4Address_Data				=> FSMCache_BCReq_TargetIPv4Address_Data,			-- broadcast + request for mac-to-ip mapping
			
			TX_Valid											=> BCReq_TX_Valid,
			TX_Data												=> BCReq_TX_Data,
			TX_SOF												=> BCReq_TX_SOF,
			TX_EOF												=> BCReq_TX_EOF,
			TX_Ready											=> BCReq_TX_Ready,
			TX_Meta_DestMACAddress_rst		=> BCReq_TX_Meta_DestMACAddress_rst,
			TX_Meta_DestMACAddress_nxt		=> BCReq_TX_Meta_DestMACAddress_nxt,
			TX_Meta_DestMACAddress_Data		=> BCReq_TX_Meta_DestMACAddress_Data
		);

	blkLLMux : BLOCK
		CONSTANT LLMUX_PORT_BCREQ		: NATURAL					:= 0;
		CONSTANT LLMUX_PORT_UCRSP		: NATURAL					:= 1;
		CONSTANT LLMUX_PORTS				: POSITIVE				:= 2;
		
		CONSTANT META_RST_BIT				: NATURAL					:= 0;
		CONSTANT META_DEST_NXT_BIT	: NATURAL					:= 1;
	
		CONSTANT META_BITS					: POSITIVE				:= 8;
		CONSTANT META_REV_BITS			: POSITIVE				:= 2;
	
		
		SIGNAL Temp_Meta						: T_SLVV_48(LLMUX_PORTS - 1 DOWNTO 0);
		SIGNAL Temp_Meta2						: T_SLV_48;
		
		SIGNAL LLMux_In_Valid				: STD_LOGIC_VECTOR(LLMUX_PORTS - 1 DOWNTO 0);
		SIGNAL LLMux_In_Data				: T_SLM(LLMUX_PORTS - 1 DOWNTO 0, T_SLV_8'range)								:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
		SIGNAL LLMux_In_Meta				: T_SLM(LLMUX_PORTS - 1 DOWNTO 0, META_BITS - 1 DOWNTO 0)				:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
		SIGNAL LLMux_In_Meta_rev		: T_SLM(LLMUX_PORTS - 1 DOWNTO 0, META_REV_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
		SIGNAL LLMux_In_SOF					: STD_LOGIC_VECTOR(LLMUX_PORTS - 1 DOWNTO 0);
		SIGNAL LLMux_In_EOF					: STD_LOGIC_VECTOR(LLMUX_PORTS - 1 DOWNTO 0);
		SIGNAL LLMux_In_Ready				: STD_LOGIC_VECTOR(LLMUX_PORTS - 1 DOWNTO 0);
		
		SIGNAL LLMux_Out_Meta				: STD_LOGIC_VECTOR(META_BITS - 1 DOWNTO 0);
		SIGNAL LLMux_Out_Meta_rev		: STD_LOGIC_VECTOR(META_REV_BITS - 1 DOWNTO 0);
		
	BEGIN
	
		-- LLMux Port 0 - broadcast requester
		LLMux_In_Valid(LLMUX_PORT_BCREQ)				<= BCReq_TX_Valid;
		assign_row(LLMux_In_Data, BCReq_TX_Data,	LLMUX_PORT_BCREQ);
		LLMux_In_SOF(LLMUX_PORT_BCREQ)					<= BCReq_TX_SOF;
		LLMux_In_EOF(LLMUX_PORT_BCREQ)					<= BCReq_TX_EOF;
		BCReq_TX_Ready													<= LLMux_In_Ready(LLMUX_PORT_BCREQ);
		assign_row(LLMux_In_Meta, BCReq_TX_Meta_DestMACAddress_Data, LLMUX_PORT_BCREQ);
		BCReq_TX_Meta_DestMACAddress_rst				<= LLMux_In_Meta_rev(LLMUX_PORT_BCREQ, META_RST_BIT);
		BCReq_TX_Meta_DestMACAddress_nxt				<= LLMux_In_Meta_rev(LLMUX_PORT_BCREQ, META_DEST_NXT_BIT);
		
		-- LLMux Port 1 - unicast responder
		LLMux_In_Valid(LLMUX_PORT_UCRSP)				<= UCRsp_TX_Valid;
		assign_row(LLMux_In_Data, UCRsp_TX_Data,	LLMUX_PORT_UCRSP);
		LLMux_In_SOF(LLMUX_PORT_UCRSP)					<= UCRsp_TX_SOF;
		LLMux_In_EOF(LLMUX_PORT_UCRSP)					<= UCRsp_TX_EOF;
		UCRsp_TX_Ready													<= LLMux_In_Ready(LLMUX_PORT_UCRSP);
		UCRsp_TX_Meta_DestMACAddress_rst				<= LLMux_In_Meta_rev(LLMUX_PORT_UCRSP, META_RST_BIT);
		UCRsp_TX_Meta_DestMACAddress_nxt				<= LLMux_In_Meta_rev(LLMUX_PORT_UCRSP, META_DEST_NXT_BIT);
		assign_row(LLMux_In_Meta, UCRsp_TX_Meta_DestMACAddress_Data, LLMUX_PORT_UCRSP);

		LLMux : ENTITY L_Global.LocalLink_Mux
			GENERIC MAP (
				PORTS									=> LLMUX_PORTS,
				DATA_BITS							=> Eth_UC_TX_Data'length,
				META_BITS							=> META_BITS,
				META_REV_BITS					=> META_REV_BITS
			)
			PORT MAP (
				Clock									=> Clock,
				Reset									=> Reset,
				
				In_Valid							=> LLMux_In_Valid,
				In_Data								=> LLMux_In_Data,
				In_Meta								=> LLMux_In_Meta,
				In_Meta_rev						=> LLMux_In_Meta_rev,
				In_SOF								=> LLMux_In_SOF,
				In_EOF								=> LLMux_In_EOF,
				In_Ready							=> LLMux_In_Ready,
				
				Out_Valid							=> Eth_UC_TX_Valid,
				Out_Data							=> Eth_UC_TX_Data,
				Out_Meta							=> LLMux_Out_Meta,
				Out_Meta_rev					=> LLMux_Out_Meta_rev,
				Out_SOF								=> Eth_UC_TX_SOF,
				Out_EOF								=> Eth_UC_TX_EOF,
				Out_Ready							=> Eth_UC_TX_Ready
			);
	
		LLMux_Out_Meta_rev(META_RST_BIT)				<= Eth_UC_TX_Meta_rst;
		LLMux_Out_Meta_rev(META_DEST_NXT_BIT)		<= Eth_UC_TX_Meta_DestMACAddress_nxt;
		Eth_UC_TX_Meta_DestMACAddress_Data			<= LLMux_Out_Meta(Eth_UC_TX_Meta_DestMACAddress_Data'range);
	END BLOCK;
END ARCHITECTURE;
