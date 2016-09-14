library IEEE;
use	IEEE.STD_LOGIC_1164.all;
use	IEEE.NUMERIC_STD.all;

entity EventSync is
  port (
	Clock1			: in	std_logic;															-- input clock domain
	Clock2			: in	std_logic;															-- output clock domain
	src			: in	std_logic;
	strobe			: out	std_logic				-- event detect
	);
end;

architecture rtl of EventSync is
	signal sreg		: std_logic	:= '0';
	signal sample		: std_logic_vector(1 downto 0)	:= "00";
	signal toggle		: std_logic := '0';
begin
	-- input T-FF @Clock1
	process(Clock1)
	begin
		if rising_edge(Clock1) then
			if (src = '1' and sreg = '0') then
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
	strobe <= sample(0) xor sample(1);

end;
