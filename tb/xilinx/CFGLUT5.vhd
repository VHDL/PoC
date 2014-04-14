-- $Header: /srv/cvs/alignment/systolic/vhdl/unisim/CFGLUT5.vhd,v 1.1 2011-08-11 20:46:47 tbp Exp $
-------------------------------------------------------------------------------
-- Copyright (c) 1995/2004 Xilinx, Inc.
-- All Right Reserved.
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor : Xilinx
-- \   \   \/     Version : 11.1
--  \   \         Description : Xilinx Functional Simulation Library Component
--  /   /                 5-input Dynamically Reconfigurable Look-Up-Table with Carry and Clock Enable 
-- /___/   /\     Filename : CFGLUT5.vhd
-- \   \  /  \    Timestamp : 
--  \___\/\___\
--
-- Revision:
--    12/28/05 - Initial version.
--    04/13/06 - Add address declaration. (CR229735)
-- End Revision

----- CELL CFGLUT5 -----

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity CFGLUT5 is

  generic (
       INIT : bit_vector := X"00000000"
  );

  port (
        CDO : out STD_ULOGIC;
        O5  : out STD_ULOGIC;
        O6  : out STD_ULOGIC;

        CDI : in STD_ULOGIC;
        CE  : in STD_ULOGIC;
        CLK : in STD_ULOGIC;        
        I0  : in STD_ULOGIC;
        I1  : in STD_ULOGIC;
        I2  : in STD_ULOGIC;
        I3  : in STD_ULOGIC;
        I4  : in STD_ULOGIC
       ); 
end CFGLUT5;

library IEEE;
use IEEE.numeric_std.all;

architecture CFGLUT5_V of CFGLUT5 is
  signal SHIFT_REG : std_ulogic_vector(31 downto 0) :=  std_ulogic_vector(To_StdLogicVector(INIT));
begin

  -----------------------------------------------------------------------------
  -- Reading
  process(SHIFT_REG, I4, I3, I2, I1, I0)
   variable addr   : std_ulogic_vector(4 downto 0);
   variable v5, v6 : std_logic;
  begin
    -- Concatenate Input Address
    addr := I4 & I3 & I2 & I1 & I0;
    if not Is_X(addr) then
      -- Keep the Standard Case Simple
      O6 <= SHIFT_REG(to_integer(unsigned(addr(4 downto 0))));
      O5 <= SHIFT_REG(to_integer(unsigned(addr(3 downto 0))));
    else
      -- Now we have UNKNOWNs ...
      v6 := 'Z';
      v5 := 'Z';
      for i in 0 to 15 loop
	if To_BitVector(addr(3 downto 0) xor std_ulogic_vector(to_unsigned(i, 4))) = x"0" then
	  v5 := resolved(v5 & SHIFT_REG(i));
	  case To_X01(addr(4)) is
	    when 'X' => v6 := resolved(v6 & SHIFT_REG(i) & SHIFT_REG(16+i));
	    when '0' => v6 := resolved(v6 & SHIFT_REG(i));
	    when '1' => v6 := resolved(v6 & SHIFT_REG(16+i));
	  end case;
	end if;
      end loop;
      O6 <= v6;
      O5 <= v5;
    end if;
  end process;
  CDO <= SHIFT_REG(31);

  -----------------------------------------------------------------------------
  -- Shifting
  process(clk)
    variable  en : X01;
    variable  nv : std_ulogic_vector(SHIFT_REG'range);
  begin
    if rising_edge(clk) then
      en := To_X01(CE);
      if en /= '0' then
	nv := SHIFT_REG(30 downto 0) & To_X01(CDI);
	if en = 'X' then
	  for i in nv'range loop
	    nv(i) := resolved(SHIFT_REG(i) & nv(i));
	  end loop;
	end if;
	SHIFT_REG <= nv after 100 ps;
      end if;
    end if;
  end process;

end CFGLUT5_V;
