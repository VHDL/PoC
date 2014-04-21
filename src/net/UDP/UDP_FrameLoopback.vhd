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


ENTITY UDP_FrameLoopback IS
	GENERIC (
		IP_VERSION										: POSITIVE						:= 6;
		MAX_FRAMES										: POSITIVE						:= 4
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		-- IN port
		In_Valid											: IN	STD_LOGIC;
		In_Data												: IN	T_SLV_8;
		In_SOF												: IN	STD_LOGIC;
		In_EOF												: IN	STD_LOGIC;
		In_Ready											: OUT	STD_LOGIC;
		In_Meta_rst										: OUT	STD_LOGIC;
		In_Meta_DestIPAddress_nxt			: OUT	STD_LOGIC;
		In_Meta_DestIPAddress_Data		: IN	T_SLV_8;
		In_Meta_SrcIPAddress_nxt			: OUT	STD_LOGIC;
		In_Meta_SrcIPAddress_Data			: IN	T_SLV_8;
		In_Meta_DestPort							: IN	T_NET_UDP_PORT;
		In_Meta_SrcPort								: IN	T_NET_UDP_PORT;
		-- OUT port
		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ready											: IN	STD_LOGIC;
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_DestIPAddress_nxt		: IN	STD_LOGIC;
		Out_Meta_DestIPAddress_Data		: OUT	T_SLV_8;
		Out_Meta_SrcIPAddress_nxt			: IN	STD_LOGIC;
		Out_Meta_SrcIPAddress_Data		: OUT	T_SLV_8;
		Out_Meta_DestPort							: OUT	T_NET_UDP_PORT;
		Out_Meta_SrcPort							: OUT	T_NET_UDP_PORT
	);
END;

ARCHITECTURE rtl OF UDP_FrameLoopback IS
	ATTRIBUTE KEEP										: BOOLEAN;
	
	CONSTANT IPADDRESS_LENGTH					: POSITIVE																					:= ite((IP_VERSION = 4), 4, 16);
	
	CONSTANT META_STREAMID_DESTADDR		: NATURAL																						:= 0;
	CONSTANT META_STREAMID_SRCADDR		: NATURAL																						:= 1;
	CONSTANT META_STREAMID_DESTPORT		: NATURAL																						:= 2;
	CONSTANT META_STREAMID_SRCPORT		: NATURAL																						:= 3;
	CONSTANT META_STREAMS							: POSITIVE																					:= 4;		-- Destination, Source, DestPort, SrcPort

	SIGNAL LLBuf_MetaIn_nxt						: STD_LOGIC_VECTOR(META_STREAMS - 1 DOWNTO 0);
	SIGNAL LLBuf_MetaIn_Data					: T_SLM(META_STREAMS - 1 DOWNTO 0, 15 DOWNTO 0)			:= (OTHERS => (OTHERS => 'Z'));
	SIGNAL LLBuf_MetaOut_nxt					: STD_LOGIC_VECTOR(META_STREAMS - 1 DOWNTO 0);
	SIGNAL LLBuf_MetaOut_Data					: T_SLM(META_STREAMS - 1 DOWNTO 0, 15 DOWNTO 0);
	
BEGIN
	assign_row(LLBuf_MetaIn_Data, In_Meta_DestIPAddress_Data,	META_STREAMID_DESTADDR, 0, '0');
	assign_row(LLBuf_MetaIn_Data, In_Meta_SrcIPAddress_Data,	META_STREAMID_SRCADDR,	0, '0');
	assign_row(LLBuf_MetaIn_Data, In_Meta_DestPort,						META_STREAMID_DESTPORT);
	assign_row(LLBuf_MetaIn_Data, In_Meta_SrcPort,						META_STREAMID_SRCPORT);

	In_Meta_DestIPAddress_nxt		<= LLBuf_MetaIn_nxt(META_STREAMID_DESTADDR);
	In_Meta_SrcIPAddress_nxt		<= LLBuf_MetaIn_nxt(META_STREAMID_SRCADDR);

	LLBuf : ENTITY L_Global.LocalLink_Buffer
		GENERIC MAP (
			FRAMES												=> MAX_FRAMES,
			DATA_BITS											=> 8,
			DATA_FIFO_DEPTH								=> 1024,
			META_BITS											=> (META_STREAMID_DESTADDR => 8,								META_STREAMID_SRCADDR => 8,									META_STREAMID_DESTPORT => 16,	META_STREAMID_SRCPORT => 16),
			META_FIFO_DEPTH								=> (META_STREAMID_DESTADDR => IPADDRESS_LENGTH,	META_STREAMID_SRCADDR => IPADDRESS_LENGTH,	META_STREAMID_DESTPORT => 1,	META_STREAMID_SRCPORT => 1)
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,
			
			In_Valid											=> In_Valid,
			In_Data												=> In_Data,
			In_SOF												=> In_SOF,
			In_EOF												=> In_EOF,
			In_Ready											=> In_Ready,
			In_Meta_rst										=> In_Meta_rst,
			In_Meta_nxt										=> LLBuf_MetaIn_nxt,
			In_Meta_Data									=> LLBuf_MetaIn_Data,
			
			Out_Valid											=> Out_Valid,
			Out_Data											=> Out_Data,
			Out_SOF												=> Out_SOF,
			Out_EOF												=> Out_EOF,
			Out_Ready											=> Out_Ready,
			Out_Meta_rst									=> Out_Meta_rst,
			Out_Meta_nxt									=> LLBuf_MetaOut_nxt,
			Out_Meta_Data									=> LLBuf_MetaOut_Data
		);
	
	-- unpack LLBuf metadata to signals
	Out_Meta_DestIPAddress_Data														<= get_row(LLBuf_MetaOut_Data, META_STREAMID_SRCADDR,		8);			-- Crossover: Destination <= Source
	Out_Meta_SrcIPAddress_Data														<= get_row(LLBuf_MetaOut_Data, META_STREAMID_DESTADDR,	8);			-- Crossover: Source <= Destination
	Out_Meta_DestPort																			<= get_row(LLBuf_MetaOut_Data, META_STREAMID_SRCPORT);					-- Crossover: Destination <= Source
	Out_Meta_SrcPort																			<= get_row(LLBuf_MetaOut_Data, META_STREAMID_DESTPORT);				-- Crossover: Source <= Destination
	
	-- pack metadata nxt signals to LLBuf meta vector
	LLBuf_MetaOut_nxt(META_STREAMID_DESTADDR)							<= Out_Meta_DestIPAddress_nxt;
	LLBuf_MetaOut_nxt(META_STREAMID_SRCADDR)							<= Out_Meta_SrcIPAddress_nxt;
	LLBuf_MetaOut_nxt(META_STREAMID_DESTPORT)							<= '0';
	LLBuf_MetaOut_nxt(META_STREAMID_SRCPORT)							<= '0';
	
END ARCHITECTURE;
