LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

ENTITY misc_Synchronizer IS
  GENERIC (
	  BITS								: POSITIVE		:= 1;														-- number of bit to be synchronized
		GATED_INPUT_BY_BUSY	: BOOLEAN			:= FALSE												-- use gated input (by busy signal)
	);
  PORT (
		Clock1							: IN	STD_LOGIC;															-- input clock domain
		Clock2							: IN	STD_LOGIC;															-- output clock domain
		I										: IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- input bits
		O										: OUT STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);		-- output bits
		B										: OUT	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0)			-- busy bits
	);
END;

ARCHITECTURE rtl OF misc_Synchronizer IS
	ATTRIBUTE ASYNC_REG												: STRING;
	ATTRIBUTE SHREG_EXTRACT										: STRING;

BEGIN

	gen : FOR J IN 0 TO BITS - 1 GENERATE
		SIGNAL Q0			: STD_LOGIC			:= '0';
		SIGNAL Q1			: STD_LOGIC			:= '0';
		SIGNAL Q2			: STD_LOGIC			:= '0';
		SIGNAL Q3			: STD_LOGIC			:= '0';
		SIGNAL Q4			: STD_LOGIC			:= '0';
		SIGNAL Q5			: STD_LOGIC			:= '0';

		-- Mark registers Q1 and Q4  as asynchronous
		ATTRIBUTE ASYNC_REG OF Q1			: SIGNAL IS "TRUE";
		ATTRIBUTE ASYNC_REG OF Q4			: SIGNAL IS "TRUE";

		-- Prevent XST from translating two FFs into SRL plus FF
		ATTRIBUTE SHREG_EXTRACT OF Q0	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF Q1	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF Q2	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF Q3	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF Q4	: SIGNAL IS "NO";
		ATTRIBUTE SHREG_EXTRACT OF Q5	: SIGNAL IS "NO";
		
		SIGNAL Busy		: STD_LOGIC;
	BEGIN
		-- input T-FF @Clock1
		PROCESS(Clock1)
		BEGIN
			IF rising_edge(Clock1) THEN
				IF (GATED_INPUT_BY_BUSY = TRUE) THEN
					Q0	<= (I(J) AND NOT Busy) XOR Q0;
				ELSE
					Q0	<= I(J) XOR Q0;
				END IF;
			END IF;
		END PROCESS;
			
		-- D-FFs @Clock2
		PROCESS(Clock2)
		BEGIN
			IF rising_edge(Clock2) THEN
				Q1	<= Q0;
				Q2	<= Q1;
				Q3	<= Q2;
			END IF;
		END PROCESS;

		-- D-FFs @Clock1
		PROCESS(Clock1)
		BEGIN
			IF rising_edge(Clock1) THEN
				Q4	<= Q3;
				Q5	<= Q4;
			END IF;
		END PROCESS;

		-- calculate busy signal
		Busy	<= Q0 XOR Q5;
		B(J)	<= Busy;
		
		-- restore information
		O(J)	<= Q2 XOR Q3;
	END GENERATE;
END;