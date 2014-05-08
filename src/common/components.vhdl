LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

PACKAGE components IS
	-- FlipFlop functions
	FUNCTION ffdre(q : STD_LOGIC; d : STD_LOGIC; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC;												-- D-FlipFlop with reset and enable
	FUNCTION ffdre(q : STD_LOGIC_VECTOR; d : STD_LOGIC_VECTOR; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC_VECTOR;	-- D-FlipFlop with reset and enable
	FUNCTION ffdse(q : STD_LOGIC; d : STD_LOGIC; set : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC;			-- D-FlipFlop with set and enable
	FUNCTION ffrs(q : STD_LOGIC; rst : STD_LOGIC; set : STD_LOGIC) RETURN STD_LOGIC;										-- RS-FlipFlop with dominant rst

END;

PACKAGE BODY components IS
	-- D-FlipFlop with reset and enable
	FUNCTION ffdre(q : STD_LOGIC; d : STD_LOGIC; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		RETURN ((d AND en) OR (q AND NOT en)) AND NOT rst;
	END FUNCTION;
	
	FUNCTION ffdre(q : STD_LOGIC_VECTOR; d : STD_LOGIC_VECTOR; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN ((d AND (q'range => en)) OR (q AND NOT (q'range => en))) AND NOT (q'range => rst);
	END FUNCTION;
	
	-- D-FlipFlop with set and enable
	FUNCTION ffdse(q : STD_LOGIC; d : STD_LOGIC; set : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		RETURN ((d AND en) OR (q AND NOT en)) OR set;
	END FUNCTION;
	
	-- RS-FlipFlop with dominant rst
	FUNCTION ffrs(q : STD_LOGIC; rst : STD_LOGIC; set : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		RETURN (q AND NOT rst) OR (set AND NOT rst);
	END FUNCTION;
END PACKAGE BODY;