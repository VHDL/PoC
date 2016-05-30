library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
--use			PoC.lcd.all;


ENTITY BCDDigit IS
	GENERIC (
		RADIX				: POSITIVE					:= 4
	);
	PORT (
		Clock				: IN	STD_LOGIC;
		Reset				: IN	STD_LOGIC;
		Strobe			: IN	STD_LOGIC;
		C_In				: IN	STD_LOGIC_VECTOR(RADIX - 1 DOWNTO 0);
		C_Out				: OUT	STD_LOGIC_VECTOR(RADIX - 1 DOWNTO 0);
		BCD					: OUT T_BCD_VECTOR(RADIX - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF BCDDigit IS
	TYPE T_BCDSUM		IS ARRAY (NATURAL RANGE <>)		OF UNSIGNED(3 DOWNTO 0);

BEGIN
	PROCESS(Clock)
		VARIABLE BCDSum			: T_BCDSUM(RADIX - 1 DOWNTO 0)				:= (OTHERS => (OTHERS => '0'));
		VARIABLE Carray			: STD_LOGIC_VECTOR(RADIX DOWNTO 0);

	BEGIN
		IF rising_edge(Clock) THEN
			IF Reset = '1' THEN
			 BCDSum								:= (OTHERS => (OTHERS => '0'));
			ELSE
				IF Strobe = '1' THEN
					FOR I IN RADIX - 1 DOWNTO 0 LOOP

						Carray(0)				:= C_In(I);
						FOR J IN 0 TO RADIX - 1 LOOP
							BCDSum(J)			:= Bin2BCD(Carray(J), BCDSum(J));
							Carray(J + 1) := ite((BCDSum(J) > 4), '1', '0');
						END LOOP;

						C_Out(I)				<= Carray(RADIX);
					END LOOP;

					FOR I IN 0 TO RADIX - 1 LOOP
						BCD(I)					<= T_BCD'(BCDSum(I));
					END LOOP;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END;
