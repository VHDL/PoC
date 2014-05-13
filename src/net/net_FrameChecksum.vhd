LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.net.ALL;


ENTITY net_FrameChecksum IS
	GENERIC (
		MAX_FRAMES										: POSITIVE				:= 8;
		MAX_FRAME_LENGTH							: POSITIVE				:= 2048;
		META_BITS											: T_POSVEC				:= (0 => 8);
		META_FIFO_DEPTH								: T_POSVEC				:= (0 => 16)
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
		In_Meta_nxt										: OUT	STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
		In_Meta_Data									: IN	STD_LOGIC_VECTOR(isum(META_BITS) - 1 DOWNTO 0);
		-- OUT port
		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ready											: IN	STD_LOGIC;
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_nxt									: IN	STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
		Out_Meta_Data									: OUT	STD_LOGIC_VECTOR(isum(META_BITS) - 1 DOWNTO 0);
		Out_Meta_Length								: OUT	T_SLV_16;
		Out_Meta_Checksum							: OUT	T_SLV_16
	);
END;

-- FIXME: review writer-FSM: check full signals => block incoming words/frames if datafifo or metafifo is full

ARCHITECTURE rtl OF net_FrameChecksum IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	TYPE T_WRITER_STATE IS			(ST_IDLE, ST_FRAME, ST_CARRY_1, ST_CARRY_2);
	TYPE T_METAWRITER_STATE IS	(ST_IDLE, ST_METADATA);
	TYPE T_READER_STATE IS			(ST_IDLE, ST_FRAME);
	
	SIGNAL Writer_State												: T_WRITER_STATE																			:= ST_IDLE;
	SIGNAL Writer_NextState										: T_WRITER_STATE;
	SIGNAL MetaWriter_State										: T_METAWRITER_STATE																	:= ST_IDLE;
	SIGNAL MetaWriter_NextState								: T_METAWRITER_STATE;
	SIGNAL Reader_State												: T_READER_STATE																			:= ST_IDLE;
	SIGNAL Reader_NextState										: T_READER_STATE;
	
	SIGNAL Checksum_rst												: STD_LOGIC;
	SIGNAL Checksum_en												: STD_LOGIC;
	SIGNAL Checksum_Data_us										: UNSIGNED(In_Data'range);
	SIGNAL Checksum0_nxt_us										: UNSIGNED(In_Data'length DOWNTO 0);
	SIGNAL Checksum0_d_us											: UNSIGNED(In_Data'length DOWNTO 0)										:= (OTHERS => '0');
	SIGNAL Checksum0_nxt_cy										: STD_LOGIC;
	SIGNAL Checksum1_nxt_us										: UNSIGNED(In_Data'range);
	SIGNAL Checksum1_d_us											: UNSIGNED(In_Data'range)															:= (OTHERS => '0');
	SIGNAL Checksum														: T_SLV_16;
	
	CONSTANT WORDCOUNTER_BITS									: POSITIVE																						:= log2ceilnz(MAX_FRAME_LENGTH);
	SIGNAL WordCounter_rst										: STD_LOGIC;
	SIGNAL WordCounter_en											: STD_LOGIC;
	SIGNAL WordCounter_us											: UNSIGNED(WORDCOUNTER_BITS - 1 DOWNTO 0)							:= to_unsigned(1, log2ceilnz(MAX_FRAME_LENGTH));
	SIGNAL WordCount													: STD_LOGIC_VECTOR(WORDCOUNTER_BITS + 15 DOWNTO 16);
	
	SIGNAL FrameCommit												: STD_LOGIC;
	
	CONSTANT DATA_BITS												: POSITIVE																						:= 8;
	CONSTANT EOF_BIT													: NATURAL																							:= DATA_BITS;
	
	SIGNAL DataFIFO_put												: STD_LOGIC;
	SIGNAL DataFIFO_DataIn										: STD_LOGIC_VECTOR(DATA_BITS DOWNTO 0);
	SIGNAL DataFIFO_Full											: STD_LOGIC;
	SIGNAL DataFIFO_got												: STD_LOGIC;
	SIGNAL DataFIFO_DataOut										: STD_LOGIC_VECTOR(DATA_BITS DOWNTO 0);
	SIGNAL DataFIFO_Valid											: STD_LOGIC;
	
	CONSTANT META_MISC_BITS										: POSITIVE																						:= Checksum'length + WordCount'length;
	
	SIGNAL MetaFIFO_Misc_put									: STD_LOGIC;
	SIGNAL MetaFIFO_Misc_DataIn								: STD_LOGIC_VECTOR(META_MISC_BITS - 1 DOWNTO 0);
	SIGNAL MetaFIFO_Misc_Full									: STD_LOGIC;
	SIGNAL MetaFIFO_Misc_got									: STD_LOGIC;
	SIGNAL MetaFIFO_Misc_DataOut							: STD_LOGIC_VECTOR(META_MISC_BITS - 1 DOWNTO 0);
	SIGNAL MetaFIFO_Misc_Valid								: STD_LOGIC;

	SIGNAL Meta_rst														: STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
	
BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				Writer_State					<= ST_IDLE;
				Reader_State					<= ST_IDLE;
			ELSE
				Writer_State					<= Writer_NextState;
				Reader_State					<= Reader_NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(Writer_State,
					In_Valid, In_SOF, In_EOF, In_Data,
					WordCounter_us, Checksum0_nxt_cy,
					DataFIFO_Full, MetaFIFO_Misc_Full)
	BEGIN
		Writer_NextState								<= Writer_State;
		
		DataFIFO_put										<= '0';
		MetaFIFO_Misc_put								<= '0';
		
		In_Ready												<= NOT DataFIFO_Full;
		
		WordCounter_rst									<= '0';
		WordCounter_en									<= '0';
		
		Checksum_rst										<= '0';
		Checksum_en											<= '0';
		Checksum_Data_us								<= unsigned(In_Data);
		
		CASE Writer_State IS
			WHEN ST_IDLE =>
				IF ((In_Valid AND In_SOF AND (NOT DataFIFO_Full)) = '1') THEN
					WordCounter_en						<= '1';
					Checksum_en								<= '1';
					DataFIFO_put							<= In_Valid;
					
					IF (In_EOF = '1') THEN
						MetaFIFO_Misc_put						<= '1';
					
						Writer_NextState				<= ST_IDLE;
					ELSE
						Writer_NextState				<= ST_FRAME;
					END IF;
				END IF;
	
			WHEN ST_FRAME =>
				DataFIFO_put								<= In_Valid;
				
				IF ((In_Valid AND (NOT DataFIFO_Full)) = '1') THEN
					WordCounter_en						<= '1';
					Checksum_en								<= '1';
					
					IF (In_EOF = '1') THEN
						WordCounter_en					<= '0';
						
						IF (Checksum0_nxt_cy = '0') THEN
							WordCounter_rst			<= '1';
							Checksum_rst				<= '1';
							
							MetaFIFO_Misc_put				<= '1';
							
							Writer_NextState		<= ST_IDLE;
						ELSE
							Writer_NextState		<= ST_CARRY_1;
						END IF;
					END IF;
				END IF;
				
			WHEN ST_CARRY_1 =>			
				In_Ready										<= '0';

				Checksum_Data_us						<= (OTHERS => '0');
				
				IF (Checksum0_nxt_cy = '0') THEN
					Checksum_rst							<= '1';
					WordCounter_rst						<= '1';

					MetaFIFO_Misc_put							<= '1';

					Writer_NextState					<= ST_IDLE;
				ELSE
					Checksum_en								<= '1';
					
					Writer_NextState					<= ST_CARRY_2;
				END IF;
				
			WHEN ST_CARRY_2 =>			
				In_Ready										<= '0';

				Checksum_Data_us						<= (OTHERS => '0');
				Checksum_rst								<= '1';
				WordCounter_rst							<= '1';

				MetaFIFO_Misc_put								<= '1';

				Writer_NextState						<= ST_IDLE;
			
		END CASE;
	END PROCESS;


	PROCESS(Reader_State,
					Out_Ready,
					DataFIFO_Valid, DataFIFO_DataOut,
					MetaFIFO_Misc_Valid, MetaFIFO_Misc_DataOut)
	BEGIN
		Reader_NextState								<= Reader_State;
		
		Out_Valid												<= '0';
		Out_Data												<= DataFIFO_DataOut(Out_Data'range);
		Out_SOF													<= '0';
		Out_EOF													<= DataFIFO_DataOut(EOF_BIT);
		Out_Meta_Checksum								<= MetaFIFO_Misc_DataOut(Checksum'range);
		Out_Meta_Length									<= resize(MetaFIFO_Misc_DataOut(WordCount'range), Out_Meta_Length'length);
		
		DataFIFO_got										<= '0';
		
		CASE Reader_State IS
			WHEN ST_IDLE =>
				Out_SOF											<= '1';
			
				IF ((DataFIFO_Valid AND MetaFIFO_Misc_Valid) = '1') THEN
					Out_Valid									<= '1';
					
					IF (Out_Ready = '1') THEN
						DataFIFO_got						<= '1';
					
						IF (DataFIFO_DataOut(EOF_BIT) = '0') THEN
							Reader_NextState			<= ST_FRAME;
						END IF;
					END IF;
				END IF;
			
			WHEN ST_FRAME =>
				Out_Valid										<= DataFIFO_Valid;

				IF (Out_Ready = '1') THEN
					DataFIFO_got							<= '1';
					
					IF (DataFIFO_DataOut(EOF_BIT) = '1') THEN
						Reader_NextState				<= ST_IDLE;
					END IF;
				END IF;

		END CASE;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (WordCounter_rst = '1') THEN
				WordCounter_us		<= to_unsigned(1, WordCounter_us'length);
			ELSE
				IF (WordCounter_en = '1') THEN
					WordCounter_us	<= WordCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	Checksum0_nxt_cy		<= Checksum0_nxt_us(Checksum0_nxt_us'high);
	Checksum0_nxt_us		<= ('0' & Checksum1_d_us) + ('0' & Checksum_Data_us) + ((Checksum1_d_us'range => '0') & Checksum0_d_us(Checksum0_d_us'high));
	Checksum1_nxt_us		<= Checksum0_d_us(Checksum1_d_us'range);
					
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Checksum_rst = '1') THEN
				Checksum0_d_us			<= (OTHERS => '0');
				Checksum1_d_us			<= (OTHERS => '0');
			ELSE
				IF (Checksum_en = '1') THEN
					Checksum0_d_us		<= Checksum0_nxt_us;
					Checksum1_d_us		<= Checksum1_nxt_us;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	Checksum			<= std_logic_vector(Checksum0_nxt_us(Checksum1_nxt_us'range)) & std_logic_vector(Checksum1_nxt_us);
	WordCount			<= std_logic_vector(WordCounter_us);

	DataFIFO_DataIn(In_Data'range)		<= In_Data;
	DataFIFO_DataIn(EOF_BIT)					<= In_EOF;
	
	DataFIFO : ENTITY PoC.fifo_cc_got
		GENERIC MAP (
			D_BITS							=> DataFIFO_DataIn'length,			-- Data Width
			MIN_DEPTH						=> MAX_FRAME_LENGTH,						-- Minimum FIFO Depth
			DATA_REG						=> FALSE,												-- Store Data Content in Registers
			STATE_REG						=> TRUE,												-- Registered Full/Empty Indicators
			OUTPUT_REG					=> TRUE,												-- Registered FIFO Output
			ESTATE_WR_BITS			=> 0,														-- Empty State Bits
			FSTATE_RD_BITS			=> 0														-- Full State Bits
		)
		PORT MAP (
			clk									=> Clock,
			rst									=> Reset,
			-- Write Interface
			put									=> DataFIFO_put,
			din									=> DataFIFO_DataIn,
			full								=> DataFIFO_Full,
			estate_wr						=> OPEN,
			-- Read Interface
			got									=> DataFIFO_got,
			valid								=> DataFIFO_Valid,
			dout								=> DataFIFO_DataOut,
			fstate_rd						=> OPEN
		);

	MetaFIFO_Misc_DataIn(Checksum'range)		<= ite((WordCounter_us(0) = to_sl(Writer_State /= ST_CARRY_1)), Checksum, swap(Checksum, 8));
	MetaFIFO_Misc_DataIn(WordCount'range)		<= WordCount;
	
	MetaFIFO_Misc : ENTITY PoC.fifo_cc_got
		GENERIC MAP (
			D_BITS							=> MetaFIFO_Misc_DataIn'length,							-- Data Width
			MIN_DEPTH						=> MAX_FRAMES,															-- Minimum FIFO Depth
			DATA_REG						=> TRUE,																		-- Store Data Content in Registers
			STATE_REG						=> TRUE,																		-- Registered Full/Empty Indicators
			OUTPUT_REG					=> FALSE,																		-- Registered FIFO Output
			ESTATE_WR_BITS			=> 0,																				-- Empty State Bits
			FSTATE_RD_BITS			=> 0																				-- Full State Bits
		)
		PORT MAP (
			clk									=> Clock,
			rst									=> Reset,
			-- Write Interface
			put									=> MetaFIFO_Misc_put,
			din									=> MetaFIFO_Misc_DataIn,
			full								=> MetaFIFO_Misc_Full,
			estate_wr						=> OPEN,
			-- Read Interface
			got									=> MetaFIFO_Misc_got,
			valid								=> MetaFIFO_Misc_Valid,
			dout								=> MetaFIFO_Misc_DataOut,
			fstate_rd						=> OPEN
		);
	
	Out_Meta_Length					<= resize(MetaFIFO_Misc_DataOut(WordCount'range), Out_Meta_Length'length);
	Out_Meta_Checksum				<= MetaFIFO_Misc_DataOut(Checksum'range);
	
	FrameCommit							<= DataFIFO_Valid AND DataFIFO_DataOut(EOF_BIT) AND Out_Ready;
	MetaFIFO_Misc_got				<= FrameCommit;
	
	genMeta : FOR I IN 0 TO META_BITS'length - 1 GENERATE
		SIGNAL MetaFIFO_put						: STD_LOGIC;
		SIGNAL MetaFIFO_DataIn				: STD_LOGIC_VECTOR(META_BITS(I) - 1 DOWNTO 0);
		SIGNAL MetaFIFO_Full					: STD_LOGIC;
		SIGNAL MetaFIFO_got						: STD_LOGIC;
		SIGNAL MetaFIFO_DataOut				: STD_LOGIC_VECTOR(META_BITS(I) - 1 DOWNTO 0);
		SIGNAL MetaFIFO_Valid					: STD_LOGIC;
		SIGNAL MetaFIFO_Commit				: STD_LOGIC;
		SIGNAL MetaFIFO_Rollback			: STD_LOGIC;
		
		SIGNAL Writer_CounterControl	: STD_LOGIC																																:= '0';
		
		SIGNAL Writer_Counter_rst			: STD_LOGIC;
		SIGNAL Writer_Counter_en			: STD_LOGIC;
		SIGNAL Writer_Counter_us			: UNSIGNED(log2ceilnz(META_FIFO_DEPTH(I) * MAX_FRAMES) - 1 DOWNTO 0)			:= (OTHERS => '0');
	BEGIN
		Writer_Counter_rst		<= '0';		-- FIXME: is this correct?
	
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (Reset = '1') THEN
					Writer_CounterControl			<= '0';
				ELSE
					IF ((In_Valid AND In_SOF) = '1') THEN
						Writer_CounterControl		<= '1';
					ELSIF (Writer_Counter_us = (META_FIFO_DEPTH(I) - 1)) THEN
						Writer_CounterControl		<= '0';
					END IF;
				END IF;
			END IF;
		END PROCESS;
	
		Writer_Counter_en		<= (In_Valid AND In_SOF) OR Writer_CounterControl;
		
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF ((Reset OR Writer_Counter_rst) = '1') THEN
					Writer_Counter_us					<= (OTHERS => '0');
				ELSE
					IF (Writer_Counter_en = '1') THEN
						Writer_Counter_us				<= Writer_Counter_us + 1;
					END IF;
				END IF;
			END IF;
		END PROCESS;
		
		Meta_rst(I)					<= NOT Writer_Counter_en;
		In_Meta_nxt(I)			<= Writer_Counter_en;
		
		MetaFIFO_put				<= Writer_Counter_en;
		MetaFIFO_DataIn			<= In_Meta_Data(high(META_BITS, I) DOWNTO low(META_BITS, I));
	
		MetaFIFO : ENTITY PoC.fifo_cc_got_tempgot
			GENERIC MAP (
				D_BITS							=> MetaFIFO_DataIn'length,							-- Data Width
				MIN_DEPTH						=> (META_FIFO_DEPTH(I) * MAX_FRAMES),		-- Minimum FIFO Depth
				DATA_REG						=> TRUE,																-- Store Data Content in Registers
				STATE_REG						=> TRUE,																-- Registered Full/Empty Indicators
				OUTPUT_REG					=> FALSE,																-- Registered FIFO Output
				ESTATE_WR_BITS			=> 0,																		-- Empty State Bits
				FSTATE_RD_BITS			=> 0																		-- Full State Bits
			)
			PORT MAP (
				clk									=> Clock,
				rst									=> Reset,
				-- Write Interface
				put									=> MetaFIFO_put,
				din									=> MetaFIFO_DataIn,
				full								=> MetaFIFO_Full,
				estate_wr						=> OPEN,
				-- Read Interface
				got									=> MetaFIFO_got,
				valid								=> MetaFIFO_Valid,
				dout								=> MetaFIFO_DataOut,
				fstate_rd						=> OPEN,
				
				commit							=> MetaFIFO_Commit,
				rollback						=> MetaFIFO_Rollback
			);
		
		MetaFIFO_got				<= Out_Meta_nxt(I);
		MetaFIFO_Commit			<= FrameCommit;
		MetaFIFO_Rollback		<= Out_Meta_rst;
	
		Out_Meta_Data(high(META_BITS, I) DOWNTO low(META_BITS, I))	<= MetaFIFO_DataOut;
	END GENERATE;

	In_Meta_rst						<= slv_and(Meta_rst);

END ARCHITECTURE;
