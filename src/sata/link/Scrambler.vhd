LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;

ENTITY Scrambler IS
	GENERIC (
		POLYNOMIAL	: BIT_VECTOR					:= x"1A011";
		SEED				: BIT_VECTOR					:= x"FFFF";
		WIDTH				: POSITIVE						:= 32
	);
	PORT (
		Clock				: IN	STD_LOGIC;
		Enable			: IN	STD_LOGIC;
		Reset				: IN	STD_LOGIC;
		
		DataIn			: IN	STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0);
		DataOut			: OUT	STD_LOGIC_VECTOR(WIDTH - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF Scrambler IS
	FUNCTION normalize(G : BIT_VECTOR) RETURN BIT_VECTOR IS
		VARIABLE GN		: BIT_VECTOR(G'length - 1 DOWNTO 0);
	BEGIN
		GN := G;
		
		FOR i IN GN'left DOWNTO 1 LOOP
			IF (GN(i) = '1') THEN
				RETURN GN(i - 1 DOWNTO 0);
			END IF;
		END LOOP;
		
		REPORT ""	SEVERITY failure;
		RETURN G;
	END;

	CONSTANT GENERATOR	: BIT_VECTOR		:= normalize(POLYNOMIAL);
	
	SIGNAL LFSR					: STD_LOGIC_VECTOR(GENERATOR'range);
	SIGNAL Mask					: STD_LOGIC_VECTOR(DataIn'range);
	
BEGIN

-- TODO: test SEED length

	PROCESS(Clock, Reset, Enable, LFSR)
		VARIABLE Vector		: STD_LOGIC_VECTOR(LFSR'range);
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				Vector := to_stdlogicvector(SEED);
					
				FOR i IN Mask'low TO Mask'high LOOP
					Mask(i) <= Vector(Vector'left);
					
					-- Galois LFSR
					Vector	:= (Vector(Vector'left - 1 DOWNTO 0) & '0') XOR (to_stdlogicvector(GENERATOR) AND (GENERATOR'range => Vector(Vector'left)));
				END LOOP;
			
				LFSR <= Vector;
			ELSE
				IF (Enable = '1') THEN
					Vector := LFSR;
					
					FOR i IN Mask'low TO Mask'high LOOP
						Mask(i) <= Vector(Vector'left);
						
						-- Galois LFSR
						Vector	:= (Vector(Vector'left - 1 DOWNTO 0) & '0') XOR (to_stdlogicvector(GENERATOR) AND (GENERATOR'range => Vector(Vector'left)));
					END LOOP;
				
					LFSR <= Vector;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	DataOut <= DataIn XOR Mask;
END;
