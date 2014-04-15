LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

ENTITY FrameLoopback IS
	GENERIC (
		DATA_BW										: POSITIVE				:= 8;
		META_BW										: NATURAL					:= 0
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		In_Valid									: IN	STD_LOGIC;
		In_Data										: IN	STD_LOGIC_VECTOR(DATA_BW - 1 DOWNTO 0);
		In_Meta										: IN	STD_LOGIC_VECTOR(META_BW - 1 DOWNTO 0);
		In_SOF										: IN	STD_LOGIC;
		In_EOF										: IN	STD_LOGIC;
		In_Ready									: OUT	STD_LOGIC;
		

		Out_Valid									: OUT	STD_LOGIC;
		Out_Data									: OUT	STD_LOGIC_VECTOR(DATA_BW - 1 DOWNTO 0);
		Out_Meta									: OUT	STD_LOGIC_VECTOR(META_BW - 1 DOWNTO 0);
		Out_SOF										: OUT	STD_LOGIC;
		Out_EOF										: OUT	STD_LOGIC;
		Out_Ready									: IN	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF FrameLoopback IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	CONSTANT META_STREAMID_SRC							: NATURAL																						:= 0;
	CONSTANT META_STREAMID_DEST							: NATURAL																						:= 1;
	CONSTANT META_STREAMID_TYPE							: NATURAL																						:= 2;
	CONSTANT META_STREAMS										: POSITIVE																					:= 3;		-- Source, Destination, Type

	SIGNAL Meta_rst													: STD_LOGIC;
	SIGNAL Meta_nxt													: STD_LOGIC_VECTOR(META_STREAMS - 1 DOWNTO 0);

	SIGNAL Pipe_DataOut											: T_SLV_8;
	SIGNAL Pipe_MetaIn											: T_SLM(META_STREAMS - 1 DOWNTO 0, 31 DOWNTO 0)			:= (OTHERS => (OTHERS => 'Z'));
	SIGNAL Pipe_MetaOut											: T_SLM(META_STREAMS - 1 DOWNTO 0, 31 DOWNTO 0);
	SIGNAL Pipe_Meta_rst										: STD_LOGIC;
	SIGNAL Pipe_Meta_nxt										: STD_LOGIC_VECTOR(META_STREAMS - 1 DOWNTO 0);
	
	SIGNAL Pipe_Meta_SrcMACAddress_Data			: STD_LOGIC_VECTOR(TX_Funnel_SrcIPv6Address_Data'range);
	SIGNAL Pipe_Meta_DestMACAddress_Data		: STD_LOGIC_VECTOR(TX_Funnel_DestIPv6Address_Data'range);
	SIGNAL Pipe_Meta_EthType								: STD_LOGIC_VECTOR(TX_Funnel_Payload_Type'range);

	
BEGIN
	assign_row(Pipe_MetaIn, TX_Meta_SrcIPv6Address_Data(I),		META_STREAMID_SRC,	0, '0');
	assign_row(Pipe_MetaIn, TX_Meta_DestIPv6Address_Data(I),	META_STREAMID_DEST, 0, '0');
	assign_row(Pipe_MetaIn, TX_Meta_Length(I),								META_STREAMID_LEN);

	TX_Meta_rst(I)									<= Meta_rst;
	TX_Meta_SrcIPv6Address_nxt(I)		<= Meta_nxt(META_STREAMID_SRC);
	TX_Meta_DestIPv6Address_nxt(I)	<= Meta_nxt(META_STREAMID_DEST);

	Pipe : ENTITY L_Global.LocalLink_PipelineStage
		GENERIC MAP (
			FRAMES												=> 2,
			DATA_BITS											=> 8,
			DATA_FIFO_DEPTH								=> 16,
			META_BITS											=> (META_STREAMID_SRC => 8,		META_STREAMID_DEST => 8,	META_STREAMID_LEN => 16),
			META_FIFO_DEPTH								=> (META_STREAMID_SRC => 16,	META_STREAMID_DEST => 16,	META_STREAMID_LEN => 1)
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
			In_Meta_Data									=> Pipe_MetaIn,
			
			Out_Valid											=> Funnel_In_Valid(I),
			Out_Data											=> Pipe_DataOut,
			Out_SOF												=> Funnel_In_SOF(I),
			Out_EOF												=> Funnel_In_EOF(I),
			Out_Ready											=> Funnel_In_Ready(I),
			Out_Meta_rst									=> Pipe_Meta_rst,
			Out_Meta_nxt									=> Pipe_Meta_nxt,
			Out_Meta_Data									=> Pipe_MetaOut
		);
	
	-- unpack pipe metadata to signals
	Pipe_Meta_SrcIPv6Address_Data													<= get_row(Pipe_MetaOut, META_STREAMID_SRC,		8);
	Pipe_Meta_DestIPv6Address_Data												<= get_row(Pipe_MetaOut, META_STREAMID_DEST,	8);
	Pipe_Meta_Length																			<= get_row(Pipe_MetaOut, META_STREAMID_LEN);
	
	Pipe_Meta_rst																					<= Funnel_In_Meta_rev(I, META_RST_BIT);
	Pipe_Meta_nxt(META_STREAMID_SRC)											<= Funnel_In_Meta_rev(I, META_SRC_NXT_BIT);
	Pipe_Meta_nxt(META_STREAMID_DEST)											<= Funnel_In_Meta_rev(I, META_DEST_NXT_BIT);
	Pipe_Meta_nxt(META_STREAMID_LEN)											<= '0';
	
	-- pack metadata into 1 dim vector
	Funnel_MetaIn(Pipe_Meta_SrcIPv6Address_Data'range)		<= Pipe_Meta_SrcIPv6Address_Data;
	Funnel_MetaIn(Pipe_Meta_DestIPv6Address_Data'range)		<= Pipe_Meta_DestIPv6Address_Data;
	Funnel_MetaIn(Pipe_Meta_Length'range)									<= Pipe_Meta_Length;
	Funnel_MetaIn(Pipe_Meta_Payload_Type'range)						<= PACKET_TYPES(I);
	
	-- assign vectors to matrix
	assign_row(Funnel_In_Data, Pipe_DataOut, I);
	assign_row(Funnel_In_Meta, Funnel_MetaIn, I);
END ARCHITECTURE;
