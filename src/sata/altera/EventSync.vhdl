LIBRARY IEEE;
USE	IEEE.STD_LOGIC_1164.ALL;
USE	IEEE.NUMERIC_STD.ALL;

ENTITY EventSync IS
  PORT (
	Clock1			: IN	STD_LOGIC;															-- input clock domain
	Clock2			: IN	STD_LOGIC;															-- output clock domain
	src			: IN	STD_LOGIC;
	strobe			: OUT	STD_LOGIC				-- event detect
	);
END;

ARCHITECTURE rtl OF EventSync IS
	SIGNAL sreg		: STD_LOGIC	:= '0';
	SIGNAL sample		: STD_LOGIC_VECTOR(1 downto 0)	:= "00";
	SIGNAL toggle		: STD_LOGIC := '0';
BEGIN
	-- input T-FF @Clock1
	PROCESS(Clock1)
	BEGIN
		IF rising_edge(Clock1) THEN
			IF (src = '1' AND sreg = '0') THEN
				toggle <= not toggle;
			END IF;
			sreg <= src;
		END IF;
	END PROCESS;

	-- D-FFs @Clock2
	PROCESS(Clock2)
	BEGIN
		IF rising_edge(Clock2) THEN
			sample <= sample(0) & toggle;
		END IF;
	END PROCESS;

	-- calculate event signal
	strobe <= sample(0) XOR sample(1);

END;
