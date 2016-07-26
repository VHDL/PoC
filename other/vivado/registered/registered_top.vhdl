library	ieee;
use			ieee.std_logic_1164.all;

entity registered_top is
	port (
		Clock		: in	STD_LOGIC;
		DataIn	: in	STD_LOGIC;
		DataOut	: out	STD_LOGIC
	);
end entity;


architecture rtl of registered_top is
	-- implement an optional register stage
	function registered(signal Clock : std_logic; constant IsRegistered : boolean) return boolean is
	begin
		if (IsRegistered = TRUE) then
			return rising_edge(Clock);
		else
			return TRUE;
		end if;
	end function;

	signal reg0		: STD_LOGIC;
	signal reg1		: STD_LOGIC;
	signal reg2		: STD_LOGIC;
	
	signal reg3		: STD_LOGIC;
	signal reg4		: STD_LOGIC;
begin
	reg0		<= DataIn when rising_edge(Clock);
	reg1		<= reg0		when registered(Clock, FALSE);
	reg2		<= reg1		when registered(Clock, TRUE);
	
	process(Clock)
	begin
		if rising_edge(Clock) then
			reg3	<= reg2;
		end if;
	end process;
	
	reg4	<= reg3		when (Clock'event and Clock = '1' and Clock'last_value = '0');
	
	DataOut	<= reg4;
end architecture;		
