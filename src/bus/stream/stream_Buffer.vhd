LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;


ENTITY Stream_Buffer IS
	GENERIC (
		FRAMES												: POSITIVE																								:= 2;
		DATA_BITS											: POSITIVE																								:= 8;
		DATA_FIFO_DEPTH								: POSITIVE																								:= 8;
		META_BITS											: T_POSVEC																								:= (0 => 8);
		META_FIFO_DEPTH								: T_POSVEC																								:= (0 => 16)
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		-- IN Port
		In_Valid											: IN	STD_LOGIC;
		In_Data												: IN	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		In_SOF												: IN	STD_LOGIC;
		In_EOF												: IN	STD_LOGIC;
		In_Ready											: OUT	STD_LOGIC;
		In_Meta_rst										: OUT	STD_LOGIC;
		In_Meta_nxt										: OUT	STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
		In_Meta_Data									: IN	STD_LOGIC_VECTOR(isum(META_BITS) - 1 DOWNTO 0);
		-- OUT Port
		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	STD_LOGIC_VECTOR(DATA_BITS - 1 DOWNTO 0);
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ready											: IN	STD_LOGIC;
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_nxt									: IN	STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);
		Out_Meta_Data									: OUT	STD_LOGIC_VECTOR(isum(META_BITS) - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF Stream_Buffer IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	CONSTANT META_STREAMS							: POSITIVE																						:= META_BITS'length;

	TYPE T_WRITER_STATE IS (ST_IDLE, ST_FRAME);
	TYPE T_READER_STATE IS (ST_IDLE, ST_FRAME);
	
	SIGNAL Writer_State								: T_WRITER_STATE																			:= ST_IDLE;
	SIGNAL Writer_NextState						: T_WRITER_STATE;
	SIGNAL Reader_State								: T_READER_STATE																			:= ST_IDLE;
	SIGNAL Reader_NextState						: T_READER_STATE;

	CONSTANT EOF_BIT									: NATURAL																							:= DATA_BITS;

	SIGNAL DataFIFO_put								: STD_LOGIC;
	SIGNAL DataFIFO_DataIn						: STD_LOGIC_VECTOR(DATA_BITS DOWNTO 0);
	SIGNAL DataFIFO_Full							: STD_LOGIC;
	
	SIGNAL DataFIFO_got								: STD_LOGIC;
	SIGNAL DataFIFO_DataOut						: STD_LOGIC_VECTOR(DataFIFO_DataIn'range);
	SIGNAL DataFIFO_Valid							: STD_LOGIC;

	SIGNAL FrameCommit								: STD_LOGIC;
	SIGNAL Meta_rst										: STD_LOGIC_VECTOR(META_BITS'length - 1 DOWNTO 0);

BEGIN
	ASSERT (META_BITS'length = META_FIFO_DEPTH'length) REPORT "META_BITS'length /= META_FIFO_DEPTH'length" SEVERITY FAILURE;

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
					In_Valid, In_Data, In_SOF, In_EOF,
					DataFIFO_Full)
	BEGIN
		Writer_NextState									<= Writer_State;
		
		In_Ready													<= '0';
		
		DataFIFO_put											<= '0';
		DataFIFO_DataIn(In_Data'range)		<= In_Data;
		DataFIFO_DataIn(EOF_BIT)					<= In_EOF;
		
		CASE Writer_State IS
			WHEN ST_IDLE =>
				In_Ready											<= NOT DataFIFO_Full;
				DataFIFO_put									<= In_Valid;
						
				IF ((In_Valid AND In_SOF AND NOT In_EOF) = '1') THEN
					
					Writer_NextState						<= ST_FRAME;
				END IF;
				
			WHEN ST_FRAME =>
				In_Ready											<= NOT DataFIFO_Full;
				DataFIFO_put									<= In_Valid;
			
				IF ((In_Valid AND In_EOF AND NOT DataFIFO_Full) = '1') THEN
				
					Writer_NextState						<= ST_IDLE;
				END IF;
		END CASE;
	END PROCESS;
	

	PROCESS(Reader_State,
					Out_Ready,
					DataFIFO_Valid, DataFIFO_DataOut)
	BEGIN
		Reader_NextState								<= Reader_State;
		
		Out_Valid												<= '0';
		Out_Data												<= DataFIFO_DataOut(Out_Data'range);
		Out_SOF													<= '0';
		Out_EOF													<= DataFIFO_DataOut(EOF_BIT);
		
		DataFIFO_got										<= '0';
	
		CASE Reader_State IS
			WHEN ST_IDLE =>
				Out_Valid										<= DataFIFO_Valid;
				Out_SOF											<= '1';
				DataFIFO_got								<= Out_Ready;
			
				IF ((DataFIFO_Valid AND NOT DataFIFO_DataOut(EOF_BIT) AND Out_Ready) = '1') THEN
					Reader_NextState					<= ST_FRAME;
				END IF;
			
			WHEN ST_FRAME =>
				Out_Valid										<= DataFIFO_Valid;
				DataFIFO_got								<= Out_Ready;

				IF ((DataFIFO_Valid AND DataFIFO_DataOut(EOF_BIT) AND Out_Ready) = '1') THEN
					Reader_NextState					<= ST_IDLE;
				END IF;

		END CASE;
	END PROCESS;
	
	DataFIFO : ENTITY PoC.fifo_cc_got
		GENERIC MAP (
			D_BITS							=> DATA_BITS + 1,								-- Data Width
			MIN_DEPTH						=> (DATA_FIFO_DEPTH * FRAMES),	-- Minimum FIFO Depth
			DATA_REG						=> ((DATA_FIFO_DEPTH * FRAMES) <= 128),											-- Store Data Content in Registers
			STATE_REG						=> TRUE,												-- Registered Full/Empty Indicators
			OUTPUT_REG					=> FALSE,												-- Registered FIFO Output
			ESTATE_WR_BITS			=> 0,														-- Empty State Bits
			FSTATE_RD_BITS			=> 0														-- Full State Bits
		)
		PORT MAP (
			-- Global Reset and Clock
			clk									=> Clock,
			rst									=> Reset,
			
			-- Writing Interface
			put									=> DataFIFO_put,
			din									=> DataFIFO_DataIn,
			full								=> DataFIFO_Full,
			estate_wr						=> OPEN,

			-- Reading Interface
			got									=> DataFIFO_got,
			dout								=> DataFIFO_DataOut,
			valid								=> DataFIFO_Valid,
			fstate_rd						=> OPEN
		);
	
	FrameCommit		<= DataFIFO_Valid AND DataFIFO_DataOut(EOF_BIT) AND Out_Ready;
	In_Meta_rst		<= slv_and(Meta_rst);
	
	genMeta : FOR I IN 0 TO META_BITS'length - 1 GENERATE
		
	BEGIN
		genReg : IF (META_FIFO_DEPTH(I) = 1) GENERATE
			SIGNAL MetaReg_DataIn				: STD_LOGIC_VECTOR(META_BITS(I) - 1 DOWNTO 0);
			SIGNAL MetaReg_d						: STD_LOGIC_VECTOR(META_BITS(I) - 1 DOWNTO 0)		:= (OTHERS => '0');
			SIGNAL MetaReg_DataOut			: STD_LOGIC_VECTOR(META_BITS(I) - 1 DOWNTO 0);
		BEGIN
			MetaReg_DataIn		<= In_Meta_Data(high(META_BITS, I) DOWNTO low(META_BITS, I));
		
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF (Reset = '1') THEN
						MetaReg_d			<= (OTHERS => '0');
					ELSE
						IF ((In_Valid AND In_SOF) = '1') THEN
							MetaReg_d		<= MetaReg_DataIn;
						END IF;
					END IF;
				END IF;
			END PROCESS;
			
			MetaReg_DataOut		<= MetaReg_d;
			Out_Meta_Data(high(META_BITS, I) DOWNTO low(META_BITS, I))	<= MetaReg_DataOut;
		END GENERATE;	-- META_FIFO_DEPTH(I) = 1
		genFIFO : IF (META_FIFO_DEPTH(I) > 1) GENERATE
			SIGNAL MetaFIFO_put								: STD_LOGIC;
			SIGNAL MetaFIFO_DataIn						: STD_LOGIC_VECTOR(META_BITS(I) - 1 DOWNTO 0);
			SIGNAL MetaFIFO_Full							: STD_LOGIC;
			
			SIGNAL MetaFIFO_Commit						: STD_LOGIC;
			SIGNAL MetaFIFO_Rollback					: STD_LOGIC;
			
			SIGNAL MetaFIFO_got								: STD_LOGIC;
			SIGNAL MetaFIFO_DataOut						: STD_LOGIC_VECTOR(MetaFIFO_DataIn'range);
			SIGNAL MetaFIFO_Valid							: STD_LOGIC;
			
			SIGNAL Writer_CounterControl			: STD_LOGIC																																:= '0';
			SIGNAL Writer_Counter_en					: STD_LOGIC;
			SIGNAL Writer_Counter_us					: UNSIGNED(log2ceilnz(META_FIFO_DEPTH(I)) - 1 DOWNTO 0)										:= (OTHERS => '0');
		BEGIN
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
					IF (Writer_Counter_en = '0') THEN
						Writer_Counter_us					<= (OTHERS => '0');
					ELSE
						Writer_Counter_us					<= Writer_Counter_us + 1;
					END IF;
				END IF;
			END PROCESS;
			
			Meta_rst(I)					<= NOT Writer_Counter_en;
			In_Meta_nxt(I)			<= Writer_Counter_en;
			
			MetaFIFO_put				<= Writer_Counter_en;
			MetaFIFO_DataIn			<= In_Meta_Data(high(META_BITS, I) DOWNTO low(META_BITS, I));
		
			MetaFIFO : ENTITY PoC.fifo_cc_got_tempgot
				GENERIC MAP (
					D_BITS							=> META_BITS(I),										-- Data Width
					MIN_DEPTH						=> (META_FIFO_DEPTH(I) * FRAMES),		-- Minimum FIFO Depth
					DATA_REG						=> TRUE,														-- Store Data Content in Registers
					STATE_REG						=> FALSE,														-- Registered Full/Empty Indicators
					OUTPUT_REG					=> FALSE,														-- Registered FIFO Output
					ESTATE_WR_BITS			=> 0,																-- Empty State Bits
					FSTATE_RD_BITS			=> 0																-- Full State Bits
				)
				PORT MAP (
					-- Global Reset and Clock
					clk									=> Clock,
					rst									=> Reset,
					
					-- Writing Interface
					put									=> MetaFIFO_put,
					din									=> MetaFIFO_DataIn,
					full								=> MetaFIFO_Full,
					estate_wr						=> OPEN,

					-- Reading Interface
					got									=> MetaFIFO_got,
					dout								=> MetaFIFO_DataOut,
					valid								=> MetaFIFO_Valid,
					fstate_rd						=> OPEN,

					commit							=> MetaFIFO_Commit,
					rollback						=> MetaFIFO_Rollback
				);
		
			MetaFIFO_got				<= Out_Meta_nxt(I);
			MetaFIFO_Commit			<= FrameCommit;
			MetaFIFO_Rollback		<= Out_Meta_rst;
		
			Out_Meta_Data(high(META_BITS, I) DOWNTO low(META_BITS, I))	<= MetaFIFO_DataOut;
		END GENERATE;	-- (META_FIFO_DEPTH(I) > 1)
	END GENERATE;
END;