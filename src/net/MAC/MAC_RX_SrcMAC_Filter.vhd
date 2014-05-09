LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;

ENTITY MAC_RX_SrcMAC_Filter IS
	GENERIC (
		DEBUG													: BOOLEAN													:= FALSE;
		MAC_ADDRESSES									: T_NET_MAC_ADDRESS_VECTOR				:= (0 => C_NET_MAC_ADDRESS_EMPTY);
		MAC_ADDRESSE_MASKS						: T_NET_MAC_ADDRESS_VECTOR				:= (0 => C_NET_MAC_MASK_DEFAULT)
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		In_Valid											: IN	STD_LOGIC;
		In_Data												: IN	T_SLV_8;
		In_SOF												: IN	STD_LOGIC;
		In_EOF												: IN	STD_LOGIC;
		In_Ready											: OUT	STD_LOGIC;
		In_Meta_rst										: OUT	STD_LOGIC;
		In_Meta_DestMACAddress_nxt		: OUT	STD_LOGIC;
		In_Meta_DestMACAddress_Data		: IN	T_SLV_8;

		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ready											: IN	STD_LOGIC;
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_DestMACAddress_nxt		: IN	STD_LOGIC;
		Out_Meta_DestMACAddress_Data	: OUT	T_SLV_8;
		Out_Meta_SrcMACAddress_nxt		: IN	STD_LOGIC;
		Out_Meta_SrcMACAddress_Data		: OUT	T_SLV_8
	);
END;


ARCHITECTURE rtl OF MAC_RX_SrcMAC_Filter IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	CONSTANT PATTERN_COUNT						: POSITIVE																					:= MAC_ADDRESSES'length;
	CONSTANT MAC_ADDRESSES_I					: T_NET_MAC_ADDRESS_VECTOR(0 TO PATTERN_COUNT - 1)	:= MAC_ADDRESSES;
	CONSTANT MAC_ADDRESSE_MASKS_I			: T_NET_MAC_ADDRESS_VECTOR(0 TO PATTERN_COUNT - 1)	:= MAC_ADDRESSE_MASKS;

	TYPE T_STATE		IS (
		ST_IDLE,
			ST_SRC_MAC_1,
			ST_SRC_MAC_2,
			ST_SRC_MAC_3,
			ST_SRC_MAC_4,
			ST_SRC_MAC_5,
			ST_PAYLOAD_1,
			ST_PAYLOAD_N,
		ST_DISCARD_FRAME
	);
	
	SUBTYPE T_MAC_BYTEINDEX	 IS NATURAL RANGE 0 TO 5;
	
	SIGNAL State												: T_STATE																	:= ST_IDLE;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State			: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL In_Ready_i										: STD_LOGIC;
	SIGNAL Is_DataFlow									: STD_LOGIC;
	SIGNAL Is_SOF												: STD_LOGIC;
	SIGNAL Is_EOF												: STD_LOGIC;
				
	SIGNAL New_Valid_i									: STD_LOGIC;
	SIGNAL New_SOF_i										: STD_LOGIC;
	SIGNAL Out_Ready_i									: STD_LOGIC;
				
	SIGNAL MAC_ByteIndex								: T_MAC_BYTEINDEX;
	
	SIGNAL CompareRegister_rst					: STD_LOGIC;
	SIGNAL CompareRegister_init					: STD_LOGIC;
	SIGNAL CompareRegister_clear				: STD_LOGIC;
	SIGNAL CompareRegister_en						: STD_LOGIC;
	SIGNAL CompareRegister_d						: STD_LOGIC_VECTOR(PATTERN_COUNT - 1 DOWNTO 0)		:= (OTHERS => '1');
	SIGNAL NoHits												: STD_LOGIC;
	
	SIGNAL SourceMACAddress_rst					: STD_LOGIC;
	SIGNAL SourceMACAddress_en					: STD_LOGIC;
	SIGNAL SourceMACAddress_sel					: T_MAC_BYTEINDEX;
	SIGNAL SourceMACAddress_d						: T_NET_MAC_ADDRESS																:= C_NET_MAC_ADDRESS_EMPTY;
	
	CONSTANT MAC_ADDRESS_LENGTH					: POSITIVE																				:= 6;			-- MAC -> 6 bytes
	CONSTANT READER_COUNTER_BITS				: POSITIVE																				:= log2ceilnz(MAC_ADDRESS_LENGTH);

	SIGNAL Reader_Counter_rst						: STD_LOGIC;
	SIGNAL Reader_Counter_en						: STD_LOGIC;
	SIGNAL Reader_Counter_us						: UNSIGNED(READER_COUNTER_BITS - 1 DOWNTO 0)			:= (OTHERS => '0');

	SIGNAL Out_Meta_rst_i								: STD_LOGIC;
	SIGNAL Out_Meta_SrcMACAddress_nxt_i	: STD_LOGIC;
	
BEGIN
	ASSERT FALSE REPORT "RX_SrcMAC_Filter:  patterns=" & INTEGER'image(PATTERN_COUNT)			SEVERITY NOTE;

	In_Ready			<= In_Ready_i;
	Is_DataFlow		<= In_Valid AND In_Ready_i;
	Is_SOF				<= In_Valid AND In_SOF;
	Is_EOF				<= In_Valid AND In_EOF;


	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State		<= ST_IDLE;
			ELSE
				State		<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Is_DataFlow, Is_SOF, Is_EOF, In_Valid, NoHits, Out_Ready_i)
	BEGIN
		NextState										<= State;

		In_Ready_i									<= '0';
		
		New_Valid_i									<= '0';
		New_SOF_i										<= '0';

		CompareRegister_en					<= '0';
		CompareRegister_rst					<= '0';
		CompareRegister_init				<= Is_SOF;
		CompareRegister_clear				<= Is_EOF;
		
		SourceMACAddress_rst				<= Is_EOF;
		SourceMACAddress_en					<= Is_SOF;
		
		MAC_ByteIndex								<= 0;

		CASE State IS
			WHEN ST_IDLE =>
				MAC_ByteIndex						<= 5;
			
				IF (Is_SOF = '1') THEN
					In_Ready_i						<= '1';
				
					IF (Is_EOF = '0') THEN
						NextState						<= ST_SRC_MAC_1;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_SRC_MAC_1 =>
				MAC_ByteIndex						<= 4;
				CompareRegister_en			<= In_Valid;
				SourceMACAddress_en			<= In_Valid;
			
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
				
					IF (Is_EOF = '0') THEN
						NextState						<= ST_SRC_MAC_2;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_SRC_MAC_2 =>
				MAC_ByteIndex						<= 3;
				CompareRegister_en			<= In_Valid;
				SourceMACAddress_en			<= In_Valid;
			
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
					
					IF (Is_EOF = '0') THEN
						NextState						<= ST_SRC_MAC_3;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_SRC_MAC_3 =>
				MAC_ByteIndex						<= 2;
				CompareRegister_en			<= In_Valid;
				SourceMACAddress_en			<= In_Valid;
			
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
					
					IF (Is_EOF = '0') THEN
						NextState						<= ST_SRC_MAC_4;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_SRC_MAC_4 =>
				MAC_ByteIndex						<= 1;
				CompareRegister_en			<= In_Valid;
				SourceMACAddress_en			<= In_Valid;
				
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
					
					IF (Is_EOF = '0') THEN
						NextState						<= ST_SRC_MAC_5;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_SRC_MAC_5 =>
				MAC_ByteIndex						<= 0;
				CompareRegister_en			<= In_Valid;
				SourceMACAddress_en			<= In_Valid;
				
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
					
					IF (Is_EOF = '0') THEN
						NextState											<= ST_PAYLOAD_1;
					ELSE
						NextState											<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_PAYLOAD_1 =>
				IF (NoHits = '1') THEN
					IF (Is_EOF = '0') THEN
						In_Ready_i					<= '1';
						NextState						<= ST_DISCARD_FRAME;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				ELSE
					In_Ready_i						<= Out_Ready_i;
					New_Valid_i						<= In_Valid;
					New_SOF_i							<= '1';
				
					IF (IS_DataFlow = '1') THEN
						IF (Is_EOF = '0') THEN
							NextState					<= ST_PAYLOAD_N;
						ELSE
							NextState					<= ST_IDLE;
						END IF;
					END IF;
				END IF;
				
			WHEN ST_PAYLOAD_N =>
				In_Ready_i							<= Out_Ready_i;
				New_Valid_i							<= In_Valid;
			
				IF ((IS_DataFlow AND Is_EOF) = '1') THEN
					NextState							<= ST_IDLE;
				END IF;
				
			WHEN ST_DISCARD_FRAME =>
				In_Ready_i							<= '1';
			
				IF ((IS_DataFlow AND Is_EOF) = '1') THEN
					NextState							<= ST_IDLE;
				END IF;
				
		END CASE;
	END PROCESS;

	
	gen0 : FOR I IN 0 TO PATTERN_COUNT - 1 GENERATE
		SIGNAL Hit								: STD_LOGIC;
	BEGIN
		Hit <= to_sl((In_Data AND MAC_ADDRESSE_MASKS_I(I)(MAC_ByteIndex)) = (MAC_ADDRESSES_I(I)(MAC_ByteIndex) AND MAC_ADDRESSE_MASKS_I(I)(MAC_ByteIndex)));
		
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF ((Reset OR CompareRegister_rst) = '1') THEN
					CompareRegister_d(I)				<= '0';
				ELSE
					IF (CompareRegister_init	= '1') THEN
						CompareRegister_d(I)			<= Hit;
					ELSIF (CompareRegister_clear	= '1') THEN
						CompareRegister_d(I)			<= '0';
					ELSIF (CompareRegister_en  = '1') THEN
						CompareRegister_d(I)			<= CompareRegister_d(I) AND Hit;
					END IF;
				END IF;
			END IF;
		END PROCESS;
	END GENERATE;

	NoHits										<= slv_nor(CompareRegister_d);

	SourceMACAddress_sel			<= MAC_ByteIndex;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR SourceMACAddress_rst) = '1') THEN
				SourceMACAddress_d	<= C_NET_MAC_ADDRESS_EMPTY;
			ELSE
				IF (SourceMACAddress_en = '1') THEN
					SourceMACAddress_d(SourceMACAddress_sel) <= In_Data;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	Reader_Counter_rst	<= Out_Meta_rst_i;
	Reader_Counter_en		<= Out_Meta_SrcMACAddress_nxt_i;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Reader_Counter_rst) = '1') THEN
				Reader_Counter_us				<= to_unsigned(T_MAC_BYTEINDEX'high, Reader_Counter_us'length);
			ELSE
				IF (Reader_Counter_en = '1') THEN
					Reader_Counter_us			<= Reader_Counter_us - 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Out_Valid											<= New_Valid_i;
	Out_Data											<= In_Data;
	Out_SOF												<= New_SOF_i;
	Out_EOF												<= In_EOF;
	Out_Ready_i										<= Out_Ready;

	-- Meta: rst
	Out_Meta_rst_i								<= Out_Meta_rst;
	In_Meta_rst										<= Out_Meta_rst_i;

	-- Meta: DestMACAddress
	In_Meta_DestMACAddress_nxt		<= Out_Meta_DestMACAddress_nxt;
	Out_Meta_DestMACAddress_Data	<= In_Meta_DestMACAddress_Data;
	
	-- Meta: SrcMACAddress
	Out_Meta_SrcMACAddress_nxt_i	<= Out_Meta_SrcMACAddress_nxt;
	Out_Meta_SrcMACAddress_Data		<= SourceMACAddress_d(to_integer(Reader_Counter_us, SourceMACAddress_d'high));

END ARCHITECTURE;
