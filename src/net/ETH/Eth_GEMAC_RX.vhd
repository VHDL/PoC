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


ENTITY Eth_GEMAC_RX IS
	GENERIC (
		DEBUG						: BOOLEAN						:= FALSE
	);
	PORT (
		RS_RX_Clock								: IN	STD_LOGIC;
		RS_RX_Reset								: IN	STD_LOGIC;
	
		-- MAC interface
		RX_Valid									: OUT	STD_LOGIC;
		RX_Data										: OUT	T_SLV_8;
		RX_SOF										: OUT	STD_LOGIC;
		RX_EOF										: OUT	STD_LOGIC;
		RX_GoodFrame							: OUT	STD_LOGIC;
		
		-- Reconcilation Sublayer interface
		RS_RX_Valid								: IN	STD_LOGIC;
		RS_RX_Data								: IN	T_SLV_8;
		RS_RX_Error								: IN	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF Eth_GEMAC_RX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_RECEIVE_PREAMBLE,
		ST_RECEIVED_START_OF_FRAME_DELIMITER,
		ST_RECEIVE_DATA,
		ST_DISCARD_FRAME
	);
	
	SIGNAL State											: T_STATE									:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	CONSTANT PREAMBLE_COUNTER_BW			: POSITIVE																			:= log2ceilnz(C_NET_ETH_PREMABLE_LENGTH);
	SIGNAL PreambleCounter_rst				: STD_LOGIC;
	SIGNAL PreambleCounter_en					: STD_LOGIC;
	SIGNAL PreambleCounter_eq					: STD_LOGIC;
	SIGNAL PreambleCounter_us					: UNSIGNED(PREAMBLE_COUNTER_BW - 1 DOWNTO 0)		:= (OTHERS => '0');
	
	SIGNAL Register_en								: STD_LOGIC;
	SIGNAL DataRegister_d							: T_SLVV_8(4 DOWNTO 0)													:= (OTHERS => (OTHERS => '0'));
	SIGNAL SOFRegister_en							: STD_LOGIC;
	SIGNAL SOFRegister_d							: STD_LOGIC_VECTOR(4 DOWNTO 0)									:= (OTHERS => '0');
	SIGNAL Valid_rst									: STD_LOGIC;
	SIGNAL Valid_set									: STD_LOGIC;
	SIGNAL Valid_r										: STD_LOGIC;
	
	SIGNAL CRC_rst										: STD_LOGIC;
	SIGNAL CRC_en											: STD_LOGIC;
	SIGNAL CRC_OK											: STD_LOGIC;
	
	SIGNAL FSM_SOF										: STD_LOGIC;
	SIGNAL FSM_EOF										: STD_LOGIC;
	
BEGIN
	PROCESS(RS_RX_Clock)
	BEGIN
		IF rising_edge(RS_RX_Clock) THEN
			IF (RS_RX_Reset = '1') THEN
				State			<= ST_IDLE;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, RS_RX_Data, RS_RX_Valid, RS_RX_Error, PreambleCounter_eq)
	BEGIN
		NextState										<= State;
		
		FSM_SOF											<= '0';
		FSM_EOF											<= '0';
		
		Register_en									<= '0';
		
		PreambleCounter_rst					<= '0';
		PreambleCounter_en					<= '0';
		
		CRC_rst											<= '0';
		CRC_en											<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				PreambleCounter_rst			<= '1';
				CRC_rst									<= '1';
			
				IF (RS_RX_Valid = '1') THEN
					IF (RS_RX_Data = x"55") THEN
						NextState						<= ST_RECEIVE_PREAMBLE;
					ELSE
						NextState						<= ST_DISCARD_FRAME;
					END IF;
				END IF;
			
			WHEN ST_RECEIVE_PREAMBLE =>
				IF (RS_RX_Valid = '1') THEN
					IF (RS_RX_Data = x"55") THEN
						PreambleCounter_en	<= '1';
					ELSIF (RS_RX_Data = x"D5") THEN
						NextState						<= ST_RECEIVED_START_OF_FRAME_DELIMITER;
					ELSE
						NextState						<= ST_DISCARD_FRAME;
					END IF;
				ELSE
					NextState							<= ST_IDLE;
				END IF;
				
				IF (PreambleCounter_eq = '1') THEN
					IF (RS_RX_Valid = '1') THEN
						NextState							<= ST_DISCARD_FRAME;
					ELSE
						NextState							<= ST_IDLE;
					END IF;
				END IF;
				
			WHEN ST_RECEIVED_START_OF_FRAME_DELIMITER =>
				Register_en								<= '1';
				CRC_en										<= '1';
				
				FSM_SOF										<= '1';
			
				IF (RS_RX_Valid = '1') THEN
					NextState								<= ST_RECEIVE_DATA;
				ELSE
					NextState								<= ST_IDLE;
				END IF;
			
			WHEN ST_RECEIVE_DATA =>
				Register_en								<= '1';
				CRC_en										<= '1';
				
				IF (RS_RX_Valid = '0') THEN
					Register_en							<= '0';
					CRC_en									<= '0';
					
					FSM_EOF									<= '1';
					
					NextState								<= ST_IDLE;
				END IF;
			
			WHEN ST_DISCARD_FRAME =>
				IF (RS_RX_Valid = '0') THEN
					NextState								<= ST_IDLE;
				END IF;
			
		END CASE;
	END PROCESS;

	PROCESS(RS_RX_Clock)
	BEGIN
		IF rising_edge(RS_RX_Clock) THEN
			IF (PreambleCounter_rst = '1') THEN
				PreambleCounter_us			<= (OTHERS => '0');
			ELSE
				IF (PreambleCounter_en = '1') THEN
					PreambleCounter_us		<= PreambleCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PreambleCounter_eq		<= to_sl(PreambleCounter_us = C_NET_ETH_PREMABLE_LENGTH);
	
	PROCESS(RS_RX_Clock)
	BEGIN
		IF rising_edge(RS_RX_Clock) THEN
			IF (Register_en = '1') THEN
				SOFRegister_d				<= SOFRegister_d(SOFRegister_d'high - 1 DOWNTO 0)		& FSM_SOF;
				DataRegister_d			<= DataRegister_d(DataRegister_d'high - 1 DOWNTO 0) & RS_RX_Data;
			END IF;
		END IF;
	END PROCESS;
	
	Valid_rst				<= FSM_EOF;
	Valid_set				<= SOFRegister_d(SOFRegister_d'high - 1);
	
	PROCESS(RS_RX_Clock)
	BEGIN
		IF rising_edge(RS_RX_Clock) THEN
			IF ((RS_RX_Reset OR Valid_rst) = '1') THEN
				Valid_r				<= '0';
			ELSIF (Valid_set = '1') THEN
				Valid_r				<= '1';
			END IF;
		END IF;
	END PROCESS;
	
	blkCRC : BLOCK
		CONSTANT CRC32_POLYNOMIAL					: BIT_VECTOR(35 DOWNTO 0) := x"104C11DB7";
		CONSTANT CRC32_INIT								: T_SLV_32								:=  x"FFFFFFFF";
		
		SIGNAL CRC_DataIn									: T_SLV_8;
		SIGNAL CRC_DataOut								: T_SLV_32;
		SIGNAL CRC_Value									: T_SLV_32;
		
		SIGNAL CRC_Byte0_d								: T_SLVV_8(0 DOWNTO 0);
		SIGNAL CRC_Byte1_d								: T_SLVV_8(1 DOWNTO 0);
		SIGNAL CRC_Byte2_d								: T_SLVV_8(2 DOWNTO 0);
		SIGNAL CRC_Byte3_d								: T_SLVV_8(3 DOWNTO 0);

		SIGNAL CRC_ByteMatched_d					: STD_LOGIC_VECTOR(3 DOWNTO 0);
				
		ATTRIBUTE KEEP OF CRC_Value						: SIGNAL IS TRUE;
		
-- for debugging 
--		ATTRIBUTE KEEP OF CRC_Byte0_d					: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF CRC_Byte1_d					: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF CRC_Byte2_d					: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF CRC_Byte3_d					: SIGNAL IS TRUE;
		
--		ATTRIBUTE KEEP OF CRC_ByteMatched_d		: SIGNAL IS TRUE;

	BEGIN

		CRC_DataIn		<= reverse(RS_RX_Data);

		CRC : ENTITY PoC.comm_crc
			GENERIC MAP (
				GEN							=> CRC32_POLYNOMIAL(32 DOWNTO 0),		-- Generator Polynom
				BITS						=> CRC_DataIn'length								-- Number of Bits to be processed in parallel
			)
			PORT MAP (
				clk							=> RS_RX_Clock,											-- Clock
				
				set							=> CRC_rst,													-- Parallel Preload of Remainder
				init						=> CRC32_INIT,											
				step						=> CRC_en,													-- Process Input Data (MSB first)
				din							=> CRC_DataIn,

				rmd							=> CRC_DataOut,											-- Remainder
				zero						=> OPEN															-- Remainder is Zero
			);
		
		-- manipulate CRC value
		CRC_Value			<= NOT reverse(CRC_DataOut);
		
		CRC_Byte0_d(0)	<= CRC_Value(7	DOWNTO	0);
		CRC_Byte1_d(0)	<= CRC_Value(15 DOWNTO	8);
		CRC_Byte2_d(0)	<= CRC_Value(23 DOWNTO 16);
		CRC_Byte3_d(0)	<= CRC_Value(31 DOWNTO 24);
			
		-- delay some CRC bytes
		PROCESS(RS_RX_Clock)
		BEGIN
			IF rising_edge(RS_RX_Clock) THEN
				CRC_Byte1_d(CRC_Byte1_d'high DOWNTO 1)	<= CRC_Byte1_d(CRC_Byte1_d'high - 1 DOWNTO 0);
				CRC_Byte2_d(CRC_Byte2_d'high DOWNTO 1)	<= CRC_Byte2_d(CRC_Byte2_d'high - 1 DOWNTO 0);
				CRC_Byte3_d(CRC_Byte3_d'high DOWNTO 1)	<= CRC_Byte3_d(CRC_Byte3_d'high - 1 DOWNTO 0);
			END IF;
		END PROCESS;
		
		-- calculate byte matches and delay it
		CRC_ByteMatched_d(0)		<=  to_sl(CRC_Byte0_d(CRC_Byte0_d'high) = RS_RX_Data)															WHEN rising_edge(RS_RX_Clock);
		CRC_ByteMatched_d(1)		<= (to_sl(CRC_Byte1_d(CRC_Byte1_d'high) = RS_RX_Data) AND CRC_ByteMatched_d(0))		WHEN rising_edge(RS_RX_Clock);
		CRC_ByteMatched_d(2)		<= (to_sl(CRC_Byte2_d(CRC_Byte2_d'high) = RS_RX_Data) AND CRC_ByteMatched_d(1))		WHEN rising_edge(RS_RX_Clock);
		CRC_ByteMatched_d(3)		<= (to_sl(CRC_Byte3_d(CRC_Byte3_d'high) = RS_RX_Data) AND CRC_ByteMatched_d(2))		WHEN rising_edge(RS_RX_Clock);
		
		-- now a possible CRC_OK was delayed 4 times, so it should occur along with EOF
		CRC_OK <= CRC_ByteMatched_d(3);
	END BLOCK;
	
	RX_Valid			<= Valid_r;
	RX_Data				<= DataRegister_d(DataRegister_d'high);
	RX_SOF				<= SOFRegister_d(SOFRegister_d'high);
	RX_EOF				<= FSM_EOF;
	RX_GoodFrame	<= FSM_EOF AND CRC_OK;
END;
