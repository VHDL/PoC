LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;

PACKAGE stream IS
	-- single dataword for TestRAM
	TYPE T_SIM_STREAM_WORD_8 IS RECORD
		Valid			: STD_LOGIC;
		Data			: T_SLV_8;
		SOF				: STD_LOGIC;
		EOF				: STD_LOGIC;
		Ready			: STD_LOGIC;
		EOFG			: BOOLEAN;
	END RECORD;
	
	TYPE T_SIM_STREAM_WORD_32 IS RECORD
		Valid			: STD_LOGIC;
		Data			: T_SLV_32;
		SOF				: STD_LOGIC;
		EOF				: STD_LOGIC;
		Ready			: STD_LOGIC;
		EOFG			: BOOLEAN;
	END RECORD;
	
	-- define array indices
	CONSTANT C_SIM_STREAM_MAX_PATTERN_COUNT			: POSITIVE			:= 128;-- * 1024;				-- max data size per testcase
	CONSTANT C_SIM_STREAM_MAX_FRAMEGROUP_COUNT	: POSITIVE			:= 8;
	
	CONSTANT C_SIM_STREAM_WORD_INDEX_BW					: POSITIVE			:= log2ceilnz(C_SIM_STREAM_MAX_PATTERN_COUNT);
	CONSTANT C_SIM_STREAM_FRAMEGROUP_INDEX_BW		: POSITIVE			:= log2ceilnz(C_SIM_STREAM_MAX_FRAMEGROUP_COUNT);
	
	SUBTYPE T_SIM_STREAM_WORD_INDEX					IS INTEGER RANGE 0 TO C_SIM_STREAM_MAX_PATTERN_COUNT - 1;
	SUBTYPE T_SIM_STREAM_FRAMEGROUP_INDEX		IS INTEGER RANGE 0 TO C_SIM_STREAM_MAX_FRAMEGROUP_COUNT - 1;
	
	SUBTYPE T_SIM_DELAY											IS T_UINT_16;
	TYPE		T_SIM_DELAY_VECTOR							IS ARRAY (NATURAL RANGE <>) OF T_SIM_DELAY;
	
	-- define array of datawords
	TYPE		T_SIM_STREAM_WORD_VECTOR_8			IS ARRAY (NATURAL RANGE <>) OF T_SIM_STREAM_WORD_8;
	TYPE		T_SIM_STREAM_WORD_VECTOR_32			IS ARRAY (NATURAL RANGE <>) OF T_SIM_STREAM_WORD_32;
	
	-- define link layer directions
	TYPE		T_SIM_STREAM_DIRECTION					IS (SEND, RECEIVE);
	
	-- define framegroup information
	TYPE T_SIM_STREAM_FRAMEGROUP_8 IS RECORD
		Active					: BOOLEAN;
		Name						: STRING(1 TO 64);
		PrePause				: NATURAL;
		PostPause				: NATURAL;
		DataCount				: T_SIM_STREAM_WORD_INDEX;
		Data						: T_SIM_STREAM_WORD_VECTOR_8(0 TO C_SIM_STREAM_MAX_PATTERN_COUNT - 1);
	END RECORD;
	
	TYPE T_SIM_STREAM_FRAMEGROUP_32 IS RECORD
		Active					: BOOLEAN;
		Name						: STRING(1 TO 64);
		PrePause				: NATURAL;
		PostPause				: NATURAL;
		DataCount				: T_SIM_STREAM_WORD_INDEX;
		Data						: T_SIM_STREAM_WORD_VECTOR_32(T_SIM_STREAM_WORD_INDEX);
	END RECORD;
	
	-- define array of framegroups
	TYPE T_SIM_STREAM_FRAMEGROUP_VECTOR_8			IS ARRAY (NATURAL RANGE <>) OF T_SIM_STREAM_FRAMEGROUP_8;
	TYPE T_SIM_STREAM_FRAMEGROUP_VECTOR_32		IS ARRAY (NATURAL RANGE <>) OF T_SIM_STREAM_FRAMEGROUP_32;
	
	-- define constants (stored in RAMB36's parity-bits)
	CONSTANT C_SIM_STREAM_WORD_8_EMPTY			: T_SIM_STREAM_WORD_8		:= (Valid => '0', Data => (OTHERS => 'U'),	SOF => '0', EOF	=> '0', Ready => '0', EOFG => FALSE);
	CONSTANT C_SIM_STREAM_WORD_32_EMPTY			: T_SIM_STREAM_WORD_32	:= (Valid => '0', Data => (OTHERS => 'U'),	SOF => '0', EOF	=> '0', Ready => '0', EOFG => FALSE);
	CONSTANT C_SIM_STREAM_WORD_8_INVALID		: T_SIM_STREAM_WORD_8		:= (Valid	=> '0', Data => (OTHERS => 'U'),	SOF => '0', EOF	=> '0', Ready => '0', EOFG => FALSE);
	CONSTANT C_SIM_STREAM_WORD_32_INVALID		: T_SIM_STREAM_WORD_32	:= (Valid	=> '0', Data => (OTHERS => 'U'),	SOF => '0', EOF	=> '0', Ready => '0', EOFG => FALSE);
	CONSTANT C_SIM_STREAM_WORD_8_ZERO				: T_SIM_STREAM_WORD_8		:= (Valid	=> '1', Data => (OTHERS => 'Z'),	SOF => '0', EOF	=> '0', Ready => '0', EOFG => FALSE);
	CONSTANT C_SIM_STREAM_WORD_32_ZERO			: T_SIM_STREAM_WORD_32	:= (Valid	=> '1', Data => (OTHERS => 'Z'),	SOF => '0', EOF	=> '0', Ready => '0', EOFG => FALSE);
	CONSTANT C_SIM_STREAM_WORD_8_UNDEF			: T_SIM_STREAM_WORD_8		:= (Valid	=> '1', Data => (OTHERS => 'U'),	SOF => '0', EOF	=> '0', Ready => '0', EOFG => FALSE);
	CONSTANT C_SIM_STREAM_WORD_32_UNDEF			: T_SIM_STREAM_WORD_32	:= (Valid	=> '1', Data => (OTHERS => 'U'),	SOF => '0', EOF	=> '0', Ready => '0', EOFG => FALSE);
	
	CONSTANT C_SIM_STREAM_FRAMEGROUP_8_EMPTY	: T_SIM_STREAM_FRAMEGROUP_8		:= (
		Active						=> FALSE,
		Name							=> (OTHERS => nul),
		PrePause					=> 0,
		PostPause					=> 0,
		DataCount					=> 0,
		Data							=> (OTHERS => C_SIM_STREAM_WORD_8_EMPTY)
	);
	CONSTANT C_SIM_STREAM_FRAMEGROUP_32_EMPTY	: T_SIM_STREAM_FRAMEGROUP_32	:= (
		Active						=> FALSE,
		Name							=> (OTHERS => nul),
		PrePause					=> 0,
		PostPause					=> 0,
		DataCount					=> 0,
		Data							=> (OTHERS => C_SIM_STREAM_WORD_32_EMPTY)
	);
																											
	FUNCTION CountPatterns(Data : T_SIM_STREAM_WORD_VECTOR_8)	RETURN NATURAL;
	FUNCTION CountPatterns(Data : T_SIM_STREAM_WORD_VECTOR_32) RETURN NATURAL;

	FUNCTION dat(slv		: T_SLV_8)										RETURN T_SIM_STREAM_WORD_8;
	FUNCTION dat(slvv		: T_SLVV_8) 									RETURN T_SIM_STREAM_WORD_VECTOR_8;
	FUNCTION dat(slv		: T_SLV_32)										RETURN T_SIM_STREAM_WORD_32;
	FUNCTION dat(slvv		: T_SLVV_32)									RETURN T_SIM_STREAM_WORD_VECTOR_32;
	FUNCTION sof(slv		: T_SLV_8)										RETURN T_SIM_STREAM_WORD_8;
	FUNCTION sof(slvv		: T_SLVV_8) 									RETURN T_SIM_STREAM_WORD_VECTOR_8;
	FUNCTION sof(slv		: T_SLV_32)										RETURN T_SIM_STREAM_WORD_32;
	FUNCTION sof(slvv		: T_SLVV_32)									RETURN T_SIM_STREAM_WORD_VECTOR_32;
	FUNCTION eof(slv		: T_SLV_8)										RETURN T_SIM_STREAM_WORD_8;
	FUNCTION eof(slvv		: T_SLVV_8) 									RETURN T_SIM_STREAM_WORD_VECTOR_8;
	FUNCTION eof(slv		: T_SLV_32)										RETURN T_SIM_STREAM_WORD_32;
	FUNCTION eof(slvv		: T_SLVV_32)									RETURN T_SIM_STREAM_WORD_VECTOR_32;
	FUNCTION eof(stmw		: T_SIM_STREAM_WORD_8)				RETURN T_SIM_STREAM_WORD_8;
	FUNCTION eof(stmwv	: T_SIM_STREAM_WORD_VECTOR_8)	RETURN T_SIM_STREAM_WORD_VECTOR_8;
	FUNCTION eof(stmw		: T_SIM_STREAM_WORD_32)				RETURN T_SIM_STREAM_WORD_32;
	FUNCTION eofg(stmw	: T_SIM_STREAM_WORD_8)				RETURN T_SIM_STREAM_WORD_8;
	FUNCTION eofg(stmwv	: T_SIM_STREAM_WORD_VECTOR_8)	RETURN T_SIM_STREAM_WORD_VECTOR_8;
	FUNCTION eofg(stmw	: T_SIM_STREAM_WORD_32)				RETURN T_SIM_STREAM_WORD_32;
	
	FUNCTION to_string(stmw : T_SIM_STREAM_WORD_8)		RETURN STRING;
	FUNCTION to_string(stmw : T_SIM_STREAM_WORD_32)		RETURN STRING;

	-- checksum functions
	-- ================================================================
	FUNCTION sim_CRC8(words		: T_SIM_STREAM_WORD_VECTOR_8) RETURN STD_LOGIC_VECTOR;
--	FUNCTION sim_CRC16(words	: T_SIM_STREAM_WORD_VECTOR_8) RETURN STD_LOGIC_VECTOR;
END;


PACKAGE BODY stream IS
FUNCTION CountPatterns(Data : T_SIM_STREAM_WORD_VECTOR_8) RETURN NATURAL IS
	BEGIN
		FOR I IN 0 TO Data'length - 1 LOOP
			IF (Data(I).EOFG = TRUE) THEN
				RETURN I + 1;
			END IF;
		END LOOP;
		
		RETURN 0;
	END;

	FUNCTION CountPatterns(Data : T_SIM_STREAM_WORD_VECTOR_32) RETURN NATURAL IS
	BEGIN
		FOR I IN 0 TO Data'length - 1 LOOP
			IF (Data(I).EOFG = TRUE) THEN
				RETURN I + 1;
			END IF;
		END LOOP;
		
		RETURN 0;
	END;

	FUNCTION dat(slv : T_SLV_8) RETURN T_SIM_STREAM_WORD_8 IS
		VARIABLE result : T_SIM_STREAM_WORD_8;
	BEGIN
		result := (Valid => '1', Data	=> slv,	SOF	=> '0',	EOF	=> '0', Ready => '-', EOFG => FALSE);
		REPORT "dat: " & to_string(result) SEVERITY NOTE;
		RETURN result;
	END;

	FUNCTION dat(slvv : T_SLVV_8) RETURN T_SIM_STREAM_WORD_VECTOR_8 IS
		VARIABLE result			: T_SIM_STREAM_WORD_VECTOR_8(slvv'range);
	BEGIN
		FOR I IN slvv'range LOOP
			result(I)		:= dat(slvv(I));
		END LOOP;
		
		RETURN result;
	END;

	FUNCTION dat(slv : T_SLV_32) RETURN T_SIM_STREAM_WORD_32 IS
		VARIABLE result : T_SIM_STREAM_WORD_32;
	BEGIN
		result := (Valid => '1', Data	=> slv,	SOF	=> '0',	EOF	=> '0', Ready => '-', EOFG => FALSE);
		REPORT "dat: " & to_string(result) SEVERITY NOTE;
		RETURN result;
	END;

	FUNCTION dat(slvv : T_SLVV_32) RETURN T_SIM_STREAM_WORD_VECTOR_32 IS
		VARIABLE result			: T_SIM_STREAM_WORD_VECTOR_32(slvv'range);
	BEGIN
		FOR I IN slvv'range LOOP
			result(I)		:= dat(slvv(I));
		END LOOP;
		
		RETURN result;
	END;

	FUNCTION sof(slv : T_SLV_8) RETURN T_SIM_STREAM_WORD_8 IS
		VARIABLE result : T_SIM_STREAM_WORD_8;
	BEGIN
		result := (Valid => '1', Data	=> slv,	SOF	=> '1',	EOF	=> '0', Ready => '-', EOFG => FALSE);
		REPORT "sof: " & to_string(result) SEVERITY NOTE;
		RETURN result;
	END;
	
	FUNCTION sof(slvv : T_SLVV_8) RETURN T_SIM_STREAM_WORD_VECTOR_8 IS
		VARIABLE result			: T_SIM_STREAM_WORD_VECTOR_8(slvv'range);
	BEGIN
		result(slvv'low)		:= sof(slvv(slvv'low));
		FOR I IN slvv'low + 1 TO slvv'high LOOP
			result(I)		:= dat(slvv(I));
		END LOOP;
		RETURN result;
	END;
	
	FUNCTION sof(slv : T_SLV_32) RETURN T_SIM_STREAM_WORD_32 IS
		VARIABLE result : T_SIM_STREAM_WORD_32;
	BEGIN
		result := (Valid => '1', Data	=> slv,	SOF	=> '1',	EOF	=> '0', Ready => '-', EOFG => FALSE);
		REPORT "sof: " & to_string(result) SEVERITY NOTE;
		RETURN result;
	END;
	
	FUNCTION sof(slvv : T_SLVV_32) RETURN T_SIM_STREAM_WORD_VECTOR_32 IS
		VARIABLE result			: T_SIM_STREAM_WORD_VECTOR_32(slvv'range);
	BEGIN
		result(slvv'low)		:= sof(slvv(slvv'low));
		FOR I IN slvv'low + 1 TO slvv'high LOOP
			result(I)		:= dat(slvv(I));
		END LOOP;
		RETURN result;
	END;
	
	FUNCTION eof(slv : T_SLV_8) RETURN T_SIM_STREAM_WORD_8 IS
		VARIABLE result : T_SIM_STREAM_WORD_8;
	BEGIN
		result := (Valid => '1', Data	=> slv,	SOF	=> '0',	EOF	=> '1', Ready => '-', EOFG => FALSE);
		REPORT "eof: " & to_string(result) SEVERITY NOTE;
		RETURN result;
	END;
	
	FUNCTION eof(slvv : T_SLVV_8) RETURN T_SIM_STREAM_WORD_VECTOR_8 IS
		VARIABLE result			: T_SIM_STREAM_WORD_VECTOR_8(slvv'range);
	BEGIN
		FOR I IN slvv'low TO slvv'high - 1 LOOP
			result(I)		:= dat(slvv(I));
		END LOOP;
		result(slvv'high)		:= eof(slvv(slvv'high));
		RETURN result;
	END;
	
	FUNCTION eof(slv : T_SLV_32) RETURN T_SIM_STREAM_WORD_32 IS
		VARIABLE result : T_SIM_STREAM_WORD_32;
	BEGIN
		result := (Valid => '1', Data	=> slv,	SOF	=> '0',	EOF	=> '1', Ready => '-', EOFG => FALSE);
		REPORT "eof: " & to_string(result) SEVERITY NOTE;
		RETURN result;
	END;
	
	FUNCTION eof(slvv : T_SLVV_32) RETURN T_SIM_STREAM_WORD_VECTOR_32 IS
		VARIABLE result			: T_SIM_STREAM_WORD_VECTOR_32(slvv'range);
	BEGIN
		FOR I IN slvv'low TO slvv'high - 1 LOOP
			result(I)		:= dat(slvv(I));
		END LOOP;
		result(slvv'high)		:= eof(slvv(slvv'high));
		RETURN result;
	END;
	
	FUNCTION eof(stmw : T_SIM_STREAM_WORD_8) RETURN T_SIM_STREAM_WORD_8 IS
	BEGIN
		RETURN T_SIM_STREAM_WORD_8'(
			Valid		=> stmw.Valid,
			Data		=> stmw.Data,
			SOF			=> stmw.SOF,
			EOF			=> '1',
			Ready		=> '-',
			EOFG		=> stmw.EOFG);
	END FUNCTION;

	FUNCTION eof(stmw : T_SIM_STREAM_WORD_32) RETURN T_SIM_STREAM_WORD_32 IS
	BEGIN
		RETURN T_SIM_STREAM_WORD_32'(
			Valid		=> stmw.Valid,
			Data		=> stmw.Data,
			SOF			=> stmw.SOF,
			EOF			=> '1',
			Ready		=> '-',
			EOFG		=> stmw.EOFG);
	END FUNCTION;

	FUNCTION eof(stmwv : T_SIM_STREAM_WORD_VECTOR_8) RETURN T_SIM_STREAM_WORD_VECTOR_8 IS
		VARIABLE result			: T_SIM_STREAM_WORD_VECTOR_8(stmwv'range);
	BEGIN
		FOR I IN stmwv'low TO stmwv'high - 1 LOOP
			result(I)		:= stmwv(I);
		END LOOP;
		result(stmwv'high)		:= eof(stmwv(stmwv'high));
		
		RETURN result;
	END;

	FUNCTION eofg(stmw : T_SIM_STREAM_WORD_8) RETURN T_SIM_STREAM_WORD_8 IS
	BEGIN
		RETURN T_SIM_STREAM_WORD_8'(
			Valid		=> stmw.Valid,
			Data		=> stmw.Data,
			SOF			=> stmw.SOF,
			EOF			=> stmw.EOF,
			Ready		=> stmw.Ready,
			EOFG		=> TRUE);
	END FUNCTION;

	FUNCTION eofg(stmw : T_SIM_STREAM_WORD_32) RETURN T_SIM_STREAM_WORD_32 IS
	BEGIN
		RETURN T_SIM_STREAM_WORD_32'(
			Valid		=> stmw.Valid,
			Data		=> stmw.Data,
			SOF			=> stmw.SOF,
			EOF			=> stmw.EOF,
			Ready		=> stmw.Ready,
			EOFG		=> TRUE);
	END FUNCTION;
	
	FUNCTION eofg(stmwv : T_SIM_STREAM_WORD_VECTOR_8) RETURN T_SIM_STREAM_WORD_VECTOR_8 IS
		VARIABLE result			: T_SIM_STREAM_WORD_VECTOR_8(stmwv'range);
	BEGIN
		FOR I IN stmwv'low TO stmwv'high - 1 LOOP
			result(I)		:= stmwv(I);
		END LOOP;
		result(stmwv'high)		:= eofg(stmwv(stmwv'high));
		
		RETURN result;
	END;
	
	FUNCTION to_flag1_string(stmw : T_SIM_STREAM_WORD_8) RETURN STRING IS
		VARIABLE flag : STD_LOGIC_VECTOR(2 DOWNTO 0)	:= to_sl(stmw.EOFG) & stmw.EOF & stmw.SOF;
	BEGIN
		CASE flag IS
			WHEN "000" =>		RETURN "";
			WHEN "001" =>		RETURN "SOF";
			WHEN "010" =>		RETURN "EOF";
			WHEN "011" =>		RETURN "SOF+EOF";
			WHEN "100" =>		RETURN "*";
			WHEN "101" =>		RETURN "SOF*";
			WHEN "110" =>		RETURN "EOF*";
			WHEN "111" =>		RETURN "SOF+EOF*";
			WHEN OTHERS =>	RETURN "ERROR";
		END CASE;
	END FUNCTION;
	
	FUNCTION to_flag1_string(stmw : T_SIM_STREAM_WORD_32) RETURN STRING IS
		VARIABLE flag : STD_LOGIC_VECTOR(2 DOWNTO 0)	:= to_sl(stmw.EOFG) & stmw.EOF & stmw.SOF;
	BEGIN
		CASE flag IS
			WHEN "000" =>		RETURN "";
			WHEN "001" =>		RETURN "SOF";
			WHEN "010" =>		RETURN "EOF";
			WHEN "011" =>		RETURN "SOF+EOF";
			WHEN "100" =>		RETURN "*";
			WHEN "101" =>		RETURN "SOF*";
			WHEN "110" =>		RETURN "EOF*";
			WHEN "111" =>		RETURN "SOF+EOF*";
			WHEN OTHERS =>	RETURN "ERROR";
		END CASE;
	END FUNCTION;
	
	FUNCTION to_flag2_string(stmw : T_SIM_STREAM_WORD_8) RETURN STRING IS
		VARIABLE flag : STD_LOGIC_VECTOR(1 DOWNTO 0)	:= stmw.Ready & stmw.Valid;
	BEGIN
		CASE flag IS
			WHEN "00" =>		RETURN "  ";
			WHEN "01" =>		RETURN " V";
			WHEN "10" =>		RETURN "R ";
			WHEN "11" =>		RETURN "RV";
			WHEN "-0" =>		RETURN "- ";
			WHEN "-1" =>		RETURN "-V";
			WHEN OTHERS =>	RETURN "??";
		END CASE;
	END FUNCTION;
	
	FUNCTION to_flag2_string(stmw : T_SIM_STREAM_WORD_32) RETURN STRING IS
		VARIABLE flag : STD_LOGIC_VECTOR(1 DOWNTO 0)	:= stmw.Ready & stmw.Valid;
	BEGIN
		CASE flag IS
			WHEN "00" =>		RETURN "  ";
			WHEN "01" =>		RETURN " V";
			WHEN "10" =>		RETURN "R ";
			WHEN "11" =>		RETURN "RV";
			WHEN "-0" =>		RETURN "- ";
			WHEN "-1" =>		RETURN "-V";
			WHEN OTHERS =>	RETURN "??";
		END CASE;
	END FUNCTION;
	
	FUNCTION to_string(stmw : T_SIM_STREAM_WORD_8) RETURN STRING IS
	BEGIN
		RETURN to_flag2_string(stmw) & " 0x" & to_string(stmw.Data, 'h') & " " & to_flag1_string(stmw);
	END FUNCTION;
	
	FUNCTION to_string(stmw : T_SIM_STREAM_WORD_32) RETURN STRING IS
	BEGIN
		RETURN to_flag2_string(stmw) & " 0x" & to_string(stmw.Data, 'h') & " " & to_flag1_string(stmw);
	END FUNCTION;

	-- checksum functions
	-- ================================================================
--	-- Private function to_01 copied from GlobalTypes
--	FUNCTION to_01(slv : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
--	BEGIN
--	  return  to_stdlogicvector(to_bitvector(slv));
--	END;
	
	FUNCTION sim_CRC8(words : T_SIM_STREAM_WORD_VECTOR_8) RETURN STD_LOGIC_VECTOR IS
		CONSTANT CRC8_INIT					: T_SLV_8					:= x"FF";
		CONSTANT CRC8_POLYNOMIAL		: T_SLV_8					:= x"31";			-- 0x131
		
		VARIABLE CRC8_Value					: T_SLV_8					:= CRC8_INIT;

--		VARIABLE Pattern						: T_DATAFIFO_PATTERN;
		VARIABLE Word								: UNSIGNED(T_SLV_8'range);
	BEGIN
		REPORT "Computing CRC8 for Words " & to_string(words'low) & " to " & to_string(words'high) SEVERITY NOTE;
		
		FOR I IN words'range LOOP
			IF (words(I).Valid = '1') THEN
				Word	:= to_01(unsigned(words(I).Data));

--					ASSERT (J > 9) REPORT str_merge("  Word: 0x", hstr(Word), "    CRC16_Value: 0x", hstr(CRC16_Value)) SEVERITY NOTE;

				FOR J IN Word'range LOOP
						CRC8_Value := (CRC8_Value(CRC8_Value'high - 1 DOWNTO 0) & '0') XOR (CRC8_POLYNOMIAL AND (CRC8_POLYNOMIAL'range => (Word(J) XOR CRC8_Value(CRC8_Value'high))));
				END LOOP;
			END IF;
				
			EXIT WHEN (words(I).EOFG = TRUE);
		END LOOP;
	
		REPORT "  CRC8: 0x" & to_string(CRC8_Value, 'h') SEVERITY NOTE;
	
		RETURN CRC8_Value;
	END;

--	FUNCTION sim_CRC16(words : T_SIM_STREAM_WORD_VECTOR_8) RETURN STD_LOGIC_VECTOR IS
--		CONSTANT CRC16_INIT					: T_SLV_16					:= x"FFFF";
--		CONSTANT CRC16_POLYNOMIAL		: T_SLV_16					:= x"8005";			-- 0x18005
--		
--		VARIABLE CRC16_Value				: T_SLV_16					:= CRC16_INIT;
--
--		VARIABLE Pattern						: T_DATAFIFO_PATTERN;
--		VARIABLE Word								: T_SLV_32;
--	BEGIN
--		REPORT str_merge("Computing CRC16 for Frames ", str(Frames'low), " to ", str(Frames'high)) SEVERITY NOTE;
--		
--		FOR I IN Frames'range LOOP
--			NEXT WHEN (NOT ((Frames(I).Direction	= DEV_HOST) AND (Frames(I).DataFIFOPatterns(0).Data(7 DOWNTO 0) = x"46")));
--		
----			REPORT Frames(I).Name SEVERITY NOTE;
--		
--			FOR J IN 1 TO Frames(I).Count - 1 LOOP
--				Pattern		:= Frames(I).DataFIFOPatterns(J);
--				
--				IF (Pattern.Valid = '1') THEN
--					Word	:= to_01(Pattern.Data);
--
----					ASSERT (J > 9) REPORT str_merge("  Word: 0x", hstr(Word), "    CRC16_Value: 0x", hstr(CRC16_Value)) SEVERITY NOTE;
--
--					FOR K IN Word'range LOOP
--						CRC16_Value := (CRC16_Value(CRC16_Value'high - 1 DOWNTO 0) & '0') XOR (CRC16_POLYNOMIAL AND (CRC16_POLYNOMIAL'range => (Word(K) XOR CRC16_Value(CRC16_Value'high))));
--					END LOOP;
--				END IF;
--				
--				EXIT WHEN (Pattern.EOTP = TRUE);
--			END LOOP;
--		END LOOP;
--	
--		REPORT str_merge("  CRC16: 0x", hstr(CRC16_Value)) SEVERITY NOTE;
--	
--		RETURN CRC16_Value;
--	END;
END PACKAGE BODY;
