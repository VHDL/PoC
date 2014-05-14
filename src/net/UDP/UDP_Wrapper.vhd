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
	
	CONSTANT STMMUX_META_RST_BIT								: NATURAL					:= 0;
	CONSTANT STMMUX_META_SRCIP_NXT_BIT					: NATURAL					:= 1;
	CONSTANT STMMUX_META_DESTIP_NXT_BIT					: NATURAL					:= 2;
	
	CONSTANT STMMUX_META_REV_BITS								: NATURAL					:= 3;
	
	CONSTANT STMMUX_META_STREAMID_SRCIP					: NATURAL					:= 0;
	CONSTANT STMMUX_META_STREAMID_DESTIP				: NATURAL					:= 1;
	CONSTANT STMMUX_META_STREAMID_SRCPORT				: NATURAL					:= 2;
	CONSTANT STMMUX_META_STREAMID_DESTPORT			: NATURAL					:= 3;
	CONSTANT STMMUX_META_STREAMID_LENGTH				: NATURAL					:= 4;
	
	CONSTANT STMMUX_META_BITS										: T_POSVEC				:= (
		STMMUX_META_STREAMID_SRCIP			=> 8,
		STMMUX_META_STREAMID_DESTIP			=> 8,
		STMMUX_META_STREAMID_SRCPORT		=> 16,
		STMMUX_META_STREAMID_DESTPORT		=> 16,
		STMMUX_META_STREAMID_LENGTH			=> 16
	);
	
	SIGNAL StmMux_In_Valid											: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);
	SIGNAL StmMux_In_Data												: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, T_SLV_8'range)												:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL StmMux_In_Meta												: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, isum(STMMUX_META_BITS) - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL StmMux_In_Meta_rev										: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, STMMUX_META_REV_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL StmMux_In_SOF												: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);
	SIGNAL StmMux_In_EOF												: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);
	SIGNAL StmMux_In_Ready											: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);
	
	SIGNAL StmMux_Out_Valid											: STD_LOGIC;
	SIGNAL StmMux_Out_Data											: T_SLV_8;
	SIGNAL StmMux_Out_Meta											: STD_LOGIC_VECTOR(isum(STMMUX_META_BITS) - 1 DOWNTO 0);
	SIGNAL StmMux_Out_Meta_rev									: STD_LOGIC_VECTOR(STMMUX_META_REV_BITS - 1 DOWNTO 0);
	SIGNAL StmMux_Out_SOF												: STD_LOGIC;
	SIGNAL StmMux_Out_EOF												: STD_LOGIC;
	SIGNAL StmMux_Out_SrcIPAddress_Data					: T_SLV_8;
	SIGNAL StmMux_Out_DestIPAddress_Data				: T_SLV_8;
	SIGNAL StmMux_Out_Length										: T_SLV_16;
	SIGNAL StmMux_Out_Protocol									: T_SLV_8;
	
	CONSTANT TX_FCS_META_STREAMID_SRCIP					: NATURAL					:= 0;
	CONSTANT TX_FCS_META_STREAMID_DESTIP				: NATURAL					:= 1;
	CONSTANT TX_FCS_META_STREAMID_SRCPORT				: NATURAL					:= 2;
	CONSTANT TX_FCS_META_STREAMID_DESTPORT			: NATURAL					:= 3;
	CONSTANT TX_FCS_META_STREAMID_LEN						: NATURAL					:= 4;
	
	CONSTANT TX_FCS_META_BITS                   : T_POSVEC				:= (
		TX_FCS_META_STREAMID_SRCIP			=> 8,
		TX_FCS_META_STREAMID_DESTIP			=> 8,
		TX_FCS_META_STREAMID_SRCPORT		=> 16,
		TX_FCS_META_STREAMID_DESTPORT		=> 16,
		TX_FCS_META_STREAMID_LEN				=> 16
	);
		
	CONSTANT TX_FCS_META_FIFO_DEPTHS            : T_POSVEC				:= (
		TX_FCS_META_STREAMID_SRCIP			=> ite((IP_VERSION = 6), 16, 4),
		TX_FCS_META_STREAMID_DESTIP			=> ite((IP_VERSION = 6), 16, 4),
		TX_FCS_META_STREAMID_SRCPORT		=> 1,
		TX_FCS_META_STREAMID_DESTPORT		=> 1,
		TX_FCS_META_STREAMID_LEN				=> 1
	);
	
	SIGNAL TX_FCS_Valid													: STD_LOGIC;
	SIGNAL TX_FCS_Data													: T_SLV_8;
	SIGNAL TX_FCS_SOF														: STD_LOGIC;
	SIGNAL TX_FCS_EOF														: STD_LOGIC;
	SIGNAL TX_FCS_MetaOut_rst										: STD_LOGIC;
	SIGNAL TX_FCS_MetaOut_nxt										: STD_LOGIC_VECTOR(TX_FCS_META_BITS'length - 1 DOWNTO 0);
	SIGNAL TX_FCS_MetaOut_Data									: STD_LOGIC_VECTOR(isum(TX_FCS_META_BITS) - 1 DOWNTO 0);
	SIGNAL TX_FCS_Meta_SrcIPAddress_Data				: T_SLV_8;
	SIGNAL TX_FCS_Meta_DestIPAddress_Data				: T_SLV_8;
	SIGNAL TX_FCS_Meta_SrcPort									: T_SLV_16;
	SIGNAL TX_FCS_Meta_DestPort									: T_SLV_16;
	SIGNAL TX_FCS_Meta_Checksum									: T_SLV_16;
	SIGNAL TX_FCS_Meta_Length										: T_SLV_16;
	
	SIGNAL TX_FCS_Ready													: STD_LOGIC;
	SIGNAL TX_FCS_MetaIn_rst										: STD_LOGIC;
	SIGNAL TX_FCS_MetaIn_nxt										: STD_LOGIC_VECTOR(TX_FCS_META_BITS'length - 1 DOWNTO 0);
	SIGNAL TX_FCS_MetaIn_Data										: STD_LOGIC_VECTOR(isum(TX_FCS_META_BITS) - 1 DOWNTO 0);
	
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
	
	CONSTANT STMDEMUX_META_RST_BIT							: NATURAL					:= 0;
	CONSTANT STMDEMUX_META_MACSRC_NXT_BIT				: NATURAL					:= 1;
	CONSTANT STMDEMUX_META_MACDEST_NXT_BIT			: NATURAL					:= 2;
	CONSTANT STMDEMUX_META_IPSRC_NXT_BIT				: NATURAL					:= 3;
	CONSTANT STMDEMUX_META_IPDEST_NXT_BIT				: NATURAL					:= 4;
	
	CONSTANT STMDEMUX_META_STREAMID_SRCMAC			: NATURAL					:= 0;
	CONSTANT STMDEMUX_META_STREAMID_DESTMAC			: NATURAL					:= 1;
	CONSTANT STMDEMUX_META_STREAMID_ETHTYPE			: NATURAL					:= 2;
	CONSTANT STMDEMUX_META_STREAMID_SRCIP				: NATURAL					:= 3;
	CONSTANT STMDEMUX_META_STREAMID_DESTIP			: NATURAL					:= 4;
	CONSTANT STMDEMUX_META_STREAMID_LENGTH			: NATURAL					:= 5;
	CONSTANT STMDEMUX_META_STREAMID_PROTO				: NATURAL					:= 6;
	CONSTANT STMDEMUX_META_STREAMID_SRCPORT			: NATURAL					:= 7;
	CONSTANT STMDEMUX_META_STREAMID_DESTPORT		: NATURAL					:= 8;
	
	CONSTANT STMDEMUX_DATA_BITS									: NATURAL					:= 8;							-- 
	CONSTANT STMDEMUX_META_BITS									: T_POSVEC				:= (
		STMDEMUX_META_STREAMID_SRCMAC			=> 8,
		STMDEMUX_META_STREAMID_DESTMAC 		=> 8,
		STMDEMUX_META_STREAMID_ETHTYPE 		=> 16,
		STMDEMUX_META_STREAMID_SRCIP			=> 8,
		STMDEMUX_META_STREAMID_DESTIP			=> 8,
		STMDEMUX_META_STREAMID_LENGTH			=> 16,
		STMDEMUX_META_STREAMID_PROTO			=> 8,
		STMDEMUX_META_STREAMID_SRCPORT		=> 16,
		STMDEMUX_META_STREAMID_DESTPORT		=> 16
	);
	CONSTANT STMDEMUX_META_REV_BITS							: NATURAL					:= 5;							-- sum over all control bits (rst, nxt, nxt, nxt, nxt)
	
	SIGNAL StmDeMux_Out_Ready										: STD_LOGIC;
	SIGNAL StmDeMux_Out_Meta_rst									: STD_LOGIC;
	SIGNAL StmDeMux_Out_Meta_SrcMACAddress_nxt		: STD_LOGIC;
	SIGNAL StmDeMux_Out_Meta_DestMACAddress_nxt	: STD_LOGIC;
	SIGNAL StmDeMux_Out_Meta_SrcIPAddress_nxt		: STD_LOGIC;
	SIGNAL StmDeMux_Out_Meta_DestIPAddress_nxt		: STD_LOGIC;
	
	SIGNAL StmDeMux_Out_MetaIn										: STD_LOGIC_VECTOR(isum(STMDEMUX_META_BITS) - 1 DOWNTO 0);
	SIGNAL StmDeMux_Out_MetaIn_rev								: STD_LOGIC_VECTOR(STMDEMUX_META_REV_BITS - 1 DOWNTO 0);
	SIGNAL StmDeMux_Out_Data											: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, StmDEMUX_DATA_BITS - 1 DOWNTO 0)				:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL StmDeMux_Out_MetaOut									: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, isum(STMDEMUX_META_BITS) - 1 DOWNTO 0)	:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL StmDeMux_Out_MetaOut_rev							: T_SLM(UDP_SWITCH_PORTS - 1 DOWNTO 0, STMDEMUX_META_REV_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	
	SIGNAL StmDeMux_Control											: STD_LOGIC_VECTOR(UDP_SWITCH_PORTS - 1 DOWNTO 0);

BEGIN
	ASSERT ((IP_VERSION = 4) OR (IP_VERSION = 6)) REPORT "Unsupported Internet Protocol (IP) version."								SEVERITY ERROR;

-- ============================================================================================================================================================
-- TX Path
-- ============================================================================================================================================================
	StmMux_In_Data		<= to_slm(TX_Data);
	
	genStmMuxIn : FOR I IN 0 TO UDP_SWITCH_PORTS - 1 GENERATE
		SIGNAL Meta			: STD_LOGIC_VECTOR(isum(STMMUX_META_BITS) - 1 DOWNTO 0);
	BEGIN
		Meta(high(STMMUX_META_BITS, STMMUX_META_STREAMID_SRCIP)			DOWNTO	low(STMMUX_META_BITS, STMMUX_META_STREAMID_SRCIP))		<= TX_Meta_SrcIPAddress_Data(I);
		Meta(high(STMMUX_META_BITS, STMMUX_META_STREAMID_DESTIP)		DOWNTO	low(STMMUX_META_BITS, STMMUX_META_STREAMID_DESTIP))		<= TX_Meta_DestIPAddress_Data(I);
		Meta(high(STMMUX_META_BITS, STMMUX_META_STREAMID_SRCPORT)		DOWNTO	low(STMMUX_META_BITS, STMMUX_META_STREAMID_SRCPORT))	<= TX_Meta_SrcPort(I);
		Meta(high(STMMUX_META_BITS, STMMUX_META_STREAMID_DESTPORT)	DOWNTO	low(STMMUX_META_BITS, STMMUX_META_STREAMID_DESTPORT))	<= TX_Meta_DestPort(I);
		Meta(high(STMMUX_META_BITS, STMMUX_META_STREAMID_LENGTH)		DOWNTO	low(STMMUX_META_BITS, STMMUX_META_STREAMID_LENGTH))		<= TX_Meta_Length(I);
		
		assign_row(StmMux_In_Meta, Meta,	I);
	END GENERATE;
	
	TX_Meta_rst									<= get_col(StmMux_In_Meta_rev,	StmMUX_META_RST_BIT);
	TX_Meta_SrcIPAddress_nxt		<= get_col(StmMux_In_Meta_rev,	StmMUX_META_SRCIP_NXT_BIT);
	TX_Meta_DestIPAddress_nxt		<= get_col(StmMux_In_Meta_rev,	StmMUX_META_DESTIP_NXT_BIT);

	TX_StmMux : ENTITY PoC.stream_Mux
		GENERIC MAP (
			PORTS									=> UDP_SWITCH_PORTS,
			DATA_BITS							=> StmMux_Out_Data'length,
			META_BITS							=> isum(STMMUX_META_BITS),
			META_REV_BITS					=> STMMUX_META_REV_BITS
		)
		PORT MAP (
			Clock									=> Clock,
			Reset									=> Reset,
			
			In_Valid							=> TX_Valid,
			In_Data								=> StmMux_In_Data,
			In_Meta								=> StmMux_In_Meta,
			In_Meta_rev						=> StmMux_In_Meta_rev,
			In_SOF								=> TX_SOF,
			In_EOF								=> TX_EOF,
			In_Ready							=> TX_Ready,
			
			Out_Valid							=> StmMux_Out_Valid,
			Out_Data							=> StmMux_Out_Data,
			Out_Meta							=> StmMux_Out_Meta,
			Out_Meta_rev					=> StmMux_Out_Meta_rev,
			Out_SOF								=> StmMux_Out_SOF,
			Out_EOF								=> StmMux_Out_EOF,
			Out_Ready							=> TX_FCS_Ready
		);

	StmMux_Out_Meta_rev(StmMUX_META_RST_BIT)				<= TX_FCS_MetaIn_rst;
	StmMux_Out_Meta_rev(StmMUX_META_SRCIP_NXT_BIT)	<= TX_FCS_MetaIn_nxt(TX_FCS_META_STREAMID_SRCIP);
	StmMux_Out_Meta_rev(StmMUX_META_DESTIP_NXT_BIT)	<= TX_FCS_MetaIn_nxt(TX_FCS_META_STREAMID_DESTIP);

	TX_FCS_MetaIn_Data	<= StmMux_Out_Meta;

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
			
			In_Valid											=> StmMux_Out_Valid,
			In_Data												=> StmMux_Out_Data,
			In_SOF												=> StmMux_Out_SOF,
			In_EOF												=> StmMux_Out_EOF,
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

	TX_FCS_Meta_SrcIPAddress_Data			<= TX_FCS_MetaOut_Data(high(TX_FCS_META_BITS, TX_FCS_META_STREAMID_SRCIP)		 DOWNTO low(TX_FCS_META_BITS, TX_FCS_META_STREAMID_SRCIP));
	TX_FCS_Meta_DestIPAddress_Data		<= TX_FCS_MetaOut_Data(high(TX_FCS_META_BITS, TX_FCS_META_STREAMID_DESTIP)	 DOWNTO low(TX_FCS_META_BITS, TX_FCS_META_STREAMID_DESTIP));
	TX_FCS_Meta_SrcPort								<= TX_FCS_MetaOut_Data(high(TX_FCS_META_BITS, TX_FCS_META_STREAMID_SRCPORT)	 DOWNTO low(TX_FCS_META_BITS, TX_FCS_META_STREAMID_SRCPORT));
	TX_FCS_Meta_DestPort							<= TX_FCS_MetaOut_Data(high(TX_FCS_META_BITS, TX_FCS_META_STREAMID_DESTPORT) DOWNTO low(TX_FCS_META_BITS, TX_FCS_META_STREAMID_DESTPORT));
--	TX_FCS_Meta_Length								<= TX_FCS_MetaOut_Data(high(TX_FCS_META_BITS, TX_FCS_META_STREAMID_LEN)			 DOWNTO low(TX_FCS_META_BITS, TX_FCS_META_STREAMID_LEN));

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
			Out_Ready												=> StmDeMux_Out_Ready,
			Out_Meta_rst										=> StmDeMux_Out_Meta_rst,
			Out_Meta_SrcMACAddress_nxt			=> StmDeMux_Out_Meta_SrcMACAddress_nxt,
			Out_Meta_SrcMACAddress_Data			=> UDP_RX_Meta_SrcMACAddress_Data,
			Out_Meta_DestMACAddress_nxt			=> StmDeMux_Out_Meta_DestMACAddress_nxt,
			Out_Meta_DestMACAddress_Data		=> UDP_RX_Meta_DestMACAddress_Data,
			Out_Meta_EthType								=> UDP_RX_Meta_EthType,
			Out_Meta_SrcIPAddress_nxt				=> StmDeMux_Out_Meta_SrcIPAddress_nxt,
			Out_Meta_SrcIPAddress_Data			=> UDP_RX_Meta_SrcIPAddress_Data,
			Out_Meta_DestIPAddress_nxt			=> StmDeMux_Out_Meta_DestIPAddress_nxt,
			Out_Meta_DestIPAddress_Data			=> UDP_RX_Meta_DestIPAddress_Data,
			Out_Meta_Length									=> UDP_RX_Meta_Length,
			Out_Meta_Protocol								=> UDP_RX_Meta_Protocol,
			Out_Meta_SrcPort								=> UDP_RX_Meta_SrcPort,
			Out_Meta_DestPort								=> UDP_RX_Meta_DestPort
		);

	genStmDeMux_Control : FOR I IN 0 TO UDP_SWITCH_PORTS - 1 GENERATE
		StmDeMux_Control(I)		<= to_sl(UDP_RX_Meta_DestPort = PORTPAIRS(I).Ingress);
	END GENERATE;
	
	-- decompress meta_rev vector to single bits
	StmDeMux_Out_Meta_rst									<= StmDeMux_Out_MetaIn_rev(StmDEMUX_META_RST_BIT);
	StmDeMux_Out_Meta_SrcMACAddress_nxt		<= StmDeMux_Out_MetaIn_rev(StmDEMUX_META_MACSRC_NXT_BIT);
	StmDeMux_Out_Meta_DestMACAddress_nxt	<= StmDeMux_Out_MetaIn_rev(StmDEMUX_META_MACDEST_NXT_BIT);
	StmDeMux_Out_Meta_SrcIPAddress_nxt		<= StmDeMux_Out_MetaIn_rev(StmDEMUX_META_IPSRC_NXT_BIT);
	StmDeMux_Out_Meta_DestIPAddress_nxt		<= StmDeMux_Out_MetaIn_rev(StmDEMUX_META_IPDEST_NXT_BIT);
	
	-- compress meta data vectors to single meta data vector
	StmDeMux_Out_MetaIn(high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCMAC)		DOWNTO	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCMAC))		<= UDP_RX_Meta_SrcMACAddress_Data;
	StmDeMux_Out_MetaIn(high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTMAC)	DOWNTO	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTMAC))	<= UDP_RX_Meta_DestMACAddress_Data;
	StmDeMux_Out_MetaIn(high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_ETHTYPE)	DOWNTO	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_ETHTYPE))	<= UDP_RX_Meta_EthType;
	StmDeMux_Out_MetaIn(high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCIP)		DOWNTO	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCIP))		<= UDP_RX_Meta_SrcIPAddress_Data;
	StmDeMux_Out_MetaIn(high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTIP)		DOWNTO	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTIP))		<= UDP_RX_Meta_DestIPAddress_Data;
	StmDeMux_Out_MetaIn(high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_LENGTH)		DOWNTO	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_LENGTH))		<= UDP_RX_Meta_Length;
	StmDeMux_Out_MetaIn(high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_PROTO)		DOWNTO	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_PROTO))		<= UDP_RX_Meta_Protocol;
	StmDeMux_Out_MetaIn(high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCPORT) 	DOWNTO	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCPORT))	<= UDP_RX_Meta_SrcPort;
	StmDeMux_Out_MetaIn(high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTPORT)	DOWNTO	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTPORT))	<= UDP_RX_Meta_DestPort;
	
	RX_StmDeMux : ENTITY PoC.stream_DeMux
		GENERIC MAP (
			PORTS										=> UDP_SWITCH_PORTS,
			DATA_BITS								=> StmDEMUX_DATA_BITS,
			META_BITS								=> isum(STMDEMUX_META_BITS),
			META_REV_BITS						=> STMDEMUX_META_REV_BITS
		)
		PORT MAP (
			Clock										=> Clock,
			Reset										=> Reset,

			DeMuxControl						=> StmDeMux_Control,

			In_Valid								=> UDP_RX_Valid,
			In_Data									=> UDP_RX_Data,
			In_Meta									=> StmDeMux_Out_MetaIn,
			In_Meta_rev							=> StmDeMux_Out_MetaIn_rev,
			In_SOF									=> UDP_RX_SOF,
			In_EOF									=> UDP_RX_EOF,
			In_Ready								=> StmDeMux_Out_Ready,
			
			Out_Valid								=> RX_Valid,
			Out_Data								=> StmDeMux_Out_Data,
			Out_Meta								=> StmDeMux_Out_MetaOut,
			Out_Meta_rev						=> StmDeMux_Out_MetaOut_rev,
			Out_SOF									=> RX_SOF,
			Out_EOF									=> RX_EOF,
			Out_Ready								=> RX_Ready
		);

	assign_col(StmDeMux_Out_MetaOut_rev, RX_Meta_rst,									StmDEMUX_META_RST_BIT);
	assign_col(StmDeMux_Out_MetaOut_rev, RX_Meta_SrcMACAddress_nxt,		StmDEMUX_META_MACSRC_NXT_BIT);
	assign_col(StmDeMux_Out_MetaOut_rev, RX_Meta_DestMACAddress_nxt,	StmDEMUX_META_MACDEST_NXT_BIT);
	assign_col(StmDeMux_Out_MetaOut_rev, RX_Meta_SrcIPAddress_nxt,		StmDEMUX_META_IPSRC_NXT_BIT);
	assign_col(StmDeMux_Out_MetaOut_rev, RX_Meta_DestIPAddress_nxt,		StmDEMUX_META_IPDEST_NXT_BIT);

	-- new slm_slice funtion to avoid generate statement for wiring => cut multiple columns over all rows and convert to slvv_*
	RX_Data													<= to_slvv_8(StmDeMux_Out_Data);
	RX_Meta_SrcMACAddress_Data			<= to_slvv_8(	slm_slice_cols(StmDeMux_Out_MetaOut, high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCMAC),		low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCMAC)));
	RX_Meta_DestMACAddress_Data			<= to_slvv_8(	slm_slice_cols(StmDeMux_Out_MetaOut, high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTMAC),	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTMAC)));
	RX_Meta_EthType									<= to_slvv_16(slm_slice_cols(StmDeMux_Out_MetaOut, high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_ETHTYPE),	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_ETHTYPE)));
	RX_Meta_SrcIPAddress_Data				<= to_slvv_8(	slm_slice_cols(StmDeMux_Out_MetaOut, high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCIP),		low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCIP)));
	RX_Meta_DestIPAddress_Data			<= to_slvv_8(	slm_slice_cols(StmDeMux_Out_MetaOut, high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTIP),		low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTIP)));
	RX_Meta_Length									<= to_slvv_16(slm_slice_cols(StmDeMux_Out_MetaOut, high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_LENGTH),		low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_LENGTH)));
	RX_Meta_Protocol								<= to_slvv_8(	slm_slice_cols(StmDeMux_Out_MetaOut, high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_PROTO),		low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_PROTO)));
	RX_Meta_SrcPort									<= to_slvv_16(slm_slice_cols(StmDeMux_Out_MetaOut, high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCPORT),	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_SRCPORT)));
	RX_Meta_DestPort								<= to_slvv_16(slm_slice_cols(StmDeMux_Out_MetaOut, high(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTPORT),	low(STMDEMUX_META_BITS, STMDEMUX_META_STREAMID_DESTPORT)));
END ARCHITECTURE;
