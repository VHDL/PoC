library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
--use			PoC.lcd.all;


entity BCDDigit is
	generic (
		RADIX				: POSITIVE					:= 4
	);
	port (
		Clock				: in	STD_LOGIC;
		Reset				: in	STD_LOGIC;
		Strobe			: in	STD_LOGIC;
		C_In				: in	STD_LOGIC_VECTOR(RADIX - 1 downto 0);
		C_Out				: out	STD_LOGIC_VECTOR(RADIX - 1 downto 0);
		BCD					: out T_BCD_VECTOR(RADIX - 1 downto 0)
	);
end;

architecture rtl of BCDDigit is
	type T_BCDSUM		IS array (NATURAL range <>)		OF UNSIGNED(3 downto 0);

begin
	process(Clock)
		variable BCDSum			: T_BCDSUM(RADIX - 1 downto 0)				:= (others => (others => '0'));
		variable Carray			: STD_LOGIC_VECTOR(RADIX downto 0);

	begin
		if rising_edge(Clock) then
			IF Reset = '1' then
			 BCDSum								:= (others => (others => '0'));
			else
				IF Strobe = '1' then
					for i in RADIX - 1 downto 0 loop

						Carray(0)				:= C_In(I);
						for j in 0 to RADIX - 1 loop
							BCDSum(J)			:= Bin2BCD(Carray(J), BCDSum(J));
							Carray(J + 1) := ite((BCDSum(J) > 4), '1', '0');
						end loop;

						C_Out(I)				<= Carray(RADIX);
					end loop;

					for i in 0 to RADIX - 1 loop
						BCD(I)					<= T_BCD'(BCDSum(I));
					end loop;
				end if;
			end if;
		end if;
	end process;
end;
