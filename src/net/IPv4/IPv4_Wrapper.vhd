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


ENTITY IPv4_Wrapper IS
	GENERIC (
		CHIPSCOPE_KEEP									: BOOLEAN																:= FALSE;
		PACKET_TYPES										: T_NET_IPV4_PROTOCOL_VECTOR						:= (0 => x"00")
	);
	PORT (
		Clock														: IN	STD_LOGIC;
		Reset														: IN	STD_LOGIC;
		-- to Ethernet
		MAC_TX_Valid										: OUT	STD_LOGIC;
		MAC_TX_Data											: OUT	T_SLV_8;
		MAC_TX_SOF											: OUT	STD_LOGIC;
		MAC_TX_EOF											: OUT	STD_LOGIC;
		MAC_TX_Ready										: IN	STD_LOGIC;
		MAC_TX_Meta_rst									: IN	STD_LOGIC;
		MAC_TX_Meta_DestMACAddress_nxt	: IN	STD_LOGIC;
		MAC_TX_Meta_DestMACAddress_Data	: OUT	T_SLV_8;
		-- from Ethernet
		MAC_RX_Valid										: IN	STD_LOGIC;
		MAC_RX_Data											: IN	T_SLV_8;
		MAC_RX_SOF											: IN	STD_LOGIC;
		MAC_RX_EOF											: IN	STD_LOGIC;
		MAC_RX_Ready										: OUT	STD_LOGIC;
		MAC_RX_Meta_rst									: OUT	STD_LOGIC;
		MAC_RX_Meta_SrcMACAddress_nxt		: OUT	STD_LOGIC;
		MAC_RX_Meta_SrcMACAddress_Data	: IN	T_SLV_8;
		MAC_RX_Meta_DestMACAddress_nxt	: OUT	STD_LOGIC;
		MAC_RX_Meta_DestMACAddress_Data	: IN	T_SLV_8;
		MAC_RX_Meta_EthType							: IN	T_SLV_16;
		-- to ARP
		ARP_IPCache_Query								: OUT	STD_LOGIC;
		ARP_IPCache_IPv4Address_rst			: IN	STD_LOGIC;
		ARP_IPCache_IPv4Address_nxt			: IN	STD_LOGIC;
		ARP_IPCache_IPv4Address_Data		: OUT	T_SLV_8;
		-- from ARP
		ARP_IPCache_Valid								: IN	STD_LOGIC;
		ARP_IPCache_MACAddress_rst			: OUT	STD_LOGIC;
		ARP_IPCache_MACAddress_nxt			: OUT	STD_LOGIC;
		ARP_IPCache_MACAddress_Data			: IN	T_SLV_8;
		-- from upper layer
		TX_Valid												: IN	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_Data													: IN	T_SLVV_8(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_SOF													: IN	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_EOF													: IN	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_Ready												: OUT	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_Meta_rst											: OUT	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_Meta_SrcIPv4Address_nxt			: OUT	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_Meta_SrcIPv4Address_Data			: IN	T_SLVV_8(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_Meta_DestIPv4Address_nxt			: OUT	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_Meta_DestIPv4Address_Data		: IN	T_SLVV_8(PACKET_TYPES'length - 1 DOWNTO 0);
		TX_Meta_Length									: IN	T_SLVV_16(PACKET_TYPES'length - 1 DOWNTO 0);
		-- to upper layer
		RX_Valid												: OUT	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Data													: OUT	T_SLVV_8(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_SOF													: OUT	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_EOF													: OUT	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Ready												: IN	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_rst											: IN	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_SrcMACAddress_nxt				: IN	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_SrcMACAddress_Data			: OUT	T_SLVV_8(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_DestMACAddress_nxt			: IN	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_DestMACAddress_Data			: OUT	T_SLVV_8(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_EthType									: OUT	T_SLVV_16(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_SrcIPv4Address_nxt			: IN	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_SrcIPv4Address_Data			: OUT	T_SLVV_8(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_DestIPv4Address_nxt			: IN	STD_LOGIC_VECTOR(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_DestIPv4Address_Data		: OUT	T_SLVV_8(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_Length									: OUT	T_SLVV_16(PACKET_TYPES'length - 1 DOWNTO 0);
		RX_Meta_Protocol								: OUT	T_SLVV_8(PACKET_TYPES'length - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF IPv4_Wrapper IS
	CONSTANT IPV4_SWITCH_PORTS								: POSITIVE				:= PACKET_TYPES'length;
	
	CONSTANT LLMUX_META_RST_BIT								: NATURAL					:= 0;
	CONSTANT LLMUX_META_SRC_NXT_BIT						: NATURAL					:= 1;
	CONSTANT LLMUX_META_DEST_NXT_BIT					: NATURAL					:= 2;
	
	CONSTANT LLMUX_META_BITS									: NATURAL					:= 40;
	CONSTANT LLMUX_META_REV_BITS							: NATURAL					:= 3;
	
	SIGNAL LLMux_In_Valid											: STD_LOGIC_VECTOR(IPV4_SWITCH_PORTS - 1 DOWNTO 0);
	SIGNAL LLMux_In_Data											: T_SLM(IPV4_SWITCH_PORTS - 1 DOWNTO 0, T_SLV_8'range)											:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLMux_In_Meta											: T_SLM(IPV4_SWITCH_PORTS - 1 DOWNTO 0, LLMUX_META_BITS - 1 DOWNTO 0)				:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLMux_In_Meta_rev									: T_SLM(IPV4_SWITCH_PORTS - 1 DOWNTO 0, LLMUX_META_REV_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLMux_In_SOF												: STD_LOGIC_VECTOR(IPV4_SWITCH_PORTS - 1 DOWNTO 0);
	SIGNAL LLMux_In_EOF												: STD_LOGIC_VECTOR(IPV4_SWITCH_PORTS - 1 DOWNTO 0);
	SIGNAL LLMux_In_Ready											: STD_LOGIC_VECTOR(IPV4_SWITCH_PORTS - 1 DOWNTO 0);
	
	SIGNAL TX_LLMux_Valid											: STD_LOGIC;
	SIGNAL TX_LLMux_Data											: T_SLV_8;
	SIGNAL TX_LLMux_Meta											: STD_LOGIC_VECTOR(LLMUX_META_BITS - 1 DOWNTO 0);
	SIGNAL TX_LLMux_Meta_rev									: STD_LOGIC_VECTOR(LLMUX_META_REV_BITS - 1 DOWNTO 0);
	SIGNAL TX_LLMux_SOF												: STD_LOGIC;
	SIGNAL TX_LLMux_EOF												: STD_LOGIC;
	SIGNAL TX_LLMux_SrcIPv4Address_Data				: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL TX_LLMux_DestIPv4Address_Data			: STD_LOGIC_VECTOR(15 DOWNTO 8);
	SIGNAL TX_LLMux_Length										: STD_LOGIC_VECTOR(31 DOWNTO 16);
	SIGNAL TX_LLMux_Protocol									: STD_LOGIC_VECTOR(39 DOWNTO 32);
	
	SIGNAL IPv4_TX_Ready											: STD_LOGIC;
	SIGNAL IPv4_TX_Meta_rst										: STD_LOGIC;
	SIGNAL IPv4_TX_Meta_SrcIPv4Address_nxt		: STD_LOGIC;
	SIGNAL IPv4_TX_Meta_DestIPv4Address_nxt		: STD_LOGIC;
	
	SIGNAL IPv4_RX_Valid											: STD_LOGIC;
	SIGNAL IPv4_RX_Data												: T_SLV_8;
	SIGNAL IPv4_RX_SOF												: STD_LOGIC;
	SIGNAL IPv4_RX_EOF												: STD_LOGIC;
	
	SIGNAL IPv4_RX_Meta_SrcMACAddress_Data		: T_SLV_8;
	SIGNAL IPv4_RX_Meta_DestMACAddress_Data		: T_SLV_8;
	SIGNAL IPv4_RX_Meta_EthType								: T_SLV_16;
	SIGNAL IPv4_RX_Meta_SrcIPv4Address_Data		: T_SLV_8;
	SIGNAL IPv4_RX_Meta_DestIPv4Address_Data	: T_SLV_8;
	SIGNAL IPv4_RX_Meta_Length								: T_SLV_16;
	SIGNAL IPv4_RX_Meta_Protocol							: T_SLV_8;
	
	CONSTANT LLDEMUX_META_RST_BIT							: NATURAL					:= 0;
	CONSTANT LLDEMUX_META_MACSRC_NXT_BIT			: NATURAL					:= 1;
	CONSTANT LLDEMUX_META_MACDEST_NXT_BIT			: NATURAL					:= 2;
	CONSTANT LLDEMUX_META_IPV4SRC_NXT_BIT			: NATURAL					:= 3;
	CONSTANT LLDEMUX_META_IPV4DEST_NXT_BIT		: NATURAL					:= 4;
	
	CONSTANT LLDEMUX_META_STREAMID_SRCMAC			: NATURAL					:= 0;
	CONSTANT LLDEMUX_META_STREAMID_DESTMAC		: NATURAL					:= 1;
	CONSTANT LLDEMUX_META_STREAMID_ETHTYPE		: NATURAL					:= 2;
	CONSTANT LLDEMUX_META_STREAMID_SRCIP			: NATURAL					:= 3;
	CONSTANT LLDEMUX_META_STREAMID_DESTIP			: NATURAL					:= 4;
	CONSTANT LLDEMUX_META_STREAMID_LENGTH			: NATURAL					:= 5;
	CONSTANT LLDEMUX_META_STREAMID_PROTO			: NATURAL					:= 6;
	
	CONSTANT LLDEMUX_DATA_BITS								: NATURAL					:= 8;							-- 
	CONSTANT LLDEMUX_META_BITS								: T_POSVEC				:= (
		LLDEMUX_META_STREAMID_SRCMAC		=> 8,
		LLDEMUX_META_STREAMID_DESTMAC 	=> 8,
		LLDEMUX_META_STREAMID_ETHTYPE 	=> 16,
		LLDEMUX_META_STREAMID_SRCIP			=> 8,
		LLDEMUX_META_STREAMID_DESTIP		=> 8,
		LLDEMUX_META_STREAMID_LENGTH		=> 16,
		LLDEMUX_META_STREAMID_PROTO			=> 8
	);
	CONSTANT LLDEMUX_META_REV_BITS							: NATURAL					:= 5;							-- sum over all control bits (rst, nxt, nxt, nxt, nxt)
	
	SIGNAL RX_LLDeMux_Ready											: STD_LOGIC;
	SIGNAL RX_LLDeMux_Meta_rst									: STD_LOGIC;
	SIGNAL RX_LLDeMux_Meta_SrcMACAddress_nxt		: STD_LOGIC;
	SIGNAL RX_LLDeMux_Meta_DestMACAddress_nxt		: STD_LOGIC;
	SIGNAL RX_LLDeMux_Meta_SrcIPv4Address_nxt		: STD_LOGIC;
	SIGNAL RX_LLDeMux_Meta_DestIPv4Address_nxt	: STD_LOGIC;
	
	SIGNAL RX_LLDeMux_MetaIn										: STD_LOGIC_VECTOR(isum(LLDEMUX_META_BITS) - 1 DOWNTO 0);
	SIGNAL RX_LLDeMux_MetaIn_rev								: STD_LOGIC_VECTOR(LLDEMUX_META_REV_BITS - 1 DOWNTO 0);
	SIGNAL RX_LLDeMux_Data											: T_SLM(IPV4_SWITCH_PORTS - 1 DOWNTO 0, LLDEMUX_DATA_BITS - 1 DOWNTO 0)				:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL RX_LLDeMux_MetaOut										: T_SLM(IPV4_SWITCH_PORTS - 1 DOWNTO 0, isum(LLDEMUX_META_BITS) - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL RX_LLDeMux_MetaOut_rev								: T_SLM(IPV4_SWITCH_PORTS - 1 DOWNTO 0, LLDEMUX_META_REV_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	
	SIGNAL LLDeMux_Control											: STD_LOGIC_VECTOR(IPV4_SWITCH_PORTS - 1 DOWNTO 0);
	
BEGIN
-- ============================================================================================================================================================
-- TX Path
-- ============================================================================================================================================================
	genTXLLBuf : FOR I IN 0 TO IPV4_SWITCH_PORTS - 1 GENERATE
		CONSTANT TXLLBuf_META_STREAMID_SRC			: NATURAL																									:= 0;
		CONSTANT TXLLBuf_META_STREAMID_DEST			: NATURAL																									:= 1;
		CONSTANT TXLLBuf_META_STREAMID_LEN			: NATURAL																									:= 2;
		CONSTANT TXLLBuf_META_STREAMS						: POSITIVE																								:= 3;		-- Source, Destination, Length
	
		SIGNAL Meta_rst													: STD_LOGIC;
		SIGNAL Meta_nxt													: STD_LOGIC_VECTOR(TXLLBuf_META_STREAMS - 1 DOWNTO 0);
	
		SIGNAL LLBuf_DataOut										: T_SLV_8;
		SIGNAL LLBuf_MetaIn											: T_SLM(TXLLBuf_META_STREAMS - 1 DOWNTO 0, 15 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));
		SIGNAL LLBuf_MetaOut										: T_SLM(TXLLBuf_META_STREAMS - 1 DOWNTO 0, 15 DOWNTO 0);
		SIGNAL LLBuf_Meta_rst										: STD_LOGIC;
		SIGNAL LLBuf_Meta_nxt										: STD_LOGIC_VECTOR(TXLLBuf_META_STREAMS - 1 DOWNTO 0);
		
		SIGNAL LLBuf_Meta_SrcIPv4Address_Data		: STD_LOGIC_VECTOR(TX_LLMux_SrcIPv4Address_Data'range);
		SIGNAL LLBuf_Meta_DestIPv4Address_Data	: STD_LOGIC_VECTOR(TX_LLMux_DestIPv4Address_Data'range);
		SIGNAL LLBuf_Meta_Length								: STD_LOGIC_VECTOR(TX_LLMux_Length'range);
		SIGNAL LLBuf_Meta_Protocol							: STD_LOGIC_VECTOR(TX_LLMux_Protocol'range);
		
		SIGNAL LLMux_MetaIn											: STD_LOGIC_VECTOR(LLBuf_Meta_Protocol'high DOWNTO LLBuf_Meta_SrcIPv4Address_Data'low);
		
	BEGIN
		assign_row(LLBuf_MetaIn, TX_Meta_SrcIPv4Address_Data(I),	TXLLBuf_META_STREAMID_SRC,	0, '0');
		assign_row(LLBuf_MetaIn, TX_Meta_DestIPv4Address_Data(I),	TXLLBuf_META_STREAMID_DEST, 0, '0');
		assign_row(LLBuf_MetaIn, TX_Meta_Length(I),								TXLLBuf_META_STREAMID_LEN);
	
		TX_Meta_rst(I)									<= Meta_rst;
		TX_Meta_SrcIPv4Address_nxt(I)		<= Meta_nxt(TXLLBuf_META_STREAMID_SRC);
		TX_Meta_DestIPv4Address_nxt(I)	<= Meta_nxt(TXLLBuf_META_STREAMID_DEST);
	
		TX_LLBuf : ENTITY L_Global.LocalLink_Buffer
			GENERIC MAP (
				FRAMES												=> 2,
				DATA_BITS											=> 8,
				DATA_FIFO_DEPTH								=> 16,
				META_BITS											=> (TXLLBuf_META_STREAMID_SRC => 8,	TXLLBuf_META_STREAMID_DEST => 8,	TXLLBuf_META_STREAMID_LEN => 16),
				META_FIFO_DEPTH								=> (TXLLBuf_META_STREAMID_SRC => 4,	TXLLBuf_META_STREAMID_DEST => 4,	TXLLBuf_META_STREAMID_LEN => 1)
			)
			PORT MAP (
				Clock													=> Clock,
				Reset													=> Reset,
				
				In_Valid											=> TX_Valid(I),
				In_Data												=> TX_Data(I),
				In_SOF												=> TX_SOF(I),
				In_EOF												=> TX_EOF(I),
				In_Ready											=> TX_Ready(I),
				In_Meta_rst										=> Meta_rst,
				In_Meta_nxt										=> Meta_nxt,
				In_Meta_Data									=> LLBuf_MetaIn,
				
				Out_Valid											=> LLMux_In_Valid(I),
				Out_Data											=> LLBuf_DataOut,
				Out_SOF												=> LLMux_In_SOF(I),
				Out_EOF												=> LLMux_In_EOF(I),
				Out_Ready											=> LLMux_In_Ready(I),
				Out_Meta_rst									=> LLBuf_Meta_rst,
				Out_Meta_nxt									=> LLBuf_Meta_nxt,
				Out_Meta_Data									=> LLBuf_MetaOut
			);
		
		-- unpack pipe metadata to signals
		LLBuf_Meta_SrcIPv4Address_Data												<= get_row(LLBuf_MetaOut, TXLLBuf_META_STREAMID_SRC,	8);
		LLBuf_Meta_DestIPv4Address_Data												<= get_row(LLBuf_MetaOut, TXLLBuf_META_STREAMID_DEST,	8);
		LLBuf_Meta_Length																			<= get_row(LLBuf_MetaOut, TXLLBuf_META_STREAMID_LEN);
		
		LLBuf_Meta_rst																				<= LLMux_In_Meta_rev(I, LLMUX_META_RST_BIT);
		LLBuf_Meta_nxt(TXLLBuf_META_STREAMID_SRC)							<= LLMux_In_Meta_rev(I, LLMUX_META_SRC_NXT_BIT);
		LLBuf_Meta_nxt(TXLLBuf_META_STREAMID_DEST)						<= LLMux_In_Meta_rev(I, LLMUX_META_DEST_NXT_BIT);
		LLBuf_Meta_nxt(TXLLBuf_META_STREAMID_LEN)							<= '0';
		
		-- pack metadata into 1 dim vector
		LLMux_MetaIn(LLBuf_Meta_SrcIPv4Address_Data'range)		<= LLBuf_Meta_SrcIPv4Address_Data;
		LLMux_MetaIn(LLBuf_Meta_DestIPv4Address_Data'range)		<= LLBuf_Meta_DestIPv4Address_Data;
		LLMux_MetaIn(LLBuf_Meta_Length'range)									<= LLBuf_Meta_Length;
		LLMux_MetaIn(LLBuf_Meta_Protocol'range)								<= PACKET_TYPES(I);
		
		-- assign vectors to matrix
		assign_row(LLMux_In_Data, LLBuf_DataOut, I);
		assign_row(LLMux_In_Meta, LLMux_MetaIn, I);
	END GENERATE;


	TX_LLMux : ENTITY L_Global.LocalLink_Mux
		GENERIC MAP (
			PORTS									=> IPV4_SWITCH_PORTS,
			DATA_BITS							=> TX_LLMux_Data'length,
			META_BITS							=> TX_LLMux_Meta'length,
			META_REV_BITS					=> TX_LLMux_Meta_rev'length
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
			
			Out_Valid							=> TX_LLMux_Valid,
			Out_Data							=> TX_LLMux_Data,
			Out_Meta							=> TX_LLMux_Meta,
			Out_Meta_rev					=> TX_LLMux_Meta_rev,
			Out_SOF								=> TX_LLMux_SOF,
			Out_EOF								=> TX_LLMux_EOF,
			Out_Ready							=> IPv4_TX_Ready
		);

	TX_LLMux_SrcIPv4Address_Data								<= TX_LLMux_Meta(TX_LLMux_SrcIPv4Address_Data'range);
	TX_LLMux_DestIPv4Address_Data								<= TX_LLMux_Meta(TX_LLMux_DestIPv4Address_Data'range);
	TX_LLMux_Length															<= TX_LLMux_Meta(TX_LLMux_Length'range);
	TX_LLMux_Protocol														<= TX_LLMux_Meta(TX_LLMux_Protocol'range);
	
	TX_LLMux_Meta_rev(LLMUX_META_RST_BIT)				<= IPv4_TX_Meta_rst;
	TX_LLMux_Meta_rev(LLMUX_META_SRC_NXT_BIT)		<= IPv4_TX_Meta_SrcIPv4Address_nxt;
	TX_LLMux_Meta_rev(LLMUX_META_DEST_NXT_BIT)	<= IPv4_TX_Meta_DestIPv4Address_nxt;

	IPv4_TX : ENTITY L_Ethernet.IPv4_TX
		GENERIC MAP (
			CHIPSCOPE_KEEP								=> CHIPSCOPE_KEEP
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			In_Valid											=> TX_LLMux_Valid,
			In_Data												=> TX_LLMux_Data,
			In_SOF												=> TX_LLMux_SOF,
			In_EOF												=> TX_LLMux_EOF,
			In_Ready											=> IPv4_TX_Ready,
			In_Meta_rst										=> IPv4_TX_Meta_rst,
			In_Meta_SrcIPv4Address_nxt		=> IPv4_TX_Meta_SrcIPv4Address_nxt,
			In_Meta_SrcIPv4Address_Data		=> TX_LLMux_SrcIPv4Address_Data,
			In_Meta_DestIPv4Address_nxt		=> IPv4_TX_Meta_DestIPv4Address_nxt,
			In_Meta_DestIPv4Address_Data	=> TX_LLMux_DestIPv4Address_Data,
			In_Meta_Length								=> TX_LLMux_Length,
			In_Meta_Protocol							=> TX_LLMux_Protocol,
			
			ARP_IPCache_Query							=> ARP_IPCache_Query,
			ARP_IPCache_IPv4Address_rst		=> ARP_IPCache_IPv4Address_rst,
			ARP_IPCache_IPv4Address_nxt		=> ARP_IPCache_IPv4Address_nxt,
			ARP_IPCache_IPv4Address_Data	=> ARP_IPCache_IPv4Address_Data,
			
			ARP_IPCache_Valid							=> ARP_IPCache_Valid,
			ARP_IPCache_MACAddress_rst		=> ARP_IPCache_MACAddress_rst,
			ARP_IPCache_MACAddress_nxt		=> ARP_IPCache_MACAddress_nxt,
			ARP_IPCache_MACAddress_Data		=> ARP_IPCache_MACAddress_Data,
			
			Out_Valid											=> MAC_TX_Valid,
			Out_Data											=> MAC_TX_Data,
			Out_SOF												=> MAC_TX_SOF,
			Out_EOF												=> MAC_TX_EOF,
			Out_Ready											=> MAC_TX_Ready,
			Out_Meta_rst									=> MAC_TX_Meta_rst,
			Out_Meta_DestMACAddress_nxt		=> MAC_TX_Meta_DestMACAddress_nxt,
			Out_Meta_DestMACAddress_Data	=> MAC_TX_Meta_DestMACAddress_Data
		);

-- ============================================================================================================================================================
-- RX Path
-- ============================================================================================================================================================
	IPv4_RX : ENTITY L_Ethernet.IPv4_RX
		GENERIC MAP (
			CHIPSCOPE_KEEP									=> CHIPSCOPE_KEEP
		)
		PORT MAP (
			Clock														=> Clock,
			Reset														=> Reset,
		
			In_Valid												=> MAC_RX_Valid,
			In_Data													=> MAC_RX_Data,
			In_SOF													=> MAC_RX_SOF,
			In_EOF													=> MAC_RX_EOF,
			In_Ready												=> MAC_RX_Ready,
			In_Meta_rst											=> MAC_RX_Meta_rst,
			In_Meta_SrcMACAddress_nxt				=> MAC_RX_Meta_SrcMACAddress_nxt,
			In_Meta_SrcMACAddress_Data			=> MAC_RX_Meta_SrcMACAddress_Data,
			In_Meta_DestMACAddress_nxt			=> MAC_RX_Meta_DestMACAddress_nxt,
			In_Meta_DestMACAddress_Data			=> MAC_RX_Meta_DestMACAddress_Data,
			In_Meta_EthType									=> MAC_RX_Meta_EthType,
			
			Out_Valid												=> IPv4_RX_Valid,
			Out_Data												=> IPv4_RX_Data,
			Out_SOF													=> IPv4_RX_SOF,
			Out_EOF													=> IPv4_RX_EOF,
			Out_Ready												=> RX_LLDeMux_Ready,
			Out_Meta_rst										=> RX_LLDeMux_Meta_rst,
			Out_Meta_SrcMACAddress_nxt			=> RX_LLDeMux_Meta_SrcMACAddress_nxt,
			Out_Meta_SrcMACAddress_Data			=> IPv4_RX_Meta_SrcMACAddress_Data,
			Out_Meta_DestMACAddress_nxt			=> RX_LLDeMux_Meta_DestMACAddress_nxt,
			Out_Meta_DestMACAddress_Data		=> IPv4_RX_Meta_DestMACAddress_Data,
			Out_Meta_EthType								=> IPv4_RX_Meta_EthType,
			Out_Meta_SrcIPv4Address_nxt			=> RX_LLDeMux_Meta_SrcIPv4Address_nxt,
			Out_Meta_SrcIPv4Address_Data		=> IPv4_RX_Meta_SrcIPv4Address_Data,
			Out_Meta_DestIPv4Address_nxt		=> RX_LLDeMux_Meta_DestIPv4Address_nxt,
			Out_Meta_DestIPv4Address_Data		=> IPv4_RX_Meta_DestIPv4Address_Data,
			Out_Meta_Length									=> IPv4_RX_Meta_Length,
			Out_Meta_Protocol								=> IPv4_RX_Meta_Protocol
		);

	genLLDeMux_Control : FOR I IN 0 TO IPV4_SWITCH_PORTS - 1 GENERATE
		LLDeMux_Control(I)		<= to_sl(IPv4_RX_Meta_Protocol = PACKET_TYPES(I));
	END GENERATE;
	
	-- decompress meta_rev vector to single bits
	RX_LLDeMux_Meta_rst									<= RX_LLDeMux_MetaIn_rev(LLDEMUX_META_RST_BIT);
	RX_LLDeMux_Meta_SrcMACAddress_nxt		<= RX_LLDeMux_MetaIn_rev(LLDEMUX_META_MACSRC_NXT_BIT);
	RX_LLDeMux_Meta_DestMACAddress_nxt	<= RX_LLDeMux_MetaIn_rev(LLDEMUX_META_MACDEST_NXT_BIT);
	RX_LLDeMux_Meta_SrcIPv4Address_nxt	<= RX_LLDeMux_MetaIn_rev(LLDEMUX_META_IPV4SRC_NXT_BIT);
	RX_LLDeMux_Meta_DestIPv4Address_nxt	<= RX_LLDeMux_MetaIn_rev(LLDEMUX_META_IPV4DEST_NXT_BIT);
	
	-- compress meta data vectors to single meta data vector
	RX_LLDeMux_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCMAC)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCMAC))		<= IPv4_RX_Meta_SrcMACAddress_Data;
	RX_LLDeMux_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTMAC)	DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTMAC))	<= IPv4_RX_Meta_DestMACAddress_Data;
	RX_LLDeMux_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_ETHTYPE)	DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_ETHTYPE))	<= IPv4_RX_Meta_EthType;
	RX_LLDeMux_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCIP)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCIP))		<= IPv4_RX_Meta_SrcIPv4Address_Data;
	RX_LLDeMux_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTIP)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTIP))		<= IPv4_RX_Meta_DestIPv4Address_Data;
	RX_LLDeMux_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_LENGTH)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_LENGTH))		<= IPv4_RX_Meta_Length;
	RX_LLDeMux_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_PROTO)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_PROTO))		<= IPv4_RX_Meta_Protocol;
	
	RX_LLDeMux : ENTITY L_Global.LocalLink_DeMux
		GENERIC MAP (
			PORTS										=> IPV4_SWITCH_PORTS,
			DATA_BITS								=> LLDEMUX_DATA_BITS,
			META_BITS								=> isum(LLDEMUX_META_BITS),
			META_REV_BITS						=> LLDEMUX_META_REV_BITS
		)
		PORT MAP (
			Clock										=> Clock,
			Reset										=> Reset,

			DeMuxControl						=> LLDeMux_Control,

			In_Valid								=> IPv4_RX_Valid,
			In_Data									=> IPv4_RX_Data,
			In_Meta									=> RX_LLDeMux_MetaIn,
			In_Meta_rev							=> RX_LLDeMux_MetaIn_rev,
			In_SOF									=> IPv4_RX_SOF,
			In_EOF									=> IPv4_RX_EOF,
			In_Ready								=> RX_LLDeMux_Ready,
			
			Out_Valid								=> RX_Valid,
			Out_Data								=> RX_LLDeMux_Data,
			Out_Meta								=> RX_LLDeMux_MetaOut,
			Out_Meta_rev						=> RX_LLDeMux_MetaOut_rev,
			Out_SOF									=> RX_SOF,
			Out_EOF									=> RX_EOF,
			Out_Ready								=> RX_Ready
		);

	assign_col(RX_LLDeMux_MetaOut_rev, RX_Meta_rst,									LLDEMUX_META_RST_BIT);
	assign_col(RX_LLDeMux_MetaOut_rev, RX_Meta_SrcMACAddress_nxt,		LLDEMUX_META_MACSRC_NXT_BIT);
	assign_col(RX_LLDeMux_MetaOut_rev, RX_Meta_DestMACAddress_nxt,	LLDEMUX_META_MACDEST_NXT_BIT);
	assign_col(RX_LLDeMux_MetaOut_rev, RX_Meta_SrcIPv4Address_nxt,	LLDEMUX_META_IPV4SRC_NXT_BIT);
	assign_col(RX_LLDeMux_MetaOut_rev, RX_Meta_DestIPv4Address_nxt, LLDEMUX_META_IPV4DEST_NXT_BIT);

	-- new slm_slice funtion to avoid generate statement for wiring => cut multiple columns over all rows and convert to slvv_*
	RX_Data													<= to_slvv_8(RX_LLDeMux_Data);
	RX_Meta_SrcMACAddress_Data			<= to_slvv_8(	slm_slice_cols(RX_LLDeMux_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCMAC),	high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCMAC)));
	RX_Meta_DestMACAddress_Data			<= to_slvv_8(	slm_slice_cols(RX_LLDeMux_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTMAC),	high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTMAC)));
	RX_Meta_EthType									<= to_slvv_16(slm_slice_cols(RX_LLDeMux_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_ETHTYPE),	high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_ETHTYPE)));
	RX_Meta_SrcIPv4Address_Data			<= to_slvv_8(	slm_slice_cols(RX_LLDeMux_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCIP),		high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCIP)));
	RX_Meta_DestIPv4Address_Data		<= to_slvv_8(	slm_slice_cols(RX_LLDeMux_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTIP),	high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTIP)));
	RX_Meta_Length									<= to_slvv_16(slm_slice_cols(RX_LLDeMux_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_LENGTH),	high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_LENGTH)));
	RX_Meta_Protocol								<= to_slvv_8(	slm_slice_cols(RX_LLDeMux_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_PROTO),		high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_PROTO)));
END ARCHITECTURE;
