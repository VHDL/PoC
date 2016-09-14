library	ieee;
use			ieee.std_logic_1164.all;

entity registered_top is
	port (
		Clock		: in	std_logic;
		DataIn	: in	std_logic;
		DataOut	: out	std_logic
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

	signal reg0		: std_logic;
	signal reg1		: std_logic;
	signal reg2		: std_logic;

	signal reg3		: std_logic;
	signal reg4		: std_logic;
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
