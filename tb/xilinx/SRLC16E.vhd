-- $Header: /srv/cvs/alignment/systolic/vhdl/unisim/SRLC16E.vhd,v 1.1 2011-08-11 20:46:47 tbp Exp $
-------------------------------------------------------------------------------
-- Copyright (c) 1995/2004 Xilinx, Inc.
-- All Right Reserved.
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor : Xilinx
-- \   \   \/     Version : 11.1
--  \   \         Description : Xilinx Functional Simulation Library Component
--  /   /                  16-Bit Shift Register Look-Up-Table with Carry and Clock Enable
-- /___/   /\     Filename : SRLC16E.vhd
-- \   \  /  \    Timestamp : Thu Apr  8 10:56:58 PDT 2004
--  \___\/\___\
--
-- Revision:
--    03/23/04 - Initial version.

----- CELL SRLC16E -----

library IEEE;
use IEEE.STD_LOGIC_1164.all;

--library UNISIM;
--use UNISIM.VPKG.all;

entity SRLC16E is

  generic (
       INIT : bit_vector := X"0000"
  );

  port (
        Q   : out STD_ULOGIC;
        Q15 : out STD_ULOGIC;
        
        A0  : in STD_ULOGIC;
        A1  : in STD_ULOGIC;
        A2  : in STD_ULOGIC;
        A3  : in STD_ULOGIC;
        CE  : in STD_ULOGIC;
        CLK : in STD_ULOGIC;        
        D   : in STD_ULOGIC
       ); 
end SRLC16E;

library IEEE;
use IEEE.NUMERIC_STD.all;

architecture SRLC16E_V of SRLC16E is
  signal SHIFT_REG : std_ulogic_vector(15 downto 0) := std_ulogic_vector(To_StdLogicVector(INIT));
begin
  process(SHIFT_REG, A0, A1, A2, A3)
    variable addr : std_ulogic_vector(3 downto 0);
    variable rsv  : std_ulogic_vector(SHIFT_REG'range);
  begin
    addr := (A3, A2, A1, A0);
    if not Is_X(addr) then
      Q <= SHIFT_REG(to_integer(unsigned(addr)));
    else
      -- Now we have UNKNOWNs ...
      rsv := SHIFT_REG;
      for i in rsv'range loop
        if To_BitVector(addr xor std_ulogic_vector(to_unsigned(i, addr'length))) /= (addr'range => '0') then
          rsv(i) := 'Z';
        end if;
      end loop;
      Q <= resolved(rsv);
    end if;
  end process;
  Q15 <= SHIFT_REG(15);

  -- Shifting
  process(clk)
    variable  en : X01;
    variable  nv : std_ulogic_vector(SHIFT_REG'range);
  begin
    if rising_edge(clk) then
      en := To_X01(CE);
      if en /= '0' then
        nv := SHIFT_REG(14 downto 0) & To_X01(D);
        if en = 'X' then
          for i in nv'range loop
            nv(i) := resolved(SHIFT_REG(i) & nv(i));
          end loop;
        end if;
        SHIFT_REG <= nv after 100 ps;
      end if;
    end if;
  end process;

end SRLC16E_V;
