--
-- Copyright (c) 2011
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: comm_bitwidth_converter
-- Author(s): Patrick Lehmann
--						Max Koehler
-- 
-- Summary:
-- ========
--  This module convertes std_logic_vectors with different bit widths.
--	Up and down scaling is supported.
--
-- Description:
-- ============
--	Input "I" is of clock domain "Clock1"; output "O" is of clock domain "Clock2"
--	Optional output registers can be added by enabling (REGISTERED = TRUE).
--	In case of up scaling, input "Align" is required to mark byte 0 in the word.
--
-- Assertions:
-- ===========
--	- Clock periods of Clock1 and Clock2 MUST be multiples of each other.
--	- Clock1 and Clock2 MUST be phase aligned (related) to each other.
--
-- Dependancies:
-- =============
--	- IEEE.STD_LOGIC_1164.ALL
--	- IEEE.NUMERIC_STD.ALL
--	- PoC.functions.ALL
--
-- Naming conventions:
-- ===================
-- *_us			unsigned signals
-- *_d      delayed signals (mostly D-FlipFlops)
-- *_BW			bitwidth
--
--
-- Revision:    $Revision: 1.3 $
-- Last change: $Date: 2012-06-11 14:54:14 $
--

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;

ENTITY comm_bitwidth_converter IS
  GENERIC (
	  REGISTERED					: BOOLEAN			:= FALSE;												-- add output register @Clock2
		BW1									: POSITIVE		:= 32;													-- input bit width
		BW2									: POSITIVE		:= 16														-- output bit width
	);
  PORT (
	  Clock1							: IN	STD_LOGIC;															-- input clock domain
		Clock2							: IN	STD_LOGIC;															-- output clock domain
		Align								: IN	STD_LOGIC;															-- align word (one cycle high impulse)
		I										: IN	STD_LOGIC_VECTOR(BW1 - 1 DOWNTO 0);			-- input word
		O										: OUT STD_LOGIC_VECTOR(BW2 - 1 DOWNTO 0)			-- output word
	);
END;

ARCHITECTURE rtl OF comm_bitwidth_converter IS
	function bw(bw1 : positive; bw2 : positive) return positive is
    constant ratio : real		:= real(bw1) / real(bw2);
  begin
    if ratio > 1.0 then
			return log2ceil(integer(ratio));
		else
			return log2ceil(integer(1.0 / ratio));
		end if;
  end;

	CONSTANT BW_1				: POSITIVE	:= BW1;
	CONSTANT BW_2				: POSITIVE	:= BW2;

	CONSTANT BW_RATIO		: REAL			:= real(BW1) / real(BW2);
	CONSTANT SMALLER		: BOOLEAN		:= BW_RATIO > 1.0;
	CONSTANT COUNTER_BW : POSITIVE	:= bw(BW1, BW2);

BEGIN
	-- word to byte splitter
	gen1 : IF (SMALLER = TRUE) GENERATE
		TYPE SLV_mux IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(BW2 - 1 DOWNTO 0);

		SIGNAL WordBoundary			: STD_LOGIC;
		SIGNAL WordBoundary_d		: STD_LOGIC;
		SIGNAL Align_i					: STD_LOGIC;

		SIGNAL I_d							: STD_LOGIC_VECTOR(BW1 - 1 DOWNTO 0);
		SIGNAL MuxInput					: SLV_mux(2**COUNTER_BW - 1 DOWNTO 0);
		SIGNAL MuxOutput				: STD_LOGIC_VECTOR(BW2 - 1 DOWNTO 0);
		SIGNAL MuxCounter_us		: UNSIGNED(COUNTER_BW - 1 DOWNTO 0)					:= (OTHERS => '0');
		SIGNAL MuxSelect_us			: UNSIGNED(COUNTER_BW - 1 DOWNTO 0);
		
	BEGIN
		-- input register @Clock1
		PROCESS(Clock1)
		BEGIN
			IF rising_edge(Clock1) THEN
				I_d	<= I;
			END IF;
		END PROCESS;
		
		-- selection multiplexer
		gen11 : FOR J IN 2**COUNTER_BW - 1 DOWNTO 0 GENERATE
			MuxInput(J)	<= I_d(((J + 1) * BW_2) - 1 DOWNTO (J * BW_2));
		END GENERATE;
		
		-- multiplexer
		MuxOutput <= MuxInput(to_integer(MuxSelect_us));
		
		-- word boundary T-FF @Clock1 and D-FF @Clock2
		WordBoundary		<= NOT WordBoundary WHEN rising_edge(Clock1) ELSE WordBoundary;
		WordBoundary_d	<= WordBoundary			WHEN rising_edge(Clock2) ELSE WordBoundary_d;
		
		-- generate Align_i signal
		Align_i <= WordBoundary XOR WordBoundary_d;
		
		-- multiplexer control @Clock2
		PROCESS(Clock2)
		BEGIN
			IF rising_edge(Clock2) THEN
				IF (Align_i = '1') THEN
					MuxCounter_us		<= to_unsigned(1, MuxCounter_us'length);
				ELSE
					MuxCounter_us		<= MuxCounter_us + 1;
				END IF;
			END IF;
		END PROCESS;
		
		MuxSelect_us <= (OTHERS => '0') WHEN (Align_i = '1') ELSE MuxCounter_us;
		
		-- add output register @Clock2
		gen121 : IF (REGISTERED = TRUE) GENERATE
			PROCESS(Clock2)
			BEGIN
				IF rising_edge(Clock2) THEN
					O <= MuxOutput;
				END IF;
			END PROCESS;
		END GENERATE;
		gen122 : IF (REGISTERED = FALSE) GENERATE
			O <= MuxOutput;
		END GENERATE;
	END GENERATE;


	-- byte to word collection
	gen2 : IF (SMALLER = FALSE) GENERATE
		SIGNAL I_Counter_us					: UNSIGNED(COUNTER_BW - 1 DOWNTO 0)						:= (OTHERS => '0');
		SIGNAL I_Select_us					: UNSIGNED(COUNTER_BW - 1 DOWNTO 0);
		SIGNAL I_d									:	STD_LOGIC_VECTOR(BW2 - BW1 - 1 DOWNTO 0);
		SIGNAL Collected						: STD_LOGIC_VECTOR(BW2 - 1 DOWNTO 0);
		SIGNAL Collected_d					: STD_LOGIC_VECTOR(BW2 - 1 DOWNTO 0);
		
	BEGIN
		-- byte alignment counter @Clock1
		PROCESS(Clock1)
		BEGIN
			IF rising_edge(Clock1) THEN
				IF (Align = '1') THEN
					I_Counter_us		<= to_unsigned(1, I_Counter_us'length);
				ELSE
					I_Counter_us		<= I_Counter_us + 1;
				END IF;
			END IF;
		END PROCESS;
	
		I_Select_us <= (OTHERS => '0') WHEN (Align = '1') ELSE I_Counter_us;
	
		-- delay registers @Clock1
		PROCESS(Clock1)
		BEGIN
			IF rising_edge(Clock1) THEN
				FOR J IN 2**COUNTER_BW - 2 DOWNTO 0 LOOP
					IF J = to_integer(I_Select_us) THEN					-- d-FF enable
						FOR K IN BW1 - 1 DOWNTO 0 LOOP
							I_d((J * BW1) + K) <= I(K);
						END LOOP;
					END IF;
				END LOOP;
			END IF;
		END PROCESS;
		
		-- collect signals
		Collected <= I & I_d;
		
		-- register collected signals again @Clock1
		PROCESS(Clock1)
		BEGIN
			IF rising_edge(Clock1) THEN
				IF (to_integer(I_Select_us) = (2**COUNTER_BW - 1)) THEN
					Collected_d <= Collected;
				END IF;
			END IF;
		END PROCESS;
		
		-- add output register @Clock2
		gen211 : IF (REGISTERED = TRUE) GENERATE
			PROCESS(Clock2)
			BEGIN
				IF rising_edge(Clock2) THEN
					O <= Collected_d;
				END IF;
			END PROCESS;
		END GENERATE;
		gen212 : IF (REGISTERED = FALSE) GENERATE
			O <= Collected_d;
		END GENERATE;
	END GENERATE;
END;
