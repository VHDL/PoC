LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY UDP_Wrapper IS
	GENERIC (
		DEBUG															: BOOLEAN																							:= FALSE;
		IP_VERSION												: POSITIVE																						:= 6;
		PORTPAIRS													: T_NET_UDP_PORTPAIR_VECTOR														:= (0 => (x"0000", x"0000"))
	);
	PORT (
		Clock															: IN	STD_LOGIC;
		Reset															: IN	STD_LOGIC;
		-- from IP layer
		IP_TX_Valid												: OUT	STD_LOGIC;
		IP_TX_Data												: OUT	T_SLV_8;
		IP_TX_SOF													: OUT	STD_LOGIC;
		IP_TX_EOF													: OUT	STD_LOGIC;
		IP_TX_Ready												: IN	STD_LOGIC;
		IP_TX_Meta_rst										: IN	STD_LOGIC;
		IP_TX_Meta_SrcIPAddress_nxt				: IN	STD_LOGIC;
		IP_TX_Meta_SrcIPAddress_Data			: OUT	T_SLV_8;
		IP_TX_Meta_DestIPAddress_nxt			: IN	STD_LOGIC;
		IP_TX_Meta_DestIPAddress_Data			: OUT	T_SLV_8;
		IP_TX_Meta_Length									: OUT	T_SLV_16;
		-- to IP layer
		IP_RX_Valid												: IN	STD_LOGIC;
		IP_RX_Data												: IN	T_SLV_8;
		IP_RX_SOF													: IN	STD_LOGIC;
		IP_RX_EOF													: IN	STD_LOGIC;
		IP_RX_Ready												: OUT	STD_LOGIC;
		IP_RX_Meta_rst										: OUT	STD_LOGIC;
		IP_RX_Meta_SrcMACAddress_nxt			: OUT	STD_LOGIC;
		IP_RX_Meta_SrcMACAddress_Data			: IN	T_SLV_8;
		IP_RX_Meta_DestMACAddress_nxt			: OUT	STD_LOGIC;
		IP_RX_Meta_DestMACAddress_Data		: IN	T_SLV_8;
		IP_RX_Meta_EthType								: IN	T_SLV_16;
		IP_RX_Meta_SrcIPAddress_nxt				: OUT	STD_LOGIC;
		IP_RX_Meta_SrcIPAddress_Data			: IN	T_SLV_8;
		IP_RX_Meta_DestIPAddress_nxt			: OUT	STD_LOGIC;
		IP_RX_Meta_DestIPAddress_Data			: IN	T_SLV_8;
--		IP_RX_Meta_TrafficClass						: IN	T_SLV_8;
--		IP_RX_Meta_FlowLabel							: IN	T_SLV_24;
		IP_RX_Meta_Length									: IN	T_SLV_16;
		IP_RX_Meta_Protocol								: IN	T_SLV_8;
		-- from upper layer
		TX_Valid													: IN	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Data														: IN	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
		TX_SOF														: IN	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		TX_EOF														: IN	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Ready													: OUT	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Meta_rst												: OUT	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Meta_SrcIPAddress_nxt					: OUT	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Meta_SrcIPAddress_Data					: IN	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Meta_DestIPAddress_nxt					: OUT	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Meta_DestIPAddress_Data				: IN	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Meta_SrcPort										: IN	T_SLVV_16(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Meta_DestPort									: IN	T_SLVV_16(PORTPAIRS'length - 1 DOWNTO 0);
		TX_Meta_Length										: IN	T_SLVV_16(PORTPAIRS'length - 1 DOWNTO 0);
		-- to upper layer
		RX_Valid													: OUT	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Data														: OUT	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
		RX_SOF														: OUT	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		RX_EOF														: OUT	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Ready													: IN	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_rst												: IN	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_SrcMACAddress_nxt					: IN	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_SrcMACAddress_Data				: OUT	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_DestMACAddress_nxt				: IN	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_DestMACAddress_Data				: OUT	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_EthType										: OUT	T_SLVV_16(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_SrcIPAddress_nxt					: IN	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_SrcIPAddress_Data					: OUT	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_DestIPAddress_nxt					: IN	STD_LOGIC_VECTOR(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_DestIPAddress_Data				: OUT	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
--		RX_Meta_TrafficClass							: OUT	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
--		RX_Meta_FlowLabel									: OUT	T_SLVV_24(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_Length										: OUT	T_SLVV_16(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_Protocol									: OUT	T_SLVV_8(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_SrcPort										: OUT	T_SLVV_16(PORTPAIRS'length - 1 DOWNTO 0);
		RX_Meta_DestPort									: OUT	T_SLVV_16(PORTPAIRS'length - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF UDP_Wrapper IS
	CONSTANT UDP_SWITCH_PORTS										: POSITIVE				:= PORTPAIRS'length;
	
	CONSTANT LLMUX_META_RST_BIT									: NATURAL					:= 0;
	CONSTANT LLMUX_META_SRCIP_NXT_BIT						: NATURAL					:= 1;
	CONSTANT LLMUX_META_DESTIP_NXT_BIT					: NATURAL					:= 2;
	
	CONSTANT LLMUX_META_REV_BITS								: NATURAL					:= 3;
	
	CONSTANT LLMUX_META_STREAMID_SRCIP					: NATURAL					:= 0;
	CONSTANT LLMUX_META_STREAMID_DESTIP					: NATURAL					:= 1;
	CONSTANT LLMUX_META_STREAMID_SRCPORT				: NATURAL					:= 2;
	CONSTANT LLMUX_META_STREAMID_DESTPORT				: NATURAL					:= 3;
	CONSTANT LLMUX_META_STREAMID_LENGTH					: NATURAL					:= 4;
	
	CONSTANT LLMUX_META_BITS										: T_POSVEC				:= (
		LLMUX_META_STREAMID_SRCIP			=> 8,
		LLMUX_META_STREAMID_DESTIP		=> 8,
		LLMUX_META_STREAMID_SRCPORT		=> 16,
		LLMUX_META_STREAMID_DESTPORT	=> 16,
		LLMUX_META_STREAMID_LENGTH		=> 16
	);
	
	SIGNAL LLMux_In_Valid												: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);
	SIGNAL LLMux_In_Data												: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, T_SLV_8'range)												:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLMux_In_Meta												: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, isum(LLMUX_META_BITS) - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLMux_In_Meta_rev										: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, LLMUX_META_REV_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLMux_In_SOF													: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);
	SIGNAL LLMux_In_EOF													: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);
	SIGNAL LLMux_In_Ready												: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);
	
	SIGNAL LLMux_Out_Valid											: STD_LOGIC;
	SIGNAL LLMux_Out_Data												: T_SLV_8;
	SIGNAL LLMux_Out_Meta												: STD_LOGIC_VECTOR(isum(LLMUX_META_BITS) - 1 DOWNTO 0);
	SIGNAL LLMux_Out_Meta_rev										: STD_LOGIC_VECTOR(LLMUX_META_REV_BITS - 1 DOWNTO 0);
	SIGNAL LLMux_Out_SOF												: STD_LOGIC;
	SIGNAL LLMux_Out_EOF												: STD_LOGIC;
	SIGNAL LLMux_Out_SrcIPAddress_Data					: T_SLV_8;
	SIGNAL LLMux_Out_DestIPAddress_Data					: T_SLV_8;
	SIGNAL LLMux_Out_Length											: T_SLV_16;
	SIGNAL LLMux_Out_Protocol										: T_SLV_8;
	
	CONSTANT TX_FCS_META_STREAMID_SRCIP					: NATURAL					:= 0;
	CONSTANT TX_FCS_META_STREAMID_DESTIP				: NATURAL					:= 1;
	CONSTANT TX_FCS_META_STREAMID_SRCPORT				: NATURAL					:= 2;
	CONSTANT TX_FCS_META_STREAMID_DESTPORT			: NATURAL					:= 3;
--	CONSTANT TX_FCS_META_STREAMID_CHKSUM				: NATURAL					:= 4;
--	CONSTANT TX_FCS_META_STREAMID_LEN						: NATURAL					:= 5;
	CONSTANT TX_FCS_META_STREAMS								: POSITIVE				:= 4;		-- Source, Destination, Length
	
	CONSTANT TX_FCS_META_BITS                   : T_POSVEC				:= (
		TX_FCS_META_STREAMID_SRCIP		=> 8,
		TX_FCS_META_STREAMID_DESTIP		=> 8,
		TX_FCS_META_STREAMID_SRCPORT	=> 16,
		TX_FCS_META_STREAMID_DESTPORT	=> 16,
		TX_FCS_META_STREAMID_LEN			=> 16
	);
		
	CONSTANT TX_FCS_META_FIFO_DEPTHS             : T_POSVEC				:= (
		TX_FCS_META_STREAMID_SRCIP		=> ite((IP_VERSION = 6), 16, 4),
		TX_FCS_META_STREAMID_DESTIP		=> ite((IP_VERSION = 6), 16, 4),
		TX_FCS_META_STREAMID_SRCPORT	=> 1,
		TX_FCS_META_STREAMID_DESTPORT	=> 1,
		TX_FCS_META_STREAMID_LEN			=> 1
	);
	
	SIGNAL TX_FCS_Valid													: STD_LOGIC;
	SIGNAL TX_FCS_Data													: T_SLV_8;
	SIGNAL TX_FCS_SOF														: STD_LOGIC;
	SIGNAL TX_FCS_EOF														: STD_LOGIC;
	SIGNAL TX_FCS_MetaOut_rst										: STD_LOGIC;
	SIGNAL TX_FCS_MetaOut_nxt										: STD_LOGIC_VECTOR(TX_FCS_META_STREAMS - 1 DOWNTO 0);
	SIGNAL TX_FCS_MetaOut_Data									: T_SLM(TX_FCS_META_STREAMS - 1 DOWNTO 0, 15 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL TX_FCS_Meta_SrcIPAddress_Data				: T_SLV_8;
	SIGNAL TX_FCS_Meta_DestIPAddress_Data				: T_SLV_8;
	SIGNAL TX_FCS_Meta_SrcPort									: T_SLV_16;
	SIGNAL TX_FCS_Meta_DestPort									: T_SLV_16;
	SIGNAL TX_FCS_Meta_Checksum									: T_SLV_16;
	SIGNAL TX_FCS_Meta_Length										: T_SLV_16;
	
	SIGNAL TX_FCS_Ready													: STD_LOGIC;
	SIGNAL TX_FCS_MetaIn_rst										: STD_LOGIC;
	SIGNAL TX_FCS_MetaIn_nxt										: STD_LOGIC_VECTOR(TX_FCS_META_STREAMS - 1 DOWNTO 0);
	SIGNAL TX_FCS_MetaIn_Data										: T_SLM(TX_FCS_META_STREAMS - 1 DOWNTO 0, 15 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	
	SIGNAL UDP_TX_Ready													: STD_LOGIC;
	SIGNAL UDP_TX_Meta_rst											: STD_LOGIC;
	SIGNAL UDP_TX_Meta_SrcIPAddress_nxt					: STD_LOGIC;
	SIGNAL UDP_TX_Meta_DestIPAddress_nxt				: STD_LOGIC;
	
	SIGNAL UDP_RX_Valid													: STD_LOGIC;
	SIGNAL UDP_RX_Data													: T_SLV_8;
	SIGNAL UDP_RX_SOF														: STD_LOGIC;
	SIGNAL UDP_RX_EOF														: STD_LOGIC;
	
	SIGNAL UDP_RX_Meta_SrcMACAddress_Data				: T_SLV_8;
	SIGNAL UDP_RX_Meta_DestMACAddress_Data			: T_SLV_8;
	SIGNAL UDP_RX_Meta_EthType									: T_SLV_16;
	SIGNAL UDP_RX_Meta_SrcIPAddress_Data				: T_SLV_8;
	SIGNAL UDP_RX_Meta_DestIPAddress_Data				: T_SLV_8;
	SIGNAL UDP_RX_Meta_Length										: T_SLV_16;
	SIGNAL UDP_RX_Meta_Protocol									: T_SLV_8;
	SIGNAL UDP_RX_Meta_SrcPort									: T_SLV_16;
	SIGNAL UDP_RX_Meta_DestPort									: T_SLV_16;
	
	CONSTANT LLDEMUX_META_RST_BIT								: NATURAL					:= 0;
	CONSTANT LLDEMUX_META_MACSRC_NXT_BIT				: NATURAL					:= 1;
	CONSTANT LLDEMUX_META_MACDEST_NXT_BIT				: NATURAL					:= 2;
	CONSTANT LLDEMUX_META_IPSRC_NXT_BIT					: NATURAL					:= 3;
	CONSTANT LLDEMUX_META_IPDEST_NXT_BIT				: NATURAL					:= 4;
	
	CONSTANT LLDEMUX_META_STREAMID_SRCMAC				: NATURAL					:= 0;
	CONSTANT LLDEMUX_META_STREAMID_DESTMAC			: NATURAL					:= 1;
	CONSTANT LLDEMUX_META_STREAMID_ETHTYPE			: NATURAL					:= 2;
	CONSTANT LLDEMUX_META_STREAMID_SRCIP				: NATURAL					:= 3;
	CONSTANT LLDEMUX_META_STREAMID_DESTIP				: NATURAL					:= 4;
	CONSTANT LLDEMUX_META_STREAMID_LENGTH				: NATURAL					:= 5;
	CONSTANT LLDEMUX_META_STREAMID_PROTO				: NATURAL					:= 6;
	CONSTANT LLDEMUX_META_STREAMID_SRCPORT			: NATURAL					:= 7;
	CONSTANT LLDEMUX_META_STREAMID_DESTPORT			: NATURAL					:= 8;
	
	CONSTANT LLDEMUX_DATA_BITS									: NATURAL					:= 8;							-- 
	CONSTANT LLDEMUX_META_BITS									: T_POSVEC				:= (
		LLDEMUX_META_STREAMID_SRCMAC		=> 8,
		LLDEMUX_META_STREAMID_DESTMAC 	=> 8,
		LLDEMUX_META_STREAMID_ETHTYPE 	=> 16,
		LLDEMUX_META_STREAMID_SRCIP			=> 8,
		LLDEMUX_META_STREAMID_DESTIP		=> 8,
		LLDEMUX_META_STREAMID_LENGTH		=> 16,
		LLDEMUX_META_STREAMID_PROTO			=> 8,
		LLDEMUX_META_STREAMID_SRCPORT		=> 16,
		LLDEMUX_META_STREAMID_DESTPORT	=> 16
	);
	CONSTANT LLDEMUX_META_REV_BITS							: NATURAL					:= 5;							-- sum over all control bits (rst, nxt, nxt, nxt, nxt)
	
	SIGNAL LLDeMux_Out_Ready										: STD_LOGIC;
	SIGNAL LLDeMux_Out_Meta_rst									: STD_LOGIC;
	SIGNAL LLDeMux_Out_Meta_SrcMACAddress_nxt		: STD_LOGIC;
	SIGNAL LLDeMux_Out_Meta_DestMACAddress_nxt	: STD_LOGIC;
	SIGNAL LLDeMux_Out_Meta_SrcIPAddress_nxt		: STD_LOGIC;
	SIGNAL LLDeMux_Out_Meta_DestIPAddress_nxt		: STD_LOGIC;
	
	SIGNAL LLDeMux_Out_MetaIn										: STD_LOGIC_VECTOR(isum(LLDEMUX_META_BITS) - 1 DOWNTO 0);
	SIGNAL LLDeMux_Out_MetaIn_rev								: STD_LOGIC_VECTOR(LLDEMUX_META_REV_BITS - 1 DOWNTO 0);
	SIGNAL LLDeMux_Out_Data											: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, LLDEMUX_DATA_BITS - 1 DOWNTO 0)				:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLDeMux_Out_MetaOut									: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, isum(LLDEMUX_META_BITS) - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLDeMux_Out_MetaOut_rev							: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, LLDEMUX_META_REV_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	
	SIGNAL LLDeMux_Control											: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);

BEGIN
	ASSERT ((IP_VERSION = 4) OR (IP_VERSION = 6)) REPORT "Unsupported Internet Protocol (IP) version."								SEVERITY ERROR;

-- ============================================================================================================================================================
-- TX Path
-- ============================================================================================================================================================
	LLMux_In_Data		<= to_slm(TX_Data);
	
	genLLMuxIn : FOR I IN 0 TO UDP_SWITCH_PORTS - 1 GENERATE
		SIGNAL Meta			: STD_LOGIC_VECTOR(isum(LLMUX_META_BITS) - 1 DOWNTO 0);
	BEGIN
		Meta(high(LLMUX_META_BITS, LLMUX_META_STREAMID_SRCIP)			DOWNTO	low(LLMUX_META_BITS, LLMUX_META_STREAMID_SRCIP))		<= TX_Meta_SrcIPAddress_Data(I);
		Meta(high(LLMUX_META_BITS, LLMUX_META_STREAMID_DESTIP)		DOWNTO	low(LLMUX_META_BITS, LLMUX_META_STREAMID_DESTIP))		<= TX_Meta_DestIPAddress_Data(I);
		Meta(high(LLMUX_META_BITS, LLMUX_META_STREAMID_SRCPORT)		DOWNTO	low(LLMUX_META_BITS, LLMUX_META_STREAMID_SRCPORT))	<= TX_Meta_SrcPort(I);
		Meta(high(LLMUX_META_BITS, LLMUX_META_STREAMID_DESTPORT)	DOWNTO	low(LLMUX_META_BITS, LLMUX_META_STREAMID_DESTPORT))	<= TX_Meta_DestPort(I);
		Meta(high(LLMUX_META_BITS, LLMUX_META_STREAMID_LENGTH)		DOWNTO	low(LLMUX_META_BITS, LLMUX_META_STREAMID_LENGTH))		<= TX_Meta_Length(I);
		
		assign_row(LLMux_In_Meta, Meta,	I);
	END GENERATE;
	
	TX_Meta_rst									<= get_col(LLMux_In_Meta_rev,	LLMUX_META_RST_BIT);
	TX_Meta_SrcIPAddress_nxt		<= get_col(LLMux_In_Meta_rev,	LLMUX_META_SRCIP_NXT_BIT);
	TX_Meta_DestIPAddress_nxt		<= get_col(LLMux_In_Meta_rev,	LLMUX_META_DESTIP_NXT_BIT);

	TX_LLMux : ENTITY PoC.stream_Mux
		GENERIC MAP (
			PORTS									=> UDP_SWITCH_PORTS,
			DATA_BITS							=> LLMux_Out_Data'length,
			META_BITS							=> isum(LLMUX_META_BITS),
			META_REV_BITS					=> LLMUX_META_REV_BITS
		)
		PORT MAP (
			Clock									=> Clock,
			Reset									=> Reset,
			
			In_Valid							=> TX_Valid,
			In_Data								=> LLMux_In_Data,
			In_Meta								=> LLMux_In_Meta,
			In_Meta_rev						=> LLMux_In_Meta_rev,
			In_SOF								=> TX_SOF,
			In_EOF								=> TX_EOF,
			In_Ready							=> TX_Ready,
			
			Out_Valid							=> LLMux_Out_Valid,
			Out_Data							=> LLMux_Out_Data,
			Out_Meta							=> LLMux_Out_Meta,
			Out_Meta_rev					=> LLMux_Out_Meta_rev,
			Out_SOF								=> LLMux_Out_SOF,
			Out_EOF								=> LLMux_Out_EOF,
			Out_Ready							=> TX_FCS_Ready
		);

	LLMux_Out_Meta_rev(LLMUX_META_RST_BIT)				<= TX_FCS_MetaIn_rst;
	LLMux_Out_Meta_rev(LLMUX_META_SRCIP_NXT_BIT)	<= TX_FCS_MetaIn_nxt(TX_FCS_META_STREAMID_SRCIP);
	LLMux_Out_Meta_rev(LLMUX_META_DESTIP_NXT_BIT)	<= TX_FCS_MetaIn_nxt(TX_FCS_META_STREAMID_DESTIP);

--	assign_row(TX_FCS_MetaIn_Data, LLMux_Out_Meta(high(LLMUX_META_BITS, LLMUX_META_STREAMID_SRCIP)		DOWNTO low(LLMUX_META_BITS, LLMUX_META_STREAMID_SRCIP)),		TX_FCS_META_STREAMID_SRCIP);--,		 0, '0');
--	assign_row(TX_FCS_MetaIn_Data, LLMux_Out_Meta(high(LLMUX_META_BITS, LLMUX_META_STREAMID_DESTIP)		DOWNTO low(LLMUX_META_BITS, LLMUX_META_STREAMID_DESTIP)),		TX_FCS_META_STREAMID_DESTIP);--,	 0, '0');
--	assign_row(TX_FCS_MetaIn_Data, LLMux_Out_Meta(high(LLMUX_META_BITS, LLMUX_META_STREAMID_SRCPORT)	DOWNTO low(LLMUX_META_BITS, LLMUX_META_STREAMID_SRCPORT)),	TX_FCS_META_STREAMID_SRCPORT);--,	 0, '0');
--	assign_row(TX_FCS_MetaIn_Data, LLMux_Out_Meta(high(LLMUX_META_BITS, LLMUX_META_STREAMID_DESTPORT)	DOWNTO low(LLMUX_META_BITS, LLMUX_META_STREAMID_DESTPORT)),	TX_FCS_META_STREAMID_DESTPORT);--, 0, '0');

	TX_FCS_MetaIn_Data	<= LLMux_Out_Meta;

	TX_FCS : ENTITY PoC.net_FrameChecksum
		GENERIC MAP (
			MAX_FRAMES										=> 4,
			MAX_FRAME_LENGTH							=> 2048,
			META_BITS											=> TX_FCS_META_BITS,
			META_FIFO_DEPTH								=> TX_FCS_META_FIFO_DEPTHS
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			In_Valid											=> LLMux_Out_Valid,
			In_Data												=> LLMux_Out_Data,
			In_SOF												=> LLMux_Out_SOF,
			In_EOF												=> LLMux_Out_EOF,
			In_Ready											=> TX_FCS_Ready,
			In_Meta_rst										=> TX_FCS_MetaIn_rst,
			In_Meta_nxt										=> TX_FCS_MetaIn_nxt,
			In_Meta_Data									=> TX_FCS_MetaIn_Data,
			
			Out_Valid											=> TX_FCS_Valid,
			Out_Data											=> TX_FCS_Data,
			Out_SOF												=> TX_FCS_SOF,
			Out_EOF												=> TX_FCS_EOF,
			Out_Ready											=> UDP_TX_Ready,
			Out_Meta_rst									=> TX_FCS_MetaOut_rst,
			Out_Meta_nxt									=> TX_FCS_MetaOut_nxt,
			Out_Meta_Data									=> TX_FCS_MetaOut_Data,
			Out_Meta_Checksum							=> TX_FCS_Meta_Checksum,
			Out_Meta_Length								=> TX_FCS_Meta_Length
		);

	TX_FCS_MetaOut_rst																<= UDP_TX_Meta_rst;
	TX_FCS_MetaOut_nxt(TX_FCS_META_STREAMID_SRCIP)		<= UDP_TX_Meta_SrcIPAddress_nxt;
	TX_FCS_MetaOut_nxt(TX_FCS_META_STREAMID_DESTIP)		<= UDP_TX_Meta_DestIPAddress_nxt;
	TX_FCS_MetaOut_nxt(TX_FCS_META_STREAMID_SRCPORT)	<= '0';
	TX_FCS_MetaOut_nxt(TX_FCS_META_STREAMID_DESTPORT)	<= '0';

	TX_FCS_Meta_SrcIPAddress_Data			<= get_row(TX_FCS_MetaOut_Data, TX_FCS_META_STREAMID_SRCIP,			8);
	TX_FCS_Meta_DestIPAddress_Data		<= get_row(TX_FCS_MetaOut_Data, TX_FCS_META_STREAMID_DESTIP,		8);
	TX_FCS_Meta_SrcPort								<= get_row(TX_FCS_MetaOut_Data, TX_FCS_META_STREAMID_SRCPORT,	 16);
	TX_FCS_Meta_DestPort							<= get_row(TX_FCS_MetaOut_Data, TX_FCS_META_STREAMID_DESTPORT, 16);
--	TX_FCS_Meta_Length								<= get_row(TX_FCS_MetaOut_Data, TX_FCS_META_STREAMID_LEN,			 16);
--	TX_FCS_Meta_Checksum							<= get_row(TX_FCS_MetaOut_Data, TX_FCS_META_STREAMID_CHKSUM,	 16);

	TX_UDP : ENTITY PoC.UDP_TX
		GENERIC MAP (
			DEBUG												=> DEBUG,
			IP_VERSION									=> IP_VERSION
		)
		PORT MAP (
			Clock												=> Clock,
			Reset												=> Reset,
			
			In_Valid										=> TX_FCS_Valid,
			In_Data											=> TX_FCS_Data,
			In_SOF											=> TX_FCS_SOF,
			In_EOF											=> TX_FCS_EOF,
			In_Ready										=> UDP_TX_Ready,
			In_Meta_rst									=> UDP_TX_Meta_rst,
			In_Meta_SrcIPAddress_nxt		=> UDP_TX_Meta_SrcIPAddress_nxt,
			In_Meta_SrcIPAddress_Data		=> TX_FCS_Meta_SrcIPAddress_Data,
			In_Meta_DestIPAddress_nxt		=> UDP_TX_Meta_DestIPAddress_nxt,
			In_Meta_DestIPAddress_Data	=> TX_FCS_Meta_DestIPAddress_Data,
			In_Meta_SrcPort							=> TX_FCS_Meta_SrcPort,
			In_Meta_DestPort						=> TX_FCS_Meta_DestPort,
			In_Meta_Length							=> TX_FCS_Meta_Length,
			In_Meta_Checksum						=> TX_FCS_Meta_Checksum,
			
			Out_Valid										=> IP_TX_Valid,
			Out_Data										=> IP_TX_Data,
			Out_SOF											=> IP_TX_SOF,
			Out_EOF											=> IP_TX_EOF,
			Out_Ready										=> IP_TX_Ready,
			Out_Meta_rst								=> IP_TX_Meta_rst,
			Out_Meta_SrcIPAddress_nxt		=> IP_TX_Meta_SrcIPAddress_nxt,
			Out_Meta_SrcIPAddress_Data	=> IP_TX_Meta_SrcIPAddress_Data,
			Out_Meta_DestIPAddress_nxt	=> IP_TX_Meta_DestIPAddress_nxt,
			Out_Meta_DestIPAddress_Data	=> IP_TX_Meta_DestIPAddress_Data,
			Out_Meta_Length							=> IP_TX_Meta_Length
		);

-- ============================================================================================================================================================
-- RX Path
-- ============================================================================================================================================================
	RX_UDP : ENTITY PoC.UDP_RX
		GENERIC MAP (
			DEBUG														=> DEBUG,
			IP_VERSION											=> IP_VERSION
		)
		PORT MAP (
			Clock														=> Clock,
			Reset														=> Reset,
		
			In_Valid												=> IP_RX_Valid,
			In_Data													=> IP_RX_Data,
			In_SOF													=> IP_RX_SOF,
			In_EOF													=> IP_RX_EOF,
			In_Ready												=> IP_RX_Ready,
			In_Meta_rst											=> IP_RX_Meta_rst,
			In_Meta_SrcMACAddress_nxt				=> IP_RX_Meta_SrcMACAddress_nxt,
			In_Meta_SrcMACAddress_Data			=> IP_RX_Meta_SrcMACAddress_Data,
			In_Meta_DestMACAddress_nxt			=> IP_RX_Meta_DestMACAddress_nxt,
			In_Meta_DestMACAddress_Data			=> IP_RX_Meta_DestMACAddress_Data,
			In_Meta_EthType									=> IP_RX_Meta_EthType,
			In_Meta_SrcIPAddress_nxt				=> IP_RX_Meta_SrcIPAddress_nxt,
			In_Meta_SrcIPAddress_Data				=> IP_RX_Meta_SrcIPAddress_Data,
			In_Meta_DestIPAddress_nxt				=> IP_RX_Meta_DestIPAddress_nxt,
			In_Meta_DestIPAddress_Data			=> IP_RX_Meta_DestIPAddress_Data,
			In_Meta_Length									=> IP_RX_Meta_Length,
			In_Meta_Protocol								=> IP_RX_Meta_Protocol,
			
			Out_Valid												=> UDP_RX_Valid,
			Out_Data												=> UDP_RX_Data,
			Out_SOF													=> UDP_RX_SOF,
			Out_EOF													=> UDP_RX_EOF,
			Out_Ready												=> LLDeMux_Out_Ready,
			Out_Meta_rst										=> LLDeMux_Out_Meta_rst,
			Out_Meta_SrcMACAddress_nxt			=> LLDeMux_Out_Meta_SrcMACAddress_nxt,
			Out_Meta_SrcMACAddress_Data			=> UDP_RX_Meta_SrcMACAddress_Data,
			Out_Meta_DestMACAddress_nxt			=> LLDeMux_Out_Meta_DestMACAddress_nxt,
			Out_Meta_DestMACAddress_Data		=> UDP_RX_Meta_DestMACAddress_Data,
			Out_Meta_EthType								=> UDP_RX_Meta_EthType,
			Out_Meta_SrcIPAddress_nxt				=> LLDeMux_Out_Meta_SrcIPAddress_nxt,
			Out_Meta_SrcIPAddress_Data			=> UDP_RX_Meta_SrcIPAddress_Data,
			Out_Meta_DestIPAddress_nxt			=> LLDeMux_Out_Meta_DestIPAddress_nxt,
			Out_Meta_DestIPAddress_Data			=> UDP_RX_Meta_DestIPAddress_Data,
			Out_Meta_Length									=> UDP_RX_Meta_Length,
			Out_Meta_Protocol								=> UDP_RX_Meta_Protocol,
			Out_Meta_SrcPort								=> UDP_RX_Meta_SrcPort,
			Out_Meta_DestPort								=> UDP_RX_Meta_DestPort
		);

	genLLDeMux_Control : FOR I IN 0 TO UDP_SWITCH_PORTS - 1 GENERATE
		LLDeMux_Control(I)		<= to_sl(UDP_RX_Meta_DestPort = PORTPAIRS(I).Ingress);
	END GENERATE;
	
	-- decompress meta_rev vector to single bits
	LLDeMux_Out_Meta_rst									<= LLDeMux_Out_MetaIn_rev(LLDEMUX_META_RST_BIT);
	LLDeMux_Out_Meta_SrcMACAddress_nxt		<= LLDeMux_Out_MetaIn_rev(LLDEMUX_META_MACSRC_NXT_BIT);
	LLDeMux_Out_Meta_DestMACAddress_nxt		<= LLDeMux_Out_MetaIn_rev(LLDEMUX_META_MACDEST_NXT_BIT);
	LLDeMux_Out_Meta_SrcIPAddress_nxt			<= LLDeMux_Out_MetaIn_rev(LLDEMUX_META_IPSRC_NXT_BIT);
	LLDeMux_Out_Meta_DestIPAddress_nxt		<= LLDeMux_Out_MetaIn_rev(LLDEMUX_META_IPDEST_NXT_BIT);
	
	-- compress meta data vectors to single meta data vector
	LLDeMux_Out_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCMAC)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCMAC))		<= UDP_RX_Meta_SrcMACAddress_Data;
	LLDeMux_Out_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTMAC)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTMAC))	<= UDP_RX_Meta_DestMACAddress_Data;
	LLDeMux_Out_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_ETHTYPE)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_ETHTYPE))	<= UDP_RX_Meta_EthType;
	LLDeMux_Out_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCIP)			DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCIP))		<= UDP_RX_Meta_SrcIPAddress_Data;
	LLDeMux_Out_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTIP)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTIP))		<= UDP_RX_Meta_DestIPAddress_Data;
	LLDeMux_Out_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_LENGTH)		DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_LENGTH))		<= UDP_RX_Meta_Length;
	LLDeMux_Out_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_PROTO)			DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_PROTO))		<= UDP_RX_Meta_Protocol;
	LLDeMux_Out_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCPORT) 	DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCPORT))	<= UDP_RX_Meta_SrcPort;
	LLDeMux_Out_MetaIn(high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTPORT)	DOWNTO	low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTPORT))	<= UDP_RX_Meta_DestPort;
	
	RX_LLDeMux : ENTITY PoC.stream_DeMux
		GENERIC MAP (
			PORTS										=> UDP_SWITCH_PORTS,
			DATA_BITS								=> LLDEMUX_DATA_BITS,
			META_BITS								=> isum(LLDEMUX_META_BITS),
			META_REV_BITS						=> LLDEMUX_META_REV_BITS
		)
		PORT MAP (
			Clock										=> Clock,
			Reset										=> Reset,

			DeMuxControl						=> LLDeMux_Control,

			In_Valid								=> UDP_RX_Valid,
			In_Data									=> UDP_RX_Data,
			In_Meta									=> LLDeMux_Out_MetaIn,
			In_Meta_rev							=> LLDeMux_Out_MetaIn_rev,
			In_SOF									=> UDP_RX_SOF,
			In_EOF									=> UDP_RX_EOF,
			In_Ready								=> LLDeMux_Out_Ready,
			
			Out_Valid								=> RX_Valid,
			Out_Data								=> LLDeMux_Out_Data,
			Out_Meta								=> LLDeMux_Out_MetaOut,
			Out_Meta_rev						=> LLDeMux_Out_MetaOut_rev,
			Out_SOF									=> RX_SOF,
			Out_EOF									=> RX_EOF,
			Out_Ready								=> RX_Ready
		);

	assign_col(LLDeMux_Out_MetaOut_rev, RX_Meta_rst,								LLDEMUX_META_RST_BIT);
	assign_col(LLDeMux_Out_MetaOut_rev, RX_Meta_SrcMACAddress_nxt,	LLDEMUX_META_MACSRC_NXT_BIT);
	assign_col(LLDeMux_Out_MetaOut_rev, RX_Meta_DestMACAddress_nxt,	LLDEMUX_META_MACDEST_NXT_BIT);
	assign_col(LLDeMux_Out_MetaOut_rev, RX_Meta_SrcIPAddress_nxt,		LLDEMUX_META_IPSRC_NXT_BIT);
	assign_col(LLDeMux_Out_MetaOut_rev, RX_Meta_DestIPAddress_nxt,	LLDEMUX_META_IPDEST_NXT_BIT);

	-- new slm_slice funtion to avoid generate statement for wiring => cut multiple columns over all rows and convert to slvv_*
	RX_Data													<= to_slvv_8(LLDeMux_Out_Data);
	RX_Meta_SrcMACAddress_Data			<= to_slvv_8(	slm_slice_cols(LLDeMux_Out_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCMAC),		high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCMAC)));
	RX_Meta_DestMACAddress_Data			<= to_slvv_8(	slm_slice_cols(LLDeMux_Out_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTMAC),	high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTMAC)));
	RX_Meta_EthType									<= to_slvv_16(slm_slice_cols(LLDeMux_Out_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_ETHTYPE),	high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_ETHTYPE)));
	RX_Meta_SrcIPAddress_Data				<= to_slvv_8(	slm_slice_cols(LLDeMux_Out_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCIP),		high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCIP)));
	RX_Meta_DestIPAddress_Data			<= to_slvv_8(	slm_slice_cols(LLDeMux_Out_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTIP),		high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTIP)));
	RX_Meta_Length									<= to_slvv_16(slm_slice_cols(LLDeMux_Out_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_LENGTH),		high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_LENGTH)));
	RX_Meta_Protocol								<= to_slvv_8(	slm_slice_cols(LLDeMux_Out_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_PROTO),		high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_PROTO)));
	RX_Meta_SrcPort									<= to_slvv_16(slm_slice_cols(LLDeMux_Out_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCPORT),	high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_SRCPORT)));
	RX_Meta_DestPort								<= to_slvv_16(slm_slice_cols(LLDeMux_Out_MetaOut, low(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTPORT),	high(LLDEMUX_META_BITS, LLDEMUX_META_STREAMID_DESTPORT)));
END ARCHITECTURE;
