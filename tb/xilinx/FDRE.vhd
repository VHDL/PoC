-- $Header: /srv/cvs/alignment/systolic/vhdl/unisim/FDRE.vhd,v 1.1 2011-08-11 20:46:47 tbp Exp $
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
-- /___/   /\     Filename : FDRE.vhd
-- \   \  /  \    Timestamp : Thu Apr  8 10:55:24 PDT 2004
--  \___\/\___\
--
-- Revision:
--    03/23/04 - Initial version.
--    11/03/08 - Initial Q. CR49409
-- End Revision

----- CELL FDRE -----

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity FDRE is
  generic(
    INIT : bit := '0'
  );
  port(
    Q : out std_ulogic;

    C  : in std_ulogic;
    CE : in std_ulogic;
    D  : in std_ulogic;
    R  : in std_ulogic
  );
end FDRE;

architecture FDRE_V of FDRE is
  signal qq : std_ulogic := TO_X01(INIT);
begin
 
  process(C)
    variable  rt, en, nv : X01;
    variable  v : std_ulogic_vector(2 downto 0);
  begin
    if rising_edge(C) then
      rt := To_X01(R);
      en := To_X01(CE);
      if rt /= '0' or en /= '0' then
	if rt = '1' then
	  nv := '0';
	else
	  nv := To_X01(D);
	  if rt /= '0' or en /= '1' then
	    v := (qq, nv, '0');
	    if rt = '0' then
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

end FDRE_V;
