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


ENTITY IPv4_FrameLoopback IS
	GENERIC (
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
		In_Meta_SrcIPv4Address_nxt		: OUT	STD_LOGIC;
		In_Meta_SrcIPv4Address_Data		: IN	T_SLV_8;
		In_Meta_DestIPv4Address_nxt		: OUT	STD_LOGIC;
		In_Meta_DestIPv4Address_Data	: IN	T_SLV_8;
		In_Meta_Length								: IN	T_SLV_16;
		-- OUT port
		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ready											: IN	STD_LOGIC;
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_SrcIPv4Address_nxt		: IN	STD_LOGIC;
		Out_Meta_SrcIPv4Address_Data	: OUT	T_SLV_8;
		Out_Meta_DestIPv4Address_nxt	: IN	STD_LOGIC;
		Out_Meta_DestIPv4Address_Data	: OUT	T_SLV_8;
		Out_Meta_Length								: OUT	T_SLV_16
	);
END;

ARCHITECTURE rtl OF IPv4_FrameLoopback IS
	ATTRIBUTE KEEP										: BOOLEAN;
	
	CONSTANT META_STREAMID_SRC				: NATURAL																						:= 0;
	CONSTANT META_STREAMID_DEST				: NATURAL																						:= 1;
	CONSTANT META_STREAMID_LENGTH			: NATURAL																						:= 2;
	CONSTANT META_STREAMS							: POSITIVE																					:= 3;		-- Source, Destination, Type

	SIGNAL LLBuf_MetaIn_nxt						: STD_LOGIC_VECTOR(META_STREAMS - 1 DOWNTO 0);
	SIGNAL LLBuf_MetaIn_Data					: T_SLM(META_STREAMS - 1 DOWNTO 0, 15 DOWNTO 0)			:= (OTHERS => (OTHERS => 'Z'));
	SIGNAL LLBuf_MetaOut_nxt					: STD_LOGIC_VECTOR(META_STREAMS - 1 DOWNTO 0);
	SIGNAL LLBuf_MetaOut_Data					: T_SLM(META_STREAMS - 1 DOWNTO 0, 15 DOWNTO 0)			:= (OTHERS => (OTHERS => 'Z'));
	
BEGIN

	assign_row(LLBuf_MetaIn_Data, In_Meta_SrcIPv4Address_Data,	META_STREAMID_SRC,				0, '0');
	assign_row(LLBuf_MetaIn_Data, In_Meta_DestIPv4Address_Data,	META_STREAMID_DEST,				0, '0');
	assign_row(LLBuf_MetaIn_Data, In_Meta_Length,								META_STREAMID_LENGTH,			0, '0');

	In_Meta_SrcIPv4Address_nxt		<= LLBuf_MetaIn_nxt(META_STREAMID_SRC);
	In_Meta_DestIPv4Address_nxt		<= LLBuf_MetaIn_nxt(META_STREAMID_DEST);

	LLBuf : ENTITY L_Global.LocalLink_Buffer
		GENERIC MAP (
			FRAMES												=> MAX_FRAMES,
			DATA_BITS											=> 8,
			DATA_FIFO_DEPTH								=> 1024,
			META_BITS											=> (META_STREAMID_SRC => 8,	META_STREAMID_DEST => 8,	META_STREAMID_LENGTH => 16),
			META_FIFO_DEPTH								=> (META_STREAMID_SRC => 6,	META_STREAMID_DEST => 6,	META_STREAMID_LENGTH => 1)
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
	Out_Meta_DestIPv4Address_Data													<= get_row(LLBuf_MetaOut_Data, META_STREAMID_SRC,				8);			-- Crossover: Destination <= Source
	Out_Meta_SrcIPv4Address_Data													<= get_row(LLBuf_MetaOut_Data, META_STREAMID_DEST,			8);			-- Crossover: Source <= Destination
	Out_Meta_Length																				<= get_row(LLBuf_MetaOut_Data, META_STREAMID_LENGTH,	 16);
	
	-- pack metadata nxt signals to LLBuf meta vector
	LLBuf_MetaOut_nxt(META_STREAMID_DEST)									<= Out_Meta_DestIPv4Address_nxt;
	LLBuf_MetaOut_nxt(META_STREAMID_SRC)									<= Out_Meta_SrcIPv4Address_nxt;
	LLBuf_MetaOut_nxt(META_STREAMID_LENGTH)								<= '0';

END ARCHITECTURE;
