-- $Header: /srv/cvs/alignment/systolic/vhdl/unisim/SRLC32E.vhd,v 1.1 2011-08-11 20:46:47 tbp Exp $
-------------------------------------------------------------------------------
-- Copyright (c) 1995/2004 Xilinx, Inc.
-- All Right Reserved.
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor : Xilinx
-- \   \   \/     Version : 11.1
--  \   \         Description : Xilinx Functional Simulation Library Component
--  /   /                  32-Bit Shift Register Look-Up-Table with Carry and Clock Enable
-- /___/   /\     Filename : SRLC32E.vhd
-- \   \  /  \    Timestamp : Thu Apr  8 10:56:58 PDT 2004
--  \___\/\___\
--
-- Revision:
--    03/15/04 - Initial version.
--    04/22/05 - Change input A type from ulogic vector to logic vector.
-- End Revision

----- CELL SRLC32E -----

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity SRLC32E is
  generic (
       INIT : bit_vector := X"00000000"
  );
  port (
        Q   : out STD_ULOGIC;
        Q31 : out STD_ULOGIC;

        A   : in STD_LOGIC_VECTOR(4 downto 0);
        CE  : in STD_ULOGIC;
        CLK : in STD_ULOGIC;        
        D   : in STD_ULOGIC
       ); 
end SRLC32E;

architecture SRLC32E_V of SRLC32E is
  signal SHIFT_REG : std_ulogic_vector(31 downto 0) :=  std_ulogic_vector(To_StdLogicVector(INIT));
begin

  process(SHIFT_REG, A)
   variable rsv : std_ulogic_vector(31 downto 0);
  begin
    -- Concatenate Input Address
    if not Is_X(A) then
      -- Keep the Standard Case Simple
      Q <= SHIFT_REG(to_integer(unsigned(A)));
    else
      -- Now we have UNKNOWNs ...
      rsv := SHIFT_REG;
      for i in rsv'range loop
        if To_BitVector(A xor std_logic_vector(to_unsigned(i, A'length))) /= (A'range => '0') then
          rsv(i) := 'Z';
        end if;
      end loop;
      Q <= resolved(rsv);
    end if;
  end process;
  Q31 <= SHIFT_REG(31);

  -----------------------------------------------------------------------------
  -- Shifting
  process(clk)
    variable  en : X01;
    variable  nv : std_ulogic_vector(SHIFT_REG'range);
  begin
    if rising_edge(clk) then
      en := To_X01(CE);
      if en /= '0' then
        nv := SHIFT_REG(30 downto 0) & To_X01(D);
        if en = 'X' then
          for i in nv'range loop
            nv(i) := resolved(SHIFT_REG(i) & nv(i));
          end loop;
        end if;
        SHIFT_REG <= nv after 100 ps;
      end if;
    end if;
  end process;

end SRLC32E_V;


