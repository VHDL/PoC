library IEEE;
use	IEEE.STD_LOGIC_1164.all;
use	IEEE.NUMERIC_STD.all;

entity EventSync is
  port (
	Clock1			: in	STD_LOGIC;															-- input clock domain
	Clock2			: in	STD_LOGIC;															-- output clock domain
	src			: in	STD_LOGIC;
	strobe			: out	STD_LOGIC				-- event detect
	);
end;

architecture rtl of EventSync is
	signal sreg		: STD_LOGIC	:= '0';
	signal sample		: STD_LOGIC_VECTOR(1 downto 0)	:= "00";
	signal toggle		: STD_LOGIC := '0';
begin
	-- input T-FF @Clock1
	process(Clock1)
	begin
		if rising_edge(Clock1) then
			if (src = '1' AND sreg = '0') then
				toggle <= not toggle;
			end if;
			sreg <= src;
		end if;
	end process;

	-- D-FFs @Clock2
	process(Clock2)
	begin
		if rising_edge(Clock2) then
			sample <= sample(0) & toggle;
		end if;
	end process;

	-- calculate event signal
	strobe <= sample(0) XOR sample(1);

end;
