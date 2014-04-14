-- $Header: /srv/cvs/poc/alu/tb/MUXCY.vhd,v 1.1 2013-05-27 19:11:01 tbp Exp $
-------------------------------------------------------------------------------
-- Copyright (c) 1995/2004 Xilinx, Inc.
-- All Right Reserved.
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor : Xilinx
-- \   \   \/     Version : 11.1
--  \   \         Description : Xilinx Functional Simulation Library Component
--  /   /                  2-to-1 Multiplexer for Carry Logic with General Output
-- /___/   /\     Filename : MUXCY.vhd
-- \   \  /  \    Timestamp : Thu Apr  8 10:56:03 PDT 2004
--  \___\/\___\
--
-- Revision:
--    03/23/04 - Initial version.

--    08/23/07 - Handle S= X case. CR434611 
----- CELL MUXCY -----

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity MUXCY is
  port(
    O : out std_ulogic;

    CI : in std_ulogic;
    DI : in std_ulogic;
    S  : in std_ulogic
    );
end MUXCY;

architecture MUXCY_V of MUXCY is
  signal ch, dh : X01;
begin
  ch <= To_X01(CI);
  dh <= To_X01(DI);
  with To_X01(S) select O <=
    dh		      when '0',
    ch		      when '1',
    resolved(dh & ch) when others;
end MUXCY_V;


