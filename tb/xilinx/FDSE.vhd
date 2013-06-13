-- $Header: /srv/cvs/alignment/systolic/vhdl/unisim/FDSE.vhd,v 1.1 2011-08-11 21:41:00 tbp Exp $
-------------------------------------------------------------------------------
-- Copyright (c) 1995/2004 Xilinx, Inc.
-- All Right Reserved.
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor : Xilinx
-- \   \   \/     Version : 11.1
--  \   \         Description : Xilinx Functional Simulation Library Component
--  /   /                  D Flip-Flop with Synchronous Reset and Clock Enable
-- /___/   /\     Filename : FDSE.vhd
-- \   \  /  \    Timestamp : Thu Apr  8 10:55:24 PDT 2004
--  \___\/\___\
--
-- Revision:
--    03/23/04 - Initial version.
--    11/03/08 - Initial Q. CR49409
-- End Revision

----- CELL FDSE -----

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity FDSE is
  generic(
    INIT : bit := '1'
  );
  port(
    Q : out std_ulogic;

    C  : in std_ulogic;
    CE : in std_ulogic;
    D  : in std_ulogic;
    S  : in std_ulogic
  );
end FDSE;

architecture FDSE_V of FDSE is
  signal qq : std_ulogic := TO_X01(INIT);
begin
 
  process(C)
    variable  st, en, nv : X01;
    variable  v : std_ulogic_vector(2 downto 0);
  begin
    if rising_edge(C) then
      st := To_X01(S);
      en := To_X01(CE);
      if st /= '0' or en /= '0' then
	if st = '1' then
	  nv := '1';
	else
	  nv := To_X01(D);
	  if st /= '0' or en /= '1' then
	    v := (qq, nv, '1');
	    if st = '0' then
	      v(0) := 'Z';
	    else
	      case en is
		when 'X' => null;
		when '0' => v(1) := 'Z';
		when '1' => v(2) := 'Z';
	      end case;
	    end if;
	    nv := resolved(v);
	  end if;
        end if;
	qq <= nv after 100 ps;
      end if;
    end if;
  end process;
  Q <=  qq;

end FDSE_V;
